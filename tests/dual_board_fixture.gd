extends "field_fixture.gd"
## Same real-run card data setup, but deliberately inherits the production DUAL default.

func install() -> void:
	super.install()
	var encounter: EncounterData = Global.get_encounter_data("board_flow_encounter")
	encounter.encounter_board_mode = -1
	encounter.encounter_initial_fields.clear()
	encounter.encounter_boards = {
		"party": {"size": [7, 5], "deploy_cells": [[3, 4]], "initial_fields": []},
		"enemy": {"size": [7, 5], "initial_fields": []},
	}
	encounter.encounter_waves[0].wave_units.assign([
		{"weights": {"board_dummy": 1}, "cell": [3, 4], "board_id": "enemy"},
		{"weights": {"board_big": 1}, "cell": [5, 0], "board_id": "enemy"},
	])
	var second_wave := EncounterWaveData.new()
	second_wave.wave_enter_delay_ticks = 300
	second_wave.wave_units.assign([
		{"weights": {"board_dummy": 1}, "cell": [1, 1], "board_id": "party"},
		{"weights": {"board_dummy": 1}, "cell": [1, 1], "board_id": "enemy"},
	])
	encounter.encounter_waves.append(second_wave)
	_add_card("dual_finish", -1, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"damage": 1000, "number_of_attacks": 1}, [{Scripts.ACTION_ATTACK_GENERATOR: {"time_delay": 0.0}}])
	for shape: int in [BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_SHAPES.ROW, BoardTargeting.TARGET_SHAPES.COLUMN, BoardTargeting.TARGET_SHAPES.CROSS, BoardTargeting.TARGET_SHAPES.SQUARE_3, BoardTargeting.TARGET_SHAPES.LINE, BoardTargeting.TARGET_SHAPES.LINE_PIERCE]:
		var card: CardData = _add_card("dual_shape_%d" % shape, 0, shape, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"damage": 2, "number_of_attacks": 1}, [{Scripts.ACTION_ATTACK_GENERATOR: {"time_delay": 0.0}}])
		card.card_energy_cost = 1
	var push: CardData = _add_card("dual_push", 9, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {}, [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PUSH", "distance": 1}}])
	push.card_energy_cost = 1
	var blink: CardData = _add_card("dual_transfer", 0, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.EMPTY_CELL, {}, [{Scripts.ACTION_MOVE_UNIT: {"mode": "TELEPORT", "target_board_id": "SELECTED"}}])
	blink.card_energy_cost = 1
	var swap: CardData = _add_card("dual_swap", 0, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.ANY, {}, [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "SWAP"}}])
	swap.card_energy_cost = 1
	var nested: CardData = _add_card("dual_nested_push", 9, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"hidden_direction": "PUSH"}, [{Scripts.ACTION_VALIDATOR: {"passed_action_data": [{Scripts.ACTION_DISPLACE_UNIT: {"custom_key_names": {"mode": "hidden_direction"}, "distance": 1}}]}}])
	nested.card_energy_cost = 1
	var wrapper: CardData = _add_card("dual_wrapper_pull", 9, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"hidden_branch": [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "PULL", "distance": 1}}]}, [{Scripts.ACTION_VALIDATOR: {"custom_key_names": {"passed_action_data": "hidden_branch"}}}])
	wrapper.card_energy_cost = 1
	print("DUAL FIXTURE: production board_mode inherited, two 7x5 boards, hero and dummy share local (3,4) on different boards; test cards cost 1.")
