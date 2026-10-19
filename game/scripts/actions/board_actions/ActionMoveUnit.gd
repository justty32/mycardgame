## Moves units on the combat board (combat framework Phase 2). Targets = the movers: the parent
## unless values give a target_override. Values:
##   mode: "TO_CELL" (default) | "TOWARD" | "AWAY" | "TELEPORT"
##   distance: max cells (-1 = unlimited; status interceptors may set 0 = rooted)
##   target_cell: [x, y] / Vector2i (TO_CELL, TELEPORT); default card_play_request.selected_cell
##   reference: "SELECTED_TARGET" (default) | "PARENT" | "NEAREST_OPPONENT" | "HERO" (TOWARD / AWAY)
##   stop_at_distance: TOWARD stops once this close to the reference (default 1)
##   consumes_move_points: spend free move points, then paid cells (+extra_move_delay_per_cell each)
## TO_CELL / TOWARD / AWAY follow BoardData paths; TELEPORT needs a free target cell and ignores paths.
## Emits unit_moved once per moved unit and writes card_values "moved_cells".
extends BaseAction
class_name ActionMoveUnit

const MODE_TO_CELL: String = "TO_CELL"
const MODE_TOWARD: String = "TOWARD"
const MODE_AWAY: String = "AWAY"
const MODE_TELEPORT: String = "TELEPORT"
const REFERENCE_SELECTED_TARGET: String = "SELECTED_TARGET"
const REFERENCE_PARENT: String = "PARENT"
const REFERENCE_NEAREST_OPPONENT: String = "NEAREST_OPPONENT"
const REFERENCE_HERO: String = "HERO"

func perform_action() -> void:
	var board: BoardData = BoardData.get_active()
	if board == null:
		return
	var movers: Array[BaseCombatant] = []
	if values.has("target_override"):
		movers = get_adjusted_action_targets()
	elif parent_combatant != null and is_instance_valid(parent_combatant):
		movers = [parent_combatant]
	if movers.is_empty():
		return
	for action_interceptor_processor: ActionInterceptorProcessor in _intercept_action(movers):
		var unit: BaseCombatant = action_interceptor_processor.target
		if unit == null or not is_instance_valid(unit) or not unit.is_alive() or not board.has_unit(unit):
			continue
		_move_unit(board, unit, action_interceptor_processor)

func _move_unit(board: BoardData, unit: BaseCombatant, processor: ActionInterceptorProcessor) -> void:
	var mode: String = str(processor.get_shadowed_action_values("mode", MODE_TO_CELL))
	var distance: int = int(processor.get_shadowed_action_values("distance", -1))
	if distance == 0:
		return
	var consumes_move_points: bool = bool(processor.get_shadowed_action_values("consumes_move_points", false))
	var budget: int = distance
	if consumes_move_points:
		var available: int = unit.move_points + max(0, board.rules.paid_move_max_cells - unit.paid_cells_this_action)
		budget = available if budget < 0 else min(budget, available)
		if budget <= 0:
			return
	var from: Vector2i = unit.board_anchor
	var destination: Vector2i = from
	var path: Array[Vector2i] = []
	match mode:
		MODE_TELEPORT:
			destination = _get_target_cell(processor)
			if destination == from or not board.can_stand(unit, destination):
				return
			if budget >= 0 and board.distance(from, destination) > budget:
				return
		MODE_TOWARD, MODE_AWAY:
			var reference: BaseCombatant = _get_reference_unit(board, unit, processor)
			if reference == null or not board.has_unit(reference):
				return
			var stop_at_distance: int = int(processor.get_shadowed_action_values("stop_at_distance", 1))
			var choice: Array = _choose_relative(board, unit, reference, budget, mode == MODE_TOWARD, stop_at_distance)
			destination = choice[0]
			path.assign(choice[1])
		_:
			destination = _get_target_cell(processor)
			if destination == from:
				return
			path = board.find_path(unit, destination, budget)
			if path.is_empty():
				return
	if destination == from or not board.move(unit, destination):
		return
	var cells_moved: int = len(path) if mode != MODE_TELEPORT else board.distance(from, destination)
	unit.cells_moved_this_action += cells_moved
	if consumes_move_points:
		var free_cells: int = min(cells_moved, unit.move_points)
		var paid_cells: int = cells_moved - free_cells
		unit.move_points -= free_cells
		unit.paid_cells_this_action += paid_cells
		unit.action_extra_delay += paid_cells * board.rules.extra_move_delay_per_cell
		if paid_cells > 0:
			Signals.timeline_changed.emit()
	if card_play_request != null:
		card_play_request.card_values["moved_cells"] = cells_moved
	Signals.unit_moved.emit(unit, from, destination)

func _get_target_cell(processor: ActionInterceptorProcessor) -> Vector2i:
	var cell: Vector2i = EncounterData.cell_from_json(processor.get_shadowed_action_values("target_cell", null))
	if cell == BaseCombatant.BOARD_ANCHOR_NONE and card_play_request != null:
		cell = card_play_request.selected_cell
	return cell

func _get_reference_unit(board: BoardData, unit: BaseCombatant, processor: ActionInterceptorProcessor) -> BaseCombatant:
	match str(processor.get_shadowed_action_values("reference", REFERENCE_SELECTED_TARGET)):
		REFERENCE_PARENT:
			return parent_combatant
		REFERENCE_HERO:
			return UnitRegistry.get_hero()
		REFERENCE_NEAREST_OPPONENT:
			var best: BaseCombatant = null
			for other: BaseCombatant in board.get_units():
				if other.is_alive() and other.faction != unit.faction and other.faction != BaseCombatant.FACTIONS.NEUTRAL:
					if best == null or board.unit_distance(unit, other) < board.unit_distance(unit, best):
						best = other
			return best
	if card_play_request != null:
		if card_play_request.selected_target != null and is_instance_valid(card_play_request.selected_target):
			return card_play_request.selected_target
		if not card_play_request.resolved_targets.is_empty():
			return card_play_request.resolved_targets[0]
	return null

## [anchor, path]: TOWARD = shortest path to within stop_at_distance, else closest;
## AWAY = farthest from the reference. Ties: shorter path, then smaller y, then smaller x.
func _choose_relative(board: BoardData, unit: BaseCombatant, reference: BaseCombatant, budget: int, toward: bool, stop_at_distance: int) -> Array:
	var reachable: Dictionary = board.reachable_cells(unit, budget)
	var best_anchor: Vector2i = unit.board_anchor
	var best_key: int = -1
	for anchor: Vector2i in reachable:
		var distance: int = board.unit_distance(unit, reference, anchor)
		var primary: int = 0
		if toward:
			primary = 0 if distance <= stop_at_distance else 1 + distance
		else:
			primary = 999 - min(998, distance)
		var key: int = BoardData.sort_key([primary, len(reachable[anchor]), anchor.y, anchor.x])
		if best_key < 0 or key < best_key:
			best_key = key
			best_anchor = anchor
	return [best_anchor, reachable.get(best_anchor, [])]

func _to_string() -> String:
	return "Move Unit Action: " + str(get_action_value("mode", MODE_TO_CELL))
