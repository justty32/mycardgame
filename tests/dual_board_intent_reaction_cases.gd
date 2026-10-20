extends RefCounted
## The controller must re-read membership after movement/attack reactions, not cache a board.

func run(c) -> void:
	var enemy: Enemy = c.enemy as Enemy
	var hero: BaseCombatant = c.player
	var original: EnemyData = enemy.enemy_data
	var saved_move: int = enemy.cells_moved_this_action
	var saved_keep: bool = enemy.keep_intent_next_action
	var original_enemy: BoardPosition = BoardPosition.from_unit(enemy)
	var original_hero: BoardPosition = BoardPosition.from_unit(hero)
	enemy.enemy_data = original.duplicate(true)
	var intent := EnemyIntentData.new("intent_reaction_board")
	intent.enemy_intent_attack_damage = 4
	intent.enemy_intent_number_of_attacks = 1
	intent.enemy_intent_range = 1
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.TELEPORT
	intent.enemy_intent_teleport_rule = EnemyIntentData.TELEPORT_RULES.MARKED_CELL
	intent.enemy_intent_marked_cell = Vector2i(3, 3)
	for key: String in enemy.enemy_data.enemy_intents:
		enemy.enemy_data.enemy_intents[key] = intent
	var field := FieldData.new("dual_intent_reaction_transfer")
	field.field_on_enter_actions.assign([{Scripts.ACTION_MOVE_UNIT: {
		"mode": "TELEPORT", "distance": -1, "target_override": BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS,
		"target_board_id": "party", "target_cell": Vector2i(0, 0)
	}}])
	Global.register_rod(field)
	await c.create_field(field.object_id, [Vector2i(3, 3)], hero, {"board_id": "enemy"})
	var before: int = hero.get_combatant_health()
	await EnemyIntentController.perform_intent(c.director, enemy)
	c._check(enemy.board_id == "party" and enemy.board_anchor == Vector2i(0, 0), "intent movement field reaction transfers the surviving enemy to the hero board")
	c._check(hero.get_combatant_health() == before and enemy.keep_intent_next_action, "post-movement hit query uses actual new board range and skips out-of-range attack")
	await c.run_actions(hero, [], [{c.REMOVE_FIELD: {"field_id": field.object_id, "board_id": "enemy"}}])
	c._check(c.battlefield.transfer(enemy, original_enemy), "restore enemy before move_after reaction")
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.RETREAT
	intent.enemy_intent_move_distance = 1
	intent.enemy_intent_move_after = true
	intent.enemy_intent_custom_actions.assign([{Scripts.ACTION_MOVE_UNIT: {
		"mode": "TELEPORT", "distance": -1, "target_override": BaseAction.TARGET_OVERRIDES.PARENT,
		"target_board_id": "party", "target_cell": Vector2i(3, 3)
	}}])
	before = hero.get_combatant_health()
	await EnemyIntentController.perform_intent(c.director, enemy)
	c._check(enemy.board_id == "party" and enemy.board_anchor == Vector2i(3, 2), "move_after re-resolves retreat on the board entered by attack custom actions")
	c._check(before - hero.get_combatant_health() == 4, "move_after reaction still performs the original cross-board attack once")
	enemy.enemy_data = original
	enemy.cells_moved_this_action = saved_move
	enemy.keep_intent_next_action = saved_keep
	c._check(c.battlefield.transfer(enemy, original_enemy), "restore enemy after reaction intent cases")
	c._check(hero.board_id == original_hero.board_id and hero.board_anchor == original_hero.cell, "reaction cases keep the hero's position")
	await _target_rules(c)
	c.director.refresh_threats()

func _target_rules(c) -> void:
	var enemy: Enemy = c.enemy as Enemy
	var hero: BaseCombatant = c.player
	var big: BaseCombatant = c.enemy_board.get_unit_at(Vector2i(5, 0))
	if not c._check(big != null, "distance target rules have the original large-unit fixture"):
		return
	var original_data: EnemyData = enemy.enemy_data
	var original_hero := BoardPosition.from_unit(hero)
	var original_big := BoardPosition.from_unit(big)
	var original_faction: int = big.faction
	var original_keep: bool = enemy.keep_intent_next_action
	big.faction = BaseCombatant.FACTIONS.PARTY
	enemy.enemy_data = original_data.duplicate(true)
	var intent := EnemyIntentData.new("intent_distance_target_rules")
	intent.enemy_intent_attack_damage = 4
	intent.enemy_intent_number_of_attacks = 1
	intent.enemy_intent_range = -1
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.HOLD
	for key: String in enemy.enemy_data.enemy_intents:
		enemy.enemy_data.enemy_intents[key] = intent
	for rule: int in [EnemyIntentData.TARGET_RULES.NEAREST, EnemyIntentData.TARGET_RULES.FARTHEST]:
		intent.enemy_intent_target_rule = rule
		c._check(IntentResolver.choose_target(c.enemy_board, enemy, intent) == big, "distance rule %d prefers comparable same-board opponent over cross-board hero at equal coordinates" % rule)

	c._check(c.battlefield.transfer(hero, BoardPosition.new("enemy", Vector2i(2, 4))), "place near local target for distance comparisons")
	c._check(c.enemy_board.unit_distance(enemy, hero) < c.enemy_board.unit_distance(enemy, big), "local distance fixture has distinct real footprint distances")
	for rule: int in [EnemyIntentData.TARGET_RULES.NEAREST, EnemyIntentData.TARGET_RULES.FARTHEST]:
		intent.enemy_intent_target_rule = rule
		var expected: BaseCombatant = hero if rule == EnemyIntentData.TARGET_RULES.NEAREST else big
		var other: BaseCombatant = big if expected == hero else hero
		await _target_preview_execution(c, enemy, expected, other, "same-board real distance %d" % rule)

	c._check(c.battlefield.transfer(hero, original_hero), "restore hero before cross-board UID fallback")
	c._check(c.battlefield.transfer(big, BoardPosition.new("party", Vector2i(5, 0))), "move all target candidates onto the other board")
	var stable: BaseCombatant = hero if hero.unit_uid < big.unit_uid else big
	for rule: int in [EnemyIntentData.TARGET_RULES.NEAREST, EnemyIntentData.TARGET_RULES.FARTHEST]:
		intent.enemy_intent_target_rule = rule
		c._check(IntentResolver.choose_target(c.enemy_board, enemy, intent) == stable, "distance rule %d without local candidates uses stable UID, not cross-board coordinates" % rule)
		await _target_preview_execution(c, enemy, stable, big if stable == hero else hero, "cross-board stable UID %d" % rule)

	enemy.enemy_data = original_data
	enemy.keep_intent_next_action = original_keep
	big.faction = original_faction
	c._check(c.battlefield.transfer(big, original_big), "restore large fixture after target rule tests")

func _target_preview_execution(c, enemy: Enemy, expected: BaseCombatant, other: BaseCombatant, label: String) -> void:
	c.director.refresh_threats()
	var plan: Dictionary = c.director.threat_preview.get_plan(enemy)
	c._check(plan.get("target") == expected and plan.get("targets", []).has(expected) and plan.get("can_hit", false), label + ": threat preview resolves expected target")
	var before_expected: int = expected.get_combatant_health() + expected.get_block()
	var before_other: int = other.get_combatant_health() + other.get_block()
	await EnemyIntentController.perform_intent(c.director, enemy)
	c._check(before_expected - expected.get_combatant_health() - expected.get_block() == 4, label + ": controller damages the previewed target once")
	c._check(before_other == other.get_combatant_health() + other.get_block(), label + ": other candidate is not hit")
