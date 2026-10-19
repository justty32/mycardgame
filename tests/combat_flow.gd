extends SceneTree
## Run ONLY with --path pointing to an isolated copy with profile/settings/saves
## excluded, after cold import. --script must be this file's absolute path.
## UI signals exercise handlers; physical mouse hit-testing is not covered.

var checks: int = 0
var failures: int = 0
var finished: bool = false
var scenario: String = "victory"
var results: Array[Dictionary] = []
var snapshots: Array[Dictionary] = []
var player_damage_records: Array[Dictionary] = []
var counts: Dictionary = {"drawn": 0, "played": 0, "combat_started": 0, "combat_ended": 0, "enemy_turn": 0, "enemy_dead": 0, "player_dead": 0, "player_death_animation": 0, "hero_action_started": 0, "hero_action_ended": 0}
var global_data: Node
var hand_manager: Node
var action_handler: Node
var signals: Node
var stats: Node
var game_root: Node
var combat: Node
var hand: Node
var map: Node
var player: Node
var enemy: Node
var output_directory: String


func _initialize() -> void:
	call_deferred("_main")


func _main() -> void:
	create_timer(100.0).timeout.connect(_timeout)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario="):
			scenario = argument.trim_prefix("--scenario=")
	if scenario not in ["victory", "defeat"]:
		_check(false, "unknown scenario: " + scenario)
		_finish()
		return
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
	print("BOUNDARY: single combat with declared data fixtures; UI handler/signals, not mouse coordinates; autoload/save writes stay in the isolated project.")
	var completed: bool = await _scenario()
	_check(completed, "complete %s scenario returned" % scenario)
	if is_instance_valid(game_root):
		game_root.queue_free()
		await process_frame
	_finish()


func _scenario() -> bool:
	if not _check(not FileAccess.file_exists("res://external/saves/save.json"), "isolated copy starts without an existing run save"):
		return false
	var fixture: RefCounted = load(get_script().resource_path.get_base_dir().path_join("combat_fixture.gd")).new()
	fixture.install(scenario)
	var basic_attack: Resource = global_data.get_card_data("card_attack_basic")
	var basic_block: Resource = global_data.get_card_data("card_block_basic")
	if not _check(basic_attack.card_values.damage == 20 and basic_attack.card_energy_cost == 1, "native attack fixture contract is 20 damage / 1 energy"):
		return false
	if not _check(basic_block.card_values.block == 10 and basic_block.card_energy_cost == 1, "native block fixture contract is 10 block / 1 energy"):
		return false
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	game_root = scene.instantiate()
	root.add_child(game_root)
	current_scene = game_root
	await process_frame
	combat = game_root.get_node("RunScreen/Combat")
	hand = combat.get_node("Hand")
	map = game_root.get_node("RunScreen/Map")
	player = combat.get_node("Player")
	var new_run_button: Button = game_root.get_node("TitleScreen/MainMenu/VBoxContainer/NewRunButton")
	if not _check(new_run_button.is_visible_in_tree(), "fresh main menu offers New Run"):
		return false
	new_run_button.button_up.emit()
	var menu: Node = game_root.get_node("TitleScreen/NewRunMenu")
	_check(menu.is_visible_in_tree(), "New Run UI navigation opens character menu")
	menu._on_character_selected("character_red")
	menu.seed_input.text = "20261019"
	menu.start_run_button.pressed.emit()
	if not await _wait(func(): return global_data.is_run, "Start Run button creates a real run"):
		return false
	_check(global_data.player_data.player_run_seed == 20261019, "run uses the requested deterministic seed")
	_check(global_data.player_data.player_deck.size() == 5, "run builds the declared five-card deck from character data")
	_check(FileAccess.file_exists("res://external/saves/save.json"), "normal run-start autosave is created in the isolated copy")
	var options: Node = game_root.get_node("RunScreen/RunStartOptions")
	if not _check(options.is_visible_in_tree() and options.starting_option_container.get_child_count() == 1, "real start-option UI displays the declared no-bonus fixture"):
		return false
	var option: Node = options.starting_option_container.get_child(0)
	option.dialogue_option_clicked.emit(option)
	if not await _wait(func(): return map.is_visible_in_tree() and map.can_travel, "start-option handler opens the travel map"):
		return false
	var location: Resource
	for candidate: Resource in global_data.get_next_locations():
		# LOCATION_TYPES.COMBAT = 1 in the inspected upstream LocationData.
		if candidate.location_type == 1:
			location = candidate
			break
	if not _check(location != null, "generated map contains an adjacent combat destination"):
		return false
	# Bind the controlled encounter before visiting, via the normal location field.
	location.location_event_object_id = "combat_flow_event"
	var location_button: Node
	for button: Node in map.location_container.get_children():
		if button.location_data == location:
			location_button = button
			break
	if not _check(location_button != null, "generated combat location has its actual map button"):
		return false
	location_button.button_up.emit()
	if not await _wait(_player_ready, "map button starts combat and finishes initial draw"):
		return false
	_check(global_data.player_data.player_location_id == location.location_id and location.location_visited, "visit action advances the player and marks the combat location visited")
	_check(counts.combat_started == 1, "one combat started through the map visit")
	_check(global_data.get_alive_enemies().size() == 1, "event spawns exactly one fixture enemy")
	enemy = global_data.get_alive_enemies()[0]
	_check(enemy.get_combatant_health() == 65, "enemy spawn rolls the declared 65 HP")
	_check(enemy.enemy_data.get_current_intent().enemy_intent_attack_damage == 14, "enemy intent is a real 14-damage attack")
	_check(hand_manager.player_hand.size() == 5 and counts.drawn == 5, "turn one draws all five fixture cards through the draw pipeline")
	_check(global_data.player_data.player_energy == 3, "turn one begins with three energy")
	_check(counts.hero_action_started == 1 and counts.hero_action_ended == 0 and player.action_count == 1, "turn one emits unit_action_started(hero) once and no unit_action_ended")
	_check(enemy.faction == 1 and enemy.unit_uid != "" and root.get_node("UnitRegistry").get_unit(enemy.unit_uid) == enemy, "fixture enemy registers as an ENEMY-faction unit")
	_snapshot("turn_one_ready")
	if scenario == "defeat":
		return await _defeat_flow()

	if not await _play("card_block_basic", false):
		return false
	_check(player.get_block() == 10, "native Block action grants exactly ten block")
	if not await _play("card_attack_basic", true):
		return false
	_check(enemy.get_combatant_health() == 45, "native Attack action deals twenty enemy HP damage")
	if not await _play("card_attack_basic", true):
		return false
	_check(enemy.get_combatant_health() == 25, "second paid attack leaves twenty-five enemy HP")
	_check(global_data.player_data.player_energy == 0 and counts.played == 3, "three legal plays consume all energy and emit three played events")
	if not await _reject_unaffordable_card():
		return false
	_snapshot("turn_one_before_end")
	var health_before: int = player.get_combatant_health()
	combat.end_turn_button.button_up.emit()
	if not await _wait(func(): return counts.enemy_turn == 1 and _player_ready() and stats.get_turn_count() == 2, "End Turn UI runs the enemy intent and opens player turn two"):
		return false
	_check(player.get_combatant_health() == health_before - 4, "enemy's fourteen damage consumes ten block and four HP")
	_check(player.get_block() == 0, "spent block does not remain on turn two")
	_check(global_data.player_data.player_energy == 3, "turn two replenishes energy")
	_check(counts.hero_action_started == 2 and counts.hero_action_ended == 1 and player.action_count == 2, "hero unit action signals track the legacy player turns")
	_check(hand_manager.player_hand.size() == 5 and counts.drawn == 10, "discarded/played cards reshuffle and draw again on turn two")
	_check(counts.player_dead == 0 and counts.combat_ended == 0, "first enemy turn neither kills player nor ends combat")
	_snapshot("turn_two_ready")
	if not await _play("card_attack_basic", true):
		return false
	_check(enemy.get_combatant_health() == 5, "turn-two attack leaves five enemy HP")
	if not await _play("card_attack_basic", true, true):
		return false
	var rewards: Node = game_root.get_node("RunScreen/RewardOverlay")
	if not await _wait(func(): return rewards.is_visible_in_tree() and counts.combat_ended == 1, "lethal card damage and death animation naturally open combat rewards"):
		return false
	_check(counts.enemy_dead == 1 and global_data.get_alive_enemies().is_empty(), "enemy dies once with no living combatants remaining")
	_check(counts.played == 5 and counts.player_dead == 0, "combat victory follows five legitimate card plays with player alive")
	_check(not global_data.is_player_in_combat(), "combat stats leave the active combat state")
	_check(global_data.player_data.player_deck.size() == 5, "combat card copies leave the persistent deck intact")
	_snapshot("combat_won")
	if not await _claim_rewards(rewards):
		return false
	rewards.continue_button.button_up.emit()
	if not await _wait(func(): return map.is_visible_in_tree() and map.can_travel, "reward Continue button returns to a travel-enabled map"):
		return false
	_check(not global_data.get_next_locations().is_empty(), "the won encounter has a next map destination")
	_check(global_data.is_run and counts.combat_started == 1, "single-combat test ends on map inside the ongoing run")
	_snapshot("returned_to_map")
	return true


func _defeat_flow() -> bool:
	_check(player.get_combatant_health() == 10 and player.get_block() == 0, "defeat fixture starts combat at ten HP without block")
	_check(counts.played == 0, "defeat scenario passes the first turn without playing cards")
	var losses_before: int = global_data.profile_data.profile_total_losses
	var history_before: int = global_data.profile_data.profile_run_history.size()
	combat.end_turn_button.button_up.emit()
	var summary: Node = game_root.get_node("RunScreen/RunSummaryOverlay")
	if not await _wait(func(): return summary.is_visible_in_tree() and counts.player_death_animation > 0 and _idle(), "enemy attack and player death animation naturally display the defeat summary"):
		return false
	_check(player.get_combatant_health() == 0 and not player.is_alive(), "fourteen-damage enemy attack kills the ten-HP player")
	_check(player_damage_records.size() == 1 and player_damage_records[0] == {"unblocked": 14, "capped": 10, "overkill": 4}, "real damage signal records fourteen damage, ten lost HP and four overkill")
	_check(counts.enemy_turn == 1 and counts.player_dead == 1 and counts.player_death_animation == 1, "one enemy turn emits one player death and one completed death animation")
	_check(counts.hero_action_started == 1 and counts.hero_action_ended == 1, "defeat: one hero action started and ended before the lethal enemy turn")
	_check(enemy.is_alive() and enemy.get_combatant_health() == 65 and counts.enemy_dead == 0, "defeat leaves the attacking enemy alive and untouched")
	_check(summary.defeat_label.visible and not summary.victory_label.visible and summary.player_run_end_state == 1, "summary presents defeat with the native LOSS end state")
	_check(summary.stats_summary_autosize_label.get_parsed_text().contains("Damage Taken"), "defeat summary contains generated run statistics")
	_check(hand.hand_disabled and hand.get_player_hand_cards().is_empty() and hand_manager.player_hand.is_empty(), "dead player has a disabled hand and no selectable hand cards")
	_check(hand_manager.card_play_queue.is_empty() and counts.played == 0, "no card remains queued or executes after lethal enemy damage")
	_check(not game_root.get_node("RunScreen/RewardOverlay").is_visible_in_tree(), "defeat does not offer combat victory rewards")
	_check(not map.is_visible_in_tree(), "defeat cannot travel on the map")
	_snapshot("defeat_summary")
	summary.end_run_button.button_up.emit()
	if not await _wait(func(): return not global_data.is_run and game_root.get_node("TitleScreen/NewRunMenu").is_visible_in_tree(), "defeat End Run button returns to the new-run menu"):
		return false
	_check(not FileAccess.file_exists("res://external/saves/save.json"), "normal defeat settlement removes only the isolated run save")
	_check(global_data.profile_data.profile_total_losses == losses_before + 1, "defeat settlement records exactly one profile loss")
	_check(global_data.profile_data.profile_run_history.size() == history_before + 1 and not global_data.profile_data.profile_run_history.back().run_victory, "defeat settlement stores a loss in run history")
	_check(FileAccess.file_exists("res://external/profile.json"), "defeat settlement saves the isolated profile")
	_check(not summary.visible and not combat.is_visible_in_tree(), "settled defeat closes summary and combat UI")
	_snapshot("defeat_settled")
	return true


func _play(card_id: String, targeted: bool, lethal: bool = false) -> bool:
	var card: Node = _find_hand_card(card_id)
	if not _check(card != null, "hand contains playable " + card_id):
		return false
	var card_data: Resource = card.card_data
	var before_energy: int = global_data.player_data.player_energy
	var before_played: int = counts.played
	_check(card.can_play_card(enemy if targeted else null, false), "card UI accepts legal play: " + card_id)
	card.card_selected.emit(card)
	if targeted:
		_check(hand.current_selected_card == card, "attack selection prompts for its target")
		enemy._on_selection_button_up()
	if not await _wait(func(): return counts.played > before_played and _idle(), "card action queue completes: " + card_id):
		return false
	_check(global_data.player_data.player_energy == before_energy - 1, "card consumes exactly one energy: " + card_id)
	if not lethal:
		_check(not hand_manager.player_hand.has(card_data) and hand_manager.player_discard.has(card_data), "played card moves from hand to discard: " + card_id)
	return true


func _reject_unaffordable_card() -> bool:
	var card: Node = _find_hand_card("card_attack_basic")
	if not _check(card != null, "an extra attack remains for the zero-energy negative case"):
		return false
	var before_hand: int = hand_manager.player_hand.size()
	var before_played: int = counts.played
	var before_hp: int = enemy.get_combatant_health()
	_check(not card.can_play_card(enemy, false), "card UI rejects insufficient energy")
	card.card_selected.emit(card)
	await create_timer(0.2).timeout
	_check(hand.current_selected_card == null, "rejected attack does not request a target")
	_check(counts.played == before_played and hand_manager.player_hand.size() == before_hand, "rejected play neither executes nor removes the card")
	_check(enemy.get_combatant_health() == before_hp and global_data.player_data.player_energy == 0, "rejected play changes neither enemy HP nor energy")
	return true


func _claim_rewards(rewards: Node) -> bool:
	var money_button: Node
	var draft_button: Node
	for button: Node in rewards.reward_container.get_children():
		var path: String = button.get_script().resource_path
		if path.ends_with("/MoneyRewardButton.gd"):
			money_button = button
		elif path.ends_with("/CardRewardButton.gd"):
			draft_button = button
	if not _check(money_button != null and draft_button != null, "normal combat reward generation offers money and card draft"):
		return false
	var amount: int = money_button.action_on_click.values.money_amount
	var money_before: int = global_data.player_data.player_money
	_check(amount > 0, "generated money reward is positive")
	money_button.button_up.emit()
	if not await _wait(func(): return _idle() and global_data.player_data.player_money == money_before + amount, "money reward button grants the displayed amount"):
		return false
	draft_button.button_up.emit()
	var draft: Node = game_root.get_node("RunScreen/CardDraftSelectionOverlay")
	if not await _wait(func(): return draft.is_visible_in_tree() and draft.card_container.get_child_count() > 0, "card reward button opens the real draft picker"):
		return false
	var selected: Node = draft.card_container.get_child(0)
	var selected_id: String = selected.card_data.object_id
	var before_size: int = global_data.player_data.player_deck.size()
	selected.card_selected.emit(selected)
	if not await _wait(func(): return _idle() and not draft.visible, "draft selection completes its action and closes picker"):
		return false
	_check(global_data.player_data.player_deck.size() == before_size + 1, "claimed card increases the persistent deck size by one")
	_check(global_data.player_data.player_deck.back().object_id == selected_id, "claimed card ID matches the selected draft card")
	return true


func _find_hand_card(card_id: String) -> Node:
	for card_data: Resource in hand_manager.player_hand:
		if card_data.object_id == card_id:
			return hand.card_data_to_hand_card.get(card_data)
	return null


func _idle() -> bool:
	return not action_handler.actions_being_performed and not hand_manager.cards_being_played and hand_manager.card_play_queue.is_empty()


func _player_ready() -> bool:
	return global_data.is_player_in_combat() and stats.is_player_turn and not hand.hand_disabled and _idle()


func _wait(predicate: Callable, label: String, seconds: float = 12.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline:
			_snapshot("timeout: " + label)
			return _check(false, label + " (timeout)")
		await create_timer(0.02).timeout
	return _check(true, label)


func _connect_observers() -> void:
	signals.card_drawn.connect(func(_card): counts.drawn += 1)
	signals.card_played.connect(func(_request): counts.played += 1)
	signals.combat_started.connect(func(_event): counts.combat_started += 1)
	signals.combat_ended.connect(func(): counts.combat_ended += 1)
	signals.enemy_turn_started.connect(func(): counts.enemy_turn += 1)
	signals.unit_action_started.connect(func(unit):
		if unit == global_data.get_player():
			counts.hero_action_started += 1
	)
	signals.unit_action_ended.connect(func(unit):
		if unit == global_data.get_player():
			counts.hero_action_ended += 1
	)
	signals.enemy_killed.connect(func(_enemy): counts.enemy_dead += 1)
	signals.player_killed.connect(func(_player): counts.player_dead += 1)
	signals.player_death_animation_finished.connect(func(_player): counts.player_death_animation += 1)
	signals.combatant_damaged.connect(func(target, unblocked, capped, overkill):
		if target == player:
			player_damage_records.append({"unblocked": unblocked, "capped": capped, "overkill": overkill})
	)


func _snapshot(stage: String) -> void:
	var state: Dictionary = {"stage": stage, "signals": counts.duplicate(), "energy": global_data.player_data.player_energy, "health": global_data.player_data.player_health, "hand": hand_manager.player_hand.size(), "draw": hand_manager.player_draw.size(), "discard": hand_manager.player_discard.size(), "deck": global_data.player_data.player_deck.size(), "money": global_data.player_data.player_money}
	if is_instance_valid(enemy):
		state.enemy_health = enemy.get_combatant_health()
	snapshots.append(state)
	print("STATE: " + JSON.stringify(state))


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
		var report: FileAccess = FileAccess.open(output_directory.path_join("combat-result.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"scenario": scenario, "checks": checks, "failures": failures, "assertions": results, "snapshots": snapshots, "player_damage_records": player_damage_records, "boundary": "single combat, declared data fixture, real UI signals/handlers; no physical mouse hit testing or campaign"}, "\t"))
	print("COMBAT %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _timeout() -> void:
	if not finished:
		_check(false, "100-second overall timeout")
		_finish()
