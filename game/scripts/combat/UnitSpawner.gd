## Unit spawning of one combat, owned by CombatDirector: spawns encounter wave units through the
## combat's unit layer (EnemyContainer) and places them on the board (BoardController), and spawns
## board summons (ActionSummonEnemies with spawn cells). A RefCounted created per combat.
## Wave 0 spawns when combat starts (units act at enter delay + stagger * index + spawn delay).
## Later waves are scheduled by WaveController: a wave-start entry at the wave's start tick and one
## entry per unit at start + stagger * index + spawn_delay_ticks; CombatDirector enters due entries
## before the timeline unit acting at or after that tick. An entering unit acts at its entry tick.
## Occupied entry cell (EncounterWaveData.wave_spawn_policy): NEAREST_EMPTY = nearest free anchor
## (full board: retry like WAIT_UNTIL_FREE); WAIT_UNTIL_FREE = retry every wave_spawn_retry_ticks,
## after wave_spawn_max_retries use NEAREST_EMPTY; FAIL_SKIP = skip. Skipped units are dropped and
## do not block the wave from clearing.
extends RefCounted
class_name UnitSpawner

const KIND_WAVE_START: String = "wave_start"
const KIND_UNIT: String = "unit"

var director: CombatDirector = null
## unit_uid -> first next_action_tick of a wave-0 unit (enter delay, stagger and spawn delay).
var spawn_delays: Dictionary[String, int] = {}
## Entries still to enter, ordered by tick then insertion:
## {"kind", "tick", "wave", "order"} plus for units {"enemy_object_id", "cell", "retries"}.
var pending: Array[Dictionary] = []
## Wave units dropped by their spawn policy (for tests / UI).
var skipped_units: Array[Dictionary] = []
var _next_order: int = 0

func _init(combat_director: CombatDirector) -> void:
	director = combat_director

func get_unit_layer() -> Node:
	var combat: Node = director.get_parent() if director != null else null
	if combat == null or not combat.has_node("EnemyContainer"):
		return null
	return combat.get_node("EnemyContainer")

## Tick of a wave-0 unit's first action (0 without delays).
func first_action_tick(unit: BaseCombatant) -> int:
	return spawn_delays.get(unit.unit_uid, 0)

func clear() -> void:
	spawn_delays.clear()

#region Wave 0 (combat start)
## Spawns wave 0 of the encounter: weighted picks in order with rng_enemy_spawning (like the legacy
## spawner), in the event's placement mode, placed on their cell by the wave's spawn policy.
func spawn_first_wave(event_data: EventData, encounter: EncounterData) -> void:
	spawn_delays.clear()
	var unit_layer: Node = get_unit_layer()
	if unit_layer == null or encounter.encounter_waves.is_empty():
		return
	unit_layer.clear_enemies()
	var board_controller: BoardController = director.board_controller
	var wave: EncounterWaveData = encounter.encounter_waves[0]
	var index: int = 0
	for unit_entry: Dictionary in wave.wave_units:
		var enemy_object_id: String = _pick_enemy(unit_entry)
		if enemy_object_id == "":
			index += 1
			continue
		var enemy: Enemy = unit_layer.spawn_event_enemy(event_data, enemy_object_id, index)
		if enemy == null:
			break	# positional events stop when their slots run out (legacy)
		var cell: Vector2i = _entry_cell(unit_entry)
		var tick: int = _entry_tick(wave, 0, index, unit_entry)
		if board_controller.board.can_stand(enemy, cell) or wave.wave_spawn_policy == EncounterWaveData.SPAWN_POLICIES.NEAREST_EMPTY:
			board_controller.place_unit_nearest(enemy, cell)
			if tick > 0:
				spawn_delays[enemy.unit_uid] = tick
		else:
			_discard(enemy)
			var entry: Dictionary = _unit_entry(0, tick, enemy_object_id, cell)
			if wave.wave_spawn_policy == EncounterWaveData.SPAWN_POLICIES.WAIT_UNTIL_FREE:
				_retry(entry, wave)
			else:
				_skip(entry, "cell occupied (FAIL_SKIP)")
		index += 1

## Removes a just-spawned unit at once (it unregisters before the timeline is filled).
func _discard(enemy: Enemy) -> void:
	if enemy.get_parent() != null:
		enemy.get_parent().remove_child(enemy)
	enemy.queue_free()
#endregion

#region Later waves
## Schedules wave wave_index starting at start_tick: its wave-start entry and every unit entry
## (enemy ids picked now, in entry order, with rng_enemy_spawning).
func schedule_wave(wave_index: int, start_tick: int) -> void:
	var wave: EncounterWaveData = director.encounter.encounter_waves[wave_index]
	_insert({"kind": KIND_WAVE_START, "tick": start_tick, "wave": wave_index})
	var index: int = 0
	for unit_entry: Dictionary in wave.wave_units:
		var enemy_object_id: String = _pick_enemy(unit_entry)
		if enemy_object_id != "":
			_insert(_unit_entry(wave_index, start_tick + max(0, wave.wave_stagger_ticks) * index + max(0, int(unit_entry.get("spawn_delay_ticks", 0))), enemy_object_id, _entry_cell(unit_entry)))
		index += 1

func has_pending() -> bool:
	return not pending.is_empty()

## Whether units of the wave still have to enter (or retry).
func has_pending_units(wave_index: int) -> bool:
	for entry: Dictionary in pending:
		if entry["kind"] == KIND_UNIT and entry["wave"] == wave_index:
			return true
	return false

## Tick of the earliest pending entry; -1 when none.
func next_pending_tick() -> int:
	return pending[0]["tick"] if not pending.is_empty() else -1

## Enters every entry due at or before tick (wave starts and units, in order).
func enter_due(tick: int) -> void:
	while not pending.is_empty() and pending[0]["tick"] <= tick:
		var entry: Dictionary = pending.pop_front()
		if entry["kind"] == KIND_WAVE_START:
			director.waves.enter_wave(entry["wave"])
		else:
			_enter_unit(entry)

func _enter_unit(entry: Dictionary) -> void:
	var wave: EncounterWaveData = director.encounter.encounter_waves[entry["wave"]]
	var board: BoardData = director.board
	var footprint: Vector2i = _footprint_of(entry["enemy_object_id"])
	var cell: Vector2i = entry["cell"]
	var anchor: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE
	if board.footprint_fits(footprint, cell):
		anchor = cell
	else:
		match wave.wave_spawn_policy:
			EncounterWaveData.SPAWN_POLICIES.FAIL_SKIP:
				_skip(entry, "cell occupied (FAIL_SKIP)")
				return
			EncounterWaveData.SPAWN_POLICIES.WAIT_UNTIL_FREE:
				if _retry(entry, wave):
					return
		anchor = board.nearest_empty_anchor_for_footprint(footprint, cell)
		if anchor == BaseCombatant.BOARD_ANCHOR_NONE:
			# full board: wait like WAIT_UNTIL_FREE (NEAREST_EMPTY), else give up
			if wave.wave_spawn_policy != EncounterWaveData.SPAWN_POLICIES.NEAREST_EMPTY or not _retry(entry, wave):
				_skip(entry, "no free cell")
			return
	var unit_layer: Node = get_unit_layer()
	var enemy: Enemy = unit_layer.spawn_board_enemy(entry["enemy_object_id"]) if unit_layer != null else null
	if enemy == null:
		_skip(entry, "no unit layer")
		return
	if not board.place(enemy, anchor):
		_discard(enemy)
		_skip(entry, "placement failed")
		return
	director.admit_wave_unit(enemy)

## Re-queues the entry wave_spawn_retry_ticks later; false = retries used up.
func _retry(entry: Dictionary, wave: EncounterWaveData) -> bool:
	if entry["retries"] >= wave.wave_spawn_max_retries:
		return false
	entry["retries"] += 1
	entry["tick"] += max(1, wave.wave_spawn_retry_ticks)
	_insert(entry)
	return true

func _skip(entry: Dictionary, reason: String) -> void:
	skipped_units.append(entry)
	DebugLogger.log_line("UnitSpawner: wave {0} unit {1} at {2} skipped at tick {3}: {4}".format([entry["wave"], entry["enemy_object_id"], entry["cell"], entry["tick"], reason]), Color.YELLOW, DebugLogger.Severities.WARNING)
#endregion

#region Helpers
func _insert(entry: Dictionary) -> void:
	entry["order"] = _next_order
	_next_order += 1
	var position: int = pending.size()
	for i: int in pending.size():
		if entry["tick"] < pending[i]["tick"]:
			position = i
			break
	pending.insert(position, entry)

func _unit_entry(wave_index: int, tick: int, enemy_object_id: String, cell: Vector2i) -> Dictionary:
	return {"kind": KIND_UNIT, "tick": tick, "wave": wave_index, "enemy_object_id": enemy_object_id, "cell": cell, "retries": 0}

## First action tick of a wave-0 unit: enter delay + stagger * index + spawn delay.
func _entry_tick(wave: EncounterWaveData, start_tick: int, index: int, unit_entry: Dictionary) -> int:
	return start_tick + max(0, wave.wave_enter_delay_ticks) + max(0, wave.wave_stagger_ticks) * index + max(0, int(unit_entry.get("spawn_delay_ticks", 0)))

func _pick_enemy(unit_entry: Dictionary) -> String:
	var weights: Dictionary[Variant, int] = {}
	weights.assign(unit_entry.get("weights", {}))
	if weights.is_empty():
		return ""
	var rng_enemy_spawning: RandomNumberGenerator = Global.player_data.get_player_rng("rng_enemy_spawning")
	return Random.get_weighted_selection(rng_enemy_spawning, weights)

## Entry cell, or the default spawn origin when missing / off the board.
func _entry_cell(unit_entry: Dictionary) -> Vector2i:
	var cell: Vector2i = EncounterData.cell_from_json(unit_entry.get("cell", null))
	if not director.board.is_in_bounds(cell):
		cell = director.board_controller.default_spawn_origin()
	return cell

func _footprint_of(enemy_object_id: String) -> Vector2i:
	var enemy_data: EnemyData = Global.get_enemy_data(enemy_object_id)
	if enemy_data == null:
		return Vector2i(1, 1)
	return Vector2i(max(1, enemy_data.enemy_footprint.x), max(1, enemy_data.enemy_footprint.y))
#endregion

## Spawns an enemy mid-combat on the board (ActionSummonEnemies with spawn cells): placed at cell or
## the nearest empty cell. null = no unit layer / board, or the board is full.
func spawn_enemy_at_cell(enemy_object_id: String, cell: Vector2i) -> Enemy:
	var unit_layer: Node = get_unit_layer()
	var board_controller: BoardController = director.board_controller
	if unit_layer == null or board_controller == null or board_controller.board == null:
		return null
	var enemy: Enemy = unit_layer.spawn_board_enemy(enemy_object_id)
	if enemy != null and not board_controller.place_unit_nearest(enemy, cell):
		enemy.queue_free()
		return null
	return enemy
