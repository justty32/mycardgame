## Executable listener example. CardData has no card_listeners field: a decorator can own
## this signal subscription while its card is in hand. Store weak references to avoid cycles.
extends RefCounted

var owner_ref: WeakRef
var card: CardData
var moves: int = 0

func attach(owner: BaseCombatant, data: CardData) -> void:
	detach()
	owner_ref = weakref(owner)
	card = data
	Signals.unit_moved.connect(_on_moved)

func detach() -> void:
	if Signals.unit_moved.is_connected(_on_moved):
		Signals.unit_moved.disconnect(_on_moved)
	owner_ref = null
	card = null

func _on_moved(unit: BaseCombatant, _from: Vector2i, _to: Vector2i) -> void:
	if owner_ref == null or owner_ref.get_ref() != unit or not HandManager.player_hand.has(card):
		return
	moves += 1
