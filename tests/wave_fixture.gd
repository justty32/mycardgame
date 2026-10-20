extends RefCounted
## Loaded at runtime after autoload registration by wave_flow.gd.
## Only data fixtures: no combat methods, HP mutation, or outcome signals.
## Default 5x5 board, hero on (2,4), speed 10 everywhere (one action per 1000 ticks). Enemies are
## idle (no damage, HOLD). Three waves, each wave_on_cleared_actions adds 10 money:
## - wave 0: grunt at (2,0).
## - wave 1 (WAIT_UNTIL_FREE, retry 50 x2, enter 300, stagger 100): minion at (0,0) enters at
##   clear + 300; grunt for (0,0) at clear + 400 waits twice (450, 500), then NEAREST_EMPTY -> (1,0).
## - wave 2 (FAIL_SKIP, enter 200): grunt for (0,0) (still the minion's) is skipped; grunt at (4,0).

const GRUNT: String = "wave_grunt"
const MINION: String = "wave_minion"
const STRIKE: String = "wave_card_strike"

func install() -> void:
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
	var option := RunStartOptionData.new("wave_flow_no_bonus")
	option.run_start_option_bb_code = "Wave test: start without a bonus"
	Global.register_rod(option)

	var animation_id: String = Global.get_enemy_data("enemy_2").enemy_animation_id
	_add_enemy(GRUNT, 5, false, animation_id)
	_add_enemy(MINION, 300, true, animation_id)

	var strike := CardData.new(STRIKE)
	strike.card_name = "Wave Strike"
	strike.card_color_id = "color_white"
	strike.card_texture_path = "external/sprites/cards/white/card_white.png"
	strike.card_description = STRIKE
	strike.card_rarity = CardData.CARD_RARITIES.GENERATED
	strike.card_appears_in_card_packs = false
	strike.card_energy_cost = 0
	strike.card_values = {"damage": 10, "number_of_attacks": 1}
	strike.card_play_actions = [{Scripts.ACTION_ATTACK_GENERATOR: {"time_delay": 0.0}}]
	Global.register_rod(strike)

	var reward: Array[Dictionary] = [{Scripts.ACTION_ADD_MONEY: {"money_amount": 10}}]
	var wave_0 := EncounterWaveData.new()
	wave_0.wave_units.assign([{"weights": {GRUNT: 1}, "cell": [2, 0]}])
	wave_0.wave_on_cleared_actions.assign(reward)
	var wave_1 := EncounterWaveData.new()
	wave_1.wave_enter_delay_ticks = 300
	wave_1.wave_stagger_ticks = 100
	wave_1.wave_spawn_policy = EncounterWaveData.SPAWN_POLICIES.WAIT_UNTIL_FREE
	wave_1.wave_spawn_retry_ticks = 50
	wave_1.wave_spawn_max_retries = 2
	wave_1.wave_units.assign([{"weights": {MINION: 1}, "cell": [0, 0]}, {"weights": {GRUNT: 1}, "cell": [0, 0]}])
	wave_1.wave_on_cleared_actions.assign(reward)
	var wave_2 := EncounterWaveData.new()
	wave_2.wave_enter_delay_ticks = 200
	wave_2.wave_spawn_policy = EncounterWaveData.SPAWN_POLICIES.FAIL_SKIP
	wave_2.wave_units.assign([{"weights": {GRUNT: 1}, "cell": [0, 0]}, {"weights": {GRUNT: 1}, "cell": [4, 0]}])
	wave_2.wave_on_cleared_actions.assign(reward)

	var encounter := EncounterData.new("wave_flow_encounter")
	# Historical wave spawn cells share one board; DualBoard separately verifies the default.
	encounter.encounter_board_mode = CombatRulesData.BOARD_MODES.SINGLE
	encounter.encounter_waves.assign([wave_0, wave_1, wave_2])
	Global.register_rod(encounter)

	var event := EventData.new("wave_flow_event")
	event.event_encounter_object_id = "wave_flow_encounter"
	event.event_weighted_enemy_object_ids.assign([{GRUNT: 1}])
	Global.register_rod(event)
	print("FIXTURE: seed=20261019; red 200 HP speed 10, deck=5 native Basic Block; default 5x5 board, hero (2,4); idle grunts (5 HP) and a minion (300 HP); waves 0/1/2 add 10 money each on clear; strike card 10 damage, cost 0.")

func _add_enemy(object_id: String, health: int, is_minion: bool, animation_id: String) -> void:
	var enemy := EnemyData.new(object_id)
	enemy.enemy_name = object_id.capitalize()
	enemy.enemy_animation_id = animation_id
	enemy.enemy_speed = 10
	enemy.enemy_is_minion = is_minion
	enemy.enemy_health_max_random_lower = health
	enemy.enemy_health_max_random_upper = health
	enemy.add_intent_state([EnemyIntentData.new("intent_initial", 0, 0, 0, "", 0, "", {"intent_wave_idle": 1})])
	enemy.add_intent_state([EnemyIntentData.new("intent_wave_idle", 0, 0, 0, "", 0, "", {"intent_wave_idle": 1})])
	Global.register_rod(enemy)
