extends RefCounted
## Per-encounter board size (2026-10-21): data-only sizes per board, rules limits, clear validation
## errors and size-driven BoardView layout. Pure objects only (no Root, no hero); run by board_flow.gd
## before its Root scenario. Layout numbers are headless arithmetic, not a rendering check.

var c	# board_flow.gd: _check()

func run(flow) -> void:
	c = flow
	_defaults_unchanged()
	_sizes_from_data()
	_rules_limits()
	_invalid_sizes()
	_cells_out_of_bounds()
	_layout()
	load(get_script().resource_path.get_base_dir().path_join("board_layout_cases.gd")).new().run(c)

func _rules(mode: int = CombatRulesData.BOARD_MODES.DUAL) -> CombatRulesData:
	var rules := CombatRulesData.new()
	rules.board_mode = mode
	return rules

func _encounter(boards: Dictionary = {}, legacy_size: Vector2i = Vector2i.ZERO) -> EncounterData:
	var encounter := EncounterData.new("board_size_probe")
	encounter.encounter_boards = boards
	encounter.encounter_board_size = legacy_size
	return encounter

func _sizes(battlefield: CombatBattlefield) -> Dictionary:
	var sizes: Dictionary = {}
	for id: String in battlefield.boards:
		sizes[id] = battlefield.get_board(id).size
	return sizes

func _defaults_unchanged() -> void:
	var rules := CombatRulesData.new()
	c._check(rules.default_board_size == Vector2i(5, 5) and rules.board_min_size == Vector2i(3, 3) and rules.board_max_size == Vector2i(12, 12) and rules.validate_configuration() == "", "framework rules: default 5x5, allowed 3x3..12x12, valid")
	var dual := CombatBattlefield.new(_encounter(), rules)
	c._check(dual.valid and _sizes(dual) == {"party": Vector2i(5, 5), "enemy": Vector2i(5, 5)}, "encounter without sizes keeps two default 5x5 boards: %s" % [_sizes(dual)])
	var single := CombatBattlefield.new(_encounter(), _rules(CombatRulesData.BOARD_MODES.SINGLE))
	c._check(single.valid and _sizes(single) == {"shared": Vector2i(5, 5)}, "SINGLE without sizes keeps one default 5x5 board")
	var patched := _rules()
	patched.default_board_size = Vector2i(6, 4)
	var inherited := CombatBattlefield.new(_encounter({"party": {"size": [3, 3]}}), patched)
	c._check(inherited.valid and _sizes(inherited) == {"party": Vector2i(3, 3), "enemy": Vector2i(6, 4)}, "unspecified board inherits the patched rules default while the other board keeps its own size")

func _sizes_from_data() -> void:
	var rules := _rules(CombatRulesData.BOARD_MODES.SINGLE)
	var tiny := _encounter({}, Vector2i(3, 3))
	var controller := BoardController.new(rules)
	var ok: bool = controller.setup(tiny)
	var shared: BoardData = controller.battlefield.get_board("shared") if ok else null
	c._check(ok and shared.size == Vector2i(3, 3) and controller.default_deploy_cells("shared")[0] == Vector2i(1, 2) and shared.is_deploy_cell(Vector2i(1, 2)) and shared.get_cell(Vector2i(2, 0)).is_spawn_zone and controller.default_spawn_origin("shared") == Vector2i(1, 0), "3x3 SINGLE board: default deploy (1,2), spawn rows and origin (1,0) follow the size")
	c._check(ok and BoardTargeting.cells_in_shape(shared, Vector2i(1, 2), Vector2i(1, 1), BoardTargeting.TARGET_SHAPES.SQUARE_3).size() == 9 and BoardTargeting.cells_in_shape(shared, Vector2i(1, 2), Vector2i(1, 1), BoardTargeting.TARGET_SHAPES.CROSS).size() == 5, "3x3 (the minimum) still fits SQUARE_3 and CROSS whole")
	controller.clear()

	var wide := CombatBattlefield.new(_encounter({"party": {"size": [8, 6]}, "enemy": {"size": [8, 6]}}), _rules())
	c._check(wide.valid and _sizes(wide) == {"party": Vector2i(8, 6), "enemy": Vector2i(8, 6)}, "8x6 per-board sizes on both DUAL boards")
	c._check(wide.valid and BoardTargeting.cells_in_shape(wide.get_board("enemy"), Vector2i(0, 0), Vector2i(3, 5), BoardTargeting.TARGET_SHAPES.ROW).size() == 8 and BoardTargeting.cells_in_shape(wide.get_board("enemy"), Vector2i(0, 0), Vector2i(3, 5), BoardTargeting.TARGET_SHAPES.COLUMN).size() == 6, "ROW / COLUMN span the 8x6 board's real width and height")

	var asym_encounter := _encounter({"party": {"size": [3, 3], "deploy_cells": [[1, 2]]}, "enemy": {"size": [8, 6], "blocked_cells": [[7, 5]], "spawn_zone_cells": [[7, 0]]}})
	var wave := EncounterWaveData.new()
	wave.wave_units.assign([{"weights": {"x": 1}, "board_id": "enemy", "cell": [7, 4]}])
	asym_encounter.encounter_waves.assign([wave])
	var asym := BoardController.new(_rules())
	ok = asym.setup(asym_encounter)
	var party: BoardData = asym.battlefield.get_board("party") if ok else null
	var enemy: BoardData = asym.battlefield.get_board("enemy") if ok else null
	c._check(ok and party.size == Vector2i(3, 3) and enemy.size == Vector2i(8, 6) and party.is_deploy_cell(Vector2i(1, 2)) and enemy.is_blocked(Vector2i(7, 5)) and enemy.get_cell(Vector2i(7, 0)).is_spawn_zone and asym.default_spawn_origin("enemy") == Vector2i(4, 0), "asymmetric DUAL: party 3x3 and enemy 8x6 with their own deploy / blocked / spawn cells")
	if ok:
		var near: Dictionary = CrossBoardPolicy.resolve(asym.battlefield, BoardPosition.new("party", Vector2i(1, 2)), BoardPosition.new("enemy", Vector2i(7, 5)), BoardTargeting.TARGET_SHAPES.SINGLE)
		var off: Dictionary = CrossBoardPolicy.resolve(asym.battlefield, BoardPosition.new("party", Vector2i(1, 2)), BoardPosition.new("enemy", Vector2i(8, 5)), BoardTargeting.TARGET_SHAPES.SINGLE)
		var off_party: Dictionary = CrossBoardPolicy.resolve(asym.battlefield, BoardPosition.new("enemy", Vector2i(0, 0)), BoardPosition.new("party", Vector2i(3, 0)), BoardTargeting.TARGET_SHAPES.SINGLE)
		c._check(near.valid and not off.valid and off.error == "off_board" and not off_party.valid and off_party.error == "off_board", "cross-board targeting uses each board's own bounds (enemy (7,5) valid, (8,5) and party (3,0) off_board)")
	asym.clear()

func _rules_limits() -> void:
	var narrowed := _rules()
	narrowed.board_min_size = Vector2i(5, 5)
	c._check(CombatBattlefield.new(_encounter({"party": {"size": [4, 5]}}), narrowed).error == "encounter_board_size_out_of_range", "a pack that narrows board_min_size rejects smaller encounter boards")
	var widened := _rules()
	widened.board_max_size = Vector2i(16, 14)
	c._check(CombatBattlefield.new(_encounter({"enemy": {"size": [16, 14]}}), widened).valid, "a pack may widen board_max_size up to the 16x16 ceiling")
	for case: Array in [[Vector2i(0, 3), Vector2i(12, 12), Vector2i(5, 5)], [Vector2i(3, 3), Vector2i(17, 12), Vector2i(5, 5)], [Vector2i(6, 6), Vector2i(5, 5), Vector2i(5, 5)], [Vector2i(3, 3), Vector2i(12, 12), Vector2i(13, 5)]]:
		var rules := _rules()
		rules.board_min_size = case[0]
		rules.board_max_size = case[1]
		rules.default_board_size = case[2]
		var battlefield := CombatBattlefield.new(_encounter(), rules)
		c._check(rules.validate_configuration() == "invalid_board_size_limits" and not battlefield.valid and battlefield.error_detail.contains("board sizes"), "rules min %s / max %s / default %s rejected as invalid_board_size_limits" % case)

func _invalid_sizes() -> void:
	var expectations: Array = [
		[{"party": {"size": [2, 2]}}, Vector2i.ZERO, "encounter_board_size_out_of_range", "board \"party\" size 2x2 is outside the allowed 3x3..12x12"],
		[{"enemy": {"size": [13, 5]}}, Vector2i.ZERO, "encounter_board_size_out_of_range", "board \"enemy\" size 13x5"],
		[{"enemy": {"size": [5.5, 5]}}, Vector2i.ZERO, "invalid_encounter_board_size", "board \"enemy\" size"],
		[{"enemy": {"size": "5x5"}}, Vector2i.ZERO, "invalid_encounter_board_size", "not [width, height]"],
		[{}, Vector2i(2, 5), "encounter_board_size_out_of_range", "encounter_board_size 2x5"],
		[{}, Vector2i(0, 4), "invalid_encounter_board_size", "encounter_board_size"],
		[{"shared": {"size": [5, 5]}}, Vector2i.ZERO, "invalid_encounter_board", "encounter_boards key \"shared\""],
	]
	for expected: Array in expectations:
		var battlefield := CombatBattlefield.new(_encounter(expected[0], expected[1]), _rules())
		c._check(not battlefield.valid and battlefield.boards.is_empty() and battlefield.error == expected[2] and battlefield.error_detail.contains("EncounterData \"board_size_probe\"") and battlefield.error_detail.contains(expected[3]), "invalid size %s / legacy %s -> %s: %s" % [expected[0], expected[1], expected[2], battlefield.error_detail])

func _cells_out_of_bounds() -> void:
	var cases: Array = [
		[{"party": {"size": [3, 3], "deploy_cells": [[3, 2]]}}, "board \"party\" deploy_cells [3, 2] is outside the 3x3 board"],
		[{"enemy": {"size": [8, 6], "blocked_cells": [[0, 6]]}}, "board \"enemy\" blocked_cells [0, 6] is outside the 8x6 board"],
		[{"enemy": {"spawn_zone_cells": [[-1, 0]]}}, "board \"enemy\" spawn_zone_cells [-1, 0] is outside the 5x5 board"],
		[{"party": {"size": [4, 3], "initial_fields": [{"field_id": "f", "cells": [[1, 3]]}]}}, "board \"party\" initial_fields f [1, 3]"],
	]
	for case: Array in cases:
		var battlefield := CombatBattlefield.new(_encounter(case[0]), _rules())
		c._check(not battlefield.valid and battlefield.error == "encounter_cell_out_of_bounds" and battlefield.error_detail.contains(case[1]), "out-of-bounds cell rejected with location: %s" % battlefield.error_detail)
	var legacy := _encounter({"party": {"size": [3, 3]}})
	legacy.encounter_deploy_cells.assign([[3, 4]])
	var legacy_field := CombatBattlefield.new(legacy, _rules())
	c._check(legacy_field.error == "encounter_cell_out_of_bounds" and legacy_field.error_detail.contains("board \"party\" deploy_cells [3, 4]"), "legacy cell lists are checked against every board they apply to")
	var wave_encounter := _encounter({"enemy": {"size": [8, 6]}})
	var wave := EncounterWaveData.new()
	wave.wave_units.assign([{"weights": {"x": 1}, "cell": [7, 5]}, {"weights": {"x": 1}, "cell": [8, 0]}])
	wave_encounter.encounter_waves.assign([wave])
	var wave_field := CombatBattlefield.new(wave_encounter, _rules())
	c._check(wave_field.error == "encounter_cell_out_of_bounds" and wave_field.error_detail.contains("wave 0 unit 1 cell on board \"enemy\" [8, 0]"), "wave unit cell outside its (default enemy) board is rejected: %s" % wave_field.error_detail)
	wave.wave_units.assign([{"weights": {"x": 1}, "board_id": "shared"}])
	var bad_board := CombatBattlefield.new(wave_encounter, _rules())
	c._check(bad_board.error == "invalid_encounter_wave_board" and bad_board.error_detail.contains("board_id \"shared\""), "wave unit board_id outside the mode is rejected")
	wave.wave_units.assign([{"weights": {"x": 1}}])
	c._check(CombatBattlefield.new(wave_encounter, _rules()).valid, "wave unit without a cell remains valid (nearest spawn-zone fallback)")

func _layout() -> void:
	var expected: Dictionary = {
		Vector2i(3, 3): [64.0, Vector2(192, 192)],
		Vector2i(5, 5): [56.0, Vector2(280, 280)],
		Vector2i(8, 6): [280.0 / 6.0, Vector2(8, 6) * (280.0 / 6.0)],
		Vector2i(12, 12): [280.0 / 12.0, Vector2(280, 280)],
		Vector2i(12, 3): [460.0 / 12.0, Vector2(460, 3 * 460.0 / 12.0)],
	}
	for board_size: Vector2i in expected:
		var layout: Dictionary = BoardView.compute_layout(board_size)
		var fits: bool = layout.size.x <= BoardView.PANEL_MAX_SIZE.x + 0.01 and layout.size.y <= BoardView.PANEL_MAX_SIZE.y + 0.01
		c._check(is_equal_approx(layout.cell_size, expected[board_size][0]) and layout.size.is_equal_approx(expected[board_size][1]) and fits, "BoardView layout %s -> cell %.2f px, size %s inside the 460x280 slot" % [board_size, layout.cell_size, layout.size])
	c._check(BoardCombatPresentation.view_position(0, 2, Vector2(280, 280)) == Vector2(160, 170) and BoardCombatPresentation.view_position(1, 2, Vector2(280, 280)) == Vector2(730, 170) and BoardCombatPresentation.view_position(0, 1, Vector2(280, 280)) == Vector2(450, 170), "5x5 views are centred in their dual / single slots")
	var party_pos: Vector2 = BoardCombatPresentation.view_position(0, 2, Vector2(192, 192))
	var enemy_layout: Dictionary = BoardView.compute_layout(Vector2i(8, 6))
	var enemy_pos: Vector2 = BoardCombatPresentation.view_position(1, 2, enemy_layout.size)
	c._check(party_pos == Vector2(204, 214) and enemy_pos.x >= 640 and enemy_pos.x + enemy_layout.size.x <= 1100.01 and party_pos.x + 192 < enemy_pos.x and enemy_pos.y + enemy_layout.size.y <= 450.01, "asymmetric 3x3 / 8x6 views stay inside separate slots: %s, %s" % [party_pos, enemy_pos])
	var view := BoardView.new()
	view._resize(BoardData.new(Vector2i(8, 6)))
	var rect: Rect2 = view.cell_rect(Vector2i(7, 5))
	c._check(is_equal_approx(view.cell_size, enemy_layout.cell_size) and view.size.is_equal_approx(enemy_layout.size) and view.cell_at(rect.get_center()) == Vector2i(7, 5) and rect.end.is_equal_approx(view.size) and view.cell_at(view.size + Vector2.ONE) == Vector2i(8, 6), "BoardView maps the last 8x6 cell to its bottom-right corner and back")
	view.free()
	c._check(is_equal_approx(BoardActorPresentation.actor_scale_for(64.0), 0.5) and is_equal_approx(BoardActorPresentation.actor_scale_for(56.0), 0.4375) and is_equal_approx(BoardActorPresentation.actor_scale_for(280.0 / 12.0), 280.0 / 12.0 / 128.0), "actor scale follows the cell size (3x3 0.5, 5x5 0.4375, 12x12 ~0.18)")
