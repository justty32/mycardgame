extends RefCounted
## Read-only pack Smoke checks; gameplay evidence is the separate PackScenario.
func check_loaded(data: Node) -> Dictionary:
	var result: Dictionary = {}
	var character: CharacterData = data.get_character_data("demo_character")
	result["demo_ character connects to its own player prototype"] = character != null and character.character_player_id == "demo_player"
	result["demo_ original starter deck contains ten cards"] = character != null and character.character_starting_card_object_ids.size() == 10
	var player: PlayerData = data.get_player_data_from_prototype("demo_player")
	result["demo_ player starts the authored Act"] = player != null and player.player_act_id == "demo_act" and player.player_act_max == 1
	var rules: CombatRulesData = data.get_combat_rules()
	result["demo_ rules enable actual dual boards and opportunity control"] = rules.board_mode == CombatRulesData.BOARD_MODES.DUAL and rules.zone_of_control == CombatRulesData.ZOC_MODES.OPPORTUNITY_ATTACK
	result["demo_ action budget is ten cards and two free move points"] = rules.draw_per_action == 10 and rules.free_move_per_action == 2
	var all_cards: bool = true
	for id: String in ["demo_strike", "demo_guard", "demo_cross_step", "demo_swap", "demo_field", "demo_push", "demo_pulse"]:
		var card: CardData = data.get_card_data(id)
		all_cards = all_cards and card != null and not card.card_play_actions.is_empty() and card.card_color_id == "demo_color"
	result["demo_ all seven cards own effect payloads and color references"] = all_cards
	var field: FieldData = data.get_field_data("demo_hazard")
	result["demo_ hazard declares enter stay and finite lifetime"] = field != null and field.field_duration_ticks == 300 and not field.field_on_enter_actions.is_empty() and not field.field_on_stay_actions.is_empty()
	var all_events: bool = true
	for id: String in ["demo_event_entry", "demo_event_field", "demo_event_final"]:
		all_events = all_events and data.get_event_data(id) != null
	result["demo_ all three authored combat events load"] = all_events
	return result
