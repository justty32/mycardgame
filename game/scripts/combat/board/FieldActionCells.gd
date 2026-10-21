## Shared cell input for field creation/removal/obstacle actions; never mutates targeting state.
extends RefCounted
class_name FieldActionCells

## Explicit identity always wins and never falls back on a miss. Selection identifies
## the target board; absent selection uses the creator's actual board, not its faction.
static func resolve_board(action: BaseAction, explicit_id: Variant = null) -> BoardData:
	var battlefield: CombatBattlefield = CombatBattlefield.get_active()
	if battlefield == null:
		return null
	if explicit_id != null:
		return battlefield.get_board(str(explicit_id))
	if action.card_play_request != null and BoardCardOptions.selected_board_id(action.card_play_request) != "":
		return battlefield.get_board(BoardCardOptions.selected_board_id(action.card_play_request))
	if is_instance_valid(action.parent_combatant):
		return battlefield.get_board_for_unit(action.parent_combatant)
	return null

static func resolve_effect_board(action: BaseAction, explicit_id: Variant, cell_value: Variant) -> BoardData:
	var selected: BoardData = resolve_board(action, explicit_id)
	if selected != null and cell_value == null and action.card_play_request != null and action.card_play_request.card_data != null:
		return BoardTargeting.target_board_for_shape(selected, action.parent_combatant, BoardCardOptions.shape_of(action.card_play_request.card_data))
	return selected

static func resolve(action: BaseAction, board: BoardData, value: Variant, shape_default: bool = false) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var parent: BaseCombatant = action.parent_combatant
	var request: CardPlayRequest = action.card_play_request
	if value is String:
		if value == "PARENT_CELL" and is_instance_valid(parent) and board.has_unit(parent):
			cells.append(parent.board_anchor)
		elif value == "SELECTED_CELL" and request != null and (BoardCardOptions.selected_board_id(request) == "" or BoardCardOptions.selected_board_id(request) == board.board_id):
			cells.append(BoardCardOptions.selected_cell(request))
	elif value is Vector2i or value is Vector2:
		cells.append(Vector2i(value))
	elif value is Array:
		cells = EncounterData.cells_from_json(value)
	elif value == null and shape_default and request != null:
		var selected: Vector2i = BoardCardOptions.selected_cell(request)
		if selected == BaseCombatant.BOARD_ANCHOR_NONE and is_instance_valid(request.selected_target):
			selected = request.selected_target.board_anchor
		var shape: int = BoardCardOptions.shape_of(request.card_data) if request.card_data != null else BoardTargeting.TARGET_SHAPES.SINGLE
		var maximum_range: int = BoardCardOptions.range_of(request.card_data) if request.card_data != null else -1
		var geometry: Dictionary = BoardTargeting.geometry(board, parent, selected, shape, maximum_range)
		if not geometry.get("valid", false) or geometry.get("board_id", "") != board.board_id:
			return []
		cells.assign(geometry.get("cells", []))
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if board.is_in_bounds(cell) and not result.has(cell):
			result.append(cell)
	return result
