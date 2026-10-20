extends RefCounted
## Fields are board-local; the Director orders clock boundaries across the whole battlefield.

func run(c) -> void:
	var hero: BaseCombatant = c.player
	await c.create_field("field_probe_enter", [[3, 4]], hero, {"board_id": "party"})
	await c.create_field("field_probe_enter", [[2, 4]], hero, {"board_id": "enemy"})
	c._check(c.party_board.get_fields(Vector2i(3, 4)).size() == 1 and c.enemy_board.get_fields(Vector2i(3, 4)).is_empty(), "same coordinates do not share field storage")
	var events: Array = []
	var left := func(unit, board_id, cell):
		if unit == hero:
			events.append(["leave", str(board_id), cell])
	var entered := func(unit, board_id, cell):
		if unit == hero:
			events.append(["enter", str(board_id), cell])
	c.signals.unit_left_cell.connect(left)
	c.signals.unit_entered_cell.connect(entered)
	var hp: int = hero.get_combatant_health()
	await c.transfer(hero, "enemy", Vector2i(2, 4))
	c._check(events == [["leave", "party", Vector2i(3, 4)], ["enter", "enemy", Vector2i(2, 4)]], "transfer dispatches source-board leave before destination-board enter")
	c._check(hp - hero.get_combatant_health() == 5, "cross-board transfer executes both endpoint field payloads")
	c.signals.unit_left_cell.disconnect(left)
	c.signals.unit_entered_cell.disconnect(entered)
	await _clear(c)
	var relative := FieldData.new("dual_owner_relative")
	relative.field_faction_filter = FieldData.FACTION_FILTERS.OPPONENT_OF_OWNER
	relative.field_on_enter_actions.assign([{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 3, "bypass_block": true}}])
	Global.register_rod(relative)
	await c.create_field(relative.object_id, [[1, 4]], hero, {"board_id": "party"})
	c._check(c.party_board.get_fields(Vector2i(1, 4))[0].owner_uid == hero.unit_uid, "field keeps owner UID across board movement")
	var enemy_hp: int = c.enemy.get_combatant_health()
	await c.run_actions(hero, [c.enemy], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "TO_CELL", "target_board_id": "party", "target_cell": Vector2i(1, 4)}}])
	c._check(c.enemy.board_id == "party" and enemy_hp - c.enemy.get_combatant_health() == 3, "relative owner faction remains valid while owner occupies other board")
	await _clear(c)
	c._check(c.battlefield.transfer(c.enemy, BoardPosition.new("enemy", Vector2i(3, 4))), "restore enemy after relative field test")
	await c.transfer(hero, "party", Vector2i(3, 4))
	await _cross_board_opportunities(c)
	await _clock_order(c)
	await _reaction_relocation(c)
	await _clear(c)

func _cross_board_opportunities(c) -> void:
	var rules: CombatRulesData = c.director.rules
	var old_mode: int = rules.zone_of_control
	var old_forced: bool = rules.zoc_triggers_on_forced_move
	var old_actions: Array[Dictionary] = c.enemy.opportunity_actions.duplicate(true)
	rules.zone_of_control = CombatRulesData.ZOC_MODES.OPPORTUNITY_ATTACK
	c.enemy.opportunity_actions.assign([{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 5, "bypass_block": true}}])
	await c.transfer(c.player, "enemy", Vector2i(2, 4))
	c.enemy_board.reset_action_state(c.player)
	var hp: int = c.player.get_combatant_health()
	var preview: int = c.enemy_board.preview_opportunity_damage(c.player, c.player.board_anchor)
	await c.transfer(c.player, "party", Vector2i(3, 4))
	c._check(preview == 5 and hp - c.player.get_combatant_health() == preview, "ordinary transfer leaving hostile adjacency executes source-board opportunity snapshot")
	await c.transfer(c.player, "enemy", Vector2i(2, 4))
	c.enemy_board.reset_action_state(c.player)
	rules.zoc_triggers_on_forced_move = false
	hp = c.player.get_combatant_health()
	await c.run_actions(c.enemy, [c.player], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "TO_CELL", "target_board_id": "party", "target_cell": [3, 4]}}])
	c._check(c.player.board_id == "party" and c.player.get_combatant_health() == hp, "forced cross-board placement has default ZOC immunity")
	await c.transfer(c.player, "enemy", Vector2i(2, 4))
	c.enemy_board.reset_action_state(c.player)
	rules.zoc_triggers_on_forced_move = true
	await c.run_actions(c.enemy, [c.player], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "TO_CELL", "target_board_id": "party", "target_cell": [3, 4]}}])
	c._check(c.player.board_id == "party" and hp - c.player.get_combatant_health() == 5, "forced cross-board placement opt-in triggers source opportunity once")
	c.enemy.opportunity_actions.assign(old_actions)
	rules.zone_of_control = old_mode
	rules.zoc_triggers_on_forced_move = old_forced

func _clock_order(c) -> void:
	for item: Array in [["dual_tick_party", 100, "party"], ["dual_tick_enemy", 150, "enemy"]]:
		var data := FieldData.new(item[0])
		data.field_tick_interval = item[1]
		data.field_tick_actions.assign([{ get_script().resource_path.get_base_dir().path_join("field_trace_action.gd"): {"label": item[2]} }])
		Global.register_rod(data)
		await c.create_field(data.object_id, [[3, 4]], c.player, {"board_id": item[2]})
	Global.set_meta("field_test_trace", [])
	var tick: int = c.director.current_tick
	await c.director.advance_clock(tick + 250, c.director.get_generation())
	await c._wait(c._idle, "dual field clock payloads drain")
	c._check(Global.get_meta("field_test_trace") == ["party", "enemy", "party"], "one CTB advance interleaves both boards by tick 100/150/200")
	Global.remove_meta("field_test_trace")
	await _clear(c)

func _reaction_relocation(c) -> void:
	var data := FieldData.new("dual_reaction_transfer")
	data.field_triggers_on_pass_through = true
	data.field_on_enter_actions.assign([{Scripts.ACTION_MOVE_UNIT: {"mode": "TELEPORT", "target_override": BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS, "target_board_id": "enemy", "target_cell": [1, 1]}}])
	Global.register_rod(data)
	c._check(c.battlefield.transfer(c.player, BoardPosition.new("party", Vector2i(1, 4))), "setup hero at reaction path start")
	await c.create_field(data.object_id, [[1, 3]], c.player, {"board_id": "party"})
	await c.run_actions(c.player, [], [{Scripts.ACTION_MOVE_UNIT: {"target_cell": [1, 1]}}])
	c._check(c.player.board_id == "enemy" and c.player.board_anchor == Vector2i(1, 1) and not c.party_board.has_unit(c.player), "reaction transfer invalidates old walking continuation without recreating source occupancy")
	await _clear(c)
	await c.transfer(c.player, "party", Vector2i(3, 4))

func _clear(c) -> void:
	for id: String in ["party", "enemy"]:
		await c.run_actions(c.player, [], [{c.REMOVE_FIELD: {"board_id": id}}])
