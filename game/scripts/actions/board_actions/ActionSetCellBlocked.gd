## Creates/destroys static obstacle flags. Occupied cells cannot become obstacles.
extends BaseAction
class_name ActionSetCellBlocked

func perform_action() -> void:
	for processor: ActionInterceptorProcessor in _intercept_action([]):
		var cell_value: Variant = processor.get_shadowed_action_values("cells", null)
		var board: BoardData = FieldActionCells.resolve_effect_board(self, processor.get_shadowed_action_values("board_id", null), cell_value)
		if board == null:
			continue
		var blocked: bool = bool(processor.get_shadowed_action_values("blocked", true))
		var changed: bool = false
		for cell: Vector2i in FieldActionCells.resolve(self, board, cell_value, true):
			if blocked and board.get_unit_at(cell) != null:
				continue
			if board.is_blocked(cell) != blocked:
				board.set_blocked(cell, blocked)
				changed = true
		if changed:
			Signals.board_changed.emit(board.board_id)
