## Removes matching field_id/tag on cells; omitted cells means the entire selected board.
extends BaseAction
class_name ActionRemoveField

func perform_action() -> void:
	for processor: ActionInterceptorProcessor in _intercept_action([]):
		var board: BoardData = FieldActionCells.resolve_board(self, processor.get_shadowed_action_values("board_id", null))
		var controller: FieldController = FieldController.for_board(board)
		if controller == null:
			continue
		var value: Variant = processor.get_shadowed_action_values("cells", null)
		var cells: Array[Vector2i] = FieldActionCells.resolve(self, controller.board, value)
		# Explicit empty/invalid cells never accidentally mean remove from the whole board.
		if value != null and cells.is_empty():
			continue
		controller.remove_fields(cells, str(processor.get_shadowed_action_values("field_id", "")), str(processor.get_shadowed_action_values("tag", "")))
