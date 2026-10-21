extends RefCounted
## Declared cards exercise both native duplicate interceptors through real Hand requests.
func run(c) -> void:
	var field := FieldData.new("dual_duplicate_field")
	field.field_stack_policy = FieldData.STACK_POLICIES.STACK
	Global.register_rod(field)
	var create: CardData = Global.get_card_data("field_card_create").duplicate(true)
	create.object_id = "dual_duplicate_create"
	create.card_range = -1
	create.card_shape = BoardTargeting.TARGET_SHAPES.SINGLE
	create.card_energy_cost = 1
	create.card_values = {"field_id": field.object_id}
	Global.register_rod(create)
	c.player.add_status_effect_charges("status_effect_duplicate_card_plays", 1, 1)
	await _play(c, create.object_id, "enemy", Vector2i(0, 0), true)
	var instances: Array = c.enemy_board.get_fields(Vector2i(0, 0))
	c._check(instances.size() == 1 and instances[0].stacks == 2, "real DuplicateCardPlays preserves empty-cell field selection for both plays")
	c.player.add_status_effect_charges("status_effect_duplicate_card_plays", -1)
	FieldController.for_board(c.enemy_board).remove_fields([], field.object_id)

	var second: BaseCombatant
	for unit: BaseCombatant in c.enemy_board.get_units():
		if unit != c.enemy: second = unit; break
	if not c._check(second != null, "duplicate shape fixture retains its second live enemy"): return
	var original: Vector2i = second.board_anchor
	c._check(c.enemy_board.move(second, Vector2i(3, 0)), "duplicate shape fixture aligns two enemy footprints in one column")
	var attack: CardData = Global.get_card_data("dual_shape_2").duplicate(true)
	attack.object_id = "dual_duplicate_column"
	attack.card_type = CardData.CARD_TYPES.ATTACK
	attack.card_range = -1
	attack.card_values = {"damage": 2, "number_of_attacks": 1}
	attack.card_play_actions.assign([{Scripts.ACTION_ATTACK_GENERATOR: {"target_override": BaseAction.TARGET_OVERRIDES.RESOLVED_SHAPE, "time_delay": 0.0}}])
	Global.register_rod(attack)
	var protection_a: int = c.enemy.get_combatant_health() + c.enemy.get_block()
	var protection_b: int = second.get_combatant_health() + second.get_block()
	c.player.add_status_effect_charges("status_effect_duplicate_attacks", 1)
	await _play(c, attack.object_id, c.enemy.board_id, c.enemy.board_anchor, false)
	c._check(protection_a - c.enemy.get_combatant_health() - c.enemy.get_block() == 4 and protection_b - second.get_combatant_health() - second.get_block() == 4, "real DuplicateAttacks preserves column shape and damages both enemies twice")
	c._check(c.enemy_board.move(second, original), "duplicate fixture restores second enemy position")

func _play(c, id: String, board_id: String, cell: Vector2i, empty: bool) -> void:
	var card: Node = c._give(id)
	var data: CardData = card.card_data
	var seen: Array[CardPlayRequest] = []
	var listener: Callable = func(request):
		if request.card_data == data: seen.append(request)
	Signals.card_play_started.connect(listener)
	var energy: int = Global.player_data.player_energy
	var before: int = c.counts.played
	card.card_selected.emit(card)
	Signals.board_cell_clicked.emit(board_id, cell)
	await c._wait(func(): return c.counts.played >= before + 2 and c._idle(), "native duplicate completes two card plays: " + id)
	Signals.card_play_started.disconnect(listener)
	c._check(Global.player_data.player_energy == energy - 1 and HandManager.player_discard.count(data) == 1, "native spatial duplicate spends one fee and leaves one discard: " + id)
	if not c._check(seen.size() == 2, "native duplicate emits two observed requests: " + id): return
	var first: CardPlayRequest = seen[0]
	var duplicate: CardPlayRequest = seen[1]
	c._check(not first.is_duplicate_play and duplicate.is_duplicate_play and first.acting_unit == c.player and duplicate.acting_unit == first.acting_unit, "duplicate inherits actual actor identity: " + id)
	c._check(BoardCardOptions.selected_board_id(first) == board_id and BoardCardOptions.selected_board_id(duplicate) == board_id and BoardCardOptions.selected_cell(first) == cell and BoardCardOptions.selected_cell(duplicate) == cell and (not empty or duplicate.selected_target == null), "duplicate inherits board and cell even without selected unit: " + id)
	var a: Dictionary = first.module_contexts.get("board", {})
	var b: Dictionary = duplicate.module_contexts.get("board", {})
	c._check(not a.is_empty() and a == b and a.has("module_instance_id") and a.has("module_generation") and a.has("generation"), "duplicate keeps module instance module generation and Director generation: " + id)
	a["fixture_clone_marker"] = true
	c._check(not b.has("fixture_clone_marker"), "duplicate module context containers are independent: " + id)
	a.erase("fixture_clone_marker")
	if not empty:
		c._check(first.resolved_targets.size() == 2 and duplicate.resolved_targets == first.resolved_targets, "duplicate retains both resolved shape targets")
