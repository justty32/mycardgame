## Owns the boards, field controllers and movement state of one combat.
## Placement policy supplies initial positions; subsequent queries use actual board identity.
extends RefCounted
class_name BoardController

var rules: CombatRulesData
var encounter: EncounterData
var battlefield: CombatBattlefield
var board_setup: BoardSetup
var error: String = ""
var error_detail: String = ""
var _hero: BaseCombatant
var _hero_location: Dictionary = {}
var deployment: BoardDeployment
var field_controllers: Dictionary[String, FieldController] = {}
## Legacy query seam: shared board in SINGLE, party board in DUAL.
var board: BoardData:
	get:
		if battlefield == null or deployment == null:
			return null
		var id: String = deployment.hero_location(BaseCombatant.FACTIONS.PARTY).board_id
		return battlefield.get_board(id)
var field_controller: FieldController:
	get:
		return FieldController.for_board(board)

func _init(combat_rules: CombatRulesData) -> void:
	rules = combat_rules

func setup(encounter_data: EncounterData) -> bool:
	if not setup_prepared(encounter_data, BoardSetup.from_legacy(encounter_data, rules)):
		return false
	commit_setup()
	return true

## Detached resources and pure placement queries only; no hero mutation or public events.
func setup_prepared(encounter_data: EncounterData, prepared: BoardSetup) -> bool:
	encounter = encounter_data
	board_setup = prepared.detached_copy()
	deployment = board_setup.deployment
	battlefield = CombatBattlefield.new(board_setup, rules)
	if not battlefield.valid:
		return _fail(battlefield.error, battlefield.error_detail)
	if deployment == null or deployment.error != "":
		return _fail("invalid_board_deployment", "positive boards require deployment")
	var shared_opportunities: Dictionary = {}
	for current: BoardData in battlefield.boards.values():
		current.movement_state.used_opportunities = shared_opportunities
		var controller := FieldController.new(current)
		controller.published = false
		field_controllers[current.board_id] = controller
		var config: Dictionary = board_setup.get_config(current.board_id)
		for cell: Vector2i in deployment.deploy_cells(current.board_id):
			if current.is_in_bounds(cell):
				current.get_cell(cell).is_deploy_zone = true
		for cell: Vector2i in deployment.spawn_cells(current.board_id):
			if current.is_in_bounds(cell):
				current.get_cell(cell).is_spawn_zone = true
		for entry: Dictionary in config.initial_fields:
			var data: FieldData = Global.get_field_data(str(entry.get("field_id", "")))
			if data == null:
				if not board_setup.explicit:
					continue
				return _fail("invalid_initial_field", "board %s unknown field_id %s" % [current.board_id, entry.get("field_id", "")])
			for cell: Vector2i in EncounterData.cells_from_json(entry.get("cells", [])):
				controller.create_field(data, cell, null, 0, int(entry.get("duration", -2)))
	_hero = UnitRegistry.get_hero()
	if _hero != null:
		_hero_location = deployment.hero_location(_hero.faction)
		var current: BoardData = battlefield.get_board(_hero_location.board_id)
		if current == null:
			return _fail("invalid_hero_deployment", "hero destination board is missing")
		var anchor: Vector2i = _hero_location.cell if current.can_stand(_hero, _hero_location.cell) else current.nearest_empty_anchor(_hero, _hero_location.cell)
		if anchor == BaseCombatant.BOARD_ANCHOR_NONE:
			return _fail("hero_deployment_full", "hero footprint has no legal placement")
		_hero_location.cell = anchor
	return true

func commit_setup() -> void:
	if is_instance_valid(_hero) and not _hero_location.is_empty():
		battlefield.get_board(_hero_location.board_id).place(_hero, _hero_location.cell)
	_hero = null
	_hero_location.clear()
	for controller: FieldController in field_controllers.values():
		controller.discard_trial_fields()
	for controller: FieldController in field_controllers.values():
		controller.publish_fields()

func _fail(code: String, detail: String) -> bool:
	error = code
	error_detail = detail
	return false

func clear() -> void:
	_hero = null
	_hero_location.clear()
	for controller: FieldController in field_controllers.values():
		controller.clear()
	field_controllers.clear()
	battlefield = null
	board_setup = null
	deployment = null
	encounter = null

func get_board_for_unit(unit: BaseCombatant) -> BoardData:
	return battlefield.get_board_for_unit(unit) if battlefield != null else null

func get_spawn_board(unit: BaseCombatant, board_id: String = "") -> BoardData:
	if battlefield == null or not is_instance_valid(unit):
		return null
	if board_id != "":
		return battlefield.get_board(board_id)
	var existing: BoardData = get_board_for_unit(unit)
	return existing if existing != null else battlefield.get_board(deployment.default_board_id(unit.faction))

func default_deploy_cells(board_id: String = "") -> Array[Vector2i]:
	var id: String = deployment.default_board_id(BaseCombatant.FACTIONS.PARTY) if board_id == "" else board_id
	return deployment.default_deploy_cells(id)

func default_spawn_origin(board_id: String = "") -> Vector2i:
	return deployment.spawn_origin(board_id)

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
	# Execute exactly the previewed path (BoardView draws reachable_active); re-searching with a
	# step-limited key could pick an equal-cost path through other fields / control zones.
	var path: Array = reachable[cell]
	var actions: Array[BaseAction] = ActionGenerator.create_actions(unit, null, [unit], [{
		Scripts.ACTION_MOVE_UNIT: {"mode": ActionMoveUnit.MODE_TO_CELL, "target_cell": cell, "planned_path": path.duplicate(), "distance": path.size(), "consumes_move_points": true, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}
	}], null)
	ActionHandler.add_actions(actions)
	return true

## One sorted queue preserves cross-board tick chronology and generated child ordering.
func advance_fields(previous: int, current: int) -> void:
	var controllers: Array[FieldController] = []
	controllers.assign(field_controllers.values())
	if current > previous and not controllers.is_empty():
		ActionHandler.add_ordered_actions([FieldClockAction.new(controllers, previous, current)])
