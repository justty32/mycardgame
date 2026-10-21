extends RefCounted
## Real mounted lifecycle changes exercise queued requests through the normal public queue.

func run(c) -> void:
	await c._wait(c._idle, "adapter lifecycle starts idle")
	await _missing_membership(c)
	var positions: Array = []
	for unit: BaseCombatant in c.battlefield.get_units():
		positions.append({"unit": unit, "position": BoardPosition.from_unit(unit)})
	var module: BoardCombatModule = c.director.board_module
	var original_director_generation: int = c.director.get_generation()
	var queued: Dictionary = _reserve(c)
	var request: CardPlayRequest = queued.request
	var context_before: Dictionary = request.module_contexts["board"].duplicate(true)
	var clone := CardPlayRequest.new()
	clone.copy_selection_context_from(request)
	clone.module_contexts["board"]["cell"] = Vector2i(99, 99)
	clone.resolved_targets.clear()
	c._check(request.module_contexts["board"] == context_before and not request.resolved_targets.is_empty() and clone.acting_unit == request.acting_unit, "duplicate context isolates containers while retaining actor identity and source targets")
	var same_identity: int = module.get_instance_id()
	module.clear()
	c._check(module.setup(c.director, c.director.encounter), "same board module Node sets up again")
	_restore_positions(c, positions)
	c._check(module.get_instance_id() == same_identity and c.director.get_generation() == original_director_generation and module.generation != context_before.module_generation, "same Node reset changes only module generation")
	await _drain(c, queued, "stale_board_context")
	queued = _reserve(c)
	request = queued.request
	module.queue_free()
	await c.flow.process_frame
	await c.flow.process_frame
	c._check(c.director.board_module == null and c.director.battlefield == null and c.director.is_running, "queue_free detaches spatial module without stopping ordinary CTB")
	await _drain(c, queued, "board_module_required")
	# Recompose with the same scene API and rebuild geometry for following groups.
	c.combat._compose_board_module()
	var replacement: BoardCombatModule = c.combat.board_module
	c.director.combat_module = replacement
	c._check(replacement.setup(c.director, c.director.encounter), "replacement board module sets up")
	_restore_positions(c, positions)
	c._check(c.combat.card_play_adapter.validate_request(request) == "stale_board_context", "old request remains stale after a different module is mounted")
	c._check(c.director.get_generation() == original_director_generation, "spatial remount leaves the ordinary combat generation intact")
	await c.flow.process_frame
	await c.flow.process_frame
	c.director.refresh_threats()

func _reserve(c) -> Dictionary:
	var card := CardData.new("adapter_queued_spatial")
	card.card_name = "Queued Spatial Probe"
	card.card_color_id = "color_white"
	card.card_texture_path = "external/sprites/cards/white/card_white.png"
	card.card_description = "Spatial queue lifecycle probe."
	card.card_energy_cost = 1
	card.card_shape = BoardTargeting.TARGET_SHAPES.ROW
	card.card_play_actions.assign([{Scripts.ACTION_BLOCK: {"block": 5, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}}])
	HandManager.add_cards_to_hand(c._cards([card]))
	Global.player_data.player_energy = 10
	var request: CardPlayRequest = HandManager.create_card_play_request(card, c.enemy, true, true)
	request.acting_unit = c.player
	request.card_destination_pile = card.card_play_destination
	request.card_destination_strategy = card.card_play_destination_strategy
	# Hold only the consumer so the public queue performs real validation and fee reservation.
	HandManager.cards_being_played = true
	HandManager.add_card_to_play_queue(request, true, false)
	c._check(HandManager.card_play_queue.has(request) and Global.player_data.player_energy == 9 and HandManager.card_play_queue_reserved_energy_total == 1, "spatial request reserves exactly one energy before lifecycle changes")
	c._check(request.module_contexts.get("board", {}).has("module_generation"), "queued request binds module generation before payment")
	return {"request": request, "block": c.player.get_block()}

func _drain(c, queued: Dictionary, expected_reason: String) -> void:
	var plain := CardData.new("adapter_plain_guard")
	plain.card_name = "Ordinary Guard Probe"
	plain.card_color_id = "color_white"
	plain.card_texture_path = "external/sprites/cards/white/card_white.png"
	plain.card_description = "Ordinary card lifecycle probe."
	plain.card_energy_cost = 0
	plain.card_requires_target = false
	plain.card_play_actions.assign([{Scripts.ACTION_BLOCK: {"block": 3, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}}])
	HandManager.add_cards_to_hand(c._cards([plain]))
	var ordinary: CardPlayRequest = HandManager.create_card_play_request(plain, null, true, true)
	ordinary.card_destination_pile = plain.card_play_destination
	ordinary.card_destination_strategy = plain.card_play_destination_strategy
	HandManager.cards_being_played = false
	# Public enqueue starts the existing queue: reject/refund spatial, then play ordinary.
	HandManager.add_card_to_play_queue(ordinary, false, false)
	await c._wait(c._idle, "stale spatial request refunds and ordinary guard completes")
	var request: CardPlayRequest = queued.request
	c._check(request.rejection_reason == expected_reason and Global.player_data.player_energy == 10 and HandManager.card_play_queue_reserved_energy_total == 0, "lifecycle rejection refunds reserved energy exactly once: " + expected_reason)
	c._check(HandManager.player_hand.has(request.card_data) and c.player.get_block() == queued.block + 3, "rejected spatial card stays in hand while ordinary block executes once")
	c._check(ordinary.module_contexts.is_empty(), "ordinary queued card never acquires board context")
	HandManager.discard_cards(c._cards([request.card_data]), false)
	await c._wait(c._idle, "rejected lifecycle test card cleaned up")

func _restore_positions(c, positions: Array) -> void:
	c.battlefield = c.director.battlefield
	c.party_board = c.battlefield.get_board("party")
	c.enemy_board = c.battlefield.get_board("enemy")
	c.board = c.director.board
	for board: BoardData in c.battlefield.boards.values():
		for unit: BaseCombatant in board.get_units():
			board.remove(unit)
	for item: Dictionary in positions:
		if is_instance_valid(item.unit) and item.unit.is_alive():
			c._check(c.battlefield.place(item.unit, item.position), "restore real unit geometry after remount: " + item.unit.unit_uid)
	c.combat.sync_board_views()
	c.combat.actor_presentation.sync_positions(false)

func _missing_membership(c) -> void:
	var enemy: Enemy = c.enemy as Enemy
	var position := BoardPosition.from_unit(enemy)
	var board: BoardData = c.battlefield.get_board_for_unit(enemy)
	var data: EnemyData = enemy.enemy_data
	var keep: bool = enemy.keep_intent_next_action
	enemy.enemy_data = data.duplicate(true)
	var intent := EnemyIntentData.new("adapter_missing_membership")
	intent.enemy_intent_attack_damage = 5
	intent.enemy_intent_number_of_attacks = 1
	intent.enemy_intent_block = 3
	for key: String in enemy.enemy_data.enemy_intents:
		enemy.enemy_data.enemy_intents[key] = intent
	var health: int = c.player.get_combatant_health()
	var block: int = c.player.get_block()
	var enemy_block: int = enemy.get_block()
	board.remove(enemy)
	await EnemyIntentController.perform_intent(c.director, enemy)
	c._check(c.director.has_board_module() and c.player.get_combatant_health() == health and c.player.get_block() == block and enemy.get_block() == enemy_block, "mounted missing membership never falls back to an ordinary attack or block")
	enemy.enemy_data = data
	enemy.keep_intent_next_action = keep
	c._check(board.place(enemy, position.cell), "restore enemy membership after mounted refusal")
