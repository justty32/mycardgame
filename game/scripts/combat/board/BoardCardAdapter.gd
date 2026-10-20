## Optional spatial card policy, installed by the combat scene even when disabled so
## explicitly spatial content is rejected before payment rather than silently misplayed.
extends CardPlayAdapter
class_name BoardCardAdapter

var combat_ref: WeakRef
var input: BoardCardInput = null

func _init(combat: Node = null) -> void:
	combat_ref = weakref(combat) if combat != null else null

func _battlefield() -> CombatBattlefield:
	var combat: Node = combat_ref.get_ref() if combat_ref != null else null
	if not is_instance_valid(combat):
		return null
	var director: CombatDirector = combat.get("combat_director")
	return director.battlefield if director != null else null

## Old serialized defaults stay ordinary; explicit spatial metadata/actions opt in.
static func uses_board(card: CardData, request_values: Dictionary = {}) -> bool:
	if card == null:
		return false
	var context: Dictionary = card.card_values.duplicate()
	context.merge(request_values, true)
	return not BoardCardOptions.options(card).is_empty() or BoardCardOptions.range_of(card) != -1 or BoardCardOptions.shape_of(card) != 0 or BoardCardOptions.faction_of(card) != 0 or card.card_move_distance != 0 or BoardContentPolicy.requires_board(card.card_play_actions, context) or BoardContentPolicy.requires_board(card.card_play_validators, context) or BoardContentPolicy.requires_board(context, context)

func needs_selection(card: CardData) -> bool:
	return BoardTargeting.card_needs_cell(card) if uses_board(card) else super.needs_selection(card)

func prepare_request(request: CardPlayRequest, selection: Dictionary = {}) -> String:
	super.prepare_request(request, selection)
	if not uses_board(request.card_data, request.card_values):
		# Translate optional cell input back to the ordinary enemy-click contract.
		# Empty/friendly cells cannot become a paid null-target play or self-attack.
		if selection.get("cell", BaseCombatant.BOARD_ANCHOR_NONE) != BaseCombatant.BOARD_ANCHOR_NONE and request.card_data.card_requires_target:
			var selected_board: BoardData = _selection_board(request, str(selection.get("id", "")))
			if selected_board == null:
				return _reject(request, "board_module_required")
			var target: BaseCombatant = selected_board.get_unit_at(selection.cell)
			if not target is Enemy or not target.is_alive() or target.faction != BaseCombatant.FACTIONS.ENEMY:
				return _reject(request, "no_valid_target")
			request.selected_target = target
		return ""
	var battlefield: CombatBattlefield = _battlefield()
	if battlefield == null:
		return _reject(request, "board_module_required")
	var acting: BaseCombatant = request.acting_unit if is_instance_valid(request.acting_unit) else UnitRegistry.get_hero()
	request.acting_unit = acting
	var cell: Vector2i = selection.get("cell", request.selected_cell)
	var id: String = selection.get("id", request.selected_board_id)
	if id == "" and is_instance_valid(acting):
		id = acting.board_id
	var board: BoardData = battlefield.get_board(id)
	if board == null:
		return _reject(request, "invalid_board")
	request.selected_cell = cell
	request.selected_board_id = id
	if cell != BaseCombatant.BOARD_ANCHOR_NONE:
		match BoardCardOptions.faction_of(request.card_data):
			BoardTargeting.TARGET_FACTIONS.EMPTY_CELL:
				request.selected_target = null
			BoardTargeting.TARGET_FACTIONS.SELF:
				request.selected_target = acting
			_:
				request.selected_target = board.get_unit_at(cell)
	else:
		var shape: int = BoardCardOptions.shape_of(request.card_data)
		if shape in [BoardTargeting.TARGET_SHAPES.SELF_AREA, BoardTargeting.TARGET_SHAPES.ALL] and acting != null:
			request.resolved_targets = BoardTargeting.resolve_targets(board, acting, acting.board_anchor, shape, BoardCardOptions.faction_of(request.card_data), BoardCardOptions.range_of(request.card_data))
	var reason: String = validate_request(request)
	if reason == "" and BoardContentPolicy.requires_board(request.card_data.card_play_validators, request.card_values):
		var action: BaseAction = ActionGenerator.create_actions(acting, request, [request.selected_target], [{Scripts.ACTION_CARD_PLAY: {}}], null)[0]
		if not Global.validate(request.card_data.card_play_validators, request.card_data, action):
			reason = _reject(request, BoardTargeting.REJECT_VALIDATORS)
	return reason

func _selection_board(request: CardPlayRequest, id: String) -> BoardData:
	var battlefield: CombatBattlefield = _battlefield()
	if battlefield == null:
		return null
	var actor: BaseCombatant = request.acting_unit if is_instance_valid(request.acting_unit) else UnitRegistry.get_hero()
	if id == "" and actor != null:
		id = actor.board_id
	return battlefield.get_board(id)

func _reject(request: CardPlayRequest, reason: String) -> String:
	request.card_values["board_rejection"] = reason
	return reason

func validate_request(request: CardPlayRequest) -> String:
	if request == null or not uses_board(request.card_data, request.card_values):
		return ""
	if _battlefield() == null:
		return _reject(request, "board_module_required")
	var lifetime_error: String = _bind_or_check_lifetime(request)
	if lifetime_error != "":
		return _reject(request, lifetime_error)
	var reason: String = _validate_geometry(request)
	return _reject(request, reason) if reason != "" else ""

## A queued request belongs to one module instance and one director generation.
func _bind_or_check_lifetime(request: CardPlayRequest) -> String:
	var combat: Node = combat_ref.get_ref() if combat_ref != null else null
	var director: CombatDirector = combat.get("combat_director") if is_instance_valid(combat) else null
	var module: Node = director.get("board_module") if director != null else null
	if module == null:
		return "board_module_required"
	var context: Dictionary = request.module_contexts.get("board", {})
	var identity: int = module.get_instance_id()
	var generation: int = director.get_generation()
	var module_generation: int = int(module.get("generation"))
	if context.has("module_instance_id") and (context.module_instance_id != identity or context.get("generation", -1) != generation or context.get("module_generation", -1) != module_generation):
		return "stale_board_context"
	context["module_instance_id"] = identity
	context["generation"] = generation
	context["module_generation"] = module_generation
	request.module_contexts["board"] = context
	return ""

func _validate_geometry(request: CardPlayRequest) -> String:
	var battlefield: CombatBattlefield = _battlefield()
	if battlefield == null or request == null or request.card_data == null:
		return ""
	var acting: BaseCombatant = request.acting_unit if is_instance_valid(request.acting_unit) else UnitRegistry.get_hero()
	if acting == null or battlefield.get_board_for_unit(acting) == null:
		return "off_board"
	var cell: Vector2i = request.selected_cell
	var board_id: String = request.selected_board_id
	if is_instance_valid(request.selected_target):
		# A selected unit may have moved since the request was queued. Follow its actual position.
		var current_board: BoardData = battlefield.get_board_for_unit(request.selected_target)
		if current_board == null:
			return "off_board"
		if board_id != current_board.board_id or current_board.get_unit_at(cell) != request.selected_target:
			cell = request.selected_target.board_anchor
		board_id = current_board.board_id
	if cell == BaseCombatant.BOARD_ANCHOR_NONE:
		var context_values: Dictionary = request.card_data.card_values.duplicate()
		context_values.merge(request.card_values, true)
		return BoardTargeting.check_action_geometry(battlefield.get_board_for_unit(acting), acting, acting.board_anchor, request.card_data.card_play_actions, context_values)
	if board_id == "":
		board_id = acting.board_id
	var board: BoardData = battlefield.get_board(board_id)
	if board == null:
		return "off_board"
	var reason: String = BoardTargeting.check_card_target(board, acting, request.card_data, cell, request.card_values)
	if reason == "":
		request.selected_board_id = board_id
		request.selected_cell = cell
		request.resolved_targets = BoardTargeting.resolve_targets(board, acting, cell, BoardCardOptions.shape_of(request.card_data), BoardCardOptions.faction_of(request.card_data), BoardCardOptions.range_of(request.card_data))
	return reason

func resolve_play(request: CardPlayRequest, default_actor: BaseCombatant) -> Dictionary:
	var result: Dictionary = super.resolve_play(request, default_actor)
	if uses_board(request.card_data, request.card_values):
		var move: Dictionary = _get_card_move_action_data(request)
		if not move.is_empty():
			# Action stack is LIFO: appended movement runs before the card's payload.
			result.actions_data.append(move)
	return result

func _get_card_move_action_data(card_play_request: CardPlayRequest) -> Dictionary:
	var card_data: CardData = card_play_request.card_data
	if card_data.card_move_distance <= 0 or _battlefield() == null:
		return {}
	var values: Dictionary = {"distance": card_data.card_move_distance, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}
	if BoardCardOptions.faction_of(card_data) == BoardTargeting.TARGET_FACTIONS.EMPTY_CELL:
		values["mode"] = ActionMoveUnit.MODE_TO_CELL
	else:
		values["mode"] = ActionMoveUnit.MODE_TOWARD
		values["reference"] = ActionMoveUnit.REFERENCE_SELECTED_TARGET
	return {Scripts.ACTION_MOVE_UNIT: values}

func selection_for_target(target: BaseCombatant) -> Dictionary:
	var battlefield: CombatBattlefield = _battlefield()
	if battlefield != null and is_instance_valid(target):
		var board: BoardData = battlefield.get_board_for_unit(target)
		if board != null:
			return {"target": target, "cell": target.board_anchor, "id": board.board_id}
	return super.selection_for_target(target)

func bind_hand(hand: Hand) -> void:
	unbind_hand()
	if _battlefield() != null:
		input = BoardCardInput.new(self, hand)
		input.bind()

func unbind_hand() -> void:
	if input != null:
		input.unbind()
	input = null

func handle_cell_clicked(hand: Hand, id: String, cell: Vector2i) -> void:
	if _battlefield() != null:
		BoardCardInput.click(self, hand, id, cell)

func handle_cell_hovered(hand: Hand, id: String, cell: Vector2i) -> void:
	if _battlefield() != null:
		BoardCardInput.hover(self, hand, id, cell)
