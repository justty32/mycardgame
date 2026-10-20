## Creates a field on explicit cells, SELECTED_CELL/PARENT_CELL, or the card's shape.
## duration_override=-2 uses the template, -1 is permanent. owner="NONE" creates no owner.
extends BaseAction
class_name ActionCreateField

func perform_action() -> void:
	for processor: ActionInterceptorProcessor in _intercept_action([]):
		var cell_value: Variant = processor.get_shadowed_action_values("cells", null)
		var board: BoardData = FieldActionCells.resolve_effect_board(self, processor.get_shadowed_action_values("board_id", null), cell_value)
		var controller: FieldController = FieldController.for_board(board)
		if controller == null:
			continue
		var data: FieldData = Global.get_field_data(str(processor.get_shadowed_action_values("field_id", "")))
		if data == null:
			continue
		var cells: Array[Vector2i] = FieldActionCells.resolve(self, controller.board, cell_value, true)
		var owner: BaseCombatant = parent_combatant if str(processor.get_shadowed_action_values("owner", "PARENT")) == "PARENT" else null
		var director: CombatDirector = Global.get_combat_director()
		var tick: int = director.current_tick if director != null else 0
		if field_effective_tick >= 0:
			tick = field_effective_tick
		for cell: Vector2i in cells:
			controller.create_field(data, cell, owner, tick, int(processor.get_shadowed_action_values("duration_override", -2)))
