extends RefCounted
## Three fresh processes share only normal save files and an observation snapshot.

func run(c) -> bool:
	match c.phase:
		"write": return await _write(c)
		"read": return await _read(c)
		"defeat": return await _defeat(c)
	return c.check(false, "unimplemented scenario phase")

func _write(c) -> bool:
	if not c.check(not FileLoader.has_save_file(), "write phase begins with a fresh isolated profile"): return false
	if not await c.ui.new_run(): return false
	# Check normal map adjacency without altering the map or location objects.
	var initial: String = Global.player_data.player_location_id
	for button: Node in c.map.location_container.get_children():
		if button.location_data.location_event_object_id == "demo_event_final":
			button.button_up.emit()
			break
	await c.process_frame
	c.check(Global.player_data.player_location_id == initial and c.events.is_empty(), "map refuses jumping directly to the non-adjacent final battle")
	if not await c.ui.visit("demo_event_entry"): return false
	var lessons: RefCounted = load(get_script().resource_path.get_base_dir().path_join("scenario_lessons.gd")).new()
	if not await lessons.entry(c): return false
	if not await c.ui.rewards(): return false
	c.check(Global.player_data.player_deck.size() == 11, "first reward adds a real eleventh permanent card")
	# Framework checkpoints occur BEFORE a location's combat. Enter the second
	# encounter to persist the acquired card, then quit without pretending midbattle save.
	if not await c.ui.visit("demo_event_field"): return false
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://external/saves/save.json"))
	var properties: Dictionary = save.properties
	c.check(properties.player_act_id == "demo_act" and properties.player_location_id == "demo_location_field", "normal visit autosave stores the second encounter checkpoint")
	c.check(properties.player_deck.size() == 11, "autosave includes the naturally acquired reward card")
	var expected: Dictionary = {"writer_pid": OS.get_process_id(), "player": {}}
	for key: String in ["player_character_object_id", "player_act_id", "player_location_id", "player_deck", "player_money", "player_health", "player_health_max", "player_run_seed"]:
		expected.player[key] = properties[key]
	var file := FileAccess.open(c.EXPECTED, FileAccess.WRITE)
	if not c.check(file != null, "observation snapshot can be written independently of game save"): return false
	file.store_string(JSON.stringify(expected, "  "))
	file.close()
	c.game_root.get_node("RunScreen/PauseOverlay").return_to_title_button.pressed.emit()
	if not await c.wait_for(func(): return not Global.is_run, "normal Return to Title preserves checkpoint"): return false
	c.check(FileLoader.has_save_file(), "QUIT retains the real checkpoint for another process")
	return true

func _read(c) -> bool:
	if not c.check(FileAccess.file_exists(c.EXPECTED), "write-process observation snapshot exists"): return false
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(c.EXPECTED))
	c.check(int(expected.writer_pid) != OS.get_process_id(), "Continue uses a genuinely different engine process")
	var menu: Node = c.game_root.get_node("TitleScreen/MainMenu")
	if not c.check(menu.continue_button.is_visible_in_tree() and not Global.is_run, "fresh process offers real Continue for persisted run"): return false
	menu.continue_button.button_up.emit()
	if not await c.wait_for(c.ready_to_play, "Continue reconstructs the saved field encounter"): return false
	var actual: Dictionary = Global.player_data.get_serializable_properties_to_json_patch().properties
	for key: String in expected.player:
		c.check(JSON.parse_string(JSON.stringify(actual.get(key))) == expected.player[key], "cross-process checkpoint retains " + key)
	c.check(c.events == ["demo_event_field"] and c.director.battlefield.boards.size() == 2, "Continue restarts the authored second encounter with two fresh boards")
	var lessons: RefCounted = load(get_script().resource_path.get_base_dir().path_join("scenario_lessons.gd")).new()
	if not await lessons.field(c): return false
	if not await c.ui.rewards(): return false
	c.check(Global.player_data.player_deck.size() == 12, "second natural reward remains in the permanent deck")
	if not await c.ui.visit("demo_event_final"): return false
	if not await c.ui.fight(): return false
	var summary: Node = c.game_root.get_node("RunScreen/RunSummaryOverlay")
	if not await c.wait_for(func(): return summary.is_visible_in_tree() and c.idle(), "last Boss death naturally reaches whole-run summary"): return false
	c.check(summary.player_run_end_state == Global.RUN_ENDS.VICTORY and summary.victory_label.visible and not summary.defeat_label.visible, "final authored Boss produces true victory state")
	c.check(not c.game_root.get_node("RunScreen/RewardOverlay").is_visible_in_tree(), "terminal Boss bypasses ordinary reward screen")
	c.check(c.events == ["demo_event_field", "demo_event_final"], "loaded run follows the remaining fixed adjacent event sequence")
	var wins: int = Global.profile_data.profile_total_wins
	summary.end_run_button.button_up.emit()
	if not await c.wait_for(func(): return not Global.is_run, "victory End Run settles normally"): return false
	c.check(Global.profile_data.profile_total_wins == wins + 1 and not FileLoader.has_save_file(), "victory settlement records a win and removes only the isolated run checkpoint")
	return true

func _defeat(c) -> bool:
	if not c.check(not FileLoader.has_save_file(), "defeat phase starts after completed victory settlement"): return false
	if not await c.ui.new_run(): return false
	if not await c.ui.visit("demo_event_entry"): return false
	var initial_hp: int = c.player.get_combatant_health()
	var summary: Node = c.game_root.get_node("RunScreen/RunSummaryOverlay")
	for action in 65:
		if summary.is_visible_in_tree(): break
		if not await c.ui.end_turn(): return false
	if not c.check(summary.is_visible_in_tree(), "unopposed natural enemy intents eventually defeat the player"): return false
	c.check(not c.player.is_alive() and c.player.get_combatant_health() == 0 and c.damage_received >= initial_hp, "real enemy attacks and damage signals account for the lethal health loss")
	c.check(summary.player_run_end_state == Global.RUN_ENDS.LOSS and summary.defeat_label.visible, "natural lethal damage chooses defeat summary")
	c.check(c.played == 0 and not Global.get_alive_enemies().is_empty(), "defeat branch neither cheats damage nor plays cards")
	var losses: int = Global.profile_data.profile_total_losses
	summary.end_run_button.button_up.emit()
	if not await c.wait_for(func(): return not Global.is_run and c.game_root.get_node("TitleScreen/NewRunMenu").is_visible_in_tree(), "defeat settlement returns to New Run"): return false
	c.check(Global.profile_data.profile_total_losses == losses + 1 and not FileLoader.has_save_file(), "defeat records one loss and clears the isolated checkpoint")
	if not await c.ui.new_run(): return false
	c.check(Global.player_data.player_health == 70 and Global.player_data.player_deck.size() == 10 and Global.player_data.player_act_id == "demo_act", "normal restart resets authored health deck and Act")
	return true
