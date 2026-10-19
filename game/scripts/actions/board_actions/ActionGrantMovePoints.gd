## Adds free move points to units for their current action (combat framework Phase 2).
## Values: amount (may be negative; points never go below 0). Targets default to the parent.
extends BaseAction

func perform_action() -> void:
	var units: Array[BaseCombatant] = []
	if values.has("target_override"):
		units = get_adjusted_action_targets()
	elif parent_combatant != null and is_instance_valid(parent_combatant):
		units = [parent_combatant]
	for action_interceptor_processor: ActionInterceptorProcessor in _intercept_action(units):
		var unit: BaseCombatant = action_interceptor_processor.target
		if unit == null or not is_instance_valid(unit):
			continue
		var amount: int = int(action_interceptor_processor.get_shadowed_action_values("amount", 0))
		unit.move_points = max(0, unit.move_points + amount)

func is_instant_action() -> bool:
	return true

func _to_string() -> String:
	return "Grant Move Points Action: " + str(get_action_value("amount", 0))
