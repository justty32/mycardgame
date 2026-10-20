## Owns the boards, field controllers and movement state of one combat.
## Initial faction selects a home board; all subsequent queries use actual board identity.
extends RefCounted
class_name BoardController

var rules: CombatRulesData
var encounter: EncounterData
var battlefield: CombatBattlefield
var field_controllers: Dictionary[String, FieldController] = {}
## Legacy query seam: shared board in SINGLE, party board in DUAL.
var board: BoardData:
	get:
		return battlefield.get_board(battlefield.default_board_id(BaseCombatant.FACTIONS.PARTY)) if battlefield != null else null
var field_controller: FieldController:
	get:
		return FieldController.for_board(board)

func _init(combat_rules: CombatRulesData) -> void:
	rules = combat_rules

func setup(encounter_data: EncounterData) -> bool:
	encounter = encounter_data
	battlefield = CombatBattlefield.new(encounter, rules)
	if not battlefield.valid:
		DebugLogger.log_error("BoardController: " + battlefield.error)
		return false
	var shared_opportunities: Dictionary = {}
	for current: BoardData in battlefield.boards.values():
		current.movement_state.used_opportunities = shared_opportunities
		field_controllers[current.board_id] = FieldController.new(current)
		var config: Dictionary = encounter.get_board_config(current.board_id)
		var deploy: Array[Vector2i] = EncounterData.cells_from_json(config.deploy_cells)
		if deploy.is_empty():
			deploy = default_deploy_cells(current.board_id)
		for cell: Vector2i in deploy:
			if current.is_in_bounds(cell):
				current.get_cell(cell).is_deploy_zone = true
		var spawn: Array[Vector2i] = EncounterData.cells_from_json(config.spawn_zone_cells)
		if spawn.is_empty():
			for y: int in min(2, current.size.y):
				for x: int in current.size.x:
					spawn.append(Vector2i(x, y))
		for cell: Vector2i in spawn:
			if current.is_in_bounds(cell):
				current.get_cell(cell).is_spawn_zone = true
		for entry: Dictionary in config.initial_fields:
			var data: FieldData = Global.get_field_data(str(entry.get("field_id", "")))
			if data == null:
				continue
			for cell: Vector2i in EncounterData.cells_from_json(entry.get("cells", [])):
				field_controllers[current.board_id].create_field(data, cell, null, 0, int(entry.get("duration", -2)))
	var hero: BaseCombatant = UnitRegistry.get_hero()
	if hero != null:
		var home: String = battlefield.default_board_id(hero.faction)
		var deploy: Array[Vector2i] = EncounterData.cells_from_json(encounter.get_board_config(home).deploy_cells)
		if deploy.is_empty():
			deploy = default_deploy_cells(home)
		if not place_unit_nearest(hero, deploy[0], home):
			return false
	return true

func clear() -> void:
	for controller: FieldController in field_controllers.values():
		controller.clear()
	field_controllers.clear()
	battlefield = null
	encounter = null

func get_board_for_unit(unit: BaseCombatant) -> BoardData:
	return battlefield.get_board_for_unit(unit) if battlefield != null else null

func get_spawn_board(unit: BaseCombatant, board_id: String = "") -> BoardData:
	if battlefield == null or not is_instance_valid(unit):
		return null
	if board_id != "":
		return battlefield.get_board(board_id)
	var existing: BoardData = get_board_for_unit(unit)
	return existing if existing != null else battlefield.get_board(battlefield.default_board_id(unit.faction))

func default_deploy_cells(board_id: String = "") -> Array[Vector2i]:
	var current: BoardData = board if board_id == "" else battlefield.get_board(board_id)
	var cells: Array[Vector2i] = [Vector2i(int(current.size.x / 2), current.size.y - 1)]
	for y: int in range(current.size.y - 1, max(-1, current.size.y - 3), -1):
		for x: int in current.size.x:
			if not cells.has(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells

func default_spawn_origin(board_id: String = "") -> Vector2i:
	if board_id == "":
		board_id = battlefield.default_board_id(BaseCombatant.FACTIONS.ENEMY)
	var current: BoardData = battlefield.get_board(board_id)
	return Vector2i(int(current.size.x / 2), 0) if current != null else BaseCombatant.BOARD_ANCHOR_NONE

func place_unit_nearest(unit: BaseCombatant, cell: Vector2i, board_id: String = "") -> bool:
	var current: BoardData = get_spawn_board(unit, board_id)
	if current == null:
		return false
	# Repositioning an admitted unit is movement's responsibility, never faction deployment.
	var existing: BoardData = get_board_for_unit(unit)
	if existing != null and existing != current:
		return false
	if current.place(unit, cell):
		return true
	var anchor: Vector2i = current.nearest_empty_anchor(unit, cell)
	return anchor != BaseCombatant.BOARD_ANCHOR_NONE and current.place(unit, anchor)

func reset_action_state(unit: BaseCombatant) -> void:
	for current: BoardData in battlefield.boards.values():
		current.reset_action_state(unit)

func get_move_budget(unit: BaseCombatant) -> int:
	return unit.move_points + max(0, rules.paid_move_max_cells - unit.paid_cells_this_action) if unit != null else 0

func move_party_unit(unit: BaseCombatant, cell: Vector2i) -> bool:
	var current: BoardData = get_board_for_unit(unit)
	if current == null:
		return false
	var reachable: Dictionary = current.reachable_active(unit)
	if not reachable.has(cell) or reachable[cell].is_empty():
		return false
	var path: Array = reachable[cell]
	var actions: Array[BaseAction] = ActionGenerator.create_actions(unit, null, [unit], [{
		Scripts.ACTION_MOVE_UNIT: {"mode": ActionMoveUnit.MODE_TO_CELL, "target_cell": cell, "distance": path.size(), "consumes_move_points": true, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}
	}], null)
	ActionHandler.add_actions(actions)
	return true

## One sorted queue preserves cross-board tick chronology and generated child ordering.
func advance_fields(previous: int, current: int) -> void:
	var controllers: Array[FieldController] = []
	controllers.assign(field_controllers.values())
	if current > previous and not controllers.is_empty():
		ActionHandler.add_ordered_actions([FieldClockAction.new(controllers, previous, current)])
