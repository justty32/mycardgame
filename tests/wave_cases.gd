extends RefCounted
## Combat framework Phase 3 cases, loaded at runtime by wave_flow.gd after autoload registration
## (so framework classes resolve). Owns the scenario; wave_flow.gd only reports and exits.
## Hero actions at ticks 0, 1000 and 2000 each kill the current wave's grunt with the strike card.

var flow	# wave_flow.gd: _check(), root, process_frame, create_timer
var root: Window
var counts: Dictionary = {"combat_ended": 0, "player_dead": 0, "death_animations": 0, "played": 0}
var events: Array = []	# ["started"/"cleared"/"ended", wave_index, tick]
var enemy_actions: Array = []	# [object_id, tick, anchor]
var money_at_end: int = -1
var money_start: int = 0
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


func run(scene_tree) -> bool:
	flow = scene_tree
	root = scene_tree.root
	global_data = root.get_node("Global")
	hand_manager = root.get_node("HandManager")
	action_handler = root.get_node("ActionHandler")
	signals = root.get_node("Signals")
	stats = root.get_node("StatsHandler")
	signals.wave_started.connect(func(index): events.append(["started", index, director.current_tick]))
	signals.wave_cleared.connect(func(index): events.append(["cleared", index, director.current_tick]))
	signals.combat_ended.connect(_on_combat_ended)
	signals.player_killed.connect(func(_player): counts.player_dead += 1)
	signals.enemy_death_animation_finished.connect(func(_enemy): counts.death_animations += 1)
	signals.card_played.connect(func(_request): counts.played += 1)
	signals.unit_action_started.connect(_on_unit_action_started)
	return await _scenario()


func free_scene() -> void:
	if is_instance_valid(game_root):
		game_root.queue_free()
		await flow.process_frame
		await flow.process_frame


func _check(condition: bool, label: String) -> bool:
	return flow._check(condition, label)


func _on_combat_ended() -> void:
	counts.combat_ended += 1
	money_at_end = global_data.player_data.player_money
	events.append(["ended", -1, director.current_tick])


func _on_unit_action_started(unit: Node) -> void:
	if unit != player:
		enemy_actions.append([unit.enemy_data.object_id, director.current_tick, unit.board_anchor])


func _scenario() -> bool:
	var fixture: RefCounted = load(flow.get_script().resource_path.get_base_dir().path_join("wave_fixture.gd")).new()
	fixture.install()
	if not await _start_combat():
		return false
	if not await _wave_zero():
		return false
	if not await _wave_one():
		return false
	return await _wave_two()


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
	location.location_event_object_id = "wave_flow_event"
	money_start = global_data.player_data.player_money
	for button: Node in map.location_container.get_children():
		if button.location_data == location:
			button.button_up.emit()
			break
	return await _wait(_player_ready, "map button starts the wave combat and the hero's first action becomes ready")


#region Wave 0 (tick 0): clear, money, the gap between waves
func _wave_zero() -> bool:
	var waves: WaveController = director.waves
	_check(waves != null and waves.get_wave_count() == 3 and waves.current_wave == 0, "encounter has 3 waves; wave 0 started with the combat")
	_check(events == [["started", 0, 0]], "wave_started(0) fired once at tick 0")
	var grunt: Node = director.board.get_unit_at(Vector2i(2, 0))
	_check(grunt != null and grunt.enemy_data.object_id == "wave_grunt" and global_data.get_alive_enemies().size() == 1, "wave 0 grunt stands on (2,0) and is the only enemy")
	_check(combat.get_node("TimelineBar/WaveLabel").visible and combat.get_node("TimelineBar/WaveLabel").text == "Wave 1/3", "WaveLabel shows Wave 1/3")
	if not await _play_at("wave_card_strike", Vector2i(2, 0)):
		return false
	if not await _wait(func(): return counts.death_animations >= 1 and _idle(), "wave 0 grunt dies and its death animation ends"):
		return false
	_check(events.slice(0, 2) == [["started", 0, 0], ["cleared", 0, 0]], "wave_cleared(0) fired at tick 0 after the grunt died")
	_check(global_data.player_data.player_money == money_start + 10, "wave_on_cleared_actions of wave 0 added 10 money")
	_check(counts.combat_ended == 0 and director.is_running, "combat continues after wave 0 (not the last wave)")
	_check(global_data.get_alive_enemies().is_empty() and global_data.are_remaining_enemies() and director.has_remaining_opponents() and not director.is_combat_over(), "between waves: no living enemy, but Global.are_remaining_enemies() asks the director and stays true")
	var pending: Array = director.unit_spawner.pending
	_check(pending.size() == 3 and pending[0]["kind"] == "wave_start" and pending[0]["tick"] == 300 and pending[1]["tick"] == 300 and pending[2]["tick"] == 400, "wave 1 scheduled: start and minion at 0 + 300, grunt at + 100 stagger (400)")
	# a block card between waves is not short-circuited by the empty board
	var block_before: int = player.get_block()
	if not await _play_untargeted("card_block_basic"):
		return false
	_check(player.get_block() > block_before, "Basic Block played between waves still grants its block (%d -> %d)" % [block_before, player.get_block()])
	combat.end_turn_button.button_up.emit()
	return await _wait(func(): return director.current_tick >= 1000 and _player_ready(), "End Turn runs wave 1's entries and returns to the hero at tick 1000")
#endregion


#region Wave 1 (tick 1000): enter ticks, WAIT_UNTIL_FREE, minions do not block the clear
func _wave_one() -> bool:
	_check(director.current_tick == 1000, "hero's second action at tick 1000")
	_check(events.slice(2, 3) == [["started", 1, 300]], "wave_started(1) fired at tick 300 (clear tick 0 + enter delay 300)")
	_check(enemy_actions.size() >= 2 and enemy_actions[0] == ["wave_minion", 300, Vector2i(0, 0)], "the wave 0 grunt died before acting; the wave 1 minion entered on (0,0) and acted first, at tick 300")
	_check(enemy_actions.has(["wave_grunt", 500, Vector2i(1, 0)]) and not _acted_at("wave_grunt", 400) and not _acted_at("wave_grunt", 450), "WAIT_UNTIL_FREE: the grunt for occupied (0,0) waited at 400 and 450, then entered on the nearest cell (1,0) at 500")
	_check(director.unit_spawner.pending.is_empty() and director.unit_spawner.skipped_units.is_empty(), "no wave 1 entry pending or skipped")
	_check(combat.get_node("TimelineBar/WaveLabel").text == "Wave 2/3", "WaveLabel shows Wave 2/3")
	var minion: Node = director.board.get_unit_at(Vector2i(0, 0))
	if not await _play_at("wave_card_strike", Vector2i(1, 0)):
		return false
	if not await _wait(func(): return counts.death_animations >= 2 and _idle(), "wave 1 grunt dies and its death animation ends"):
		return false
	_check(events.slice(3, 4) == [["cleared", 1, 1000]], "wave_cleared(1) fired at tick 1000 with the minion still alive")
	_check(minion != null and minion.is_alive() and minion.enemy_data.enemy_is_minion, "the wave 1 minion stays alive into wave 2")
	_check(global_data.player_data.player_money == money_start + 20 and counts.combat_ended == 0, "wave 1 clear added 10 more money; combat continues")
	combat.end_turn_button.button_up.emit()
	return await _wait(func(): return director.current_tick >= 2000 and _player_ready(), "End Turn runs wave 2's entries and returns to the hero at tick 2000")
#endregion


#region Wave 2 (tick 2000): FAIL_SKIP, last wave clears -> victory with the minion alive
func _wave_two() -> bool:
	_check(events.slice(4, 5) == [["started", 2, 1200]], "wave_started(2) fired at tick 1200 (clear tick 1000 + enter delay 200)")
	var skipped: Array = director.unit_spawner.skipped_units
	_check(skipped.size() == 1 and skipped[0]["cell"] == Vector2i(0, 0) and skipped[0]["tick"] == 1200, "FAIL_SKIP: the grunt for occupied (0,0) was skipped at tick 1200")
	_check(enemy_actions.has(["wave_grunt", 1200, Vector2i(4, 0)]), "wave 2 grunt entered on (4,0) and acted at tick 1200")
	_check(combat.get_node("TimelineBar/WaveLabel").text == "Wave 3/3", "WaveLabel shows Wave 3/3")
	_check(director.waves.current_wave == 2 and not director.waves.is_final_cleared(), "last wave started but not cleared yet")
	if not await _play_at("wave_card_strike", Vector2i(4, 0)):
		return false
	if not await _wait(func(): return counts.combat_ended == 1, "last wave grunt dies and the combat ends"):
		return false
	_check(events.slice(5) == [["cleared", 2, 2000], ["ended", -1, 2000]], "wave_cleared(2) then combat_ended, only after the last wave: " + JSON.stringify(events))
	_check(money_at_end == money_start + 30, "money accumulated per cleared wave: +10 x 3 (%d -> %d)" % [money_start, money_at_end])
	_check(counts.player_dead == 0 and not director.is_running, "victory: hero alive, director stopped")
	await flow.process_frame
	_check(counts.combat_ended == 1, "combat_ended fired exactly once")
	return true
#endregion


#region Helpers
func _acted_at(object_id: String, tick: int) -> bool:
	for entry: Array in enemy_actions:
		if entry[0] == object_id and entry[1] == tick:
			return true
	return false


func _give(card_id: String) -> Node:
	global_data.player_data.player_energy = 50
	var card_data: CardData = global_data.get_card_data_from_prototype(card_id)
	hand_manager.add_cards_to_hand(_cards([card_data]))
	return hand.card_data_to_hand_card.get(card_data)


## Selects a card and clicks a cell; waits for the play to complete.
func _play_at(card_id: String, cell: Vector2i) -> bool:
	var card: Node = _give(card_id)
	if not _check(card != null, "card added to hand: " + card_id):
		return false
	var before: int = counts.played
	card.card_selected.emit(card)
	signals.cell_clicked.emit(cell)
	return await _wait(func(): return counts.played > before and _idle(), "%s played on %s" % [card_id, cell])


func _play_untargeted(card_id: String) -> bool:
	var card: Node = _give(card_id)
	if not _check(card != null, "card added to hand: " + card_id):
		return false
	var before: int = counts.played
	card.card_selected.emit(card)
	return await _wait(func(): return counts.played > before and _idle(), card_id + " played")


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
#endregion
