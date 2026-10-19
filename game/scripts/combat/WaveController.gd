## Wave progression of one combat, owned by CombatDirector (combat framework Phase 3). Wave 0 starts
## with the combat; a wave is cleared once all its units entered (or were skipped) and no living
## non-minion enemy remains; then wave_cleared(i) fires, wave_on_cleared_actions run (parent = hero)
## and wave i + 1 is scheduled at the clear tick + its wave_enter_delay_ticks (UnitSpawner). At its
## start tick wave_started(i) fires and wave_on_start_actions run. The combat is won when the last
## wave is cleared (is_final_cleared); CombatDirector then ends it.
## Minions (EnemyData.enemy_is_minion) never block a clear: they stay on the board and keep acting
## into the next wave, and the combat ends with them alive (the legacy "only minions left" rule).
## A later wave of minions only is cleared as soon as its units have entered; wave 0 is checked on
## kills only, so a minions-only encounter still ends at the first kill (legacy).
extends RefCounted
class_name WaveController

var director: CombatDirector = null
var waves: Array[EncounterWaveData] = []
## Index of the latest wave that started (-1 before wave 0).
var current_wave: int = -1
## Number of waves whose wave_cleared fired (waves 0 .. cleared_count - 1).
var cleared_count: int = 0
var _check_queued: bool = false
var _victory_requested: bool = false

func _init(combat_director: CombatDirector, encounter: EncounterData) -> void:
	director = combat_director
	if encounter != null:
		waves = encounter.encounter_waves

func get_wave_count() -> int:
	return len(waves)

## Starts a wave: wave_started and its wave_on_start_actions.
func enter_wave(wave_index: int) -> void:
	if wave_index < 0 or wave_index >= len(waves):
		return
	current_wave = wave_index
	Signals.wave_started.emit(wave_index)
	_perform_actions(waves[wave_index].wave_on_start_actions)

## Whether more enemies are still to come: a later wave or units waiting to enter.
func has_more_waves() -> bool:
	if current_wave < len(waves) - 1:
		return true
	return director.unit_spawner != null and director.unit_spawner.has_pending()

## Whether a living enemy blocks the wave clear (minions do not).
static func has_living_blockers() -> bool:
	for enemy: Enemy in Global.get_alive_enemies():
		if enemy.enemy_data != null and not enemy.enemy_data.enemy_is_minion:
			return true
	return false

## The last wave started, all its units entered and no living non-minion enemy remains (victory).
## Evaluated from the current state, so it also holds after the director stopped.
func is_final_cleared() -> bool:
	if waves.is_empty() or current_wave != len(waves) - 1:
		return false
	if director.unit_spawner != null and director.unit_spawner.has_pending_units(current_wave):
		return false
	return not has_living_blockers()

## Clears the current wave when its clear condition holds: wave_cleared, its actions and the
## scheduling of the next wave. true = a wave was cleared by this call.
func check() -> bool:
	if current_wave < 0 or cleared_count > current_wave:
		return false
	if director.unit_spawner == null or director.unit_spawner.has_pending_units(current_wave):
		return false
	if has_living_blockers():
		return false
	var wave_index: int = current_wave
	cleared_count = wave_index + 1
	Signals.wave_cleared.emit(wave_index)
	_perform_actions(waves[wave_index].wave_on_cleared_actions)
	if wave_index + 1 < len(waves):
		director.unit_spawner.schedule_wave(wave_index + 1, director.current_tick + max(0, waves[wave_index + 1].wave_enter_delay_ticks))
	return true

func _perform_actions(actions_data: Array[Dictionary]) -> void:
	if actions_data.is_empty():
		return
	var hero: BaseCombatant = UnitRegistry.get_hero()
	var actions: Array[BaseAction] = ActionGenerator.create_actions(hero, null, [], actions_data, null)
	ActionHandler.add_actions(actions)

#region Director hooks
## Wave clear check after a kill, once the action queue settles (death actions such as summons
## count before the wave is judged cleared).
func queue_check() -> void:
	if _check_queued:
		return
	_check_queued = true
	_run_queued_check.call_deferred(director.get_generation())

func _run_queued_check(generation: int) -> void:
	if not is_instance_valid(director) or generation != director.get_generation():
		_check_queued = false
		return
	if ActionHandler.actions_being_performed:
		# no await: a pending coroutine would keep this RefCounted alive past the combat
		ActionHandler.actions_ended.connect(_run_queued_check.bind(generation), CONNECT_ONE_SHOT)
		return
	_check_queued = false
	if director.is_running:
		check()

## Victory after a kill: decided when a death animation ends (legacy timing) by the last wave being
## cleared; replaces Combat.gd's "only minions left" check. Also evaluated after the loop stopped.
func on_death_animation_finished() -> void:
	if director.is_running:
		check()
	if is_final_cleared():
		end_combat_victory()

## Ends the combat through Combat.end_combat() (event post-combat actions, combat_ended) once.
func end_combat_victory() -> void:
	if _victory_requested:
		return
	_victory_requested = true
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	var combat: Node = director.get_parent()
	if combat != null and combat.has_method("end_combat"):
		combat.end_combat()

## Enters pending wave entries due before the next timeline unit (ties: entries first), advancing
## the clock to each entry tick. A last wave cleared here without a kill (skipped units) ends the combat.
func enter_due_units(generation: int) -> void:
	while director.unit_spawner != null and director.unit_spawner.has_pending():
		var entry_tick: int = director.unit_spawner.next_pending_tick()
		var unit_tick: int = director.timeline.peek_next_tick()
		if unit_tick >= 0 and entry_tick > unit_tick:
			return
		await director.advance_clock(entry_tick, generation)
		if director.is_aborted(generation):
			return
		director.unit_spawner.enter_due(director.current_tick)
		await director.wait_actions(generation)
		if director.is_aborted(generation):
			return
		check()
		if is_final_cleared():
			end_combat_victory()
			return
#endregion
