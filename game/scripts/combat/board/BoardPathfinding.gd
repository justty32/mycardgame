## Pure deterministic terrain / occupancy / control-zone movement queries.
extends RefCounted
class_name BoardPathfinding

const DIAGONALS: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]

static func can_pass(board: BoardData, unit: BaseCombatant, anchor: Vector2i, override_flying: Variant = null) -> bool:
	var flying: bool = unit.ignores_occupancy if override_flying == null else bool(override_flying)
	for cell: Vector2i in BoardData.footprint_cells(anchor, unit.footprint):
		if not board.is_in_bounds(cell):
			return false
		if flying:
			continue
		if not board.is_cell_enterable(cell, unit):
			return false
		var occupant: BaseCombatant = board.get_unit_at(cell)
		if occupant == null or occupant == unit:
			continue
		if occupant.faction == unit.faction and board.rules.move_pass_through_allies:
			continue
		if occupant.faction != unit.faction and occupant.faction != BaseCombatant.FACTIONS.NEUTRAL and board.rules.move_pass_through_enemies:
			continue
		return false
	return true

static func neighbours(board: BoardData) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = BoardData.NEIGHBOURS_FOUR.duplicate()
	if board.rules.move_adjacency == CombatRulesData.MOVE_ADJACENCY.EIGHT:
		offsets.append_array(DIAGONALS)
	return offsets

static func step_cost(board: BoardData, unit: BaseCombatant, from: Vector2i, to: Vector2i, ignore_zoc: bool = false) -> int:
	var cost: int = 1
	for cell: Vector2i in BoardData.footprint_cells(to, unit.footprint):
		var data: BoardCellData = board.get_cell(cell)
		if data == null:
			return 1 << 20
		var cell_cost: int = max(1, data.move_cost)
		for instance: FieldInstance in board.get_fields(cell):
			if instance.field_data.field_move_cost_override >= 0:
				cell_cost = max(1, instance.field_data.field_move_cost_override)
		cost = max(cost, cell_cost)
	if board.rules.zone_of_control == CombatRulesData.ZOC_MODES.EXTRA_MOVE_COST and not board.zoc_controllers(unit, from, ignore_zoc).is_empty():
		cost += max(0, board.rules.zoc_extra_move_cost)
	return cost

static func reachable(board: BoardData, unit: BaseCombatant, budget: int, ignore_occupancy: Variant, ignore_zoc: bool) -> Dictionary:
	var result: Dictionary = {}
	if unit == null or not board.has_unit(unit):
		return result
	var start: Vector2i = unit.board_anchor
	var parents: Dictionary = {start: start}
	var costs: Dictionary = {start: 0}
	var frontier: Array[Vector2i] = [start]
	result[start] = [] as Array[Vector2i]
	while not frontier.is_empty():
		var best_index: int = 0
		for index: int in range(1, frontier.size()):
			if costs[frontier[index]] < costs[frontier[best_index]]:
				best_index = index
		var current: Vector2i = frontier[best_index]
		frontier.remove_at(best_index)
		for offset: Vector2i in neighbours(board):
			var next: Vector2i = current + offset
			if not can_pass(board, unit, next, ignore_occupancy):
				continue
			var cost: int = costs[current] + step_cost(board, unit, current, next, ignore_zoc)
			if budget >= 0 and cost > budget:
				continue
			if costs.has(next) and costs[next] <= cost:
				continue
			costs[next] = cost
			parents[next] = current
			if not frontier.has(next):
				frontier.append(next)
			if board.can_stand(unit, next):
				var path: Array[Vector2i] = []
				var cursor: Vector2i = next
				while cursor != start:
					path.push_front(cursor)
					cursor = parents[cursor]
				result[next] = path
	return result

## Paid movement buys a physical step, not each point of expensive terrain.
## Keep resource states separately: a cheapest-cost path may consume more paid cells.
static func reachable_active(board: BoardData, unit: BaseCombatant, ignore_zoc: bool = false, max_steps: int = -1) -> Dictionary:
	var result: Dictionary = {}
	if unit == null or not board.has_unit(unit):
		return result
	var start: Dictionary = {"cell": unit.board_anchor, "free": unit.move_points, "paid": max(0, board.rules.paid_move_max_cells - unit.paid_cells_this_action), "cost": 0, "path": []}
	var frontier: Array[Dictionary] = [start]
	var seen: Dictionary = {}
	var best_cost: Dictionary = {}
	while not frontier.is_empty():
		var best: int = 0
		for index: int in range(1, frontier.size()):
			if frontier[index].cost < frontier[best].cost:
				best = index
		var entry: Dictionary = frontier[best]
		frontier.remove_at(best)
		var key: String = str(entry.cell) + ":" + str(entry.free) + ":" + str(entry.paid) + (":" + str(entry.path.size()) if max_steps >= 0 else "")
		if seen.has(key):
			continue
		seen[key] = true
		if board.can_stand(unit, entry.cell) and (not best_cost.has(entry.cell) or entry.cost < best_cost[entry.cell]):
			result[entry.cell] = entry.path
			best_cost[entry.cell] = entry.cost
		if max_steps >= 0 and entry.path.size() >= max_steps:
			continue
		for offset: Vector2i in neighbours(board):
			var next: Vector2i = entry.cell + offset
			if not can_pass(board, unit, next):
				continue
			var cost: int = step_cost(board, unit, entry.cell, next, ignore_zoc)
			var paid: int = entry.paid - (1 if entry.free < cost else 0)
			if paid < 0:
				continue
			var path: Array = entry.path.duplicate()
			path.append(next)
			frontier.append({"cell": next, "free": max(0, int(entry.free) - cost), "paid": paid, "cost": entry.cost + cost, "path": path})
	return result

## Card movement limits physical steps while terrain still chooses the cheapest legal path.
static func reachable_steps(board: BoardData, unit: BaseCombatant, max_steps: int, ignore_zoc: bool = false) -> Dictionary:
	if max_steps < 0:
		return reachable(board, unit, -1, null, ignore_zoc)
	var result: Dictionary = {}
	if unit == null or not board.has_unit(unit):
		return result
	var frontier: Array[Dictionary] = [{"cell": unit.board_anchor, "cost": 0, "path": []}]
	var seen: Dictionary = {}
	var best_cost: Dictionary = {}
	while not frontier.is_empty():
		var best: int = 0
		for index: int in range(1, frontier.size()):
			if frontier[index].cost < frontier[best].cost:
				best = index
		var entry: Dictionary = frontier[best]
		frontier.remove_at(best)
		var key: String = str(entry.cell) + ":" + str(entry.path.size())
		if seen.has(key):
			continue
		seen[key] = true
		if board.can_stand(unit, entry.cell) and (not best_cost.has(entry.cell) or entry.cost < best_cost[entry.cell]):
			result[entry.cell] = entry.path
			best_cost[entry.cell] = entry.cost
		if entry.path.size() >= max_steps:
			continue
		for offset: Vector2i in neighbours(board):
			var next: Vector2i = entry.cell + offset
			if not can_pass(board, unit, next):
				continue
			var path: Array = entry.path.duplicate()
			path.append(next)
			frontier.append({"cell": next, "cost": entry.cost + step_cost(board, unit, entry.cell, next, ignore_zoc), "path": path})
	return result
