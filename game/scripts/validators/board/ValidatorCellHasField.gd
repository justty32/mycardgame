## Checks an explicit cell, SELECTED_CELL (default), or PARENT_CELL. Both field_id and tag
## constrain the same instance. BaseValidator also supports the standard invert_validation.
extends BaseValidator
class_name ValidatorCellHasField

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var board: BoardData = null
	if action != null:
		board = FieldActionCells.resolve_board(action, _get_validator_value("board_id", values, action, null))
	else:
		var battlefield: CombatBattlefield = CombatBattlefield.get_active()
		if battlefield != null:
			board = battlefield.get_board(str(values.board_id)) if values.has("board_id") else battlefield.get_board_for_unit(BoardTargeting.context_parent(null))
	if board == null:
		return false
	var value: Variant = _get_validator_value("cell", values, action, "SELECTED_CELL")
	var cell: Vector2i = BoardTargeting.context_cell(action, value)
	if value is String and value == "PARENT_CELL":
		var parent: BaseCombatant = BoardTargeting.context_parent(action)
		if is_instance_valid(parent) and board.has_unit(parent):
			cell = parent.board_anchor
	var field_id: String = str(_get_validator_value("field_id", values, action, ""))
	var tag: String = str(_get_validator_value("tag", values, action, ""))
	var found: bool = false
	for instance: FieldInstance in board.get_fields(cell, tag):
		if field_id == "" or instance.field_data.object_id == field_id:
			found = true
			break
	return found != bool(values.get("invert", false))
