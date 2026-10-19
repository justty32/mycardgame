extends SceneTree
## Combat framework Phase 1: action timeline (CTB) with a single hero.
## Run ONLY with --path pointing to an isolated copy (tools/test_game.py --suite Ctb).
## Drives the real Root scene, New Run menu, map and End Turn button; asserts the action order
## and ticks of the first 8 actions, clock signals, EVERY_N_TICKS status processing, block reset
## at action start and turn_count = hero action count. Mouse hit-testing is not covered.

const EXPECTED_ORDER: Array = [["fast", 0], ["hero", 0], ["slow", 0], ["fast", 500], ["fast", 1000], ["hero", 1000], ["fast", 1500], ["fast", 2000]]

var checks: int = 0
var failures: int = 0
var finished: bool = false
var results: Array[Dictionary] = []
var action_log: Array = []	# [name, tick] per unit_action_started
var ended_log: Array = []
var tick_advances: Array = []
var hero_block_at_action_start: Array = []
var hero_block_before_reset: Array = []
var player_turn_flags: Array = []	# is_player_turn seen at each unit_action_started
var counts: Dictionary = {"enemy_turn_started": 0, "enemy_turn_ended": 0, "player_turn_started": 0, "player_turn_ended": 0, "timeline_changed": 0, "combat_started": 0, "combat_ended": 0, "player_dead": 0}
var global_data: Node
var hand_manager: Node
var action_handler: Node
var signals: Node
var stats: Node
var game_root: Node
var combat: Node
var director: Node
var hand: Node
var map: Node
var player: Node
var output_directory: String


func _initialize() -> void:
	call_deferred("_main")


func _main() -> void:
	create_timer(100.0).timeout.connect(_timeout)
	output_directory = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/").get_base_dir()
	if not _check(output_directory.replace("\\", "/").contains("/artifacts/"), "project is in an isolated artifacts copy"):
		_finish()
		return
	global_data = root.get_node("Global")
	hand_manager = root.get_node("HandManager")
	action_handler = root.get_node("ActionHandler")
	signals = root.get_node("Signals")
	stats = root.get_node("StatsHandler")
	_connect_observers()
	print("BOUNDARY: one combat on the action timeline with declared data fixtures; UI handler/signals, not mouse coordinates; the combat is left unfinished and the scene freed.")
	var completed: bool = await _scenario()
	_check(completed, "complete ctb scenario returned")
	if is_instance_valid(game_root):
		game_root.queue_free()
		await process_frame
		await process_frame
	_check(global_data.get_combat_director() == null, "freed run screen leaves no combat director behind")
	_finish()


func _scenario() -> bool:
	var fixture: RefCounted = load(get_script().resource_path.get_base_dir().path_join("ctb_fixture.gd")).new()
	fixture.install()
	var rules: Resource = global_data.get_combat_rules()
	if not _check(rules.timeline_delay_scale == 100 and rules.default_action_delay == 100 and rules.tie_break == 0, "default rules: delay 100, scale 100, higher speed first"):
		return false
	_check(hand_manager.get_hand_limit() == rules.hand_limit and rules.hand_limit == 10, "hand limit is read from the combat rules (10)")
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	game_root = scene.instantiate()
	root.add_child(game_root)
	current_scene = game_root
	await process_frame
	combat = game_root.get_node("RunScreen/Combat")
	director = combat.get_node("CombatDirector")
	hand = combat.get_node("Hand")
	map = game_root.get_node("RunScreen/Map")
	player = combat.get_node("Player")
	_check(global_data.get_combat_director() == director and not director.is_running, "Combat owns an idle CombatDirector before any run")
	_check(combat.get_node("TimelineBar") != null and not combat.get_node("TimelineBar").visible, "TimelineBar exists and is hidden outside combat")
	var new_run_button: Button = game_root.get_node("TitleScreen/MainMenu/VBoxContainer/NewRunButton")
	if not _check(new_run_button.is_visible_in_tree(), "fresh main menu offers New Run"):
		return false
	new_run_button.button_up.emit()
	var menu: Node = game_root.get_node("TitleScreen/NewRunMenu")
	menu._on_character_selected("character_red")
	menu.seed_input.text = "20261019"
	menu.start_run_button.pressed.emit()
	if not await _wait(func(): return global_data.is_run, "Start Run button creates a real run"):
		return false
	_check(player.speed == 10 and player.base_speed == 10, "hero speed comes from character_speed")
	var options: Node = game_root.get_node("RunScreen/RunStartOptions")
	if not _check(options.is_visible_in_tree() and options.starting_option_container.get_child_count() == 1, "start-option UI displays the declared no-bonus fixture"):
		return false
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
	location.location_event_object_id = "ctb_flow_event"
	var location_button: Node
	for button: Node in map.location_container.get_children():
		if button.location_data == location:
			location_button = button
			break
	if not _check(location_button != null, "generated combat location has its actual map button"):
		return false
	location_button.button_up.emit()
	if not await _wait(_player_ready, "map button starts combat and the hero's first action becomes ready"):
		return false
	_check(counts.combat_started == 1 and director.is_running, "combat started once and the director runs")
	var enemies: Array = global_data.get_alive_enemies()
	if not _check(enemies.size() == 2, "event spawns the two fixture enemies"):
		return false
	var fast: Node = _enemy("ctb_enemy_fast")
	var slow: Node = _enemy("ctb_enemy_slow")
	_check(fast != null and fast.speed == 20 and slow != null and slow.speed == 5, "enemy speeds come from enemy_speed (20 and 5)")
	_check(fast.enemy_data.get_current_intent().object_id == "intent_guard" and slow.enemy_data.get_current_intent().object_id == "intent_poke", "enemies decided their first intent at combat start")
	_check(player.get_status_charges("ctb_status_tick") == 10, "event initial action applied the 500-tick status with 10 charges before the first action")
	_check(action_log == [["fast", 0], ["hero", 0]], "fast enemy (speed 20) acts before the hero at tick 0, hero second")
	_check(ended_log == [["fast", 0]], "fast enemy's action ended before the hero's began")
	_check(hand_manager.player_hand.size() == 5 and global_data.player_data.player_energy == 3, "hero action one draws 5 and has 3 energy under the default rules")
	_check(stats.get_turn_count() == 1 and player.action_count == 1 and stats.unit_action_counts.get(player.unit_uid, 0) == 1, "turn count 1 on the hero's first action")
	_check(combat.get_node("TimelineBar").visible and combat.get_node("TimelineBar/Entries").get_child_count() > 0, "TimelineBar is visible in combat and lists projected actions")
	_check(combat.get_node("TurnOverlay/TurnLabel").text == "Tick 0 - Action 1", "TurnOverlay shows the tick and hero action number")
	_check(not combat.end_turn_button.disabled, "End Turn button is enabled during the hero's action")
	var projection: Array = director.project_timeline(8)
	_check(projection.size() == 8 and projection[0]["unit"] == player and projection[0]["tick"] == 0 and projection[1]["unit"] == slow and projection[1]["tick"] == 0 and projection[2]["unit"] == fast and projection[2]["tick"] == 500, "timeline projection: hero (acting), slow@0, fast@500")

	# hero action 1: gain block, then end the action
	if not await _play_block():
		return false
	_check(player.get_block() == 10, "native Block grants ten block during the hero's action")
	combat.end_turn_button.button_up.emit()
	_check(combat.end_turn_button.disabled, "End Turn request disables the button")
	if not await _wait(func(): return action_log.size() >= 6 and _player_ready(), "timeline runs slow@0, fast@500, fast@1000 and returns to the hero at tick 1000"):
		return false
	_check(action_log == EXPECTED_ORDER.slice(0, 6), "first six actions follow speed order and ticks: " + JSON.stringify(action_log))
	_check(tick_advances == [[0, 500], [500, 1000]], "combat_tick_advanced reports strictly increasing ticks 0->500->1000")
	_check(director.current_tick == 1000 and stats.combat_tick == 1000, "director and StatsHandler agree on tick 1000")
	_check(hero_block_before_reset == [0, 9], "slow enemy's 1 damage left 9 block before the hero's second action")
	_check(hero_block_at_action_start == [0, 0], "block is cleared at the start of each hero action (rules.reset_block_on_action_start)")
	_check(stats.get_turn_count() == 2 and player.action_count == 2, "turn count equals the hero action count (2), not the enemy actions")
	_check(stats.unit_action_counts.get(fast.unit_uid, 0) == 3 and stats.unit_action_counts.get(slow.unit_uid, 0) == 1, "per-unit action counts: fast 3, slow 1")
	_check(player.get_status_charges("ctb_status_tick") == 8, "EVERY_N_TICKS status processed twice by tick 1000 (10 -> 8 charges)")
	_check(global_data.player_data.player_energy == 3 and hand_manager.player_hand.size() == 5, "second hero action refills energy and redraws five cards")
	_check(player.get_combatant_health() == 80, "block absorbed the slow enemy's poke")
	_check(fast.get_block() == 1, "fast enemy's guard intent gives it block on its own action")
	_check(combat.get_node("TurnOverlay/TurnLabel").text == "Tick 1000 - Action 2", "TurnOverlay shows tick 1000 and action 2")

	# hero action 2: end immediately
	combat.end_turn_button.button_up.emit()
	if not await _wait(func(): return action_log.size() >= 8, "timeline continues with fast@1500 and fast@2000"):
		return false
	_check(action_log.slice(0, 8) == EXPECTED_ORDER, "first eight actions match the expected CTB order: " + JSON.stringify(action_log.slice(0, 8)))
	_check(tick_advances.slice(0, 4) == [[0, 500], [500, 1000], [1000, 1500], [1500, 2000]], "clock advanced through 1500 and 2000")
	_check(player.get_status_charges("ctb_status_tick") == 6, "EVERY_N_TICKS status processed four times by tick 2000 (10 -> 6 charges)")
	_check(player_turn_flags.slice(0, 8) == [false, true, false, false, false, true, false, false], "is_player_turn is true only during hero actions")
	_check(counts.player_turn_started == 2 and counts.player_turn_ended == 2, "legacy player_turn_* fired once per hero action")
	_check(counts.enemy_turn_started == 6 and counts.enemy_turn_ended >= 5, "legacy enemy_turn_* fire per enemy action")
	_check(counts.combat_ended == 0 and counts.player_dead == 0 and global_data.get_alive_enemies().size() == 2, "combat is still running with both enemies alive")
	return true


func _play_block() -> bool:
	var card: Node
	for card_data: Resource in hand_manager.player_hand:
		if card_data.object_id == "card_block_basic":
			card = hand.card_data_to_hand_card.get(card_data)
			break
	if not _check(card != null, "hand contains a playable Basic Block"):
		return false
	var before_played: int = stats.cards_played_this_turn.size()
	card.card_selected.emit(card)
	return await _wait(func(): return stats.cards_played_this_turn.size() > before_played and _idle(), "block card play completes")


func _enemy(object_id: String) -> Node:
	for enemy: Node in global_data.get_alive_enemies():
		if enemy.enemy_data.object_id == object_id:
			return enemy
	return null


func _unit_name(unit: Node) -> String:
	if unit == player:
		return "hero"
	if unit.enemy_data.object_id == "ctb_enemy_fast":
		return "fast"
	if unit.enemy_data.object_id == "ctb_enemy_slow":
		return "slow"
	return unit.unit_uid


func _idle() -> bool:
	return not action_handler.actions_being_performed and not hand_manager.cards_being_played and hand_manager.card_play_queue.is_empty()


func _player_ready() -> bool:
	return global_data.is_player_in_combat() and stats.is_player_turn and director.is_player_action_pending() and not hand.hand_disabled and _idle()


func _wait(predicate: Callable, label: String, seconds: float = 15.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline:
			print("STATE: " + JSON.stringify({"actions": action_log, "ticks": tick_advances, "counts": counts}))
			return _check(false, label + " (timeout)")
		await create_timer(0.02).timeout
	return _check(true, label)


func _connect_observers() -> void:
	signals.unit_action_started.connect(func(unit):
		action_log.append([_unit_name(unit), director.current_tick])
		player_turn_flags.append(stats.is_player_turn)
		if unit == player:
			hero_block_at_action_start.append(player.get_block())
	)
	signals.unit_action_ended.connect(func(unit): ended_log.append([_unit_name(unit), director.current_tick]))
	signals.combat_tick_advanced.connect(func(previous, current): tick_advances.append([previous, current]))
	signals.player_turn_started.connect(func():
		counts.player_turn_started += 1
		hero_block_before_reset.append(player.get_block())
	)
	signals.player_turn_ended.connect(func(): counts.player_turn_ended += 1)
	signals.enemy_turn_started.connect(func(): counts.enemy_turn_started += 1)
	signals.enemy_turn_ended.connect(func(): counts.enemy_turn_ended += 1)
	signals.timeline_changed.connect(func(): counts.timeline_changed += 1)
	signals.combat_started.connect(func(_event): counts.combat_started += 1)
	signals.combat_ended.connect(func(): counts.combat_ended += 1)
	signals.player_killed.connect(func(_player): counts.player_dead += 1)


func _check(condition: bool, label: String) -> bool:
	checks += 1
	results.append({"pass": condition, "label": label})
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		printerr("FAIL: " + label)
	return condition


func _finish() -> void:
	if finished:
		return
	finished = true
	if output_directory != "" and output_directory.replace("\\", "/").contains("/artifacts/"):
		var report: FileAccess = FileAccess.open(output_directory.path_join("ctb-result.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"checks": checks, "failures": failures, "assertions": results, "action_log": action_log, "tick_advances": tick_advances, "boundary": "one unfinished CTB combat, declared data fixture, real UI signals/handlers; no physical mouse hit testing"}, "\t"))
	print("CTB %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _timeout() -> void:
	if not finished:
		_check(false, "100-second overall timeout")
		_finish()
