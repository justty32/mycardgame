## Unit spawning of one combat, owned by CombatDirector: spawns encounter wave units through the
## combat's unit layer (EnemyContainer) and places them on the board (BoardController), and spawns
## board summons (ActionSummonEnemies with spawn cells). A RefCounted created per combat.
extends RefCounted
class_name UnitSpawner

var director: CombatDirector = null
## unit_uid -> first next_action_tick of a wave-0 unit (its spawn delay).
var spawn_delays: Dictionary[String, int] = {}

func _init(combat_director: CombatDirector) -> void:
	director = combat_director

func get_unit_layer() -> Node:
	var combat: Node = director.get_parent() if director != null else null
	if combat == null or not combat.has_node("EnemyContainer"):
		return null
	return combat.get_node("EnemyContainer")

## Tick of a unit's first action: its wave spawn delay, 0 otherwise.
func first_action_tick(unit: BaseCombatant) -> int:
	return spawn_delays.get(unit.unit_uid, 0)

func clear() -> void:
	spawn_delays.clear()

## Spawns wave 0 of the encounter: weighted picks in order with rng_enemy_spawning (like the legacy
## spawner), in the event's placement mode, placed on their cell or the nearest empty one.
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
		if not board_controller.board.is_in_bounds(cell):
			cell = board_controller.default_spawn_origin()
		board_controller.place_unit_nearest(enemy, cell)
		var spawn_delay: int = int(unit_entry.get("spawn_delay_ticks", 0))
		if spawn_delay > 0:
			spawn_delays[enemy.unit_uid] = spawn_delay
		index += 1

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
