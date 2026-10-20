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
	var movers: Array[BaseCombatant] = []
	if values.has("target_override"):
		movers = get_adjusted_action_targets()
	elif is_instance_valid(parent_combatant):
		movers = [parent_combatant]
	var actions: Array[BaseAction] = []
	if card_play_request != null:
		card_play_request.card_values["moved_cells"] = 0
	for unit: BaseCombatant in movers:
		actions.append(BoardMovementDispatch.new(self, unit, &"_move_unit"))
	ActionHandler.add_ordered_actions(actions)

func _move_unit(board: BoardData, unit: BaseCombatant, processor: ActionInterceptorProcessor) -> void:
	var mode: String = str(processor.get_shadowed_action_values("mode", MODE_TO_CELL))
	var distance: int = int(processor.get_shadowed_action_values("distance", -1))
	if distance == 0:
		return
	var teleport: bool = mode == MODE_TELEPORT or not bool(processor.get_shadowed_action_values("use_path", true))
	if teleport and bool(processor.get_shadowed_action_values("teleport_blocked", false)):
		return
	var target_board_id: String = str(processor.get_shadowed_action_values("target_board_id", ""))
	if target_board_id == "" and processor.get_shadowed_action_values("target_cell", null) == null and card_play_request != null and card_play_request.selected_board_id != "" and card_play_request.selected_board_id != board.board_id and (teleport or mode == MODE_TO_CELL):
		return
	if target_board_id == "SELECTED" and card_play_request != null:
		target_board_id = card_play_request.selected_board_id
	if target_board_id != "" and target_board_id != board.board_id:
		# An explicit teleport/direct placement authorizes crossing. Ordinary paths never do.
		if teleport:
			BoardTransferAction.move_unit(self, unit, target_board_id, _get_target_cell(processor), false, bool(processor.get_shadowed_action_values("ignore_zoc", false)))
		return
	var consumes: bool = bool(processor.get_shadowed_action_values("consumes_move_points", false)) and not teleport
	var ignore_zoc: bool = bool(processor.get_shadowed_action_values("ignore_zoc", false))
	var from: Vector2i = unit.board_anchor
	var destination: Vector2i = from
	var path: Array[Vector2i] = []
	var reachable: Dictionary = board.reachable_active(unit, ignore_zoc, distance) if consumes else board.reachable_steps(unit, distance, ignore_zoc)
	if teleport:
		destination = _get_target_cell(processor)
		if destination == from or not board.can_teleport(unit, destination):
			return
		if distance >= 0 and board.distance(from, destination) > distance:
			return
		path = [destination]
	elif processor.get_shadowed_action_values("planned_path", null) != null:
		for value: Variant in processor.get_shadowed_action_values("planned_path", []):
			path.append(EncounterData.cell_from_json(value))
		var previous: Vector2i = from
		for cell: Vector2i in path:
			if not BoardPathfinding.neighbours(board).has(cell - previous):
				return
			previous = cell
		if path.is_empty() or (distance >= 0 and path.size() > distance):
			return
	elif mode == MODE_TOWARD or mode == MODE_AWAY:
		var reference: BaseCombatant = _get_reference_unit(board, unit, processor)
		if reference == null or not board.has_unit(reference):
			return
		var stop: int = int(processor.get_shadowed_action_values("stop_at_distance", 1))
		var choice: Array = _choose_relative(board, unit, reference, distance, mode == MODE_TOWARD, stop, reachable, ignore_zoc)
		path.assign(choice[1])
	else:
		destination = _get_target_cell(processor)
		path.assign(reachable.get(destination, []))
	if path.is_empty():
		return
	board.capture_move_start(unit)
	if card_play_request != null:
		board.invalidate_undo(unit)
	BoardMoveSequence.start(board, unit, path, self, {"teleport": teleport, "consumes": consumes, "ignore_zoc": ignore_zoc, "path_actions": processor.get_shadowed_action_values("path_actions", []), "distance": distance, "charge": bool(processor.get_shadowed_action_values("charge", false))})

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
func _choose_relative(board: BoardData, unit: BaseCombatant, reference: BaseCombatant, budget: int, toward: bool, stop_at_distance: int, supplied_reachable: Dictionary = {}, ignore_zoc: bool = false) -> Array:
	var reachable: Dictionary = supplied_reachable if not supplied_reachable.is_empty() else board.reachable_cells(unit, budget, null, ignore_zoc)
	var best_anchor: Vector2i = unit.board_anchor
	var best_key: int = -1
	for anchor: Vector2i in reachable:
		var distance: int = board.unit_distance(unit, reference, anchor)
		var primary: int = 0
		if toward:
			primary = 0 if distance <= stop_at_distance else 1 + distance
		else:
			primary = 999 - min(998, distance)
		var key: int = BoardData.sort_key([primary, board.path_cost(unit, reachable[anchor], ignore_zoc), anchor.y, anchor.x])
		if best_key < 0 or key < best_key:
			best_key = key
			best_anchor = anchor
	return [best_anchor, reachable.get(best_anchor, [])]

func _to_string() -> String:
	return "Move Unit Action: " + str(get_action_value("mode", MODE_TO_CELL))
