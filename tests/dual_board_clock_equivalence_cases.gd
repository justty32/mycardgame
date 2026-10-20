extends RefCounted
## Real Director advances: independent bulk/stepwise experiments with explicit expected states.

func run(c) -> void:
	for kind: String in ["refresh", "death", "cross"]:
		var bulk: Dictionary = await _experiment(c, kind, [350])
		var stepped: Dictionary = await _experiment(c, kind, [100, 100, 100, 50])
		c._check(bulk == stepped, "field bulk/stepwise equivalence for " + kind + ": " + str(bulk))
		match kind:
			"refresh":
				c._check(bulk.trace == ["refresh", "refresh", "refresh"] and bulk.created == 300 and bulk.expires == 600 and bulk.next == 400, "REPLACE refresh happens at each effective boundary, not final endpoint")
			"death":
				c._check(bulk.trace == ["death"] and not bulk.alive and not bulk.occupied and bulk.next == 400, "tick death removes target and later ticks do not replay payload")
			"cross":
				c._check(bulk.trace == ["parent", "parent", "child", "child"] and bulk.created == 100 and bulk.next == 400 and bulk.board == "enemy", "cross-board child created at 100 joins global 200/300 boundaries; equal ticks use board order")

func _experiment(c, kind: String, steps: Array) -> Dictionary:
	var start: int = c.director.current_tick
	var name: String = "equivalence_" + kind + "_" + str(start)
	var parent := FieldData.new(name)
	parent.field_tick_interval = 100
	parent.field_duration_ticks = 300 if kind != "death" else -1
	var trace_path: String = get_script().resource_path.get_base_dir().path_join("field_trace_action.gd")
	var child: FieldData = null
	var victim: Enemy = null
	var board_id: String = "party"
	var cell: Vector2i = Vector2i(3, 4)
	if kind == "refresh":
		parent.field_tick_actions.assign([{trace_path: {"label": "refresh"}}, {c.CREATE_FIELD: {"field_id": name, "cells": [cell], "board_id": "party"}}])
	elif kind == "death":
		board_id = "enemy"
		cell = Vector2i(0, 4)
		victim = c.director.spawn_enemy_at_cell("board_dummy", cell, board_id)
		await c.flow.process_frame
		await c.flow.process_frame
		parent.field_tick_actions.assign([{trace_path: {"label": "death"}}, {Scripts.ACTION_DIRECT_DAMAGE: {"damage": 9999, "bypass_block": true}}])
	else:
		child = FieldData.new(name + "_child")
		child.field_stack_policy = FieldData.STACK_POLICIES.IGNORE
		child.field_tick_interval = 100
		child.field_tick_actions.assign([{trace_path: {"label": "child"}}])
		Global.register_rod(child)
		parent.field_tick_actions.assign([{trace_path: {"label": "parent"}}, {c.CREATE_FIELD: {"field_id": child.object_id, "cells": [cell], "board_id": "enemy"}}])
	Global.register_rod(parent)
	await c.create_field(parent.object_id, [cell], c.player, {"board_id": board_id})
	Global.set_meta("field_test_trace", [])
	for step: int in steps:
		await c.director.advance_clock(c.director.current_tick + step, c.director.get_generation())
		await c._wait(c._idle, kind + " clock experiment drains")
	var observed: BoardData = c.enemy_board if kind in ["death", "cross"] else c.party_board
	var fields: Array[FieldInstance] = observed.get_fields(cell)
	var snapshot: Dictionary = {"trace": Global.get_meta("field_test_trace").duplicate()}
	if c._check(fields.size() == 1, kind + " experiment leaves expected active field"):
		var instance: FieldInstance = fields[0]
		snapshot["created"] = instance.created_tick - start
		snapshot["expires"] = instance.expires_tick - start if instance.expires_tick >= 0 else -1
		snapshot["next"] = instance.next_tick - start
		snapshot["board"] = instance.board_id
	if kind == "death":
		snapshot["alive"] = is_instance_valid(victim) and victim.is_alive()
		snapshot["occupied"] = c.enemy_board.get_unit_at(cell) != null
		if is_instance_valid(victim):
			victim.queue_free()
			await c.flow.process_frame
	for id: String in ["party", "enemy"]:
		await c.run_actions(c.player, [], [{c.REMOVE_FIELD: {"board_id": id}}])
	Global.remove_meta("field_test_trace")
	return snapshot
