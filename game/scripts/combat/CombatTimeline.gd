## Action timeline of one combat (CTB clock): the units waiting for their next action, ordered by
## next_action_tick with CombatRulesData.tie_break, plus a read-only projection of upcoming actions
## for the UI. Created per combat by CombatDirector; a RefCounted, never saved.
## wait = action_delay * timeline_delay_scale / speed, so equal speeds reproduce fixed alternation.
extends RefCounted
class_name CombatTimeline

var rules: CombatRulesData = null
## Clock value of the action currently being performed (mirrors CombatDirector.current_tick).
var current_tick: int = 0
## Units waiting for their next action (the acting unit is popped while it acts).
var _units: Array[BaseCombatant] = []
## unit_uid -> first insertion index; final tie-break and the SPAWN_ORDER rule.
var _spawn_order: Dictionary[String, int] = {}
var _next_spawn_index: int = 0

func _init(_rules: CombatRulesData) -> void:
	rules = _rules

## Adds a waiting unit. Re-pushing a queued unit is a no-op.
func push(unit: BaseCombatant) -> void:
	if unit == null or _units.has(unit):
		return
	if not _spawn_order.has(unit.unit_uid):
		_spawn_order[unit.unit_uid] = _next_spawn_index
		_next_spawn_index += 1
	_units.append(unit)

func remove(unit: BaseCombatant) -> void:
	_units.erase(unit)

func has(unit: BaseCombatant) -> bool:
	return _units.has(unit)

func clear() -> void:
	_units.clear()
	_spawn_order.clear()
	_next_spawn_index = 0

func is_empty() -> bool:
	_prune()
	return _units.is_empty()

## Waiting units (unordered copy; freed or dead units already dropped).
func get_units() -> Array[BaseCombatant]:
	_prune()
	return _units.duplicate()

## Removes and returns the unit that acts next, or null when nothing waits.
func pop_next() -> BaseCombatant:
	_prune()
	if _units.is_empty():
		return null
	var best: BaseCombatant = _units[0]
	for unit: BaseCombatant in _units:
		if unit != best and _is_before(unit, unit.next_action_tick, best, best.next_action_tick):
			best = unit
	_units.erase(best)
	return best

## Ticks a unit of the given speed waits after an action of the given delay. Never below 1.
func wait_for(action_delay: int, speed: int) -> int:
	var scale: int = max(1, rules.timeline_delay_scale)
	@warning_ignore("integer_division")
	var wait: int = (max(0, action_delay) * scale) / max(1, speed)
	return max(1, wait)

## Projects the next `count` actions as [{"unit": BaseCombatant, "tick": int}] without mutating
## the queue, assuming every unit then waits for rules.default_action_delay.
## `acting_unit` (the unit currently acting, not queued) is listed first at the current tick when given.
func project(count: int, acting_unit: BaseCombatant = null) -> Array[Dictionary]:
	_prune()
	var ticks: Dictionary[BaseCombatant, int] = {}
	var entries: Array[Dictionary] = []
	for unit: BaseCombatant in _units:
		ticks[unit] = unit.next_action_tick
	if acting_unit != null and is_instance_valid(acting_unit) and not _units.has(acting_unit):
		entries.append({"unit": acting_unit, "tick": current_tick})
		if acting_unit.is_alive():
			ticks[acting_unit] = current_tick + wait_for(rules.default_action_delay, acting_unit.speed)
	while entries.size() < count and not ticks.is_empty():
		var best: BaseCombatant = null
		for unit: BaseCombatant in ticks.keys():
			if best == null or _is_before(unit, ticks[unit], best, ticks[best]):
				best = unit
		entries.append({"unit": best, "tick": ticks[best]})
		ticks[best] = ticks[best] + wait_for(rules.default_action_delay, best.speed)
	return entries

## Drops freed and dead units; a unit that dies while waiting never acts again.
func _prune() -> void:
	var kept: Array[BaseCombatant] = []
	for unit: BaseCombatant in _units:
		if is_instance_valid(unit) and unit.is_inside_tree() and unit.is_alive():
			kept.append(unit)
	_units = kept

## Ordering: smaller tick first; ties by rules.tie_break, then party before enemy, then spawn order.
func _is_before(a: BaseCombatant, tick_a: int, b: BaseCombatant, tick_b: int) -> bool:
	if tick_a != tick_b:
		return tick_a < tick_b
	var a_party: bool = a.faction == BaseCombatant.FACTIONS.PARTY
	var b_party: bool = b.faction == BaseCombatant.FACTIONS.PARTY
	match rules.tie_break:
		CombatRulesData.TIE_BREAKS.PARTY_FIRST:
			if a_party != b_party:
				return a_party
			if a.speed != b.speed:
				return a.speed > b.speed
		CombatRulesData.TIE_BREAKS.SPAWN_ORDER:
			pass
		_: # HIGHER_SPEED_FIRST
			if a.speed != b.speed:
				return a.speed > b.speed
			if a_party != b_party:
				return a_party
	return _spawn_index(a) < _spawn_index(b)

func _spawn_index(unit: BaseCombatant) -> int:
	return _spawn_order.get(unit.unit_uid, _next_spawn_index)
