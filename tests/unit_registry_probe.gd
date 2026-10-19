extends RefCounted
## Combat framework Phase 0 probe, called from framework_smoke.gd after the main scene is ready.
## Checks UnitRegistry hero registration, CombatRulesData defaults (= original behavior),
## schema registration and the declared unit/timeline signals. No run is started; the
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

	# declared signals
	for signal_name: String in ["unit_action_started", "unit_action_ended", "combat_tick_advanced", "timeline_changed", "unit_moved", "unit_spawned", "unit_downed", "unit_removed", "wave_started", "wave_cleared", "end_action_requested", "cell_clicked", "cell_hovered", "party_member_recruited", "party_member_left", "party_member_advanced", "ai_plan_decided"]:
		results["Signals declares " + signal_name] = signals.has_signal(signal_name)
	return results
