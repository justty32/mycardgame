## Scene-supplied card policy. The default preserves ordinary unit-targeted card play.
## Hooks are synchronous and never reserve/refund energy or enqueue actions.
extends RefCounted
class_name CardPlayAdapter

func needs_selection(card: CardData) -> bool:
	return card.card_requires_target

func prepare_request(request: CardPlayRequest, selection: Dictionary = {}) -> String:
	if selection.has("target"):
		request.selected_target = selection.target
	if selection.has("actor"):
		request.acting_unit = selection.actor
	return ""

func validate_request(_request: CardPlayRequest) -> String:
	return ""

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

## Optional module input. Base implementations never reinterpret a cell as a unit target.
func selection_for_target(target: BaseCombatant) -> Dictionary:
	return {"target": target}

func handle_cell_clicked(_hand: Hand, _id: String, _cell: Vector2i) -> void:
	pass

func handle_cell_hovered(_hand: Hand, _id: String, _cell: Vector2i) -> void:
	pass
