extends RefCounted
## Small declared two-wave fixture for UnitSpawner's ordinary (NONE) admission branch.
## install runs before New Run; run uses only normal card, End Turn and victory paths.

func install() -> void:
	var enemy: EnemyData = Global.get_enemy_data("combat_flow_enemy")
	enemy.enemy_health_max_random_lower = 40
	enemy.enemy_health_max_random_upper = 40
	var first := EncounterWaveData.new()
	first.wave_units.assign([{"weights": {"combat_flow_enemy": 1}}])
	var later := EncounterWaveData.new()
	later.wave_enter_delay_ticks = 75
	later.wave_units.assign([{"weights": {"combat_flow_enemy": 1}, "spawn_delay_ticks": 25}])
	var encounter := EncounterData.new("boardless_wave_encounter")
	encounter.encounter_waves.assign([first, later])
	Global.register_rod(encounter)
	Global.get_event_data("combat_flow_event").event_encounter_object_id = encounter.object_id
	print("FIXTURE: scene_off uses two ordinary 40 HP enemies in separate waves; second entry at clear tick + 100; no board cells or live-state rewrites.")

## Called after scene_off's first normal attack and block (first enemy has 20 HP left).
func run(c) -> bool:
	var director: CombatDirector = c.combat.combat_director
	var first_uid: String = c.enemy.unit_uid
	if not c._check(c.enemy.get_combatant_health() == 20 and director.waves.get_wave_count() == 2, "NONE wave fixture reached through ordinary attack and block"):
		return false
	if not await c._play("card_attack_basic", true):
		return false
	if not await c._wait(func(): return director.waves.cleared_count == 1 and c._idle(), "ordinary lethal card clears wave zero"):
		return false
	c._check(c.counts.combat_ended == 0 and director.has_remaining_opponents() and director.unit_spawner.has_pending_units(1), "pending NONE wave prevents premature victory with no living enemy")
	var enemy_actions_before: int = c.counts.enemy_action_started
	c.combat.end_turn_button.button_up.emit()
	if not await c._wait(func(): return director.waves.current_wave == 1 and c._player_ready(), "End Turn admits the delayed ordinary wave and resumes hero input"):
		return false
	var living: Array[Enemy] = Global.get_alive_enemies()
	if not c._check(living.size() == 1, "later NONE wave spawns exactly one real enemy"):
		return false
	c.enemy = living[0]
	c._check(c.enemy.unit_uid != first_uid and UnitRegistry.get_unit(c.enemy.unit_uid) == c.enemy and director.timeline.has(c.enemy), "later enemy has fresh registry identity and joins real CTB timeline")
	c._check(c.enemy.board_anchor == BaseCombatant.BOARD_ANCHOR_NONE and director.battlefield == null and director.board_module == null, "later wave admission allocates no board and no synthetic anchor")
	c._check(c.counts.enemy_action_started > enemy_actions_before and c.enemy.last_action_tick == 100, "delayed wave enemy executes at authored entry tick before hero resumes")
	c.assert_no_board()
	if not await c._play("card_attack_basic", true):
		return false
	if not await c._play("card_attack_basic", true, true):
		return false
	var rewards: Node = c.game_root.get_node("RunScreen/RewardOverlay")
	if not await c._wait(func(): return c.counts.combat_ended == 1 and rewards.is_visible_in_tree() and c._idle(), "final ordinary wave lethal opens genuine victory rewards"):
		return false
	c._check(c.counts.enemy_dead == 2 and director.waves.is_final_cleared() and not director.is_running, "both ordinary waves die naturally and end combat once")
	c._check(c.wave_log == ["started 0", "cleared 0", "started 1", "cleared 1", "ended"], "NONE waves retain start-clear-final-victory ordering")
	return true
