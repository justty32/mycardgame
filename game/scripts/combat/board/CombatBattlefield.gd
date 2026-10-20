## Owns independent boards for one combat. Geometry mutations are synchronous and emit no
## gameplay events; action owners dispatch leave/enter only after a complete successful commit.
## Action owners enforce alive/immovable/interceptor rules; placement also serves pre-ready units.
extends RefCounted
class_name CombatBattlefield

const BOARD_SHARED: String = "shared"
const BOARD_PARTY: String = "party"
const BOARD_ENEMY: String = "enemy"

var boards: Dictionary[String, BoardData] = {}
var rules: CombatRulesData = null
var encounter: EncounterData = null
var valid: bool = false
var error: String = ""
var board_mode: int = CombatRulesData.BOARD_MODES.DUAL

func _init(encounter_data: EncounterData = null, combat_rules: CombatRulesData = null) -> void:
	rules = combat_rules if combat_rules != null else CombatRulesData.new()
	encounter = encounter_data if encounter_data != null else EncounterData.new()
	error = rules.validate_configuration()
	if error == "":
		error = encounter.validate_configuration(rules)
	if error != "":
		return
	board_mode = encounter.get_board_mode(rules)
	var ids: Array[String] = [BOARD_SHARED]
	if board_mode == CombatRulesData.BOARD_MODES.DUAL:
		ids.assign([BOARD_PARTY, BOARD_ENEMY])
	for id: String in ids:
		var board := BoardData.new(encounter.get_size_for_board(id, rules), rules)
		board.board_id = id
		for cell: Vector2i in EncounterData.cells_from_json(encounter.get_board_config(id).blocked_cells):
			board.set_blocked(cell)
		boards[id] = board
	valid = true

static func get_active() -> CombatBattlefield:
	var director: CombatDirector = Global.get_combat_director()
	return director.battlefield if director != null else null

func get_board(id: String) -> BoardData:
	return boards.get(id, null)

func get_board_for_unit(unit: BaseCombatant) -> BoardData:
	if unit == null or not is_instance_valid(unit):
		return null
	var board: BoardData = get_board(unit.board_id)
	return board if board != null and board.has_unit(unit) and board.get_unit_at(unit.board_anchor) == unit else null

func get_units() -> Array[BaseCombatant]:
	var returned: Array[BaseCombatant] = []
	for board: BoardData in boards.values():
		for unit: BaseCombatant in board.get_units():
			if not returned.has(unit):
				returned.append(unit)
	return returned

## Initial deployment only. Never use faction to locate a unit that already exists.
func default_board_id(faction: int) -> String:
	if board_mode == CombatRulesData.BOARD_MODES.SINGLE:
		return BOARD_SHARED
	return BOARD_PARTY if faction == BaseCombatant.FACTIONS.PARTY else BOARD_ENEMY

func get_position(unit: BaseCombatant) -> BoardPosition:
	return BoardPosition.from_unit(unit) if get_board_for_unit(unit) != null else BoardPosition.new()

func place(unit: BaseCombatant, position: BoardPosition) -> bool:
	if not valid or unit == null or not is_instance_valid(unit) or position == null:
		return false
	for existing: BoardData in boards.values():
		if existing.unit_cells.has(unit.unit_uid) or existing._uid_to_unit.has(unit.unit_uid):
			return false
	var board: BoardData = get_board(position.board_id)
	if board == null or not board.place(unit, position.cell):
		return false
	unit.board_id = position.board_id
	return true

func can_transfer(unit: BaseCombatant, destination: BoardPosition) -> bool:
	if destination == null or get_board_for_unit(unit) == null:
		return false
	var target: BoardData = get_board(destination.board_id)
	return target != null and target.can_teleport(unit, destination.cell)

func transfer(unit: BaseCombatant, destination: BoardPosition) -> bool:
	if not can_transfer(unit, destination):
		return false
	var source: BoardData = get_board_for_unit(unit)
	var target: BoardData = get_board(destination.board_id)
	var old: BoardPosition = BoardPosition.from_unit(unit)
	var snapshots: Array[Dictionary] = [_snapshot(source)]
	if source != target:
		snapshots.append(_snapshot(target))
	source.remove(unit)
	if not target.place(unit, destination.cell):
		_restore(snapshots)
		unit.board_id = old.board_id
		unit.board_anchor = old.cell
		return false
	unit.board_id = destination.board_id
	return true

func transfer_unit(unit: BaseCombatant, target_board_id: String, target_cell: Vector2i) -> bool:
	return transfer(unit, BoardPosition.new(target_board_id, target_cell))

func can_swap(a: BaseCombatant, b: BaseCombatant) -> bool:
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		return false
	if a == b or a.footprint != b.footprint:
		return false
	var board_a: BoardData = get_board_for_unit(a)
	var board_b: BoardData = get_board_for_unit(b)
	if board_a == null or board_b == null:
		return false
	if not board_b.can_teleport(a, b.board_anchor, [b]) or not board_a.can_teleport(b, a.board_anchor, [a]):
		return false
	if board_a == board_b:
		var cells_a: Array[Vector2i] = BoardData.footprint_cells(b.board_anchor, a.footprint)
		for cell: Vector2i in BoardData.footprint_cells(a.board_anchor, b.footprint):
			if cells_a.has(cell):
				return false
	return true

func swap(a: BaseCombatant, b: BaseCombatant) -> bool:
	if not can_swap(a, b):
		return false
	var board_a: BoardData = get_board_for_unit(a)
	var board_b: BoardData = get_board_for_unit(b)
	var old_a: BoardPosition = BoardPosition.from_unit(a)
	var old_b: BoardPosition = BoardPosition.from_unit(b)
	var snapshots: Array[Dictionary] = [_snapshot(board_a)]
	if board_a != board_b:
		snapshots.append(_snapshot(board_b))
	board_a.remove(a)
	board_b.remove(b)
	if not board_b.place(a, old_b.cell) or not board_a.place(b, old_a.cell):
		_restore(snapshots)
		a.board_id = old_a.board_id
		a.board_anchor = old_a.cell
		b.board_id = old_b.board_id
		b.board_anchor = old_b.cell
		return false
	a.board_id = old_b.board_id
	b.board_id = old_a.board_id
	return true

func swap_units(a: BaseCombatant, b: BaseCombatant) -> bool:
	return swap(a, b)

## Snapshot only geometry; rollback cannot replay or undo gameplay events because none run here.
static func _snapshot(board: BoardData) -> Dictionary:
	var occupants: Dictionary = {}
	for cell: Vector2i in board.cells:
		occupants[cell] = board.cells[cell].occupant_uid
	return {"board": board, "occupants": occupants, "unit_cells": board.unit_cells.duplicate(true), "units": board._uid_to_unit.duplicate()}

static func _restore(snapshots: Array[Dictionary]) -> void:
	for snapshot: Dictionary in snapshots:
		var board: BoardData = snapshot.board
		board.unit_cells.assign(snapshot.unit_cells)
		board._uid_to_unit.assign(snapshot.units)
		for cell: Vector2i in snapshot.occupants:
			board.cells[cell].occupant_uid = snapshot.occupants[cell]
