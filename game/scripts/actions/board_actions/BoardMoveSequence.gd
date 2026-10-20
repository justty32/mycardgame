## Ordered movement continuation. Each child effect resolves before the next step.
## No coroutine or retained board/controller cycle survives ActionHandler.clear_all_actions().
extends BaseAction
class_name BoardMoveSequence

var state: Dictionary = {}
var stage: int = 0

static func start(board: BoardData, unit: BaseCombatant, path: Array[Vector2i], source: BaseAction, options: Dictionary) -> void:
	var action: BoardMoveSequence = BoardMoveSequence.new()
	action.inherit_execution_context(source)
	action.state = {"board": weakref(board), "unit": weakref(unit), "path": path, "source": source, "options": options,
		"index": 0, "from": unit.board_anchor, "cursor": unit.board_anchor, "moved": 0, "cost": 0, "collided": false, "expected_anchor": unit.board_anchor, "expected_board": unit.board_id, "generation": ActionHandler._action_generation, "crossed": {}, "finished": false, "director_running": _running_director()}
	action.perform_action()

func perform_action() -> void:
	if not state.source.prepare_execution() or not prepare_execution():
		return
	var board: BoardData = state.board.get_ref()
	var unit: BaseCombatant = state.unit.get_ref()
	if not _valid(board, unit):
		_finish(board, unit)
		return
	while state.index < state.path.size():
		if not _valid(board, unit):
			_finish(board, unit)
			return
		var from: Vector2i = state.cursor
		var to: Vector2i = state.path[state.index]
		var options: Dictionary = state.options
		var last: bool = state.index == state.path.size() - 1
		if stage == 0:
			var allowed: bool = board.can_teleport(unit, to) if options.get("teleport", false) else (board.can_stand(unit, to) if last or options.get("forced", false) or (options.get("charge", false) and not unit.ignores_occupancy) else board.can_pass(unit, to))
			if not allowed:
				_collision(board, unit, to)
				_finish(board, unit)
				return
			var step: int = board.step_cost(unit, from, to, options.get("ignore_zoc", false))
			if options.get("consumes", false) and unit.move_points < step and unit.paid_cells_this_action >= board.rules.paid_move_max_cells:
				_finish(board, unit)
				return
			state.step_cost = step
			stage = 1
			var before: Array[BaseAction] = board.movement_state.opportunity_actions(board, unit, from, options.get("ignore_zoc", false), options.get("forced", false), state.source)
			before.append_array(_field_actions(board, unit, from, to, false, state.index > 0))
			if _suspend(before):
				return
		if stage == 1:
			# The previous field or opportunity action may have killed, moved or blocked us.
			if not _valid(board, unit):
				_finish(board, unit)
				return
			state.step_cost = board.step_cost(unit, from, to, options.get("ignore_zoc", false))
			if options.get("consumes", false) and unit.move_points < state.step_cost and unit.paid_cells_this_action >= board.rules.paid_move_max_cells:
				_finish(board, unit)
				return
			if options.get("teleport", false) and not board.can_teleport(unit, to):
				_finish(board, unit)
				return
			var did_place: bool = false
			if board.can_stand(unit, to):
				did_place = true
				board.move(unit, to)
				state.expected_anchor = unit.board_anchor
			elif last or options.get("forced", false) or (options.get("charge", false) and not unit.ignores_occupancy) or not board.can_pass(unit, to):
				_finish(board, unit)
				return
			state.cursor = to
			var moved_now: int = board.distance(from, to) if options.get("teleport", false) else 1
			state.moved += moved_now
			var source: BaseAction = state.source
			if source.card_play_request != null:
				var counter_key: String = "displaced_cells" if options.get("forced", false) else "moved_cells"
				source.card_play_request.card_values[counter_key] = int(source.card_play_request.card_values.get(counter_key, 0)) + moved_now
			state.cost += state.step_cost
			if options.get("forced", false):
				unit.cells_displaced_this_action += board.distance(from, to) if options.get("teleport", false) else 1
			else:
				unit.cells_moved_this_action += board.distance(from, to) if options.get("teleport", false) else 1
			var paid: bool = false
			if options.get("consumes", false):
				paid = unit.move_points < state.step_cost
				unit.move_points = max(0, unit.move_points - int(state.step_cost))
				if paid:
					unit.paid_cells_this_action += 1
					unit.action_extra_delay += board.rules.extra_move_delay_per_cell
			if did_place:
				Signals.unit_board_moved.emit(unit, board.board_id, from, board.board_id, to)
			if paid and _valid(board, unit):
				Signals.timeline_changed.emit()
			if not _valid(board, unit):
				_finish(board, unit)
				return
			stage = 2
			var after: Array[BaseAction] = _field_actions(board, unit, from, to, true, not last)
			var path_actions: Array[Dictionary] = []
			path_actions.assign(options.get("path_actions", []))
			if not path_actions.is_empty() and unit.ignores_occupancy:
				var crossed: Array[BaseCombatant] = board.units_in_cells(BoardData.footprint_cells(to, unit.footprint))
				crossed.erase(unit)
				var unique_crossed: Array[BaseCombatant] = []
				for crossed_unit: BaseCombatant in crossed:
					if not state.crossed.has(crossed_unit.unit_uid):
						state.crossed[crossed_unit.unit_uid] = true
						unique_crossed.append(crossed_unit)
				crossed = unique_crossed
				if not crossed.is_empty():
					board.invalidate_undo(unit)
					after.append_array(ActionGenerator.create_actions(unit, state.source.card_play_request, crossed, path_actions, state.source))
			if _suspend(after):
				return
		state.index += 1
		stage = 0
	_finish(board, unit)

func _field_actions(board: BoardData, unit: BaseCombatant, from: Vector2i, to: Vector2i, entering: bool, intermediate: bool) -> Array[BaseAction]:
	if board.field_controller == null or board.field_controller.get_ref() == null:
		return []
	return board.field_controller.get_ref().make_movement_actions(unit, from, to, entering, intermediate, state.source)

func _suspend(actions: Array[BaseAction]) -> bool:
	if not _valid(state.board.get_ref(), state.unit.get_ref()):
		return true
	if actions.is_empty():
		return false
	var continuation: BoardMoveSequence = BoardMoveSequence.new()
	continuation.inherit_execution_context(state.source)
	continuation.state = state
	continuation.stage = stage
	actions.append(continuation)
	ActionHandler.add_ordered_actions(actions)
	return true

func _collision(board: BoardData, unit: BaseCombatant, to: Vector2i) -> void:
	if not state.options.get("forced", false) or state.options.get("teleport", false):
		return
	state.collided = true
	if state.source.card_play_request != null:
		state.source.card_play_request.card_values["collided"] = true
	var blocker: BaseCombatant = null
	for cell: Vector2i in BoardData.footprint_cells(to, unit.footprint):
		var occupant: BaseCombatant = board.get_unit_at(cell)
		if occupant != null and occupant != unit:
			blocker = occupant
			break
	state.source._apply_collision(state.options.processor, unit, blocker, state.path.size() - state.index)

func _finish(board: BoardData, unit: BaseCombatant) -> void:
	if state.finished:
		return
	state.finished = true
	if state.moved > 0 and _valid(board, unit):
		Signals.unit_moved.emit(unit, state.from, unit.board_anchor)

static func _running_director() -> bool:
	var director: CombatDirector = Global.get_combat_director()
	return director != null and director.is_running

func _valid(board: BoardData, unit: BaseCombatant) -> bool:
	if board == null or not is_instance_valid(unit) or not unit.is_alive() or not board.has_unit(unit):
		return false
	if state.generation != ActionHandler._action_generation or (state.director_running and not _running_director()):
		return false
	return unit.board_id == state.expected_board and unit.board_anchor == state.expected_anchor
