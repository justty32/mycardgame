extends "field_cases.gd"
## True default dual-board startup; shares only the established Root/menu/map driver.

var battlefield: CombatBattlefield
var party_board: BoardData
var enemy_board: BoardData
var enemy: BaseCombatant

func _scenario() -> bool:
	_check(CombatRulesData.new().board_mode == CombatRulesData.BOARD_MODES.DUAL, "fresh combat rules default to DUAL")
	var fixture: RefCounted = load(flow.get_script().resource_path.get_base_dir().path_join("dual_board_fixture.gd")).new()
	fixture.install()
	if not await _start_combat():
		return false
	battlefield = director.battlefield
	party_board = battlefield.get_board("party")
	enemy_board = battlefield.get_board("enemy")
	if not _check(battlefield.valid and battlefield.boards.size() == 2 and party_board != null and enemy_board != null, "normal Root New Run builds two independent boards"):
		return false
	enemy = enemy_board.get_unit_at(Vector2i(3, 4))
	_check(player.board_id == "party" and enemy != null and enemy.board_id == "enemy" and party_board.get_unit_at(Vector2i(3, 4)) == player, "same coordinates on distinct boards have independent occupants")
	_check(director.has_living_opponents() and not director.is_combat_over(), "enemy on other board still prevents victory")
	var presentation: RefCounted = load(flow.get_script().resource_path.get_base_dir().path_join("dual_board_presentation_cases.gd")).new()
	await presentation.run(self)
	for script: String in ["dual_board_policy_cases.gd", "dual_board_transfer_cases.gd", "dual_board_field_cases.gd", "dual_board_clock_equivalence_cases.gd", "dual_board_intent_reaction_cases.gd", "dual_board_lifetime_cases.gd", "dual_board_atomic_cases.gd", "dual_board_duplicate_cases.gd", "dual_board_adapter_cases.gd"]:
		var group: RefCounted = load(flow.get_script().resource_path.get_base_dir().path_join(script)).new()
		await group.run(self)
	await presentation.run_exit(self)
	var waves: RefCounted = load(flow.get_script().resource_path.get_base_dir().path_join("dual_board_wave_cases.gd")).new()
	await waves.run(self)
	return true

func _play_board(card_id: String, board_id: String, cell: Vector2i) -> String:
	var card: Node = _give(card_id)
	if card == null:
		_check(false, "dual card added: " + card_id)
		return "missing"
	var before: int = counts.played
	var unchanged: Dictionary = _request_state()
	card.card_selected.emit(card)
	if hand.current_selected_card != card:
		_check(_request_state() == unchanged, "preselection rejection preserves piles/energy/RNG/positions before cleanup")
		hand_manager.discard_cards(_cards([card.card_data]), false)
		await _wait(_idle, "dual card rejected before selection")
		return "not_selected"
	signals.board_cell_clicked.emit(board_id, cell)
	if hand.current_selected_card == card:
		var reason: String = hand.last_target_rejection
		_check(_request_state() == unchanged, "target rejection preserves piles/energy/RNG/positions before cleanup: " + reason)
		hand._on_background_button_up()
		hand_manager.discard_cards(_cards([card.card_data]), false)
		await _wait(_idle, "dual rejected request drains")
		return reason
	if not await _wait(func(): return counts.played > before and _idle(), "dual card play completes: " + card_id):
		return "timeout"
	return ""

func transfer(unit: BaseCombatant, board_id: String, cell: Vector2i) -> void:
	await _run_actions(unit, [], [{Scripts.ACTION_MOVE_UNIT: {"mode": "TELEPORT", "target_board_id": board_id, "target_cell": cell}}])

func snap_presentation() -> void:
	combat.actor_presentation.sync_positions(false)
	await flow.process_frame

func _request_state() -> Dictionary:
	var rngs: Dictionary = {}
	for name: String in Global.player_data.player_rng:
		var rng: RandomNumberGenerator = Global.player_data.player_rng[name]
		rngs[name] = [rng.seed, rng.state]
	var positions: Dictionary = {}
	for unit: BaseCombatant in battlefield.get_units():
		positions[unit.unit_uid] = [unit.board_id, unit.board_anchor, unit.get_combatant_health()]
	return {"hand": HandManager.player_hand.duplicate(), "draw": HandManager.player_draw.duplicate(), "discard": HandManager.player_discard.duplicate(), "exhaust": HandManager.player_exhaust.duplicate(), "energy": Global.player_data.player_energy, "reserved": HandManager.card_play_queue_reserved_energy_total, "rng": rngs, "positions": positions}
