extends RefCounted
## Loaded at runtime after autoload registration by ctb_flow.gd.
## Only data fixtures: no combat methods, HP mutation, or outcome signals.
## Hero speed 10 vs two enemies of speed 20 and 5 under the default combat rules
## (delay 100, scale 100): waits are 1000 / 500 / 2000 ticks.

func install() -> void:
	var character: CharacterData = Global.get_character_data("character_red")
	character.character_starting_health = 80
	character.character_starting_money = 100
	character.character_speed = 10
	character.character_starting_artifact_ids.clear()
	character.character_starting_card_object_ids.assign([
		"card_block_basic", "card_block_basic", "card_block_basic",
		"card_block_basic", "card_block_basic"
	])
	Global._id_to_run_start_option_data.clear()
	var option := RunStartOptionData.new("ctb_flow_no_bonus")
	option.run_start_option_bb_code = "CTB test: start without a bonus"
	Global.register_rod(option)

	# status processed every 500 ticks, decaying one charge each time (observable count)
	var status := StatusEffectData.new("ctb_status_tick")
	status.status_effect_name = "Tick Marker"
	status.status_effect_texture_path = Global.get_status_effect_data("status_effect_corrosion").status_effect_texture_path
	status.status_effect_type = StatusEffectData.STATUS_EFFECT_TYPES.NEUTRAL
	status.status_effect_decay_rate = -1
	status.status_effect_tick_interval = 500
	status.status_effect_action_process_times = [StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.EVERY_N_TICKS]
	status.status_effect_player_process_actions = []
	Global.register_rod(status)

	var fast := EnemyData.new("ctb_enemy_fast")
	fast.enemy_name = "CTB Fast"
	fast.enemy_speed = 20
	fast.enemy_animation_id = Global.get_enemy_data("enemy_2").enemy_animation_id
	fast.enemy_health_max_random_lower = 50
	fast.enemy_health_max_random_upper = 50
	fast.add_intent_state([EnemyIntentData.new("intent_initial", 0, 0, 0, "", 0, "", {"intent_guard": 1})])
	fast.add_intent_state([EnemyIntentData.new("intent_guard", 0, 0, 0, "", 1, "", {"intent_guard": 1})])
	Global.register_rod(fast)

	var slow := EnemyData.new("ctb_enemy_slow")
	slow.enemy_name = "CTB Slow"
	slow.enemy_speed = 5
	slow.enemy_animation_id = Global.get_enemy_data("enemy_2").enemy_animation_id
	slow.enemy_health_max_random_lower = 50
	slow.enemy_health_max_random_upper = 50
	slow.add_intent_state([EnemyIntentData.new("intent_initial", 0, 0, 0, "", 0, "", {"intent_poke": 1})])
	slow.add_intent_state([EnemyIntentData.new("intent_poke", 0, 1, 1, "", 0, "", {"intent_poke": 1})])
	Global.register_rod(slow)

	var event := EventData.new("ctb_flow_event")
	event.event_weighted_enemy_object_ids.assign([{"ctb_enemy_fast": 1}, {"ctb_enemy_slow": 1}])
	event.event_initial_combat_actions = [{
		Scripts.ACTION_APPLY_STATUS: {
			"status_effect_object_id": "ctb_status_tick",
			"status_charge_amount": 10,
			"target_override": BaseAction.TARGET_OVERRIDES.PLAYER,
		}
	}]
	Global.register_rod(event)
	print("FIXTURE: seed=20261019; red 80 HP speed 10, deck=5 native Basic Block; enemies fast(speed 20, block 1) and slow(speed 5, 1x1 attack); hero starts with 10 charges of a 500-tick status; default combat rules.")
