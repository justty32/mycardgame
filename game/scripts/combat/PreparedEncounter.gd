## Detached author data and an optional data-only module setup for one start.
extends RefCounted
class_name PreparedEncounter

const BOARD_MODULE_SCRIPT: String = "res://scripts/combat/board/BoardCombatModule.gd"
var _event: Dictionary = {}
var _rules: Dictionary = {}
var _encounter: Dictionary = {}
var _module_setup: Variant = null
var _mount_board: bool = false
var board_format: String = "legacy"
var error_code: String = ""
var error_detail: String = ""
var unavailable_reason: String = ""

static func prepare(event_data: EventData = null, resolver: Callable = Callable(), scene_board_enabled: bool = true) -> PreparedEncounter:
	if event_data == null:
		event_data = Global.get_player_event_data()
	var prepared := PreparedEncounter.new()
	if event_data != null:
		prepared._event = event_data.get_serializable_properties().duplicate(true)
	prepared._rules = Global.get_configured_combat_rules().get_serializable_properties().duplicate(true)
	var event_snapshot: EventData = prepared.get_event()
	var resolved: EncounterData = resolver.call(event_snapshot) if resolver.is_valid() else Global.get_event_encounter_data(event_snapshot, prepared.get_rules())
	if resolved == null:
		return prepared._reject("missing_encounter", "event %s names an unavailable encounter" % (event_data.object_id if event_data != null else ""))
	prepared._encounter = resolved.get_serializable_properties().duplicate(true)
	var raw: Variant = resolved.encounter_board_setup
	if not raw is Dictionary:
		return prepared._reject("invalid_board_setup", "encounter_board_setup must be an object")
	if not raw.is_empty():
		var version: Variant = raw.get("version")
		if not (version is int or version is float) or version != 1 or not raw.get("boards") is Array:
			return prepared._reject("invalid_board_setup", "encounter_board_setup requires version 1 and boards array")
		if resolved.has_legacy_board_overrides():
			return prepared._reject("conflicting_board_formats", "new setup cannot be combined with nondefault legacy board overrides")
		for key: Variant in raw:
			if key not in ["version", "boards", "deployment", "presentation"]:
				return prepared._reject("invalid_board_setup", "unknown setup key %s" % key)
		prepared.board_format = "zero" if raw.boards.is_empty() else "explicit"
		if prepared.board_format == "zero" and (raw.has("deployment") or raw.has("presentation")):
			return prepared._reject("invalid_board_setup", "zero boards has no deployment or presentation configuration")
	for wave: EncounterWaveData in resolved.encounter_waves:
		if wave == null:
			return prepared._reject("invalid_encounter_wave", "encounter wave must not be null")
		for entry: Dictionary in wave.wave_units:
			if not entry.get("weights", {}) is Dictionary:
				return prepared._reject("invalid_encounter_wave", "wave weights must be an object")
			for enemy_id: Variant in entry.get("weights", {}):
				var weight: Variant = entry.weights[enemy_id]
				if not (weight is int or weight is float) or weight < 0 or weight != floorf(float(weight)):
					return prepared._reject("invalid_encounter_wave", "wave weights must be nonnegative whole numbers")
				if not enemy_id is String or Global.get_enemy_data(enemy_id) == null:
					return prepared._reject("invalid_encounter_enemy", "unknown wave enemy %s" % enemy_id)
	if not scene_board_enabled:
		prepared.unavailable_reason = "scene_disabled"
	elif not prepared._rules.get("board_enabled", true):
		prepared.unavailable_reason = "rules_disabled"
	elif not ResourceLoader.exists(BOARD_MODULE_SCRIPT):
		prepared.unavailable_reason = "module_missing"
	if prepared.board_format == "zero":
		return prepared
	if prepared.unavailable_reason != "":
		return prepared._reject("board_module_unavailable", prepared.unavailable_reason) if prepared.board_format == "explicit" else prepared
	var module_script: Variant = load(BOARD_MODULE_SCRIPT)
	var checked: Dictionary = module_script.prepare_encounter(prepared.get_encounter(), prepared.get_rules())
	if not checked.ok:
		return prepared._reject(checked.code, checked.detail)
	prepared._module_setup = checked.setup
	prepared._mount_board = true
	return prepared

func _reject(code: String, detail: String) -> PreparedEncounter:
	error_code = code
	error_detail = detail
	return self

func is_valid() -> bool:
	return error_code == ""

func get_event() -> EventData:
	if _event.is_empty():
		return null
	var data := EventData.new()
	data.set_serializable_properties(_event.duplicate(true))
	return data

func get_rules() -> CombatRulesData:
	var data := CombatRulesData.new()
	data.set_serializable_properties(_rules.duplicate(true))
	return data

func get_encounter() -> EncounterData:
	var data := EncounterData.new()
	data.set_serializable_properties(_encounter.duplicate(true))
	return data

## Detached data-only copy, with no parser rerun and no mutable alias to preparation.
func get_module_setup() -> Variant:
	return _module_setup.detached_copy() if _module_setup != null else null

func allows_board_module() -> bool:
	return is_valid() and _mount_board

func uses_event_slots() -> bool:
	return board_format != "explicit"
