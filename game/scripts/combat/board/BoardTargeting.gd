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
				while board.is_in_bounds(cell) and not board.is_blocked(cell) and (max_range < 0 or steps <= max_range):
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

## Living units of the shape around cell that pass the faction filter.
static func resolve_targets(board: BoardData, acting_unit: BaseCombatant, cell: Vector2i, shape: int, faction_filter: int, max_range: int = -1) -> Array[BaseCombatant]:
	var returned: Array[BaseCombatant] = []
	if board == null:
		return returned
	var origin: Vector2i = acting_unit.board_anchor if acting_unit != null else cell
	if shape == TARGET_SHAPES.SINGLE and faction_filter == TARGET_FACTIONS.SELF and acting_unit != null:
		return [acting_unit]
	for unit: BaseCombatant in board.units_in_cells(cells_in_shape(board, origin, cell, shape, max_range)):
		if faction_matches(acting_unit, unit, faction_filter):
			returned.append(unit)
	return returned

## Whether a card may be played by acting_unit at cell. Returns "" or a REJECT_* reason.
## Range: card_range >= 0 limits the distance from the unit's nearest cell to the selected cell.
## OPPONENT / ALLY / ANY need a matching unit on the cell; EMPTY_CELL needs a cell the unit can stand on.
static func check_card_target(board: BoardData, acting_unit: BaseCombatant, card_data: CardData, cell: Vector2i) -> String:
	if board == null:
		return ""
	if not board.is_in_bounds(cell):
		return REJECT_OFF_BOARD
	if card_data.card_range >= 0 and acting_unit != null and board.unit_distance_to_cell(acting_unit, cell) > card_data.card_range:
		return REJECT_OUT_OF_RANGE
	match card_data.card_target_faction:
		TARGET_FACTIONS.EMPTY_CELL:
			if board.get_unit_at(cell) != null or board.is_blocked(cell) or (acting_unit != null and not board.can_stand(acting_unit, cell)):
				return REJECT_CELL_NOT_FREE
		TARGET_FACTIONS.SELF:
			pass
		_:
			var unit: BaseCombatant = board.get_unit_at(cell)
			if unit == null or not unit.is_alive() or not faction_matches(acting_unit, unit, card_data.card_target_faction):
				return REJECT_NO_TARGET
	return ""

## Whether a card needs a board cell from the player (target selection) before it is played.
static func card_needs_cell(card_data: CardData) -> bool:
	return card_data.card_requires_target or card_data.card_target_faction == TARGET_FACTIONS.EMPTY_CELL

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
	if action == null or action.card_play_request == null:
		return null
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

## A validator cell value: "SELECTED_CELL" (BOARD_ANCHOR_NONE if unknown) or [x, y].
static func context_cell(action: BaseAction, value: Variant) -> Vector2i:
	if value is String and value == "SELECTED_CELL":
		if action != null and action.card_play_request != null:
			return action.card_play_request.selected_cell
		return BaseCombatant.BOARD_ANCHOR_NONE
	return EncounterData.cell_from_json(value)
#endregion
