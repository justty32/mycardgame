## Detached author-data snapshots for one start. No runtime objects or module dependencies.
extends RefCounted
class_name PreparedEncounter

var _event: Dictionary = {}
var _rules: Dictionary = {}
var _encounter: Dictionary = {}

## The optional resolver supports the same single lookup in compatibility callers and probes.
static func prepare(event_data: EventData = null, resolver: Callable = Callable()) -> PreparedEncounter:
	if event_data == null:
		event_data = Global.get_player_event_data()
	var prepared := PreparedEncounter.new()
	if event_data != null:
		prepared._event = event_data.get_serializable_properties().duplicate(true)
	prepared._rules = Global.get_configured_combat_rules().get_serializable_properties().duplicate(true)
	var event_snapshot: EventData = prepared.get_event()
	var resolved: EncounterData = resolver.call(event_snapshot) if resolver.is_valid() else Global.get_event_encounter_data(event_snapshot, prepared.get_rules())
	prepared._encounter = resolved.get_serializable_properties().duplicate(true)
	return prepared

func get_event() -> EventData:
	if _event.is_empty():
		return null
	var data := EventData.new()
	data.set_serializable_properties(_event.duplicate(true))
	return data

func get_rules() -> CombatRulesData:
	var data := CombatRulesData.new()
	data.set_serializable_properties(_rules.duplicate(true))
	return data

func get_encounter() -> EncounterData:
	var data := EncounterData.new()
	data.set_serializable_properties(_encounter.duplicate(true))
	return data

func allows_board_module() -> bool:
	return bool(_rules.get("board_enabled", true))
