extends RefCounted
## Explicit API fixtures; natural combat and rewards are exercised separately by the flow.
func run(c) -> bool:
	var attack: Node = c._find_hand_card("card_attack_basic")
	var block: Node = c._find_hand_card("card_block_basic")
	if not c._check(attack != null and block != null, "boardless card contract fixtures are naturally drawn"): return false
	var attack_data: CardData = attack.card_data
	var block_data: CardData = block.card_data
	var hp: int = c.enemy.get_combatant_health()
	var before: int = c.counts.played
	var energy: int = Global.player_data.player_energy
	# Selecting then cancelling does not move a card or reserve a fee.
	attack.card_selected.emit(attack)
	c._check(c.hand.current_selected_card == attack, "ordinary no-board attack waits for enemy selection")
	c.hand._on_background_button_up()
	c._check(c.hand.current_selected_card == null and HandManager.player_hand.has(attack_data) and Global.player_data.player_energy == energy, "selection cancellation leaves ordinary card and energy unchanged")
	# Actual handler barrier, then public queue reservation/refund. No board context exists.
	var action: BaseAction = load(get_script().resource_path.get_base_dir().path_join("boardless_delay.gd")).new()
	action.time_delay = 0.25
	ActionHandler.add_actions([action])
	var request: CardPlayRequest = HandManager.create_card_play_request(attack_data, c.enemy)
	request.card_destination_pile = HandManager.DISCARD_PILE
	HandManager.add_card_to_play_queue(request)
	c._check(HandManager.card_play_queue.has(request) and Global.player_data.player_energy == energy - 1 and HandManager.card_play_queue_reserved_energy_total == 1, "ordinary queued play reserves exactly one energy while handler is busy")
	HandManager.refund_card_queue()
	await c._wait(c._idle, "real handler barrier drains after queue refund")
	c._check(c.enemy.get_combatant_health() == hp and c.counts.played == before and HandManager.player_hand.has(attack_data) and Global.player_data.player_energy == energy and HandManager.card_play_queue_reserved_energy_total == 0, "refunded queued card performs no damage and restores all reserved energy")
	# Native duplicate interceptor exercises the same selected enemy twice for one fee.
	c.player.add_status_effect_charges("status_effect_duplicate_card_plays", 1, 1)
	if not await c._play("card_attack_basic", true): return false
	c._check(hp - c.enemy.get_combatant_health() == 40 and c.counts.played == before + 2, "native duplicate play applies two ordinary attacks to the selected enemy")
	c._check(HandManager.player_discard.count(attack_data) == 1 and Global.player_data.player_energy == energy - 1, "duplicated play spends one fee and leaves one discard card")
	c.player.add_status_effect_charges("status_effect_duplicate_card_plays", -1)
	if not await c._play("card_block_basic", false): return false
	c._check(c.player.get_block() == 10, "ordinary untargeted Block resolves to the hero without board geometry")
	energy = Global.player_data.player_energy
	var autoplay: CardPlayRequest = HandManager.create_card_play_request(block_data, null)
	autoplay.card_destination_pile = HandManager.DISCARD_PILE
	HandManager.add_card_to_play_queue(autoplay, false)
	await c._wait(c._idle, "ordinary auto-play from discard completes through the public queue")
	c._check(c.player.get_block() == 20 and Global.player_data.player_energy == energy and HandManager.player_discard.count(block_data) == 1, "free auto-play preserves energy and pile while executing ordinary Block")
	await _reject_spatial(c, attack_data)
	return true

func _reject_spatial(c, original: CardData) -> void:
	for variant: String in ["action", "geometry", "request_action"]:
		var data: CardData = original.duplicate(true)
		data.object_id = "boardless_reject_" + variant
		if variant == "action":
			data.card_play_actions.assign([{Scripts.ACTION_MOVE_UNIT: {"target_cell": [1, 1]}}])
		elif variant == "geometry":
			data.card_values["board"] = {"range": 1}
		else:
			data.card_play_actions.assign([{Scripts.ACTION_DISPLACE_UNIT: {"custom_key_names": {"mode": "hidden_mode"}}}])
		var cards: Array[CardData] = [data]
		HandManager.add_cards_to_hand(cards, 20)
		await c.process_frame
		var request: CardPlayRequest = HandManager.create_card_play_request(data, c.enemy)
		if variant == "request_action": request.card_values["hidden_mode"] = "PUSH"
		var energy: int = Global.player_data.player_energy
		var hp: int = c.enemy.get_combatant_health()
		var count: int = c.counts.played
		HandManager.add_card_to_play_queue(request)
		await c.process_frame
		c._check(request.card_values.get("play_rejection", "") == "board_module_required", "disabled module rejects spatial card before execution: " + variant)
		c._check(Global.player_data.player_energy == energy and HandManager.player_hand.has(data) and HandManager.card_play_queue.is_empty() and c.enemy.get_combatant_health() == hp and c.counts.played == count, "disabled spatial rejection preserves fee pile target and queue: " + variant)
		HandManager.move_card_to_pile(data, HandManager.HAND_PILE, HandManager.BANISH_PILE, HandManager.PILE_INSERTION_STRATEGIES.TOP, HandManager.get_hand_limit(), false, true)
		await c.process_frame
