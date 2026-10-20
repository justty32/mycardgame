## Pure footprint-aware position queries; hypothetical anchors never move a live unit.
extends RefCounted
class_name BoardPositionQueries

static func opponents(a: BaseCombatant, b: BaseCombatant) -> bool:
	return a != null and b != null and a.faction != b.faction and a.faction != BaseCombatant.FACTIONS.NEUTRAL and b.faction != BaseCombatant.FACTIONS.NEUTRAL

static func count_adjacent(board: BoardData, around: BaseCombatant, faction: String = "ANY", hypothetical_anchor: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE) -> int:
	if board == null or around == null or not board.has_unit(around):
		return 0
	var count: int = 0
	for unit: BaseCombatant in board.get_units():
		if unit == around or not unit.is_alive() or board.unit_distance(around, unit, hypothetical_anchor) != 1:
			continue
		if faction == "ANY" or (faction == "ALLY" and unit.faction == around.faction) or (faction == "OPPONENT" and opponents(around, unit)):
			count += 1
	return count

static func surrounded_count(board: BoardData, target: BaseCombatant) -> int:
	return count_adjacent(board, target, "OPPONENT")

## PINCER requires the attacker itself and a living ally touching opposite cardinal sides.
## Large footprints are compared by their exposed edges, not only their anchors.
static func is_flanked(board: BoardData, attacker: BaseCombatant, target: BaseCombatant, hypothetical_anchor: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE) -> bool:
	if board == null or attacker == null or target == null or not board.has_unit(attacker) or not board.has_unit(target) or not opponents(attacker, target):
		return false
	var anchor: Vector2i = attacker.board_anchor if hypothetical_anchor == BaseCombatant.BOARD_ANCHOR_NONE else hypothetical_anchor
	var sides: Array[Vector2i] = _contact_sides(anchor, attacker.footprint, target.board_anchor, target.footprint)
	if sides.is_empty():
		return false
	for ally: BaseCombatant in board.get_units():
		if ally == attacker or ally == target or not ally.is_alive() or ally.faction != attacker.faction:
			continue
		var ally_sides: Array[Vector2i] = _contact_sides(ally.board_anchor, ally.footprint, target.board_anchor, target.footprint)
		for side: Vector2i in sides:
			if ally_sides.has(-side):
				return true
	return false

static func _contact_sides(anchor: Vector2i, footprint: Vector2i, target: Vector2i, target_size: Vector2i) -> Array[Vector2i]:
	var returned: Array[Vector2i] = []
	var overlap_x: bool = anchor.x < target.x + target_size.x and target.x < anchor.x + footprint.x
	var overlap_y: bool = anchor.y < target.y + target_size.y and target.y < anchor.y + footprint.y
	if overlap_x and anchor.y + footprint.y == target.y:
		returned.append(Vector2i.UP)
	if overlap_x and target.y + target_size.y == anchor.y:
		returned.append(Vector2i.DOWN)
	if overlap_y and anchor.x + footprint.x == target.x:
		returned.append(Vector2i.LEFT)
	if overlap_y and target.x + target_size.x == anchor.x:
		returned.append(Vector2i.RIGHT)
	return returned

static func is_on_edge(board: BoardData, unit: BaseCombatant) -> bool:
	if board == null or unit == null or not board.has_unit(unit):
		return false
	var anchor: Vector2i = unit.board_anchor
	return anchor.x == 0 or anchor.y == 0 or anchor.x + unit.footprint.x == board.size.x or anchor.y + unit.footprint.y == board.size.y
