extends SceneTree
## Run in an isolated --path only. Phases write/read run in separate processes.
## fixtures are kept under that project, never under the source game/.

const EXPECTED_FILE := "res://save-flow-expected.json"
const RUN_SEED := 7192026
var checks := 0
var failures := 0
var phase := ""
var finished := false
var global_data: Node
var loader: Node
var game_root: Node
var run_signals := 0
var location_signals := 0
var source_game_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--source-game-path="):
			source_game_path = arg.trim_prefix("--source-game-path=")
	create_timer(40.0).timeout.connect(_timeout)
	global_data = root.get_node("Global")
	loader = root.get_node("FileLoader")
	var project_path := ProjectSettings.globalize_path("res://").replace("\\", "/")
	var source_path: String = get_script().resource_path.get_base_dir().path_join("../game").simplify_path().replace("\\", "/")
	if not source_game_path.is_empty():
		source_path = source_game_path.simplify_path().replace("\\", "/")
	_check(project_path.trim_suffix("/") != source_path.trim_suffix("/"), "project is not the source game directory")
	_check(project_path.contains("/artifacts/"), "save fixture project is inside artifacts")
	if failures > 0:
		_finish()
		return
	print("SAVELOAD phase=%s pid=%d project=%s" % [phase, OS.get_process_id(), project_path])
	if phase == "missing" or phase == "invalid":
		_probe_rejected_input()
		_finish()
		return
	if phase == "rejected":
		_run_rejection_regressions()
		_finish()
		return
	if phase == "custom_only":
		_check_custom_without_default()
		_finish()
		return
	var packed: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	game_root = packed.instantiate()
	root.add_child(game_root)
	current_scene = game_root
	await process_frame
	await process_frame
	if phase == "write":
		await _write_phase()
	elif phase == "read":
		await _read_phase()
	else:
		_check(false, "phase must be write/read/missing/invalid/rejected/custom_only")
	# Teardown only after all observations; QUIT retains the checkpoint by contract.
	if global_data.is_run:
		global_data.end_run(0)
	await process_frame
	await process_frame
	if game_root != null:
		game_root.queue_free()
		await process_frame
	_finish()

func _write_phase() -> void:
	global_data.start_run("character_red", RUN_SEED, 0)
	await process_frame
	await process_frame
	_check(global_data.is_run, "real start_run starts a run")
	_check(loader.has_save_file(), "new run creates its automatic checkpoint")
	var player: Resource = global_data.player_data
	_check(player.player_location_id == "location_0", "checkpoint is starting location, not a mid-combat snapshot")
	_check(not player.player_deck.is_empty(), "new run populates permanent deck")
	if player.player_deck.is_empty():
		return
	var extra: Resource = global_data.get_card_data_from_prototype("card_attack_basic")
	player.player_deck.append(extra)
	extra.upgrade_card()
	_check(extra.card_upgrade_amount == 1, "real upgrade_card updates extra card")
	_check(extra.card_values.damage == 21 and extra.card_values.number_of_attacks == 2, "upgraded attack values changed from prototype")
	player.player_money = 137
	player.player_health_max = 61
	player.player_health = 37
	player.player_values["save_flow_marker"] = {"nested": [3, "roundtrip", true]}
	var rng: RandomNumberGenerator = player.get_player_rng("rng_save_flow")
	for i in 7:
		rng.randi()
	var clone := RandomNumberGenerator.new()
	clone.seed = rng.seed
	clone.state = rng.state
	var expected_next: Array = []
	for i in 5:
		expected_next.append(str(clone.randi()))
	loader.save_game()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://external/saves/save.json"))
	_check(saved is Dictionary and saved.has("properties"), "real save_game writes parseable serialized player")
	var expected := {
		"writer_pid": OS.get_process_id(),
		"player": _normalized_snapshot(player),
		"rng_next": expected_next,
		"extra_uid": extra.object_uid
	}
	var output := FileAccess.open(EXPECTED_FILE, FileAccess.WRITE)
	_check(output != null, "expected semantic fixture can be written")
	if output != null:
		output.store_string(JSON.stringify(expected, "\t"))
		output.close()
	_check(player.player_run_seed == RUN_SEED, "fixture preserves requested run seed")

func _read_phase() -> void:
	_check(FileAccess.file_exists(EXPECTED_FILE), "write-phase fixture exists")
	if not FileAccess.file_exists(EXPECTED_FILE):
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_FILE))
	_check(int(expected.writer_pid) != OS.get_process_id(), "read runs in a different Godot process")
	_check(not global_data.is_run, "fresh process has not started a run")
	_check(loader.has_save_file(), "checkpoint is discoverable by Continue")
	var menu: Node = game_root.get_node("TitleScreen/MainMenu")
	_check(menu.continue_button.visible, "Continue is visible for saved checkpoint")
	var initial_player: Resource = global_data.player_data
	loader.load_game(false)
	var player: Resource = global_data.player_data
	_check(player != initial_player, "load_game builds a new PlayerData instance")
	var actual: Dictionary = _normalized_snapshot(player)
	var expected_player: Dictionary = expected.player
	for key in expected_player:
		_check(actual.get(key) == expected_player[key], "roundtrip field: " + key)
	_check(root.get_node("StatsHandler").current_run_stats == player.player_run_stats, "loaded run statistics reference is reattached")
	_check(player.player_deck.back().object_uid == expected.extra_uid, "upgraded card UID survives across processes")
	var rng: RandomNumberGenerator = player.get_player_rng("rng_save_flow")
	var actual_next: Array = []
	for i in 5:
		actual_next.append(str(rng.randi()))
	_check(actual_next == expected.rng_next, "next five RNG outputs match saved state")
	# Re-load through the real Continue handler so RNG probing above cannot affect continuation.
	menu._on_continue_button_up()
	await process_frame
	await process_frame
	_check(global_data.is_run, "Continue re-enters run")
	_check(not game_root.get_node("TitleScreen").visible, "Continue hides title screen")
	var player_after: Resource = global_data.player_data
	_check(player_after.player_money == 137 and player_after.player_health == 37, "Continue retains money and health")
	_check(global_data.get_player() != null, "Continue restores player scene")
	var locations: Array = global_data.get_next_locations()
	_check(not locations.is_empty(), "loaded map has reachable next locations")
	if locations.is_empty():
		return
	var next_location: Resource = null
	for candidate in locations:
		if candidate.location_type == 1:
			next_location = candidate
			break
	_check(next_location != null, "starting checkpoint has a reachable combat location")
	if next_location == null:
		return
	root.get_node("ActionGenerator").generate_visition_location(next_location.location_id)
	var deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		if not root.get_node("ActionHandler").actions_being_performed and not root.get_node("HandManager").player_hand.is_empty():
			break
		await process_frame
	_check(global_data.player_data.player_location_id == next_location.location_id, "post-load visit action advances to adjacent map location")
	_check(not global_data.get_alive_enemies().is_empty(), "post-load combat spawns live enemies")
	_check(not root.get_node("HandManager").player_hand.is_empty(), "post-load combat draws playable hand")
	_check(not root.get_node("ActionHandler").actions_being_performed, "post-load action pipeline settles")
	var loaded_director: Node = global_data.get_combat_director()
	_check(loaded_director != null and loaded_director.battlefield != null and loaded_director.battlefield.boards.size() == 2, "post-load combat rebuilds two boards from production defaults")
	if loaded_director != null and loaded_director.battlefield != null:
		var loaded_hero: Node = global_data.get_player()
		_check(loaded_hero.board_id == "party" and loaded_director.battlefield.get_board("party").get_unit_at(loaded_hero.board_anchor) == loaded_hero, "post-load hero occupies the party board")
		var enemies_on_own_board: bool = true
		for loaded_enemy: Node in global_data.get_alive_enemies():
			enemies_on_own_board = enemies_on_own_board and loaded_enemy.board_id == "enemy" and loaded_director.battlefield.get_board("enemy").get_unit_at(loaded_enemy.board_anchor) == loaded_enemy
		_check(enemies_on_own_board, "post-load enemies occupy independent enemy-board cells")
	var saved_after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://external/saves/save.json"))
	_check(saved_after.properties.player_location_id == next_location.location_id, "next-location autosave writes the new checkpoint")

func _normalized_snapshot(player: Resource) -> Dictionary:
	# Compare semantic selected fields; transient combat piles/animations are not the save contract.
	var all_properties: Dictionary = player.get_serializable_properties_to_json_patch().properties
	var selected := {}
	for key in ["player_character_object_id", "player_run_seed", "player_health", "player_health_max", "player_money", "player_deck", "player_values", "player_rng", "player_location_id", "location_id_to_location_data", "player_act", "player_act_id", "player_run_stats", "player_event_pools", "player_event_blacklisted_ids", "player_artifact_uid_to_artifact_data", "player_artifact_pool"]:
		_check(all_properties.has(key), "serialized contract includes " + key)
		selected[key] = all_properties.get(key)
	return JSON.parse_string(JSON.stringify(selected))

func _probe_rejected_input() -> void:
	var original: Resource = global_data.player_data
	var original_run: bool = global_data.is_run
	var path := "res://external/saves/save.json"
	if phase == "missing":
		_check(not FileAccess.file_exists(path), "missing probe starts without a default save")
		if FileAccess.file_exists(path):
			return
	else:
		DirAccess.make_dir_recursive_absolute("res://external/saves")
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("{ deliberately invalid JSON")
		file.close()
	loader.load_game(false)
	_check(global_data.player_data == original, "rejected input preserves player object")
	_check(global_data.is_run == original_run, "rejected input preserves run state")
	print("SAVELOAD DIAGNOSTIC: missing/invalid probes intentionally exercise loader error reporting; expected errors must not be treated as clean gameplay logs.")

func _run_rejection_regressions() -> void:
	# Run after write/read in the same isolated project; never overwrite its good save.
	var good_save_path := "res://external/saves/save.json"
	_check(FileAccess.file_exists(good_save_path), "rejection suite requires good checkpoint")
	if not FileAccess.file_exists(good_save_path):
		return
	var untouched_save := FileAccess.get_file_as_string(good_save_path)
	loader.load_game(false)
	_check(global_data.is_run, "valid checkpoint initializes guard fixture")
	root.get_node("Signals").run_started.connect(func(): run_signals += 1)
	root.get_node("Signals").map_location_selected.connect(func(_location): location_signals += 1)
	var cases_dir := "save-flow-cases/"
	DirAccess.make_dir_recursive_absolute("res://" + cases_dir)
	var suffix := str(OS.get_process_id())
	var cases := {
		"missing": null,
		"malformed": "{ invalid JSON",
		"array": "[]",
		"scalar": "42",
		"null": "null",
		"no_properties": "{}",
		"array_properties": "{\"properties\":[]}",
		"empty_properties": "{\"properties\":{}}",
		"array_patch_metadata": "{\"properties\":{\"player_character_object_id\":\"character_red\"},\"patch_data\":[]}",
		"unknown_character": "{\"properties\":{\"player_character_object_id\":\"missing_character\"}}"
	}
	for case_name in cases:
		var filename: String = case_name + "-" + suffix + ".json"
		if cases[case_name] != null:
			var file := FileAccess.open("res://" + cases_dir + filename, FileAccess.WRITE)
			file.store_string(cases[case_name])
			file.close()
		var original: Resource = global_data.player_data
		var original_run: bool = global_data.is_run
		var original_stats: Resource = root.get_node("StatsHandler").current_run_stats
		var snapshot := JSON.stringify(original.get_serializable_properties_to_json_patch())
		var errors_before: int = root.get_node("DebugLogger").logged_lines.size()
		print("EXPECTED SAVE REJECTION BEGIN: " + case_name)
		loader.load_game(true, cases_dir, filename)
		print("EXPECTED SAVE REJECTION END: " + case_name)
		_check(global_data.player_data == original, case_name + ": preserves PlayerData identity")
		_check(global_data.is_run == original_run, case_name + ": preserves run state")
		_check(root.get_node("StatsHandler").current_run_stats == original_stats, case_name + ": preserves stats reference")
		_check(JSON.stringify(original.get_serializable_properties_to_json_patch()) == snapshot, case_name + ": preserves player values")
		_check(run_signals == 0 and location_signals == 0, case_name + ": emits no run or location signal")
		var entries: Array = root.get_node("DebugLogger").logged_lines
		_check(entries.size() == errors_before + 1 and str(entries.back()[1]).begins_with("FileLoader.load_game(): Save rejected"), case_name + ": reports one explicit rejection")
	# Use different content/name to prove arguments select the requested custom save.
	global_data.player_data.player_money = 2468
	loader.save_game(cases_dir, "valid-custom.json")
	global_data.player_data.player_money = 9999
	loader.load_game(false, cases_dir, "valid-custom.json")
	_check(global_data.player_data.player_money == 2468, "valid custom directory/name loads its own payload")
	_check(run_signals == 0 and location_signals == 0, "custom load(false) emits no resume signals")
	_check(FileAccess.get_file_as_string(good_save_path) == untouched_save, "guard fixtures leave default checkpoint untouched")
	_check_custom_without_default()

func _check_custom_without_default() -> void:
	# The project guard above requires artifacts/. Move only this isolated fixture,
	# restore before assertions, and keep a uniquely named backup if restoration fails.
	var default_path := "res://external/saves/save.json"
	_check(FileAccess.file_exists(default_path), "custom-only fixture starts with a good default checkpoint")
	if not FileAccess.file_exists(default_path):
		return
	var original_text := FileAccess.get_file_as_string(default_path)
	loader.load_game(false)
	var cases_dir := "save-flow-cases/"
	DirAccess.make_dir_recursive_absolute("res://" + cases_dir)
	var unique := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var backup_path := "res://" + cases_dir + "default-backup-" + unique + ".json"
	var custom_name := "valid-without-default-" + unique + ".json"
	global_data.player_data.player_money = 3579
	loader.save_game(cases_dir, custom_name)
	global_data.player_data.player_money = 9999
	var move_error := DirAccess.rename_absolute(default_path, backup_path)
	_check(move_error == OK, "isolated default checkpoint moved to unique recoverable backup")
	if move_error != OK:
		return
	var default_absent := not FileAccess.file_exists(default_path)
	loader.load_game(false, cases_dir, custom_name)
	var loaded_custom: bool = global_data.player_data.player_money == 3579
	var restore_error := DirAccess.rename_absolute(backup_path, default_path)
	_check(restore_error == OK, "isolated default checkpoint restored after custom load")
	if restore_error != OK:
		printerr("RECOVERY: isolated checkpoint backup retained at " + backup_path)
	_check(default_absent, "custom load was attempted with no default checkpoint")
	_check(loaded_custom, "valid custom save loads when default save does not exist")
	_check(FileAccess.get_file_as_string(default_path) == original_text, "restored default checkpoint is byte-for-byte unchanged")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _timeout() -> void:
	if not finished:
		printerr("SAVELOAD FAIL: event-loop timeout")
		quit(124)

func _finish() -> void:
	finished = true
	print("SAVELOAD %s: phase=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", phase, checks, failures])
	quit(0 if failures == 0 else 1)
