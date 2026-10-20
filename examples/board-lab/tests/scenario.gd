extends SceneTree
## Real pack scenario: no fixture registration or direct content/state replacement.
var global_data: Node
var signals: Node
var action_handler: Node
var hand_manager: Node
var stats: Node
var phase: String = ""
var checks: int = 0
var failures: int = 0
var finished: bool = false
var game_root: Node
var combat: Node
var hand: Node
var map: Node
var player: Node
var director: Node
var ui: RefCounted
var played: int = 0
var hero_actions: int = 0
var damage_received: int = 0
var events: Array[String] = []
var results: Array[Dictionary] = []
const EXPECTED = "user://board-lab-checkpoint.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	global_data = root.get_node("Global")
	signals = root.get_node("Signals")
	action_handler = root.get_node("ActionHandler")
	hand_manager = root.get_node("HandManager")
	stats = root.get_node("StatsHandler")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario-phase="):
			phase = arg.trim_prefix("--scenario-phase=")
	create_timer(220.0).timeout.connect(func(): check(false, "scenario timeout"); finish())
	if not check(phase in ["write", "read", "defeat"], "known declared phase"):
		finish()
		return
	if not check(ProjectSettings.globalize_path("res://").replace("\\", "/").contains("/artifacts/"), "isolated artifact project"):
		finish()
		return
	check(global_data.get_content_profile() == "pack", "standalone pack profile skips framework test content")
	check(global_data.get_character_data("character_red") == null, "framework sample character is absent")
	signals.card_played.connect(func(_request): played += 1)
	signals.unit_action_started.connect(func(unit):
		if unit == global_data.get_player(): hero_actions += 1)
	signals.combat_started.connect(func(event_id): events.append(event_id if not str(event_id).is_empty() else global_data.get_player_location_data().location_event_object_id))
	signals.combatant_damaged.connect(func(target, _unblocked, capped, _overkill):
		if target == global_data.get_player(): damage_received += capped)
	root.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width", 1200), ProjectSettings.get_setting("display/window/size/viewport_height", 700))
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	game_root = scene.instantiate()
	root.add_child(game_root)
	current_scene = game_root
	await process_frame
	await process_frame
	combat = game_root.get_node("RunScreen/Combat")
	hand = combat.get_node("Hand")
	map = game_root.get_node("RunScreen/Map")
	player = combat.get_node("Player")
	director = combat.combat_director
	ui = load(get_script().resource_path.get_base_dir().path_join("scenario_ui.gd")).new()
	ui.c = self
	var campaign: RefCounted = load(get_script().resource_path.get_base_dir().path_join("scenario_campaign.gd")).new()
	var ok: bool = await campaign.run(self)
	check(ok, "complete real pack " + phase + " flow")
	ui = null
	campaign = null
	if global_data.is_run:
		game_root.get_node("RunScreen/PauseOverlay").return_to_title_button.pressed.emit()
	await process_frame
	await process_frame
	game_root.queue_free()
	await process_frame
	await process_frame
	game_root = null
	combat = null
	hand = null
	map = null
	player = null
	director = null
	finish()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value: failures += 1
	results.append({"label": label, "passed": value})
	print(("PASS: " if value else "FAIL: ") + label)
	return value

func wait_for(predicate: Callable, label: String, seconds: float = 14.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline:
			print("STATE: ", JSON.stringify({"phase": phase, "energy": global_data.player_data.player_energy, "health": global_data.player_data.player_health, "location": global_data.player_data.player_location_id, "played": played, "hero_actions": hero_actions}))
			return check(false, label + " (timeout)")
		await create_timer(0.02).timeout
	return check(true, label)

func idle() -> bool:
	return not action_handler.actions_being_performed and not hand_manager.cards_being_played and hand_manager.card_play_queue.is_empty()

func ready_to_play() -> bool:
	return global_data.is_player_in_combat() and stats.is_player_turn and not hand.hand_disabled and idle()

func finish() -> void:
	if finished: return
	finished = true
	var file := FileAccess.open("user://board-lab-" + phase + "-result.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"phase": phase, "checks": checks, "failures": failures, "pid": OS.get_process_id(), "results": results}, "  "))
		file.close()
	print("SCENARIO COUNTS: checks=%d failures=%d" % [checks, failures])
	print("PACK SCENARIO %s: %s" % ["PASS" if failures == 0 else "FAIL", phase])
	quit(0 if failures == 0 else 1)
