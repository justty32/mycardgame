## Board distance check (combat framework Phase 2). Values: from "PARENT" (default), to
## "SELECTED_TARGET" (default) | "HERO" | "NEAREST_OPPONENT", operator, comparison_value.
## Passes when the "to" unit is unknown (no target chosen yet) or outside a board combat.
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
	var operator: String = str(_get_validator_value("operator", values, action, "<="))
	var comparison_value: int = int(_get_validator_value("comparison_value", values, action, 1))
	return _compare(board.unit_distance(parent, other), comparison_value, operator)
