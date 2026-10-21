## Data-only detection of content that needs an optional combat module (CombatModule). Uses plain
## string / enum markers, never module classes, so an unmounted (or removed) module can still be
## refused before fees, greyed out in hand and skipped by enemy intents.
## Content may also declare requirements explicitly: card_values / action values
## "requires_modules": ["board"].
extends RefCounted
class_name CombatContentRequirements

const MODULE_BOARD: StringName = &"board"
const REJECTION_SUFFIX: String = "_module_required"
const MAX_DEPTH: int = 32

## Board markers: module action / validator script folders and spatial target overrides.
const BOARD_PATH_MARKERS: Array[String] = ["/board_actions/", "/validators/board/"]
const BOARD_TARGET_OVERRIDES: Array[int] = [
	BaseAction.TARGET_OVERRIDES.RESOLVED_SHAPE,
	BaseAction.TARGET_OVERRIDES.UNITS_IN_RANGE,
	BaseAction.TARGET_OVERRIDES.UNITS_ON_FIELD,
]

static func rejection_for(module_id: StringName) -> String:
	return str(module_id) + REJECTION_SUFFIX

## First missing module's rejection reason ("board_module_required"), "" when all are mounted.
static func missing_rejection(required: Array[StringName], mounted: Array[StringName]) -> String:
	for module_id: StringName in required:
		if not mounted.has(module_id):
			return rejection_for(module_id)
	return ""

## Modules a card needs: explicit declaration, legacy scalar board fields, card_values.board and
## its action / validator payloads (request values may alias wrapper payloads).
static func card_requirements(card: CardData, request_values: Dictionary = {}) -> Array[StringName]:
	var found: Array[StringName] = []
	if card == null:
		return found
	var context: Dictionary = card.card_values.duplicate()
	context.merge(request_values, true)
	_add_declared(found, context.get("requires_modules", []))
	var board_options: Variant = context.get("board", {})
	if (board_options is Dictionary and not board_options.is_empty()) or card.card_range != -1 or card.card_shape != 0 or card.card_target_faction != 0 or card.card_move_distance != 0:
		_add(found, MODULE_BOARD)
	_scan(card.card_play_actions, context, found, 0)
	_scan(card.card_play_validators, context, found, 0)
	_scan(context, context, found, 0)
	return found

static func card_requires(card: CardData, module_id: StringName, request_values: Dictionary = {}) -> bool:
	return card_requirements(card, request_values).has(module_id)

## Modules an action payload (Array / Dictionary of {script_path: values}) needs.
static func payload_requirements(data: Variant, context: Dictionary = {}) -> Array[StringName]:
	var found: Array[StringName] = []
	_scan(data, context, found, 0)
	return found

static func payload_requires(data: Variant, module_id: StringName, context: Dictionary = {}) -> bool:
	return payload_requirements(data, context).has(module_id)

static func _add(found: Array[StringName], module_id: StringName) -> void:
	if module_id != &"" and not found.has(module_id):
		found.append(module_id)

static func _add_declared(found: Array[StringName], declared: Variant) -> void:
	if declared is Array or declared is PackedStringArray:
		for value: Variant in declared:
			_add(found, StringName(str(value)))
	elif declared is String or declared is StringName:
		_add(found, StringName(str(declared)))

static func _scan(data: Variant, context: Dictionary, found: Array[StringName], depth: int) -> void:
	if depth > MAX_DEPTH:
		_add(found, MODULE_BOARD)	# malformed / deep payloads cannot silently bypass the guard
		return
	if data is Array:
		for item: Variant in data:
			_scan(item, context, found, depth + 1)
	elif data is Dictionary:
		var aliases: Dictionary = data.get("custom_key_names", {}) if data.get("custom_key_names", {}) is Dictionary else {}
		_add_declared(found, data.get("requires_modules", []))
		var override_key: String = str(aliases.get("target_override", "target_override"))
		var override: Variant = data.get(override_key, context.get(override_key, -1))
		if (override is int or override is float) and BOARD_TARGET_OVERRIDES.has(int(override)):
			_add(found, MODULE_BOARD)
		# A summon placed only by cells has no slot fallback without the board.
		var spawn_cells: Variant = data.get("spawn_cells", [])
		var spawn_slots: Variant = data.get("spawn_slots", [])
		if spawn_cells is Array and not spawn_cells.is_empty() and not (spawn_slots is Array and not spawn_slots.is_empty()):
			_add(found, MODULE_BOARD)
		for key: Variant in data:
			var text: String = str(key)
			for marker: String in BOARD_PATH_MARKERS:
				if text.contains(marker):
					_add(found, MODULE_BOARD)
			_scan(data[key], context, found, depth + 1)
		# Wrapper action_data may itself be supplied only through a renamed request value.
		for alias: Variant in aliases.values():
			if context.has(alias):
				_scan(context[alias], context, found, depth + 1)
