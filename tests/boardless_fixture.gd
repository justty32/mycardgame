extends "combat_fixture.gd"
## Declared regression fixtures only; not the neutral demo's authored campaign.
func install(scenario: String = "victory") -> void:
	super.install(scenario)
	var rules: CombatRulesData = Global.get_combat_rules()
	rules.board_enabled = false
	if scenario != "defeat":
		var enemy: EnemyData = Global.get_enemy_data("combat_flow_enemy")
		enemy.enemy_health_max_random_lower = 200
		enemy.enemy_health_max_random_upper = 200
