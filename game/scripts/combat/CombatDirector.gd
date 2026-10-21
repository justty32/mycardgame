## Runs one combat as an action timeline (CTB): pops the unit with the smallest next_action_tick,
## performs its action (player input or enemy intent) and re-queues it after a delay scaled by its
## speed (CombatRulesData). Replaces the AnimationPlayer-driven turn alternation of Combat.gd;
## Combat.gd keeps the HUD and composes an optional CombatModule (e.g. the board). UnitSpawner
## spawns wave units / summons through the EnemyContainer unit layer and WaveController runs the wave
## flow (wave_started / wave_cleared, next-wave scheduling, victory when the last wave is cleared,
## which ends the combat through Combat.end_combat); CombatActionPhases holds the
## fixed begin / end phases of an action and CombatStartActions the combat-start actions; enemy
## intents run in EnemyIntentController, delegating only when a mounted module handles intents.
## The core never names a module class: modules attach through the CombatModule hooks.
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
## Optional scene-composed component (CombatModule); null for an ordinary combat.
var _module: CombatModule = null
var combat_module: CombatModule:
	get:
		if not is_instance_valid(_module) or _module.is_queued_for_deletion() or not _module.is_inside_tree():
			return null
		return _module
	set(value):
		_module = value
var unit_spawner: UnitSpawner = null
## Wave progression of the current / last combat (kept after the combat stops for the victory check).
var waves: WaveController = null
## Encounter and waves exist independently of any optional module.
var encounter: EncounterData = null

## Compatibility forwards (untyped, no module class dependency): the mounted board module and
## its current resources, or null. Board-specific work belongs to the module itself.
var board_module:
	get:
		return get_module(&"board")
var board_controller:
	get:
		return _module_property(&"board", &"board_controller")
var battlefield:
	get:
		return _module_property(&"board", &"battlefield")
var field_controller:
	get:
		return _module_property(&"board", &"field_controller")
var board:
	get:
		return _module_property(&"board", &"board")
var threat_preview:
	get:
		return _module_property(&"board", &"threat_preview")

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
	tree_exiting.connect(_stop)

#region Public queries
## The mounted module with this id, or null.
func get_module(module_id: StringName) -> CombatModule:
	var module: CombatModule = combat_module
	return module if module != null and module.get_module_id() == module_id else null

func has_module(module_id: StringName) -> bool:
	return get_module(module_id) != null

func has_board_module() -> bool:
	return has_module(&"board")

## Ids of the mounted modules (content requirements are checked against these).
func get_mounted_module_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var module: CombatModule = combat_module
	if module != null:
		ids.append(module.get_module_id())
	return ids

## Mounted module that places units (spawning, summons), or null.
func get_placement_module() -> CombatModule:
	var module: CombatModule = combat_module
	return module if module != null and module.places_units() else null

func _module_property(module_id: StringName, property: StringName) -> Variant:
	var module: CombatModule = get_module(module_id)
	return module.get(property) if module != null else null

## Module exit may arrive after another module was composed. Detach only that exact instance.
## Ordinary CTB and queued non-module work continue after a component is unmounted.
func detach_module(component: CombatModule) -> void:
	if is_instance_valid(_module) and _module == component:
		_module = null

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
## Called by Combat: sets up any mounted module, spawns wave 0 and runs the CTB loop.
## event_data null = the player's current event.
func begin_combat(event_data: EventData = null) -> void:
	_generation += 1
	var generation: int = _generation
	rules = Global.get_combat_rules()
	timeline = CombatTimeline.new(rules)
	current_tick = 0
	acting_unit = null
	_waiting_for_player = false
	_player_finish_pending = false
	_cards_played_this_action.clear()
	reset_end_action()
	if event_data == null:
		event_data = Global.get_player_event_data()
	encounter = Global.get_event_encounter_data(event_data)
	# The scene composition owns the optional component; the core never creates it.
	combat_module = get_parent().get("combat_module") as CombatModule
	if combat_module != null and not combat_module.setup(self, encounter):
		_stop()
		return
	unit_spawner = UnitSpawner.new(self)
	waves = WaveController.new(self, encounter)
	unit_spawner.spawn_first_wave(event_data, encounter)
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
	if combat_module != null:
		for unit: BaseCombatant in UnitRegistry.get_all_units():
			combat_module.on_unit_spawned(unit)
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

func _stop(preserve_presentation: bool = false) -> void:
	_generation += 1
	is_running = false
	acting_unit = null
	var component: CombatModule = combat_module
	if component == null and is_instance_valid(get_parent()):
		component = get_parent().get("combat_module") as CombatModule
	if component != null:
		component.clear(preserve_presentation)
	combat_module = null
	unit_spawner = null
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
	_stop(true)

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
	if combat_module != null and not combat_module.prepare_spawned_unit(unit):
		return
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
	if combat_module != null:
		combat_module.on_unit_spawned(unit)
	if unit is Enemy:
		(unit as Enemy).decide_next_intent()
	refresh_threats()
	Signals.timeline_changed.emit()

func _on_unit_removed(unit: BaseCombatant) -> void:
	if combat_module != null:
		combat_module.on_unit_removed(unit)
	if timeline != null and timeline.has(unit):
		timeline.remove(unit)
		Signals.timeline_changed.emit()

## Dead enemies leave the module's positions (their node stays until the death animation /
## combat end); on_unit_removed refreshes module threats, the hero display is refreshed here.
func _on_enemy_killed(enemy: Enemy) -> void:
	if combat_module != null:
		combat_module.on_unit_removed(enemy)
	_refresh_hero_incoming_damage()
	if is_running and waves != null:
		waves.queue_check()

## Victory after a kill is decided when a death animation ends (legacy timing; WaveController).
func _on_enemy_death_animation_finished(_enemy: Enemy) -> void:
	if waves != null:
		waves.on_death_animation_finished()

## Re-resolves module threat previews and the hero's incoming damage display.
func refresh_threats() -> void:
	if not is_running:
		return
	if combat_module != null:
		combat_module.refresh_threats()
	_refresh_hero_incoming_damage()

func _refresh_hero_incoming_damage() -> void:
	if not is_running:
		return
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
		if not is_instance_valid(unit) or not unit.is_alive():
			acting_unit = null
			continue
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
	if combat_module != null:
		combat_module.on_clock_advanced(previous_tick, tick)
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
		if combat_module != null:
			combat_module.on_card_played(acting_unit)
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

func resolve_module_action_targets(action: BaseAction, override: int, force_dead: bool) -> Array[BaseCombatant]:
	if combat_module != null:
		return combat_module.resolve_action_targets(action, override, force_dead)
	return []
#endregion

#region Spawning and input gating
## Spawns an enemy mid-combat at a module position (ActionSummonEnemies with spawn cells): placed at
## cell or the nearest free anchor; it enters the timeline as if it had just acted. null without a
## placement module, unit layer or free anchor.
func spawn_enemy_at_cell(enemy_object_id: String, cell: Vector2i, board_id: String = "") -> Enemy:
	if unit_spawner == null:
		return null
	return unit_spawner.spawn_enemy_at_cell(enemy_object_id, cell, board_id)

## Core input gating shared by optional module controls (e.g. board movement and undo).
func can_request_player_input() -> bool:
	if not is_running or not is_instance_valid(acting_unit) or acting_unit.faction != BaseCombatant.FACTIONS.PARTY:
		return false
	if not _waiting_for_player or _end_action_request != null:
		return false
	return not ActionHandler.actions_being_performed and not HandManager.cards_being_played and HandManager.card_play_queue.is_empty()
#endregion
