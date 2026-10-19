## The combat board (combat framework Phase 2): a grid of BoardCellData, unit placement with
## footprints, distances and deterministic path finding. Created by CombatDirector per combat,
## not saved. Pure queries are shared by the UI (BoardView), card targeting (BoardTargeting),
## enemy intents (IntentResolver / ThreatPreview) and the board actions so they see the same facts.
extends RefCounted
class_name BoardData

## Neighbour expansion order is fixed (N, E, S, W) so path finding is deterministic.
const NEIGHBOURS_FOUR: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const UNLIMITED: int = -1

var size: Vector2i = Vector2i(5, 5)
var rules: CombatRulesData = null
var cells: Dictionary[Vector2i, BoardCellData] = {}
## unit_uid -> covered cells (anchor first).
var unit_cells: Dictionary[String, Array] = {}
var _uid_to_unit: Dictionary[String, Variant] = {}

func _init(board_size: Vector2i = Vector2i(5, 5), combat_rules: CombatRulesData = null) -> void:
	size = Vector2i(max(1, board_size.x), max(1, board_size.y))
	rules = combat_rules if combat_rules != null else CombatRulesData.new()
	for y: int in size.y:
		for x: int in size.x:
			cells[Vector2i(x, y)] = BoardCellData.new()

## The board of the running combat, or null.
static func get_active() -> BoardData:
	var director: CombatDirector = Global.get_combat_director()
	if director == null:
		return null
	return director.board

#region Cells
func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

func get_cell(cell: Vector2i) -> BoardCellData:
	return cells.get(cell, null)

func set_blocked(cell: Vector2i, blocked: bool = true) -> void:
	var cell_data: BoardCellData = get_cell(cell)
	if cell_data != null:
		cell_data.is_blocked = blocked

func is_blocked(cell: Vector2i) -> bool:
	var cell_data: BoardCellData = get_cell(cell)
	return cell_data == null or cell_data.is_blocked

func is_deploy_cell(cell: Vector2i) -> bool:
	var cell_data: BoardCellData = get_cell(cell)
	return cell_data != null and cell_data.is_deploy_zone

func all_cells() -> Array[Vector2i]:
	var returned: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			returned.append(Vector2i(x, y))
	return returned

static func footprint_cells(anchor: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var returned: Array[Vector2i] = []
	for dy: int in max(1, footprint.y):
		for dx: int in max(1, footprint.x):
			returned.append(anchor + Vector2i(dx, dy))
	return returned
#endregion

#region Units
func has_unit(unit: BaseCombatant) -> bool:
	return unit != null and unit_cells.has(unit.unit_uid)

func get_unit_at(cell: Vector2i) -> BaseCombatant:
	var cell_data: BoardCellData = get_cell(cell)
	if cell_data == null or cell_data.occupant_uid == "":
		return null
	var value: Variant = _uid_to_unit.get(cell_data.occupant_uid, null)
	if value != null and is_instance_valid(value):
		return value
	return null

func get_unit_cells(unit: BaseCombatant) -> Array[Vector2i]:
	var returned: Array[Vector2i] = []
	if unit != null:
		returned.assign(unit_cells.get(unit.unit_uid, []))
	return returned

## Placed units that are still valid, in placement order.
func get_units() -> Array[BaseCombatant]:
	var returned: Array[BaseCombatant] = []
	for value: Variant in _uid_to_unit.values():
		if value != null and is_instance_valid(value):
			returned.append(value)
	return returned

## Places a unit with its footprint at anchor. Fails (false) when any covered cell is unusable.
func place(unit: BaseCombatant, anchor: Vector2i) -> bool:
	if unit == null:
		return false
	if not can_stand(unit, anchor):
		return false
	remove(unit)
	var covered: Array = []
	for cell: Vector2i in footprint_cells(anchor, unit.footprint):
		cells[cell].occupant_uid = unit.unit_uid
		covered.append(cell)
	unit_cells[unit.unit_uid] = covered
	_uid_to_unit[unit.unit_uid] = unit
	unit.board_anchor = anchor
	return true

func remove(unit: BaseCombatant) -> void:
	if unit == null or not unit_cells.has(unit.unit_uid):
		return
	for cell: Vector2i in unit_cells[unit.unit_uid]:
		var cell_data: BoardCellData = get_cell(cell)
		if cell_data != null and cell_data.occupant_uid == unit.unit_uid:
			cell_data.occupant_uid = ""
	unit_cells.erase(unit.unit_uid)
	_uid_to_unit.erase(unit.unit_uid)
	if is_instance_valid(unit):
		unit.board_anchor = BaseCombatant.BOARD_ANCHOR_NONE

## Moves a placed unit to a new anchor (its own cells do not block). false = not moved.
func move(unit: BaseCombatant, anchor: Vector2i) -> bool:
	if not has_unit(unit) or not can_stand(unit, anchor):
		return false
	var covered: Array = unit_cells[unit.unit_uid]
	for cell: Vector2i in covered:
		cells[cell].occupant_uid = ""
	covered.clear()
	for cell: Vector2i in footprint_cells(anchor, unit.footprint):
		cells[cell].occupant_uid = unit.unit_uid
		covered.append(cell)
	unit.board_anchor = anchor
	return true

## Exchanges the anchors of two placed units with equal footprints.
func swap(unit_a: BaseCombatant, unit_b: BaseCombatant) -> bool:
	if not has_unit(unit_a) or not has_unit(unit_b) or unit_a.footprint != unit_b.footprint:
		return false
	var anchor_a: Vector2i = unit_a.board_anchor
	var anchor_b: Vector2i = unit_b.board_anchor
	remove(unit_a)
	remove(unit_b)
	place(unit_a, anchor_b)
	place(unit_b, anchor_a)
	return true

## Units in the given cells (each once, alive only), optionally filtered by faction (-1 = any).
func units_in_cells(cell_list: Array[Vector2i], faction_filter: int = -1) -> Array[BaseCombatant]:
	var returned: Array[BaseCombatant] = []
	for cell: Vector2i in cell_list:
		var unit: BaseCombatant = get_unit_at(cell)
		if unit == null or returned.has(unit) or not unit.is_alive():
			continue
		if faction_filter >= 0 and unit.faction != faction_filter:
			continue
		returned.append(unit)
	return returned
#endregion

#region Distance
func distance(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = (a - b).abs()
	if rules.distance_metric == CombatRulesData.DISTANCE_METRICS.CHEBYSHEV:
		return max(delta.x, delta.y)
	return delta.x + delta.y

## Smallest distance between a footprint at anchor and a cell.
func footprint_distance_to_cell(anchor: Vector2i, footprint: Vector2i, cell: Vector2i) -> int:
	var best: int = 1 << 30
	for covered: Vector2i in footprint_cells(anchor, footprint):
		best = min(best, distance(covered, cell))
	return best

func unit_distance_to_cell(unit: BaseCombatant, cell: Vector2i) -> int:
	if not has_unit(unit):
		return 1 << 30
	return footprint_distance_to_cell(unit.board_anchor, unit.footprint, cell)

## Smallest distance between any cells of two units (a footprint may be hypothetical: from_anchor).
func unit_distance(unit_a: BaseCombatant, unit_b: BaseCombatant, from_anchor: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE) -> int:
	if unit_a == null or unit_b == null or not has_unit(unit_b):
		return 1 << 30
	var anchor: Vector2i = from_anchor if from_anchor != BaseCombatant.BOARD_ANCHOR_NONE else unit_a.board_anchor
	if anchor == BaseCombatant.BOARD_ANCHOR_NONE:
		return 1 << 30
	var best: int = 1 << 30
	for cell: Vector2i in get_unit_cells(unit_b):
		best = min(best, footprint_distance_to_cell(anchor, unit_a.footprint, cell))
	return best

## Whether two units share a row or a column (any covered cells).
func is_in_line(unit_a: BaseCombatant, unit_b: BaseCombatant) -> bool:
	for cell_a: Vector2i in get_unit_cells(unit_a):
		for cell_b: Vector2i in get_unit_cells(unit_b):
			if cell_a.x == cell_b.x or cell_a.y == cell_b.y:
				return true
	return false
#endregion

#region Movement queries
## Whether the unit's footprint fits at anchor: in bounds, not blocked, not covered by another
## unit (the unit's own cells and units in ignored_units do not count).
func can_stand(unit: BaseCombatant, anchor: Vector2i, ignored_units: Array = []) -> bool:
	var footprint: Vector2i = unit.footprint if unit != null else Vector2i(1, 1)
	return _footprint_fits(unit, footprint, anchor, ignored_units)

## Whether a not-yet-spawned unit of this footprint fits at anchor (wave spawn policies).
func footprint_fits(footprint: Vector2i, anchor: Vector2i) -> bool:
	return _footprint_fits(null, footprint, anchor, [])

func _footprint_fits(unit: BaseCombatant, footprint: Vector2i, anchor: Vector2i, ignored_units: Array) -> bool:
	for cell: Vector2i in footprint_cells(anchor, footprint):
		if not is_in_bounds(cell) or is_blocked(cell):
			return false
		var occupant: BaseCombatant = get_unit_at(cell)
		if occupant != null and occupant != unit and not ignored_units.has(occupant):
			return false
	return true

func _can_pass(unit: BaseCombatant, anchor: Vector2i, ignore_occupancy: bool) -> bool:
	if not ignore_occupancy:
		return can_stand(unit, anchor)
	for cell: Vector2i in footprint_cells(anchor, unit.footprint):
		if not is_in_bounds(cell):
			return false
	return true

## Breadth-first search from the unit's anchor (N, E, S, W expansion; deterministic).
## Returns reachable anchor -> path (cells after the start, destination last); the start maps to [].
## budget UNLIMITED (-1) = no length limit. ignore_occupancy (flying) passes over units and blocked
## cells but never stops on them. Units off the board reach nothing.
func reachable_cells(unit: BaseCombatant, budget: int = UNLIMITED, ignore_occupancy: Variant = null) -> Dictionary:
	var returned: Dictionary = {}
	if unit == null or not has_unit(unit):
		return returned
	var flying: bool = unit.ignores_occupancy if ignore_occupancy == null else bool(ignore_occupancy)
	var start: Vector2i = unit.board_anchor
	var parents: Dictionary = {start: start}
	var depth: Dictionary = {start: 0}
	var frontier: Array[Vector2i] = [start]
	returned[start] = [] as Array[Vector2i]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if budget != UNLIMITED and depth[current] >= budget:
			continue
		for offset: Vector2i in NEIGHBOURS_FOUR:
			var next: Vector2i = current + offset
			if parents.has(next) or not _can_pass(unit, next, flying):
				continue
			parents[next] = current
			depth[next] = depth[current] + 1
			frontier.append(next)
			if can_stand(unit, next):
				returned[next] = _build_path(parents, start, next)
	return returned

## Shortest path from the unit's anchor to an anchor ([] = unreachable or already there).
func find_path(unit: BaseCombatant, to: Vector2i, budget: int = UNLIMITED) -> Array[Vector2i]:
	var returned: Array[Vector2i] = []
	var reachable: Dictionary = reachable_cells(unit, budget)
	if reachable.has(to):
		returned.assign(reachable[to])
	return returned

func _build_path(parents: Dictionary, start: Vector2i, destination: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Vector2i = destination
	while current != start:
		path.push_front(current)
		current = parents[current]
	return path

## NEAREST_EMPTY spawn rule: the free anchor nearest to origin (by distance), not in the deploy zone;
## ties: spawn-zone cells first, then smaller y, then smaller x. Falls back to the deploy zone too.
## BOARD_ANCHOR_NONE = the board is full.
func nearest_empty_anchor(unit: BaseCombatant, origin: Vector2i) -> Vector2i:
	return _nearest_empty_anchor(unit, unit.footprint if unit != null else Vector2i(1, 1), origin)

## nearest_empty_anchor for a not-yet-spawned unit of this footprint.
func nearest_empty_anchor_for_footprint(footprint: Vector2i, origin: Vector2i) -> Vector2i:
	return _nearest_empty_anchor(null, footprint, origin)

func _nearest_empty_anchor(unit: BaseCombatant, footprint: Vector2i, origin: Vector2i) -> Vector2i:
	var best: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE
	var best_key: int = -1
	for allow_deploy: bool in [false, true]:
		for cell: Vector2i in all_cells():
			var cell_data: BoardCellData = get_cell(cell)
			if cell_data.is_deploy_zone and not allow_deploy:
				continue
			if not _footprint_fits(unit, footprint, cell, []):
				continue
			var key: int = sort_key([distance(cell, origin), 0 if cell_data.is_spawn_zone else 1, cell.y, cell.x])
			if best_key < 0 or key < best_key:
				best_key = key
				best = cell
		if best != BaseCombatant.BOARD_ANCHOR_NONE:
			return best
	return best
#endregion

## Combines small non-negative integers (each < 1000) into one comparable key, most significant first.
static func sort_key(parts: Array) -> int:
	var key: int = 0
	for part: Variant in parts:
		key = key * 1000 + clampi(int(part), 0, 999)
	return key
