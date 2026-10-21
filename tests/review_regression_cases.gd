extends RefCounted
## 2026-10-21 review regressions in a mounted board combat (Field suite, real Director/module):
## step-limited path validation, paid-cell-minimal active paths, executed path == preview path,
## event-driven movement preview / actor sync and inline consumption of empty field boundaries.

const PATH_VALIDATOR: String = "res://scripts/validators/board/ValidatorPathExists.gd"

func run(c) -> void:
	await _natural_hand_card_in_mounted_mode(c)
	_paid_minimal_path(c)
	_validator_counts_steps(c)
	await _player_path_matches_preview(c)
	await _idle_frames_do_not_requery(c)
	await _empty_field_boundaries_inline(c)

## A scratch board: the cheapest-cost path to (2, 2) spends 3 paid cells, another spends 2.
func _paid_minimal_path(c) -> void:
	var rules := CombatRulesData.new()
	rules.paid_move_max_cells = 3
	var scratch := BoardData.new(Vector2i(5, 5), rules)
	var costs: Dictionary = {Vector2i(0, 2): 3, Vector2i(1, 1): 2, Vector2i(2, 1): 3, Vector2i(2, 2): 2, Vector2i(3, 0): 3, Vector2i(3, 2): 3}
	for cell: Vector2i in scratch.all_cells():
		scratch.get_cell(cell).move_cost = costs.get(cell, 1)
		scratch.get_cell(cell).is_blocked = cell == Vector2i(0, 1) or cell.x > 3 or cell.y > 2
	var saved: Array = [c.player.board_id, c.player.board_anchor, c.player.move_points, c.player.paid_cells_this_action]
	c.player.move_points = 2
	c.player.paid_cells_this_action = 0
	var placed: bool = scratch.place(c.player, Vector2i(0, 0))
	var path: Array = scratch.reachable_active(c.player).get(Vector2i(2, 2), [])
	scratch.remove(c.player)
	c.player.board_id = saved[0]
	c.player.board_anchor = saved[1]
	c.player.move_points = saved[2]
	c.player.paid_cells_this_action = saved[3]
	c._check(placed and path == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)], "active movement prefers 2 paid cells (cost 7) over the cost-6 path with 3 paid cells: %s" % [path])

## Card movement counts physical steps; a cost-3 cell on a 2-step route must not reject it.
func _validator_counts_steps(c) -> void:
	var board: BoardData = c.board
	var start: Vector2i = c.player.board_anchor
	var line: Array[Vector2i] = []
	for direction: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		var mid: Vector2i = start + direction
		var end: Vector2i = start + direction * 2
		if board.can_stand(c.player, mid) and board.can_stand(c.player, end):
			line = [mid, end]
			break
	if not c._check(not line.is_empty(), "free straight 2-cell line beside the hero"):
		return
	var cell_data: BoardCellData = board.get_cell(line[0])
	var old_cost: int = cell_data.move_cost
	cell_data.move_cost = 3
	var action: BaseAction = ActionGenerator.create_actions(c.player, null, [c.player], [{Scripts.ACTION_MOVE_UNIT: {}}], null)[0]
	var two: Array[Dictionary] = [{PATH_VALIDATOR: {"to": [line[1].x, line[1].y], "max_length": 2}}]
	var one: Array[Dictionary] = [{PATH_VALIDATOR: {"to": [line[1].x, line[1].y], "max_length": 1}}]
	var two_ok: bool = Global.validate(two, null, action)
	var one_ok: bool = Global.validate(one, null, action)
	cell_data.move_cost = old_cost
	c._check(two_ok and not one_ok, "ValidatorPathExists max_length=2 accepts a 2-step route over cost-3 terrain (step semantics as ActionMoveUnit); max_length=1 rejects")

func _view(c) -> Node:
	return c.combat.board_views.get(c.player.board_id)

## The clicked move executes exactly the path BoardView previewed (tie between two L routes).
func _player_path_matches_preview(c) -> void:
	if not await c._wait(c._player_ready, "hero action pending for preview/execution path check"):
		return
	var board: BoardData = c.board
	var start: Vector2i = c.player.board_anchor
	var goal: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE
	for candidate: Vector2i in [start + Vector2i(1, -1), start + Vector2i(-1, -1), start + Vector2i(1, 1), start + Vector2i(-1, 1)]:
		if board.can_stand(c.player, candidate) and board.can_stand(c.player, Vector2i(candidate.x, start.y)) and board.can_stand(c.player, Vector2i(start.x, candidate.y)):
			goal = candidate
			break
	if not c._check(goal != BaseCombatant.BOARD_ANCHOR_NONE, "diagonal goal with two equal-cost routes"):
		return
	c.player.move_points = 4
	var view: Node = _view(c)
	var preview: Array = view.movement_preview(board, c.player).get(goal, []).duplicate()
	var walked: Array = []
	var trace := func(unit, _from_id, _from, _to_id, to):
		if unit == c.player:
			walked.append(to)
	c.signals.unit_board_moved.connect(trace)
	var accepted: bool = c.director.board_module.request_player_move(c.player, goal)
	await c._wait(c._idle, "player move drains")
	c.signals.unit_board_moved.disconnect(trace)
	c._check(accepted and preview.size() == 2 and walked == preview and c.player.board_anchor == goal, "executed move path %s equals the previewed path %s" % [walked, preview])

## Idle frames neither re-run the weighted movement search nor resync actor presentation.
func _idle_frames_do_not_requery(c) -> void:
	var view: Node = _view(c)
	var presentation: Node = c.combat.actor_presentation
	view.movement_preview(c.board, c.player)
	view.queue_redraw()
	await c.flow.process_frame
	var queries: int = view.movement_query_count
	var syncs: int = presentation.sync_count
	for _frame: int in 10:
		await c.flow.process_frame
	c._check(view.movement_query_count == queries, "10 idle frames run no movement search (%d -> %d)" % [queries, view.movement_query_count])
	c._check(presentation.sync_count == syncs, "10 idle frames run no full actor sync (%d -> %d)" % [syncs, presentation.sync_count])
	c.signals.timeline_changed.emit()
	view.queue_redraw()
	await c.flow.process_frame
	await c.flow.process_frame
	c._check(presentation.sync_count > syncs, "a presentation signal triggers one resync")

## interval-1 field on an empty cell: hundreds of boundaries are consumed in a few frames.
func _empty_field_boundaries_inline(c) -> void:
	var data := FieldData.new("field_review_interval_one")
	data.field_tick_interval = 1
	data.field_duration_ticks = -1
	data.field_tick_actions.assign([{c.flow.get_script().resource_path.get_base_dir().path_join("field_trace_action.gd"): {"label": "empty_tick"}}])
	Global.register_rod(data)
	var empty: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE
	for cell: Vector2i in c.board.all_cells():
		if c.board.get_unit_at(cell) == null and not c.board.is_blocked(cell):
			empty = cell
			break
	await c.create_field(data.object_id, [[empty.x, empty.y]])
	Global.set_meta("field_test_trace", [])
	var frames: Array[int] = [0]
	var counter := func(): frames[0] += 1
	c.flow.process_frame.connect(counter)
	await c.director.advance_clock(c.director.current_tick + 300, c.director.get_generation())
	await c._wait(c._idle, "empty interval-1 field clock drains")
	c.flow.process_frame.disconnect(counter)
	var found: Array = c.board.get_fields(empty)
	c._check(Global.get_meta("field_test_trace").is_empty() and not found.is_empty() and found[0].next_tick > c.director.current_tick, "empty boundaries run no payload and advance next_tick past the clock")
	c._check(frames[0] < 30, "300 empty boundaries finish in %d frames (was >= 600)" % frames[0])
	Global.remove_meta("field_test_trace")
	await c.remove_fields()

## Normal play path in mounted DUAL/board mode: a naturally drawn card, real fee, no test energy.
func _natural_hand_card_in_mounted_mode(c) -> void:
	if not await c._wait(c._player_ready, "hero action pending for natural card play"):
		return
	var card: Node = null
	for candidate: Node in c.hand.card_data_to_hand_card.values():
		if candidate.card_data.object_id == "card_block_basic":
			card = candidate
			break
	if not c._check(card != null, "a naturally drawn Basic Block is in hand"):
		return
	var data: CardData = card.card_data
	var cost: int = data.get_card_energy_cost(true, true)
	var energy: int = Global.player_data.player_energy
	var block: int = c.player.get_block()
	c._check(card.can_play_card(null, false) and c.director.has_board_module(), "ordinary card stays playable while the board module is mounted")
	card.card_selected.emit(card)
	await c._wait(c._idle, "natural Basic Block resolves through Hand and the public queue")
	c._check(Global.player_data.player_energy == energy - cost and c.player.get_block() > block and not HandManager.player_hand.has(data) and data.object_id in HandManager.player_discard.map(func(d): return d.object_id), "mounted mode: natural click pays the real fee, applies block and discards (no fixture injection)")
