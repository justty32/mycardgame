## Forced displacement on the combat board (combat framework Phase 2). Targets = the displaced units
## (default the selected targets). Values:
##   mode: "PUSH" (default, away from the origin) | "PULL" (toward it) | "PULL_ADJACENT" (pull until
##         adjacent) | "SWAP" (exchange anchors with the parent) | "TO_CELL" (place on target_cell /
##         the selected cell)
##   distance: cells (default 1; status interceptors may set 0 = rooted)
##   origin_cell: [x, y]; default the parent's anchor
##   collision_damage_per_cell: damage to the displaced unit per remaining cell when blocked (default 0)
##   collision_damage_to_blocker: damage to a unit that blocked it (default 0)
##   bypass_block: collision damage ignores block (default false)
## Direction = main axis from the origin to the target (ties: rules.displace_tie_axis). Steps stop at
## the board edge, blocked cells and units. Immovable units and footprints larger than
## rules.displace_max_footprint_area do not move. Forced movement uses no move points and does not
## count toward cells_moved_this_action (cells_displaced_this_action instead). Writes card_values
## "displaced_cells" and "collided". Units that left the board are skipped.
extends BaseAction
class_name ActionDisplaceUnit

const MODE_PUSH: String = "PUSH"
const MODE_PULL: String = "PULL"
const MODE_PULL_ADJACENT: String = "PULL_ADJACENT"
const MODE_SWAP: String = "SWAP"
const MODE_TO_CELL: String = "TO_CELL"

func perform_action() -> void:
	var board: BoardData = BoardData.get_active()
	if board == null:
		return
	var displaced_total: int = 0
	var collided_any: bool = false
	for action_interceptor_processor: ActionInterceptorProcessor in _intercept_action():
		var unit: BaseCombatant = action_interceptor_processor.target
		if unit == null or not is_instance_valid(unit) or not unit.is_alive() or not board.has_unit(unit):
			continue
		var result: Array = _displace(board, unit, action_interceptor_processor)
		displaced_total += result[0]
		collided_any = collided_any or result[1]
	if card_play_request != null:
		card_play_request.card_values["displaced_cells"] = displaced_total
		card_play_request.card_values["collided"] = collided_any

## Returns [cells moved, collided].
func _displace(board: BoardData, unit: BaseCombatant, processor: ActionInterceptorProcessor) -> Array:
	var mode: String = str(processor.get_shadowed_action_values("mode", MODE_PUSH))
	var distance: int = int(processor.get_shadowed_action_values("distance", 1))
	if not is_displaceable(board, unit) or distance == 0:
		return [0, false]
	var from: Vector2i = unit.board_anchor
	match mode:
		MODE_SWAP:
			if parent_combatant == null or parent_combatant == unit or not board.has_unit(parent_combatant):
				return [0, false]
			var parent_from: Vector2i = parent_combatant.board_anchor
			if not board.swap(parent_combatant, unit):
				return [0, false]
			unit.cells_displaced_this_action += board.distance(from, unit.board_anchor)
			Signals.unit_moved.emit(parent_combatant, parent_from, parent_combatant.board_anchor)
			Signals.unit_moved.emit(unit, from, unit.board_anchor)
			return [board.distance(from, unit.board_anchor), false]
		MODE_TO_CELL:
			var cell: Vector2i = EncounterData.cell_from_json(processor.get_shadowed_action_values("target_cell", null))
			if cell == BaseCombatant.BOARD_ANCHOR_NONE and card_play_request != null:
				cell = card_play_request.selected_cell
			if cell == from or not board.move(unit, cell):
				return [0, false]
			unit.cells_displaced_this_action += board.distance(from, cell)
			Signals.unit_moved.emit(unit, from, cell)
			return [board.distance(from, cell), false]
	var origin: Vector2i = EncounterData.cell_from_json(processor.get_shadowed_action_values("origin_cell", null))
	if origin == BaseCombatant.BOARD_ANCHOR_NONE:
		if parent_combatant == null or not board.has_unit(parent_combatant):
			return [0, false]
		origin = parent_combatant.board_anchor
	var direction: Vector2i = BoardTargeting.main_axis_direction(origin, from, board.rules.displace_tie_axis)
	if direction == Vector2i.ZERO:
		return [0, false]
	var steps: int = distance
	if mode == MODE_PULL or mode == MODE_PULL_ADJACENT:
		direction = -direction
	if mode == MODE_PULL_ADJACENT:
		# pull until adjacent to the origin unit (or origin cell): remaining = distance - 1
		var reference_distance: int = board.unit_distance(unit, parent_combatant) if (parent_combatant != null and board.has_unit(parent_combatant) and not values.has("origin_cell")) else board.footprint_distance_to_cell(from, unit.footprint, origin)
		steps = max(0, reference_distance - 1)
	var anchor: Vector2i = from
	var moved: int = 0
	var blocker: BaseCombatant = null
	var collided: bool = false
	while moved < steps:
		var next: Vector2i = anchor + direction
		if not board.can_stand(unit, next):
			collided = true
			for cell: Vector2i in BoardData.footprint_cells(next, unit.footprint):
				var occupant: BaseCombatant = board.get_unit_at(cell)
				if occupant != null and occupant != unit:
					blocker = occupant
					break
			break
		anchor = next
		moved += 1
	if moved > 0:
		board.move(unit, anchor)
		unit.cells_displaced_this_action += moved
		Signals.unit_moved.emit(unit, from, anchor)
	if collided:
		_apply_collision(processor, unit, blocker, steps - moved)
	return [moved, collided]

func _apply_collision(processor: ActionInterceptorProcessor, unit: BaseCombatant, blocker: BaseCombatant, remaining: int) -> void:
	var bypass_block: bool = bool(processor.get_shadowed_action_values("bypass_block", false))
	var collision_actions: Array[BaseAction] = []
	var per_cell: int = int(processor.get_shadowed_action_values("collision_damage_per_cell", 0))
	if per_cell > 0 and remaining > 0:
		collision_actions += ActionGenerator.create_actions(parent_combatant, card_play_request, [unit], [{
			Scripts.ACTION_DIRECT_DAMAGE: {"damage": per_cell * remaining, "bypass_block": bypass_block, "time_delay": 0.0}
		}], self)
	var to_blocker: int = int(processor.get_shadowed_action_values("collision_damage_to_blocker", 0))
	if to_blocker > 0 and blocker != null and blocker.is_alive():
		collision_actions += ActionGenerator.create_actions(parent_combatant, card_play_request, [blocker], [{
			Scripts.ACTION_DIRECT_DAMAGE: {"damage": to_blocker, "bypass_block": bypass_block, "time_delay": 0.0}
		}], self)
	if not collision_actions.is_empty():
		ActionHandler.add_actions(collision_actions)

## Not immovable and footprint area within rules.displace_max_footprint_area.
static func is_displaceable(board: BoardData, unit: BaseCombatant) -> bool:
	if unit == null or unit.is_immovable:
		return false
	return unit.footprint.x * unit.footprint.y <= board.rules.displace_max_footprint_area

func _to_string() -> String:
	return "Displace Unit Action: " + str(get_action_value("mode", MODE_PUSH))
