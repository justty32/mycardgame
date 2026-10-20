## The parent and a unit share a row or a column (combat framework Phase 2). Values: to
## "SELECTED_TARGET" (default) | "HERO" | "NEAREST_OPPONENT". Passes when the unit is unknown yet.
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var parent: BaseCombatant = BoardTargeting.context_parent(action)
	var board: BoardData = BoardData.get_for_unit(parent)
	var other: BaseCombatant = BoardTargeting.context_unit(board, action, parent, str(_get_validator_value("to", values, action, "SELECTED_TARGET")))
	if board == null or parent == null or other == null:
		return true
	var target_board: BoardData = BoardData.get_for_unit(other)
	if target_board == null:
		return false
	var query: Dictionary = BoardTargeting.geometry(target_board, parent, other.board_anchor, BoardTargeting.TARGET_SHAPES.SINGLE)
	if not query.valid or query.cross_board:
		return false
	return board.is_in_line(parent, other)
