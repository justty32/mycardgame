extends "board_fixture.gd"
## Data-only extension of the existing real-run board fixture.

func install() -> void:
	super.install()
	var rules: CombatRulesData = Global.get_combat_rules()
	rules.free_move_per_action = 12
	rules.paid_move_max_cells = 0
	Global.get_character_data("character_red").character_starting_health = 2000
	_add_field("field_probe_enter", {"field_on_enter_actions": _damage(3), "field_on_leave_actions": _damage(2), "field_tags": ["probe"]})
	_add_field("field_probe_pass", {"field_on_enter_actions": _damage(5), "field_triggers_on_pass_through": true})
	_add_field("field_probe_spawn", {"field_on_enter_actions": _damage(7), "field_triggers_on_spawn": true})
	_add_field("field_probe_clock", {"field_duration_ticks": 300, "field_tick_interval": 100, "field_tick_actions": _damage(2)})
	_add_field("field_probe_stay", {"field_on_stay_actions": _damage(4)})
	_add_field("field_probe_wall", {"field_blocks_movement": true})
	_add_field("field_probe_no_blink", {"field_blocks_teleport_into": true})
	_add_field("field_probe_cost", {"field_move_cost_override": 4})
	_add_field("field_probe_attack", {"field_on_enter_actions": [{Scripts.ACTION_ATTACK_GENERATOR: {"damage": 6, "number_of_attacks": 1, "time_delay": 0.0}}]})
	_add_field("field_probe_lethal", {"field_triggers_on_pass_through": true, "field_on_enter_actions": [{Scripts.ACTION_ATTACK_GENERATOR: {"damage": 1000, "time_delay": 0.0}}]})
	Global.get_encounter_data("board_flow_encounter").encounter_initial_fields.assign([{ "field_id": "field_probe_enter", "cells": [[0, 0]] }])
	_add_card("field_card_create", 5, BoardTargeting.TARGET_SHAPES.CROSS, BoardTargeting.TARGET_FACTIONS.EMPTY_CELL, {"field_id": "field_probe_enter"}, [{"res://scripts/actions/board_actions/ActionCreateField.gd": {}}])
	print("FIELD FIXTURE: same 7x5 real run; hero 2000 HP, 12 free move; field definitions registered through JSON patch schema; field actions have no audio.")

func _damage(amount: int) -> Array[Dictionary]:
	return [{Scripts.ACTION_DIRECT_DAMAGE: {"damage": amount, "bypass_block": true}}]

func _add_field(id: String, properties: Dictionary) -> FieldData:
	var data := FieldData.new(id)
	data.set_serializable_properties_from_json_patch({"object_id": id, "properties": properties})
	Global.register_rod(data)
	return data
