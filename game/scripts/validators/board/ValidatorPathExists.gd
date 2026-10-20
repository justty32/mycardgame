## The parent can move to a cell (combat framework Phase 2). Values: to "SELECTED_CELL" (default) or
## [x, y]; max_length (-1 = unlimited); teleport (true = no path needed). Fails when the parent cannot
## move at all (a preview ActionMoveUnit is intercepted to distance 0, e.g. rooted). Without a known
## cell only the mobility check runs.
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var parent: BaseCombatant = BoardTargeting.context_parent(action)
	var board: BoardData = BoardData.get_for_unit(parent)
	if board == null or parent == null or not board.has_unit(parent):
		return true
	var max_length: int = int(_get_validator_value("max_length", values, action, -1))
	var move_distance: int = _preview_move_distance(parent, max_length)
	if move_distance == 0:
		return false
	var cell: Vector2i = BoardTargeting.context_cell(action, _get_validator_value("to", values, action, "SELECTED_CELL"))
	if cell == BaseCombatant.BOARD_ANCHOR_NONE:
		return true
	var target_board: BoardData = BoardTargeting.context_board(action, parent)
	var query: Dictionary = BoardTargeting.geometry(target_board, parent, cell, BoardTargeting.TARGET_SHAPES.SINGLE)
	if not query.valid or query.cross_board:
		return false
	if bool(_get_validator_value("teleport", values, action, false)):
		return board.can_teleport(parent, cell)
	return not board.find_path(parent, cell, move_distance).is_empty()

## Move distance after interceptors (preview): -1 = unlimited, 0 = cannot move.
static func _preview_move_distance(unit: BaseCombatant, max_length: int) -> int:
	var preview: BaseAction = ActionGenerator.create_actions(unit, null, [unit], [{Scripts.ACTION_MOVE_UNIT: {"distance": max_length}}], null)[0]
	var processors: Array[ActionInterceptorProcessor] = preview._intercept_action([unit], true)
	if processors.is_empty():
		return 0
	return int(processors[0].get_shadowed_action_values("distance", max_length))
