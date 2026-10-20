## Optional board-module target overrides. Core actions delegate without owning spatial queries.
extends RefCounted
class_name BoardActionTargets

static func resolve(action: BaseAction, override: int, force_dead_targets: bool) -> Array[BaseCombatant]:
	var result: Array[BaseCombatant] = []
	if override == BaseAction.TARGET_OVERRIDES.UNITS_IN_RANGE:
		var parent: BaseCombatant = action.parent_combatant
		var board: BoardData = BoardData.get_for_unit(parent)
		var unit_range: int = int(action.get_action_value("range", 1))
		if board != null and is_instance_valid(parent) and board.has_unit(parent):
			for unit: BaseCombatant in board.get_units():
				if unit != parent and unit.is_alive() and board.unit_distance(parent, unit) <= unit_range:
					result.append(unit)
	elif override == BaseAction.TARGET_OVERRIDES.UNITS_ON_FIELD:
		var board: BoardData = FieldActionCells.resolve_board(action, action.get_action_value("board_id", null))
		if board != null:
			var field_id: String = str(action.get_action_value("field_id", ""))
			var tag: String = str(action.get_action_value("tag", ""))
			for cell: Vector2i in board.fields:
				for instance: FieldInstance in board.get_fields(cell, tag):
					if field_id != "" and instance.field_data.object_id != field_id:
						continue
					var unit: BaseCombatant = board.get_unit_at(cell)
					if is_instance_valid(unit) and (unit.is_alive() or force_dead_targets) and not result.has(unit):
						result.append(unit)
	return result
