extends RefCounted
## Real controller execution plus pure preview contracts for Phase 2b intent / position rules.

var c
var board: BoardData
var hero: BaseCombatant
var enemy: Enemy
var ally: Enemy
var intent: EnemyIntentData

func run(context) -> void:
	c = context
	board = c.board
	hero = c.player
	var placements: Array = []
	for unit: BaseCombatant in board.get_units():
		placements.append([unit, unit.board_anchor])
		board.remove(unit)
	board.place(hero, Vector2i(2, 2))
	enemy = await c._spawn("board_dummy", Vector2i(3, 2))
	ally = await c._spawn("board_dummy", Vector2i(4, 2))
	if enemy == null or ally == null:
		c._check(false, "intent fixtures spawn")
		return
	await _position()
	await _teleports()
	await _flank_charge_retreat()
	await _listener()
	for unit: BaseCombatant in [enemy, ally]:
		board.remove(unit)
		unit.queue_free()
	await c.flow.process_frame
	await c.flow.process_frame
	for placement: Array in placements:
		board.remove(placement[0])
	for placement: Array in placements:
		c._check(board.place(placement[0], placement[1]), "intent fixtures restore original placement")
	c.director.refresh_threats()

func _position() -> void:
	ally.faction = BaseCombatant.FACTIONS.PARTY
	c._check(BoardPositionQueries.is_flanked(board, hero, enemy), "PINCER: attacker and ally on opposite target sides")
	c._check(BoardPositionQueries.surrounded_count(board, enemy) == 2, "SURROUND counts adjacent opponents once")
	var compute: Script = load(Scripts.ACTION_COMPUTE_BOARD_VALUE)
	var pure: Dictionary = compute.compute_values(board, hero, enemy)
	c._check(pure.size() == 7 and pure.is_flanked == 1 and pure.target_adjacent_opponents == 2 and pure.distance == 1, "all seven computed board keys include flank and target opponent count")
	var hypothetical: Dictionary = compute.compute_values(board, hero, enemy, Vector2i(0, 2))
	c._check(hypothetical.distance == 3 and hypothetical.is_flanked == 0 and hypothetical.target_adjacent_opponents == 1 and hero.board_anchor == Vector2i(2, 2), "hypothetical board values do not mutate occupancy and move the parent's adjacency contribution")
	var request := CardPlayRequest.new()
	request.selected_target = enemy
	var action: BaseAction = compute.new()
	action.init(hero, request, [enemy])
	var queued_actions: Array[BaseAction] = [action]
	c.action_handler.add_actions(queued_actions)
	await c._wait(c._idle, "compute board value action completes")
	c._check(request.card_values == pure, "real ComputeBoardValue action writes the pure preview result")
	var flanked: BaseValidator = load("res://scripts/validators/board/ValidatorFlanked.gd").new()
	var adjacent: BaseValidator = load("res://scripts/validators/board/ValidatorAdjacentUnits.gd").new()
	c._check(flanked.validate(null, action, {}) and flanked.validate(null, action, {"mode": "SURROUND", "comparison_value": 2}), "PINCER and SURROUND validators accept matching positions")
	c._check(not flanked.validate(null, action, {"mode": "SURROUND", "comparison_value": 3}) and adjacent.validate(null, action, {"around": "SELECTED_TARGET", "faction": "OPPONENT", "comparison_value": 2}), "position validators reject threshold 3 and count target's faction correctly")
	ally.faction = BaseCombatant.FACTIONS.NEUTRAL
	c._check(not BoardPositionQueries.is_flanked(board, hero, enemy) and BoardPositionQueries.surrounded_count(board, enemy) == 1, "neutral unit does not provide flank or surround")
	ally.faction = BaseCombatant.FACTIONS.PARTY
	c._arrange([[ally, Vector2i(3, 1)]])
	c._check(not BoardPositionQueries.is_flanked(board, hero, enemy), "perpendicular adjacent ally is not a pincer")
	c._arrange([[ally, Vector2i(6, 4)]])
	ally.faction = BaseCombatant.FACTIONS.ENEMY
	request.selected_target = null
	action = null
	request = null

func _set_intent() -> void:
	intent = EnemyIntentData.new("intent_field_test")
	intent.enemy_intent_attack_damage = 4
	intent.enemy_intent_number_of_attacks = 1
	intent.enemy_intent_range = 1
	intent.enemy_intent_move_distance = 4
	for key: String in enemy.enemy_data.enemy_intents:
		enemy.enemy_data.enemy_intents[key] = intent

func _teleports() -> void:
	_set_intent()
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.TELEPORT
	intent.enemy_intent_move_distance = 0
	c._arrange([[enemy, Vector2i(0, 0)], [hero, Vector2i(3, 2)]])
	var plan: Dictionary = IntentResolver.resolve(board, enemy, intent, hero)
	c._check(plan.move_cell == Vector2i(3, 1) and plan.path.is_empty() and plan.can_hit, "TELEPORT adjacent ignores move range and has no walked path")
	var before: int = hero.get_combatant_health()
	await EnemyIntentController.perform_intent(c.director, enemy)
	c._check(enemy.board_anchor == plan.move_cell and before - hero.get_combatant_health() == 4, "real teleport controller lands at preview and attacks for expected damage")
	intent.enemy_intent_teleport_rule = EnemyIntentData.TELEPORT_RULES.RANDOM_EMPTY
	var first: Dictionary = IntentResolver.resolve(board, enemy, intent, hero)
	var anchor_before: Vector2i = enemy.board_anchor
	var moves_before: int = enemy.cells_moved_this_action
	for index: int in 4:
		c._check(IntentResolver.resolve(board, enemy, intent, hero).move_cell == first.move_cell, "RANDOM_EMPTY repeated preview is stable without consuming RNG")
	c._check(enemy.board_anchor == anchor_before and enemy.cells_moved_this_action == moves_before, "teleport previews do not move or increment action counters")
	enemy.add_status_effect_charges("status_rooted", 1)
	c._check(IntentResolver.resolve(board, enemy, intent, hero).move_cell == enemy.board_anchor, "rooted teleport preview agrees with intercepted movement rejection")
	enemy.add_status_effect_charges("status_rooted", -1)
	intent.enemy_intent_teleport_rule = EnemyIntentData.TELEPORT_RULES.FARTHEST_FROM_OPPONENTS
	var far: Dictionary = IntentResolver.resolve(board, enemy, intent, hero)
	c._check(board.unit_distance(enemy, hero, far.move_cell) == 5, "FARTHEST_FROM_OPPONENTS selects a farthest legal corner")
	intent.enemy_intent_teleport_rule = EnemyIntentData.TELEPORT_RULES.MARKED_CELL
	intent.enemy_intent_marked_cell = Vector2i(1, 1)
	c._check(IntentResolver.resolve(board, enemy, intent, hero).move_cell == Vector2i(1, 1), "MARKED_CELL explicit anchor")
	await c.create_field("field_probe_no_blink", [Vector2i(1, 1)], hero)
	c._check(IntentResolver.resolve(board, enemy, intent, hero).move_cell == enemy.board_anchor, "teleport-blocking field prevents marked landing")
	await c.remove_fields()
	intent.enemy_intent_marked_cell = BaseCombatant.BOARD_ANCHOR_NONE
	intent.enemy_intent_marked_field_tag = "probe"
	await c.create_field("field_probe_enter", [Vector2i(1, 2)], hero)
	c._check(IntentResolver.resolve(board, enemy, intent, hero).move_cell == Vector2i(1, 2), "MARKED_CELL selects tagged field when no explicit cell")
	await c.remove_fields()

func _flank_charge_retreat() -> void:
	c._arrange([[hero, Vector2i(3, 2)], [enemy, Vector2i(0, 2)], [ally, Vector2i(4, 2)]])
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.FLANK
	intent.enemy_intent_move_distance = 4
	var flank: Dictionary = IntentResolver.resolve(board, enemy, intent, hero)
	c._check(flank.move_cell == Vector2i(2, 2), "FLANK prefers opposite side of adjacent allied enemy")
	c._arrange([[enemy, Vector2i(2, 2)], [ally, Vector2i(6, 4)]])
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.RETREAT
	intent.enemy_intent_move_distance = 2
	intent.enemy_intent_move_after = true
	var retreat: Dictionary = IntentResolver.resolve(board, enemy, intent, hero)
	c._check(retreat.can_hit and board.unit_distance(enemy, hero, retreat.move_cell) > 1, "move_after preview attacks from original anchor before retreat")
	var before: int = hero.get_combatant_health()
	await EnemyIntentController.perform_intent(c.director, enemy)
	c._check(before - hero.get_combatant_health() == 4 and enemy.board_anchor == retreat.move_cell, "move_after real attack then movement matches preview")
	intent.enemy_intent_move_after = false
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.CHARGE
	intent.enemy_intent_move_distance = 5
	intent.enemy_intent_path_actions = [{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 3, "bypass_block": true}}]
	enemy.ignores_occupancy = true
	c._arrange([[hero, Vector2i(5, 3)], [enemy, Vector2i(1, 2)], [ally, Vector2i(3, 3)]])
	var charge: Dictionary = IntentResolver.resolve(board, enemy, intent, hero)
	c._check(charge.move_cell == Vector2i(4, 3) and charge.path[0] == Vector2i(1, 3), "CHARGE makes one alignment step then follows a straight path")
	c._check(charge.path_targets == [ally], "CHARGE preview identifies the crossed unit once")
	c.director.refresh_threats()
	var path_damage: float = FieldPreview.preview_actions(intent.enemy_intent_path_actions, enemy, ally, false, false)
	c._check(path_damage == 3.0, "CHARGE payload preview reports the same path damage")
	before = ally.get_combatant_health()
	await EnemyIntentController.perform_intent(c.director, enemy)
	c._check(enemy.board_anchor == charge.move_cell and before - ally.get_combatant_health() == int(path_damage), "CHARGE path_actions hit each crossed unit once via real movement")
	enemy.ignores_occupancy = false

func _listener() -> void:
	var listener: RefCounted = load(get_script().resource_path.get_base_dir().path_join("field_move_listener.gd")).new()
	var card: CardData = c.global_data.get_card_data_from_prototype("board_card_compute")
	c.hand_manager.player_hand.append(card)
	listener.attach(hero, card)
	var from: Vector2i = hero.board_anchor
	await c.move_unit(hero, Vector2i(5, 4), {"distance": 1})
	c._check(listener.moves == 1 and hero.board_anchor != from, "movement listener example observes its owner's actual movement")
	await c.move_unit(enemy, Vector2i(4, 4), {"distance": 1})
	c._check(listener.moves == 1, "movement listener ignores another unit")
	c.hand_manager.player_hand.erase(card)
	await c.move_unit(hero, from, {"distance": 1})
	c._check(listener.moves == 1, "movement listener ignores its card outside the hand")
	listener.detach()
	var reference: WeakRef = weakref(listener)
	listener = null
	c._check(reference.get_ref() == null, "movement listener disconnects and releases cleanly")
