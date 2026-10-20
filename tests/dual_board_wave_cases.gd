extends RefCounted
## Final group: real two-board wave admission and victory. Does not emit outcome signals.

func run(c) -> void:
	var ended_before: int = c.counts.combat_ended
	var event_order: Array = []
	var on_started := func(index): event_order.append(["started", index])
	var on_cleared := func(index): event_order.append(["cleared", index])
	var on_ended := func(): event_order.append(["ended", -1])
	c.signals.wave_started.connect(on_started)
	c.signals.wave_cleared.connect(on_cleared)
	c.signals.combat_ended.connect(on_ended)
	var initial: Array[Enemy] = []
	initial.assign(Global.get_alive_enemies())
	for unit: Enemy in initial:
		c._check(await c._play_board("dual_finish", unit.board_id, unit.board_anchor) == "", "real card clears initial dual-board enemy")
	await c._wait(func(): return c.director.waves.cleared_count == 1 and c._idle(), "first dual wave clears through real death flow")
	c._check(c.counts.combat_ended == ended_before and c.director.has_remaining_opponents(), "empty current boards do not end combat while second wave is pending")
	c.combat.end_turn_button.button_up.emit()
	await c._wait(func(): return c.director.waves.current_wave == 1 and c._player_ready(), "End Turn admits second wave on both boards")
	var party_enemy: BaseCombatant = c.party_board.get_unit_at(Vector2i(1, 1))
	var enemy_enemy: BaseCombatant = c.enemy_board.get_unit_at(Vector2i(1, 1))
	if not c._check(party_enemy != null and enemy_enemy != null and party_enemy != enemy_enemy and party_enemy.faction == BaseCombatant.FACTIONS.ENEMY and enemy_enemy.faction == BaseCombatant.FACTIONS.ENEMY, "wave entries with same local cell occupy their explicit boards without changing faction"):
		return
	c._check(c.director.timeline.has(party_enemy) and c.director.timeline.has(enemy_enemy), "both board wave units join the single timeline")
	c._check(await c._play_board("dual_finish", "enemy", Vector2i(1, 1)) == "", "defeat enemy-board final-wave unit")
	await c._wait(c._idle, "last party-board opponent remains after enemy-board death")
	c._check(c.counts.combat_ended == ended_before and party_enemy.is_alive() and not c.director.is_combat_over(), "enemy faction on party board still prevents victory")
	c._check(await c._play_board("dual_finish", "party", Vector2i(1, 1)) == "", "defeat invading party-board final-wave unit")
	await c._wait(func(): return c.counts.combat_ended == ended_before + 1, "last opponent on either board triggers real victory")
	c._check(event_order == [["cleared", 0], ["started", 1], ["cleared", 1], ["ended", -1]], "two-board waves clear before exactly one combat_ended")
	c._check(not c.director.is_running and c.party_board.fields.is_empty() and c.enemy_board.fields.is_empty(), "victory stops CTB and clears both boards' fields")
	c.signals.wave_started.disconnect(on_started)
	c.signals.wave_cleared.disconnect(on_cleared)
	c.signals.combat_ended.disconnect(on_ended)
