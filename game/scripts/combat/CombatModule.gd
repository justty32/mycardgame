## Optional combat component composed by the combat scene (Combat.gd) and attached to the CTB
## core (CombatDirector). The core only calls these hooks and never names a module class, so a
## module's files can be removed without breaking ordinary combat. Every hook defaults to the
## behavior of an unmounted combat (no positions, no extra content rules).
## Fees, queues, draw and card resolution stay in Hand / HandManager; a module only supplies data
## (CardPlayAdapter hooks), positions and its own actions.
extends Node
class_name CombatModule

## Stable id used by content requirements (CombatContentRequirements) and compatibility getters.
func get_module_id() -> StringName:
	return &""

#region Lifetime
## Builds the module's per-combat resources. false aborts the combat start.
func setup(_director: CombatDirector, _encounter: EncounterData) -> bool:
	return true

## Releases per-combat resources; must be idempotent and re-entrant.
func clear(_preserve_presentation: bool = false) -> void:
	pass
#endregion

#region Timeline hooks
## Admission of a mid-combat summon; false keeps it out of the timeline.
func prepare_spawned_unit(_unit: BaseCombatant) -> bool:
	return true

func on_unit_spawned(_unit: BaseCombatant) -> void:
	pass

func on_unit_removed(_unit: BaseCombatant) -> void:
	pass

## Before the action's begin phase (movement allowances etc.).
func on_action_reset(_unit: BaseCombatant) -> void:
	pass

## After unit_action_started.
func on_action_started(_unit: BaseCombatant) -> void:
	pass

## The CTB clock advanced from previous_tick to current_tick.
func on_clock_advanced(_previous_tick: int, _current_tick: int) -> void:
	pass

func on_card_played(_unit: BaseCombatant) -> void:
	pass

## Recompute derived previews (threats); the director refreshes the hero display afterwards.
func refresh_threats() -> void:
	pass
#endregion

#region Content
## The scene-level card policy while this module is mounted; null keeps the core adapter.
func get_card_play_adapter() -> CardPlayAdapter:
	return null

## true = this module executes enemy intents (perform_enemy_intent) instead of the core.
func handles_enemy_intents() -> bool:
	return false

func perform_enemy_intent(_enemy: Enemy) -> void:
	pass

## Module-specific BaseAction.TARGET_OVERRIDES (e.g. UNITS_IN_RANGE).
func resolve_action_targets(_action: BaseAction, _override: int, _force_dead: bool) -> Array[BaseCombatant]:
	return []

## Damage the hero will take before its next action; -1 = not provided (core sums intents).
func incoming_damage_for(_hero: BaseCombatant, _recalculate: bool) -> int:
	return -1
#endregion

#region Positions (spatial modules)
## true = spawned / summoned units are placed by this module (zone id + cell anchor).
func places_units() -> bool:
	return false

## {"board_id": String, "cell": Vector2i} for an encounter wave unit entry.
func resolve_spawn_location(_unit_entry: Dictionary) -> Dictionary:
	return {"board_id": "", "cell": BaseCombatant.BOARD_ANCHOR_NONE}

func has_zone(_zone_id: String) -> bool:
	return false

func anchor_fits(_zone_id: String, _footprint: Vector2i, _cell: Vector2i) -> bool:
	return false

func nearest_free_anchor(_zone_id: String, _footprint: Vector2i, _cell: Vector2i) -> Vector2i:
	return BaseCombatant.BOARD_ANCHOR_NONE

func place_unit_at(_unit: BaseCombatant, _zone_id: String, _anchor: Vector2i) -> bool:
	return false

## Places at cell or the nearest free anchor of the zone (summons).
func place_unit_nearest(_unit: BaseCombatant, _cell: Vector2i, _zone_id: String = "") -> bool:
	return false
#endregion
