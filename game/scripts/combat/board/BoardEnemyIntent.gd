## Board-module enemy execution: resolve movement and geometry, then perform the intent.
## Membership is re-read after reactions; a missing board rejects execution.
extends RefCounted
class_name BoardEnemyIntent

static func perform_intent(director: CombatDirector, enemy: Enemy) -> void:
	var generation: int = director.get_generation()
	if not is_instance_valid(enemy) or not enemy.is_alive():
		return
	var board: BoardData = BoardData.get_for_unit(enemy)
	if board == null:
		return
	var enemy_intent: EnemyIntentData = enemy.enemy_data.get_current_intent()
	var target: BaseCombatant = IntentResolver.choose_target(board, enemy, enemy_intent)
	var plan: Dictionary = IntentResolver.resolve(board, enemy, enemy_intent, target)
	if plan.get("error", "") not in ["", "out_of_range"]:
		enemy.keep_intent_next_action = true
		return
	var move_after: bool = enemy_intent != null and enemy_intent.enemy_intent_move_after
	if not move_after:
		await _perform_move(director, enemy, enemy_intent, plan, generation)
		if director.is_aborted(generation) or not is_instance_valid(enemy) or not enemy.is_alive():
			return
		# A cell reaction can transfer the mover without killing it.
		board = BoardData.get_for_unit(enemy)
		if board == null:
			return
	var hit: Dictionary = IntentResolver.hits_from(board, enemy, enemy.board_anchor, enemy_intent, target)
	if hit.get("error", "") not in ["", "out_of_range"]:
		enemy.keep_intent_next_action = true
		return
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
	elif is_instance_valid(target) and target.is_alive():
		targets.append(target)
	var enemy_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, targets, enemy_actions_data, null)
	ActionHandler.add_actions(enemy_actions)
	await director.wait_actions(generation)
	if move_after and not director.is_aborted(generation) and is_instance_valid(enemy) and enemy.is_alive():
		# Custom actions can transfer either participant. Re-read membership after the wait.
		board = BoardData.get_for_unit(enemy)
		if board == null:
			return
		if not is_instance_valid(target) or not target.is_alive():
			target = IntentResolver.choose_target(board, enemy, enemy_intent)
		plan = IntentResolver.resolve(board, enemy, enemy_intent, target)
		await _perform_move(director, enemy, enemy_intent, plan, generation)

static func _perform_move(director: CombatDirector, enemy: Enemy, intent: EnemyIntentData, plan: Dictionary, generation: int) -> void:
	var board: BoardData = BoardData.get_for_unit(enemy)
	if board == null or intent == null or plan["move_cell"] == enemy.board_anchor:
		return
	var path: Array = plan.get("path", [])
	var teleport: bool = intent.enemy_intent_move == EnemyIntentData.MOVE_MODES.TELEPORT
	var values: Dictionary = {
		"mode": ActionMoveUnit.MODE_TELEPORT if teleport else ActionMoveUnit.MODE_TO_CELL,
		"target_cell": plan["move_cell"], "planned_path": path,
		"distance": -1 if teleport else path.size(),
		"target_override": BaseAction.TARGET_OVERRIDES.PARENT
	}
	if intent.enemy_intent_move == EnemyIntentData.MOVE_MODES.CHARGE:
		values["path_actions"] = intent.enemy_intent_path_actions
		values["charge"] = true
	var move_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, [enemy], [{Scripts.ACTION_MOVE_UNIT: values}], null)
	ActionHandler.add_actions(move_actions)
	await director.wait_actions(generation)
