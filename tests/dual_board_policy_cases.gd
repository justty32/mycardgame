extends RefCounted
## One geometry policy, actual Hand fee gates, and sprite/HUD identity after normal startup.

func run(c) -> void:
	var source := BoardPosition.from_unit(c.player)
	var target := BoardPosition.from_unit(c.enemy)
	for shape: int in [BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_SHAPES.ROW, BoardTargeting.TARGET_SHAPES.COLUMN, BoardTargeting.TARGET_SHAPES.CROSS, BoardTargeting.TARGET_SHAPES.SQUARE_3]:
		var result: Dictionary = CrossBoardPolicy.resolve(c.battlefield, source, target, shape, 0)
		c._check(result.valid and result.board_id == "enemy" and result.cells.has(target.cell), "policy A cross-board shape %d ignores inter-board range" % shape)
		var bounded: bool = true
		for cell: Vector2i in result.cells:
			bounded = bounded and c.enemy_board.is_in_bounds(cell)
		c._check(bounded, "cross-board shape %d clips to selected board" % shape)
		var hp: int = c.enemy.get_combatant_health()
		c._check(await c._play_board("dual_shape_%d" % shape, "enemy", target.cell) == "" and hp - c.enemy.get_combatant_health() == 2, "Hand executes accepted cross-board shape %d" % shape)
	for shape: int in [BoardTargeting.TARGET_SHAPES.LINE, BoardTargeting.TARGET_SHAPES.LINE_PIERCE]:
		var hp: int = c.enemy.get_combatant_health()
		var result: String = await c._play_board("dual_shape_%d" % shape, "enemy", target.cell)
		c._check(result == "cross_board_direction_unsupported" and Global.player_data.player_energy == 50 and c.enemy.get_combatant_health() == hp, "directional shape %d rejected before energy and damage" % shape)
	var before: BoardPosition = BoardPosition.from_unit(c.enemy)
	c._check(await c._play_board("dual_push", "enemy", target.cell) == "cross_board_direction_unsupported" and Global.player_data.player_energy == 50 and BoardPosition.from_unit(c.enemy).equals(before), "cross-board directional push rejected before fee or displacement")
	for card_id: String in ["dual_nested_push", "dual_wrapper_pull"]:
		c._check(await c._play_board(card_id, "enemy", target.cell) == "cross_board_direction_unsupported" and Global.player_data.player_energy == 50 and BoardPosition.from_unit(c.enemy).equals(before), "nested/aliased directional payload rejected before payment: " + card_id)
	var self_result: Dictionary = CrossBoardPolicy.resolve(c.battlefield, source, target, BoardTargeting.TARGET_SHAPES.SELF_AREA, 2)
	c._check(self_result.valid and self_result.board_id == "party", "SELF_AREA stays on caster actual board")
	var all_result: Dictionary = CrossBoardPolicy.resolve(c.battlefield, source, target, BoardTargeting.TARGET_SHAPES.ALL, 0)
	c._check(all_result.valid and all_result.board_id == "enemy" and all_result.cells.size() == 35, "ALL shape covers only selected board")
	var missing := CombatRulesData.new()
	missing.set_serializable_properties_from_json_patch({"properties": {"free_move_per_action": 1}})
	c._check(missing.board_mode == CombatRulesData.BOARD_MODES.DUAL and missing.cross_board_policy_version == 1 and missing.cross_board_policy == "SELECT_TARGET_CELL", "old patch missing policy fields inherits explicit v1 A defaults")
	c.director.rules.cross_board_policy_version = 99
	var version_result: Dictionary = CrossBoardPolicy.resolve(c.battlefield, source, target, BoardTargeting.TARGET_SHAPES.SINGLE, 0)
	c._check(not version_result.valid and version_result.error == "unsupported_cross_board_policy_version", "unknown policy version fails closed")
	c.director.rules.cross_board_policy_version = 1
	c.director.rules.cross_board_policy = "FUTURE_C"
	c._check(not CrossBoardPolicy.resolve(c.battlefield, source, target, BoardTargeting.TARGET_SHAPES.SINGLE, 0).valid, "unimplemented future policy is rejected rather than guessed")
	c.director.rules.cross_board_policy = "SELECT_TARGET_CELL"
	c._check(not CrossBoardPolicy.resolve(c.battlefield, source, BoardPosition.new("missing", Vector2i.ZERO), 0).valid, "unknown target board is rejected")
	await c.snap_presentation()
	c._check(c.combat.board_views.size() == 2, "combat has one BoardView for each real board")
	c._check(c.player.global_position.is_equal_approx(c.combat.actor_presentation.target_position_for(c.player)) and c.enemy.global_position.is_equal_approx(c.combat.actor_presentation.target_position_for(c.enemy)), "actual combatant roots follow board-derived positions")
	c._check(not c.player.global_position.is_equal_approx(c.enemy.global_position), "same local cell has different global actor positions on different boards")
	c._check(c.player.animated_sprite_2d != null and c.enemy.animated_sprite_2d != null, "positioned nodes retain their actual AnimatedSprite2D actors")
