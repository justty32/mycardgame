extends RefCounted
## Explicit intent API fixtures. Save/restore data; never construct a board or module.

func run(c) -> void:
	var director: CombatDirector = c.combat.combat_director
	var enemy: Enemy = c.enemy as Enemy
	var hero: Player = c.player as Player
	var original_data: EnemyData = enemy.enemy_data
	var original_keep: bool = enemy.keep_intent_next_action
	var original_target: BaseCombatant = enemy.intended_target
	var original_block: int = hero.get_block()
	var original_hp: int = hero.get_combatant_health()
	enemy.enemy_data = original_data.duplicate(true)
	enemy.enemy_data.enemy_block = 0
	var intent := EnemyIntentData.new("boardless_fixture_intent")
	intent.enemy_intent_attack_damage = 4
	intent.enemy_intent_number_of_attacks = 1
	intent.enemy_intent_range = 0
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.TELEPORT
	intent.enemy_intent_marked_cell = Vector2i(99, 99)
	for key: String in enemy.enemy_data.enemy_intents:
		enemy.enemy_data.enemy_intents[key] = intent
	# Spatial metadata has no meaning in NONE; ordinary attacks still run against the hero.
	intent.enemy_intent_target_rule = EnemyIntentData.TARGET_RULES.NEAREST
	await EnemyIntentController.perform_intent(director, enemy)
	c._check(original_hp + original_block - hero.get_combatant_health() - hero.get_block() == 4, "NONE uses ordinary hero target without interpreting range, NEAREST distance or teleport metadata")
	c._check(not enemy.keep_intent_next_action, "NONE does not retain an ordinary attack as out of range")
	Global.player_data.player_health = original_hp
	hero.set_block(original_block)

	# Reset -> Block 3 -> SELF attack 4 -> custom Block 2 follows the normal action stack.
	intent.enemy_intent_target_rule = EnemyIntentData.TARGET_RULES.SELF
	intent.enemy_intent_block = 3
	intent.enemy_intent_custom_actions.assign([{Scripts.ACTION_BLOCK: {"block": 2, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}}])
	await _refresh_incoming(c, hero)
	c._check(hero.incoming_damage_amount_text.text == "0" and enemy.intended_target == enemy, "NONE SELF preview targets the enemy and contributes no hero incoming damage")
	var enemy_hp: int = enemy.get_combatant_health()
	await EnemyIntentController.perform_intent(director, enemy)
	c._check(enemy_hp - enemy.get_combatant_health() == 1 and enemy.get_block() == 2, "NONE SELF keeps normal block, self-attack and custom-action ordering")
	c._check(hero.get_combatant_health() == original_hp and hero.get_block() == original_block, "NONE SELF attack never hits the hero")

	# A conditional board-only action rejects the entire intent, not just its custom tail.
	intent.enemy_intent_target_rule = EnemyIntentData.TARGET_RULES.HERO
	intent.enemy_intent_attack_damage = 25
	intent.enemy_intent_block = 99
	intent.enemy_intent_custom_actions.assign([{Scripts.ACTION_VALIDATOR: {"passed_action_data": [{Scripts.ACTION_MOVE_UNIT: {"mode": "TO_CELL", "target_cell": [1, 1]}}]}}])
	c._check(EnemyIntentController.get_plain_intent_error(enemy, intent) == "board_module_required", "NONE pure intent preflight identifies nested board-only effects")
	await _refresh_incoming(c, hero)
	c._check(hero.incoming_damage_amount_text.text == "0", "NONE rejected intent contributes no hero incoming damage")
	enemy_hp = enemy.get_combatant_health()
	var enemy_block: int = enemy.get_block()
	await EnemyIntentController.perform_intent(director, enemy)
	c._check(enemy.keep_intent_next_action and enemy.get_combatant_health() == enemy_hp and enemy.get_block() == enemy_block, "NONE rejection retains the intent and skips reset/block/custom effects")
	c._check(hero.get_combatant_health() == original_hp and hero.get_block() == original_block and c._idle(), "NONE rejection queues no ordinary attack or partial action payload")
	c._check(director.board_module == null and director.battlefield == null and director.threat_preview == null, "NONE intent fixtures never construct a board, module or ThreatPreview")

	enemy.enemy_data = original_data
	enemy.keep_intent_next_action = original_keep
	enemy.intended_target = original_target
	enemy.update_health_bar(false)
	hero.update_health_bar(false)
	await _refresh_incoming(c, hero)

func _refresh_incoming(c, hero: Player) -> void:
	await c._wait(func(): return not hero._intent_is_updating, "previous lazy incoming update completes")
	hero.update_incoming_damage_amount(true)
	await c._wait(func(): return not hero._intent_is_updating, "fixture incoming update completes")
