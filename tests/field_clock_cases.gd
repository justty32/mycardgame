extends RefCounted
## Real Director clock advancement, own-action stay ordering and final controller cleanup.

func run(c) -> void:
	c._arrange([[c.player, Vector2i(3, 4)]])
	await c.create_field("field_probe_clock", [[3, 4]])
	var expiry_events: Array = []
	var on_removed := func(instance): expiry_events.append(instance.field_data.object_id)
	c.signals.field_removed.connect(on_removed)
	var hp: int = c.player.get_combatant_health()
	var start: int = c.director.current_tick
	await c.director.advance_clock(start + 350, c.director.get_generation())
	await c._wait(c._idle, "clock field payloads complete after crossing multiple interval boundaries")
	c._check(hp - c.player.get_combatant_health() == 4, "300-tick field catches up at 100 and 200, expires before boundary 300")
	c._check(c.board.get_fields(Vector2i(3, 4)).is_empty() and expiry_events == ["field_probe_clock"], "clock expiry removes field once and emits field_removed")
	c.signals.field_removed.disconnect(on_removed)
	await _catchup_mutations(c)
	await c.create_field("field_probe_stay", [[3, 4]])
	var observed: Array = []
	var on_start := func(unit):
		if unit == c.player:
			observed.append(["start", c.player.get_combatant_health()])
	var on_draw := func(_card): observed.append(["draw", c.player.get_combatant_health()])
	c.signals.unit_action_started.connect(on_start)
	c.signals.card_drawn.connect(on_draw)
	hp = c.player.get_combatant_health()
	c.combat.end_turn_button.button_up.emit()
	await c._wait(func(): return c.director.current_tick > start + 350 and c._player_ready(), "real End Turn reaches hero next action with stay field")
	c._check(observed.size() >= 2 and observed[0] == ["start", hp] and observed[1] == ["draw", hp - 4], "stay occurs after unit_action_started and before first drawn card")
	c._check(hp - c.player.get_combatant_health() == 4, "on_stay triggers exactly once on occupying unit own action")
	c.signals.unit_action_started.disconnect(on_start)
	c.signals.card_drawn.disconnect(on_draw)
	await c.remove_fields()
	await c.create_field("field_probe_clock", [[3, 4]])
	var held_board: BoardData = c.board
	var controller: FieldController = c.field_controller()
	await c.free_scene()
	c._check(held_board.fields.is_empty(), "scene exit clears all field instances even when test holds board reference")
	controller.advance_ticks(0, 1000)
	c._check(not ActionHandler.actions_being_performed, "detached field controller cannot enqueue effects after run exit")

func _catchup_mutations(c) -> void:
	var child := FieldData.new("field_clock_child")
	child.field_stack_policy = FieldData.STACK_POLICIES.IGNORE
	child.field_tick_interval = 100
	child.field_tick_actions.assign([{ get_script().resource_path.get_base_dir().path_join("field_trace_action.gd"): {"label": "child_tick"} }])
	Global.register_rod(child)
	var parent := FieldData.new("field_clock_parent")
	parent.field_duration_ticks = 300
	parent.field_tick_interval = 100
	parent.field_tick_actions.assign([{c.CREATE_FIELD: {"field_id": child.object_id, "cells": [[3, 4]]}}])
	Global.register_rod(parent)
	var bulk: Dictionary = await _created_field_run(c, parent, child, [350])
	var stepped: Dictionary = await _created_field_run(c, parent, child, [100, 100, 100, 50])
	c._check(bulk == stepped and bulk.created == 100 and bulk.next == 400 and bulk.trace == ["child_tick", "child_tick"], "bulk advance equals stepwise: tick-100 child is created at 100 and runs at 200/300")
	var refreshing := FieldData.new("field_clock_refresh")
	refreshing.field_duration_ticks = 300
	refreshing.field_tick_interval = 100
	refreshing.field_stack_policy = FieldData.STACK_POLICIES.REPLACE
	refreshing.field_tick_actions.assign([
		{get_script().resource_path.get_base_dir().path_join("field_trace_action.gd"): {"label": "refresh"}},
		{c.CREATE_FIELD: {"field_id": refreshing.object_id, "cells": [[3, 4]]}},
	])
	Global.register_rod(refreshing)
	await c.create_field(refreshing.object_id, [[3, 4]])
	Global.set_meta("field_test_trace", [])
	var endpoint: int = c.director.current_tick + 350
	await c.director.advance_clock(endpoint, c.director.get_generation())
	await c._wait(c._idle, "catch-up refreshed field drains")
	var found: FieldInstance = c.board.get_fields(Vector2i(3, 4))[0]
	c._check(found.created_tick == endpoint - 50 and found.expires_tick == endpoint + 250 and Global.get_meta("field_test_trace") == ["refresh", "refresh", "refresh"], "tick refresh reschedules new boundaries within the same bulk advance")
	Global.remove_meta("field_test_trace")
	await c.remove_fields()
	refreshing.field_stack_policy = FieldData.STACK_POLICIES.STACK
	await c.create_field(refreshing.object_id, [[3, 4]])
	Global.set_meta("field_test_trace", [])
	var old: FieldInstance = c.board.get_fields(Vector2i(3, 4))[0]
	var original_tick: int = old.created_tick
	var stale: Array[BaseAction] = []
	for event: String in ["tick", "expire"]:
		var work := FieldEventAction.new(c.field_controller(), event, old.cell, null, old)
		work.scheduled_revision = old.revision
		stale.append(work)
	await c.create_field(refreshing.object_id, [[3, 4]])
	ActionHandler.add_ordered_actions(stale)
	await c._wait(c._idle, "same-tick refreshed stale boundary queue drains")
	c._check(c.board.get_fields(Vector2i(3, 4)).has(old) and old.stacks == 2 and old.created_tick == original_tick and Global.get_meta("field_test_trace").is_empty(), "same-created-tick refresh revision suppresses old tick and expiry work")
	Global.remove_meta("field_test_trace")
	await c.remove_fields()

func _created_field_run(c, parent: FieldData, child: FieldData, steps: Array) -> Dictionary:
	await c.create_field(parent.object_id, [[3, 4]])
	Global.set_meta("field_test_trace", [])
	var start: int = c.director.current_tick
	for step: int in steps:
		await c.director.advance_clock(c.director.current_tick + step, c.director.get_generation())
		await c._wait(c._idle, "created field clock step drains")
	var found: FieldInstance = c.board.get_fields(Vector2i(3, 4))[0]
	c._check(found.field_data == child, "parent expired while its created child survives")
	var snapshot: Dictionary = {"created": found.created_tick - start, "next": found.next_tick - start, "trace": Global.get_meta("field_test_trace").duplicate()}
	await c.remove_fields()
	return snapshot
