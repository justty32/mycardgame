extends BaseCombatant
class_name Enemy

@onready var enemy_intent: HBoxContainer = $Visible/Intent

# icons used for displaying specific intent types
@onready var attacking_intent: TextureRect = $Visible/Intent/AttackingIntent
@onready var blocking_intent: TextureRect = $Visible/Intent/BlockingIntent
@onready var debuffing_intent: TextureRect = $Visible/Intent/DebuffingIntent
@onready var buffing_intent: TextureRect = $Visible/Intent/BuffingIntent
@onready var summoning_intent: TextureRect = $Visible/Intent/SummoningIntent

# maps the EnemyIntentData.enemy_intent_display_type to the texture to display
@onready var INTENT_DISPLAY_TYPE_TO_INTENT: Dictionary[int, TextureRect] = {
	EnemyIntentData.INTENT_DISPLAY_TYPES.ATTACKING: attacking_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.BLOCKING: blocking_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.DEBUFFING: debuffing_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.BUFFING: buffing_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.SUMMONING: summoning_intent,
}

@onready var enemy_intent_amount_label: Label = $Visible/Intent/IntentAmount

@onready var name_label = %NameLabel
@onready var death_animation_player: AnimationPlayer = $DeathAnimationPlayer

var enemy_data: EnemyData = null
var enemy_slot: int = 0 # the spawn slot the enemy is in

var enemy_intent_attack_damage: int = 0
var enemy_intent_number_of_attacks: int = 0

#region Board intent plan (combat framework Phase 2; set by ThreatPreview, see IntentResolver)
## Unit the current intent targets (null = the hero, legacy).
var intended_target: BaseCombatant = null
## Anchor the enemy plans to act from and the path to it ([] = stays).
var planned_move_cell: Vector2i = BOARD_ANCHOR_NONE
var planned_path: Array[Vector2i] = []
## false = the target is out of the intent's range / shape (intent shown dimmed).
var intent_can_hit: bool = true
## true = keep the current intent for the next action (its attack could not hit this action).
var keep_intent_next_action: bool = false
const INTENT_UNREACHABLE_ALPHA: float = 0.4
#endregion

func init(_enemy_data: EnemyData):
	enemy_data = _enemy_data
	base_speed = enemy_data.enemy_speed
	move_range = enemy_data.enemy_move_range
	footprint = Vector2i(max(1, enemy_data.enemy_footprint.x), max(1, enemy_data.enemy_footprint.y))
	ignores_occupancy = enemy_data.enemy_ignores_occupancy
	is_immovable = enemy_data.enemy_is_immovable
	ignores_zoc = ignores_occupancy if enemy_data.enemy_ignores_zoc < 0 else bool(enemy_data.enemy_ignores_zoc)
	opportunity_actions = enemy_data.enemy_opportunity_actions
	displace_resistance = max(0, enemy_data.enemy_displace_resistance)

	selection_button.mouse_entered.connect(_on_mouse_entered)
	selection_button.mouse_exited.connect(_on_mouse_exited)
	
	animated_sprite_2d.sprite_frames = get_animation_sprite_frames()
	animated_sprite_2d.play(AnimationData.ANIMATION_IDLE)
	
	# apply initial effects
	for status_effect_object_id in enemy_data.enemy_initial_status_effects.keys():
		var charge_amount: int = enemy_data.enemy_initial_status_effects[status_effect_object_id]
		add_status_effect_charges(status_effect_object_id, charge_amount)
	
	name_label.text = enemy_data.enemy_name
	
	# update_health_bar()
	layered_health_bar.init(enemy_data.enemy_health, enemy_data.enemy_health_max)
	
func _get_default_faction() -> int:
	return FACTIONS.ENEMY

func get_unit_display_name() -> String:
	if enemy_data != null and enemy_data.enemy_name != "":
		return enemy_data.enemy_name
	return name

func get_animation_data() -> AnimationData:
	var animation_data: AnimationData = Global.get_animation_data(enemy_data.enemy_animation_id)
	return animation_data

## Does damage to combatant and returns [unblocked damage dealt, damage to 0 (if enemy dies), overkill damage (if enemy dies)]
## eg 15 damage on 10 remaining health and 3 block will return [12, 10, 2].
## bypass_block = true will do damage directly to health.
func damage(_damage: int, bypass_block: bool = false) -> Array[int]:
	var bypassed_damage: int = _damage # raw unblocked damage
	var bypassed_damage_capped: int = 0 # damage done that does not factor in overkill damage
	var overkill_damage: int = 0 # damage done past 0
	
	if enemy_data.enemy_block > 0 and not bypass_block:
		if enemy_data.enemy_block > _damage:
			# damage less than block
			enemy_data.enemy_block -= _damage
			bypassed_damage = 0
			create_block_text()
			Signals.combatant_blocked.emit(self, _damage)
		else:
			# damage exceeds block
			bypassed_damage = _damage - enemy_data.enemy_block
			enemy_data.enemy_block = 0
			Signals.combatant_block_broken.emit(self)
	
	block.visible = enemy_data.enemy_block > 0
	block_amount.text = str(enemy_data.enemy_block)
	
	if bypassed_damage <= 0:
		return [0,0,0]
	
	create_damage_text(bypassed_damage)
	
	overkill_damage = max(0, bypassed_damage - enemy_data.enemy_health)
	bypassed_damage_capped = bypassed_damage - overkill_damage
	
	# check health to prevent multiple deaths
	if enemy_data.enemy_health > 0:
		# damage the enemy
		enemy_data.enemy_health = max(0, enemy_data.enemy_health - bypassed_damage)
		Signals.combatant_damaged.emit(self, bypassed_damage, bypassed_damage_capped, overkill_damage)
		
		# generate an interceptable action and intercept it to possibly change health
		if enemy_data.enemy_health <= 0:
			ActionGenerator.generate_combatant_death(self)
		
		# update healthbar and potentially kill enemy
		update_health_bar(true)
		if enemy_data.enemy_health <= 0:
			if not death_animation_player.is_playing():
				animated_sprite_2d.play(AnimationData.ANIMATION_DEATH)
				death_animation_player.play("Enemy/death")
				remove_from_group("enemies")
				Signals.enemy_killed.emit(self)
	
	return [bypassed_damage, bypassed_damage_capped, overkill_damage]

func set_block(amount: int) -> void:
	enemy_data.enemy_block = amount
	enemy_data.enemy_block = max(0, enemy_data.enemy_block)
	
	block.visible = enemy_data.enemy_block > 0
	block_amount.text = str(enemy_data.enemy_block)

func get_block() -> int:
	return enemy_data.enemy_block

func add_block(amount: int) -> void:
	set_block(enemy_data.enemy_block + amount)
	if amount > 0:
		create_block_fade()
		Signals.combatant_block_added.emit(self)

#region Health
func heal_percentage(percent: float):
	var percentage_health: int = int(ceil(float(enemy_data.enemy_health_max) * percent))
	add_health(percentage_health, 0)

func add_health(health_amount: int, health_amount_max: int = 0) -> void:
	set_health(enemy_data.enemy_health + health_amount, enemy_data.enemy_health_max + health_amount_max)

func set_health(health_amount: int, health_amount_max: int = enemy_data.enemy_health_max) -> void:
	var is_damaged: bool = health_amount < enemy_data.enemy_health
	
	enemy_data.enemy_health_max = max(1, enemy_data.enemy_health_max)
	enemy_data.enemy_health = clamp(0, health_amount, enemy_data.enemy_health_max)
	
	update_health_bar(is_damaged)

func update_health_bar(as_damage: bool = false) -> void:
	if as_damage:
		layered_health_bar.apply_damage(enemy_data.enemy_health, enemy_data.enemy_health_max, status_id_to_status_effects)
	else:
		layered_health_bar.update_health_layers(enemy_data.enemy_health, enemy_data.enemy_health_max, status_id_to_status_effects)

func get_combatant_health() -> int:
	return enemy_data.enemy_health

func get_combatant_health_max() -> int:
	return enemy_data.enemy_health_max

#endregion

## Changes the enemy's intent to the next intent in the random walk.
func cycle_enemy_intent():
	enemy_data.cycle_next_intent_state()
	update_enemy_intent()
	Signals.enemy_intent_changed.emit()

## Decides and displays the intent for the enemy's next action. Called by CombatDirector when the
## enemy enters the timeline (combat start / spawn) and after each of its actions.
## Intents needing an unmounted combat module are skipped (bounded by the intent count), so such
## an enemy keeps acting with its ordinary intents instead of stalling on a refused one.
func decide_next_intent() -> void:
	if keep_intent_next_action:
		keep_intent_next_action = false
		if EnemyIntentController.get_intent_module_error(self, enemy_data.get_current_intent()) == "":
			update_enemy_intent()
			Signals.enemy_intent_changed.emit()
			return
	cycle_enemy_intent()
	for _attempt: int in max(1, enemy_data.enemy_intents.size()):
		if EnemyIntentController.get_intent_module_error(self, enemy_data.get_current_intent()) == "":
			return
		cycle_enemy_intent()

## Stores the board plan of the current intent (ThreatPreview.refresh()).
func apply_intent_plan(plan: Dictionary) -> void:
	intended_target = plan.get("target", null)
	planned_move_cell = plan.get("move_cell", board_anchor)
	planned_path.assign(plan.get("path", []))
	intent_can_hit = bool(plan.get("can_hit", true))

## Action payload performing the given intent: reset block (optional), block, attacks and the
## intent's custom actions. NOTE: ActionHandler pops these in reverse order, so reset block runs first.
func build_intent_actions_data(enemy_intent: EnemyIntentData, include_reset_block: bool = true, include_attacks: bool = true) -> Array[Dictionary]:
	var enemy_actions_data: Array[Dictionary] = []
	var intent_attack_damage: int = 0
	var intent_number_of_attacks: int = 0
	var intent_block: int = 0
	var intent_audio_path: String = ""
	var intent_attack_impact_animation_id: String = ""
	if enemy_intent != null:
		# add custom actions
		enemy_actions_data.assign(enemy_intent.enemy_intent_custom_actions)
		# get attack data
		intent_attack_damage = enemy_intent.enemy_intent_attack_damage
		intent_number_of_attacks = enemy_intent.enemy_intent_number_of_attacks
		intent_block = enemy_intent.enemy_intent_block
		intent_audio_path = enemy_intent.enemy_intent_audio_path
		intent_attack_impact_animation_id = enemy_intent.enemy_intent_attack_impact_animation_id

	# add attacks
	if intent_number_of_attacks > 0 and include_attacks:
		enemy_actions_data.append(
		{
		Scripts.ACTION_ATTACK_GENERATOR:
			{
			"damage": intent_attack_damage,
			"number_of_attacks": intent_number_of_attacks,
			"impact_vfx_animation_id": intent_attack_impact_animation_id,
			"time_delay": EnemyData.ENEMY_ATTACK_DELAY,
			"audio_path": intent_audio_path
			}
		})

	# add block
	if intent_block > 0:
		enemy_actions_data.append(
			{
			Scripts.ACTION_BLOCK: {
				"block": intent_block,
				"target_override": BaseAction.TARGET_OVERRIDES.PARENT,
				"time_delay": 0.0,
				}
			}
	)

	# add reset block action (runs first on the stack)
	if include_reset_block:
		enemy_actions_data.append(
		{
		Scripts.ACTION_RESET_BLOCK:  {
			"target_override": BaseAction.TARGET_OVERRIDES.PARENT,
			"time_delay": 0.0
			}
		}
		)
	return enemy_actions_data

## Displays the enemy's intentions above them based on their current intent.
func update_enemy_intent():
	# get current intent's attack
	var current_enemy_intent: EnemyIntentData = enemy_data.get_current_intent()
	var attack_damage: int = 0
	var number_of_attacks: int = 0
	if current_enemy_intent == null:
		breakpoint
	else:
		attack_damage = current_enemy_intent.enemy_intent_attack_damage
		number_of_attacks = current_enemy_intent.enemy_intent_number_of_attacks
	
	# reset intent icon visibility
	for intent_icon: TextureRect in INTENT_DISPLAY_TYPE_TO_INTENT.values():
		intent_icon.hide()
	
	# show intent icons based on intent
	for display_intent_type: int in current_enemy_intent.enemy_intent_display_types:
		var intent_icon: TextureRect = INTENT_DISPLAY_TYPE_TO_INTENT.get(display_intent_type, null)
		if intent_icon == null:
			breakpoint
			DebugLogger.log_error("Enemey: No intent icon mapped to EnemyIntentData.INTENT_DISPLAY_TYPES of value {0}".format([display_intent_type]))
			continue
		else:
			intent_icon.show()
	
	# previews are computed against the intended target (the hero for legacy intents)
	var player: BaseCombatant = intended_target if (intended_target != null and is_instance_valid(intended_target)) else Global.get_player()
	enemy_intent.modulate.a = 1.0 if intent_can_hit else INTENT_UNREACHABLE_ALPHA
	
	### damage
	# intercept an attack action in preview mode
	var action_data: Array[Dictionary] = [{
			Scripts.ACTION_ATTACK: 
				{
				"damage": attack_damage,
				"target_override": BaseAction.TARGET_OVERRIDES.PLAYER
				}}]
	var generated_action: BaseAction = ActionGenerator.create_actions(self, null, [player], action_data, null)[0]
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = generated_action._intercept_action([player], true)
	
	if len(action_interceptor_processors) == 1:
		var action_interceptor_processor: ActionInterceptorProcessor = action_interceptor_processors[0]
		# get intercepted attack values
		enemy_intent_attack_damage = max(0, action_interceptor_processor.get_shadowed_action_values("damage", 0))

	
	### number of attacks
	# intercept an attack action generator in preview mode
	action_data = [{
		Scripts.ACTION_ATTACK_GENERATOR: 
			{
			"damage": attack_damage,
			"number_of_attacks": number_of_attacks,
			"target_override": BaseAction.TARGET_OVERRIDES.PLAYER
			}}]
	generated_action = ActionGenerator.create_actions(self, null, [player], action_data, null)[0]
	action_interceptor_processors = generated_action._intercept_action([player], true)
	
	if len(action_interceptor_processors) == 1:
		var action_interceptor_processor: ActionInterceptorProcessor = action_interceptor_processors[0]
		# get intercepted attack values
		enemy_intent_number_of_attacks = max(0, action_interceptor_processor.get_shadowed_action_values("number_of_attacks", 0))
	
	### Display intent
	enemy_intent_amount_label.visible = false
	if enemy_intent_attack_damage * enemy_intent_number_of_attacks > 0:
		enemy_intent_amount_label.visible = true
		enemy_intent_amount_label.text = str(enemy_intent_attack_damage)
		if enemy_intent_number_of_attacks > 1:
			enemy_intent_amount_label.text += " x " + str(enemy_intent_number_of_attacks)

func is_alive() -> bool:
	# enemy_data is null between add_child (unit registration) and init()
	return enemy_data != null and enemy_data.enemy_health > 0

func is_attacking() -> bool:
	return enemy_intent_number_of_attacks > 0

func _on_combat_started(_event_id: String):
	pass

func _on_combat_ended():
	queue_free()

func _on_selection_button_up():
	if is_alive():
		Signals.enemy_clicked.emit(self)

func _on_mouse_entered():
	Signals.enemy_hovered.emit(self)
	name_label.visible = true

func _on_mouse_exited():
	Signals.enemy_hovered.emit(null)
	name_label.visible = false

func _on_death_animtation_finished():
	# called from animation player
	Signals.enemy_death_animation_finished.emit(self)
