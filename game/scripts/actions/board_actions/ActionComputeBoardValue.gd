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
	var parent: BaseCombatant = parent_combatant
	var board: BoardData = BoardData.get_for_unit(parent)
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
	if target != null and not board.has_unit(target):
		return # No cross-board numeric distance; card preflight rejects this action before payment.
	card_play_request.card_values.merge(compute_values(board, parent, target), true)

## Pure preview seam for a future AI context; never writes a request, unit, board or RNG.
static func compute_values(board: BoardData, parent: BaseCombatant, target: BaseCombatant, hypothetical_anchor: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE) -> Dictionary:
	var result: Dictionary = {"distance": 0, "adjacent_allies": 0, "adjacent_opponents": 0, "target_adjacent_opponents": 0, "cells_moved_this_action": 0, "cells_displaced_this_action": 0, "is_flanked": 0}
	if board == null or parent == null or not board.has_unit(parent):
		return result
	result["adjacent_allies"] = BoardPositionQueries.count_adjacent(board, parent, "ALLY", hypothetical_anchor)
	result["adjacent_opponents"] = BoardPositionQueries.count_adjacent(board, parent, "OPPONENT", hypothetical_anchor)
	result["cells_moved_this_action"] = parent.cells_moved_this_action
	result["cells_displaced_this_action"] = parent.cells_displaced_this_action
	if target != null and not board.has_unit(target):
		result["distance"] = -1
		result["target_adjacent_opponents"] = BoardPositionQueries.surrounded_count(BoardData.get_for_unit(target), target)
	if target != null and board.has_unit(target):
		result["distance"] = board.unit_distance(parent, target, hypothetical_anchor)
		var adjacent: int = BoardPositionQueries.surrounded_count(board, target)
		if hypothetical_anchor != BaseCombatant.BOARD_ANCHOR_NONE and BoardPositionQueries.opponents(parent, target):
			adjacent -= int(board.unit_distance(parent, target) == 1)
			adjacent += int(board.unit_distance(parent, target, hypothetical_anchor) == 1)
		result["target_adjacent_opponents"] = adjacent
		result["is_flanked"] = int(BoardPositionQueries.is_flanked(board, parent, target, hypothetical_anchor))
	return result

func is_instant_action() -> bool:
	return true

func _to_string() -> String:
	return "Compute Board Value Action"
