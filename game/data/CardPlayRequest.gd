## A data payload for requesting a card play through Hand.
## Stored in Hand in a queue and in Actions as a value/targeting reference.
## In other parts of the code it may be used as a holder of values to pass into action payloads with
## card_values if no card is provided, for actions without cards that need shared dynamic values.
extends RefCounted
class_name CardPlayRequest

var card_data: CardData = null
var selected_target: BaseCombatant = null	# the target the player selected for this play, can be null
var card_values: Dictionary = {}	# a duplicated version of the card's values for the duration of the card play, which can be freely modified without affecting the parent card
var refundable_energy: int = 0	# how much energy the card play can refund if interrupted
var input_energy: int = 0	# how much energy is input into the card play. Can be positive even if refundable_energy is 0. Useful for X cost cards and card play duplications
var is_duplicate_play: bool = false	# duplcate plays should not be further duplicated

## Optional scene modules own their namespaced targeting payloads.
var module_contexts: Dictionary = {}
## Generic actor/targets also support non-spatial combat modules.
var acting_unit: BaseCombatant = null
var resolved_targets: Array[BaseCombatant] = []
## Compatibility accessors: storage only; the card core does not interpret these values.
var selected_cell: Vector2i:
	get:
		return module_contexts.get("board", {}).get("cell", Vector2i(-1, -1))
	set(value):
		if not module_contexts.has("board"):
			module_contexts["board"] = {}
		module_contexts["board"]["cell"] = value
var selected_board_id: String:
	get:
		return module_contexts.get("board", {}).get("id", "")
	set(value):
		if not module_contexts.has("board"):
			module_contexts["board"] = {}
		module_contexts["board"]["id"] = value


## Where the card being played came from. This will almost always be HandManager.HAND_PILE, but can be
## from other piles if played indirectly.
## Empty if the card somehow did not come from anywhere (banished)
## WARNING: This will not actually be populated properly until the time of the card play
## during HandManager._play_card().
var card_origin_pile: String = HandManager.BANISH_PILE

## The pile the card will be sent to after the card is finished playing.
## Empty (banish) for cards that do not go anywhere.
## NOTE: This can be mutated by actions/interceptors. Typically you'll intercept the
## special ActionCardPlay action to do it, or use ActionChangeCardPlayDestination.
var card_destination_pile: String = HandManager.BANISH_PILE

## Where in the pile the card will be sent to after the card is finished playing.
## NOTE: This can be modified by actions/interceptors
var card_destination_strategy: int = HandManager.PILE_INSERTION_STRATEGIES.TOP

## The state of the hand at time of play. This is useful for certain validators that need to know hand state
## since it will include the played card (if it was played from hand) while it would otherwise exist
## in limbo.
var hand_at_play_time: Array[CardData] = []

## Duplicate only selection ownership, preserving live actor/unit identities while isolating
## mutable module payload containers. Card values intentionally keep the factory's semantics.
func copy_selection_context_from(source: CardPlayRequest) -> void:
	module_contexts = source.module_contexts.duplicate(true)
	acting_unit = source.acting_unit
	resolved_targets = source.resolved_targets.duplicate()
