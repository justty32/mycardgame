## Writes board quantities into card_play_request.card_values for later actions of the same play
## (combat framework Phase 2; list it so it runs before them). Keys:
##   distance: parent -> first target (selected target, else first resolved / action target)
##   adjacent_allies / adjacent_opponents: units next to the parent
##   target_adjacent_opponents: opponents of the target next to it
##   cells_moved_this_action / cells_displaced_this_action: the parent's counters
## NOTE: "distance" shares its name with the movement actions' distance value; do not combine both
## in one card play.
extends BaseAction

func perform_action() -> void:
	if card_play_request == null:
		return
	var board: BoardData = BoardData.get_active()
	var parent: BaseCombatant = parent_combatant
	if board == null or parent == null or not board.has_unit(parent):
		return
	var target: BaseCombatant = card_play_request.selected_target
	if target == null or not is_instance_valid(target):
		target = card_play_request.resolved_targets[0] if not card_play_request.resolved_targets.is_empty() else null
	if target == null:
		for candidate: BaseCombatant in targets:
			if candidate != null and is_instance_valid(candidate):
				target = candidate
				break
	var values_out: Dictionary = card_play_request.card_values
	if target != null and board.has_unit(target):
		values_out["distance"] = board.unit_distance(parent, target)
		values_out["target_adjacent_opponents"] = _count_adjacent(board, target, true)
	values_out["adjacent_allies"] = _count_adjacent(board, parent, false)
	values_out["adjacent_opponents"] = _count_adjacent(board, parent, true)
	values_out["cells_moved_this_action"] = parent.cells_moved_this_action
	values_out["cells_displaced_this_action"] = parent.cells_displaced_this_action

func _count_adjacent(board: BoardData, around: BaseCombatant, opponents: bool) -> int:
	var count: int = 0
	for unit: BaseCombatant in board.get_units():
		if unit == around or not unit.is_alive() or board.unit_distance(around, unit) != 1:
			continue
		var is_opponent: bool = unit.faction != around.faction and unit.faction != BaseCombatant.FACTIONS.NEUTRAL
		var is_ally: bool = unit.faction == around.faction
		if (opponents and is_opponent) or (not opponents and is_ally):
			count += 1
	return count

func is_instant_action() -> bool:
	return true

func _to_string() -> String:
	return "Compute Board Value Action"
