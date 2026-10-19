## Board side of one combat, owned by CombatDirector: builds the BoardData from the encounter
## (deploy / spawn zones, blocked cells), deploys the hero, places units (NEAREST_EMPTY) and runs the
## acting party unit's click movement (free move points first, then paid cells). A RefCounted
## created per combat; CombatDirector.board / .encounter read through it.
extends RefCounted
class_name BoardController

var rules: CombatRulesData = null
## Board of the current combat and the encounter it was built from.
var board: BoardData = null
var encounter: EncounterData = null

func _init(combat_rules: CombatRulesData) -> void:
	rules = combat_rules

## Builds the board from the encounter and places the hero on the first deploy cell.
func setup(encounter_data: EncounterData) -> void:
	encounter = encounter_data
	board = BoardData.new(encounter.get_board_size(rules), rules)
	var deploy_cells: Array[Vector2i] = EncounterData.cells_from_json(encounter.encounter_deploy_cells)
	if deploy_cells.is_empty():
		deploy_cells = default_deploy_cells()
	for cell: Vector2i in deploy_cells:
		if board.is_in_bounds(cell):
			board.get_cell(cell).is_deploy_zone = true
	var spawn_cells: Array[Vector2i] = EncounterData.cells_from_json(encounter.encounter_spawn_zone_cells)
	if spawn_cells.is_empty():
		for y: int in min(2, board.size.y):
			for x: int in board.size.x:
				spawn_cells.append(Vector2i(x, y))
	for cell: Vector2i in spawn_cells:
		if board.is_in_bounds(cell):
			board.get_cell(cell).is_spawn_zone = true
	for cell: Vector2i in EncounterData.cells_from_json(encounter.encounter_blocked_cells):
		board.set_blocked(cell, true)
	# party: the hero takes the first deploy cell
	var hero: BaseCombatant = UnitRegistry.get_hero()
	if hero != null:
		place_unit_nearest(hero, deploy_cells[0] if not deploy_cells.is_empty() else Vector2i(int(board.size.x / 2), board.size.y - 1))

func clear() -> void:
	board = null
	encounter = null

## Default deploy zone: the two south rows, the hero's cell (bottom row center) first.
func default_deploy_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [Vector2i(int(board.size.x / 2), board.size.y - 1)]
	for y: int in range(board.size.y - 1, max(-1, board.size.y - 3), -1):
		for x: int in board.size.x:
			if not cells.has(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells

func default_spawn_origin() -> Vector2i:
	return Vector2i(int(board.size.x / 2), 0)

## Places a unit at cell, or the nearest empty anchor (NEAREST_EMPTY). false = the board is full.
func place_unit_nearest(unit: BaseCombatant, cell: Vector2i) -> bool:
	if board == null or unit == null:
		return false
	if board.place(unit, cell):
		return true
	var anchor: Vector2i = board.nearest_empty_anchor(unit, cell)
	if anchor == BaseCombatant.BOARD_ANCHOR_NONE:
		DebugLogger.log_error("CombatDirector: no free cell for unit {0}".format([unit.get_unit_display_name()]))
		return false
	return board.place(unit, anchor)

## Cells the party unit can still move this action: free move points plus paid cells.
func get_move_budget(unit: BaseCombatant) -> int:
	if unit == null or rules == null:
		return 0
	return unit.move_points + max(0, rules.paid_move_max_cells - unit.paid_cells_this_action)

## Moves the unit along the shortest path to cell within its move budget (ActionMoveUnit, consuming
## move points). false = no budget or the cell is not reachable.
func move_party_unit(unit: BaseCombatant, cell: Vector2i) -> bool:
	if board == null or unit == null:
		return false
	var budget: int = get_move_budget(unit)
	if budget <= 0:
		return false
	var path: Array[Vector2i] = board.find_path(unit, cell, budget)
	if path.is_empty():
		return false
	var move_actions: Array[BaseAction] = ActionGenerator.create_actions(unit, null, [unit], [{
		Scripts.ACTION_MOVE_UNIT: {"mode": ActionMoveUnit.MODE_TO_CELL, "target_cell": cell, "distance": len(path), "consumes_move_points": true, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}
	}], null)
	ActionHandler.add_actions(move_actions)
	return true
