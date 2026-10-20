## Conservative detection for optional spatial content; shared by card and intent adapters.
## Values may contain nested wrapper payloads and aliases into request/card values.
extends RefCounted
class_name BoardContentPolicy

static func requires_board(data: Variant, context: Dictionary = {}, depth: int = 0) -> bool:
	if depth > 32:
		return true # malformed/deep payloads cannot silently bypass the optional-module guard
	if data is Array:
		for item: Variant in data:
			if requires_board(item, context, depth + 1):
				return true
	elif data is Dictionary:
		var aliases: Dictionary = data.get("custom_key_names", {})
		var override_key: String = str(aliases.get("target_override", "target_override"))
		var override: Variant = data.get(override_key, context.get(override_key, -1))
		if override in [BaseAction.TARGET_OVERRIDES.RESOLVED_SHAPE, BaseAction.TARGET_OVERRIDES.UNITS_IN_RANGE, BaseAction.TARGET_OVERRIDES.UNITS_ON_FIELD]:
			return true
		for key: Variant in data:
			if str(key).contains("/board_actions/") or str(key).contains("/validators/board/"):
				return true
			if requires_board(data[key], context, depth + 1):
				return true
		# Wrapper action_data may itself be supplied only through a renamed request value.
		for alias: Variant in aliases.values():
			if context.has(alias) and requires_board(context[alias], context, depth + 1):
				return true
	return false
