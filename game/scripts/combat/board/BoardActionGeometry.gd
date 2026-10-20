## Pre-payment geometry checks, including conditional/nested action payloads. This is
## conservative: both branches must be safe, since earlier effects can change the predicate.
extends RefCounted
class_name BoardActionGeometry

static func check(board: BoardData, parent: BaseCombatant, cell: Vector2i, data: Variant, context_values: Dictionary = {}, depth: int = 0) -> String:
	if depth > 32:
		return "action_geometry_depth_exceeded"
	if data is Array:
		for entry: Variant in data:
			var error: String = check(board, parent, cell, entry, context_values, depth + 1)
			if error != "":
				return error
	elif data is Dictionary:
		for key: Variant in data:
			var value: Variant = data[key]
			if value is Dictionary:
				# Wrapper children can live in card/request values and use custom key names.
				var child_keys: Array[String] = []
				if str(key) == Scripts.ACTION_VALIDATOR:
					child_keys.assign(["passed_action_data", "failed_action_data"])
				elif str(key).ends_with("/ActionVariableActionGenerator.gd"):
					child_keys.assign(["action_data"])
				elif str(key).ends_with("/ActionRandomSelection.gd"):
					child_keys.assign(["weighted_action_data"])
				for child_key: String in child_keys:
					var child_error: String = check(board, parent, cell, _value(value, context_values, child_key, []), context_values, depth + 1)
					if child_error != "":
						return child_error
				var action_error: String = _check_action(board, parent, cell, str(key), value, context_values)
				if action_error != "":
					return action_error
			var nested_error: String = check(board, parent, cell, value, context_values, depth + 1)
			if nested_error != "":
				return nested_error
	return ""

static func _value(values: Dictionary, context: Dictionary, name: String, fallback: Variant) -> Variant:
	var names: Dictionary = values.get("custom_key_names", {})
	var key: String = str(names.get(name, name))
	return values.get(key, context.get(key, fallback))

static func _check_action(board: BoardData, parent: BaseCombatant, cell: Vector2i, path: String, values: Dictionary, context: Dictionary) -> String:
	if path not in [Scripts.ACTION_COMPUTE_BOARD_VALUE, Scripts.ACTION_DISPLACE_UNIT, Scripts.ACTION_MOVE_UNIT]:
		return ""
	var movement: String = str(_value(values, context, "mode", "PUSH")) if path == Scripts.ACTION_DISPLACE_UNIT else ""
	if path == Scripts.ACTION_DISPLACE_UNIT:
		var override_error: String = _override_error(board, parent, values, context, movement)
		if override_error != "":
			return override_error
		var override: int = int(_value(values, context, "target_override", BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS))
		if override not in [BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS, BaseAction.TARGET_OVERRIDES.RESOLVED_SHAPE]:
			movement = "" # The selected cell does not determine this override's targets.
	var query: Dictionary = BoardTargeting.geometry(board, parent, cell, BoardTargeting.TARGET_SHAPES.SINGLE, -1, movement)
	if not query.valid:
		return query.error
	if not query.cross_board:
		return ""
	if path == Scripts.ACTION_COMPUTE_BOARD_VALUE:
		return "cross_board_distance_undefined"
	if path != Scripts.ACTION_MOVE_UNIT:
		return ""
	var mode: String = str(_value(values, context, "mode", "TO_CELL"))
	var target_board_id: String = str(_value(values, context, "target_board_id", ""))
	var teleport: bool = mode == "TELEPORT" or not bool(_value(values, context, "use_path", true))
	if target_board_id == "SELECTED":
		target_board_id = board.board_id
	if target_board_id != "" and target_board_id != parent.board_id:
		return "" if teleport else "cross_board_walk_unsupported"
	if mode in ["TOWARD", "AWAY"]:
		var reference: String = str(_value(values, context, "reference", "SELECTED_TARGET"))
		if reference == "SELECTED_TARGET":
			return "cross_board_direction_unsupported"
		if reference == "HERO":
			var hero: BaseCombatant = UnitRegistry.get_hero()
			if hero != null and hero.board_id != parent.board_id:
				return "cross_board_direction_unsupported"
		return ""
	# A selected cell on another board cannot silently become the same coordinate locally.
	if _value(values, context, "target_cell", null) == null:
		return "cross_board_move_requires_destination"
	return ""

## Resolve all possible global targets without drawing RNG. The actual action still validates
## again after any earlier queued effect changes membership or position.
static func _override_error(board: BoardData, parent: BaseCombatant, values: Dictionary, context: Dictionary, movement: String) -> String:
	var override: int = int(_value(values, context, "target_override", BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS))
	if override in [BaseAction.TARGET_OVERRIDES.SELECTED_TARGETS, BaseAction.TARGET_OVERRIDES.RESOLVED_SHAPE]:
		return ""
	var action_values: Dictionary[String, Variant] = {}
	action_values.assign(values)
	var names: Dictionary = values.get("custom_key_names", {})
	var override_key: String = str(names.get("target_override", "target_override"))
	if override == BaseAction.TARGET_OVERRIDES.RANDOM_OPPONENT:
		action_values[override_key] = BaseAction.TARGET_OVERRIDES.ALL_OPPONENTS
	elif override == BaseAction.TARGET_OVERRIDES.RANDOM_ENEMY:
		action_values[override_key] = BaseAction.TARGET_OVERRIDES.ALL_ENEMIES
	var request := CardPlayRequest.new()
	request.card_values = context.duplicate()
	var probe := BaseAction.new()
	probe.init(parent, request, [], action_values)
	for candidate: BaseCombatant in probe.get_adjusted_action_targets():
		var target_board: BoardData = board if board.has_unit(candidate) else BoardData.get_for_unit(candidate)
		var query: Dictionary = BoardTargeting.geometry(target_board, parent, candidate.board_anchor, BoardTargeting.TARGET_SHAPES.SINGLE, -1, movement)
		if not query.valid:
			return query.error
	return ""
