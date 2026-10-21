# maintains combat UI; the action timeline loop lives in CombatDirector (child node)
extends Control

@onready var money_label: Label = $%MoneyLabel
@onready var health_label: Label = $%HealthLabel

@onready var energy_count: Label = $Energy/EnergyCount
@onready var energy: TextureButton = $Energy
@onready var draw_count: Label = $DrawPile/DrawCount
@onready var discard_count: Label = $DiscardPile/DiscardCount
@onready var exhaust_count: Label = $ExhaustPile/ExhaustCount

@onready var deck_button: TextureButton = %DeckButton
@onready var draw_pile_button: TextureButton = %DrawPile
@onready var discard_pile_button: TextureButton = %DiscardPile
@onready var exhaust_pile_button: TextureButton = %ExhaustPile

@onready var card_selection_overlay = $%CardSelectionOverlay

@onready var combat_animation_player: AnimationPlayer = $CombatAnimation
@onready var enemy_container = $EnemyContainer
@onready var combat_director: CombatDirector = $CombatDirector
@onready var timeline_bar: Control = $TimelineBar
## Scene-level mount switch of the optional board module (also needs CombatRulesData.board_enabled).
@export var board_module_enabled: bool = true
## Optional board module script; composed only when the file exists, so the core runs without it.
const BOARD_MODULE_SCRIPT: String = "res://scripts/combat/board/BoardCombatModule.gd"
## The composed optional module (a CombatModule), or null for an ordinary combat.
var combat_module: CombatModule = null
var prepared_encounter: PreparedEncounter:
	get:
		return combat_director.prepared_encounter if is_instance_valid(combat_director) else null
## Core card policy used whenever no module supplies one.
var _core_card_play_adapter: CardPlayAdapter = CardPlayAdapter.new()
var card_play_adapter: CardPlayAdapter:
	get:
		var supplied: CardPlayAdapter = combat_module.get_card_play_adapter() if is_instance_valid(combat_module) else null
		return supplied if supplied != null else _core_card_play_adapter
## Compatibility forwards (untyped; no module class dependency).
var board_module:
	get:
		return combat_module if is_instance_valid(combat_module) and combat_module.get_module_id() == &"board" else null
var board_view:
	get:
		return _presentation_property(&"board_view")
var board_views:
	get:
		var views: Variant = _presentation_property(&"board_views")
		return views if views != null else {}
var actor_presentation:
	get:
		return _presentation_property(&"actor_presentation")
var undo_move_button:
	get:
		return _presentation_property(&"undo_move_button")

@onready var player = $Player
@onready var hand = $Hand
@onready var chest = $Chest
@onready var shop = $Shop

@onready var background_button: TextureButton = %BackgroundButton

@onready var end_turn_button: Button = $EndTurnButton

var _combat_ending: bool = false	# end_combat() runs once per combat

func _ready():
	Signals.player_money_changed.connect(_on_player_money_changed)
	Signals.player_health_changed.connect(_on_player_health_changed)

	Signals.enemy_killed.connect(_on_enemy_killed)

	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)

	Signals.unit_action_started.connect(_on_unit_action_started)
	Signals.unit_action_ended.connect(_on_unit_action_ended)
	Signals.end_action_requested.connect(_on_end_action_requested)
	Signals.end_turn_requested.connect(_on_end_action_requested)

	end_turn_button.button_up.connect(_on_end_turn_button_up)

	update_combat_display()
	player.update_player_display(Global.player_data)


	# pile buttons
	deck_button.button_up.connect(_on_deck_button_up)
	draw_pile_button.button_up.connect(_on_draw_pile_button_up)
	discard_pile_button.button_up.connect(_on_discard_pile_button_up)
	exhaust_pile_button.button_up.connect(_on_exhaust_pile_button_up)

	# updating pile counts when cards do things
	Signals.card_played.connect(_on_card_played)	# player is playing card
	Signals.card_drawn.connect(_on_card_drawn)
	Signals.card_deck_shuffled.connect(_on_card_deck_shuffled)
	Signals.card_discarded.connect(_on_card_discarded)
	Signals.card_exhausted.connect(_on_card_exhausted)

	Signals.energy_changed.connect(_on_energy_changed)
	Signals.card_queue_refunded.connect(_on_card_queue_refunded)

	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)

	Signals.map_location_selected.connect(_on_map_location_selected)

	# map back references
	HandManager.card_destination_to_ui_elements[HandManager.DECK] = deck_button
	HandManager.card_destination_to_ui_elements[HandManager.DRAW_PILE] = draw_pile_button
	HandManager.card_destination_to_ui_elements[HandManager.DISCARD_PILE] = discard_pile_button
	HandManager.card_destination_to_ui_elements[HandManager.EXHAUST_PILE] = exhaust_pile_button

func _on_map_location_selected(location_data: LocationData):
	# determine what to do when the player visits a new location
	var location_type: int = location_data.location_type

	chest.visible = false
	shop.visible = false

	set_combat_display_visibility(false)

	match location_type:
		LocationData.LOCATION_TYPES.COMBAT, LocationData.LOCATION_TYPES.MINIBOSS, LocationData.LOCATION_TYPES.BOSS:
			ActionGenerator.generate_combat_start("") # emit empty event to get location's combat event
		LocationData.LOCATION_TYPES.TREASURE:
			chest.visible = true
		LocationData.LOCATION_TYPES.SHOP:
			shop.visible = true

	_update_background()

	ActionGenerator.generate_location_music_action()

func update_combat_display():
	energy_count.text = str(Global.player_data.player_energy) + "/" + str(Global.player_data.player_energy_max)
	draw_count.text = str(len(HandManager.player_draw))
	discard_count.text = str(len(HandManager.player_discard))
	exhaust_count.text = str(len(HandManager.player_exhaust))
	_on_player_health_changed()
	_on_player_money_changed()

func _update_background() -> void:
	# set the background if possible
	var background_texture_path: String = ""

	var act_id: String = Global.player_data.player_act_id
	var act_data: ActData = Global.get_act_data(act_id)
	var location_data: LocationData = Global.get_player_location_data()

	# act background
	if act_data.act_background_texture_path != "":
		background_texture_path = act_data.act_background_texture_path
	# location background
	if location_data.location_background_texture_path != "":
		background_texture_path = location_data.location_background_texture_path
	# event background
	var location_event_object_id: String = location_data.get_location_event_object_id()
	if location_event_object_id != "":
		var event_data: EventData = Global.get_event_data(location_event_object_id)
		if event_data.event_background_texture_path != "":
			background_texture_path = event_data.event_background_texture_path

	if background_texture_path != "":
		background_button.texture_normal = FileLoader.load_texture(background_texture_path)


func set_combat_display_visibility(display_visibility: bool) -> void:
	energy.visible = display_visibility
	draw_pile_button.visible = display_visibility
	discard_pile_button.visible = display_visibility
	exhaust_pile_button.visible = display_visibility
	end_turn_button.visible = display_visibility
	timeline_bar.visible = display_visibility and combat_director.is_running

func _on_card_played(_card_play_request: CardPlayRequest):
	update_combat_display()

func _on_card_drawn(_card_data: CardData):
	update_combat_display()

func _on_card_deck_shuffled(_is_reshuffle: bool):
	update_combat_display()

func _on_card_discarded(_card_data: CardData, _is_manual_discard: bool):
	update_combat_display()

func _on_card_exhausted(_card_data: CardData):
	update_combat_display()

func _on_energy_changed():
	update_combat_display()

func _on_card_queue_refunded():
	update_combat_display()

func _on_player_money_changed(_delta: int = 0):
	money_label.text = "$%s" % Global.player_data.player_money

func _on_player_health_changed():
	health_label.text = "%s / %s" % [Global.player_data.player_health, Global.player_data.player_health_max]

### Deck Buttons

func _on_deck_button_up():
	card_selection_overlay.view_deck()
func _on_draw_pile_button_up():
	card_selection_overlay.view_draw_pile()
func _on_discard_pile_button_up():
	card_selection_overlay.view_discard()
func _on_exhaust_pile_button_up():
	card_selection_overlay.view_exhaust()

### Combat lifecycle

func _on_enemy_killed(enemy: Enemy):
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, [], enemy.enemy_data.enemy_actions_on_death, null)
	ActionHandler.add_actions(generated_actions)


func _on_combat_started(event_id: String):
	var current_event: EventData = null
	if event_id == "":
		# if no event is provided, it will be derived from the location
		var current_location: LocationData = Global.get_player_location_data()
		current_event = Global.get_player_event_data()
		current_location.location_visited = true
	else:
		current_event = Global.get_event_data(event_id)

	_combat_ending = false
	end_turn_button.disabled = true

	Global.player_data.player_energy = Global.player_data.player_energy_max
	set_combat_display_visibility(true)
	update_combat_display()

	# compose / drop the optional module, then the director sets it up, spawns the encounter's
	# units and runs the action timeline
	var prepared: PreparedEncounter = PreparedEncounter.prepare(current_event)
	_compose_board_module(prepared)
	combat_director.begin_prepared_combat(prepared)
	timeline_bar.visible = true

func _on_combat_ended():
	set_combat_display_visibility(false)

### Action handling (hero's own action; CombatDirector drives the timeline)

func _on_unit_action_started(unit: BaseCombatant) -> void:
	if unit.faction == BaseCombatant.FACTIONS.PARTY:
		end_turn_button.disabled = false
	update_combat_display()

func _on_unit_action_ended(_unit: BaseCombatant) -> void:
	end_turn_button.disabled = true
	update_combat_display()

func _on_end_turn_button_up():
	Signals.end_action_requested.emit(CombatEndAction.END_ACTION_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS)

func _on_end_action_requested(_immediacy: int):
	end_turn_button.disabled = true

func _on_run_started():
	visible = true
	_on_player_health_changed()
	_on_player_money_changed()

	# load energy
	var character_data: CharacterData = Global.get_player_character_data()
	if character_data != null:
		var color_data: ColorData = Global.get_color_data(character_data.character_color_id)
		if color_data != null:
			energy.texture_normal = FileLoader.load_texture(color_data.color_energy_icon_texture_path)

func _on_run_ended():
	visible = false

## Performs end of combat logic and signals end of combat. Runs once per combat. Called by the
## CombatDirector's WaveController when the last wave is cleared (after a death animation).
func end_combat() -> void:
	if _combat_ending:
		return
	_combat_ending = true
	var event_data: EventData = Global.get_player_event_data()
	if event_data != null:
		# perform event initial actions
		var event_post_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(player, null, [], event_data.event_post_combat_actions, null)
		ActionHandler.add_actions(event_post_combat_actions)

		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended

	Signals.combat_ended.emit()

## Scene composition owns the optional board feature; core combat only sees CombatModule.
## Loaded by path when present, so deleting the module's files leaves ordinary combat intact.
func _compose_board_module(prepared: PreparedEncounter = null) -> void:
	compose_combat_module(prepared)

func compose_combat_module(prepared: PreparedEncounter = null) -> void:
	var current: PreparedEncounter = prepared if prepared != null else prepared_encounter
	var enabled: bool = current != null and board_module_enabled and current.allows_board_module() and ResourceLoader.exists(BOARD_MODULE_SCRIPT)
	if enabled and not is_instance_valid(combat_module):
		var script: Script = load(BOARD_MODULE_SCRIPT) as Script
		combat_module = script.new() as CombatModule if script != null else null
		if combat_module != null:
			combat_module.name = "BoardCombatModule"
			add_child(combat_module)
	elif not enabled and is_instance_valid(combat_module):
		combat_module.clear()
		combat_module.queue_free()
		combat_module = null

func _presentation_property(property: StringName) -> Variant:
	if not is_instance_valid(combat_module):
		return null
	var presentation: Variant = combat_module.get(&"presentation")
	return presentation.get(property) if is_instance_valid(presentation) else null

## Compatibility query; board UI work belongs to the optional module's presentation.
func sync_board_views() -> void:
	var presentation: Variant = combat_module.get(&"presentation") if is_instance_valid(combat_module) else null
	if is_instance_valid(presentation):
		presentation.sync_board_views()

func _exit_tree() -> void:
	if is_instance_valid(combat_module):
		var adapter: CardPlayAdapter = combat_module.get_card_play_adapter()
		if adapter != null:
			adapter.unbind_hand()
		combat_module.clear()
	combat_module = null
