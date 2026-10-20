extends RefCounted
## Public action/handler regression groups. Board moves in setup deliberately bypass field hooks.

func run(c) -> void:
	await _schema_and_actions(c)
	await _movement_events(c)
	await _owner_lifetime(c)

func _schema_and_actions(c) -> void:
	c._check(c.board.get_fields(Vector2i(0, 0)).size() == 1 and c.board.get_unit_at(Vector2i(0, 0)).get_combatant_health() == 300, "encounter_initial_fields installs before wave without default spawn damage")
	await c.remove_fields()
	var data: FieldData = Global.get_field_data("field_probe_clock")
	c._check(data != null and data.field_duration_ticks == 300 and data.field_tick_interval == 100, "FieldData JSON patch registered duration and tick interval")
	var copy := FieldData.new()
	copy.set_serializable_properties_from_json_patch(data.get_serializable_properties_to_json_patch())
	c._check(copy.field_tick_actions == data.field_tick_actions and copy.field_duration_ticks == 300, "FieldData public JSON serialization round-trips typed action payloads")
	await c.create_field("field_probe_enter", [[2, 2]], c.player, {"duration_override": 300})
	var first: FieldInstance = c.board.get_fields(Vector2i(2, 2))[0]
	c._check(first.expires_tick == c.director.current_tick + 300, "ActionCreateField duration_override uses creation clock")
	await c.create_field("field_probe_enter", [[2, 2]])
	c._check(c.board.get_fields(Vector2i(2, 2)).size() == 1 and c.board.get_fields(Vector2i(2, 2))[0] != first, "REPLACE replaces same-id instance instead of doubling payload")
	var template: FieldData = Global.get_field_data("field_probe_enter")
	template.field_stack_policy = FieldData.STACK_POLICIES.IGNORE
	first = c.board.get_fields(Vector2i(2, 2))[0]
	await c.create_field("field_probe_enter", [[2, 2]])
	c._check(c.board.get_fields(Vector2i(2, 2))[0] == first and first.stacks == 1, "IGNORE preserves original instance and stack count")
	template.field_stack_policy = FieldData.STACK_POLICIES.STACK
	await c.create_field("field_probe_enter", [[2, 2]])
	c._check(first.stacks == 2 and c.board.get_fields(Vector2i(2, 2)).size() == 1, "STACK increments same-id stack count")
	c._arrange([[c.player, Vector2i(2, 3)]])
	var hp: int = c.player.get_combatant_health()
	await c.move_unit(c.player, Vector2i(2, 2))
	c._check(hp - c.player.get_combatant_health() == 6, "STACK executes enter damage once per stack through real handler")
	template.field_stack_policy = FieldData.STACK_POLICIES.REPLACE
	await c.run_actions(c.player, [], [{c.REMOVE_FIELD: {"tag": "probe"}}])
	c._check(c.board.fields.is_empty(), "ActionRemoveField tag removes matching fields across board")
	await c.create_field("field_probe_enter", [[2, 2], [3, 2]])
	await c.run_actions(c.player, [], [{c.REMOVE_FIELD: {"field_id": "field_probe_enter", "cells": [[2, 2]]}}])
	c._check(c.board.get_fields(Vector2i(2, 2)).is_empty() and c.board.get_fields(Vector2i(3, 2)).size() == 1, "field_id plus explicit cell removal leaves other instances")
	await c.remove_fields()
	await c.run_actions(c.player, [], [{c.SET_BLOCKED: {"cells": [[2, 1]], "blocked": true}}])
	c._check(c.board.is_blocked(Vector2i(2, 1)) and not c.board.reachable_cells(c.player, 12).has(Vector2i(2, 1)), "ActionSetCellBlocked updates path queries")
	await c.run_actions(c.player, [], [{c.SET_BLOCKED: {"cells": [[2, 1]], "blocked": false}}])
	await c.create_field("field_probe_wall", [[2, 1]])
	c._check(not c.board.reachable_cells(c.player, 12).has(Vector2i(2, 1)), "field_blocks_movement excludes its cell from reachable endpoints")
	await c.remove_fields()
	await c.create_field("field_probe_no_blink", [[2, 1]])
	c._check(c.board.can_stand(c.player, Vector2i(2, 1)) and not c.board.can_teleport(c.player, Vector2i(2, 1)), "teleport-only blocker preserves normal walkability")
	await c.move_unit(c.player, Vector2i(2, 1), {"mode": "TELEPORT"})
	c._check(c.player.board_anchor == Vector2i(2, 2), "ActionMoveUnit TELEPORT rejects field_blocks_teleport_into")
	await c.remove_fields()
	await c.create_field("field_probe_cost", [[2, 1]])
	c._check(c.board.step_cost(c.player, Vector2i(2, 2), Vector2i(2, 1)) == 4 and not c.board.reachable_cells(c.player, 3).has(Vector2i(2, 1)), "field_move_cost_override is consumed by weighted reachability")
	await c.remove_fields()
	c._arrange([[c.player, Vector2i(3, 4)]])
	c._check(await c._play_at("field_card_create", Vector2i(3, 2)) == "", "real Hand request creates a field shape")
	c._check(c.board.get_fields(Vector2i(3, 2)).size() == 1 and c.board.get_fields(Vector2i(2, 2)).size() == 1 and c.board.get_fields(Vector2i(3, 1)).size() == 1, "omitted cells resolves card CROSS rather than only selected cell")
	await c.remove_fields()

func _movement_events(c) -> void:
	c._arrange([[c.player, Vector2i(3, 4)]])
	await c.create_field("field_probe_enter", [[3, 3]])
	var hp: int = c.player.get_combatant_health()
	await c.move_unit(c.player, Vector2i(3, 2))
	c._check(c.player.board_anchor == Vector2i(3, 2) and c.player.get_combatant_health() == hp, "default intermediate field does not trigger enter or leave")
	await c.move_unit(c.player, Vector2i(3, 3))
	c._check(hp - c.player.get_combatant_health() == 3, "destination enter fires once")
	await c.move_unit(c.player, Vector2i(3, 4))
	c._check(hp - c.player.get_combatant_health() == 5, "origin leave fires once")
	await c.remove_fields()
	await c.create_field("field_probe_pass", [[3, 3]])
	hp = c.player.get_combatant_health()
	await c.move_unit(c.player, Vector2i(3, 2))
	c._check(hp - c.player.get_combatant_health() == 5, "pass-through opt-in executes intermediate enter exactly once")
	await c.remove_fields()
	var template: FieldData = Global.get_field_data("field_probe_enter")
	for filter: int in [FieldData.FACTION_FILTERS.PARTY, FieldData.FACTION_FILTERS.ENEMY, FieldData.FACTION_FILTERS.ALLY_OF_OWNER, FieldData.FACTION_FILTERS.OPPONENT_OF_OWNER]:
		template.field_faction_filter = filter
		c._arrange([[c.player, Vector2i(3, 4)]])
		await c.create_field("field_probe_enter", [[3, 3]])
		hp = c.player.get_combatant_health()
		await c.move_unit(c.player, Vector2i(3, 3))
		var expected: int = 3 if filter in [FieldData.FACTION_FILTERS.PARTY, FieldData.FACTION_FILTERS.ALLY_OF_OWNER] else 0
		c._check(hp - c.player.get_combatant_health() == expected, "faction filter %d controls real enter actions" % filter)
		await c.remove_fields()
	template.field_faction_filter = FieldData.FACTION_FILTERS.ANY
	await c.create_field("field_probe_enter", [[4, 3]])
	var spawned: Node = await c._spawn("board_dummy", Vector2i(4, 3))
	c._check(spawned != null and spawned.get_combatant_health() == 300, "spawn does not trigger enter by default")
	spawned.queue_free()
	await c.flow.process_frame
	await c.remove_fields()
	await c.create_field("field_probe_spawn", [[4, 3]])
	spawned = await c._spawn("board_dummy", Vector2i(4, 3))
	await c._wait(c._idle, "spawn opt-in field actions drain")
	c._check(spawned != null and spawned.get_combatant_health() == 293, "spawn opt-in triggers exactly one enter after placement")
	spawned.queue_free()
	await c.flow.process_frame
	await c.remove_fields()

func _owner_lifetime(c) -> void:
	var owner: Node = await c._spawn("board_dummy", Vector2i(4, 3))
	await c.create_field("field_probe_attack", [[3, 3]], owner)
	owner.queue_free()
	await c.flow.process_frame
	await c.flow.process_frame
	c._arrange([[c.player, Vector2i(3, 4)]])
	c.player.add_status_effect_charges("status_effect_vulnerable", 2)
	var hp: int = c.player.get_combatant_health()
	var preview: float = c.field_controller().preview_hazard(Vector2i(3, 3), c.player)
	var preview_again: float = c.field_controller().preview_hazard(Vector2i(3, 3), c.player)
	c._check(preview == 9 and preview_again == preview and c.player.get_combatant_health() == hp, "ownerless AttackGenerator hazard preview includes target Vulnerable without mutating HP")
	await c.move_unit(c.player, Vector2i(3, 3))
	c._check(hp - c.player.get_combatant_health() == int(preview), "freed owner field still executes generated attacks against targets and matches preview")
	c.player.add_status_effect_charges("status_effect_vulnerable", -99)
	await c.remove_fields()
	var victim: Node = await c._spawn("board_dummy", Vector2i(4, 4))
	await c.create_field("field_probe_lethal", [[4, 3]])
	var observed: Array = []
	var observe := func(unit, _board_id, cell):
		if unit == victim:
			observed.append(cell)
	c.signals.unit_entered_cell.connect(observe)
	var money: int = Global.player_data.player_money
	await c.run_actions(victim, [], [{Scripts.ACTION_ADD_MONEY: {"money_amount": 1}}, {Scripts.ACTION_MOVE_UNIT: {"target_cell": Vector2i(4, 2)}}])
	c._check(not victim.is_alive() and not observed.has(Vector2i(4, 2)), "nested generated lethal field attack completes before next movement step")
	c._check(Global.player_data.player_money == money + 1 and c._idle(), "lethal movement does not swallow following independent handler queue")
	c.signals.unit_entered_cell.disconnect(observe)
	await c.remove_fields()
