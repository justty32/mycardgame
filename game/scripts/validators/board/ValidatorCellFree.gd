## A cell is free for the unit's footprint: on the board, not blocked, no other unit (combat
## framework Phase 2). Values: cell "SELECTED_CELL" (default) or [x, y]. Passes when the cell is unknown.
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var board: BoardData = BoardData.get_active()
	var parent: BaseCombatant = BoardTargeting.context_parent(action)
	if board == null or parent == null:
		return true
	var cell: Vector2i = BoardTargeting.context_cell(action, _get_validator_value("cell", values, action, "SELECTED_CELL"))
	if cell == BaseCombatant.BOARD_ANCHOR_NONE:
		return true
	return board.can_stand(parent, cell)
