## Board distance check (combat framework Phase 2). Values: from "PARENT" (default), to
## "SELECTED_TARGET" (default) | "HERO" | "NEAREST_OPPONENT", operator, comparison_value.
## Passes when the "to" unit is unknown (no target chosen yet) or outside a board combat.
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var board: BoardData = BoardData.get_active()
	if board == null:
		return true
	var parent: BaseCombatant = BoardTargeting.context_parent(action)
	var other: BaseCombatant = BoardTargeting.context_unit(board, action, parent, str(_get_validator_value("to", values, action, "SELECTED_TARGET")))
	if parent == null or other == null or not board.has_unit(parent) or not board.has_unit(other):
		return true
	var operator: String = str(_get_validator_value("operator", values, action, "<="))
	var comparison_value: int = int(_get_validator_value("comparison_value", values, action, 1))
	return _compare(board.unit_distance(parent, other), comparison_value, operator)
