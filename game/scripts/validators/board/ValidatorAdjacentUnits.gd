## Counts living adjacent units once per footprint; faction is relative to around.
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var parent: BaseCombatant = BoardTargeting.context_parent(action)
	var board: BoardData = BoardData.get_for_unit(parent)
	var around: BaseCombatant = BoardTargeting.context_unit(board, action, parent, str(_get_validator_value("around", values, action, "PARENT")))
	board = BoardData.get_for_unit(around)
	if board == null or around == null:
		return true
	var count: int = BoardPositionQueries.count_adjacent(board, around, str(_get_validator_value("faction", values, action, "ANY")))
	return _compare(count, int(_get_validator_value("comparison_value", values, action, 1)), str(_get_validator_value("operator", values, action, ">=")))
