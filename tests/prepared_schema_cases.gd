extends RefCounted
## Public serializer roundtrips, including malformed inputs that typed exports would discard.

func run(check: Callable) -> void:
	var absent := EncounterData.new("schema_omitted")
	absent.set_serializable_properties_from_json_patch(JSON.parse_string('{"properties":{},"patch_data":{}}'))
	check.call(absent.encounter_board_setup == {}, "omitted setup remains legacy after public JSON loading")
	for value: Variant in [{}, {"version": 1, "boards": []}, null, 7, [], {"boards": []}, {"version": true, "boards": []}]:
		var source := EncounterData.new("schema_roundtrip")
		var patch: Dictionary = JSON.parse_string(JSON.stringify({"properties": {"encounter_board_setup": value}, "patch_data": {}}))
		source.set_serializable_properties_from_json_patch(patch)
		var restored := EncounterData.new()
		restored.set_serializable_properties_from_json_patch(JSON.parse_string(JSON.stringify(source.get_serializable_properties_to_json_patch())))
		check.call(restored.encounter_board_setup == source.encounter_board_setup, "raw setup survives real serialization roundtrip: %s" % [value])
		var prepared: PreparedEncounter = PreparedEncounter.prepare(EventData.new("schema_event"), func(_event): return restored)
		var valid: bool = value is Dictionary and (value.is_empty() or (value.get("version") is int and value.version == 1 and value.get("boards") is Array))
		check.call(prepared.is_valid() == valid and (not valid or prepared.board_format == ("legacy" if value.is_empty() else "zero")), "roundtrip distinguishes legacy zero and invalid: %s" % [value])
	var mixed := EncounterData.new("schema_mixed")
	mixed.encounter_board_setup = {"version": 1, "boards": []}
	mixed.encounter_board_mode = CombatRulesData.BOARD_MODES.SINGLE
	check.call(PreparedEncounter.prepare(EventData.new(), func(_event): return mixed).error_code == "conflicting_board_formats", "nondefault legacy overrides cannot silently override explicit zero")
	var missing := EventData.new("schema_missing")
	missing.event_encounter_object_id = "missing_encounter_for_schema_probe"
	check.call(PreparedEncounter.prepare(missing).error_code == "missing_encounter", "named missing encounter rejects instead of synthesizing another fight")
	var positive := EncounterData.new("schema_positive")
	positive.encounter_board_setup = fixture(3)
	var prepared: PreparedEncounter = PreparedEncounter.prepare(EventData.new(), func(_event): return positive, false)
	check.call(prepared.error_code == "board_module_unavailable" and prepared.unavailable_reason == "scene_disabled", "explicit positive collection reports scene capability unavailable")
	positive.encounter_board_setup = {"version": 1, "boards": []}
	prepared = PreparedEncounter.prepare(EventData.new(), func(_event): return positive, false)
	check.call(prepared.is_valid() and not prepared.allows_board_module(), "explicit zero needs no board capability")

static func fixture(count: int) -> Dictionary:
	var raw: Dictionary = {"version": 1, "boards": [], "deployment": {"policy": "explicit_positions", "hero": {"board_id": "zone_0", "cell": [2, 4]}, "spawn": {"board_id": "zone_0", "cell": [2, 0]}}, "presentation": {"slots": []}}
	for index: int in count:
		var id: String = "zone_%s" % index
		raw.boards.append({"id": id, "size": [5, 5]})
		raw.presentation.slots.append({"board_id": id, "rect": [index * 100, 100, 90, 90]})
	return raw
