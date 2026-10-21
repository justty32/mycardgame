extends "combat_flow.gd"
## Declared data fixture, real menus/cards/rewards/checkpoints. No board world is installed.
var phase: String = ""
const EXPECTED := "user://boardless-checkpoint.json"

func _main() -> void:
	create_timer(180.0).timeout.connect(_timeout)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--boardless-phase="): phase = argument.trim_prefix("--boardless-phase=")
	output_directory = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/").get_base_dir()
	if not _check(phase in ["write", "read", "defeat", "scene_off", "removed"] and output_directory.replace("\\", "/").contains("/artifacts/"), "known isolated boardless phase"):
		_finish()
		return
	global_data = root.get_node("Global")
	hand_manager = root.get_node("HandManager")
	action_handler = root.get_node("ActionHandler")
	signals = root.get_node("Signals")
	stats = root.get_node("StatsHandler")
	_connect_observers()
	var fixture: RefCounted = load(get_script().resource_path.get_base_dir().path_join("boardless_fixture.gd")).new()
	fixture.install("defeat" if phase == "defeat" else "victory")
	# scene_off: rules enabled, scene opt-out. removed (BoardRemoved suite): rules and scene enabled,
	# but the board module files are deleted from the isolated copy.
	if phase in ["scene_off", "removed"]: global_data.get_combat_rules().board_enabled = true
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	game_root = scene.instantiate()
	combat = game_root.get_node("RunScreen/Combat")
	if phase == "scene_off": combat.board_module_enabled = false
	root.add_child(game_root)
	current_scene = game_root
	await process_frame
	hand = combat.get_node("Hand")
	map = game_root.get_node("RunScreen/Map")
	player = combat.get_node("Player")
	print("BOUNDARY: explicit ordinary-card data fixtures; real menu/queue/intent/reward/save handlers; no physical UI input.")
	var campaign: RefCounted = load(get_script().resource_path.get_base_dir().path_join("boardless_campaign.gd")).new()
	var completed: bool = await campaign.run(self)
	_check(completed, "complete boardless phase " + phase)
	if global_data.is_run:
		game_root.get_node("RunScreen/PauseOverlay").return_to_title_button.pressed.emit()
		await _wait(func(): return not global_data.is_run and _idle(), "normal quit settles boardless cleanup")
	game_root.queue_free()
	await process_frame
	_finish()

func new_run() -> bool:
	var main: Node = game_root.get_node("TitleScreen/MainMenu")
	if root.get_node("FileLoader").has_save_file():
		main.forfeit_run_button.button_up.emit()
		await process_frame
	if main.new_run_button.is_visible_in_tree(): main.new_run_button.button_up.emit()
	var menu: Node = game_root.get_node("TitleScreen/NewRunMenu")
	menu._on_character_selected("character_red")
	menu.seed_input.text = "20261019"
	menu.start_run_button.pressed.emit()
	if not await _wait(func(): return global_data.is_run, "real Start Run creates boardless campaign"): return false
	_check(global_data.player_data.player_act_id == "act_1" and global_data.player_data.player_deck.size() == 5, "legacy start uses default Act and authored fixture deck")
	var options: Node = game_root.get_node("RunScreen/RunStartOptions")
	if not _check(options.starting_option_container.get_child_count() == 1, "normal start option exists"): return false
	var option: Node = options.starting_option_container.get_child(0)
	option.dialogue_option_clicked.emit(option)
	return await _wait(func(): return map.is_visible_in_tree() and map.can_travel, "normal start option opens map")

func visit_fixture() -> bool:
	var location: Resource
	for candidate: Resource in global_data.get_next_locations():
		if candidate.location_type == 1:
			location = candidate
			break
	if not _check(location != null, "real generated map has adjacent combat for declared fixture"): return false
	location.location_event_object_id = "combat_flow_event"
	for button: Node in map.location_container.get_children():
		if button.location_data == location:
			button.button_up.emit()
			break
	if not await _wait(_player_ready, "map visit starts ordinary encounter and initial draw"): return false
	enemy = global_data.get_alive_enemies()[0]
	assert_no_board()
	return true

func assert_no_board() -> void:
	var director: Node = combat.combat_director
	_check(combat.board_module == null and director.board_module == null, "disabled combat has no BoardCombatModule instance")
	_check(director.board_controller == null and director.battlefield == null and director.board == null and director.field_controller == null and director.threat_preview == null, "disabled combat allocates no board controller battlefield field or preview")
	_check(combat.board_view == null and combat.board_views.is_empty() and combat.actor_presentation == null and combat.undo_move_button == null, "disabled combat creates no board views standing actor controller or undo control")
	_check(combat.card_play_adapter != null, "passive card rejection adapter exists without allocating a board world")
	_check(player.board_anchor == Vector2i(-1, -1) and enemy.board_anchor == Vector2i(-1, -1), "ordinary units remain outside board occupancy")
	_check(root.get_node("UnitRegistry").get_unit(player.unit_uid) == player and root.get_node("UnitRegistry").get_unit(enemy.unit_uid) == enemy and (director.acting_unit == player or director.timeline.has(player)) and (director.acting_unit == enemy or director.timeline.has(enemy)), "ordinary units retain registry identities and real CTB timeline membership")
	_check(not _has_board_node(combat), "disabled scene tree contains no module or board view node")

func _has_board_node(node: Node) -> bool:
	var script: Script = node.get_script()
	if script != null and script.resource_path.get_file() in ["BoardCombatModule.gd", "BoardView.gd"]: return true
	for child: Node in node.get_children():
		if _has_board_node(child): return true
	return false

func win_combat() -> bool:
	for turn: int in range(12):
		while global_data.is_player_in_combat() and is_instance_valid(enemy) and enemy.is_alive() and global_data.player_data.player_energy > 0:
			if _find_hand_card("card_attack_basic") == null: break
			if not await _play("card_attack_basic", true, enemy.get_combatant_health() <= 20): return false
		if not global_data.is_player_in_combat() or not is_instance_valid(enemy) or not enemy.is_alive(): break
		var started: int = counts.hero_action_started
		combat.end_turn_button.button_up.emit()
		if not await _wait(func(): return not global_data.is_player_in_combat() or (_player_ready() and counts.hero_action_started > started), "ordinary enemy intent and next hero action complete"): return false
	var rewards: Node = game_root.get_node("RunScreen/RewardOverlay")
	if not await _wait(func(): return rewards.is_visible_in_tree() and _idle(), "ordinary lethal card naturally opens rewards"): return false
	_check(counts.enemy_dead == 1 and counts.combat_ended == 1 and player.is_alive(), "boardless combat reaches genuine victory once")
	if not await _claim_rewards(rewards): return false
	rewards.continue_button.button_up.emit()
	return await _wait(func(): return map.is_visible_in_tree() and map.can_travel, "ordinary reward Continue returns to map")

func _finish() -> void:
	if finished: return
	finished = true
	var file := FileAccess.open("user://boardless-" + phase + "-result.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"phase": phase, "checks": checks, "failures": failures, "assertions": results, "snapshots": snapshots}, "  "))
		file.close()
	print("BOARDLESS CHECKS: %d, failures: %d" % [checks, failures])
	print("BOARDLESS %s: %s" % ["PASS" if failures == 0 else "FAIL", phase])
	quit(0 if failures == 0 else 1)
