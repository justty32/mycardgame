## PINCER: parent and ally on opposing cardinal sides. SURROUND: target's adjacent opponents.
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var parent: BaseCombatant = BoardTargeting.context_parent(action)
	var board: BoardData = BoardData.get_for_unit(parent)
	var target: BaseCombatant = BoardTargeting.context_unit(board, action, parent, str(_get_validator_value("target", values, action, "SELECTED_TARGET")))
	if board == null or target == null:
		return true
	var target_board: BoardData = BoardData.get_for_unit(target)
	var query: Dictionary = BoardTargeting.geometry(target_board, parent, target.board_anchor, BoardTargeting.TARGET_SHAPES.SINGLE)
	if not query.valid:
		return false
	if str(_get_validator_value("mode", values, action, "PINCER")) == "SURROUND":
		return BoardPositionQueries.surrounded_count(target_board, target) >= int(_get_validator_value("comparison_value", values, action, 2))
	return not query.cross_board and BoardPositionQueries.is_flanked(board, parent, target)
