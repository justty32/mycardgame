## Per-timeline-action ZOC deduplication and conservative movement undo snapshots.
extends RefCounted
class_name BoardMovementState

var used_opportunities: Dictionary = {}
var undo_snapshots: Dictionary = {}
var undo_blocked: Dictionary = {}

func reset() -> void:
	used_opportunities.clear()
	undo_snapshots.clear()
	undo_blocked.clear()

func invalidate(unit: BaseCombatant) -> void:
	if unit != null:
		undo_blocked[unit.unit_uid] = true
		undo_snapshots.erase(unit.unit_uid)

func capture(unit: BaseCombatant) -> void:
	if undo_blocked.has(unit.unit_uid) or undo_snapshots.has(unit.unit_uid):
		return
	undo_snapshots[unit.unit_uid] = {"board_id": unit.board_id, "anchor": unit.board_anchor, "points": unit.move_points, "paid": unit.paid_cells_this_action, "delay": unit.action_extra_delay, "moved": unit.cells_moved_this_action}

func can_undo(board: BoardData, unit: BaseCombatant) -> bool:
	return unit != null and board.has_unit(unit) and unit.is_alive() and board.rules.move_undo_allowed and undo_snapshots.has(unit.unit_uid) and not undo_blocked.has(unit.unit_uid) and unit.board_id == undo_snapshots[unit.unit_uid].board_id and unit.board_anchor != undo_snapshots[unit.unit_uid].anchor and board.can_stand(unit, undo_snapshots[unit.unit_uid].anchor)

func undo(board: BoardData, unit: BaseCombatant) -> bool:
	if not can_undo(board, unit):
		return false
	var snapshot: Dictionary = undo_snapshots[unit.unit_uid]
	var from: Vector2i = unit.board_anchor
	if not board.move(unit, snapshot.anchor):
		return false
	unit.move_points = snapshot.points
	unit.paid_cells_this_action = snapshot.paid
	unit.action_extra_delay = snapshot.delay
	unit.cells_moved_this_action = snapshot.moved
	undo_snapshots.erase(unit.unit_uid)
	Signals.unit_board_moved.emit(unit, board.board_id, from, board.board_id, snapshot.anchor)
	if board.has_unit(unit) and unit.board_anchor == snapshot.anchor:
		Signals.unit_moved.emit(unit, from, snapshot.anchor)
		Signals.timeline_changed.emit()
	return true

func zoc_controllers(board: BoardData, unit: BaseCombatant, from: Vector2i, ignore_zoc: bool, forced: bool) -> Array[BaseCombatant]:
	var result: Array[BaseCombatant] = []
	if unit == null or unit.ignores_zoc or ignore_zoc or board.rules.zone_of_control == CombatRulesData.ZOC_MODES.NONE:
		return result
	if forced and not board.rules.zoc_triggers_on_forced_move:
		return result
	for other: BaseCombatant in board.get_units():
		if other == unit or not other.is_alive() or other.faction == unit.faction or other.faction == BaseCombatant.FACTIONS.NEUTRAL:
			continue
		if board.unit_distance(unit, other, from) == 1:
			result.append(other)
	return result

func opportunity_actions(board: BoardData, unit: BaseCombatant, from: Vector2i, ignore_zoc: bool, forced: bool, source: BaseAction) -> Array[BaseAction]:
	var result: Array[BaseAction] = []
	if board.rules.zone_of_control != CombatRulesData.ZOC_MODES.OPPORTUNITY_ATTACK:
		return result
	return opportunity_actions_from_controllers(board, unit, zoc_controllers(board, unit, from, ignore_zoc, forced), source)

func opportunity_actions_from_controllers(board: BoardData, unit: BaseCombatant, controllers: Array[BaseCombatant], source: BaseAction) -> Array[BaseAction]:
	var result: Array[BaseAction] = []
	if board.rules.zone_of_control != CombatRulesData.ZOC_MODES.OPPORTUNITY_ATTACK:
		return result
	var generation: int = ActionHandler._action_generation
	for other: BaseCombatant in controllers:
		if not is_instance_valid(other) or not other.is_alive() or not board.has_unit(other):
			continue
		var key: String = other.unit_uid + ":" + unit.unit_uid
		if used_opportunities.has(key) or other.opportunity_actions.is_empty():
			continue
		used_opportunities[key] = true
		invalidate(unit)
		Signals.unit_left_zoc.emit(unit, other)
		if generation != ActionHandler._action_generation or not is_instance_valid(unit) or not unit.is_alive():
			return []
		if not is_instance_valid(other) or not other.is_alive() or not board.has_unit(other):
			continue
		for child: BaseAction in ActionGenerator.create_actions(other, null, [unit], other.opportunity_actions, source):
			# A field can cause the move, but the opportunity attack belongs to its controller.
			child.owner_bound = true
			child.owner_uid = other.unit_uid
			result.append(child)
	return result

func preview_damage(board: BoardData, unit: BaseCombatant, from: Vector2i, ignore_zoc: bool, forced: bool) -> int:
	if board.rules.zone_of_control != CombatRulesData.ZOC_MODES.OPPORTUNITY_ATTACK:
		return 0
	var state: Dictionary = {"block": float(unit.get_block()), "total": 0.0}
	for other: BaseCombatant in zoc_controllers(board, unit, from, ignore_zoc, forced):
		if used_opportunities.has(other.unit_uid + ":" + unit.unit_uid):
			continue
		FieldPreview.preview_actions_into(other.opportunity_actions, other, unit, state, true, false)
	return int(state.total)
