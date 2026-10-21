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
	c._check(not enemy.keep_intent_next_action and enemy.get_combatant_health() == enemy_hp and enemy.get_block() == enemy_block, "NONE rejection does not retain the intent (no permanent stall) and skips reset/block/custom effects")
	c._check(hero.get_combatant_health() == original_hp and hero.get_block() == original_block and c._idle(), "NONE rejection queues no ordinary attack or partial action payload")
	c._check(director.board_module == null and director.battlefield == null and director.threat_preview == null, "NONE intent fixtures never construct a board, module or ThreatPreview")

	await _rotation_after_rejection(c, director, enemy, hero, intent)

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

## H1 regression: an enemy whose intent needs the board keeps acting with its ordinary intents.
func _rotation_after_rejection(c, director: CombatDirector, enemy: Enemy, hero: Player, board_intent: EnemyIntentData) -> void:
	var saved_hp: int = hero.get_combatant_health()
	var saved_block: int = hero.get_block()
	var ordinary := EnemyIntentData.new("boardless_fixture_ordinary")
	ordinary.enemy_intent_attack_damage = 3
	ordinary.enemy_intent_number_of_attacks = 1
	ordinary.enemy_intent_target_rule = EnemyIntentData.TARGET_RULES.HERO
	var board_id: String = "boardless_fixture_board_only"
	board_intent.object_id = board_id
	board_intent.enemy_intent_next_intent_weights = {ordinary.object_id: 1}
	ordinary.enemy_intent_next_intent_weights = {board_id: 1}
	enemy.enemy_data.enemy_intents.clear()
	enemy.enemy_data.enemy_intents[board_id] = board_intent
	enemy.enemy_data.enemy_intents[ordinary.object_id] = ordinary
	enemy.enemy_data.enemy_intent_current_id = board_id
	enemy.keep_intent_next_action = false
	await EnemyIntentController.perform_intent(director, enemy)
	enemy.decide_next_intent()
	c._check(enemy.enemy_data.get_current_intent() == ordinary, "after a refused board-only intent the enemy rotates to its ordinary intent")
	var before: int = hero.get_combatant_health() + hero.get_block()
	await EnemyIntentController.perform_intent(director, enemy)
	c._check(before - hero.get_combatant_health() - hero.get_block() == 3, "the rotated ordinary intent actually acts (enemy is not stalled)")
	enemy.decide_next_intent()
	c._check(enemy.enemy_data.get_current_intent() == ordinary, "decide_next_intent skips the board-only intent while no board module is mounted")
	enemy.keep_intent_next_action = true
	enemy.enemy_data.enemy_intent_current_id = board_id
	enemy.decide_next_intent()
	c._check(enemy.enemy_data.get_current_intent() == ordinary, "a kept board-only intent is not retained without the module")
	Global.player_data.player_health = saved_hp
	hero.set_block(saved_block)
