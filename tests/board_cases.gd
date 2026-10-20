extends RefCounted
## Combat framework Phase 2 cases, loaded at runtime by board_flow.gd after autoload registration
## (so framework classes resolve). Owns the scenario; board_flow.gd only reports and exits.

const HERO_CELL: Vector2i = Vector2i(3, 4)
const PARKING: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)]

var flow	# board_flow.gd: _check(), root, process_frame, create_timer
var root: Window
var counts: Dictionary = {"unit_moved": 0, "played": 0, "combat_ended": 0, "player_dead": 0}
var last_request: CardPlayRequest = null
var global_data: Node
var hand_manager: Node
var action_handler: Node
var signals: Node
var stats: Node
var game_root: Node
var combat: Node
var director: CombatDirector
var hand: Node
var map: Node
var player: Node
var board: BoardData
var target_a: Node	# helper dummies spawned for the cases
var target_b: Node
var target_c: Node


func run(scene_tree) -> bool:
	flow = scene_tree
	root = scene_tree.root
	global_data = root.get_node("Global")
	hand_manager = root.get_node("HandManager")
	action_handler = root.get_node("ActionHandler")
	signals = root.get_node("Signals")
	stats = root.get_node("StatsHandler")
	signals.unit_moved.connect(func(_unit, _from, _to): counts.unit_moved += 1)
	signals.card_played.connect(func(_request): counts.played += 1)
	signals.card_play_started.connect(func(request): last_request = request)
	signals.combat_ended.connect(func(): counts.combat_ended += 1)
	signals.player_killed.connect(func(_player): counts.player_dead += 1)
	return await _scenario()


func free_scene() -> void:
	if is_instance_valid(game_root):
		game_root.queue_free()
		await flow.process_frame
		await flow.process_frame


func _check(condition: bool, label: String) -> bool:
	return flow._check(condition, label)


func _scenario() -> bool:
	var fixture: RefCounted = load(flow.get_script().resource_path.get_base_dir().path_join("board_fixture.gd")).new()
	fixture.install()
	if not await _start_combat():
		return false
	if not await _action_one():
		return false
	if not await _action_two():
		return false
	return await _action_three()


func _start_combat() -> bool:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	game_root = scene.instantiate()
	root.add_child(game_root)
	flow.current_scene = game_root
	await flow.process_frame
	combat = game_root.get_node("RunScreen/Combat")
	director = combat.get_node("CombatDirector")
	hand = combat.get_node("Hand")
	map = game_root.get_node("RunScreen/Map")
	player = combat.get_node("Player")
	_check(combat.board_view == null and combat.board_views.is_empty(), "board presentation is unallocated outside combat")
	game_root.get_node("TitleScreen/MainMenu/VBoxContainer/NewRunButton").button_up.emit()
	var menu: Node = game_root.get_node("TitleScreen/NewRunMenu")
	menu._on_character_selected("character_red")
	menu.seed_input.text = "20261019"
	menu.start_run_button.pressed.emit()
	if not await _wait(func(): return global_data.is_run, "Start Run button creates a real run"):
		return false
	var options: Node = game_root.get_node("RunScreen/RunStartOptions")
	var option: Node = options.starting_option_container.get_child(0)
	option.dialogue_option_clicked.emit(option)
	if not await _wait(func(): return map.is_visible_in_tree() and map.can_travel, "start-option handler opens the travel map"):
		return false
	var location: Resource
	for candidate: Resource in global_data.get_next_locations():
		if candidate.location_type == 1:	# LOCATION_TYPES.COMBAT
			location = candidate
			break
	if not _check(location != null, "generated map contains an adjacent combat destination"):
		return false
	location.location_event_object_id = "board_flow_event"
	for button: Node in map.location_container.get_children():
		if button.location_data == location:
			button.button_up.emit()
			break
	if not await _wait(_player_ready, "map button starts the board combat and the hero's first action becomes ready"):
		return false
	board = director.board
	return _check(board != null, "director built a board for the encounter")


#region Hero action 1 (tick 0): movement, targeting, shapes, displacement, validators
func _action_one() -> bool:
	var dummy: Node = board.get_unit_at(Vector2i(0, 0))
	var big: Node = board.get_unit_at(Vector2i(5, 0))
	_check(board.size == Vector2i(7, 5) and player.board_anchor == HERO_CELL, "7x5 encounter board; hero on its deploy cell (3,4)")
	_check(dummy != null and dummy.enemy_data.object_id == "board_dummy" and big != null and big.enemy_data.object_id == "board_big", "wave 0 units stand on their encounter cells")
	var big_cells: bool = true
	for cell: Vector2i in [Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1), Vector2i(6, 1)]:
		big_cells = big_cells and board.get_unit_at(cell) == big
	_check(big_cells and board.get_unit_cells(big).size() == 4, "2x2 enemy occupies 4 cells")
	_check(is_instance_valid(combat.board_view) and combat.board_view.is_inside_tree() and combat.board_view.visible, "BoardView is visible during combat")

	# 1. free move point, click a cell at distance 1
	_check(player.move_points == 1, "move 1: hero starts its action with move_points 1 (rules.free_move_per_action)")
	var moved_before: int = counts.unit_moved
	signals.cell_clicked.emit(Vector2i(3, 3))
	await _wait(_idle, "move click completes")
	_check(counts.unit_moved == moved_before + 1 and player.board_anchor == Vector2i(3, 3), "move 1: clicking an empty cell at distance 1 emits unit_moved once")
	_check(player.move_points == 0 and player.cells_moved_this_action == 1, "move 1: move_points 0 and cells_moved_this_action 1 after the move")
	_check(board.unit_distance(player, dummy) == 6, "base: distance after moving one cell is correct (Manhattan 3 + 3)")
	# 2. paid move of two cells
	signals.cell_clicked.emit(Vector2i(3, 1))
	await _wait(_idle, "paid move click completes")
	_check(player.board_anchor == Vector2i(3, 1) and player.paid_cells_this_action == 2 and player.action_extra_delay == 40, "move 2: paid move of 2 cells adds action_extra_delay 40")
	signals.cell_clicked.emit(Vector2i(3, 0))
	await _wait(_idle, "move beyond the budget is ignored")
	_check(player.board_anchor == Vector2i(3, 1), "move 2: no budget left, a further click does not move")

	target_a = await _spawn("board_dummy", PARKING[0])
	target_b = await _spawn("board_dummy", PARKING[1])
	target_c = await _spawn("board_dummy", PARKING[2])
	if not _check(target_a != null and target_b != null and target_c != null, "helper dummies spawned on parking cells"):
		return false

	# base: range, CROSS, LINE / LINE_PIERCE, 2x2 selection
	_arrange([[player, HERO_CELL], [target_a, Vector2i(3, 2)]])
	_check(await _play_at("board_card_reach1", Vector2i(3, 2)) == BoardTargeting.REJECT_OUT_OF_RANGE, "base: card_range 1 rejects a target at distance 2")
	_arrange([[target_b, Vector2i(2, 2)], [target_c, Vector2i(4, 2)]])
	var hp: Array = _hp([target_a, target_b, target_c])
	_check(await _play_at("board_card_cross", Vector2i(3, 2)) == "" and last_request.resolved_targets.size() == 3, "base: CROSS shape resolves 3 units")
	_check(_hp_delta([target_a, target_b, target_c], hp) == [2, 2, 2], "base: CROSS hits all three for 2")
	_arrange([[target_b, Vector2i(3, 0)], [target_c, PARKING[2]]])
	var line_targets: Array[BaseCombatant] = BoardTargeting.resolve_targets(board, player, Vector2i(3, 2), BoardTargeting.TARGET_SHAPES.LINE, BoardTargeting.TARGET_FACTIONS.OPPONENT)
	_check(line_targets.size() == 1 and line_targets[0] == target_a, "base: LINE stops at the first unit")
	hp = _hp([target_a, target_b])
	_check(await _play_at("board_card_pierce", Vector2i(3, 2)) == "" and _hp_delta([target_a, target_b], hp) == [2, 2], "base: LINE_PIERCE passes through and hits both units in the column")
	hp = _hp([big])
	_check(await _play_at("board_card_any", Vector2i(6, 1)) == "" and last_request.selected_target == big and _hp_delta([big], hp) == [1], "base: any cell of the 2x2 enemy selects it")

	# 12. ValidatorDistance in play validators; ActionComputeBoardValue
	_arrange([[target_b, PARKING[1]], [target_a, Vector2i(3, 2)]])
	var far_card: Node = _give("board_card_far_only")
	_check(not far_card.can_play_card(null, false) and not far_card._glow_validation(), "validator 12: ValidatorDistance >= 3 to the nearest opponent at distance 2 makes the card unplayable and unlit")
	hand_manager.discard_cards(_cards([far_card.card_data]), false)
	_check(await _play_at("board_card_compute", Vector2i(3, 2)) == "" and last_request.card_values.get("distance", -1) == board.unit_distance(player, target_a) and board.unit_distance(player, target_a) == 2, "value 12: ActionComputeBoardValue writes card_values.distance = BoardData distance (2)")

	# 4. dash strike
	_arrange([[target_a, Vector2i(3, 1)]])
	hp = _hp([target_a])
	_check(await _play_at("card_test_dash_strike", Vector2i(3, 1)) == "" and player.board_anchor == Vector2i(3, 2) and _hp_delta([target_a], hp) == [6], "dash 4: target in the column at distance 3 -> hero stops adjacent and deals 6")
	_arrange([[player, HERO_CELL], [target_a, PARKING[0]], [target_c, Vector2i(4, 2)]])
	_check(await _play_at("card_test_dash_strike", Vector2i(4, 2)) == BoardTargeting.REJECT_VALIDATORS, "dash 4: ValidatorInLine rejects a target off the hero's row and column")

	# 5. shove: push, wall collision, unit collision
	_arrange([[target_c, PARKING[2]], [target_a, Vector2i(3, 3)]])
	hp = _hp([target_a])
	_check(await _play_at("card_test_shove", Vector2i(3, 3)) == "" and target_a.board_anchor == Vector2i(3, 1), "push 5: enemy at (3,3) pushed north 2 to (3,1)")
	_check(last_request.card_values.get("displaced_cells") == 2 and last_request.card_values.get("collided") == false and _hp_delta([target_a], hp) == [4], "push 5: displaced_cells 2, no collision, only the 4 attack damage")
	_arrange([[player, Vector2i(3, 1)], [target_a, Vector2i(3, 0)]])
	hp = _hp([target_a])
	_check(await _play_at("card_test_shove", Vector2i(3, 0)) == "" and target_a.board_anchor == Vector2i(3, 0) and last_request.card_values.get("collided") == true, "push 5: enemy against the board edge does not move and collides")
	_check(_hp_delta([target_a], hp) == [4 + 3 * 2], "push 5: collision damage 3 x 2 remaining cells on top of the attack")
	_arrange([[player, Vector2i(3, 3)], [target_a, Vector2i(3, 2)], [target_b, Vector2i(3, 1)]])
	hp = _hp([target_a, target_b])
	_check(await _play_at("board_card_shove_wall", Vector2i(3, 2)) == "" and target_a.board_anchor == Vector2i(3, 2) and _hp_delta([target_a, target_b], hp) == [3, 3], "push 5: blocked by a unit -> 0 cells, both take 3 (collision_damage_to_blocker variant)")

	# 6. multi-cell and immovable units, rooted hero
	_arrange([[player, Vector2i(4, 2)], [target_b, PARKING[1]]])
	await _run_actions(player, [big], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": ActionDisplaceUnit.MODE_PUSH, "distance": 2}}])
	_check(big.board_anchor == Vector2i(5, 0), "displace 6: 2x2 enemy is not displaced (displace_max_footprint_area 1)")
	_arrange([[player, HERO_CELL], [target_a, Vector2i(3, 3)]])
	target_a.is_immovable = true
	await _run_actions(player, [target_a], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": ActionDisplaceUnit.MODE_PUSH, "distance": 2}}])
	_check(target_a.board_anchor == Vector2i(3, 3), "displace 6: is_immovable enemy is not displaced")
	target_a.is_immovable = false
	player.add_status_effect_charges("status_rooted", 1)
	_check(await _play_at("card_test_blink", Vector2i(3, 1)) == "not_playable", "rooted 6: status_rooted hero's card_test_blink is rejected by its validators (ValidatorPathExists: cannot move)")
	player.add_status_effect_charges("status_rooted", -1)

	# 7. swap with a neutral unit, pull adjacent
	_arrange([[target_a, PARKING[0]], [target_c, Vector2i(3, 3)]])
	target_c.faction = BaseCombatant.FACTIONS.NEUTRAL
	var moved: int = counts.unit_moved
	_check(await _play_at("board_card_swap", Vector2i(3, 3)) == "" and player.board_anchor == Vector2i(3, 3) and target_c.board_anchor == HERO_CELL and counts.unit_moved == moved + 2, "swap 7: SWAP with the neutral unit exchanges anchors and emits unit_moved twice")
	target_c.faction = BaseCombatant.FACTIONS.ENEMY
	_arrange([[player, HERO_CELL], [target_c, PARKING[2]], [target_a, Vector2i(3, 0)]])
	_check(await _play_at("board_card_pull", Vector2i(3, 0)) == "" and target_a.board_anchor == Vector2i(3, 3), "pull 7: PULL_ADJACENT pulls the enemy at (3,0) to (3,3)")

	# 8. blink
	_check(await _play_at("card_test_blink", Vector2i(3, 3)) == BoardTargeting.REJECT_CELL_NOT_FREE, "blink 8: an occupied cell is rejected")
	_arrange([[target_a, PARKING[0]]])
	_check(await _play_at("card_test_blink", Vector2i(3, 0)) == BoardTargeting.REJECT_OUT_OF_RANGE, "blink 8: an empty cell at distance 4 is rejected by card_range 3")
	moved = counts.unit_moved
	_check(await _play_at("card_test_blink", Vector2i(3, 1)) == "" and player.board_anchor == Vector2i(3, 1) and counts.unit_moved == moved + 1, "blink 8: an empty cell at distance 3 teleports the hero")

	# 11. summon on an occupied cell -> nearest empty cell
	_arrange([[player, HERO_CELL], [target_a, Vector2i(3, 2)]])
	var units_before: Array = global_data.get_alive_enemies()
	await _run_actions(dummy, [], [{Scripts.ACTION_SUMMON_ENEMIES: {"random_enemy_object_ids": ["board_dummy"], "spawn_cells": [[3, 2]], "number_of_spawns": 1}}])
	await flow.process_frame
	var summoned: Node = null
	for enemy: Node in global_data.get_alive_enemies():
		if not units_before.has(enemy):
			summoned = enemy
	_check(summoned != null and summoned.board_anchor == Vector2i(3, 1) and director.timeline.has(summoned), "summon 11: occupied spawn cell (3,2) -> nearest empty cell (3,1) (distance 1, smaller y), unit enters the timeline")
	if summoned != null:
		summoned.queue_free()
		await flow.process_frame

	# 3. blocked cells and detours
	_arrange([[target_a, PARKING[0]]])
	for cell: Vector2i in [Vector2i(3, 2), Vector2i(2, 3), Vector2i(4, 3)]:
		board.set_blocked(cell, true)
	var reachable: Dictionary = board.reachable_cells(player, 3)
	_check(not reachable.has(Vector2i(3, 2)) and not reachable.has(Vector2i(3, 1)) and reachable.has(Vector2i(3, 3)), "obstacles 3: blocked (3,2),(2,3),(4,3) -> reachable cells exclude (3,2) and the cell behind it")
	for cell: Vector2i in [Vector2i(3, 2), Vector2i(2, 3), Vector2i(4, 3)]:
		board.set_blocked(cell, false)
	_arrange([[target_a, Vector2i(3, 3)]])
	var detour: Array[Vector2i] = board.find_path(player, Vector2i(3, 2))
	_check(detour.size() >= 3 and not detour.has(Vector2i(3, 3)), "obstacles 3: an enemy at (3,3) makes find_path to (3,2) detour (length %d)" % detour.size())

	# 9-10 setup: archer KEEP_RANGE 3 at distance 2; preview before the hero's action ends
	_arrange([[target_a, PARKING[0]]])
	var archer: Node = await _spawn("enemy_test_archer", Vector2i(3, 2))
	if not _check(archer != null, "archer spawned at distance 2"):
		return false
	director.refresh_threats()
	_check(archer.planned_move_cell == Vector2i(3, 1) and board.unit_distance(player, archer, Vector2i(-1, -1)) == 2, "keep range 9: archer at distance 2 plans to step back to (3,1)")
	_check(board.footprint_distance_to_cell(archer.planned_move_cell, Vector2i(1, 1), HERO_CELL) == 3 and archer.intent_can_hit, "keep range 9: planned cell is at distance 3 and in range")
	var preview: int = director.threat_preview.incoming_damage_for(player)
	_check(preview == 3, "threat 10: ThreatPreview expects the archer's 3 damage before the hero's next action")
	set_meta("archer", archer)
	set_meta("archer_preview", preview)
	set_meta("archer_plan", archer.planned_move_cell)
	set_meta("hp_before", player.get_combatant_health())
	_check(player.get_block() == 0, "hero has no block before ending action 1")
	combat.end_turn_button.button_up.emit()
	return await _wait(func(): return director.current_tick > 0 and _player_ready(), "End Turn runs the timeline to the hero's next action")
#endregion


#region Hero action 2: paid delay, archer result, charger / approacher setup
func _action_two() -> bool:
	var timeline: CombatTimeline = director.timeline
	_check(director.current_tick == timeline.wait_for(140, 10) and director.current_tick == timeline.wait_for(100, 10) + 400, "move 2: paid cells add 40 to the 100 card delay -> next action at tick 1400 (400 ticks later)")
	_check(player.action_extra_delay == 0 and player.move_points == 1 and player.paid_cells_this_action == 0, "move 1: the next action resets move points and the paid delay")
	var archer: Node = get_meta("archer")
	_check(archer.board_anchor == get_meta("archer_plan") and board.unit_distance(player, archer) == 3, "keep range 9: archer acted from its planned cell at distance 3")
	var damage: int = int(get_meta("hp_before")) - player.get_combatant_health()
	_check(damage == 3 and damage == int(get_meta("archer_preview")), "threat 10: actual damage (%d) equals the ThreatPreview value" % damage)
	archer.queue_free()
	await flow.process_frame

	# 9. charger off-line falls back to APPROACH; in line it charges
	var charger: Node = await _spawn("enemy_test_charger", Vector2i(1, 0))
	if not _check(charger != null, "charger spawned"):
		return false
	var intent: EnemyIntentData = charger.enemy_data.get_current_intent()
	var approach: EnemyIntentData = intent.duplicate()
	approach.enemy_intent_move = EnemyIntentData.MOVE_MODES.APPROACH
	var charge_plan: Dictionary = IntentResolver.resolve(board, charger, intent, player)
	var approach_plan: Dictionary = IntentResolver.resolve(board, charger, approach, player)
	_check(charge_plan["move_cell"] == approach_plan["move_cell"] and charge_plan["move_cell"] != charger.board_anchor, "charge 9: off the hero's row and column CHARGE falls back to APPROACH")
	_arrange([[charger, Vector2i(3, 0)]])
	var approacher: Node = await _spawn("board_approacher", Vector2i(0, 4))
	if not _check(approacher != null, "approacher spawned"):
		return false
	director.refresh_threats()
	_check(charger.planned_move_cell == Vector2i(3, 3) and approacher.planned_move_cell == Vector2i(2, 4), "charge / approach: planned cells are adjacent to the hero")
	var preview: int = director.threat_preview.incoming_damage_for(player)
	_check(preview == 4 + 5, "threat 10: preview sums the charger (4) and approacher (5) from their planned cells")
	set_meta("charger", charger)
	set_meta("approacher", approacher)
	set_meta("move_preview", preview)
	set_meta("hp_before", player.get_combatant_health())
	combat.end_turn_button.button_up.emit()
	return await _wait(func(): return director.current_tick >= 2400 and _player_ready(), "End Turn runs the charger and approacher to the hero's third action")


func _action_three() -> bool:
	var charger: Node = get_meta("charger")
	var approacher: Node = get_meta("approacher")
	_check(charger.board_anchor == Vector2i(3, 3) and board.unit_distance(player, charger) == 1, "charge 9: charger in the hero's column at distance 4 (move 3) ends adjacent")
	_check(approacher.board_anchor == Vector2i(2, 4) and board.unit_distance(player, approacher) == 1, "approach: APPROACH enemy moved adjacent before attacking")
	var damage: int = int(get_meta("hp_before")) - player.get_combatant_health()
	_check(damage == 9 and damage == int(get_meta("move_preview")), "threat 10: damage after CHARGE / APPROACH movement (%d) equals the preview" % damage)
	_check(counts.combat_ended == 0 and counts.player_dead == 0, "combat is still running with the hero alive")
	return true
#endregion


#region Helpers
## Test-only placement: removes the listed units from the board, then places each at its cell.
func _arrange(placements: Array) -> void:
	for placement: Array in placements:
		board.remove(placement[0])
	for placement: Array in placements:
		if not board.place(placement[0], placement[1]):
			_check(false, "test placement of %s at %s" % [placement[0].get_unit_display_name(), placement[1]])
	director.refresh_threats()


func _spawn(enemy_id: String, cell: Vector2i) -> Node:
	var enemy: Node = director.spawn_enemy_at_cell(enemy_id, cell)
	await flow.process_frame
	await flow.process_frame
	return enemy


func _give(card_id: String) -> Node:
	global_data.player_data.player_energy = 50
	var card_data: CardData = global_data.get_card_data_from_prototype(card_id)
	hand_manager.add_cards_to_hand(_cards([card_data]))
	return hand.card_data_to_hand_card.get(card_data)


## Selects a card and clicks a cell. Returns "" when the card was played (waits for it), else the
## rejection reason (the card is then discarded to keep the hand small).
func _play_at(card_id: String, cell: Vector2i) -> String:
	var card: Node = _give(card_id)
	if card == null:
		_check(false, "card added to hand: " + card_id)
		return "missing"
	var before: int = counts.played
	var playable: bool = card.can_play_card(null, false)
	card.card_selected.emit(card)
	if hand.current_selected_card != card:
		hand_manager.discard_cards(_cards([card.card_data]), false)
		await _wait(_idle, "unplayable card leaves the queue idle")
		return "not_playable" if not playable else "not_selected"
	signals.cell_clicked.emit(cell)
	if hand.current_selected_card == card:
		var reason: String = hand.last_target_rejection
		hand._on_background_button_up()
		hand_manager.discard_cards(_cards([card.card_data]), false)
		await _wait(_idle, "rejected card leaves the queue idle")
		return reason
	if not await _wait(func(): return counts.played > before and _idle(), "card play completes: " + card_id):
		return "timeout"
	return ""


func _run_actions(parent: Node, targets: Array, actions_data: Array[Dictionary]) -> void:
	var typed_targets: Array[BaseCombatant] = []
	typed_targets.assign(targets)
	action_handler.add_actions(root.get_node("ActionGenerator").create_actions(parent, null, typed_targets, actions_data, null))
	await _wait(_idle, "board actions complete")


func _hp(units: Array) -> Array:
	var values: Array = []
	for unit: Node in units:
		values.append(unit.get_combatant_health())
	return values


func _hp_delta(units: Array, before: Array) -> Array:
	var values: Array = []
	for index: int in units.size():
		values.append(before[index] - units[index].get_combatant_health())
	return values


func _idle() -> bool:
	return not action_handler.actions_being_performed and not hand_manager.cards_being_played and hand_manager.card_play_queue.is_empty()


func _player_ready() -> bool:
	return global_data.is_player_in_combat() and stats.is_player_turn and director.is_player_action_pending() and not hand.hand_disabled and _idle()


func _wait(predicate: Callable, label: String, seconds: float = 15.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline:
			return _check(false, label + " (timeout)")
		await flow.create_timer(0.02).timeout
	return _check(true, label)


func _cards(list: Array) -> Array[CardData]:
	var typed: Array[CardData] = []
	typed.assign(list)
	return typed
