## Enemy unit: performs the intent decided when it last entered the timeline
## (Enemy.decide_next_intent). Moves by the intent's move mode (IntentResolver), then performs the
## intent against what it hits from there. An attack that cannot reach its target is skipped and the
## intent is kept for the enemy's next action.
extends BaseUnitController
class_name EnemyIntentController

func decide(director: CombatDirector, unit: BaseCombatant) -> Variant:
	await perform_intent(director, unit as Enemy)
	return null

static func perform_intent(director: CombatDirector, enemy: Enemy) -> void:
	var generation: int = director.get_generation()
	if enemy == null or not enemy.is_alive():
		return
	var board: BoardData = director.board
	var enemy_intent: EnemyIntentData = enemy.enemy_data.get_current_intent()
	var target: BaseCombatant = IntentResolver.choose_target(board, enemy, enemy_intent)
	var plan: Dictionary = IntentResolver.resolve(board, enemy, enemy_intent, target)
	var path: Array = plan.get("path", [])
	if board != null and not path.is_empty() and plan["move_cell"] != enemy.board_anchor:
		var move_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, [enemy], [{
			Scripts.ACTION_MOVE_UNIT: {"mode": ActionMoveUnit.MODE_TO_CELL, "target_cell": plan["move_cell"], "distance": len(path), "target_override": BaseAction.TARGET_OVERRIDES.PARENT}
		}], null)
		ActionHandler.add_actions(move_actions)
		await director.wait_actions(generation)
		if director.is_aborted(generation) or not enemy.is_alive():
			return
	var hit: Dictionary = IntentResolver.hits_from(board, enemy, enemy.board_anchor, enemy_intent, target)
	var can_hit: bool = hit["can_hit"]
	if enemy_intent != null and enemy_intent.enemy_intent_number_of_attacks > 0 and not can_hit:
		enemy.keep_intent_next_action = true
	var enemy_actions_data: Array[Dictionary] = enemy.build_intent_actions_data(enemy_intent, director.rules.reset_block_on_action_start, can_hit)
	# play intent sound if one exists and no attacks
	if enemy_intent != null and enemy_intent.enemy_intent_audio_path != "" and enemy_intent.enemy_intent_number_of_attacks == 0:
		ActionGenerator.generate_sound_action(enemy_intent.enemy_intent_audio_path, false)
	var targets: Array[BaseCombatant] = []
	if can_hit:
		targets.assign(hit["targets"])
	elif target != null:
		targets.append(target)
	var enemy_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, targets, enemy_actions_data, null)
	ActionHandler.add_actions(enemy_actions)
	await director.wait_actions(generation)
