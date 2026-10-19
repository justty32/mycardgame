## Runs one combat as an action timeline (CTB): pops the unit with the smallest next_action_tick,
## performs its action (player input or enemy intent) and re-queues it after a delay scaled by its
## speed (CombatRulesData). Replaces the AnimationPlayer-driven turn alternation of Combat.gd;
## Combat.gd keeps the HUD. Components (one per combat): BoardController builds the board from the
## event's EncounterData (or one synthesized for legacy events) and runs movement; UnitSpawner
## spawns wave units / summons through the EnemyContainer unit layer and WaveController runs the wave
## flow (wave_started / wave_cleared, next-wave scheduling, victory when the last wave is cleared,
## which ends the combat through Combat.end_combat); CombatActionPhases holds the
## fixed begin / end phases of an action and CombatStartActions the combat-start actions; enemy
## intents (with intent movement) run in EnemyIntentController. The Director keeps the ThreatPreview fresh.
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
## Components of the current combat (null outside combat): board / movement and unit spawning.
var board_controller: BoardController = null
var unit_spawner: UnitSpawner = null
## Wave progression of the current / last combat (kept after the combat stops for the victory check).
var waves: WaveController = null
## Board of the current combat (null outside combat) and the encounter it was built from.
var board: BoardData:
	get:
		return board_controller.board if board_controller != null else null
var encounter: EncounterData:
	get:
		return board_controller.encounter if board_controller != null else null
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
	Signals.enemy_death_animation_finished.connect(_on_enemy_death_animation_finished)
	Signals.unit_moved.connect(_on_unit_moved)
	tree_exiting.connect(_stop)

#region Public queries
func has_living_opponents() -> bool:
	return not Global.get_alive_enemies().is_empty()

## Living opponents (minions included) or enemies still to come (a later wave, units waiting to
## enter). Global.are_remaining_enemies() delegates here during combat, so the ActionHandler /
## HandManager short-circuits do not fire between waves.
func has_remaining_opponents() -> bool:
	if has_living_opponents():
		return true
	return is_running and waves != null and waves.has_more_waves()

## Hero down (hero_down_ends_run) or no remaining opponents (has_remaining_opponents); also true once
## combat_ended fired. Victory itself is decided by WaveController.is_final_cleared.
func is_combat_over() -> bool:
	if not is_running:
		return true
	var hero: BaseCombatant = UnitRegistry.get_hero()
	if hero == null or (rules.hero_down_ends_run and not hero.is_alive()):
		return true
	return not has_remaining_opponents()

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
	reset_end_action()
	if event_data == null:
		event_data = Global.get_player_event_data()
	board_controller = BoardController.new(rules)
	unit_spawner = UnitSpawner.new(self)
	var encounter_data: EncounterData = Global.get_event_encounter_data(event_data)
	board_controller.setup(encounter_data)
	waves = WaveController.new(self, encounter_data)
	unit_spawner.spawn_first_wave(event_data, encounter_data)
	for unit: BaseCombatant in UnitRegistry.get_all_units():
		if not unit.is_alive():
			continue
		unit.reset_unit_combat_state()
		unit.next_action_tick = unit_spawner.first_action_tick(unit)
		_assign_controller(unit)
		timeline.push(unit)
	unit_spawner.clear()
	# enemies decide their first intent while waiting for their first action
	for enemy: Enemy in Global.get_alive_enemies():
		enemy.decide_next_intent()
	is_running = true
	refresh_threats()
	Signals.timeline_changed.emit()
	waves.enter_wave(0)
	await _wait_actions(generation)
	if _aborted(generation):
		return
	await CombatStartActions.perform(self, generation)
	if generation != _generation:
		return
	await _run_loop(generation)
	if generation == _generation:
		acting_unit = null

func _stop() -> void:
	_generation += 1
	is_running = false
	acting_unit = null
	if board_controller != null:
		board_controller.clear()
	board_controller = null
	unit_spawner = null
	threat_preview = null
	reset_end_action()
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
		board_controller.place_unit_nearest(unit, board_controller.default_spawn_origin())
	_admit(unit, current_tick + timeline.wait_for(rules.default_action_delay, unit.speed))

## A wave unit entering mid-combat (UnitSpawner): acts at the current tick.
func admit_wave_unit(unit: BaseCombatant) -> void:
	if is_running and timeline != null and unit.is_alive():
		_admit(unit, current_tick)

## Queues a unit entering mid-combat; enemies decide their intent now.
func _admit(unit: BaseCombatant, next_tick: int) -> void:
	unit.reset_unit_combat_state()
	_assign_controller(unit)
	unit.last_action_tick = current_tick
	unit.next_action_tick = next_tick
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
	if is_running and waves != null:
		waves.queue_check()

## Victory after a kill is decided when a death animation ends (legacy timing; WaveController).
func _on_enemy_death_animation_finished(_enemy: Enemy) -> void:
	if waves != null:
		waves.on_death_animation_finished()

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
		await waves.enter_due_units(generation)
		if _aborted(generation):
			return
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

## Generation of the running combat; components pass it back to is_aborted / wait_actions.
func get_generation() -> int:
	return _generation

## True when a suspended step must return without touching state (combat/run ended or hero died).
func is_aborted(generation: int) -> bool:
	return _aborted(generation)

## Awaits the ActionHandler queue (no-op when idle).
func wait_actions(generation: int) -> void:
	await _wait_actions(generation)

func _aborted(generation: int) -> bool:
	if generation != _generation:
		return true
	var hero: BaseCombatant = UnitRegistry.get_hero()
	return hero == null or not hero.is_alive()

## Advances the clock to tick (combat_tick_advanced, EVERY_N_TICKS statuses); no-op if not later.
func advance_clock(tick: int, generation: int) -> void:
	await _advance_clock(tick, generation)

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
		await CombatActionPhases.begin_party_action(self, unit, generation)
	else:
		await CombatActionPhases.begin_enemy_action(self, unit, generation)

func _end_action(unit: BaseCombatant, generation: int) -> void:
	if unit.faction == BaseCombatant.FACTIONS.PARTY:
		await CombatActionPhases.end_party_action(self, unit, generation)
	else:
		await CombatActionPhases.end_enemy_action(self, unit, generation)

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

## Cancels a waiting end-action request (action ended or combat stopped).
func reset_end_action() -> void:
	if _end_action_request != null:
		_end_action_request.disable()
		_end_action_request = null

#endregion

#region Enemy action
## Performs the enemy's current intent with intent movement (EnemyIntentController.perform_intent).
func perform_enemy_intent(enemy: Enemy) -> void:
	await EnemyIntentController.perform_intent(self, enemy)
#endregion

#region Board and spawning (delegated to BoardController / UnitSpawner)
## Places a unit at cell, or the nearest empty anchor (NEAREST_EMPTY). false = the board is full.
func place_unit_nearest(unit: BaseCombatant, cell: Vector2i) -> bool:
	return board_controller != null and board_controller.place_unit_nearest(unit, cell)

## Spawns an enemy mid-combat on the board (ActionSummonEnemies with spawn cells): placed at cell or
## the nearest empty cell; it enters the timeline as if it had just acted.
func spawn_enemy_at_cell(enemy_object_id: String, cell: Vector2i) -> Enemy:
	if unit_spawner == null:
		return null
	return unit_spawner.spawn_enemy_at_cell(enemy_object_id, cell)

## Cells the acting party unit can still move this action: free move points plus paid cells.
func get_move_budget(unit: BaseCombatant) -> int:
	if board_controller == null:
		return 0
	return board_controller.get_move_budget(unit)

## Player movement input (BoardView click on an empty cell): moves the acting party unit along the
## shortest path, spending free move points first, then paid cells (+extra_move_delay_per_cell each).
## false = not the player's action, busy, or the cell is not reachable within the budget.
func request_player_move(cell: Vector2i) -> bool:
	if not is_running or board_controller == null or acting_unit == null or acting_unit.faction != BaseCombatant.FACTIONS.PARTY:
		return false
	if not _waiting_for_player or _end_action_request != null:
		return false
	if ActionHandler.actions_being_performed or HandManager.cards_being_played or not HandManager.card_play_queue.is_empty():
		return false
	return board_controller.move_party_unit(acting_unit, cell)
#endregion
