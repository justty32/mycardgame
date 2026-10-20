## Read-only numeric preview of standard field/opportunity payloads. Unknown actions contribute
## zero; random damage uses its mean without drawing RNG. No action is performed here.
extends RefCounted
class_name FieldPreview

static func preview_actions(payload: Array[Dictionary], owner: BaseCombatant,
		unit: BaseCombatant, account_block: bool = false, include_benefits: bool = true) -> float:
	if not is_instance_valid(unit) or not unit.is_alive():
		return 0.0
	var state: Dictionary = {"total": 0.0, "block": float(unit.get_block())}
	preview_actions_into(payload, owner, unit, state, account_block, include_benefits)
	return state.total

## Shared simulated block pool for consecutive opportunity controllers; callers own
## state={total:0.0, block:unit.get_block()}, which is never written into a combatant.
static func preview_actions_into(payload: Array[Dictionary], owner: BaseCombatant,
		unit: BaseCombatant, state: Dictionary, account_block: bool = false, include_benefits: bool = true) -> void:
	if not is_instance_valid(unit) or not unit.is_alive():
		return
	for action: BaseAction in ActionGenerator.create_actions(owner, null, [unit], payload, null):
		var path: String = action.get_script().resource_path
		if path == Scripts.ACTION_ATTACK_GENERATOR:
			_preview_generator(action, unit, state, account_block)
		else:
			_preview_direct(action, unit, state, account_block, include_benefits)

static func _targets_unit(action: BaseAction, unit: BaseCombatant) -> bool:
	var override: int = int(action.get_action_value("target_override", BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS))
	# Random target selection must never advance the named target RNG during preview.
	if override == BaseAction.TARGET_OVERRIDES.RANDOM_ENEMY or override == BaseAction.TARGET_OVERRIDES.RANDOM_OPPONENT:
		return false
	return action.get_adjusted_action_targets().has(unit)

static func _preview_generator(action: BaseAction, unit: BaseCombatant, state: Dictionary, account_block: bool) -> void:
	for processor: ActionInterceptorProcessor in action._intercept_action([], true):
		var damage: float = float(processor.get_shadowed_action_values("damage", 0))
		var random_damage: int = int(processor.get_shadowed_action_values("damage_random", 0))
		if random_damage > 1:
			damage += random_damage / 2.0
		var count: int = max(0, int(processor.get_shadowed_action_values("number_of_attacks", 1)))
		if bool(processor.get_shadowed_action_values("merge_attacks", false)):
			damage *= count
			count = 1
		var child_values: Dictionary[String, Variant] = {
			"damage": damage,
			"target_override": processor.get_shadowed_action_values("target_override", BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS),
		}
		for index: int in count:
			var child: BaseAction = load(Scripts.ACTION_ATTACK).new()
			child.init(action.parent_combatant, null, [unit], child_values, action)
			_preview_direct(child, unit, state, account_block, false)

static func _preview_direct(action: BaseAction, unit: BaseCombatant, state: Dictionary,
		account_block: bool, include_benefits: bool) -> void:
	var path: String = action.get_script().resource_path
	if not [Scripts.ACTION_ATTACK, Scripts.ACTION_DIRECT_DAMAGE, Scripts.ACTION_BLOCK,
			Scripts.ACTION_ADD_HEALTH, Scripts.ACTION_HEAL_PERCENT].has(path) or not _targets_unit(action, unit):
		return
	for processor: ActionInterceptorProcessor in action._intercept_action([unit], true):
		if path == Scripts.ACTION_ATTACK or path == Scripts.ACTION_DIRECT_DAMAGE:
			var damage: float = maxf(0.0, float(processor.get_shadowed_action_values("damage", 0)))
			if account_block and not bool(processor.get_shadowed_action_values("bypass_block", false)):
				var absorbed: float = minf(state.block, damage)
				state.block -= absorbed
				damage -= absorbed
			state.total += damage
		elif path == Scripts.ACTION_BLOCK:
			var block: float = maxf(0.0, float(processor.get_shadowed_action_values("block", 0)))
			state.block += block
			if include_benefits:
				state.total -= block
		elif include_benefits and path == Scripts.ACTION_ADD_HEALTH:
			state.total -= float(processor.get_shadowed_action_values("health_amount", 0))
		elif include_benefits and path == Scripts.ACTION_HEAL_PERCENT:
			state.total -= floorf(unit.get_combatant_health_max() * float(processor.get_shadowed_action_values("percentage_heal_amount", 1.0)))
