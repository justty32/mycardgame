## Cells the parent moved this action (own and card movement, not displacement) compared to a value
## (combat framework Phase 2). Values: operator (default ">="), comparison_value (default 1).
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var parent: BaseCombatant = BoardTargeting.context_parent(action)
	if parent == null:
		return false
	var operator: String = str(_get_validator_value("operator", values, action, ">="))
	var comparison_value: int = int(_get_validator_value("comparison_value", values, action, 1))
	return _compare(parent.cells_moved_this_action, comparison_value, operator)
