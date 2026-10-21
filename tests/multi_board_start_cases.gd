extends RefCounted
## Real scene requests, ordinary queue and explicit spatial targeting in the same scene.

func run(c) -> void:
	var schema: RefCounted = load(get_script().resource_path.get_base_dir().path_join("prepared_schema_cases.gd")).new()
	var notifications: Array[int] = [0, 0, 0]
	var started: Callable = func(_id): notifications[0] += 1
	var waves: Callable = func(_index): notifications[1] += 1
	var fields: Callable = func(_instance): notifications[2] += 1
	Signals.combat_started.connect(started)
	Signals.wave_started.connect(waves)
	Signals.field_created.connect(fields)
	var encounter := EncounterData.new("multi_start_encounter")
	var wave := EncounterWaveData.new()
	wave.wave_units.assign([{"weights": {"board_dummy": 1}}])
	encounter.encounter_waves.assign([wave])
	Global.register_rod(encounter)
	var event := EventData.new("multi_start_event")
	event.event_encounter_object_id = encounter.object_id
	event.event_has_combat_rewards = false
	Global.register_rod(event)
	for mode: String in ["zero", "legacy", "zero", "explicit"]:
		encounter.encounter_board_setup = {"version": 1, "boards": []} if mode == "zero" else ({} if mode == "legacy" else schema.fixture(3))
		wave.wave_units.assign([{"weights": {"board_dummy": 1}}])
		encounter.encounter_waves.assign([wave])
		if mode == "zero":
			var later := EncounterWaveData.new()
			later.wave_units.assign([{"weights": {"board_dummy": 1}}])
			encounter.encounter_waves.append(later)
		if mode == "explicit":
			wave.wave_units.assign([{"weights": {"board_dummy": 1}, "board_id": "zone_0", "cell": [1, 1]}, {"weights": {"board_dummy": 1}, "board_id": "zone_1", "cell": [1, 1]}, {"weights": {"board_dummy": 1}, "board_id": "zone_2", "cell": [1, 1]}])
			event.event_enemy_placement_is_automatic = false
			event.event_enemy_placement_positions.assign([[0, 0]])
			event.event_weighted_enemy_object_ids.assign([{"board_dummy": 1}])
		var before: int = notifications[0]
		c._check(c.combat.request_combat_start(event.object_id), "normal scene request accepts " + mode)
		await c._wait(c._player_ready, "prepared " + mode + " reaches ordinary player action")
		c._check(notifications[0] == before + 1, "successful start notifies subscribers exactly once: " + mode)
		if mode == "zero":
			c._check(c.combat.combat_module == null and c.director.board_controller == null and c.combat.board_views.is_empty() and c.player.board_id == "" and c.player.board_anchor == BaseCombatant.BOARD_ANCHOR_NONE, "zero truly allocates no board module or presentation and clears prior membership")
			var card := CardData.new("multi_plain_block")
			card.card_name = "Ordinary Block Probe"
			card.card_color_id = "color_white"
			card.card_texture_path = "external/sprites/cards/white/card_white.png"
			card.card_energy_cost = 1
			card.card_requires_target = false
			card.card_play_actions.assign([{Scripts.ACTION_BLOCK: {"block": 3, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}}])
			HandManager.add_cards_to_hand(c._cards([card]))
			var request: CardPlayRequest = HandManager.create_card_play_request(card, null, true, true)
			request.card_destination_pile = card.card_play_destination
			request.card_destination_strategy = card.card_play_destination_strategy
			var energy: int = Global.player_data.player_energy
			var block: int = c.player.get_block()
			HandManager.add_card_to_play_queue(request, true, false)
			await c._wait(c._idle, "zero ordinary paid card settles")
			c._check(Global.player_data.player_energy == energy - 1 and c.player.get_block() == block + 3 and request.module_contexts.is_empty(), "zero retains ordinary card payment and effect")
			var lethal := CardData.new("multi_plain_attack")
			lethal.card_name = "Ordinary Attack Probe"
			lethal.card_color_id = "color_white"
			lethal.card_texture_path = "external/sprites/cards/white/card_white.png"
			lethal.card_energy_cost = 1
			lethal.card_values = {"damage": 1000, "number_of_attacks": 1}
			lethal.card_play_actions.assign([{Scripts.ACTION_ATTACK_GENERATOR: {"time_delay": 0.0}}])
			HandManager.add_cards_to_hand(c._cards([lethal]))
			var attack: CardPlayRequest = HandManager.create_card_play_request(lethal, Global.get_alive_enemies()[0], true, true)
			attack.card_destination_pile = lethal.card_play_destination
			attack.card_destination_strategy = lethal.card_play_destination_strategy
			HandManager.add_card_to_play_queue(attack, true, false)
			await c._wait(c._idle, "zero ordinary attack clears initial wave")
			c.combat.end_turn_button.button_up.emit()
			await c._wait(func(): return c.director.waves.current_wave == 1 and c._player_ready(), "zero advances to its later wave and next ordinary action")
			c._check(c.director.combat_module == null and Global.get_alive_enemies().size() == 1, "new zero encounter retains real later-wave admission without board state")
		elif mode == "explicit":
			c.battlefield = c.director.battlefield
			c._check(c.battlefield.boards.size() == 3 and Global.get_alive_enemies().size() == 3, "formal explicit encounter spawns three boards and three units despite one screen slot")
			var enemy: Enemy = c.battlefield.get_board("zone_2").get_unit_at(Vector2i(1, 1))
			var health: int = enemy.get_combatant_health()
			c._check(await c._play_board("dual_shape_%d" % BoardTargeting.TARGET_SHAPES.SINGLE, "zone_2", Vector2i(1, 1)) == "" and enemy.get_combatant_health() < health, "formal N-board request executes existing spatial targeting on explicit destination")
	var consumables: Node = c.combat.get_node("Consumables")
	consumables.selected_consumable_slot_index = 0
	consumables.consumable_target_requested = true
	consumables.select_target_label.show()
	var inventory: Dictionary = Global.player_data.player_consumable_slot_to_consumable_object_id.duplicate(true)
	# Reject after a real active start: no subscriber side effects and no partial world.
	var status := StatusEffectData.new("multi_preserved_status")
	status.status_effect_texture_path = "external/sprites/cards/white/card_white.png"
	Global.register_rod(status)
	c.player.add_status_effect_charges(status.object_id, 3)
	var rewards: Node = c.game_root.get_node("RunScreen/RewardOverlay")
	var drafts: Array[Array] = []
	var artifacts: Array[String] = []
	var reward_actions: Array[Array] = []
	rewards.add_rewards(777, 11, drafts, artifacts, reward_actions)
	var snapshot: Array = [StatsHandler.current_combat_stats, HandManager.player_hand.duplicate(), Global.player_data.player_energy, notifications.duplicate(), c.player.get_status_charges(status.object_id), rewards.reward_data.duplicate(true)]
	encounter.encounter_board_setup = schema.fixture(3)
	encounter.encounter_board_setup.deployment.hero.cell = [99, 99]
	c._check(not c.combat.request_combat_start(event.object_id), "invalid explicit deployment refuses start")
	c._check(StatsHandler.current_combat_stats == snapshot[0] and HandManager.player_hand == snapshot[1] and Global.player_data.player_energy == snapshot[2] and notifications == snapshot[3], "failed preparation publishes no combat wave field notification and preserves stats hand energy")
	encounter.encounter_board_setup = schema.fixture(1)
	for y: int in 5:
		for x: int in 5:
			encounter.encounter_board_setup.boards[0].get_or_add("blocked_cells", []).append([x, y])
	encounter.encounter_board_setup.boards[0].initial_fields = [{"field_id": "field_probe_enter", "cells": [[0, 0]]}]
	wave.wave_units.assign([{"weights": {"board_dummy": 1}, "board_id": "zone_0", "cell": [1, 1]}])
	c._check(not c.combat.request_combat_start(event.object_id) and c.combat.last_start_error.code == "hero_deployment_full", "valid schema can fail dry deployment without committing trial fields")
	c._check(notifications == snapshot[3] and c.player.get_status_charges(status.object_id) == snapshot[4] and rewards.reward_data == snapshot[5] and HandManager.player_hand == snapshot[1], "dry failure preserves nonempty status and rewards plus hand and publishes no field")
	c._check(c.combat.combat_module == null and not c.director.is_running and c.director.timeline == null and c.combat.end_turn_button.disabled and not c.combat.timeline_bar.visible, "failed start clears module timeline and old combat HUD without fake outcome")
	c._check(consumables.selected_consumable_slot_index == consumables.NO_CONSUMABLE and not consumables.consumable_target_requested and not consumables.select_target_label.visible and Global.player_data.player_consumable_slot_to_consumable_object_id == inventory, "stop clears existing consumable target selection without using or discarding inventory")
	var blocked_card: Card = c.hand.card_data_to_hand_card[HandManager.player_hand[0]]
	var stopped_energy: int = Global.player_data.player_energy
	var stopped_hand: Array[CardData] = HandManager.player_hand.duplicate()
	blocked_card.card_selected.emit(blocked_card)
	c._check(c.hand.hand_disabled and c.hand.current_selected_card == null and Global.player_data.player_energy == stopped_energy and HandManager.player_hand == stopped_hand and HandManager.card_play_queue.is_empty(), "real selection after failed start cannot reserve energy queue or move a retained ordinary card")
	encounter.encounter_board_setup = schema.fixture(1)
	wave.wave_units.assign([{"weights": {"board_dummy": 1}, "board_id": "zone_0", "cell": [1, 1]}])
	var location: LocationData = Global.get_player_location_data()
	var original_event: String = location.location_event_object_id
	location.location_visited = false
	location.location_event_object_id = event.object_id
	c.map.show_map()
	var retry_button: Node = null
	var forward_button: Node = null
	var next_locations: Array = Global.get_next_locations()
	for button: Node in c.map.location_container.get_children():
		if button.location_data == location:
			retry_button = button
		elif next_locations.has(button.location_data):
			forward_button = button
	if forward_button != null:
		c.map._on_map_location_button_up(forward_button)
	c._check(Global.player_data.player_location_id == location.location_id and not c.director.is_running, "unfinished failed encounter cannot be skipped through an adjacent map node")
	c._check(retry_button != null, "failed current combat remains present on retry map")
	if retry_button != null:
		retry_button.button_up.emit()
	await c._wait(c._player_ready, "map retries repaired encounter through normal visit and scene request")
	c._check(location.location_visited and c.combat.last_start_error.is_empty(), "successful retry commits its visited marker after validation")
	c._check(not c.hand.hand_disabled, "successful retry unlocks ordinary card input at the existing player-action phase")
	location.location_event_object_id = original_event
	# A real public field callback cancels this committed setup; no old wave/CTB may follow.
	encounter.encounter_board_setup = schema.fixture(1)
	encounter.encounter_board_setup.boards[0].initial_fields = [{"field_id": "field_probe_enter", "cells": [[0, 0], [1, 0]]}]
	var cancel: Callable = func(_instance):
		if is_instance_valid(c.combat.combat_module):
			c.combat.combat_module.clear()
	Signals.field_created.connect(cancel, CONNECT_ONE_SHOT)
	var waves_before: int = notifications[1]
	var fields_before: int = notifications[2]
	c._check(not c.combat.request_combat_start(event.object_id), "field-created cancellation prevents the old start from proceeding")
	await c.flow.process_frame
	c._check(not c.director.is_running and c.director.timeline == null and notifications[1] == waves_before and notifications[2] == fields_before + 1, "cancelled field commit never starts an old wave or CTB loop")
	encounter.encounter_board_setup = schema.fixture(1)
	var cancel_on_start: Callable = func(_id): c.combat.combat_module.clear()
	Signals.combat_started.connect(cancel_on_start, CONNECT_ONE_SHOT)
	waves_before = notifications[1]
	c._check(not c.combat.request_combat_start(event.object_id), "committed notification clearing the staged same Node invalidates its saved module token")
	await c.flow.process_frame
	c._check(c.director.prepared_encounter == null and not c.director.is_running and c.director.timeline == null and notifications[1] == waves_before and not c.combat.timeline_bar.visible, "start-notification cancellation creates no old timeline wave or lingering HUD")
	Signals.combat_started.disconnect(started)
	Signals.wave_started.disconnect(waves)
	Signals.field_created.disconnect(fields)
