## Combat-start actions run once before the first action of a combat (moved from Combat.gd's first
## player turn): location / event initial actions, consumable initial actions and the draw pile's
## card_initial_combat_actions, parented to the hero. Called by CombatDirector.begin_combat.
extends RefCounted
class_name CombatStartActions

static func perform(director: CombatDirector, generation: int) -> void:
	var hero: BaseCombatant = UnitRegistry.get_hero()
	var location_data: LocationData = Global.get_player_location_data()
	if location_data != null:
		var card_play_request: CardPlayRequest = HandManager.create_card_play_request(null, null, false, true)
		card_play_request.card_data = null
		card_play_request.selected_target = null
		# location initial actions
		var location_initial_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(hero, card_play_request, [], location_data.location_initial_combat_actions, null)
		ActionHandler.add_actions(location_initial_combat_actions)
		await director.wait_actions(generation)
		if director.is_aborted(generation):
			return
		# event initial actions
		var event_data: EventData = Global.get_player_event_data()
		if event_data != null:
			var event_initial_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(hero, card_play_request, [], event_data.event_initial_combat_actions, null)
			ActionHandler.add_actions(event_initial_combat_actions)
			await director.wait_actions(generation)
			if director.is_aborted(generation):
				return
	# combat start consumable actions
	for consumable_slot_index: int in Global.player_data.player_consumable_slot_count:
		var consumable_data: ConsumableData = Global.get_player_consumable_in_slot_index(consumable_slot_index)
		if consumable_data != null and len(consumable_data.consumable_initial_combat_actions) > 0:
			var consumable_request: CardPlayRequest = HandManager.create_card_play_request(null, null, false, true)
			var consumable_actions: Array[BaseAction] = ActionGenerator.create_actions(null, consumable_request, [], consumable_data.consumable_initial_combat_actions, null)
			ActionHandler.add_actions(consumable_actions)
	await director.wait_actions(generation)
	if director.is_aborted(generation):
		return
	# combat start card actions
	for card_data: CardData in HandManager.player_draw:
		var card_request: CardPlayRequest = HandManager.create_card_play_request(card_data, null, true, true)
		var card_play_actions: Array[BaseAction] = ActionGenerator.create_actions(hero, card_request, [], card_data.card_initial_combat_actions, null)
		ActionHandler.add_actions(card_play_actions)
	await director.wait_actions(generation)
