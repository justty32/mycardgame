## Autoload registry of the combatant units currently in the scene tree.
## Maps unit_uid -> BaseCombatant, answers faction queries and tracks the hero
## (the party unit that represents the run's main character). BaseCombatant registers itself
## on _ready and unregisters on tree_exiting, so the registry mirrors scene-tree membership.
## Faction queries return units in scene-tree order, matching SceneTree.get_nodes_in_group().
extends Node

## Values are untyped so a freed unit can be skipped with is_instance_valid() instead of erroring.
var _uid_to_unit: Dictionary[String, Variant] = {}
var _hero_uid: String = ""
var _next_uid_index: int = 0

## Registers a unit, assigning a unit_uid if it has none. Re-registering is a no-op.
func register_unit(unit: BaseCombatant) -> void:
	if unit == null:
		return
	if unit.unit_uid == "":
		unit.unit_uid = _generate_uid()
	_uid_to_unit[unit.unit_uid] = unit
	if unit.is_hero() and get_hero() == null:
		_hero_uid = unit.unit_uid

func unregister_unit(unit: BaseCombatant) -> void:
	if unit == null or unit.unit_uid == "":
		return
	if _uid_to_unit.get(unit.unit_uid, null) == unit:
		_uid_to_unit.erase(unit.unit_uid)
	if _hero_uid == unit.unit_uid:
		_hero_uid = ""
		# promote another registered hero-capable unit, if any
		for other: BaseCombatant in get_all_units():
			if other.is_hero():
				_hero_uid = other.unit_uid
				break

func get_unit(unit_uid: String) -> BaseCombatant:
	var value: Variant = _uid_to_unit.get(unit_uid, null)
	if value != null and is_instance_valid(value):
		return value
	return null

## The hero unit (Global.get_player() delegates here). Null outside a loaded run screen.
func get_hero() -> BaseCombatant:
	if _hero_uid == "":
		return null
	return get_unit(_hero_uid)

## All registered units in scene-tree order.
func get_all_units() -> Array[BaseCombatant]:
	var units: Array[BaseCombatant] = []
	for value: Variant in _uid_to_unit.values():
		if is_instance_valid(value) and (value as BaseCombatant).is_inside_tree():
			units.append(value)
	units.sort_custom(_is_before_in_tree)
	return units

## Registered units of a faction (BaseCombatant.FACTIONS) in scene-tree order.
func get_units_by_faction(faction: int, alive_only: bool = false) -> Array[BaseCombatant]:
	var units: Array[BaseCombatant] = []
	for unit: BaseCombatant in get_all_units():
		if unit.faction != faction:
			continue
		if alive_only and not unit.is_alive():
			continue
		units.append(unit)
	return units

func _generate_uid() -> String:
	_next_uid_index += 1
	return "unit_%d" % _next_uid_index

func _is_before_in_tree(a: BaseCombatant, b: BaseCombatant) -> bool:
	return b.is_greater_than(a)
