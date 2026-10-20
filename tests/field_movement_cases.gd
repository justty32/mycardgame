extends RefCounted
## Phase 2b movement integration. Setup places real combatants; effects go through the handler.

var c
var board: BoardData
var hero: BaseCombatant
var enemy: BaseCombatant
var ally: BaseCombatant
var big: BaseCombatant

func run(context) -> void:
	c = context
	board = c.board
	hero = c.player
	var placements: Array = []
	for unit: BaseCombatant in board.get_units():
		placements.append([unit, unit.board_anchor])
		board.remove(unit)
	board.place(hero, Vector2i(1, 3))
	var saved_rules: Dictionary = {}
	for key: String in ["move_adjacency", "move_pass_through_allies", "move_pass_through_enemies", "move_undo_allowed", "zone_of_control", "zoc_extra_move_cost", "zoc_triggers_on_forced_move", "displace_max_footprint_area", "paid_move_max_cells", "extra_move_delay_per_cell"]:
		saved_rules[key] = board.rules.get(key)
	var saved_hero: Dictionary = {}
	for key: String in ["move_points", "paid_cells_this_action", "cells_moved_this_action", "cells_displaced_this_action", "action_extra_delay", "ignores_zoc", "ignores_occupancy"]:
		saved_hero[key] = hero.get(key)
	enemy = await c._spawn("board_dummy", Vector2i(5, 4))
	ally = await c._spawn("board_dummy", Vector2i(6, 4))
	big = await c._spawn("board_big", Vector2i(5, 0))
	if enemy != null and ally != null and big != null:
		ally.faction = BaseCombatant.FACTIONS.PARTY
		await _paths_and_undo()
		await _zoc()
		await _displacement()
	else:
		c._check(false, "movement fixtures spawn three real units")
	for unit: BaseCombatant in [enemy, ally, big]:
		if is_instance_valid(unit):
			board.remove(unit)
			unit.queue_free()
	await c.flow.process_frame
	await c.flow.process_frame
	for key: String in saved_rules:
		board.rules.set(key, saved_rules[key])
	for key: String in saved_hero:
		hero.set(key, saved_hero[key])
	board.remove(hero)
	for placement: Array in placements:
		c._check(board.place(placement[0], placement[1]), "movement restores original combat placement")
	board.reset_action_state(hero)
	c.director.refresh_threats()

func _paths_and_undo() -> void:
	board.rules.zone_of_control = CombatRulesData.ZOC_MODES.NONE
	board.rules.move_adjacency = CombatRulesData.MOVE_ADJACENCY.FOUR
	c._arrange([[hero, Vector2i(1, 3)], [ally, Vector2i(2, 3)]])
	var diagonal: Vector2i = Vector2i(2, 2)
	c._check(not board.reachable_cells(hero, 1).has(diagonal), "FOUR cannot reach a diagonal in one point")
	board.rules.move_adjacency = CombatRulesData.MOVE_ADJACENCY.EIGHT
	c._check(board.reachable_cells(hero, 1).has(diagonal) and board.distance(hero.board_anchor, diagonal) == 2, "EIGHT changes path adjacency without changing Manhattan range")
	await _move(diagonal, {"distance": 1})
	c._check(hero.board_anchor == diagonal, "ActionMoveUnit executes the one-step diagonal path")
	board.rules.move_adjacency = CombatRulesData.MOVE_ADJACENCY.FOUR
	c._arrange([[hero, Vector2i(1, 3)]])
	board.rules.move_pass_through_allies = false
	c._check(not board.reachable_cells(hero, 2).has(Vector2i(3, 3)), "ally occupancy blocks the two-step path by default")
	board.rules.move_pass_through_allies = true
	var route: Array[Vector2i] = board.find_path(hero, Vector2i(3, 3), 2)
	c._check(route == [Vector2i(2, 3), Vector2i(3, 3)] and not board.reachable_cells(hero, 2).has(Vector2i(2, 3)), "ally can be crossed but never selected as a landing cell")
	await _move(Vector2i(3, 3), {"distance": 2})
	c._check(hero.board_anchor == Vector2i(3, 3) and board.get_unit_at(Vector2i(2, 3)) == ally, "crossing an ally preserves its occupancy")
	ally.faction = BaseCombatant.FACTIONS.ENEMY
	c._arrange([[hero, Vector2i(1, 3)]])
	c._check(not board.reachable_cells(hero, 2).has(Vector2i(3, 3)), "ally pass flag does not authorize crossing opponents")
	board.rules.move_pass_through_enemies = true
	c._check(board.reachable_cells(hero, 2).has(Vector2i(3, 3)), "opponent pass flag independently enables the path")
	ally.faction = BaseCombatant.FACTIONS.PARTY
	c._arrange([[ally, Vector2i(6, 4)], [hero, Vector2i(1, 3)]])
	board.rules.move_undo_allowed = true
	board.rules.paid_move_max_cells = 2
	board.rules.extra_move_delay_per_cell = 20
	board.reset_action_state(hero)
	hero.move_points = 1
	hero.paid_cells_this_action = 0
	hero.cells_moved_this_action = 0
	hero.action_extra_delay = 0
	await _move(Vector2i(3, 3), {"consumes_move_points": true})
	c._check(hero.move_points == 0 and hero.paid_cells_this_action == 1 and hero.action_extra_delay == 20, "paid movement consumes the actual path budget")
	c._check(board.can_undo_move(hero) and board.undo_move(hero), "enabled undo succeeds before cards or field effects")
	c._check(hero.board_anchor == Vector2i(1, 3) and hero.move_points == 1 and hero.paid_cells_this_action == 0 and hero.action_extra_delay == 0 and hero.cells_moved_this_action == 0, "undo restores anchor, free points, paid allowance, counters and delay")
	await _move(Vector2i(2, 3))
	board.rules.move_undo_allowed = false
	c._check(not board.can_undo_move(hero) and not board.undo_move(hero), "disabled rule rejects undo without changing position")
	board.rules.move_undo_allowed = true
	c._check(await c._play_at("board_card_any", enemy.board_anchor) == "", "real card play completes before undo rejection")
	c._check(not board.can_undo_move(hero) and not board.undo_move(hero), "playing a card invalidates the prior movement snapshot")
	await _move(Vector2i(3, 3))
	c._check(not board.can_undo_move(hero), "movement after a card cannot create a fresh undo allowance")
	board.get_cell(Vector2i(4, 3)).move_cost = 4
	hero.move_points = 0
	hero.paid_cells_this_action = 0
	hero.action_extra_delay = 0
	await _move(Vector2i(4, 3), {"consumes_move_points": true})
	c._check(hero.board_anchor == Vector2i(4, 3) and hero.paid_cells_this_action == 1 and hero.action_extra_delay == 20, "paid movement charges one physical cell even when terrain costs four points")
	c._arrange([[hero, Vector2i(3, 3)]])
	await _move(Vector2i(4, 3), {"distance": 1})
	c._check(hero.board_anchor == Vector2i(4, 3), "card distance one limits physical steps rather than terrain cost")
	board.get_cell(Vector2i(4, 3)).move_cost = 1

func _zoc() -> void:
	board.rules.move_pass_through_enemies = false
	board.rules.zone_of_control = CombatRulesData.ZOC_MODES.EXTRA_MOVE_COST
	board.rules.zoc_extra_move_cost = 2
	c._arrange([[hero, Vector2i(2, 3)], [enemy, Vector2i(2, 2)], [ally, Vector2i(6, 4)]])
	c._check(board.step_cost(hero, hero.board_anchor, Vector2i(1, 3)) == 3, "leaving an adjacent opponent costs base 1 plus ZOC 2")
	c._check(not board.reachable_cells(hero, 2).has(Vector2i(1, 3)) and board.reachable_cells(hero, 3).has(Vector2i(1, 3)), "ZOC cost shrinks the reachable set at the exact budget boundary")
	hero.ignores_zoc = true
	c._check(board.reachable_cells(hero, 1).has(Vector2i(1, 3)), "unit ignores_zoc removes the weighted surcharge")
	hero.ignores_zoc = false
	c._check(board.reachable_cells(hero, 1, null, true).has(Vector2i(1, 3)), "action preview ignore_zoc removes the same surcharge")
	hero.move_points = 3
	hero.paid_cells_this_action = 0
	await _move(Vector2i(1, 3), {"consumes_move_points": true})
	c._check(hero.board_anchor == Vector2i(1, 3) and hero.move_points == 0, "real move spends ZOC-weighted points rather than path length")
	board.rules.zone_of_control = CombatRulesData.ZOC_MODES.OPPORTUNITY_ATTACK
	board.reset_action_state(hero)
	enemy.opportunity_actions.assign([{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 7, "time_delay": 0.0}}])
	c._arrange([[hero, Vector2i(2, 3)]])
	hero.set_block(2)
	var hp: int = hero.get_combatant_health()
	var tick: int = hero.next_action_tick
	var preview: int = board.preview_opportunity_damage(hero, hero.board_anchor)
	c._check(preview == 5 and board.preview_opportunity_damage(hero, hero.board_anchor) == preview and hero.get_block() == 2 and hero.get_combatant_health() == hp, "opportunity preview includes block and repeated calls are pure")
	await _move(Vector2i(1, 3))
	c._check(hp - hero.get_combatant_health() == preview and hero.next_action_tick == tick, "opportunity damage equals preview and adds no timeline delay")
	await _move(Vector2i(2, 3))
	hp = hero.get_combatant_health()
	c._check(board.preview_opportunity_damage(hero, hero.board_anchor) == 0, "spent attacker/mover pair previews no second strike")
	await _move(Vector2i(3, 3))
	c._check(hero.get_combatant_health() == hp, "same controller cannot strike the same mover twice in an action")
	board.reset_action_state(hero)
	c._arrange([[hero, Vector2i(2, 3)]])
	await _move(Vector2i(1, 3), {"ignore_zoc": true})
	c._check(hero.get_combatant_health() == hp, "ActionMoveUnit ignore_zoc suppresses opportunity execution")
	c._arrange([[hero, Vector2i(2, 3)]])
	c._check(board.preview_opportunity_damage(hero, hero.board_anchor) == 7, "ignored movement does not spend the opportunity pair")
	board.rules.zoc_triggers_on_forced_move = false
	await c.run_actions(enemy, [hero], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 1}}])
	c._check(hero.board_anchor == Vector2i(2, 4) and hero.get_combatant_health() == hp, "forced movement is immune to opportunity attacks by default")
	c._arrange([[hero, Vector2i(2, 3)]])
	board.rules.zoc_triggers_on_forced_move = true
	await c.run_actions(enemy, [hero], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 1}}])
	c._check(hp - hero.get_combatant_health() == 7, "explicit forced-move ZOC opt-in executes the pending strike")
	board.reset_action_state(hero)
	c._arrange([[hero, Vector2i(2, 3)]])
	enemy.opportunity_actions.assign([{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 4, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}}])
	hp = hero.get_combatant_health()
	var enemy_hp: int = enemy.get_combatant_health()
	c._check(board.preview_opportunity_damage(hero, hero.board_anchor) == 0, "opportunity action targeting PARENT previews no damage to mover")
	await _move(Vector2i(1, 3))
	c._check(hero.get_combatant_health() == hp and enemy_hp - enemy.get_combatant_health() == 4, "PARENT opportunity damages its owner and never the mover")
	board.reset_action_state(hero)
	ally.faction = BaseCombatant.FACTIONS.ENEMY
	c._arrange([[hero, Vector2i(2, 3)], [enemy, Vector2i(2, 2)], [ally, Vector2i(3, 3)]])
	enemy.opportunity_actions.assign([{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 4}}])
	ally.opportunity_actions.assign([{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 4}}])
	hero.set_block(5)
	hp = hero.get_combatant_health()
	c._check(board.preview_opportunity_damage(hero, hero.board_anchor) == 3, "two controllers share one preview block pool")
	await _move(Vector2i(1, 3))
	c._check(hp - hero.get_combatant_health() == 3 and hero.get_block() == 0, "two real opportunity reactions consume the same block pool once")
	ally.faction = BaseCombatant.FACTIONS.PARTY

func _displacement() -> void:
	board.rules.zone_of_control = CombatRulesData.ZOC_MODES.NONE
	c._arrange([[hero, Vector2i(1, 3)], [enemy, Vector2i(2, 3)], [ally, Vector2i(6, 4)]])
	enemy.displace_resistance = 1
	var active: int = enemy.cells_moved_this_action
	var displaced: int = enemy.cells_displaced_this_action
	await c.run_actions(hero, [enemy], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 3}}])
	c._check(enemy.board_anchor == Vector2i(4, 3) and enemy.cells_displaced_this_action == displaced + 2 and enemy.cells_moved_this_action == active, "resistance reduces push distance and only the displacement counter changes")
	c._arrange([[enemy, Vector2i(2, 3)]])
	await c.run_actions(hero, [enemy], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 1}}])
	c._check(enemy.board_anchor == Vector2i(2, 3), "resistance equal to distance produces a successful no-op")
	await c.run_actions(hero, [enemy], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 1, "ignore_resistance": true}}])
	c._check(enemy.board_anchor == Vector2i(3, 3), "ignore_resistance restores the full displacement")
	enemy.displace_resistance = 0
	c._arrange([[hero, Vector2i(4, 3)], [enemy, Vector2i(6, 3)]])
	var tick: int = enemy.next_action_tick
	var hp: int = enemy.get_combatant_health()
	await c.run_actions(hero, [enemy], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 2, "delay_on_collision": 37, "collision_damage_per_cell": 3}}])
	c._check(enemy.next_action_tick == tick + 37 and hp - enemy.get_combatant_health() == 6 and enemy.board_anchor == Vector2i(6, 3), "edge collision applies damage per remaining cell and adds raw delay ticks once")
	c._arrange([[hero, Vector2i(0, 1)], [enemy, Vector2i(6, 3)], [big, Vector2i(2, 1)]])
	board.rules.displace_max_footprint_area = 1
	await c.run_actions(hero, [big], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 1}}])
	c._check(big.board_anchor == Vector2i(2, 1), "2x2 displacement stays disabled under the conservative default")
	board.rules.displace_max_footprint_area = 4
	await c.run_actions(hero, [big], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 1}}])
	c._check(big.board_anchor == Vector2i(3, 1) and board.get_unit_at(Vector2i(4, 2)) == big and board.get_unit_at(Vector2i(2, 1)) == null, "enabled 2x2 displacement updates all occupied cells atomically")
	board.set_blocked(Vector2i(5, 2), true)
	await c.run_actions(hero, [big], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 1}}])
	c._check(big.board_anchor == Vector2i(3, 1), "blocked trailing footprint cell stops the entire multi-cell unit")
	board.set_blocked(Vector2i(5, 2), false)

func _move(cell: Vector2i, extra: Dictionary = {}) -> void:
	var values: Dictionary = {"target_cell": cell, "mode": "TO_CELL"}
	values.merge(extra, true)
	await c.run_actions(hero, [hero], [{Scripts.ACTION_MOVE_UNIT: values}])
