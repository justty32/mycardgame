extends RefCounted
## Loaded at runtime after autoload registration by combat_flow.gd.
## Only data fixtures: no combat methods, HP mutation, or outcome signals.

func install(scenario: String = "victory") -> void:
	var character: CharacterData = Global.get_character_data("character_red")
	character.character_starting_health = 10 if scenario == "defeat" else 80
	character.character_starting_money = 100
	character.character_starting_artifact_ids.clear()
	character.character_starting_card_object_ids.assign([
		"card_attack_basic", "card_attack_basic", "card_attack_basic",
		"card_block_basic", "card_block_basic"
	])
	# One explicit no-bonus option avoids unrelated draft/artifact side effects.
	Global._id_to_run_start_option_data.clear()
	var option := RunStartOptionData.new("combat_flow_no_bonus")
	option.run_start_option_bb_code = "Combat test: start without a bonus"
	Global.register_rod(option)

	var enemy := EnemyData.new("combat_flow_enemy")
	enemy.enemy_name = "Combat Flow Fixture"
	enemy.enemy_animation_id = Global.get_enemy_data("enemy_2").enemy_animation_id
	enemy.enemy_health_max_random_lower = 65
	enemy.enemy_health_max_random_upper = 65
	enemy.add_intent_state([
		EnemyIntentData.new("intent_initial", 0, 0, 0, "", 0, "", {"intent_test_attack": 1})
	])
	enemy.add_intent_state([
		EnemyIntentData.new("intent_test_attack", 0, 14, 1, "", 0, "", {"intent_test_attack": 1})
	])
	Global.register_rod(enemy)
	var event := EventData.new("combat_flow_event")
	event.event_weighted_enemy_object_ids.assign([{"combat_flow_enemy": 1}])
	Global.register_rod(event)
	print("FIXTURE: scenario=%s; seed=20261019; red=%d HP/100 money/no artifacts; deck=3 native Basic Attack +2 native Basic Block; no-bonus start option; one 65 HP enemy with 14x1 intent; normal map/reward generation." % [scenario, character.character_starting_health])
