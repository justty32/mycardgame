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
	if card_play_request != null:
		card_play_request.card_values["displaced_cells"] = 0
		card_play_request.card_values["collided"] = false
	var actions: Array[BaseAction] = []
	for unit: BaseCombatant in get_adjusted_action_targets():
		actions.append(BoardMovementDispatch.new(self, unit, &"_displace"))
	ActionHandler.add_ordered_actions(actions)

func _displace(board: BoardData, unit: BaseCombatant, processor: ActionInterceptorProcessor) -> void:
	var mode: String = str(processor.get_shadowed_action_values("mode", MODE_PUSH))
	var distance: int = int(processor.get_shadowed_action_values("distance", 1))
	if not is_displaceable(board, unit) or distance <= 0:
		return
	var resistance: int = 0 if bool(processor.get_shadowed_action_values("ignore_resistance", false)) else max(0, unit.displace_resistance)
	var ignore_zoc: bool = bool(processor.get_shadowed_action_values("ignore_zoc", false))
	var from: Vector2i = unit.board_anchor
	if mode == MODE_SWAP:
		var parent_board: BoardData = BoardData.get_for_unit(parent_combatant)
		if parent_board == null or parent_combatant == unit or not is_displaceable(parent_board, parent_combatant):
			return
		if unit.footprint != parent_combatant.footprint or distance <= resistance or bool(processor.get_shadowed_action_values("teleport_blocked", false)):
			return
		# Swap is a two-participant displacement; both interception chains may reject it.
		var accepted_parent: bool = false
		for parent_processor: ActionInterceptorProcessor in _intercept_action([parent_combatant]):
			var parent_distance: int = int(parent_processor.get_shadowed_action_values("distance", 1))
			var parent_resistance: int = 0 if bool(parent_processor.get_shadowed_action_values("ignore_resistance", false)) else max(0, parent_combatant.displace_resistance)
			accepted_parent = parent_distance > parent_resistance and not bool(parent_processor.get_shadowed_action_values("teleport_blocked", false))
		if accepted_parent:
			BoardTransferAction.swap_units(self, parent_combatant, unit, ignore_zoc)
		return
	if mode == MODE_TO_CELL:
		if distance <= resistance or bool(processor.get_shadowed_action_values("teleport_blocked", false)):
			return
		if processor.get_shadowed_action_values("target_board_id", null) == null and processor.get_shadowed_action_values("target_cell", null) == null and card_play_request != null and card_play_request.selected_board_id != "" and card_play_request.selected_board_id != board.board_id:
			return
		var cell: Vector2i = EncounterData.cell_from_json(processor.get_shadowed_action_values("target_cell", null))
		if cell == BaseCombatant.BOARD_ANCHOR_NONE and card_play_request != null:
			cell = card_play_request.selected_cell
		var target_board_id: String = str(processor.get_shadowed_action_values("target_board_id", board.board_id))
		if target_board_id == "SELECTED" and card_play_request != null:
			target_board_id = card_play_request.selected_board_id
		if target_board_id != board.board_id:
			BoardTransferAction.move_unit(self, unit, target_board_id, cell, true, ignore_zoc)
		elif cell != from and board.can_teleport(unit, cell):
			board.invalidate_undo(unit)
			BoardMoveSequence.start(board, unit, [cell], self, {"forced": true, "teleport": true, "ignore_zoc": ignore_zoc, "processor": processor})
		return
	if not [MODE_PUSH, MODE_PULL, MODE_PULL_ADJACENT].has(mode):
		return
	# Directional cross-board effects have no direction in policy A.
	if is_instance_valid(parent_combatant) and parent_combatant.board_id != unit.board_id:
		return
	var origin: Vector2i = EncounterData.cell_from_json(processor.get_shadowed_action_values("origin_cell", null))
	if origin == BaseCombatant.BOARD_ANCHOR_NONE:
		if parent_combatant == null or not board.has_unit(parent_combatant):
			return
		origin = parent_combatant.board_anchor
	var direction: Vector2i = BoardTargeting.main_axis_direction(origin, from, board.rules.displace_tie_axis)
	if direction == Vector2i.ZERO:
		return
	var steps: int = distance
	if mode == MODE_PULL or mode == MODE_PULL_ADJACENT:
		direction = -direction
	if mode == MODE_PULL_ADJACENT:
		var reference_distance: int = board.unit_distance(unit, parent_combatant) if (parent_combatant != null and board.has_unit(parent_combatant) and not values.has("origin_cell")) else board.footprint_distance_to_cell(from, unit.footprint, origin)
		steps = max(0, reference_distance - 1)
	steps = max(0, steps - resistance)
	if steps == 0:
		return
	var path: Array[Vector2i] = []
	for index: int in steps:
		path.append(from + direction * (index + 1))
	board.invalidate_undo(unit)
	BoardMoveSequence.start(board, unit, path, self, {"forced": true, "ignore_zoc": ignore_zoc, "processor": processor})

func _apply_collision(processor: ActionInterceptorProcessor, unit: BaseCombatant, blocker: BaseCombatant, remaining: int) -> void:
	var delay: int = max(0, int(processor.get_shadowed_action_values("delay_on_collision", 0)))
	if delay > 0 and unit.is_alive():
		unit.next_action_tick += delay
		Signals.timeline_changed.emit()
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
		ActionHandler.add_ordered_actions(collision_actions)

## Not immovable and footprint area within rules.displace_max_footprint_area.
static func is_displaceable(board: BoardData, unit: BaseCombatant) -> bool:
	if board == null or not is_instance_valid(unit) or unit.is_immovable:
		return false
	return unit.footprint.x * unit.footprint.y <= board.rules.displace_max_footprint_area

func _to_string() -> String:
	return "Displace Unit Action: " + str(get_action_value("mode", MODE_PUSH))
