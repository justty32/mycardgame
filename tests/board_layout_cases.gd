extends RefCounted
## Arithmetic and view-slot contracts only. Explicit >2 rectangles are fixtures, not a product policy.

func run(c) -> void:
	var ids: Array = ["west", "summit", "vault"]
	var rects: Array[Rect2] = [Rect2(10, 20, 210, 180), Rect2(250, 20, 260, 200), Rect2(550, 20, 300, 240)]
	var slots: Dictionary[String, Rect2] = BoardLayout.map_slots(ids, rects)
	c._check(slots.size() == ids.size() and slots["vault"] == rects[2], "explicit slots retain every arbitrary board ID without a two-slot clamp")
	var disjoint: bool = true
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			disjoint = disjoint and not slots[ids[i]].intersects(slots[ids[j]])
	c._check(disjoint, "three explicit fixture slots do not overlap")
	var reversed_ids: Array = ids.duplicate()
	reversed_ids.reverse()
	var reordered: Dictionary[String, Rect2] = BoardLayout.map_slots(reversed_ids, rects)
	c._check(reordered["west"] == rects[2] and reordered["vault"] == rects[0] and ids == ["west", "summit", "vault"], "display ordering maps stable IDs to new rectangles without mutating the input IDs")
	c._check(BoardLayout.compatibility_slots([]).is_empty() and BoardLayout.compatibility_slots(ids).is_empty(), "compatibility layout chooses no arbitrary three-board policy")
	var short_rects: Array[Rect2] = [rects[0]]
	c._check(BoardLayout.map_slots(ids, short_rects).is_empty() and BoardLayout.map_slots(["same", "same", "last"], rects).is_empty(), "incomplete rectangles and duplicate identities reject the whole mapping")
	var view := BoardView.new()
	view.board_id = "summit"
	var board := BoardData.new(Vector2i(12, 3))
	var fits: bool = true
	for slot: Rect2 in rects:
		view.set_layout_slot(slot, board)
		var last: Rect2 = view.cell_rect(Vector2i(11, 2))
		fits = fits and slot.encloses(Rect2(view.position, view.size)) and last.end.is_equal_approx(view.size) and view.cell_at(last.get_center()) == Vector2i(11, 2)
	c._check(fits and view.board_id == "summit" and board.size == Vector2i(12, 3), "slot changes refit every cell and retain view ID and gameplay board dimensions")
	var small_layout: Dictionary = BoardView.compute_layout(board.size, rects[0].size)
	c._check(is_equal_approx(small_layout.cell_size, 17.5) and small_layout.size == Vector2(210, 52.5), "caller slot dimensions drive square cell sizing independently of compatibility constants")
	view.free()

## Temporary normalized runtime world, explicit fixture rectangles and real existing actors.
## No event-loop yield occurs while the fixture replaces the live world's reference.
func run_presentation(c) -> void:
	var module: BoardCombatModule = c.combat.board_module
	var presentation: BoardCombatPresentation = module.presentation
	var original: CombatBattlefield = module.battlefield
	var saved_slots: Dictionary[String, Rect2] = presentation.layout_slots.duplicate()
	var states: Array[Dictionary] = []
	var definitions: Dictionary = {
		"west": {"size": Vector2i(7, 5)},
		"summit": {"size": Vector2i(7, 5)},
		"vault": {"size": Vector2i(7, 5)},
	}
	var world := CombatBattlefield.new(BoardSetup.from_definitions(definitions, c.director.rules), c.director.rules)
	for unit: BaseCombatant in original.get_units():
		states.append({"unit": unit, "board_id": unit.board_id, "anchor": unit.board_anchor, "faction": unit.faction})
		var destination: String = "west" if unit.board_id == "party" else "summit"
		c._check(world.place(unit, BoardPosition.new(destination, unit.board_anchor)), "layout fixture places existing actor on explicit arbitrary-ID board")
	module.board_controller.battlefield = world
	var rects: Array[Rect2] = [Rect2(20, 170, 300, 240), Rect2(360, 170, 300, 240), Rect2(700, 170, 300, 240)]
	presentation.layout_slots = BoardLayout.map_slots(world.boards.keys(), rects)
	c._check(presentation.sync_board_views() and presentation.board_views.size() == 3 and presentation.board_views.has("west") and presentation.board_views.has("summit") and presentation.board_views.has("vault"), "real presentation creates three arbitrary-ID views from explicit fixture rectangles")
	var views: Dictionary[String, BoardView] = presentation.board_views.duplicate()
	var actor_position: Vector2 = c.player.global_position
	var old_size: Vector2 = views["west"].size
	var old_position: Vector2 = views["west"].position
	presentation.layout_slots["west"] = Rect2(40, 130, 210, 150)
	c._check(presentation.sync_board_views() and presentation.board_views["west"] == views["west"] and views["west"].size != old_size and views["west"].position != old_position, "same board IDs receive changed slot geometry without replacing their views")
	presentation.actor_presentation.sync_positions(false)
	c._check(c.player.global_position != actor_position, "existing actor presentation follows a changed slot while gameplay location stays committed")
	var reordered: Dictionary[String, BoardData] = {}
	for id: String in ["vault", "summit", "west"]:
		reordered[id] = world.boards[id]
	world.boards = reordered
	presentation.layout_slots = BoardLayout.map_slots(world.boards.keys(), rects)
	c._check(presentation.sync_board_views() and presentation.board_view == views["vault"] and presentation.board_views["west"] == views["west"] and presentation.board_views["summit"] == views["summit"] and presentation.board_views["vault"] == views["vault"], "reordering display IDs retains every view instance and selects the corresponding first view")
	var unchanged: bool = true
	for state: Dictionary in states:
		var unit: BaseCombatant = state.unit
		var expected_id: String = "west" if state.board_id == "party" else "summit"
		unchanged = unchanged and unit.board_id == expected_id and unit.board_anchor == state.anchor and unit.faction == state.faction and world.get_board(expected_id).get_unit_at(state.anchor) == unit
	c._check(unchanged, "presentation slot changes and reordering preserve actor board ID, anchor, faction and occupancy")
	var good_position: Vector2 = views["west"].position
	var good_cell_size: float = views["west"].cell_size
	presentation.layout_slots["west"] = Rect2(0, 0, 0, 100)
	c._check(not presentation.sync_board_views() and presentation.layout_error == "invalid_layout_slot:west" and views["west"].position == good_position and views["west"].cell_size == good_cell_size, "invalid explicit slot rejects the entire update before changing valid views")
	presentation.layout_slots.erase("west")
	c._check(not presentation.sync_board_views() and presentation.layout_error == "invalid_layout_slot:west", "missing explicit slot rejects without silently dropping a board")
	# Restore fixture-owned substitutions before any gameplay process resumes.
	for state: Dictionary in states:
		state.unit.board_id = state.board_id
		state.unit.board_anchor = state.anchor
	module.board_controller.battlefield = original
	presentation.layout_slots = saved_slots
	c._check(presentation.sync_board_views() and presentation.layout_error.is_empty(), "presentation fixture restores original world and compatibility layout")
	presentation.actor_presentation.sync_positions(false)
	await c.flow.process_frame
