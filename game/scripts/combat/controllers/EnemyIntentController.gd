## Executes the current enemy intent. A mounted module that handles intents (the board: movement,
## geometry) performs it; otherwise the core keeps ordinary attack/block/custom-action behavior.
## Intents whose payload needs an unmounted module (CombatContentRequirements) are refused as a
## whole and never become a permanent stall: the enemy rotates to its next intent after the action
## and Enemy.decide_next_intent skips unavailable intents.
extends BaseUnitController
class_name EnemyIntentController

func decide(director: CombatDirector, unit: BaseCombatant) -> Variant:
	await perform_intent(director, unit as Enemy)
	return null

static func perform_intent(director: CombatDirector, enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or not enemy.is_alive():
		return
	var module: CombatModule = director.combat_module
	if module != null and module.handles_enemy_intents():
		await module.perform_enemy_intent(enemy)
		return
	await _perform_plain_intent(director, enemy)

## Without an intent-handling module: no spatial queries or plans.
static func _perform_plain_intent(director: CombatDirector, enemy: Enemy) -> void:
	var generation: int = director.get_generation()
	var intent: EnemyIntentData = enemy.enemy_data.get_current_intent()
	var rejection: String = get_intent_module_error(enemy, intent)
	if rejection != "":
		# Rejected whole (no partial payload). Not kept: decide_next_intent rotates afterwards.
		enemy.keep_intent_next_action = false
		push_warning("EnemyIntentController: %s for enemy '%s'; rotating intent" % [rejection, enemy.enemy_data.object_id])
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

## Pure capability check: "" when every module the intent's payload needs is mounted, else the
## rejection ("board_module_required"). Shared by execution, intent choice and the damage display.
static func get_intent_module_error(enemy: Enemy, intent: EnemyIntentData) -> String:
	if enemy == null or intent == null:
		return ""
	var payload: Array[Dictionary] = enemy.build_intent_actions_data(intent, false, true)
	var context: Dictionary = Global.player_data.player_values if Global.player_data != null else {}
	var required: Array[StringName] = CombatContentRequirements.payload_requirements(payload, context)
	if required.is_empty():
		return ""
	var director: CombatDirector = Global.get_combat_director()
	var mounted: Array[StringName] = director.get_mounted_module_ids() if director != null else ([] as Array[StringName])
	return CombatContentRequirements.missing_rejection(required, mounted)

## Compatibility name (tests / older callers).
static func get_plain_intent_error(enemy: Enemy, intent: EnemyIntentData) -> String:
	return get_intent_module_error(enemy, intent)
