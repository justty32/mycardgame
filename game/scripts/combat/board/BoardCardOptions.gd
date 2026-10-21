## Module-owned card options. New content uses card_values.board; old saves/packs
## retain their scalar fields as compatibility fallbacks without involving the card core.
extends RefCounted
class_name BoardCardOptions

static func options(card: CardData) -> Dictionary:
	if card == null:
		return {}
	var value: Variant = card.card_values.get("board", {})
	return value if value is Dictionary else {}

static func range_of(card: CardData) -> int:
	return int(options(card).get("range", card.card_range))

static func shape_of(card: CardData) -> int:
	return int(options(card).get("shape", card.card_shape))

static func faction_of(card: CardData) -> int:
	return int(options(card).get("target_faction", card.card_target_faction))

## Board selection of a card play, stored in the request's "board" module context.
static func selected_cell(request: CardPlayRequest) -> Vector2i:
	if request == null:
		return BaseCombatant.BOARD_ANCHOR_NONE
	return request.module_contexts.get("board", {}).get("cell", BaseCombatant.BOARD_ANCHOR_NONE)

static func selected_board_id(request: CardPlayRequest) -> String:
	if request == null:
		return ""
	return str(request.module_contexts.get("board", {}).get("id", ""))

static func set_selection(request: CardPlayRequest, cell: Vector2i, board_id: String) -> void:
	var context: Dictionary = request.module_contexts.get("board", {})
	context["cell"] = cell
	context["id"] = board_id
	request.module_contexts["board"] = context
