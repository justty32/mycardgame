## Per-combat fields. Director calls clock/stay/spawn explicitly; movement supplies each
## leave/enter boundary. Queued events use weak ownership and a generation cancellation gate.
extends RefCounted
class_name FieldController

var _board_ref: WeakRef
var generation: int = 0
var active: bool = true
## Setup stages fields without observable events until the whole module is ready.
var published: bool = true
var _staged_creates: Array[Dictionary] = []
var _trial_discarded: bool = false
var board: BoardData:
	get:
		return _board_ref.get_ref() if _board_ref != null else null

func _init(combat_board: BoardData) -> void:
	_board_ref = weakref(combat_board)
	combat_board.field_controller = weakref(self)

## BaseAction execution scope: expanded field payloads die with this controller generation.
func is_execution_scope_active(scope_generation: int) -> bool:
	return active and generation == scope_generation

static func for_board(current: BoardData) -> FieldController:
	return current.field_controller.get_ref() if current != null and current.field_controller != null else null

static func get_for_unit(unit: BaseCombatant) -> FieldController:
	var battlefield: CombatBattlefield = CombatBattlefield.get_active()
	return for_board(battlefield.get_board_for_unit(unit)) if battlefield != null else null

func create_field(data: FieldData, cell: Vector2i, owner: BaseCombatant = null,
		current_tick: int = 0, duration_override: int = -2) -> FieldInstance:
	if not active or board == null or data == null or not board.is_in_bounds(cell):
		return null
	if not published:
		_staged_creates.append({"data": data, "cell": cell, "owner": owner, "tick": current_tick, "duration": duration_override})
	for existing: FieldInstance in board.get_fields(cell):
		if existing.field_data.object_id != data.object_id:
			continue
		match data.field_stack_policy:
			FieldData.STACK_POLICIES.IGNORE:
				return existing
			FieldData.STACK_POLICIES.STACK:
				existing.stacks += 1
				existing.refresh(current_tick, duration_override)
				if published:
					Signals.field_changed.emit(existing)
				if existing.expires_tick == current_tick:
					remove_field(existing)
				return existing
			_:
				remove_field(existing)
	if not active or board == null:
		return null
	var instance := FieldInstance.new(data, cell, owner, current_tick, duration_override)
	instance.board_id = board.board_id
	if not board.fields.has(cell):
		board.fields[cell] = []
	board.fields[cell].append(instance)
	if published:
		Signals.field_created.emit(instance)
	# A zero-duration field is observable as created/removed, but cannot trigger effects.
	if instance.expires_tick == current_tick:
		remove_field(instance)
	return instance

## Remove invisible trial instances on every board before the first public callback.
func discard_trial_fields() -> void:
	if not published and active and board != null and not _trial_discarded:
		board.fields.clear()
		_trial_discarded = true

## Publish only after every fallible setup step has succeeded.
func publish_fields() -> void:
	if published or not active:
		return
	var creates: Array[Dictionary] = _staged_creates
	_staged_creates = []
	# Discard invisible trial instances, then replay original operations so callbacks see
	# the same stack, membership and zero-duration state as ordinary create_field.
	discard_trial_fields()
	published = true
	for operation: Dictionary in creates:
		if not active:
			break
		create_field(operation.data, operation.cell, operation.owner, operation.tick, operation.duration)

func has_field(instance: FieldInstance) -> bool:
	return active and board != null and board.get_fields(instance.cell).has(instance)

func remove_field(instance: FieldInstance) -> bool:
	if board == null or not board.get_fields(instance.cell).has(instance):
		return false
	board.fields[instance.cell].erase(instance)
	if board.fields[instance.cell].is_empty():
		board.fields.erase(instance.cell)
	if published:
		Signals.field_removed.emit(instance)
	return true

func remove_fields(cells: Array[Vector2i] = [], field_id: String = "", tag: String = "") -> int:
	var removed: int = 0
	for instance: FieldInstance in _all_fields():
		if not cells.is_empty() and not cells.has(instance.cell):
			continue
		if field_id != "" and instance.field_data.object_id != field_id:
			continue
		if tag != "" and not instance.field_data.field_tags.has(tag):
			continue
		if remove_field(instance):
			removed += 1
	return removed

## The mover calls the leave half before changing occupancy, and the enter half afterwards.
## intermediate=true skips ordinary fields but still emits the public cell crossing signal.
func make_movement_actions(unit: BaseCombatant, from: Vector2i, to: Vector2i,
		entering: bool, intermediate: bool, parent_action: BaseAction = null) -> Array[BaseAction]:
	var result: Array[BaseAction] = []
	if not active or not is_instance_valid(unit) or from == to:
		return result
	var old_cells: Array[Vector2i] = BoardData.footprint_cells(from, unit.footprint)
	var new_cells: Array[Vector2i] = BoardData.footprint_cells(to, unit.footprint)
	var changed: Array[Vector2i] = new_cells if entering else old_cells
	var retained: Array[Vector2i] = old_cells if entering else new_cells
	for cell: Vector2i in changed:
		if not retained.has(cell):
			result.append(FieldEventAction.new(self, "enter" if entering else "leave", cell, unit, null, intermediate, parent_action))
	return result

## Transfer has already atomically committed occupancy. Even equal local coordinates
## on different boards represent distinct cells, so there is no footprint intersection.
func make_transfer_actions(unit: BaseCombatant, anchor: Vector2i, entering: bool,
		parent_action: BaseAction = null) -> Array[BaseAction]:
	var result: Array[BaseAction] = []
	if not active or not is_instance_valid(unit):
		return result
	for cell: Vector2i in BoardData.footprint_cells(anchor, unit.footprint):
		result.append(FieldEventAction.new(self, "enter" if entering else "leave", cell, unit, null, false, parent_action))
	return result

func on_unit_spawned(unit: BaseCombatant) -> void:
	_enqueue_unit_cells(unit, "spawn")

func on_unit_action_started(unit: BaseCombatant) -> void:
	_enqueue_unit_cells(unit, "stay")

func _enqueue_unit_cells(unit: BaseCombatant, event: String) -> void:
	if not active or board == null or not is_instance_valid(unit) or not unit.is_alive():
		return
	var actions: Array[BaseAction] = []
	for cell: Vector2i in board.get_unit_cells(unit):
		actions.append(FieldEventAction.new(self, event, cell, unit))
	ActionHandler.add_ordered_actions(actions)

## Single-board convenience wrapper; production uses one shared clock for all boards.
func advance_ticks(previous_tick: int, current_tick: int) -> void:
	if active and current_tick > previous_tick:
		ActionHandler.add_ordered_actions([FieldClockAction.new([self], previous_tick, current_tick)])

## Pure next-event query. A tick at the expiry boundary is excluded. Already consumed
## boundaries are represented by next_tick, so equal-time events on other fields remain due.
func next_tick_boundary(previous_tick: int, current_tick: int) -> Dictionary:
	var best: Dictionary = {}
	for instance: FieldInstance in _all_fields():
		var tick: int = instance.next_tick
		var interval: int = instance.field_data.field_tick_interval
		if interval > 0 and tick >= 0:
			if tick <= previous_tick:
				tick += (int((previous_tick - tick) / interval) + 1) * interval
			if tick <= current_tick and (instance.expires_tick < 0 or tick < instance.expires_tick):
				if best.is_empty() or tick < best.tick:
					best = {"tick": tick, "event": "tick", "instance": instance}
		if instance.expires_tick >= 0 and instance.expires_tick <= current_tick:
			if best.is_empty() or instance.expires_tick < best.tick:
				best = {"tick": instance.expires_tick, "event": "expire", "instance": instance}
	return best

## Positive = danger, negative = healing/block benefit. Query does not move the unit.
func preview_hazard(cell: Vector2i, unit: BaseCombatant) -> float:
	if not active or board == null or not is_instance_valid(unit):
		return 0.0
	var total: float = 0.0
	for covered: Vector2i in BoardData.footprint_cells(cell, unit.footprint):
		for instance: FieldInstance in board.get_fields(covered):
			if instance.affects(unit):
				var data: FieldData = instance.field_data
				total += instance.stacks * FieldPreview.preview_actions(data.field_on_enter_actions + data.field_on_stay_actions, instance.get_owner(), unit)
	return total

func clear() -> void:
	generation += 1
	active = false
	_staged_creates.clear()
	for instance: FieldInstance in _all_fields():
		remove_field(instance)
	if board != null and board.field_controller != null and board.field_controller.get_ref() == self:
		board.field_controller = null
	_board_ref = null

func _all_fields() -> Array[FieldInstance]:
	var result: Array[FieldInstance] = []
	if board != null:
		for cell: Vector2i in board.fields:
			result.append_array(board.get_fields(cell))
	return result
