extends RefCounted
## Separate engine processes share normal checkpoints, never in-memory fixtures.
func run(c) -> bool:
	match c.phase:
		"write": return await _write(c)
		"read": return await _read(c)
		"defeat":
			if not await c.new_run() or not await c.visit_fixture(): return false
			return await c._defeat_flow()
		"scene_off":
			var waves: RefCounted = load(get_script().resource_path.get_base_dir().path_join("boardless_wave_cases.gd")).new()
			waves.install()
			if not await c.new_run() or not await c.visit_fixture(): return false
			c._check(Global.get_combat_rules().board_enabled and not c.combat.board_module_enabled, "scene-level opt-out independently overrides enabled rules")
			if not await c._play("card_attack_basic", true) or not await c._play("card_block_basic", false): return false
			return await waves.run(c)
	return false

func _write(c) -> bool:
	if not c._check(not FileLoader.has_save_file(), "boardless write begins without checkpoint"): return false
	if not await c.new_run() or not await c.visit_fixture(): return false
	var preflight: RefCounted = load(get_script().resource_path.get_base_dir().path_join("run_start_preflight_probe.gd")).new()
	preflight.run(c._check)
	var cards: RefCounted = load(get_script().resource_path.get_base_dir().path_join("boardless_card_cases.gd")).new()
	if not await cards.run(c): return false
	var intents: RefCounted = load(get_script().resource_path.get_base_dir().path_join("boardless_intent_cases.gd")).new()
	await intents.run(c)
	var hero_action: int = c.counts.hero_action_started
	var hp: int = c.player.get_combatant_health()
	c.combat.end_turn_button.button_up.emit()
	if not await c._wait(func(): return c._player_ready() and c.counts.hero_action_started > hero_action, "no-board enemy really executes its intent after card contracts"): return false
	c._check(c.counts.enemy_action_started > 0 and c.player.get_combatant_health() == hp and c.player.get_block() == 0, "ordinary enemy attack consumes prior Block before next-turn reset")
	hero_action = c.counts.hero_action_started
	c.combat.end_turn_button.button_up.emit()
	if not await c._wait(func(): return c._player_ready() and c.counts.hero_action_started > hero_action, "unguarded ordinary enemy turn completes"): return false
	c._check(c.player.get_combatant_health() == hp - 14, "ordinary enemy intent deals real HP damage without board targeting")
	if not await c.win_combat(): return false
	c._check(Global.player_data.player_deck.size() == 6, "normal boardless reward adds one persistent card")
	if not await c.visit_fixture(): return false
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://external/saves/save.json"))
	var expected: Dictionary = {"writer_pid": OS.get_process_id(), "player": {}}
	for key: String in ["player_character_object_id", "player_act_id", "player_location_id", "player_deck", "player_money", "player_health", "player_run_seed"]:
		expected.player[key] = save.properties[key]
	c._check(save.properties.player_deck.size() == 6, "second encounter visit persists naturally claimed card at checkpoint")
	var file := FileAccess.open(c.EXPECTED, FileAccess.WRITE)
	if not c._check(file != null, "boardless checkpoint observation can be saved"): return false
	file.store_string(JSON.stringify(expected, "  "))
	file.close()
	return true

func _read(c) -> bool:
	if not c._check(FileLoader.has_save_file() and FileAccess.file_exists(c.EXPECTED), "fresh read process has prior normal checkpoint and observation"): return false
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(c.EXPECTED))
	c._check(int(expected.writer_pid) != OS.get_process_id(), "boardless Continue runs in a distinct engine process")
	var menu: Node = c.game_root.get_node("TitleScreen/MainMenu")
	if not c._check(menu.continue_button.is_visible_in_tree(), "fresh menu offers Continue"): return false
	menu.continue_button.button_up.emit()
	if not await c._wait(c._player_ready, "Continue reconstructs normal boardless encounter"): return false
	c.enemy = Global.get_alive_enemies()[0]
	c.assert_no_board()
	var actual: Dictionary = Global.player_data.get_serializable_properties_to_json_patch().properties
	for key: String in expected.player:
		if actual.get(key) != expected.player[key]:
			_report_difference(key, actual.get(key), expected.player[key])
		c._check(JSON.parse_string(JSON.stringify(actual.get(key))) == expected.player[key], "boardless checkpoint retains " + key)
	var hp: int = c.enemy.get_combatant_health()
	if not await c._play("card_attack_basic", true): return false
	c._check(c.enemy.get_combatant_health() == hp - 20, "loaded ordinary card damages actual selected enemy")
	return true

func _report_difference(key: String, actual: Variant, expected: Variant) -> void:
	var file := FileAccess.open("user://boardless-read-difference.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"key": key, "actual": actual, "expected": expected}, "  "))
	file.close()
	if key == "player_deck" and actual is Array and expected is Array:
		print("CHECKPOINT DIFF deck sizes actual=", actual.size(), " expected=", expected.size())
		for i: int in mini(actual.size(), expected.size()):
			for property: String in actual[i]:
				if actual[i].get(property) != expected[i].get(property):
					print("CHECKPOINT DIFF card=", i, " property=", property, " actual=", JSON.stringify(actual[i].get(property)), " expected=", JSON.stringify(expected[i].get(property)), " types=", typeof(actual[i].get(property)), "/", typeof(expected[i].get(property)))
	else:
		print("CHECKPOINT DIFF ", key, " actual=", JSON.stringify(actual), " expected=", JSON.stringify(expected))