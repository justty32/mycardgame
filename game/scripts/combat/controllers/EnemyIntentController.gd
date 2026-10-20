## Executes the current enemy intent, delegating spatial behavior only when a board module is mounted.
extends BaseUnitController
class_name EnemyIntentController

func decide(director: CombatDirector, unit: BaseCombatant) -> Variant:
	await perform_intent(director, unit as Enemy)
	return null

static func perform_intent(director: CombatDirector, enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or not enemy.is_alive():
		return
	if director.board_module != null:
		await director.board_module.perform_enemy_intent(enemy)
		return
	await _perform_plain_intent(director, enemy)

## NONE keeps ordinary attack/block/custom-action behavior without spatial queries or plans.
static func _perform_plain_intent(director: CombatDirector, enemy: Enemy) -> void:
	var generation: int = director.get_generation()
	var intent: EnemyIntentData = enemy.enemy_data.get_current_intent()
	var rejection: String = get_plain_intent_error(enemy, intent)
	if rejection != "":
		enemy.keep_intent_next_action = true
		push_warning("EnemyIntentController: %s for enemy '%s'" % [rejection, enemy.enemy_data.object_id])
		return
	var target: BaseCombatant = UnitRegistry.get_hero()
	if intent != null and intent.enemy_intent_target_rule == EnemyIntentData.TARGET_RULES.SELF:
		target = enemy
	var targets: Array[BaseCombatant] = []
	if is_instance_valid(target) and target.is_alive():
		targets.append(target)
	var payload: Array[Dictionary] = enemy.build_intent_actions_data(intent, director.rules.reset_block_on_action_start, true)
	if intent != null and intent.enemy_intent_audio_path != "" and intent.enemy_intent_number_of_attacks == 0:
		ActionGenerator.generate_sound_action(intent.enemy_intent_audio_path, false)
	var actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, targets, payload, null)
	ActionHandler.add_actions(actions)
	await director.wait_actions(generation)

## Pure capability check shared with the ordinary incoming-damage display.
static func get_plain_intent_error(enemy: Enemy, intent: EnemyIntentData) -> String:
	var payload: Array[Dictionary] = enemy.build_intent_actions_data(intent, false, true)
	var context: Dictionary = Global.player_data.player_values if Global.player_data != null else {}
	return "board_module_required" if BoardContentPolicy.requires_board(payload, context) else ""
