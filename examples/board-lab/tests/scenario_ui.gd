extends RefCounted
var c

func new_run() -> bool:
	var main: Node = c.game_root.get_node("TitleScreen/MainMenu")
	var menu: Node = c.game_root.get_node("TitleScreen/NewRunMenu")
	if main.new_run_button.is_visible_in_tree(): main.new_run_button.button_up.emit()
	if not c.check(menu.is_visible_in_tree(), "character menu reached through normal New Run navigation"): return false
	var selection: Node
	for button: Node in menu.character_button_container.get_children():
		if button.character_object_id == "demo_character": selection = button
	if not c.check(selection != null, "pack character has a real selection button"): return false
	selection.button_up.emit()
	menu.seed_input.text = "20261020"
	menu.start_run_button.pressed.emit()
	if not await c.wait_for(func(): return Global.is_run, "New Run starts the selected pack character"): return false
	c.check(Global.player_data.player_character_object_id == "demo_character" and Global.player_data.player_act_id == "demo_act", "new run selects pack player and authored starting Act")
	var histogram: Dictionary = {}
	for card: CardData in Global.player_data.player_deck:
		histogram[card.object_id] = histogram.get(card.object_id, 0) + 1
	c.check(histogram == {"demo_strike": 3, "demo_guard": 2, "demo_cross_step": 1, "demo_swap": 1, "demo_field": 1, "demo_push": 1, "demo_pulse": 1}, "natural character deck has the exact ten authored cards")
	var options: Node = c.game_root.get_node("RunScreen/RunStartOptions")
	if not await c.wait_for(func(): return options.is_visible_in_tree() and options.starting_option_container.get_child_count() > 0, "authored start option is available"): return false
	var option: Node = options.starting_option_container.get_child(0)
	option.dialogue_option_clicked.emit(option)
	return await c.wait_for(func(): return c.map.is_visible_in_tree() and c.map.can_travel, "start option completes into adjacent-map travel")

func visit(event_id: String) -> bool:
	var location: LocationData
	for candidate: LocationData in Global.get_next_locations():
		if candidate.location_event_object_id == event_id: location = candidate
	if not c.check(location != null, "authored event is a natural adjacent destination: " + event_id): return false
	var button: Node
	for candidate: Node in c.map.location_container.get_children():
		if candidate.location_data == location: button = candidate
	if not c.check(button != null and c.map.can_travel, "map offers a real travel button: " + event_id): return false
	button.button_up.emit()
	if not await c.wait_for(c.ready_to_play, "normal map visit and initial hand settle: " + event_id): return false
	c.check(Global.player_data.player_location_id == location.location_id and c.events.back() == event_id, "map handler visits the authored event without replacement: " + event_id)
	c.check(c.director.battlefield.boards.size() == 2 and c.player.board_id == "party", "encounter creates real dual boards and party deployment")
	return true

func find_card(id: String) -> Node:
	for data: CardData in HandManager.player_hand:
		if data.object_id == id: return c.hand.card_data_to_hand_card.get(data)
	return null

func play(id: String, board_id: String = "", cell: Vector2i = Vector2i(-1, -1)) -> bool:
	var card: Node = find_card(id)
	if not c.check(card != null, "naturally drawn card available: " + id): return false
	var data: CardData = card.card_data
	var before: int = c.played
	var energy: int = Global.player_data.player_energy
	var cost: int = data.get_card_energy_cost()
	card.card_selected.emit(card)
	if not board_id.is_empty():
		if not c.check(c.hand.current_selected_card == card, "selected card awaits legal board target: " + id): return false
		Signals.board_cell_clicked.emit(board_id, cell)
	if not await c.wait_for(func(): return c.played > before and c.idle(), "real card action queue completes: " + id): return false
	c.check(Global.player_data.player_energy == energy - cost, "card spends its authored energy: " + id)
	return true

func walk(cell: Vector2i) -> bool:
	var board_id: String = c.player.board_id
	Signals.board_cell_clicked.emit(board_id, cell)
	return await c.wait_for(func(): return c.player.board_id == board_id and c.player.board_anchor == cell and c.idle(), "ordinary board selection moves to " + str(cell))

func end_turn() -> bool:
	var before: int = c.hero_actions
	c.combat.end_turn_button.button_up.emit()
	var summary: Node = c.game_root.get_node("RunScreen/RunSummaryOverlay")
	return await c.wait_for(func(): return summary.is_visible_in_tree() or (c.hero_actions > before and c.ready_to_play()), "real End Turn resolves enemy actions and next player action")

func rewards() -> bool:
	var overlay: Node = c.game_root.get_node("RunScreen/RewardOverlay")
	if not await c.wait_for(func(): return overlay.is_visible_in_tree() and c.idle(), "natural victory opens rewards"): return false
	var money: Node
	var draft: Node
	for button: Node in overlay.reward_container.get_children():
		var path: String = button.get_script().resource_path
		if path.ends_with("/MoneyRewardButton.gd"): money = button
		elif path.ends_with("/CardRewardButton.gd"): draft = button
	if not c.check(money != null and draft != null, "normal reward offers money and card draft"): return false
	var before_money: int = Global.player_data.player_money
	var amount: int = money.action_on_click.values.money_amount
	money.button_up.emit()
	if not await c.wait_for(func(): return c.idle() and Global.player_data.player_money == before_money + amount, "real reward button grants displayed money"): return false
	draft.button_up.emit()
	var picker: Node = c.game_root.get_node("RunScreen/CardDraftSelectionOverlay")
	if not await c.wait_for(func(): return picker.is_visible_in_tree() and picker.card_container.get_child_count() > 0, "real pack reward draft opens"): return false
	var selected: Node = picker.card_container.get_child(0)
	for candidate: Node in picker.card_container.get_children():
		if candidate.card_data.object_id == "demo_strike": selected = candidate
	var selected_id: String = selected.card_data.object_id
	var before_size: int = Global.player_data.player_deck.size()
	selected.card_selected.emit(selected)
	if not await c.wait_for(func(): return c.idle() and not picker.visible, "draft selection joins persistent deck"): return false
	c.check(selected_id.begins_with("demo_") and Global.player_data.player_deck.size() == before_size + 1 and Global.player_data.player_deck.back().object_id == selected_id, "reward card comes from authored pack and persists in deck")
	overlay.continue_button.button_up.emit()
	return await c.wait_for(func(): return c.map.is_visible_in_tree() and c.map.can_travel, "reward Continue returns to next map edge")

func fight() -> bool:
	for turn in 18:
		if not Global.is_player_in_combat(): return true
		if Global.get_alive_enemies().is_empty():
			return await c.wait_for(func(): return not Global.is_player_in_combat() and c.idle(), "last enemy death animation settles combat before further input")
		if not c.check(c.player.is_alive(), "campaign fighter remains alive"): return false
		var progressed: bool = true
		while progressed and c.ready_to_play():
			progressed = false
			for id: String in ["demo_pulse", "demo_strike"]:
				var card: Node = find_card(id)
				if card == null or card.card_data.get_card_energy_cost() > Global.player_data.player_energy: continue
				for enemy: BaseCombatant in Global.get_alive_enemies():
					var board: BoardData = c.director.battlefield.get_board_for_unit(enemy)
					var rejection: String = BoardTargeting.check_card_target(board, c.player, card.card_data, enemy.board_anchor)
					if not rejection.is_empty(): continue
					var hp: int = enemy.get_combatant_health()
					var block: int = enemy.get_block()
					if not await play(id, enemy.board_id, enemy.board_anchor): return false
					c.check(not is_instance_valid(enemy) or not enemy.is_alive() or enemy.get_combatant_health() + enemy.get_block() < hp + block, "real attack reduces enemy health or protection: " + id)
					progressed = true
					break
				if progressed: break
		if not Global.is_player_in_combat(): return true
		if Global.get_alive_enemies().is_empty():
			return await c.wait_for(func(): return not Global.is_player_in_combat() and c.idle(), "last enemy death animation settles combat before further input")
		if find_card("demo_guard") != null and Global.player_data.player_energy > 0:
			if not await play("demo_guard"): return false
		if not await end_turn(): return false
	return c.check(false, "campaign combat completed within eighteen real turns")
