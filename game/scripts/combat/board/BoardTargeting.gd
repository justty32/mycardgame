## Pure board targeting functions (combat framework Phase 2): target shapes, faction filters and
## card target checks. Shared by Hand (player input), HandManager (resolved targets), enemy intents
## and the board validators so every consumer resolves the same cells and units.
extends RefCounted
class_name BoardTargeting

## card_shape / enemy_intent_shape. Numbers are the JSON values (append only).
enum TARGET_SHAPES {SINGLE, ROW, COLUMN, CROSS, SQUARE_3, LINE, LINE_PIERCE, SELF_AREA, ALL, NONE}
## card_target_faction, relative to the acting unit.
enum TARGET_FACTIONS {OPPONENT, ALLY, ANY, SELF, EMPTY_CELL}

## Rejection reasons of check_card_target() ("" = accepted).
const REJECT_OFF_BOARD: String = "off_board"
const REJECT_OUT_OF_RANGE: String = "out_of_range"
const REJECT_NO_TARGET: String = "no_valid_target"
const REJECT_CELL_NOT_FREE: String = "cell_not_free"
const REJECT_VALIDATORS: String = "validators"

## Main-axis unit step from origin toward target (|dx| > |dy| -> x, else y; ties use tie_axis).
static func main_axis_direction(origin: Vector2i, target: Vector2i, tie_axis: int = CombatRulesData.DISPLACE_TIE_AXES.VERTICAL) -> Vector2i:
	var delta: Vector2i = target - origin
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	var use_x: bool = abs(delta.x) > abs(delta.y)
	if abs(delta.x) == abs(delta.y):
		use_x = tie_axis == CombatRulesData.DISPLACE_TIE_AXES.HORIZONTAL
	if use_x:
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))

## Cells covered by a shape. origin = the acting unit's anchor, target = the selected cell.
## LINE stops at (and includes) the first occupied cell; LINE / LINE_PIERCE stop before blocked
## cells and after max_range cells (-1 = board edge).
static func cells_in_shape(board: BoardData, origin: Vector2i, target: Vector2i, shape: int, max_range: int = -1) -> Array[Vector2i]:
	var returned: Array[Vector2i] = []
	match shape:
		TARGET_SHAPES.SINGLE:
			returned.append(target)
		TARGET_SHAPES.ROW:
			for x: int in board.size.x:
				returned.append(Vector2i(x, target.y))
		TARGET_SHAPES.COLUMN:
			for y: int in board.size.y:
				returned.append(Vector2i(target.x, y))
		TARGET_SHAPES.CROSS:
			returned.append(target)
			for offset: Vector2i in BoardData.NEIGHBOURS_FOUR:
				returned.append(target + offset)
		TARGET_SHAPES.SQUARE_3:
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					returned.append(target + Vector2i(dx, dy))
		TARGET_SHAPES.LINE, TARGET_SHAPES.LINE_PIERCE:
			var direction: Vector2i = main_axis_direction(origin, target, board.rules.displace_tie_axis)
			if direction != Vector2i.ZERO:
				var cell: Vector2i = origin + direction
				var steps: int = 1
				while board.is_in_bounds(cell) and not board.is_blocked(cell) and not board.get_cell(cell).blocks_line and (max_range < 0 or steps <= max_range):
					returned.append(cell)
					if shape == TARGET_SHAPES.LINE and board.get_unit_at(cell) != null:
						break
					cell += direction
					steps += 1
		TARGET_SHAPES.SELF_AREA:
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					if dx != 0 or dy != 0:
						returned.append(origin + Vector2i(dx, dy))
		TARGET_SHAPES.ALL:
			returned = board.all_cells()
		TARGET_SHAPES.NONE:
			pass
	var in_bounds: Array[Vector2i] = []
	for cell: Vector2i in returned:
		if board.is_in_bounds(cell) and not in_bounds.has(cell):
			in_bounds.append(cell)
	return in_bounds

## Whether unit passes a TARGET_FACTIONS filter relative to acting_unit.
static func faction_matches(acting_unit: BaseCombatant, unit: BaseCombatant, faction_filter: int) -> bool:
	if unit == null:
		return false
	match faction_filter:
		TARGET_FACTIONS.OPPONENT:
			return acting_unit == null or unit.faction != acting_unit.faction
		TARGET_FACTIONS.ALLY:
			return acting_unit != null and unit.faction == acting_unit.faction and unit != acting_unit
		TARGET_FACTIONS.ANY:
			return true
		TARGET_FACTIONS.SELF:
			return unit == acting_unit
	return false

## Resolve geometry once through the versioned policy, including same-board range.
static func geometry(board: BoardData, acting_unit: BaseCombatant, cell: Vector2i, shape: int, max_range: int = -1, movement: String = "", source_anchor: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE) -> Dictionary:
	if board == null or acting_unit == null:
		return {"valid": false, "error": REJECT_OFF_BOARD, "cells": [], "board_id": "", "cross_board": false}
	var battlefield: CombatBattlefield = _battlefield_for(board)
	var source: BoardPosition = battlefield.get_position(acting_unit)
	if source_anchor != BaseCombatant.BOARD_ANCHOR_NONE:
		source.cell = source_anchor
	return CrossBoardPolicy.resolve(battlefield, source, BoardPosition.new(board.board_id, cell), shape, max_range, acting_unit.footprint, movement)

## Standalone BoardData fixtures keep the same policy path as a running battlefield.
static func _battlefield_for(board: BoardData) -> CombatBattlefield:
	var active: CombatBattlefield = CombatBattlefield.get_active()
	if active != null and active.get_board(board.board_id) == board:
		return active
	var local := CombatBattlefield.new(null, board.rules)
	local.boards.clear()
	local.boards[board.board_id] = board
	return local

static func target_board_for_shape(board: BoardData, acting_unit: BaseCombatant, shape: int) -> BoardData:
	if shape == TARGET_SHAPES.SELF_AREA and acting_unit != null:
		return _battlefield_for(board).get_board_for_unit(acting_unit)
	return board

static func resolve_card_cells(board: BoardData, acting_unit: BaseCombatant, card_data: CardData, cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if check_card_target(board, acting_unit, card_data, cell) != "":
		return result
	result.assign(geometry(board, acting_unit, cell, BoardCardOptions.shape_of(card_data), BoardCardOptions.range_of(card_data)).get("cells", []))
	return result

## Living targets of a shape on the selected board. SELF_AREA remains on the caster's board.
static func resolve_targets(board: BoardData, acting_unit: BaseCombatant, cell: Vector2i, shape: int, faction_filter: int, max_range: int = -1) -> Array[BaseCombatant]:
	var returned: Array[BaseCombatant] = []
	var resolved: Dictionary = geometry(board, acting_unit, cell, shape, max_range)
	if not resolved.valid:
		return returned
	if shape == TARGET_SHAPES.SINGLE and faction_filter == TARGET_FACTIONS.SELF:
		return [acting_unit]
	var effect_board: BoardData = _battlefield_for(board).get_board(resolved.board_id)
	var cells: Array[Vector2i] = []
	cells.assign(resolved.cells)
	for unit: BaseCombatant in effect_board.units_in_cells(cells):
		if faction_matches(acting_unit, unit, faction_filter):
			returned.append(unit)
	return returned

## Returns a rejection before fees or movement. board identifies the selected target board.
static func check_card_target(board: BoardData, acting_unit: BaseCombatant, card_data: CardData, cell: Vector2i, request_values: Dictionary = {}) -> String:
	if board == null:
		return ""
	var resolved: Dictionary = geometry(board, acting_unit, cell, BoardCardOptions.shape_of(card_data), BoardCardOptions.range_of(card_data))
	if not resolved.valid:
		return resolved.error
	var effect_board: BoardData = _battlefield_for(board).get_board(resolved.board_id)
	var effective_cell: Vector2i = acting_unit.board_anchor if BoardCardOptions.shape_of(card_data) == TARGET_SHAPES.SELF_AREA else cell
	var context_values: Dictionary = card_data.card_values.duplicate()
	context_values.merge(request_values, true)
	var action_error: String = check_action_geometry(effect_board, acting_unit, effective_cell, card_data.card_play_actions, context_values)
	if action_error != "":
		return action_error
	if resolved.cross_board and card_data.card_move_distance > 0:
		return "cross_board_walk_unsupported"
	match BoardCardOptions.faction_of(card_data):
		TARGET_FACTIONS.EMPTY_CELL:
			if effect_board.get_unit_at(effective_cell) != null or not effect_board.can_stand(acting_unit, effective_cell):
				return REJECT_CELL_NOT_FREE
		TARGET_FACTIONS.SELF:
			pass
		_:
			var unit: BaseCombatant = effect_board.get_unit_at(effective_cell)
			if unit == null or not unit.is_alive() or not faction_matches(acting_unit, unit, BoardCardOptions.faction_of(card_data)):
				return REJECT_NO_TARGET
	return ""

## Recursive action checks share the geometry gate with intent and card execution.
static func check_action_geometry(board: BoardData, parent: BaseCombatant, cell: Vector2i, data: Variant, context_values: Dictionary = {}) -> String:
	return BoardActionGeometry.check(board, parent, cell, data, context_values)

## Whether a card needs a board cell from the player (target selection) before it is played.
static func card_needs_cell(card_data: CardData) -> bool:
	return card_data.card_requires_target or BoardCardOptions.faction_of(card_data) == TARGET_FACTIONS.EMPTY_CELL

#region Validator context (board validators run with or without an action)
## The unit a validator checks "from": the action's parent, else the acting party unit, else the hero.
static func context_parent(action: BaseAction) -> BaseCombatant:
	if action != null and action.parent_combatant != null and is_instance_valid(action.parent_combatant):
		return action.parent_combatant
	var director: CombatDirector = Global.get_combat_director()
	if director != null and director.acting_unit != null and director.acting_unit.faction == BaseCombatant.FACTIONS.PARTY:
		return director.acting_unit
	return UnitRegistry.get_hero()

## The selected target of the action's card play (first resolved target as fallback); null = unknown
## (e.g. glow / playability checks before a target is chosen).
static func context_target(action: BaseAction) -> BaseCombatant:
	if action == null:
		return null
	if action.card_play_request == null:
		return action.targets[0] if not action.targets.is_empty() and is_instance_valid(action.targets[0]) else null
	var request: CardPlayRequest = action.card_play_request
	if request.selected_target != null and is_instance_valid(request.selected_target):
		return request.selected_target
	if not request.resolved_targets.is_empty():
		return request.resolved_targets[0]
	return null

## A validator "to" unit: "SELECTED_TARGET" (null if unknown), "HERO" or "NEAREST_OPPONENT" of parent.
static func context_unit(board: BoardData, action: BaseAction, parent: BaseCombatant, reference: String) -> BaseCombatant:
	match reference:
		"HERO":
			return UnitRegistry.get_hero()
		"NEAREST_OPPONENT":
			var best: BaseCombatant = null
			if board == null or parent == null:
				return null
			for unit: BaseCombatant in board.get_units():
				if unit.is_alive() and unit.faction != parent.faction and unit.faction != BaseCombatant.FACTIONS.NEUTRAL:
					if best == null or board.unit_distance(parent, unit) < board.unit_distance(parent, best):
						best = unit
			return best
		"PARENT":
			return parent
	return context_target(action)

## The explicitly selected board, otherwise the parent's actual board.
static func context_board(action: BaseAction, parent: BaseCombatant) -> BoardData:
	var battlefield: CombatBattlefield = CombatBattlefield.get_active()
	if action != null and action.card_play_request != null and action.card_play_request.selected_board_id != "" and battlefield != null:
		return battlefield.get_board(action.card_play_request.selected_board_id)
	return BoardData.get_for_unit(parent)

## A validator cell value: "SELECTED_CELL" (BOARD_ANCHOR_NONE if unknown) or [x, y].
static func context_cell(action: BaseAction, value: Variant) -> Vector2i:
	if value is String and value == "SELECTED_CELL":
		if action != null and action.card_play_request != null:
			return action.card_play_request.selected_cell
		return BaseCombatant.BOARD_ANCHOR_NONE
	return EncounterData.cell_from_json(value)
#endregion
