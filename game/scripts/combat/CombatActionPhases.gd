## Fixed phases of one unit action on the combat timeline (status-effect hooks, legacy turn
## signals, draw / discard, overlay animations), called by CombatDirector around the controller's
## decide(). Party units: begin = animation, player_turn_started, energy, block reset, PRE_DRAW,
## unit_action_started + field stay, draw, POST_DRAW + UNIT_ACTION_START; end = animation, player_turn_ended,
## PRE_DISCARD, discard, POST_DISCARD + UNIT_ACTION_END, unit_action_ended. Enemies: PRE_ENEMY_TURN,
## PRE_ENEMY_INTENT + UNIT_ACTION_START, unit_action_started / POST_ENEMY_INTENT, POST_ENEMY_TURN +
## UNIT_ACTION_END, unit_action_ended, enemy_turn_ended.
extends RefCounted
class_name CombatActionPhases

static func begin_party_action(director: CombatDirector, unit: BaseCombatant, generation: int) -> void:
	HandManager.set_disable_hand(true)
	unit.reset_action_movement(director.rules.free_move_per_action)
	if director.board_controller != null:
		director.board_controller.reset_action_state(unit)
	if unit.is_hero():
		StatsHandler.begin_hero_action()	# turn count = hero actions; before the overlay reads it
	await play_combat_animation(director, CombatDirector.ANIMATION_ACTION_START)
	if director.is_aborted(generation):
		return
	# hero's action has started: legacy signal (StatsHandler turn count, artifacts, intent cycle listeners)
	Signals.player_turn_started.emit()
	ActionGenerator.generate_start_of_turn_energy_actions()
	if unit is Player:
		(unit as Player).update_incoming_damage_amount(true)
	if director.rules.reset_block_on_action_start:
		unit.generate_reset_block_action()
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DRAW_PLAYER_START_TURN)
	await director.wait_actions(generation)
	if director.is_aborted(generation):
		return
	Signals.unit_action_started.emit(unit)
	var fields: FieldController = FieldController.get_for_unit(unit)
	if fields != null:
		fields.on_unit_action_started(unit)
	await director.wait_actions(generation)
	if director.is_aborted(generation) or not unit.is_alive():
		return
	ActionGenerator.generate_start_of_turn_draw_actions()
	await director.wait_actions(generation)
	if director.is_aborted(generation):
		return
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_DRAW_PLAYER_START_TURN)
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.UNIT_ACTION_START)
	await director.wait_actions(generation)
	if director.is_aborted(generation):
		return
	HandManager.set_disable_hand(false)
	if HandManager.hand != null:
		HandManager.hand.update_hand_card_display()

static func end_party_action(director: CombatDirector, unit: BaseCombatant, generation: int) -> void:
	HandManager.set_disable_hand(true)
	director.reset_end_action()
	await play_combat_animation(director, CombatDirector.ANIMATION_ACTION_END)
	if director.is_aborted(generation):
		return
	Signals.player_turn_ended.emit()
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DISCARD_PLAYER_END_TURN)
	await director.wait_actions(generation)
	if director.is_aborted(generation):
		return
	if director.rules.discard_hand_on_action_end:
		await HandManager.perform_end_of_action_hand_actions()
		await director.wait_actions(generation)
		if director.is_aborted(generation):
			return
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_DISCARD_PLAYER_END_TURN)
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.UNIT_ACTION_END)
	await director.wait_actions(generation)
	if director.is_aborted(generation):
		return
	Signals.unit_action_ended.emit(unit)

## Plays an animation on Combat's AnimationPlayer (TurnOverlay) and waits for it. No-op headless-safe.
static func play_combat_animation(director: CombatDirector, animation_name: String) -> void:
	var combat: Node = director.get_parent()
	if combat == null or not combat.has_node("CombatAnimation"):
		return
	var animation_player: AnimationPlayer = combat.get_node("CombatAnimation") as AnimationPlayer
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	animation_player.play(animation_name)
	await animation_player.animation_finished

static func begin_enemy_action(director: CombatDirector, unit: BaseCombatant, generation: int) -> void:
	unit.reset_action_movement(0)
	if director.board_controller != null:
		director.board_controller.reset_action_state(unit)
	Signals.enemy_turn_started.emit()	# legacy signal: one enemy's action begins
	# both legacy pairs fire for this enemy's own action (old data stays valid)
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_ENEMY_TURN)
	await director.wait_actions(generation)
	if director.is_aborted(generation):
		return
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_ENEMY_INTENT)
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.UNIT_ACTION_START)
	await director.wait_actions(generation)
	if director.is_aborted(generation):
		return
	Signals.unit_action_started.emit(unit)
	var fields: FieldController = FieldController.get_for_unit(unit)
	if fields != null:
		fields.on_unit_action_started(unit)
	await director.wait_actions(generation)

static func end_enemy_action(director: CombatDirector, unit: BaseCombatant, generation: int) -> void:
	if unit.is_alive():
		unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_ENEMY_INTENT)
		await director.wait_actions(generation)
		if director.is_aborted(generation):
			return
		unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_ENEMY_TURN)
		unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.UNIT_ACTION_END)
		await director.wait_actions(generation)
		if director.is_aborted(generation):
			return
	Signals.unit_action_ended.emit(unit)
	Signals.enemy_turn_ended.emit()
