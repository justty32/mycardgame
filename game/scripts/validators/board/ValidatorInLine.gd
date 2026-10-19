## The parent and a unit share a row or a column (combat framework Phase 2). Values: to
## "SELECTED_TARGET" (default) | "HERO" | "NEAREST_OPPONENT". Passes when the unit is unknown yet.
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var board: BoardData = BoardData.get_active()
	if board == null:
		return true
	var parent: BaseCombatant = BoardTargeting.context_parent(action)
	var other: BaseCombatant = BoardTargeting.context_unit(board, action, parent, str(_get_validator_value("to", values, action, "SELECTED_TARGET")))
	if parent == null or other == null or not board.has_unit(parent) or not board.has_unit(other):
		return true
	return board.is_in_line(parent, other)
