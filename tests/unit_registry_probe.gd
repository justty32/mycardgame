extends RefCounted
## Combat framework Phase 0 probe, called from framework_smoke.gd after the main scene is ready.
## Checks UnitRegistry hero registration, CombatRulesData defaults (= original behavior),
## schema registration and the declared unit/timeline signals; Phase 2 adds the legacy encounter
## synthesis and pure board queries. No run is started; the
## "unit_action_started once per hero turn" contract is asserted by combat_flow.gd.

## Returns {label: bool}. tree_root is SceneTree.root; game_root is the instantiated main scene.
func check(tree_root: Window, game_root: Node) -> Dictionary:
	var results: Dictionary = {}
	var global_data: Node = tree_root.get_node("Global")
	var registry: Node = tree_root.get_node_or_null("UnitRegistry")
	var signals: Node = tree_root.get_node("Signals")
	results["UnitRegistry autoload is present"] = registry != null
	if registry == null:
		return results

	# hero registration
	var player: Node = game_root.get_node_or_null("RunScreen/Combat/Player")
	var hero: Node = registry.get_hero()
	results["run screen Player registers as the UnitRegistry hero"] = player != null and hero == player
	results["Global.get_player() delegates to the registry hero"] = hero != null and global_data.get_player() == hero
	if hero != null:
		results["hero has a non-empty unit_uid"] = hero.unit_uid != ""
		results["hero resolves by unit_uid"] = registry.get_unit(hero.unit_uid) == hero
		results["hero faction is PARTY"] = hero.faction == BaseCombatant.FACTIONS.PARTY
		results["hero defaults: speed 10, footprint 1x1, unplaced, no controller"] = hero.speed == BaseCombatant.DEFAULT_SPEED and hero.footprint == Vector2i(1, 1) and hero.board_anchor == BaseCombatant.BOARD_ANCHOR_NONE and hero.controller == null
		var party_units: Array = registry.get_units_by_faction(BaseCombatant.FACTIONS.PARTY)
		results["PARTY faction query returns only the hero"] = party_units.size() == 1 and party_units[0] == hero
	results["no enemy units outside combat"] = registry.get_units_by_faction(BaseCombatant.FACTIONS.ENEMY).is_empty() and global_data.get_alive_enemies().is_empty()

	# combat rules
	results["CombatRulesData is in Global.CLASS_NAME_TO_CLASS"] = global_data.CLASS_NAME_TO_CLASS.get("CombatRulesData") == CombatRulesData
	results["CombatRulesData is in the SerializableData script cache"] = SerializableData._serializable_data_script_cache.has("CombatRulesData")
	var registered: Resource = global_data.get_combat_rules_data(CombatRulesData.DEFAULT_OBJECT_ID)
	if global_data.get_content_profile() == global_data.CONTENT_PROFILE_TEST:
		results["test profile registers combat_rules_default"] = registered != null
	var rules: CombatRulesData = global_data.get_combat_rules()
	results["Global.get_combat_rules() resolves combat_rules_default"] = rules != null and rules.object_id == CombatRulesData.DEFAULT_OBJECT_ID and (registered == null or rules == registered)
	if rules != null:
		results["default rules keep original pacing: refill energy, draw 5, hand 10"] = rules.energy_per_action == CombatRulesData.ENERGY_REFILL and rules.energy_cap == CombatRulesData.ENERGY_REFILL and rules.draw_per_action == 5 and rules.hand_limit == 10
		results["default rules keep original turn end/start: discard hand, reset block"] = rules.discard_hand_on_action_end and rules.reset_block_on_action_start
		results["default rules keep a single-character party"] = rules.party_size_max == 1 and rules.deploy_size_max == 1 and rules.hero_down_ends_run
		results["refill rule gains full max energy"] = rules.get_start_of_action_energy_gain(1, 3) == 3
	var paced: CombatRulesData = CombatRulesData.new("probe_rules")
	paced.energy_per_action = 2
	paced.energy_cap = 4
	results["per-action energy gain respects the cap"] = paced.get_start_of_action_energy_gain(3, 3) == 1 and paced.get_start_of_action_energy_gain(0, 3) == 2

	# JSON round trip, including Vector2i fields
	var patched: CombatRulesData = CombatRulesData.new("probe_rules")
	patched.set_serializable_properties_from_json_patch({
		"properties": {"draw_per_action": 3, "default_board_size": [7, 6]},
		"patch_data": {}
	})
	results["CombatRulesData JSON patch sets int and Vector2i fields"] = patched.draw_per_action == 3 and patched.default_board_size == Vector2i(7, 6)
	var exported: Dictionary = patched.get_serializable_properties(true)
	results["CombatRulesData exports Vector2i as a JSON array"] = exported.get("default_board_size") == [7, 6]
	var limits: CombatRulesData = CombatRulesData.new("probe_rules")
	limits.set_serializable_properties_from_json_patch({"properties": {"board_min_size": [4, 3], "board_max_size": [10, 8]}, "patch_data": {}})
	results["CombatRulesData JSON patch sets board_min_size / board_max_size"] = limits.board_min_size == Vector2i(4, 3) and limits.board_max_size == Vector2i(10, 8) and limits.validate_configuration() == ""
	# Author feedback: every loaded encounter must fit the active rules (sizes, cells, wave boards).
	if rules != null and rules.board_enabled:
		var invalid: Array[String] = []
		for encounter: EncounterData in global_data._id_to_encounter_data.values():
			var checked: Dictionary = encounter.validate_configuration_detail(rules)
			if checked.code != "":
				invalid.append(checked.detail)
		results["loaded EncounterData fit the active board rules" + ("" if invalid.is_empty() else ": " + "; ".join(invalid))] = invalid.is_empty() and rules.validate_configuration() == ""

	# board (Phase 2): legacy events synthesize a default encounter; pure board queries
	results["EncounterData is in Global.CLASS_NAME_TO_CLASS"] = global_data.CLASS_NAME_TO_CLASS.get("EncounterData") == EncounterData
	if rules != null:
		results["default rules keep movement off: no free / paid moves, split allowed, single-cell displacement"] = rules.free_move_per_action == 0 and rules.paid_move_max_cells == 0 and rules.extra_move_delay_per_cell == 0 and rules.move_split_allowed and rules.displace_max_footprint_area == 1
		var legacy_event := EventData.new("probe_legacy_event")
		legacy_event.event_weighted_enemy_object_ids.assign([{"probe_enemy_a": 1}, {"probe_enemy_b": 1}, {"probe_enemy_c": 1}])
		var synthesized: EncounterData = global_data.get_event_encounter_data(legacy_event)
		var wave_cells: Array = []
		if synthesized != null and synthesized.encounter_waves.size() == 1:
			for unit_entry: Dictionary in synthesized.encounter_waves[0].wave_units:
				wave_cells.append(unit_entry.get("cell", []))
		results["legacy event (no encounter id) synthesizes one wave on the north row, centered"] = synthesized != null and synthesized.get_board_size(rules) == rules.default_board_size and wave_cells == [[1, 0], [2, 0], [3, 0]]
		var board := BoardData.new(Vector2i(5, 5), rules)
		results["board shapes: CROSS 5 cells, ROW 5 cells, LINE to the edge 4 cells"] = BoardTargeting.cells_in_shape(board, Vector2i(2, 4), Vector2i(2, 2), BoardTargeting.TARGET_SHAPES.CROSS).size() == 5 and BoardTargeting.cells_in_shape(board, Vector2i(2, 4), Vector2i(0, 1), BoardTargeting.TARGET_SHAPES.ROW).size() == 5 and BoardTargeting.cells_in_shape(board, Vector2i(2, 4), Vector2i(2, 0), BoardTargeting.TARGET_SHAPES.LINE).size() == 4
		results["board distance is Manhattan by default"] = board.distance(Vector2i(0, 0), Vector2i(2, 3)) == 5
	var encounter_patch := EncounterData.new("probe_encounter")
	encounter_patch.set_serializable_properties_from_json_patch({"properties": {"encounter_board_size": [7, 5], "encounter_blocked_cells": [[3, 2]]}, "patch_data": {}})
	results["EncounterData JSON patch sets the board size (Vector2i) and cell lists"] = encounter_patch.encounter_board_size == Vector2i(7, 5) and EncounterData.cells_from_json(encounter_patch.encounter_blocked_cells).size() == 1 and EncounterData.cells_from_json(encounter_patch.encounter_blocked_cells)[0] == Vector2i(3, 2)

	# declared signals
	for signal_name: String in ["unit_action_started", "unit_action_ended", "combat_tick_advanced", "timeline_changed", "unit_moved", "unit_spawned", "unit_downed", "unit_removed", "wave_started", "wave_cleared", "end_action_requested", "cell_clicked", "cell_hovered", "party_member_recruited", "party_member_left", "party_member_advanced", "ai_plan_decided"]:
		results["Signals declares " + signal_name] = signals.has_signal(signal_name)
	return results
