extends SceneTree
## Run tools/game.ps1 -Mode Import, then -Mode Smoke.

var failures: int = 0
var checks: int = 0
var finished: bool = false
var global_data: Node
var file_loader: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	global_data = root.get_node("Global")
	file_loader = root.get_node("FileLoader")
	create_timer(45.0).timeout.connect(_on_timeout)
	print("SMOKE: Global autoload _ready has already run; initial profile/settings reads or writes precede this script.")
	var runtime_dir: String = ProjectSettings.globalize_path("res://").path_join("../artifacts/test-runtime").simplify_path()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(runtime_dir)
	_check(directory_error == OK, "test-runtime directory can be created")
	if directory_error != OK:
		_finish()
		return
	# Redirect settings writes after autoload ready.
	file_loader.PROFILE_DIR_PATH = "../artifacts/test-runtime/"
	file_loader.USER_SETTINGS_DIR_PATH = "../artifacts/test-runtime/"
	_check(ProjectSettings.globalize_path(file_loader._get_modified_filepath(file_loader.PROFILE_DIR_PATH)).simplify_path().trim_suffix("/") == runtime_dir, "profile writes resolve to artifacts/test-runtime")

	var main_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var packed: PackedScene = load(main_path) as PackedScene
	_check(packed != null, "configured main scene loads")
	if packed == null:
		_finish()
		return
	var game_root: Node = packed.instantiate()
	_check(game_root != null, "configured main scene instantiates")
	if game_root == null:
		_finish()
		return
	root.add_child(game_root)
	current_scene = game_root
	await process_frame
	await process_frame
	var menu: Control = game_root.get_node_or_null("TitleScreen/MainMenu") as Control
	_check(menu != null and menu.is_visible_in_tree(), "main menu is visible after ready")
	var new_run: Button = game_root.get_node_or_null("TitleScreen/MainMenu/VBoxContainer/NewRunButton") as Button
	_check(new_run != null and new_run.is_node_ready(), "new run button initializes")
	var content_profile: String = global_data.get_content_profile()
	print("SMOKE: content profile " + content_profile)
	if content_profile == global_data.CONTENT_PROFILE_PACK:
		# Pack profile: the built-in example/test content must be absent; packs bring their own.
		_check(global_data.get_character_data("character_red") == null, "pack profile skips built-in test content (no character_red)")
		_check(global_data.get_card_data("card_attack_basic") == null, "pack profile skips built-in test content (no card_attack_basic)")
		_check(_check_array_patch() == true, "array patch probe completed")
		_check(_check_dictionary_patch() == true, "dictionary patch assertions completed")
		print("SMOKE: pack profile; example_mod probe skipped because it extends built-in test content.")
	else:
		var character: Resource = global_data.get_character_data("character_red")
		_check(character != null, "character_red is registered")
		_check(not global_data.get_all_cards().is_empty(), "card prototypes are registered")
		if character == null:
			_finish()
			return
		_check(not character.character_starting_card_object_ids.is_empty(), "red character has a starting deck")
		for card_id: String in character.character_starting_card_object_ids:
			_check(global_data.get_card_data(card_id) != null, "starting card resolves: " + card_id)

		_check(_check_array_patch() == true, "array patch probe completed")
		_check(_check_dictionary_patch() == true, "dictionary patch assertions completed")
		_check(_check_example_mod(character) == true, "example_mod probe completed")
	_run_file_loader_probe(runtime_dir)
	_run_unit_registry_probe(game_root)
	_run_pack_probes()
	if OS.get_cmdline_user_args().has("--capture"):
		_check(await _capture_menu() == true, "main menu screenshot saved")
	if OS.get_cmdline_user_args().has("--force-failure"):
		_check(false, "requested failure-path control")
	game_root.queue_free()
	await process_frame
	_finish()


func _check_array_patch() -> bool:
	var character: Resource = load("res://data/readonly/CharacterData.gd").new()
	character.character_starting_card_object_ids.assign(["card_before"])
	character.set_serializable_properties_from_json_patch({
		"properties": {"character_starting_card_object_ids": ["card_after"]},
		"patch_data": {"character_starting_card_object_ids": "append"}
	})
	_check(character.character_starting_card_object_ids == ["card_before", "card_after"], "SerializableData JSON patch appends to CharacterData Array")
	return true


func _check_dictionary_patch() -> bool:
	var expected_by_strategy: Dictionary = {
		"merge_keep": {"existing": 3, "shared": 1, "added": 5},
		"merge_overwrite": {"existing": 3, "shared": 9, "added": 5},
		"overwrite": {"added": 5, "shared": 9},
		"unknown_strategy": {"added": 5, "shared": 9},
	}
	for strategy: String in expected_by_strategy:
		var card: Resource = load("res://data/prototype/CardData.gd").new()
		card.card_values = {"existing": 3, "shared": 1}
		card.set_serializable_properties_from_json_patch({
			"properties": {"card_values": {"added": 5, "shared": 9}},
			"patch_data": {"card_values": strategy}
		})
		_check(card.card_values == expected_by_strategy[strategy], "Dictionary JSON patch %s preserves its strategy contract" % strategy)
	return true


func _check_example_mod(character: Resource) -> bool:
	var before: Array[String] = character.character_starting_card_object_ids.duplicate()
	var mod_list_before: String = FileAccess.get_file_as_string("res://external/mod_list.json")
	var loader_script := GDScript.new()
	loader_script.source_code = "extends \"res://autoload/FileLoader.gd\"\nfunc _load_mod_list_data() -> ModListData:\n\tvar mod_list := ModListData.new()\n\tmod_list.mod_load_data = {\"external/mods/example_mod/\": {\"enabled\": true, \"load_priority\": 1}}\n\treturn mod_list\n"
	var compile_error: Error = loader_script.reload()
	_check(compile_error == OK, "test-only mod list adapter compiles after autoload initialization")
	if compile_error != OK:
		return false
	var loader: Node = loader_script.new()
	loader.load_read_only_data()
	var card: Resource = global_data.get_card_data("card_modded_card")
	_check(card != null, "real FileLoader registers example_mod card")
	var expected: Array[String] = before.duplicate()
	expected.append("card_modded_card")
	_check(character.character_starting_card_object_ids == expected, "example_mod appends one starting card and preserves original order")
	_check(FileAccess.get_file_as_string("res://external/mod_list.json") == mod_list_before, "example_mod probe leaves mod_list.json unchanged")
	if card != null:
		_check(card.card_play_actions.size() == 1, "example_mod deserializes its play action")
		if card.card_play_actions.size() == 1:
			var replacement: Script = load("res://scripts/actions/debug_actions/ActionDebugLog.gd")
			_check(replacement.source_code.contains("Mod loading successful"), "example_mod takes over the debug action resource path")
			var base_action: RefCounted = load("res://scripts/actions/BaseAction.gd").new()
			var actions: Array = root.get_node("ActionGenerator").create_actions(null, null, base_action.targets, card.card_play_actions, null)
			_check(actions.size() == 1 and actions[0].get_script() == replacement, "ActionGenerator creates the card action with the replacement script")
	loader.free()
	print("SMOKE: example_mod enabled only in this process; no run started, save-game or mod-list file written by this probe.")
	return true


## Real directory loading regression, independent of built-in or pack content.
func _run_file_loader_probe(runtime_dir: String) -> void:
	var probe_path: String = get_script().resource_path.get_base_dir().path_join("file_loader_probe.gd")
	var probe_script: GDScript = load(probe_path) as GDScript
	_check(probe_script != null, "file loader probe loads")
	if probe_script == null:
		return
	var results: Dictionary = probe_script.new().check(global_data, runtime_dir)
	_check(not results.is_empty(), "file loader probe returns assertions")
	for label: Variant in results.keys():
		_check(results[label] == true, str(label))
	print("FILE LOADER PROBE DONE: %d assertions" % results.size())


## Combat framework Phase 0 probe (tests/unit_registry_probe.gd), run in both content profiles.
func _run_unit_registry_probe(game_root: Node) -> void:
	var probe_path: String = get_script().resource_path.get_base_dir().path_join("unit_registry_probe.gd")
	var probe_script: GDScript = load(probe_path) as GDScript
	_check(probe_script != null, "unit registry probe loads")
	if probe_script == null:
		return
	var results: Dictionary = probe_script.new().check(root, game_root)
	_check(not results.is_empty(), "unit registry probe returns assertions")
	for label: Variant in results.keys():
		_check(results[label] == true, str(label))
	print("UNIT REGISTRY PROBE DONE: %d assertions" % results.size())


## Content-pack probes passed by the runner as --pack-probe=<path>. Each probe script
## defines check_loaded(global_data) -> {label: bool}; labels are printed as PASS/FAIL lines.
func _run_pack_probes() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--pack-probe="):
			continue
		var probe_path: String = argument.trim_prefix("--pack-probe=")
		var probe_name: String = probe_path.get_file()
		var probe_script: GDScript = load(probe_path) as GDScript
		_check(probe_script != null, "pack probe loads: " + probe_name)
		if probe_script == null:
			continue
		var probe: Object = probe_script.new()
		_check(probe.has_method("check_loaded"), "pack probe defines check_loaded(): " + probe_name)
		if not probe.has_method("check_loaded"):
			continue
		var results: Dictionary = probe.check_loaded(global_data)
		_check(not results.is_empty(), "pack probe returns assertions: " + probe_name)
		for label: Variant in results.keys():
			_check(results[label] == true, str(label))
		print("PACK PROBE DONE: %s (%d assertions)" % [probe_name, results.size()])


func _capture_menu() -> bool:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: --capture requires a rendered run; omit --headless")
		return false
	await RenderingServer.frame_post_draw
	var capture_dir: String = ProjectSettings.globalize_path("res://").path_join("../artifacts/startup").simplify_path()
	if DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
		return false
	var capture_path: String = capture_dir.path_join("main-menu.png")
	var capture_error: Error = root.get_texture().get_image().save_png(capture_path)
	print("SMOKE capture: " + capture_path)
	return capture_error == OK


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		printerr("FAIL: " + label)


func _finish() -> void:
	if finished:
		return
	finished = true
	print("SMOKE %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _on_timeout() -> void:
	if not finished:
		printerr("SMOKE FAIL: 45-second timeout before completion")
		quit(124)
