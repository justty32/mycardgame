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
