## Atomic board placement followed by guarded old-board leave and new-board enter events.
## Geometry cannot be half-committed by a synchronous signal or a lethal field reaction.
extends BaseAction
class_name BoardTransferAction

var source: BaseAction
var unit_ref: WeakRef
var old_board_ref: WeakRef
var new_board_ref: WeakRef
var old_anchor: Vector2i
var new_anchor: Vector2i
var expected_generation: int
var originally_running: bool
var stage: int = 0
var ignore_zoc: bool = false
var forced: bool = false
var old_controllers: Array[BaseCombatant] = []

static func move_unit(action: BaseAction, unit: BaseCombatant, target_board_id: String, target_cell: Vector2i, is_forced: bool, zoc_ignored: bool) -> void:
	var director: CombatDirector = Global.get_combat_director()
	if director == null or director.battlefield == null:
		return
	var old_board: BoardData = director.battlefield.get_board_for_unit(unit)
	var new_board: BoardData = director.battlefield.get_board(target_board_id)
	if old_board == null or new_board == null or old_board == new_board:
		return
	var from: Vector2i = unit.board_anchor
	var controllers: Array[BaseCombatant] = old_board.zoc_controllers(unit, from, zoc_ignored, is_forced)
	if not director.battlefield.transfer(unit, BoardPosition.new(target_board_id, target_cell)):
		return
	old_board.invalidate_undo(unit)
	new_board.invalidate_undo(unit)
	# A cross-board placement is one transfer, never a fictitious distance between local cells.
	if is_forced:
		unit.cells_displaced_this_action += 1
	else:
		unit.cells_moved_this_action += 1
	_record(action, 1, is_forced)
	var event: BoardTransferAction = _event(action, unit, old_board, new_board, from, target_cell, is_forced, zoc_ignored)
	event.old_controllers = controllers
	Signals.unit_board_moved.emit(unit, old_board.board_id, from, new_board.board_id, target_cell)
	if event._valid(unit, old_board, new_board):
		ActionHandler.add_ordered_actions([event])

static func swap_units(action: BaseAction, unit_a: BaseCombatant, unit_b: BaseCombatant, zoc_ignored: bool) -> void:
	var director: CombatDirector = Global.get_combat_director()
	if director == null or director.battlefield == null:
		return
	var board_a: BoardData = director.battlefield.get_board_for_unit(unit_a)
	var board_b: BoardData = director.battlefield.get_board_for_unit(unit_b)
	if board_a == null or board_b == null:
		return
	var from_a: Vector2i = unit_a.board_anchor
	var from_b: Vector2i = unit_b.board_anchor
	var controllers_a: Array[BaseCombatant] = board_a.zoc_controllers(unit_a, from_a, zoc_ignored, true)
	var controllers_b: Array[BaseCombatant] = board_b.zoc_controllers(unit_b, from_b, zoc_ignored, true)
	if not director.battlefield.swap(unit_a, unit_b):
		return
	board_a.invalidate_undo(unit_a)
	board_a.invalidate_undo(unit_b)
	board_b.invalidate_undo(unit_a)
	board_b.invalidate_undo(unit_b)
	var amount: int = 1 if board_a != board_b else board_a.distance(from_a, from_b)
	unit_a.cells_displaced_this_action += amount
	unit_b.cells_displaced_this_action += amount
	_record(action, amount, true)
	var first: BoardTransferAction = _event(action, unit_a, board_a, board_b, from_a, from_b, true, zoc_ignored)
	var second: BoardTransferAction = _event(action, unit_b, board_b, board_a, from_b, from_a, true, zoc_ignored)
	first.old_controllers = controllers_a
	second.old_controllers = controllers_b
	Signals.unit_board_moved.emit(unit_a, board_a.board_id, from_a, board_b.board_id, from_b)
	if second._valid(unit_b, board_b, board_a):
		Signals.unit_board_moved.emit(unit_b, board_b.board_id, from_b, board_a.board_id, from_a)
	var events: Array[BaseAction] = []
	if first._valid(unit_a, board_a, board_b):
		events.append(first)
	if second._valid(unit_b, board_b, board_a):
		events.append(second)
	ActionHandler.add_ordered_actions(events)

static func _event(action: BaseAction, unit: BaseCombatant, old_board: BoardData, new_board: BoardData, from: Vector2i, to: Vector2i, is_forced: bool, zoc_ignored: bool) -> BoardTransferAction:
	var result := BoardTransferAction.new()
	result.source = action
	result.inherit_execution_context(action)
	result.unit_ref = weakref(unit)
	result.old_board_ref = weakref(old_board)
	result.new_board_ref = weakref(new_board)
	result.old_anchor = from
	result.new_anchor = to
	result.expected_generation = ActionHandler._action_generation
	result.originally_running = director_running()
	result.forced = is_forced
	result.ignore_zoc = zoc_ignored
	return result

static func _record(action: BaseAction, amount: int, is_forced: bool) -> void:
	if action.card_play_request != null:
		var key: String = "displaced_cells" if is_forced else "moved_cells"
		action.card_play_request.card_values[key] = int(action.card_play_request.card_values.get(key, 0)) + amount

static func director_running() -> bool:
	var director: CombatDirector = Global.get_combat_director()
	return director != null and director.is_running

func perform_action() -> void:
	if not source.prepare_execution() or not prepare_execution():
		return
	var unit: BaseCombatant = unit_ref.get_ref()
	var old_board: BoardData = old_board_ref.get_ref()
	var new_board: BoardData = new_board_ref.get_ref()
	if not _valid(unit, old_board, new_board):
		return
	var children: Array[BaseAction] = []
	if stage == 0:
		children = old_board.movement_state.opportunity_actions_from_controllers(old_board, unit, old_controllers, source)
	elif stage == 1:
		if old_board.field_controller != null and old_board.field_controller.get_ref() != null:
			children = old_board.field_controller.get_ref().make_transfer_actions(unit, old_anchor, false, source)
	elif stage == 2:
		if new_board.field_controller != null and new_board.field_controller.get_ref() != null:
			children = new_board.field_controller.get_ref().make_transfer_actions(unit, new_anchor, true, source)
	else:
		Signals.unit_moved.emit(unit, old_anchor, new_anchor)
		return
	if not _valid(unit, old_board, new_board):
		return
	var continuation: BoardTransferAction = _event(source, unit, old_board, new_board, old_anchor, new_anchor, forced, ignore_zoc)
	continuation.expected_generation = expected_generation
	continuation.originally_running = originally_running
	continuation.stage = stage + 1
	children.append(continuation)
	ActionHandler.add_ordered_actions(children)

func _valid(unit: BaseCombatant, old_board: BoardData, new_board: BoardData) -> bool:
	return is_instance_valid(unit) and unit.is_alive() and old_board != null and new_board != null and new_board.has_unit(unit) and unit.board_anchor == new_anchor and expected_generation == ActionHandler._action_generation and (not originally_running or director_running())
