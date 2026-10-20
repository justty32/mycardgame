## A board-local position. Two identical cells on different boards are distinct positions.
extends RefCounted
class_name BoardPosition

var board_id: String = ""
var cell: Vector2i = Vector2i(-1, -1)

func _init(id: String = "", local_cell: Vector2i = Vector2i(-1, -1)) -> void:
	board_id = id
	cell = local_cell

static func from_unit(unit: BaseCombatant) -> BoardPosition:
	if unit == null or not is_instance_valid(unit):
		return BoardPosition.new()
	return BoardPosition.new(unit.board_id, unit.board_anchor)

func equals(other: BoardPosition) -> bool:
	return other != null and board_id == other.board_id and cell == other.cell
