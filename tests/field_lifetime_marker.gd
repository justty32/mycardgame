extends BaseAction
## Observation only; damage, movement and cancellation remain production actions.
func perform_action() -> void:
	var observations: Array = Global.get_meta("field_lifetime_observations", [])
	observations.append({"label": str(get_action_value("label", "")), "owner_null": parent_combatant == null})
	Global.set_meta("field_lifetime_observations", observations)
