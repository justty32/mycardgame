## Base abstract class for shared interface of player and enemies
extends Control
class_name BaseCombatant

@onready var block: Sprite2D = $Visible/Block
@onready var block_amount: Label = $Visible/Block/BlockAmount

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D
@onready var layered_health_bar: LayeredHealthBar = %LayeredHealthBar

@onready var fade_container = $Visible/FadeContainer
@onready var image_fade_container: Node2D = %ImageFadeContainer

@onready var selection_button: Button = %SelectionButton

@onready var status_container: GridContainer = $Visible/StatusContainer
@onready var custom_ui_container = $Visible/CustomUIContainer

@onready var speech_bubble: SpeechBubble = %SpeechBubble

var status_id_to_status_effects: Dictionary = {}	# maps status id to the array of ui element(s) it matches
var custom_ui_object_id_to_custom_ui: Dictionary = {} # maps a custom ui id to the ui component it matches. Duplicate registrations will be ignored

const BLOCK_TEXTURE: Texture = preload("res://icon.svg")

#region Unit identity (combat framework)
## Side a unit fights for. PARTY = the player's side, ENEMY = opponents, NEUTRAL = neither.
enum FACTIONS {PARTY, ENEMY, NEUTRAL}
## Speed every unit has unless data or interceptors change it (equal speeds = original turn order).
const DEFAULT_SPEED: int = 10
const BOARD_ANCHOR_NONE: Vector2i = Vector2i(-1, -1)

## Unique id within the process, assigned by UnitRegistry on _ready. Not saved.
var unit_uid: String = ""
var faction: int = FACTIONS.NEUTRAL
## Top-left board cell of the unit; BOARD_ANCHOR_NONE while not placed on a board.
var board_anchor: Vector2i = BOARD_ANCHOR_NONE
## Physical board identity; independent of faction, including after cross-board transfers.
var board_id: String = "shared"
## Immutable sprite origin captured before run animations can alter the local pose.
var presentation_sprite_origin: Vector2 = Vector2.ZERO
var presentation_sprite_offset: Vector2 = Vector2.ZERO
var presentation_sprite_origin_captured: bool = false
## Board cells covered by the unit.
var footprint: Vector2i = Vector2i(1, 1)
## Unmodified speed (from data); read the effective value through speed / get_speed().
var base_speed: int = DEFAULT_SPEED
## Effective speed. Read-only; subclasses override get_speed() to apply modifiers.
var speed: int:
	get:
		return get_speed()
var move_range: int = 1
var next_action_tick: int = 0
var last_action_tick: int = 0
## Number of own actions started this combat (unit_action_started with unit == self).
var action_count: int = 0
## Decides the unit's actions on the combat timeline; CombatDirector assigns a default
## (PlayerInputController for PARTY, EnemyIntentController otherwise) when null at combat start.
var controller: BaseUnitController = null

#region Board movement (combat framework Phase 2; combat only, not saved)
## Free move points left in the current action (reset to rules.free_move_per_action for party units).
var move_points: int = 0
## Paid cells used this action (each adds rules.extra_move_delay_per_cell to action_extra_delay).
var paid_cells_this_action: int = 0
## Cells moved this action by own movement and card movement (not forced displacement).
var cells_moved_this_action: int = 0
## Cells moved this action by forced displacement.
var cells_displaced_this_action: int = 0
## Delay added to this action's delay (paid movement); folded in and cleared by CombatDirector.
var action_extra_delay: int = 0
## Flying: passes over units and blocked cells, never stops on them.
var ignores_occupancy: bool = false
var ignores_zoc: bool = false
var opportunity_actions: Array[Dictionary] = []
var displace_resistance: int = 0
## Cannot be displaced (ActionDisplaceUnit).
var is_immovable: bool = false
#endregion
#endregion

func _ready():
	presentation_sprite_origin = animated_sprite_2d.position
	presentation_sprite_offset = animated_sprite_2d.offset
	presentation_sprite_origin_captured = true
	faction = _get_default_faction()
	UnitRegistry.register_unit(self)
	tree_exiting.connect(_on_unit_tree_exiting)
	
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.player_turn_started.connect(_on_player_turn_started)
	Signals.player_turn_ended.connect(_on_player_turn_ended)
	Signals.unit_action_started.connect(_on_unit_action_started)
	Signals.unit_action_ended.connect(_on_unit_action_ended)
	
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	
	selection_button.button_up.connect(_on_selection_button_up)

func _on_selection_button_up():
	breakpoint

#region Unit identity (combat framework)
## Override. Faction assigned on _ready.
func _get_default_faction() -> int:
	return FACTIONS.NEUTRAL

## Override. Whether this unit represents the run's main character (see UnitRegistry.get_hero()).
func is_hero() -> bool:
	return false

## Override to apply speed modifiers (e.g. status effects in later phases).
func get_speed() -> int:
	return base_speed

## Override. Short name for timeline / HUD display.
func get_unit_display_name() -> String:
	return name

func _on_unit_tree_exiting() -> void:
	UnitRegistry.unregister_unit(self)

func _on_unit_action_started(unit: BaseCombatant) -> void:
	if unit == self:
		action_count += 1
		_on_own_action_started()

func _on_unit_action_ended(unit: BaseCombatant) -> void:
	if unit == self:
		_on_own_action_ended()

## Override. Called when this unit's own action starts (after draw, before input).
func _on_own_action_started() -> void:
	pass

## Override. Called when this unit's own action ends (after discard).
func _on_own_action_ended() -> void:
	pass
#endregion

#region Animations

## Keep.
func play_animation(animation_name: String) -> void:
	animated_sprite_2d.play(animation_name)

## Keep
func get_animation_sprite_frames() -> SpriteFrames:
	var animation_data: AnimationData = get_animation_data()
	if animation_data == null:
		return animated_sprite_2d.sprite_frames
	return animation_data.animations

## Override. Gets the AnimationData of the combatant.
func get_animation_data() -> AnimationData:
	breakpoint
	return null

## Keep. Moves to next animation in the animation state machine. If none exist does nothing.
func play_next_animation() -> void:
	var animation_data: AnimationData = get_animation_data()
	if animation_data == null:
		return
	var current_animation_name: String = animated_sprite_2d.animation
	var next_animation_name: String = animation_data.get_next_animation_name(current_animation_name)
	if next_animation_name != AnimationData.ANIMATION_NONE:
		animated_sprite_2d.play(next_animation_name)

func _on_animation_finished() -> void:
	play_next_animation()
	
#endregion

#region Block
func set_block(_amount: int) -> void:
	# override
	breakpoint

func get_block() -> int:
	# override
	breakpoint
	return 0

func add_block(_amount: int) -> void:
	# override
	breakpoint

func generate_reset_block_action() -> void:
	# generates a reset block action for this combatant and adds it to the action stack
	var actions_data: Array[Dictionary] = [
		{
		Scripts.ACTION_RESET_BLOCK:  {
			"target_override": BaseAction.TARGET_OVERRIDES.PARENT,
			"time_delay": 0.0
			}
		}
	]
	
	var generated_actions: Array = ActionGenerator.create_actions(self, null, [self], actions_data, null)
	ActionHandler.add_actions(generated_actions)

func reset_block() -> void:
	set_block(0)
#endregion

#region Health
## Adds health and max health to the combatant
func add_health(_health_amount: int, _max_health_amount: int) -> void:
	pass

## Heals the combatant by a given percentage between 0.0 and 1.0.
func heal_percentage(_health_percent: float) -> void:
	breakpoint
	
func set_health(health_amount: int, health_amount_max: int = 1) -> void:
	breakpoint

func update_health_bar(_as_damage: bool = false) -> void:
	# as_damage will tell the healthbar to update as though the combatant took some kind of damage
	breakpoint
	
func get_combatant_health() -> int:
	breakpoint
	return 0

func get_combatant_health_max() -> int:
	breakpoint
	return 0

func is_alive() -> bool:
	# override this
	breakpoint
	return true

## Does damage to combatant and returns [unblocked damage dealt, overkill damage (if combatant dies)]
func damage(_damage: int, _bypass_block: bool = false) -> Array[int]:
	breakpoint
	return [0,0,0]
#endregion

#region Custom UI
func register_custom_ui(custom_ui_object_id: String) -> void:
	# generates a custom ui element and attaches it to the combatant if it doesn't already exist
	if not custom_ui_object_id_to_custom_ui.has(custom_ui_object_id):
		var custom_ui_data: CustomUIData = Global.get_custom_ui_data(custom_ui_object_id)
		if custom_ui_data != null:
			if custom_ui_data.custom_ui_asset_path != "":
				var custom_ui_asset: PackedScene = load(custom_ui_data.custom_ui_asset_path)
				var custom_ui: BaseCustomUI = custom_ui_asset.instantiate()
				custom_ui_container.add_child(custom_ui)
				custom_ui_object_id_to_custom_ui[custom_ui_object_id] = custom_ui
				custom_ui.init(custom_ui_object_id, self)

func unregister_custom_ui(custom_ui_object_id: String) -> void:
	var custom_ui: BaseCustomUI = custom_ui_object_id_to_custom_ui.get(custom_ui_object_id, null)
	if custom_ui != null:
		custom_ui.queue_free()
		custom_ui_object_id_to_custom_ui.erase(custom_ui_object_id)
		
func unregister_all_custom_ui() -> void:
	for custom_ui_object_id: String in custom_ui_object_id_to_custom_ui.keys().duplicate():
		unregister_custom_ui(custom_ui_object_id)
#endregion

#region Speech
func queue_speech_message(message_bbcode: String) -> void:
	speech_bubble.queue_message(message_bbcode)

#endregion

#region Fades

func create_block_text() -> void:
	var text_fade: TextFade = Scenes.TEXT_FADE.instantiate()
	fade_container.add_child(text_fade)
	text_fade.init("Blocked")

func create_damage_text(damage_amount: int) -> void:
	var text_fade: TextFade = Scenes.TEXT_FADE.instantiate()
	fade_container.add_child(text_fade)
	text_fade.init(str(damage_amount))

func create_block_fade() -> void:
	create_image_fade(BLOCK_TEXTURE)

func create_image_fade(texture: Texture) -> void:
	var image_fade: ImageFade = Scenes.IMAGE_FADE.instantiate()
	image_fade_container.add_child(image_fade)
	image_fade.init(texture)

## Spawns an animated effect over the combatant
## Used for things like imacts
func create_effect_animation(animation_id: String) -> void:
	var animation_data: AnimationData = Global.get_animation_data(animation_id)
	if animation_data == null:
		return
	
	var animated_combat_effect: AnimatedCombatEffect = Scenes.COMBAT_EFFECT_ANIMATION.instantiate()
	image_fade_container.add_child(animated_combat_effect)
	animated_combat_effect.init(animation_data)

#endregion

#region Statuses

## general method for adding status effects and charge amounts
## adds charges and secondary charges to ALL instances of a given status.
## If no status exists, create one and apply charges
## Will remove statuses that become zero'd out.
## NOTE: status_effect_secondary_charge_collision_strategy of the status determines how to
## handle secondary charges.
func add_status_effect_charges(status_effect_object_id: String, charge_amount: int, secondary_charge_amount: int = 0) -> void:

	if charge_amount == 0 and secondary_charge_amount == 0:
		return # charge applications of zero have no effect
	
	# get status data
	var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
	if status_effect_data == null:
		# status effect of given id does not exist
		DebugLogger.log_error("Status effect {0} does not exist".format([status_effect_object_id]))
		return
	
	#  get status effect ui elements corresponding to the status
	var status_effects: Array[StatusEffect] = []
	if status_id_to_status_effects.has(status_effect_object_id):
		status_effects = status_id_to_status_effects[status_effect_object_id]
	
	# create a new status if none exists
	if len(status_effects) == 0:
		var _status_effect: StatusEffect = _create_status_effect(status_effect_object_id)
		status_effects = status_id_to_status_effects[status_effect_object_id]
		
		# mutate secondary charges upon creation if KEEP strategy used
		var status_effect_secondary_charge_collision_strategy: int = _status_effect.status_effect_script.status_effect_data.status_effect_secondary_charge_collision_strategy
		if  status_effect_secondary_charge_collision_strategy == StatusEffectData.STATUS_EFFECT_SECONDARY_CHARGE_COLLISION_STRATEGIES.KEEP:
			var status_effect_script: BaseStatusEffect = _status_effect.status_effect_script
			status_effect_script.status_secondary_charges = secondary_charge_amount
	
	# iterate over all statuses and apply charges
	for status_effect in status_effects.duplicate():
		var status_effect_script: BaseStatusEffect = status_effect.status_effect_script
		
		# apply charges and secondary charges
		status_effect_script.add_status_charges(charge_amount)
		status_effect_script.add_status_secondary_charges(secondary_charge_amount)
		
		# delete the effect if zero charges
		if (status_effect_script.status_charges == 0):
			_remove_status_effect(status_effect)
		else:
			# update ui with charge count
			status_effect.update_status_charge_display()
	
	update_health_bar(false)
	
	Signals.enemy_intent_changed.emit()	# update enemy intent in case statuses affect them

func add_new_status_effect(status_effect_object_id: String, charge_amount: int, secondary_charge_amount: int = 0, custom_values: Dictionary = {}) -> void:
	# attempts to add an entirely new status effect with given charges
	# this is mainly useful for statuses that allow multiples
	# will fail if status does not allow multiples and one already exists
	# see add_status_effect_charges()
	var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
	
	if charge_amount == 0:
		return
	
	var status_effect: StatusEffect = _create_status_effect(status_effect_object_id)
	if status_effect != null:
		var status_effect_script: BaseStatusEffect = status_effect.status_effect_script
		
		# apply charges and secondary charges
		status_effect_script.add_status_charges(charge_amount)
		status_effect_script.status_secondary_charges += secondary_charge_amount
		
		# apply unique values beyond charges
		status_effect_script.status_custom_values = custom_values
		
		# delete the effect if zero charges
		if (status_effect_script.status_charges == 0):
			_remove_status_effect(status_effect)
		else:
			# update ui with charge count
			status_effect.update_status_charge_display()
	
	update_health_bar(false)
	
	Signals.enemy_intent_changed.emit()	# update enemy intent in case statuses affect them

func clear_all_status_effects():
	for status_effect_object_id in status_id_to_status_effects.keys().duplicate():
		var status_effects: Array[StatusEffect] = status_id_to_status_effects[status_effect_object_id] 
		for status_effect in status_effects.duplicate():
			_remove_status_effect(status_effect)
	
	status_id_to_status_effects.clear()
	update_health_bar(false)

## Decrements statuses by the decay rate and potentially removes them.
func _decay_status_effect(status_effect_object_id: String) -> void:
	var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
	if status_effect_data != null:
		# get the first status effect of the given type
		# and use it to determine the decay ratw of all the statuses
		var status_effects: Array[StatusEffect] = []
		if status_id_to_status_effects.has(status_effect_object_id):
			status_effects = status_id_to_status_effects[status_effect_object_id]
		if len(status_effects) > 0:
			var status_effect: StatusEffect = status_effects[0]
			var status_effect_script: BaseStatusEffect = status_effect.status_effect_script
			var decay_amount: int = status_effect_script.get_status_decay_amount()
			
			# generate an instant intercepted action to decay the status
			ActionGenerator.generate_decay_status_effect(self, status_effect_object_id, decay_amount)
			# 
			# add_status_effect_charges(status_effect_object_id, decay_amount, 0)

## DEPRECATED Left in for being potentially useful, but not used anywhere
func _decay_all_status_effects():
	for status_effect_object_id in status_id_to_status_effects.keys().duplicate():
		_decay_status_effect(status_effect_object_id)

func get_status_charges(status_effect_object_id: String) -> int:
	# returns the amount of status effect charges of a given effect
	# zero if no status applied, if multiple statuses returns absolute maximum
	var status_effects: Array = status_id_to_status_effects.get(status_effect_object_id, [])
	var absolute_maximum: int = 0
	for s_e in status_effects:
		var status_effect: StatusEffect = s_e
		if abs(status_effect.status_effect_script.status_charges) > abs(absolute_maximum):
			absolute_maximum = status_effect.status_effect_script.status_charges
	return absolute_maximum

func get_status_secondary_charges(status_effect_object_id: String) -> int:
	# returns the amount of secondary status effect charges of a given effect
	# zero if no status applied, if multiple statuses returns absolute maximum
	var status_effects: Array = status_id_to_status_effects.get(status_effect_object_id, [])
	var absolute_maximum: int = 0
	for s_e in status_effects:
		var status_effect: StatusEffect = s_e
		if abs(status_effect.status_effect_script.status_charges) > abs(absolute_maximum):
			absolute_maximum = status_effect.status_effect_script.status_secondary_charges
	return absolute_maximum

func _remove_status_effect(status_effect: StatusEffect) -> void:
	var status_effect_data: StatusEffectData = status_effect.status_effect_script.status_effect_data
	var status_effect_object_id: String = status_effect_data.object_id
	
	# get status list
	var status_effects: Array[StatusEffect] = status_id_to_status_effects[status_effect_object_id]
	# remove from lists
	status_effects.erase(status_effect)
	
	if len(status_effects) == 0:
		# remove the status keys if no other effects of that type
		status_id_to_status_effects.erase(status_effect_object_id)	
		# unregister action interceptors
		for interceptor_id in status_effect_data.status_effect_interceptor_ids:
			ActionHandler.unregister_action_interceptor(self, interceptor_id)
	
	status_effect.queue_free()

func _create_status_effect(status_effect_object_id: String) -> StatusEffect:
	# creates a status on the combatant and creates bindings and back references for it
	# does not allow duplicate statuses that do not allow multiples
	var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
	# check if existing status and if duplicates aren't allowed
	var status_exists: bool = len(status_id_to_status_effects.get(status_effect_object_id, [])) > 0
	if (not status_exists) or status_effect_data.status_effect_allows_multiples:
		# create the status
		var status_effect: StatusEffect = Scenes.STATUS_EFFECT.instantiate()
		var status_effect_script_asset: Resource = load(status_effect_data.status_effect_script_path)
		var status_effect_script: BaseStatusEffect = status_effect_script_asset.new()
		
		# set bindings for ui elements
		if status_id_to_status_effects.has(status_effect_object_id):
			status_id_to_status_effects[status_effect_object_id].append(status_effect)
		else:
			var statuses: Array[StatusEffect] = [status_effect] # ensures typed array passed in
			status_id_to_status_effects[status_effect_object_id] = statuses
		
		# initialize status effect
		status_effect.status_effect_script = status_effect_script
		status_container.add_child(status_effect)
		# initialize status effect script
		status_effect_script.init(status_effect_data, self)
		
		# register interceptors when creating first instance of effect
		if not status_exists:
			for interceptor_id in status_effect_data.status_effect_interceptor_ids:
				ActionHandler.register_action_interceptor(self, interceptor_id)
		
		return status_effect
	return null
#endregion

#region Turns/Combat

func _on_combat_started(_event_id: String):
	pass

func _on_combat_ended():
	pass

## Resets per-combat timeline counters. Called by subclasses' combat start handling.
func reset_unit_combat_state() -> void:
	next_action_tick = 0
	last_action_tick = 0
	action_count = 0
	reset_action_movement(0)

## Clears per-action movement counters and sets the free move points (start of each action).
func reset_action_movement(free_move_points: int) -> void:
	move_points = max(0, free_move_points)
	paid_cells_this_action = 0
	cells_moved_this_action = 0
	cells_displaced_this_action = 0
	action_extra_delay = 0

func _on_player_turn_started():
	pass

func _on_player_turn_ended():
	pass


## Processes and then decays all status effects belonging to a given process type (action phase)
func perform_status_effect_process_actions(status_effect_process_time: int = StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DRAW_PLAYER_START_TURN):
	var status_effect_ids: Array = _get_status_effects_with_process_time(status_id_to_status_effects.keys(), status_effect_process_time)
	_process_status_effects(status_effect_ids)

## Processes EVERY_N_TICKS statuses once per crossed multiple of status_effect_tick_interval
## between the two clock values. Called by CombatDirector when the combat clock advances.
func perform_tick_status_effects(previous_tick: int, current_tick: int) -> void:
	var status_effect_ids: Array = _get_status_effects_with_process_time(status_id_to_status_effects.keys(), StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.EVERY_N_TICKS)
	for status_effect_object_id in status_effect_ids:
		var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
		var interval: int = max(1, status_effect_data.status_effect_tick_interval)
		@warning_ignore("integer_division")
		var times: int = (current_tick / interval) - (previous_tick / interval)
		for _i: int in max(0, times):
			if not status_id_to_status_effects.has(status_effect_object_id):
				break	# decayed away
			_process_status_effects([status_effect_object_id])

## Performs and then decays the given statuses in priority order.
func _process_status_effects(status_effect_ids: Array) -> void:
	# sort the statuses by their process priority
	status_effect_ids.sort_custom(_sort_status_effect_priorities)

	for status_effect_object_id in status_effect_ids:
		if not status_id_to_status_effects.has(status_effect_object_id):
			continue
		var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)	
		# perform the status effect
		var status_effects: Array[StatusEffect] = status_id_to_status_effects[status_effect_object_id]
		for status_effect in status_effects:
			status_effect.status_effect_script.perform_status_effect_process_actions()
		
		# NOTE: Uncommenting this will make status related code more stable by forcing
		# all actions to process before decaying, but
		# doesn't look as good as statuses decaying instantly.
		#if ActionHandler.actions_being_performed:
			#await ActionHandler.actions_ended
		
		# decay all status effects of given type
		_decay_status_effect(status_effect_object_id)


## Helper method. Gets all status effects with a given status_effect_process_time.
func _get_status_effects_with_process_time(status_effect_object_ids: Array, status_effect_process_time: int = StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DRAW_PLAYER_START_TURN) -> Array[String]:
	var returned_status_effect_ids: Array[String] = []
	for status_effect_object_id: String in status_effect_object_ids:
		var status_effect_data: StatusEffectData = Global.get_status_effect_data(status_effect_object_id)
		if status_effect_data == null:
			continue
		if not status_effect_data.status_effect_action_process_times.has(status_effect_process_time):
			continue
		returned_status_effect_ids.append(status_effect_object_id)
		
	return returned_status_effect_ids

## Helper method. Custom sort method for sorting the priorities of a given list of status effects.
## Used to ensure status effects fire in a consistent order.
func _sort_status_effect_priorities(status_effect_object_id_1: String, status_effect_object_id_2: String) -> bool:
	var status_effect_data_1: StatusEffectData = Global.get_status_effect_data(status_effect_object_id_1)
	var status_effect_data_2: StatusEffectData = Global.get_status_effect_data(status_effect_object_id_2)
	if status_effect_data_1.status_effect_priority == status_effect_data_2.status_effect_priority:
		return status_effect_data_1.object_id > status_effect_data_2.object_id
	else:
		return status_effect_data_1.status_effect_priority > status_effect_data_2.status_effect_priority


#endregion
