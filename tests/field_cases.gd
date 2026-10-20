extends "board_cases.gd"
## Reuses the established real Root/map/Hand startup and handler waits; no duplicated run driver.

const CREATE_FIELD: String = "res://scripts/actions/board_actions/ActionCreateField.gd"
const REMOVE_FIELD: String = "res://scripts/actions/board_actions/ActionRemoveField.gd"
const SET_BLOCKED: String = "res://scripts/actions/board_actions/ActionSetCellBlocked.gd"

func _scenario() -> bool:
	var fixture: RefCounted = load(flow.get_script().resource_path.get_base_dir().path_join("field_fixture.gd")).new()
	fixture.install()
	if not await _start_combat():
		return false
	var ordered: RefCounted = load(flow.get_script().resource_path.get_base_dir().path_join("ordered_action_cases.gd")).new()
	await ordered.run(flow, _check, player, board.get_unit_at(Vector2i(0, 0)))
	for script: String in ["field_action_cases.gd", "field_query_cases.gd", "field_movement_cases.gd", "field_intent_cases.gd", "field_reaction_cases.gd", "field_lifetime_cases.gd", "field_clock_cases.gd"]:
		var group: RefCounted = load(flow.get_script().resource_path.get_base_dir().path_join(script)).new()
		await group.run(self)
		if is_instance_valid(game_root):
			await remove_fields()
	return true

func field_controller() -> FieldController:
	return board.field_controller.get_ref() as FieldController if board.field_controller != null else null

func create_field(id: String, cells: Array, owner: Node = null, extra: Dictionary = {}) -> void:
	var values: Dictionary = {"field_id": id, "cells": cells}
	values.merge(extra, true)
	await _run_actions(owner if owner != null else player, [], [{CREATE_FIELD: values}])

func remove_fields() -> void:
	await _run_actions(player, [], [{REMOVE_FIELD: {}}])

func move_unit(unit: Node, cell: Vector2i, extra: Dictionary = {}) -> void:
	var values: Dictionary = {"target_cell": cell}
	values.merge(extra, true)
	await _run_actions(unit, [], [{Scripts.ACTION_MOVE_UNIT: values}])

func run_actions(parent: Node, targets: Array, data: Array) -> void:
	var typed: Array[Dictionary] = []
	typed.assign(data)
	await _run_actions(parent, targets, typed)
