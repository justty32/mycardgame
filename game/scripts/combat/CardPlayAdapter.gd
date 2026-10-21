## Scene-supplied card policy. The default preserves ordinary unit-targeted card play and refuses
## content that needs an unmounted optional module (CombatContentRequirements) before any fee.
## Hooks are synchronous and never reserve/refund energy or enqueue actions. A mounted
## CombatModule may supply a subclass (CombatModule.get_card_play_adapter()).
extends RefCounted
class_name CardPlayAdapter

## "" = the card can be played with the modules mounted now; otherwise the rejection reason
## (e.g. "board_module_required"). Card.can_play_card greys such cards out in hand.
func get_availability_error(card: CardData, request_values: Dictionary = {}) -> String:
	if card == null:
		return ""
	return CombatContentRequirements.missing_rejection(CombatContentRequirements.card_requirements(card, request_values), mounted_module_ids())

func mounted_module_ids() -> Array[StringName]:
	var director: CombatDirector = Global.get_combat_director()
	if director != null:
		return director.get_mounted_module_ids()
	var none: Array[StringName] = []
	return none

func needs_selection(card: CardData) -> bool:
	return card.card_requires_target

func prepare_request(request: CardPlayRequest, selection: Dictionary = {}) -> String:
	if selection.has("target"):
		request.selected_target = selection.target
	if selection.has("actor"):
		request.acting_unit = selection.actor
	return reject(request, get_availability_error(request.card_data, request.card_values))

func validate_request(request: CardPlayRequest) -> String:
	if request == null:
		return ""
	return reject(request, get_availability_error(request.card_data, request.card_values))

## Records the reason on the request (never in card_values, which feed action values).
func reject(request: CardPlayRequest, reason: String) -> String:
	if reason != "" and request != null:
		request.rejection_reason = reason
	return reason

func resolve_play(request: CardPlayRequest, default_actor: BaseCombatant) -> Dictionary:
	var targets: Array[BaseCombatant] = [request.selected_target]
	if not request.resolved_targets.is_empty():
		targets.assign(request.resolved_targets)
	var actor: BaseCombatant = request.acting_unit if is_instance_valid(request.acting_unit) else default_actor
	return {"actor": actor, "targets": targets, "actions_data": request.card_data.card_play_actions.duplicate()}

func bind_hand(_hand: Hand) -> void:
	pass

func unbind_hand() -> void:
	pass

## Module input may enrich a unit selection (e.g. with its position).
func selection_for_target(target: BaseCombatant) -> Dictionary:
	return {"target": target}
