## Detached, normalized board definitions. Runtime geometry never interprets legacy modes.
extends RefCounted
class_name BoardSetup

var _definitions: Dictionary = {}
var deployment: BoardDeployment = null
var layout_slots: Dictionary[String, Rect2] = {}
var explicit: bool = false
var _validated: bool = false
var error: String = ""
var error_detail: String = ""

func is_valid() -> bool:
	return _validated and error == ""

func get_config(id: String) -> Dictionary:
	return _definitions.get(id, {}).duplicate(true)

func get_board_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_definitions.keys())
	return ids

static func from_legacy(encounter: EncounterData, rules: CombatRulesData) -> BoardSetup:
	var setup := BoardSetup.new()
	setup.error = rules.validate_configuration()
	if setup.error != "":
		setup.error_detail = "CombatRulesData \"%s\": %s (board sizes %s, default %s, ceiling %s)" % [rules.object_id, setup.error, rules.describe_board_size_limits(), rules.default_board_size, CombatRulesData.BOARD_SIZE_CEILING]
		return setup
	var checked: Dictionary = encounter.validate_configuration_detail(rules)
	setup.error = checked.code
	setup.error_detail = checked.detail
	if setup.error != "":
		return setup
	for id: String in encounter.get_board_ids(rules):
		var config: Dictionary = encounter.get_board_config(id).duplicate(true)
		config.size = encounter.get_size_for_board(id, rules)
		setup._definitions[id] = config
	var single: bool = encounter.get_board_mode(rules) == CombatRulesData.BOARD_MODES.SINGLE
	var normalized: BoardSetup = from_definitions(setup._definitions, rules)
	if normalized.is_valid():
		normalized.deployment = BoardDeployment.new(normalized._definitions, "shared" if single else "party", "shared" if single else "enemy")
	return normalized

## Internal geometry input, not a serialized encounter format. No deployment policy is required.
static func from_definitions(definitions: Dictionary, rules: CombatRulesData) -> BoardSetup:
	var setup := BoardSetup.new()
	setup.error = rules.validate_spatial_configuration()
	if setup.error != "":
		setup.error_detail = setup.error
		return setup
	for id: Variant in definitions:
		if not id is String or id == "" or not definitions[id] is Dictionary:
			return _invalid("invalid_board_definition", "board IDs must be nonempty strings and definitions objects")
		var config: Dictionary = definitions[id].duplicate(true)
		var raw_size: Variant = config.get("size", null)
		if not EncounterData._valid_cell(raw_size) or not EncounterData._whole_cell(raw_size):
			return _invalid("invalid_board_definition_size", "board %s size must be two whole numbers" % id)
		var size: Vector2i = EncounterData.cell_from_json(raw_size)
		if not rules.is_board_size_allowed(size):
			return _invalid("invalid_board_definition_size", "board %s size %s is outside %s" % [id, size, rules.describe_board_size_limits()])
		config.size = size
		for key: String in ["blocked_cells", "deploy_cells", "spawn_zone_cells"]:
			var cells: Variant = config.get(key, [])
			if not cells is Array:
				return _invalid("invalid_board_definition_cells", "board %s %s must be an array" % [id, key])
			for value: Variant in cells:
				if not _valid_cell(value, size):
					return _invalid("invalid_board_definition_cells", "board %s %s has invalid cell %s" % [id, key, value])
			config[key] = cells
		var fields: Variant = config.get("initial_fields", [])
		if not fields is Array:
			return _invalid("invalid_board_definition_fields", "board %s initial_fields must be an array" % id)
		for field: Variant in fields:
			if not field is Dictionary or not field.get("cells", []) is Array:
				return _invalid("invalid_board_definition_fields", "board %s invalid initial field" % id)
			for value: Variant in field.get("cells", []):
				if not _valid_cell(value, size):
					return _invalid("invalid_board_definition_fields", "board %s invalid field cell %s" % [id, value])
		config.initial_fields = fields
		setup._definitions[id] = config
	setup._validated = true
	return setup

static func _valid_cell(value: Variant, size: Vector2i) -> bool:
	if not EncounterData._valid_cell(value) or not EncounterData._whole_cell(value):
		return false
	var cell: Vector2i = EncounterData.cell_from_json(value)
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

static func _invalid(code: String, detail: String) -> BoardSetup:
	var setup := BoardSetup.new()
	setup.error = code
	setup.error_detail = detail
	return setup

## Versioned author input; omitted/empty envelope is exclusively the legacy path.
static func from_explicit(raw: Dictionary, rules: CombatRulesData) -> BoardSetup:
	if raw.get("version") != 1 or not raw.get("boards") is Array:
		return _invalid("invalid_board_setup", "encounter_board_setup requires version 1 and boards array")
	var definitions: Dictionary = {}
	for entry: Variant in raw.boards:
		if not entry is Dictionary or not entry.get("id") is String or entry.id == "" or definitions.has(entry.id):
			return _invalid("invalid_board_id", "boards require unique nonempty string IDs")
		definitions[entry.id] = entry.duplicate(true)
	var result: BoardSetup = from_definitions(definitions, rules)
	result.explicit = true
	if not result.is_valid() or definitions.is_empty():
		return result
	for id: String in result.get_board_ids():
		for field: Dictionary in result.get_config(id).initial_fields:
			if not field.get("field_id", "") is String or field.get("field_id", "") == "":
				return _invalid("invalid_board_definition_fields", "board %s requires field_id" % id)
			var duration: Variant = field.get("duration", -2)
			if not (duration is int or duration is float) or not is_finite(float(duration)) or float(duration) != floor(float(duration)):
				return _invalid("invalid_board_definition_fields", "board %s field duration must be a whole number" % id)
	var placement: Variant = raw.get("deployment", {})
	if not placement is Dictionary:
		return _invalid("invalid_board_deployment", "deployment must be an object")
	var normalized_definitions: Dictionary = {}
	for id: String in result.get_board_ids():
		normalized_definitions[id] = result.get_config(id)
	result.deployment = BoardDeployment.from_explicit(normalized_definitions, placement)
	if result.deployment.error != "":
		return _invalid(result.deployment.error, "deployment.hero requires a valid board_id and cell; spawn must be valid when supplied")
	var presentation: Variant = raw.get("presentation", {})
	if not presentation is Dictionary or not presentation.get("slots") is Array:
		return _invalid("invalid_board_layout", "presentation.slots must specify every board rectangle")
	for slot: Variant in presentation.slots:
		if not slot is Dictionary or not slot.get("board_id") is String or not definitions.has(slot.board_id) or result.layout_slots.has(slot.board_id):
			return _invalid("invalid_board_layout", "slots require unique known board_id")
		var rect: Variant = slot.get("rect")
		if not rect is Array or rect.size() != 4:
			return _invalid("invalid_board_layout", "rect must be [x,y,width,height]")
		for value: Variant in rect:
			if not (value is int or value is float) or not is_finite(float(value)):
				return _invalid("invalid_board_layout", "rect values must be finite numbers")
		var rectangle := Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
		if not BoardLayout.valid_slot(rectangle):
			return _invalid("invalid_board_layout", "rect width and height must be positive")
		result.layout_slots[slot.board_id] = rectangle
	if result.layout_slots.size() != definitions.size():
		return _invalid("invalid_board_layout", "every board requires a presentation slot")
	return result

## Config-only copy; callers never receive mutable aliases to the prepared snapshot.
func detached_copy() -> BoardSetup:
	var copy := BoardSetup.new()
	copy._definitions = _definitions.duplicate(true)
	copy.layout_slots.assign(layout_slots)
	copy.explicit = explicit
	copy._validated = _validated
	copy.error = error
	copy.error_detail = error_detail
	copy.deployment = deployment.detached_copy() if deployment != null else null
	return copy
