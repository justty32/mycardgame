extends RefCounted
## Natural ordinary Strike through mounted board input; no card or state mutation.
func run(c, enemy: BaseCombatant) -> bool:
	var card: Node = c.ui.find_card("demo_strike")
	if not c.check(card != null, "ordinary Strike is naturally available for board-input translation"): return false
	var data: CardData = card.card_data
	var energy: int = Global.player_data.player_energy
	var hp: int = enemy.get_combatant_health()
	var played: int = c.played
	var hand_before: Array = HandManager.player_hand.duplicate()
	var draw_before: Array = HandManager.player_draw.duplicate()
	var discard_before: Array = HandManager.player_discard.duplicate()
	card.card_selected.emit(card)
	for selected: Dictionary in [{"id": "enemy", "cell": Vector2i(0, 0)}, {"id": c.player.board_id, "cell": c.player.board_anchor}]:
		var accepted: bool = c.hand.attempt_play_selected_card_at_cell(selected.cell, null, selected.id)
		await c.process_frame
		c.check(not accepted and c.hand.last_target_rejection == "no_valid_target" and c.hand.current_selected_card == card, "ordinary Strike rejects empty/friendly board cell while retaining selection")
		c.check(HandManager.card_play_queue.is_empty() and HandManager.player_hand == hand_before and HandManager.player_draw == draw_before and HandManager.player_discard == discard_before and Global.player_data.player_energy == energy and enemy.get_combatant_health() == hp and c.played == played, "ordinary invalid board selection preserves fee piles target and queue")
	var observed: Dictionary = {}
	var on_started: Callable = func(request):
		if request.card_data == data: observed["board_context"] = request.module_contexts.has("board")
	Signals.card_play_started.connect(on_started)
	var accepted: bool = c.hand.attempt_play_selected_card_at_cell(enemy.board_anchor, enemy, enemy.board_id)
	var completed: bool = await c.wait_for(func(): return c.played > played and c.idle(), "ordinary Strike accepts enemy cell and completes")
	Signals.card_play_started.disconnect(on_started)
	c.check(accepted and completed and hp - enemy.get_combatant_health() == 8 and Global.player_data.player_energy == energy - 1, "ordinary Strike enemy-cell selection deals authored eight damage for one energy")
	c.check(observed.has("board_context") and not observed.board_context, "ordinary successful request contains no board module context")
	return completed
