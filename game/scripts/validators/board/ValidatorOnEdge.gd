extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var parent: BaseCombatant = BoardTargeting.context_parent(action)
	var board: BoardData = BoardData.get_for_unit(parent)
	var unit: BaseCombatant = BoardTargeting.context_unit(board, action, parent, str(_get_validator_value("unit", values, action, "PARENT")))
	board = BoardData.get_for_unit(unit)
	return board == null or unit == null or BoardPositionQueries.is_on_edge(board, unit)
