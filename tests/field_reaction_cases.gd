extends RefCounted
## Reactions use actual fields, status interceptors, ActionHandler and combatant HP/block.
## Arrangement is test setup; the behavior under assertion is never simulated by a callback.

var c
var board: BoardData
var hero: BaseCombatant
var a: BaseCombatant
var b: BaseCombatant
var controller: BaseCombatant

func run(context) -> void:
	c = context
	board = c.board
	hero = c.player
	await c.remove_fields()
	var placements: Array = []
	for unit: BaseCombatant in board.get_units():
		placements.append([unit, unit.board_anchor])
	var rule_keys: Array[String] = ["zone_of_control", "zoc_triggers_on_forced_move", "paid_move_max_cells", "extra_move_delay_per_cell", "move_adjacency", "move_undo_allowed"]
	var saved_rules: Dictionary = {}
	for key: String in rule_keys:
		saved_rules[key] = board.rules.get(key)
	var unit_keys: Array[String] = ["move_points", "paid_cells_this_action", "cells_moved_this_action", "cells_displaced_this_action", "action_extra_delay", "ignores_occupancy", "ignores_zoc"]
	var saved_hero: Dictionary = {}
	for key: String in unit_keys:
		saved_hero[key] = hero.get(key)
	var saved_block: int = hero.get_block()
	board.rules.zone_of_control = CombatRulesData.ZOC_MODES.NONE
	board.rules.move_adjacency = CombatRulesData.MOVE_ADJACENCY.FOUR
	a = await c._spawn("board_dummy", Vector2i(6, 4))
	b = await c._spawn("board_dummy", Vector2i(1, 2))
	controller = await c._spawn("board_dummy", Vector2i(3, 2))
	if c._check(a != null and b != null and controller != null, "reaction fixture spawns living independent owners and movers"):
		await _multi_target_root()
		await _field_opportunity_owner()
		await _redirect_cancels_path()
		await _charge_deduplicates_footprint()
		await _charge_dynamic_blocker()
		await _paid_steps_not_cost_points()
	await c.remove_fields()
	for unit: BaseCombatant in [a, b, controller]:
		if is_instance_valid(unit):
			board.remove(unit)
			unit.queue_free()
	await c.flow.process_frame
	await c.flow.process_frame
	for key: String in rule_keys:
		board.rules.set(key, saved_rules[key])
	for key: String in unit_keys:
		hero.set(key, saved_hero[key])
	hero.set_block(saved_block)
	c._arrange(placements)
	board.reset_action_state(hero)

func _multi_target_root() -> void:
	c._arrange([[hero, Vector2i(2, 4)], [a, Vector2i(6, 4)], [b, Vector2i(1, 2)], [controller, Vector2i(3, 2)]])
	await _field("field_reaction_root", {"field_on_leave_actions": [{Scripts.ACTION_APPLY_STATUS: {
		"target_override": BaseAction.TARGET_OVERRIDES.MEMBER_UID, "member_uid": controller.unit_uid,
		"status_effect_object_id": "status_rooted", "status_charge_amount": 1}}]}, a, [[1, 2]])
	await c.run_actions(hero, [b, controller], [{Scripts.ACTION_MOVE_UNIT: {
		"target_override": BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS,
		"mode": "AWAY", "reference": "PARENT", "distance": 1}}])
	c._check(b.board_anchor == Vector2i(1, 1), "first target completes its real movement before the second dispatch")
	c._check(controller.board_anchor == Vector2i(3, 2), "first mover leave field roots second mover before its interception runs")
	controller.add_status_effect_charges("status_rooted", -99)
	await c.run_actions(hero, [controller], [{Scripts.ACTION_MOVE_UNIT: {
		"target_override": BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS,
		"mode": "AWAY", "reference": "PARENT", "distance": 1}}])
	c._check(controller.board_anchor == Vector2i(3, 1), "removing Root permits the previously blocked second route")
	await c.remove_fields()

func _field_opportunity_owner() -> void:
	c._arrange([[hero, Vector2i(3, 3)], [a, Vector2i(6, 4)], [b, Vector2i(6, 3)], [controller, Vector2i(2, 2)]])
	board.rules.zone_of_control = CombatRulesData.ZOC_MODES.OPPORTUNITY_ATTACK
	board.reset_action_state(hero)
	hero.ignores_zoc = false
	hero.set_block(0)
	a.set_block(0)
	controller.set_block(0)
	a.add_status_effect_charges("status_effect_damage_increase", 11)
	controller.add_status_effect_charges("status_effect_damage_increase", 3)
	controller.opportunity_actions.assign([
		{Scripts.ACTION_BLOCK: {"block": 7, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}},
		{Scripts.ACTION_ATTACK_GENERATOR: {"damage": 2, "number_of_attacks": 1, "time_delay": 0.0, "attack_animation_name": AnimationData.ANIMATION_NONE}}
	])
	await _field("field_reaction_move", {"field_on_enter_actions": [{Scripts.ACTION_MOVE_UNIT: {
		"target_override": BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS,
		"target_cell": [1, 3], "distance": 1}}]}, a, [[2, 3]])
	var hp: int = hero.get_combatant_health()
	var preview: int = board.preview_opportunity_damage(hero, Vector2i(2, 3))
	c._check(preview == 5 and controller.get_block() == 0 and hero.get_combatant_health() == hp, "opportunity preview respects C's strength and PARENT target without side effects")
	await c.move_unit(hero, Vector2i(2, 3))
	c._check(hero.board_anchor == Vector2i(1, 3), "field owned by A moves its entering target out of C's control zone")
	c._check(controller.get_block() == 7 and a.get_block() == 0, "opportunity PARENT resolves C rather than inheriting field owner A")
	c._check(hp - hero.get_combatant_health() == preview, "nested opportunity AttackGenerator uses C's +3 damage rather than A's +11")
	a.add_status_effect_charges("status_effect_damage_increase", -99)
	controller.add_status_effect_charges("status_effect_damage_increase", -99)
	controller.opportunity_actions.clear()
	controller.set_block(0)
	board.rules.zone_of_control = CombatRulesData.ZOC_MODES.NONE
	await c.remove_fields()

func _redirect_cancels_path() -> void:
	c._arrange([[hero, Vector2i(1, 4)], [controller, Vector2i(6, 2)]])
	await _field("field_reaction_redirect", {"field_triggers_on_pass_through": true,
		"field_on_enter_actions": [{Scripts.ACTION_MOVE_UNIT: {
			"target_override": BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS,
			"mode": "TELEPORT", "target_cell": [4, 4]}}]}, a, [[1, 3]])
	var visited: Array[Vector2i] = []
	var observe := func(unit: BaseCombatant, _id: StringName, cell: Vector2i):
		if unit == hero:
			visited.append(cell)
	Signals.unit_entered_cell.connect(observe)
	await c.move_unit(hero, Vector2i(1, 1), {"planned_path": [[1, 3], [1, 2], [1, 1]], "distance": 3})
	Signals.unit_entered_cell.disconnect(observe)
	c._check(hero.board_anchor == Vector2i(4, 4) and not visited.has(Vector2i(1, 2)) and not visited.has(Vector2i(1, 1)), "field teleport invalidates expected anchor so the old path cannot pull the mover back")
	await c.remove_fields()

func _charge_deduplicates_footprint() -> void:
	c._arrange([[hero, Vector2i(0, 1)]])
	var big: BaseCombatant = await c._spawn("board_big", Vector2i(2, 1))
	if not c._check(big != null, "charge fixture spawns a two-cell-wide target on the route"):
		return
	hero.ignores_occupancy = true
	var hp: int = big.get_combatant_health()
	await c.move_unit(hero, Vector2i(4, 1), {"planned_path": [[1, 1], [2, 1], [3, 1], [4, 1]], "distance": 4, "charge": true,
		"path_actions": [{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 3, "bypass_block": true}}]})
	c._check(hero.board_anchor == Vector2i(4, 1) and hp - big.get_combatant_health() == 3, "CHARGE crosses both cells of a 2x2 unit but executes path payload once per uid")
	c._check(board.get_unit_at(Vector2i(2, 1)) == big and board.get_unit_at(Vector2i(3, 1)) == big, "flying CHARGE never overwrites the crossed footprint's occupancy")
	hero.ignores_occupancy = false
	board.remove(big)
	big.queue_free()
	await c.flow.process_frame
	await c.flow.process_frame

func _charge_dynamic_blocker() -> void:
	c._arrange([[hero, Vector2i(0, 3)], [a, Vector2i(4, 3)], [b, Vector2i(6, 3)], [controller, Vector2i(6, 2)]])
	var prior_pass: bool = board.rules.move_pass_through_allies
	var prior_faction: int = b.faction
	board.rules.move_pass_through_allies = true
	b.faction = hero.faction
	hero.ignores_occupancy = false
	await _field("field_reaction_charge_block", {"field_triggers_on_pass_through": true,
		"field_on_enter_actions": [{Scripts.ACTION_MOVE_UNIT: {
			"target_override": BaseAction.TARGET_OVERRIDES.MEMBER_UID, "member_uid": b.unit_uid,
			"mode": "TELEPORT", "target_cell": [2, 3]}}]}, a, [[1, 3]])
	var intent := EnemyIntentData.new()
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.CHARGE
	intent.enemy_intent_move_distance = 3
	intent.enemy_intent_range = 1
	intent.enemy_intent_shape = BoardTargeting.TARGET_SHAPES.SINGLE
	var before: Dictionary = IntentResolver.resolve(board, hero, intent, a)
	c._check(before.move_cell == Vector2i(3, 3) and before.can_hit, "CHARGE initially previews an unobstructed three-step route and adjacent hit")
	var moved_before: int = hero.cells_moved_this_action
	await c.move_unit(hero, Vector2i(3, 3), {"planned_path": before.path, "distance": 3, "charge": true})
	c._check(b.board_anchor == Vector2i(2, 3) and board.can_pass(hero, Vector2i(2, 3)), "intermediate field inserts a living ally that ordinary pass-through rules would permit")
	c._check(hero.board_anchor == Vector2i(1, 3) and hero.cells_moved_this_action == moved_before + 1, "non-flying CHARGE revalidates the next step and stops before the new blocker without counting phantom steps")
	var after: Dictionary = IntentResolver.resolve(board, hero, intent, a)
	c._check(after.path.is_empty() and after.move_cell == hero.board_anchor and not after.can_hit, "fresh CHARGE preview agrees with the blocked position rather than claiming the stale endpoint or hit")
	b.faction = prior_faction
	board.rules.move_pass_through_allies = prior_pass
	await c.remove_fields()

func _paid_steps_not_cost_points() -> void:
	c._arrange([[hero, Vector2i(1, 4)]])
	await c.create_field("field_probe_cost", [[1, 3]], a)
	board.rules.paid_move_max_cells = 1
	board.rules.extra_move_delay_per_cell = 20
	hero.move_points = 0
	hero.paid_cells_this_action = 0
	hero.action_extra_delay = 0
	c._check(board.reachable_active(hero).has(Vector2i(1, 3)), "one paid physical cell admits a terrain step costing four free points")
	await c.move_unit(hero, Vector2i(1, 3), {"consumes_move_points": true})
	c._check(hero.board_anchor == Vector2i(1, 3) and hero.paid_cells_this_action == 1 and hero.action_extra_delay == 20, "expensive terrain charges one physical paid step and one delay increment")
	c._arrange([[hero, Vector2i(1, 4)]])
	board.rules.paid_move_max_cells = 0
	hero.paid_cells_this_action = 0
	hero.action_extra_delay = 0
	await c.move_unit(hero, Vector2i(1, 3), {"distance": 1})
	c._check(hero.board_anchor == Vector2i(1, 3) and hero.paid_cells_this_action == 0 and hero.action_extra_delay == 0, "card distance is a physical-step limit and does not spend terrain movement points")
	await c.remove_fields()

func _field(id: String, properties: Dictionary, owner: BaseCombatant, cells: Array) -> void:
	var data := FieldData.new(id)
	data.set_serializable_properties_from_json_patch({"object_id": id, "properties": properties})
	Global.register_rod(data)
	await c.create_field(id, cells, owner)
