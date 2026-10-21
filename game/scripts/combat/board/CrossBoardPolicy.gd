## The one targeting geometry entry point. Version 1 implements SELECT_TARGET_CELL only.
## Faction, unit existence and card/action-specific permissions remain caller validations.
extends RefCounted
class_name CrossBoardPolicy

const VERSION: int = 1
const SELECT_TARGET_CELL: String = "SELECT_TARGET_CELL"

static func resolve(battlefield: CombatBattlefield, source: BoardPosition, target: BoardPosition, shape: int, max_range: int = -1, footprint: Vector2i = Vector2i.ONE, movement: String = "") -> Dictionary:
	if battlefield == null or not battlefield.valid:
		return _rejected("invalid_battlefield")
	var configuration_error: String = battlefield.rules.validate_spatial_configuration()
	if configuration_error != "":
		return _rejected(configuration_error)
	if source == null or target == null:
		return _rejected("off_board")
	var source_board: BoardData = battlefield.get_board(source.board_id)
	var target_board: BoardData = battlefield.get_board(target.board_id)
	if source_board == null or target_board == null or not source_board.is_in_bounds(source.cell) or not target_board.is_in_bounds(target.cell):
		return _rejected("off_board")
	if shape not in BoardTargeting.TARGET_SHAPES.values():
		return _rejected("unknown_shape")
	var cross_board: bool = source.board_id != target.board_id
	if cross_board and (shape in [BoardTargeting.TARGET_SHAPES.LINE, BoardTargeting.TARGET_SHAPES.LINE_PIERCE] or movement in ["PUSH", "PULL", "PULL_ADJACENT"]):
		return _rejected("cross_board_direction_unsupported")
	if shape == BoardTargeting.TARGET_SHAPES.SELF_AREA:
		target_board = source_board
		target = source
		cross_board = false
	if not cross_board and max_range >= 0 and source_board.footprint_distance_to_cell(source.cell, footprint, target.cell) > max_range:
		return _rejected("out_of_range")
	var cells: Array[Vector2i] = BoardTargeting.cells_in_shape(target_board, source.cell, target.cell, shape, max_range)
	var distance: Variant = null if cross_board else source_board.footprint_distance_to_cell(source.cell, footprint, target.cell)
	return {"valid": true, "error": "", "cross_board": cross_board, "board_id": target.board_id, "cells": cells, "distance": distance}

static func _rejected(reason: String) -> Dictionary:
	return {"valid": false, "error": reason, "cross_board": false, "board_id": "", "cells": [], "distance": null}
