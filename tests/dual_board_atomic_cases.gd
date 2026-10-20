extends RefCounted
## Isolated geometry fault injection plus cancellation of a real queued transfer.

func run(c) -> void:
	var battlefield := CombatBattlefield.new()
	var failure_script: Script = load(get_script().resource_path.get_base_dir().path_join("dual_board_failing_board.gd"))
	var a_board: BoardData = failure_script.new(Vector2i(5, 5), battlefield.rules)
	var b_board: BoardData = failure_script.new(Vector2i(5, 5), battlefield.rules)
	a_board.board_id = "party"
	b_board.board_id = "enemy"
	battlefield.boards["party"] = a_board
	battlefield.boards["enemy"] = b_board
	var a := BaseCombatant.new()
	var b := BaseCombatant.new()
	a.unit_uid = "atomic_probe_a"
	b.unit_uid = "atomic_probe_b"
	a.footprint = Vector2i(2, 2)
	b.footprint = Vector2i(2, 2)
	c._check(battlefield.place(a, BoardPosition.new("party", Vector2i(0, 0))) and battlefield.place(b, BoardPosition.new("enemy", Vector2i(2, 2))), "atomic fixture places 2x2 units on independent boards")
	var duplicate := BaseCombatant.new()
	duplicate.unit_uid = a.unit_uid
	c._check(not battlefield.place(duplicate, BoardPosition.new("enemy", Vector2i(4, 4))) and a_board.get_unit_at(Vector2i.ZERO) == a, "different entity with duplicate UID cannot occupy another board")
	duplicate.free()
	a.board_id = "enemy"
	c._check(not battlefield.place(a, BoardPosition.new("enemy", Vector2i.ZERO)) and a_board.get_unit_at(Vector2i.ZERO) == a and b_board.get_unit_at(Vector2i.ZERO) == null, "changing board_id cannot duplicate an already placed identity")
	a.board_id = "party"
	b_board.fail_next_place = true
	c._check(not battlefield.transfer(a, BoardPosition.new("enemy", Vector2i(0, 0))), "injected destination commit failure rejects transfer")
	c._check(a.board_id == "party" and a.board_anchor == Vector2i.ZERO and a_board.get_unit_at(Vector2i(1, 1)) == a and b_board.get_unit_at(Vector2i.ZERO) == null, "failed transfer restores every source footprint cell and target occupancy")
	a_board.fail_next_place = true
	c._check(not battlefield.swap(a, b), "injected second endpoint commit failure rejects swap")
	c._check(a.board_id == "party" and b.board_id == "enemy" and a_board.get_unit_at(Vector2i(1, 1)) == a and b_board.get_unit_at(Vector2i(3, 3)) == b and a_board.get_unit_at(Vector2i(2, 2)) == null and b_board.get_unit_at(Vector2i.ZERO) == null, "second endpoint failure rolls back both multi-cell occupancies atomically")
	c._check(battlefield.swap(a, b) and a.board_id == "enemy" and b.board_id == "party" and b_board.get_unit_at(Vector2i(3, 3)) == a and a_board.get_unit_at(Vector2i(1, 1)) == b, "successful multi-cell swap commits complete footprints")
	a_board.remove(b)
	b_board.remove(a)
	a.free()
	b.free()
	var before := BoardPosition.from_unit(c.player)
	var generated: Array[BaseAction] = ActionGenerator.create_actions(c.player, null, [], [
		{Scripts.ACTION_MOVE_UNIT: {"mode": "TELEPORT", "target_board_id": "enemy", "target_cell": [0, 4]}},
		{get_script().resource_path.get_base_dir().path_join("field_trace_action.gd"): {"label": "cancel_gate", "time_delay": 0.1}},
	], null)
	ActionHandler.add_actions(generated)
	ActionHandler.clear_all_actions()
	await c._wait(c._idle, "cancelled transfer queue becomes idle")
	c._check(BoardPosition.from_unit(c.player).equals(before), "cancellation before transfer commit leaves both boards unchanged")
	Global.remove_meta("field_test_trace")
