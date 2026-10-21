## Board-module view of the core content requirements (CombatContentRequirements), shared by the
## card adapter and board intents. The detection itself lives in the core so it also works when
## this module is unmounted or removed.
extends RefCounted
class_name BoardContentPolicy

static func requires_board(data: Variant, context: Dictionary = {}) -> bool:
	return CombatContentRequirements.payload_requires(data, CombatContentRequirements.MODULE_BOARD, context)

static func card_uses_board(card: CardData, request_values: Dictionary = {}) -> bool:
	return CombatContentRequirements.card_requires(card, CombatContentRequirements.MODULE_BOARD, request_values)
