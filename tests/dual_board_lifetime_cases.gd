extends RefCounted
## Post-commit lethal effects cannot leave half an exchange or erase the surviving endpoint.

func run(c) -> void:
	var a: Enemy = c.director.spawn_enemy_at_cell("board_dummy", Vector2i(2, 2), "party")
	var b: Enemy = c.director.spawn_enemy_at_cell("board_dummy", Vector2i(2, 2), "enemy")
	await c.flow.process_frame
	await c.flow.process_frame
	if not c._check(a != null and b != null, "cross-board lifecycle fixtures spawned"):
		return
	var a_hp: int = a.get_combatant_health()
	var b_hp: int = b.get_combatant_health()
	var all_cells: Dictionary = CrossBoardPolicy.resolve(c.battlefield, BoardPosition.from_unit(c.player), BoardPosition.from_unit(b), BoardTargeting.TARGET_SHAPES.ALL)
	c._check(all_cells.board_id == "enemy" and not c.enemy_board.get_units().has(a), "ALL shape remains local despite an opponent on caster board")
	await c.run_actions(c.player, [], [{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 1, "bypass_block": true, "target_override": BaseAction.TARGET_OVERRIDES.ALL_OPPONENTS}}])
	c._check(a_hp - a.get_combatant_health() == 1 and b_hp - b.get_combatant_health() == 1, "ALL_OPPONENTS override independently spans both boards")
	var lethal := FieldData.new("dual_swap_lethal_leave")
	lethal.field_on_leave_actions.assign([{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 1000, "bypass_block": true}}])
	Global.register_rod(lethal)
	await c.create_field(lethal.object_id, [[2, 2]], c.player, {"board_id": "party"})
	await c.run_actions(a, [b], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "SWAP"}}])
	c._check(not a.is_alive() and b.is_alive() and b.board_id == "party" and b.board_anchor == Vector2i(2, 2), "swap commits both endpoints before source leave kills one participant")
	c._check(c.party_board.get_unit_at(Vector2i(2, 2)) == b and c.enemy_board.get_unit_at(Vector2i(2, 2)) == null, "lethal post-swap continuation neither recreates dead unit nor rolls back survivor")
	await c.run_actions(c.player, [], [{c.REMOVE_FIELD: {"board_id": "party"}}])
	for unit: Enemy in [a, b]:
		if is_instance_valid(unit):
			unit.queue_free()
	await c.flow.process_frame
	await c.flow.process_frame
