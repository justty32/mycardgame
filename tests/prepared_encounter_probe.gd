extends RefCounted
## Pure preparation and scene composition; no run or gameplay signal is started.

func run(check: Callable, combat: Node) -> void:
	check.call(combat.combat_module == null and combat.prepared_encounter == null, "ready leaves unknown encounter unmounted")
	combat._compose_board_module()
	check.call(combat.combat_module == null, "legacy compose cannot guess an encounter before preparation")
	var source := EncounterData.new("prepared_probe")
	var wave := EncounterWaveData.new()
	wave.wave_units.assign([{"weights": {"enemy_1": 1}, "cell": [1, 2]}])
	source.encounter_waves.append(wave)
	source.encounter_boards = {"party": {"size": Vector2i(7, 5)}}
	wave.wave_on_start_actions.assign([{"probe": {"value": 1}}])
	var event := EventData.new("prepared_event")
	event.event_initial_combat_actions.assign([{"probe": {"value": 1}}])
	var calls: Array[int] = [0]
	var prepared: PreparedEncounter = PreparedEncounter.prepare(event, func(input: EventData) -> EncounterData:
		calls[0] += 1
		check.call(input != event and input.object_id == event.object_id, "resolver receives detached event snapshot")
		return source)
	check.call(calls[0] == 1, "preparation resolves encounter exactly once")
	source.encounter_waves[0].wave_units[0].weights.enemy_1 = 99
	source.encounter_waves[0].wave_on_start_actions[0].probe.value = 99
	source.encounter_boards.party.size = Vector2i(9, 9)
	event.event_initial_combat_actions[0].probe.value = 99
	var first: EncounterData = prepared.get_encounter()
	check.call(first.encounter_waves[0].wave_units[0].weights.enemy_1 == 1 and prepared.get_event().event_initial_combat_actions[0].probe.value == 1, "prepared nested event and wave data do not alias sources")
	check.call(first.encounter_boards.party.size == Vector2i(7, 5) and first.encounter_waves[0].wave_on_start_actions[0].probe.value == 1, "nested native vectors and wave actions survive detached preparation")
	first.encounter_waves[0].wave_units[0].cell[0] = 99
	first.encounter_waves[0].wave_units[0].weights.enemy_1 = 12
	first.encounter_waves[0].wave_on_start_actions[0].probe.value = 12
	check.call(source.encounter_waves[0].wave_units[0].weights.enemy_1 == 99 and source.encounter_waves[0].wave_on_start_actions[0].probe.value == 99 and prepared.get_encounter().encounter_waves[0].wave_units[0].weights.enemy_1 == 1, "consumer wave Resource weights and actions cannot mutate source or preparation")
	var rules: CombatRulesData = prepared.get_rules()
	rules.board_enabled = not rules.board_enabled
	check.call(prepared.get_encounter().encounter_waves[0].wave_units[0].cell == [1, 2] and prepared.get_rules().board_enabled != rules.board_enabled, "consumer mutation cannot alter prepared encounter or rules")
	check.call(calls[0] == 1, "reading prepared data never resolves encounter again")
	var actual_rules: CombatRulesData = Global.get_combat_rules()
	var old_mode: int = actual_rules.board_mode
	var old_enabled: bool = actual_rules.board_enabled
	for mode: int in [CombatRulesData.BOARD_MODES.SINGLE, CombatRulesData.BOARD_MODES.DUAL]:
		actual_rules.board_mode = mode
		var legacy: PreparedEncounter = PreparedEncounter.prepare(EventData.new("legacy_prepared"))
		check.call(legacy.get_encounter().get_board_mode(legacy.get_rules()) == mode, "omitted legacy mode follows prepared rules: %s" % mode)
		check.call(legacy.get_encounter().encounter_boards.is_empty(), "empty legacy overrides retain inheritance: %s" % mode)
	actual_rules.board_enabled = false
	var disabled: PreparedEncounter = PreparedEncounter.prepare(event)
	actual_rules.board_enabled = true
	check.call(not disabled.allows_board_module() and not disabled.get_rules().board_enabled, "prepared rules retain opt-out after source changes")
	actual_rules.board_enabled = old_enabled
	actual_rules.board_mode = old_mode
