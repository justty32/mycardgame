## Runs one combat as an action timeline (CTB): pops the unit with the smallest next_action_tick,
## performs its action (player input or enemy intent) and re-queues it after a delay scaled by its
## speed (CombatRulesData). Replaces the AnimationPlayer-driven turn alternation of Combat.gd;
## Combat.gd keeps the HUD and ends combat from the death animation. Phase 2: the Director builds the
## board (BoardData) from the event's EncounterData (or one synthesized for legacy events), spawns
## wave 0 through the EnemyContainer unit layer, places units, runs movement (move points, paid
## movement, enemy intent movement) and keeps the ThreatPreview fresh.
## Child of RunScreen/Combat. Signals: player_turn_* = the hero's action (pre-draw / post-discard),
## enemy_turn_* = one enemy's action, unit_action_started/ended for every unit, combat_tick_advanced,
## timeline_changed. With equal speeds and the default rules the order equals the old turn flow.
extends Node
class_name CombatDirector

const GROUP_NAME: String = "combat_director"
const ANIMATION_ACTION_START: String = "start_turn"	# TurnOverlay fade on Combat's AnimationPlayer
const ANIMATION_ACTION_END: String = "end_turn"

## Emitted (deferred) when the acting player unit's action is finished by CombatEndAction.
signal player_action_finished

var timeline: CombatTimeline = null
var rules: CombatRulesData = null
## The unit whose action is in progress; null between actions and outside combat.
var acting_unit: BaseCombatant = null
var current_tick: int = 0
var is_running: bool = false
## Board of the current combat (null outside combat) and the encounter it was built from.
var board: BoardData = null
var encounter: EncounterData = null
var threat_preview: ThreatPreview = null

var _generation: int = 0	# invalidates suspended loops when combat/run ends
var _waiting_for_player: bool = false
var _player_finish_pending: bool = false
var _end_action_request: CombatEndAction = null
var _cards_played_this_action: Array[CardData] = []

func _ready() -> void:
	add_to_group(GROUP_NAME)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_run_ended)
	Signals.player_killed.connect(_on_player_killed)
	Signals.end_action_requested.connect(request_end_action)
	Signals.end_turn_requested.connect(request_end_action)	# legacy name, same request
	Signals.card_played.connect(_on_card_played)
	Signals.unit_spawned.connect(_on_unit_spawned)
	Signals.unit_removed.connect(_on_unit_removed)
	Signals.enemy_killed.connect(_on_enemy_killed)
	Signals.unit_moved.connect(_on_unit_moved)
	tree_exiting.connect(_stop)

#region Public queries
func has_living_opponents() -> bool:
	return not Global.get_alive_enemies().is_empty()

## Hero down (hero_down_ends_run) or no living opponents; also true once combat_ended fired.
func is_combat_over() -> bool:
	if not is_running:
		return true
	var hero: BaseCombatant = UnitRegistry.get_hero()
	if hero == null or (rules.hero_down_ends_run and not hero.is_alive()):
		return true
	return not has_living_opponents()

func is_player_action_pending() -> bool:
	return _waiting_for_player

## Upcoming actions for the UI: [{"unit", "tick"}], acting unit first.
func project_timeline(count: int) -> Array[Dictionary]:
	if timeline == null:
		return []
	return timeline.project(count, acting_unit)
#endregion

#region Combat start / stop
## Called by Combat when a combat event starts: builds the board, spawns wave 0 of the event's
## encounter and runs the whole combat loop. event_data null = the player's current event.
func begin_combat(event_data: EventData = null) -> void:
	_generation += 1
	var generation: int = _generation
	rules = Global.get_combat_rules()
	timeline = CombatTimeline.new(rules)
	threat_preview = ThreatPreview.new(self)
	current_tick = 0
	acting_unit = null
	_waiting_for_player = false
	_player_finish_pending = false
	_cards_played_this_action.clear()
	_reset_end_action()
	if event_data == null:
		event_data = Global.get_player_event_data()
	_setup_board(event_data)
	for unit: BaseCombatant in UnitRegistry.get_all_units():
		if not unit.is_alive():
			continue
		unit.reset_unit_combat_state()
		unit.next_action_tick = _spawn_delays.get(unit.unit_uid, 0)
		_assign_controller(unit)
		timeline.push(unit)
	_spawn_delays.clear()
	# enemies decide their first intent while waiting for their first action
	for enemy: Enemy in Global.get_alive_enemies():
		enemy.decide_next_intent()
	is_running = true
	refresh_threats()
	Signals.timeline_changed.emit()
	await _perform_initial_combat_actions(generation)
	if generation != _generation:
		return
	await _run_loop(generation)
	if generation == _generation:
		acting_unit = null

func _stop() -> void:
	_generation += 1
	is_running = false
	acting_unit = null
	board = null
	encounter = null
	threat_preview = null
	_reset_end_action()
	_cards_played_this_action.clear()
	if timeline != null:
		timeline.clear()
		timeline = null
	_player_finish_pending = false
	if _waiting_for_player:
		player_action_finished.emit()	# release the suspended loop; it returns on the generation check

func _on_combat_ended() -> void:
	_stop()

func _on_run_ended() -> void:
	_stop()

func _on_player_killed(_player: Player) -> void:
	_stop()

func _assign_controller(unit: BaseCombatant) -> void:
	if unit.controller != null:
		return
	if unit.faction == BaseCombatant.FACTIONS.PARTY:
		unit.controller = PlayerInputController.new()
	else:
		unit.controller = EnemyIntentController.new()

## Units spawned mid-combat (summons) enter the timeline as if they had just acted. Registration
## happens before Enemy.init(), so admission is deferred until the unit's data is set.
func _on_unit_spawned(unit: BaseCombatant) -> void:
	if not is_running or timeline == null:
		return
	_admit_spawned_unit.call_deferred(unit, _generation)

func _admit_spawned_unit(unit: BaseCombatant, generation: int) -> void:
	if generation != _generation or not is_running or timeline == null:
		return
	if not is_instance_valid(unit) or not unit.is_inside_tree() or unit == acting_unit or timeline.has(unit):
		return
	if not unit.is_alive():
		return
	if board != null and not board.has_unit(unit):
		place_unit_nearest(unit, _default_spawn_origin())
	unit.reset_unit_combat_state()
	_assign_controller(unit)
	unit.last_action_tick = current_tick
	unit.next_action_tick = current_tick + timeline.wait_for(rules.default_action_delay, unit.speed)
	timeline.push(unit)
	if unit is Enemy:
		(unit as Enemy).decide_next_intent()
	refresh_threats()
	Signals.timeline_changed.emit()

func _on_unit_removed(unit: BaseCombatant) -> void:
	if board != null:
		board.remove(unit)
	if timeline != null and timeline.has(unit):
		timeline.remove(unit)
		Signals.timeline_changed.emit()

## Dead enemies leave the board (their node stays until the death animation / combat end).
func _on_enemy_killed(enemy: Enemy) -> void:
	if board != null:
		board.remove(enemy)
		refresh_threats()

func _on_unit_moved(_unit: BaseCombatant, _from: Vector2i, _to: Vector2i) -> void:
	refresh_threats()

## Re-resolves enemy intents (ThreatPreview) and the hero's incoming damage display.
func refresh_threats() -> void:
	if not is_running or threat_preview == null:
		return
	threat_preview.refresh()
	var hero: Player = UnitRegistry.get_hero() as Player
	if hero != null:
		hero.update_incoming_damage_amount(false)
#endregion

#region Loop
func _run_loop(generation: int) -> void:
	while generation == _generation:
		if is_combat_over():
			break
		var unit: BaseCombatant = timeline.pop_next()
		if unit == null:
			break
		acting_unit = unit
		_cards_played_this_action.clear()
		await _advance_clock(unit.next_action_tick, generation)
		if _aborted(generation):
			return
		await _begin_action(unit, generation)
		if _aborted(generation):
			return
		if is_combat_over():
			break
		await unit.controller.decide(self, unit)
		if _aborted(generation):
			return
		if is_combat_over():
			break
		await _end_action(unit, generation)
		if _aborted(generation):
			return
		var delay: int = _compute_action_delay(unit)
		unit.last_action_tick = current_tick
		unit.next_action_tick = current_tick + timeline.wait_for(delay, unit.speed)
		if unit is Enemy and unit.is_alive():
			(unit as Enemy).decide_next_intent()	# decided on entering the wait (replaces the old player-turn-start cycle)
		if unit.is_alive():
			timeline.push(unit)
		acting_unit = null
		Signals.timeline_changed.emit()
	if generation == _generation:
		acting_unit = null

## True when the loop must return without touching state (combat/run ended or hero died).
func _aborted(generation: int) -> bool:
	if generation != _generation:
		return true
	var hero: BaseCombatant = UnitRegistry.get_hero()
	return hero == null or not hero.is_alive()

func _advance_clock(tick: int, generation: int) -> void:
	if tick <= current_tick:
		return
	var previous_tick: int = current_tick
	current_tick = tick
	timeline.current_tick = tick
	Signals.combat_tick_advanced.emit(previous_tick, tick)
	for unit: BaseCombatant in UnitRegistry.get_all_units():
		if unit.is_alive():
			unit.perform_tick_status_effects(previous_tick, tick)
	await _wait_actions(generation)

func _wait_actions(_generation: int) -> void:
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended

func _begin_action(unit: BaseCombatant, generation: int) -> void:
	if unit.faction == BaseCombatant.FACTIONS.PARTY:
		await _begin_party_action(unit, generation)
	else:
		await _begin_enemy_action(unit, generation)

func _end_action(unit: BaseCombatant, generation: int) -> void:
	if unit.faction == BaseCombatant.FACTIONS.PARTY:
		await _end_party_action(unit, generation)
	else:
		await _end_enemy_action(unit, generation)

## Delay of the action just performed: the largest card_action_delay played (party) or the
## intent's enemy_intent_action_delay; rules.default_action_delay when unspecified.
func _compute_action_delay(unit: BaseCombatant) -> int:
	var delay: int = -1
	if unit is Enemy:
		var intent: EnemyIntentData = (unit as Enemy).enemy_data.get_current_intent()
		if intent != null:
			delay = intent.enemy_intent_action_delay
	else:
		for card_data: CardData in _cards_played_this_action:
			delay = max(delay, card_data.card_action_delay)
	_cards_played_this_action.clear()
	if delay < 0:
		delay = rules.default_action_delay
	# paid movement adds to (not max with) the card / intent delay
	delay += max(0, unit.action_extra_delay)
	unit.action_extra_delay = 0
	return delay

func _on_card_played(card_play_request: CardPlayRequest) -> void:
	if is_running and card_play_request.card_data != null:
		_cards_played_this_action.append(card_play_request.card_data)
		# move-then-play rules: the first card play ends this action's movement
		if not rules.move_split_allowed and acting_unit != null and acting_unit.faction == BaseCombatant.FACTIONS.PARTY:
			acting_unit.move_points = 0
			acting_unit.paid_cells_this_action = max(acting_unit.paid_cells_this_action, rules.paid_move_max_cells)
#endregion

#region Party (hero) action
func _begin_party_action(unit: BaseCombatant, generation: int) -> void:
	HandManager.set_disable_hand(true)
	unit.reset_action_movement(rules.free_move_per_action)
	if unit.is_hero():
		StatsHandler.begin_hero_action()	# turn count = hero actions; before the overlay reads it
	await _play_combat_animation(ANIMATION_ACTION_START)
	if _aborted(generation):
		return
	# hero's action has started: legacy signal (StatsHandler turn count, artifacts, intent cycle listeners)
	Signals.player_turn_started.emit()
	ActionGenerator.generate_start_of_turn_energy_actions()
	if unit is Player:
		(unit as Player).update_incoming_damage_amount(true)
	if rules.reset_block_on_action_start:
		unit.generate_reset_block_action()
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DRAW_PLAYER_START_TURN)
	await _wait_actions(generation)
	if _aborted(generation):
		return
	ActionGenerator.generate_start_of_turn_draw_actions()
	await _wait_actions(generation)
	if _aborted(generation):
		return
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_DRAW_PLAYER_START_TURN)
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.UNIT_ACTION_START)
	await _wait_actions(generation)
	if _aborted(generation):
		return
	Signals.unit_action_started.emit(unit)
	HandManager.set_disable_hand(false)
	if HandManager.hand != null:
		HandManager.hand.update_hand_card_display()

## Awaited by PlayerInputController until CombatEndAction finishes the action.
func wait_for_player_action() -> void:
	if _player_finish_pending:
		_player_finish_pending = false
		return
	_waiting_for_player = true
	await player_action_finished
	_waiting_for_player = false

## Queues the end of the acting player unit's action; a higher immediacy replaces a waiting request.
func request_end_action(immediacy: int = CombatEndAction.END_ACTION_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS) -> void:
	if not is_running or acting_unit == null or acting_unit.faction != BaseCombatant.FACTIONS.PARTY:
		return
	if _end_action_request == null:
		_end_action_request = CombatEndAction.new(self, immediacy)
		_end_action_request.wait()
	elif immediacy > _end_action_request.immediacy:
		_end_action_request.disable()	# stop the old one working
		_end_action_request = CombatEndAction.new(self, immediacy)
		_end_action_request.wait()

## Called by CombatEndAction once its wait condition is met.
func finish_player_action(end_action: CombatEndAction = null) -> void:
	if end_action != null and end_action != _end_action_request:
		return	# a replaced request
	_end_action_request = null
	if not is_running:
		return
	if _waiting_for_player:
		player_action_finished.emit.call_deferred()
	else:
		_player_finish_pending = true

func _reset_end_action() -> void:
	if _end_action_request != null:
		_end_action_request.disable()
		_end_action_request = null

func _end_party_action(unit: BaseCombatant, generation: int) -> void:
	HandManager.set_disable_hand(true)
	_reset_end_action()
	await _play_combat_animation(ANIMATION_ACTION_END)
	if _aborted(generation):
		return
	Signals.player_turn_ended.emit()
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DISCARD_PLAYER_END_TURN)
	await _wait_actions(generation)
	if _aborted(generation):
		return
	if rules.discard_hand_on_action_end:
		await HandManager.perform_end_of_action_hand_actions()
		await _wait_actions(generation)
		if _aborted(generation):
			return
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_DISCARD_PLAYER_END_TURN)
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.UNIT_ACTION_END)
	await _wait_actions(generation)
	if _aborted(generation):
		return
	Signals.unit_action_ended.emit(unit)

## Plays an animation on Combat's AnimationPlayer (TurnOverlay) and waits for it. No-op headless-safe.
func _play_combat_animation(animation_name: String) -> void:
	var combat: Node = get_parent()
	if combat == null or not combat.has_node("CombatAnimation"):
		return
	var animation_player: AnimationPlayer = combat.get_node("CombatAnimation") as AnimationPlayer
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	animation_player.play(animation_name)
	await animation_player.animation_finished
#endregion

#region Enemy action
func _begin_enemy_action(unit: BaseCombatant, generation: int) -> void:
	unit.reset_action_movement(0)
	Signals.enemy_turn_started.emit()	# legacy signal: one enemy's action begins
	# both legacy pairs fire for this enemy's own action (old data stays valid)
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_ENEMY_TURN)
	await _wait_actions(generation)
	if _aborted(generation):
		return
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_ENEMY_INTENT)
	unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.UNIT_ACTION_START)
	await _wait_actions(generation)
	if _aborted(generation):
		return
	Signals.unit_action_started.emit(unit)

## Performs the enemy's current intent (EnemyIntentController): moves by the intent's move mode
## (IntentResolver), then performs the intent against what it hits from there. An attack that
## cannot reach its target is skipped and the intent is kept for the enemy's next action.
func perform_enemy_intent(enemy: Enemy) -> void:
	var generation: int = _generation
	if enemy == null or not enemy.is_alive():
		return
	var enemy_intent: EnemyIntentData = enemy.enemy_data.get_current_intent()
	var target: BaseCombatant = IntentResolver.choose_target(board, enemy, enemy_intent)
	var plan: Dictionary = IntentResolver.resolve(board, enemy, enemy_intent, target)
	var path: Array = plan.get("path", [])
	if board != null and not path.is_empty() and plan["move_cell"] != enemy.board_anchor:
		var move_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, [enemy], [{
			Scripts.ACTION_MOVE_UNIT: {"mode": ActionMoveUnit.MODE_TO_CELL, "target_cell": plan["move_cell"], "distance": len(path), "target_override": BaseAction.TARGET_OVERRIDES.PARENT}
		}], null)
		ActionHandler.add_actions(move_actions)
		await _wait_actions(generation)
		if _aborted(generation) or not enemy.is_alive():
			return
	var hit: Dictionary = IntentResolver.hits_from(board, enemy, enemy.board_anchor, enemy_intent, target)
	var can_hit: bool = hit["can_hit"]
	if enemy_intent != null and enemy_intent.enemy_intent_number_of_attacks > 0 and not can_hit:
		enemy.keep_intent_next_action = true
	var enemy_actions_data: Array[Dictionary] = enemy.build_intent_actions_data(enemy_intent, rules.reset_block_on_action_start, can_hit)
	# play intent sound if one exists and no attacks
	if enemy_intent != null and enemy_intent.enemy_intent_audio_path != "" and enemy_intent.enemy_intent_number_of_attacks == 0:
		ActionGenerator.generate_sound_action(enemy_intent.enemy_intent_audio_path, false)
	var targets: Array[BaseCombatant] = []
	if can_hit:
		targets.assign(hit["targets"])
	elif target != null:
		targets.append(target)
	var enemy_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, targets, enemy_actions_data, null)
	ActionHandler.add_actions(enemy_actions)
	await _wait_actions(generation)

func _end_enemy_action(unit: BaseCombatant, generation: int) -> void:
	if unit.is_alive():
		unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_ENEMY_INTENT)
		await _wait_actions(generation)
		if _aborted(generation):
			return
		unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_ENEMY_TURN)
		unit.perform_status_effect_process_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.UNIT_ACTION_END)
		await _wait_actions(generation)
		if _aborted(generation):
			return
	Signals.unit_action_ended.emit(unit)
	Signals.enemy_turn_ended.emit()
#endregion

#region First-action setup (moved from Combat.gd's first player turn)
func _perform_initial_combat_actions(generation: int) -> void:
	var hero: BaseCombatant = UnitRegistry.get_hero()
	var location_data: LocationData = Global.get_player_location_data()
	if location_data != null:
		var card_play_request: CardPlayRequest = HandManager.create_card_play_request(null, null, false, true)
		card_play_request.card_data = null
		card_play_request.selected_target = null
		# location initial actions
		var location_initial_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(hero, card_play_request, [], location_data.location_initial_combat_actions, null)
		ActionHandler.add_actions(location_initial_combat_actions)
		await _wait_actions(generation)
		if _aborted(generation):
			return
		# event initial actions
		var event_data: EventData = Global.get_player_event_data()
		if event_data != null:
			var event_initial_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(hero, card_play_request, [], event_data.event_initial_combat_actions, null)
			ActionHandler.add_actions(event_initial_combat_actions)
			await _wait_actions(generation)
			if _aborted(generation):
				return
	# combat start consumable actions
	for consumable_slot_index: int in Global.player_data.player_consumable_slot_count:
		var consumable_data: ConsumableData = Global.get_player_consumable_in_slot_index(consumable_slot_index)
		if consumable_data != null and len(consumable_data.consumable_initial_combat_actions) > 0:
			var consumable_request: CardPlayRequest = HandManager.create_card_play_request(null, null, false, true)
			var consumable_actions: Array[BaseAction] = ActionGenerator.create_actions(null, consumable_request, [], consumable_data.consumable_initial_combat_actions, null)
			ActionHandler.add_actions(consumable_actions)
	await _wait_actions(generation)
	if _aborted(generation):
		return
	# combat start card actions
	for card_data: CardData in HandManager.player_draw:
		var card_request: CardPlayRequest = HandManager.create_card_play_request(card_data, null, true, true)
		var card_play_actions: Array[BaseAction] = ActionGenerator.create_actions(hero, card_request, [], card_data.card_initial_combat_actions, null)
		ActionHandler.add_actions(card_play_actions)
	await _wait_actions(generation)
#endregion

#region Board (combat framework Phase 2)
var _spawn_delays: Dictionary[String, int] = {}	# unit_uid -> first next_action_tick (wave spawn delays)

func _get_unit_layer() -> Node:
	var combat: Node = get_parent()
	if combat == null or not combat.has_node("EnemyContainer"):
		return null
	return combat.get_node("EnemyContainer")

## Builds the board from the event's encounter, places the hero on the first deploy cell and
## spawns wave 0 (weighted picks in order with rng_enemy_spawning, like the legacy spawner).
func _setup_board(event_data: EventData) -> void:
	encounter = Global.get_event_encounter_data(event_data)
	board = BoardData.new(encounter.get_board_size(rules), rules)
	var deploy_cells: Array[Vector2i] = EncounterData.cells_from_json(encounter.encounter_deploy_cells)
	if deploy_cells.is_empty():
		deploy_cells = _default_deploy_cells()
	for cell: Vector2i in deploy_cells:
		if board.is_in_bounds(cell):
			board.get_cell(cell).is_deploy_zone = true
	var spawn_cells: Array[Vector2i] = EncounterData.cells_from_json(encounter.encounter_spawn_zone_cells)
	if spawn_cells.is_empty():
		for y: int in min(2, board.size.y):
			for x: int in board.size.x:
				spawn_cells.append(Vector2i(x, y))
	for cell: Vector2i in spawn_cells:
		if board.is_in_bounds(cell):
			board.get_cell(cell).is_spawn_zone = true
	for cell: Vector2i in EncounterData.cells_from_json(encounter.encounter_blocked_cells):
		board.set_blocked(cell, true)
	# party: the hero takes the first deploy cell
	var hero: BaseCombatant = UnitRegistry.get_hero()
	if hero != null:
		place_unit_nearest(hero, deploy_cells[0] if not deploy_cells.is_empty() else Vector2i(int(board.size.x / 2), board.size.y - 1))
	_spawn_delays.clear()
	var unit_layer: Node = _get_unit_layer()
	if unit_layer == null or encounter.encounter_waves.is_empty():
		return
	unit_layer.clear_enemies()
	var wave: EncounterWaveData = encounter.encounter_waves[0]
	var index: int = 0
	for unit_entry: Dictionary in wave.wave_units:
		var weights: Dictionary[Variant, int] = {}
		weights.assign(unit_entry.get("weights", {}))
		if weights.is_empty():
			index += 1
			continue
		var rng_enemy_spawning: RandomNumberGenerator = Global.player_data.get_player_rng("rng_enemy_spawning")
		var enemy_object_id: String = Random.get_weighted_selection(rng_enemy_spawning, weights)
		var enemy: Enemy = unit_layer.spawn_event_enemy(event_data, enemy_object_id, index)
		if enemy == null:
			break	# positional events stop when their slots run out (legacy)
		var cell: Vector2i = EncounterData.cell_from_json(unit_entry.get("cell", null))
		if not board.is_in_bounds(cell):
			cell = _default_spawn_origin()
		place_unit_nearest(enemy, cell)
		var spawn_delay: int = int(unit_entry.get("spawn_delay_ticks", 0))
		if spawn_delay > 0:
			_spawn_delays[enemy.unit_uid] = spawn_delay
		index += 1

## Default deploy zone: the two south rows, the hero's cell (bottom row center) first.
func _default_deploy_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [Vector2i(int(board.size.x / 2), board.size.y - 1)]
	for y: int in range(board.size.y - 1, max(-1, board.size.y - 3), -1):
		for x: int in board.size.x:
			if not cells.has(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells

func _default_spawn_origin() -> Vector2i:
	return Vector2i(int(board.size.x / 2), 0)

## Places a unit at cell, or the nearest empty anchor (NEAREST_EMPTY). false = the board is full.
func place_unit_nearest(unit: BaseCombatant, cell: Vector2i) -> bool:
	if board == null or unit == null:
		return false
	if board.place(unit, cell):
		return true
	var anchor: Vector2i = board.nearest_empty_anchor(unit, cell)
	if anchor == BaseCombatant.BOARD_ANCHOR_NONE:
		DebugLogger.log_error("CombatDirector: no free cell for unit {0}".format([unit.get_unit_display_name()]))
		return false
	return board.place(unit, anchor)

## Spawns an enemy mid-combat on the board (ActionSummonEnemies with spawn cells): placed at cell or
## the nearest empty cell; it enters the timeline as if it had just acted.
func spawn_enemy_at_cell(enemy_object_id: String, cell: Vector2i) -> Enemy:
	var unit_layer: Node = _get_unit_layer()
	if unit_layer == null or board == null:
		return null
	var enemy: Enemy = unit_layer.spawn_board_enemy(enemy_object_id)
	if enemy != null and not place_unit_nearest(enemy, cell):
		enemy.queue_free()
		return null
	return enemy

## Cells the acting party unit can still move this action: free move points plus paid cells.
func get_move_budget(unit: BaseCombatant) -> int:
	if unit == null or rules == null:
		return 0
	return unit.move_points + max(0, rules.paid_move_max_cells - unit.paid_cells_this_action)

## Player movement input (BoardView click on an empty cell): moves the acting party unit along the
## shortest path, spending free move points first, then paid cells (+extra_move_delay_per_cell each).
## false = not the player's action, busy, or the cell is not reachable within the budget.
func request_player_move(cell: Vector2i) -> bool:
	if not is_running or board == null or acting_unit == null or acting_unit.faction != BaseCombatant.FACTIONS.PARTY:
		return false
	if not _waiting_for_player or _end_action_request != null:
		return false
	if ActionHandler.actions_being_performed or HandManager.cards_being_played or not HandManager.card_play_queue.is_empty():
		return false
	var unit: BaseCombatant = acting_unit
	var budget: int = get_move_budget(unit)
	if budget <= 0:
		return false
	var path: Array[Vector2i] = board.find_path(unit, cell, budget)
	if path.is_empty():
		return false
	var move_actions: Array[BaseAction] = ActionGenerator.create_actions(unit, null, [unit], [{
		Scripts.ACTION_MOVE_UNIT: {"mode": ActionMoveUnit.MODE_TO_CELL, "target_cell": cell, "distance": len(path), "consumes_move_points": true, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}
	}], null)
	ActionHandler.add_actions(move_actions)
	return true
#endregion
