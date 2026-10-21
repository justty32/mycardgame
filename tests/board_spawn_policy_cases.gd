extends RefCounted
## Internal slot-free capability versus the unchanged legacy default, using real spawning.

func run(c) -> void:
	c.director._stop()
	await c._wait(c._idle, "previous direct start actions settle before generation-policy fixture")
	var layer: Node = c.director.get_parent().get_node("EnemyContainer")
	layer.clear_enemies()
	await c.flow.process_frame
	var encounter := EncounterData.new("internal_spawn_policy")
	encounter.encounter_board_size = Vector2i(7, 5)
	encounter.encounter_deploy_cells.assign([[3, 4]])
	var wave := EncounterWaveData.new()
	wave.wave_units.assign([{"weights": {"board_dummy": 1}, "cell": [0, 0]}, {"weights": {"board_dummy": 1}, "cell": [1, 0]}, {"weights": {"board_dummy": 1}, "cell": [2, 0]}])
	encounter.encounter_waves.assign([wave])
	var event := EventData.new("explicit_positional_compatibility")
	event.event_encounter_object_id = encounter.object_id
	event.event_enemy_placement_is_automatic = false
	event.event_enemy_placement_positions.assign([[0, 0]])
	# The legacy diagnostics compare event weights with screen slots, not authored wave units.
	event.event_weighted_enemy_object_ids.assign([{"board_dummy": 1}])
	var module: BoardCombatModule = c.combat.combat_module
	for use_event_slots: bool in [false, true]:
		c.director.encounter = encounter
		c.director.combat_module = module
		c._check(module.setup(c.director, encounter), "spawn-policy fixture installs ordinary legacy board geometry")
		var spawner := UnitSpawner.new(c.director)
		if use_event_slots:
			spawner.spawn_first_wave(event, encounter)
		else:
			spawner.spawn_first_wave(event, encounter, false)
		await c.flow.process_frame
		var enemies: Array[Enemy] = Global.get_alive_enemies()
		c._check(enemies.size() == (1 if use_event_slots else 3), "explicit Encounter positional event retains slot default; internal opt-in exceeds slots: %s" % use_event_slots)
		var placed: bool = true
		for enemy: Enemy in enemies:
			placed = placed and module.battlefield.get_board_for_unit(enemy) != null and enemy.get_parent() == layer.board_actor_container and UnitRegistry.get_unit(enemy.unit_uid) == enemy
		c._check(placed and spawner.pending.is_empty() and spawner.skipped_units.is_empty(), "actual spawned units register and occupy cells independently of screen capacity: %s" % use_event_slots)
		module.clear()
		layer.clear_enemies()
		await c.flow.process_frame
	c.director.combat_module = null
