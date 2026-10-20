extends RefCounted
## Loaded at runtime after autoload registration by board_flow.gd.
## Only data fixtures: no combat methods, HP mutation, or outcome signals.
## Rules patch (in memory): 1 free move per action, 2 paid cells at +20 delay each. Board 7x5 with
## the hero deployed at (3,4); wave 0 = a 1x1 dummy at (0,0) and a 2x2 dummy at (5,0). Dummies are
## slow (speed 1) and idle; the framework's moving test enemies are used for intent movement.

func install() -> void:
	var rules: CombatRulesData = Global.get_combat_rules()
	rules.free_move_per_action = 1
	rules.paid_move_max_cells = 2
	rules.extra_move_delay_per_cell = 20

	var character: CharacterData = Global.get_character_data("character_red")
	character.character_starting_health = 200
	character.character_starting_money = 100
	character.character_speed = 10
	character.character_starting_artifact_ids.clear()
	character.character_starting_card_object_ids.assign([
		"card_block_basic", "card_block_basic", "card_block_basic",
		"card_block_basic", "card_block_basic"
	])
	Global._id_to_run_start_option_data.clear()
	var option := RunStartOptionData.new("board_flow_no_bonus")
	option.run_start_option_bb_code = "Board test: start without a bonus"
	Global.register_rod(option)

	var animation_id: String = Global.get_enemy_data("enemy_2").enemy_animation_id
	_add_enemy("board_dummy", Vector2i(1, 1), 1, 0, 0, 1, -1, EnemyIntentData.MOVE_MODES.HOLD, animation_id)
	_add_enemy("board_big", Vector2i(2, 2), 1, 0, 0, 1, -1, EnemyIntentData.MOVE_MODES.HOLD, animation_id)
	_add_enemy("board_approacher", Vector2i(1, 1), 15, 5, 1, 2, 1, EnemyIntentData.MOVE_MODES.APPROACH, animation_id)
	# framework examples: the charger acts once between two hero actions at speed 15
	Global.get_enemy_data("enemy_test_charger").enemy_speed = 15
	Global.get_enemy_data("enemy_test_charger").enemy_animation_id = animation_id
	Global.get_enemy_data("enemy_test_archer").enemy_animation_id = animation_id

	_add_card("board_card_reach1", 1, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"damage": 5, "number_of_attacks": 1}, [{Scripts.ACTION_ATTACK_GENERATOR: {"time_delay": 0.0}}])
	_add_card("board_card_cross", 4, BoardTargeting.TARGET_SHAPES.CROSS, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"damage": 2, "number_of_attacks": 1}, [{Scripts.ACTION_ATTACK_GENERATOR: {"time_delay": 0.0}}])
	_add_card("board_card_pierce", -1, BoardTargeting.TARGET_SHAPES.LINE_PIERCE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"damage": 2, "number_of_attacks": 1}, [{Scripts.ACTION_ATTACK_GENERATOR: {"time_delay": 0.0}}])
	_add_card("board_card_any", -1, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"damage": 1, "number_of_attacks": 1}, [{Scripts.ACTION_ATTACK_GENERATOR: {"time_delay": 0.0}}])
	_add_card("board_card_compute", -1, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {}, [{Scripts.ACTION_COMPUTE_BOARD_VALUE: {}}])
	_add_card("board_card_shove_wall", 1, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"distance": 1, "collision_damage_per_cell": 3, "collision_damage_to_blocker": 3}, [{Scripts.ACTION_DISPLACE_UNIT: {"mode": ActionDisplaceUnit.MODE_PUSH}}])
	_add_card("board_card_swap", -1, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.ANY, {}, [{Scripts.ACTION_DISPLACE_UNIT: {"mode": ActionDisplaceUnit.MODE_SWAP}}])
	_add_card("board_card_pull", -1, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {}, [{Scripts.ACTION_DISPLACE_UNIT: {"mode": ActionDisplaceUnit.MODE_PULL_ADJACENT}}])
	var far_only: CardData = _add_card("board_card_far_only", -1, BoardTargeting.TARGET_SHAPES.SINGLE, BoardTargeting.TARGET_FACTIONS.OPPONENT, {"block": 1}, [{Scripts.ACTION_BLOCK: {"target_override": BaseAction.TARGET_OVERRIDES.PARENT}}])
	far_only.card_requires_target = false
	far_only.card_play_validators = [{Scripts.VALIDATOR_DISTANCE: {"to": "NEAREST_OPPONENT", "operator": ">=", "comparison_value": 3}}]

	var encounter := EncounterData.new("board_flow_encounter")
	# This suite preserves historical shared-board distance/occupancy assertions.
	encounter.encounter_board_mode = CombatRulesData.BOARD_MODES.SINGLE
	encounter.encounter_board_size = Vector2i(7, 5)
	encounter.encounter_deploy_cells.assign([[3, 4]])
	var wave := EncounterWaveData.new()
	wave.wave_units.assign([
		{"weights": {"board_dummy": 1}, "cell": [0, 0]},
		{"weights": {"board_big": 1}, "cell": [5, 0]},
	])
	encounter.encounter_waves.assign([wave])
	Global.register_rod(encounter)

	var event := EventData.new("board_flow_event")
	event.event_encounter_object_id = "board_flow_encounter"
	event.event_weighted_enemy_object_ids.assign([{"board_dummy": 1}])
	Global.register_rod(event)
	print("FIXTURE: seed=20261019; red 200 HP speed 10, deck=5 native Basic Block; rules free move 1, paid 2 cells x 20 delay; 7x5 board, hero (3,4), idle dummies 1x1 (0,0) and 2x2 (5,0); test cards cost 0.")

func _add_enemy(object_id: String, footprint: Vector2i, speed: int, damage: int, intent_range: int, move_range: int, preferred_range: int, move_mode: int, animation_id: String) -> void:
	var enemy := EnemyData.new(object_id)
	enemy.enemy_name = object_id.capitalize()
	enemy.enemy_animation_id = animation_id
	enemy.enemy_footprint = footprint
	enemy.enemy_speed = speed
	enemy.enemy_move_range = move_range
	enemy.enemy_health_max_random_lower = 300
	enemy.enemy_health_max_random_upper = 300
	var attacks: int = 1 if damage > 0 else 0
	var intent := EnemyIntentData.new("intent_board", 0, damage, attacks, "", 0, "", {"intent_board": 1})
	intent.enemy_intent_range = intent_range if damage > 0 else -1
	intent.enemy_intent_preferred_range = preferred_range
	intent.enemy_intent_move = move_mode
	enemy.add_intent_state([EnemyIntentData.new("intent_initial", 0, 0, 0, "", 0, "", {"intent_board": 1})])
	enemy.add_intent_state([intent])
	Global.register_rod(enemy)

func _add_card(object_id: String, card_range: int, shape: int, faction: int, card_values: Dictionary, actions: Array[Dictionary]) -> CardData:
	var card := CardData.new(object_id)
	card.card_name = object_id.capitalize()
	card.card_color_id = "color_white"
	card.card_texture_path = "external/sprites/cards/white/card_white.png"
	card.card_description = object_id
	card.card_rarity = CardData.CARD_RARITIES.GENERATED
	card.card_appears_in_card_packs = false
	card.card_energy_cost = 0
	card.card_range = card_range
	card.card_shape = shape
	card.card_target_faction = faction
	card.card_values = card_values
	card.card_play_actions = actions
	Global.register_rod(card)
	return card
