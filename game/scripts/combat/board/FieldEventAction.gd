## Deferred field boundary. Resolves the living owner and occupancy at execution, and
## puts child payloads ahead of the next movement/tick continuation.
extends BaseAction
class_name FieldEventAction

var _controller_ref: WeakRef
var _unit_ref: WeakRef
var generation: int
var event: String
var cell: Vector2i
var instance: FieldInstance
var intermediate: bool
var scheduled_revision: int = -1
var scheduled_tick: int = -1
var expected_board_id: String = ""
var expected_anchor: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE

func _init(controller: FieldController, event_name: String, at_cell: Vector2i,
		unit: BaseCombatant = null, field: FieldInstance = null,
		passing: bool = false, ancestor: BaseAction = null) -> void:
	_controller_ref = weakref(controller)
	execution_scope_ref = _controller_ref
	execution_scope_generation = controller.generation
	_unit_ref = weakref(unit) if is_instance_valid(unit) else null
	generation = controller.generation
	event = event_name
	cell = at_cell
	instance = field
	intermediate = passing
	parent_action = ancestor
	resolve_children_immediately = true
	if ancestor != null:
		effective_tick = ancestor.effective_tick
	if is_instance_valid(unit) and event in ["enter", "leave"]:
		expected_board_id = unit.board_id
		expected_anchor = unit.board_anchor

func perform_action() -> void:
	var controller: FieldController = _controller_ref.get_ref()
	if controller == null or not controller.active or generation != controller.generation or controller.board == null:
		return
	if instance != null and (not controller.has_field(instance) or (scheduled_revision >= 0 and scheduled_revision != instance.revision)):
		return
	if scheduled_tick >= 0:
		effective_tick = scheduled_tick
	if event == "expire":
		controller.remove_field(instance)
		return
	var unit: BaseCombatant = _unit_ref.get_ref() if _unit_ref != null else controller.board.get_unit_at(cell)
	if not is_instance_valid(unit) or not unit.is_alive():
		return
	if expected_anchor != BaseCombatant.BOARD_ANCHOR_NONE and (unit.board_id != expected_board_id or unit.board_anchor != expected_anchor):
		return
	# Cross-board transfer commits both endpoints before leave effects; only leave may
	# legitimately refer to a cell the unit no longer occupies.
	if event != "leave" and not intermediate and controller.board.get_unit_at(cell) != unit:
		return
	if event == "enter" or event == "spawn":
		Signals.unit_entered_cell.emit(unit, controller.board.board_id, cell)
	elif event == "leave":
		Signals.unit_left_cell.emit(unit, controller.board.board_id, cell)
	if generation != controller.generation or not controller.active:
		return
	if expected_anchor != BaseCombatant.BOARD_ANCHOR_NONE and (not is_instance_valid(unit) or unit.board_id != expected_board_id or unit.board_anchor != expected_anchor):
		return
	var fields: Array[FieldInstance] = []
	if instance != null:
		fields.append(instance)
	else:
		fields.assign(controller.board.get_fields(cell))
	var actions: Array[BaseAction] = []
	for field: FieldInstance in fields:
		if not controller.has_field(field) or not field.affects(unit):
			continue
		var data: FieldData = field.field_data
		if intermediate and not data.field_triggers_on_pass_through:
			continue
		if event == "spawn" and not data.field_triggers_on_spawn:
			continue
		var payload: Array[Dictionary] = []
		match event:
			"enter", "spawn": payload = data.field_on_enter_actions
			"leave": payload = data.field_on_leave_actions
			"stay": payload = data.field_on_stay_actions
			"tick": payload = data.field_tick_actions
		if payload.is_empty():
			continue
		controller.board.invalidate_undo(unit)
		for stack: int in field.stacks:
			for child: BaseAction in ActionGenerator.create_actions(field.get_owner(), null, [unit], payload, self):
				child.owner_bound = true
				child.owner_uid = field.owner_uid
				actions.append(child)
	ActionHandler.add_ordered_actions(actions)
