## Self-drawn combat board (combat framework Phase 2): grid, units, movement preview and enemy
## intent preview. Created by Combat (top-left panel) and only visible while the CombatDirector runs.
## Input: left click -> Signals.cell_clicked, mouse motion -> Signals.cell_hovered (Hand turns these
## into card targets or movement). Free move cells are filled, paid cells hatched with their extra
## wait in ticks; hovering a reachable cell shows the path; with a card selected the card's shape is
## shown; hovering an enemy shows its planned path, a ghost at planned_move_cell and its hit cells.
## Combatant sprites keep their screen positions; units appear here as labelled tokens.
extends Control
class_name BoardView

const PANEL_POSITION: Vector2 = Vector2(16, 120)
const PANEL_MAX_SIZE: Vector2 = Vector2(184, 200)
const CELL_SIZE_MAX: float = 28.0

const COLOR_CELL: Color = Color(0.16, 0.17, 0.2, 0.85)
const COLOR_GRID: Color = Color(0.45, 0.47, 0.52, 0.9)
const COLOR_DEPLOY: Color = Color(0.2, 0.3, 0.45, 0.85)
const COLOR_BLOCKED: Color = Color(0.05, 0.05, 0.05, 0.95)
const COLOR_PARTY: Color = Color(0.25, 0.7, 0.35)
const COLOR_ENEMY: Color = Color(0.8, 0.25, 0.25)
const COLOR_NEUTRAL: Color = Color(0.6, 0.6, 0.6)
const COLOR_ACTING: Color = Color(1.0, 0.9, 0.3)
const COLOR_FREE_MOVE: Color = Color(0.3, 0.6, 1.0, 0.45)
const COLOR_PAID_MOVE: Color = Color(0.95, 0.65, 0.2, 0.8)
const COLOR_PATH: Color = Color(1.0, 1.0, 1.0, 0.9)
const COLOR_SHAPE: Color = Color(1.0, 0.85, 0.3, 0.45)
const COLOR_THREAT: Color = Color(1.0, 0.3, 0.3, 0.35)

var cell_size: float = CELL_SIZE_MAX
var hovered_cell: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE
var _last_selected_card: Variant = null

func _ready() -> void:
	position = PANEL_POSITION
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	Signals.unit_moved.connect(_on_board_changed.unbind(3))
	Signals.timeline_changed.connect(_on_board_changed)
	Signals.enemy_intent_changed.connect(_on_board_changed)
	Signals.unit_action_started.connect(_on_board_changed.unbind(1))
	Signals.unit_action_ended.connect(_on_board_changed.unbind(1))
	Signals.enemy_killed.connect(_on_board_changed.unbind(1))
	Signals.unit_removed.connect(_on_board_changed.unbind(1))
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_combat_ended)

func get_board() -> BoardData:
	return BoardData.get_active()

func _process(_delta: float) -> void:
	var board: BoardData = get_board()
	var director: CombatDirector = Global.get_combat_director()
	var should_show: bool = board != null and director != null and director.is_running
	if should_show != visible:
		visible = should_show
		_resize(board)
	if visible:
		var selected: Variant = HandManager.hand.current_selected_card if HandManager.hand != null else null
		if selected != _last_selected_card:
			_last_selected_card = selected
			queue_redraw()

func _resize(board: BoardData) -> void:
	if board == null:
		return
	cell_size = min(CELL_SIZE_MAX, min(PANEL_MAX_SIZE.x / board.size.x, PANEL_MAX_SIZE.y / board.size.y))
	size = Vector2(board.size) * cell_size
	queue_redraw()

func _on_board_changed() -> void:
	if visible:
		_resize(get_board())

func _on_combat_ended() -> void:
	hovered_cell = BaseCombatant.BOARD_ANCHOR_NONE
	visible = false

func cell_at(local_position: Vector2) -> Vector2i:
	if cell_size <= 0.0:
		return BaseCombatant.BOARD_ANCHOR_NONE
	return Vector2i(floori(local_position.x / cell_size), floori(local_position.y / cell_size))

func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * cell_size, Vector2(cell_size, cell_size))

func _gui_input(event: InputEvent) -> void:
	var board: BoardData = get_board()
	if board == null:
		return
	if event is InputEventMouseMotion:
		var cell: Vector2i = cell_at(event.position)
		if not board.is_in_bounds(cell):
			cell = BaseCombatant.BOARD_ANCHOR_NONE
		if cell != hovered_cell:
			hovered_cell = cell
			if cell != BaseCombatant.BOARD_ANCHOR_NONE:
				Signals.cell_hovered.emit(cell)
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var cell: Vector2i = cell_at(event.position)
		if board.is_in_bounds(cell):
			accept_event()
			Signals.cell_clicked.emit(cell)

func _draw() -> void:
	var board: BoardData = get_board()
	var director: CombatDirector = Global.get_combat_director()
	if board == null or director == null:
		return
	for cell: Vector2i in board.all_cells():
		var cell_data: BoardCellData = board.get_cell(cell)
		var color: Color = COLOR_CELL
		if cell_data.is_blocked:
			color = COLOR_BLOCKED
		elif cell_data.is_deploy_zone:
			color = COLOR_DEPLOY
		draw_rect(cell_rect(cell), color, true)
	var acting: BaseCombatant = director.acting_unit
	var selected_card: Card = HandManager.hand.current_selected_card if HandManager.hand != null else null
	if selected_card != null and acting != null and board.has_unit(acting) and board.is_in_bounds(hovered_cell):
		_draw_cells(BoardTargeting.cells_in_shape(board, acting.board_anchor, hovered_cell, selected_card.card_data.card_shape, selected_card.card_data.card_range), COLOR_SHAPE)
	elif acting != null and acting.faction == BaseCombatant.FACTIONS.PARTY and director.is_player_action_pending():
		_draw_movement(board, director, acting)
	_draw_enemy_preview(board, director)
	for unit: BaseCombatant in board.get_units():
		_draw_unit(board, unit, unit == acting)
	for x: int in board.size.x + 1:
		draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, board.size.y * cell_size), COLOR_GRID, 1.0)
	for y: int in board.size.y + 1:
		draw_line(Vector2(0, y * cell_size), Vector2(board.size.x * cell_size, y * cell_size), COLOR_GRID, 1.0)

func _draw_cells(cell_list: Array[Vector2i], color: Color) -> void:
	for cell: Vector2i in cell_list:
		draw_rect(cell_rect(cell), color, true)

## Reachable cells of the acting party unit: free (filled) and paid (hatched, "+N" extra ticks).
func _draw_movement(board: BoardData, director: CombatDirector, unit: BaseCombatant) -> void:
	var budget: int = director.get_move_budget(unit)
	if budget <= 0:
		return
	var reachable: Dictionary = board.reachable_cells(unit, budget)
	var font: Font = get_theme_default_font()
	for cell: Vector2i in reachable:
		var length: int = len(reachable[cell])
		if length == 0:
			continue
		var rect: Rect2 = cell_rect(cell)
		if length <= unit.move_points:
			draw_rect(rect, COLOR_FREE_MOVE, true)
		else:
			var paid: int = length - unit.move_points
			for offset: float in [0.25, 0.5, 0.75]:
				draw_line(rect.position + Vector2(rect.size.x * offset, 0), rect.position + Vector2(0, rect.size.y * offset), COLOR_PAID_MOVE, 1.5)
			var extra_ticks: int = director.timeline.wait_for(paid * director.rules.extra_move_delay_per_cell, unit.speed) if director.rules.extra_move_delay_per_cell > 0 else 0
			draw_string(font, rect.position + Vector2(2, rect.size.y - 3), "+%d" % extra_ticks, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_PAID_MOVE)
	if reachable.has(hovered_cell):
		_draw_path(unit.board_anchor, reachable[hovered_cell], COLOR_PATH)

## Hovered enemy: hit cells, planned path and a ghost token at its planned move cell.
func _draw_enemy_preview(board: BoardData, director: CombatDirector) -> void:
	if not board.is_in_bounds(hovered_cell) or director.threat_preview == null:
		return
	var enemy: Enemy = board.get_unit_at(hovered_cell) as Enemy
	if enemy == null:
		return
	var plan: Dictionary = director.threat_preview.get_plan(enemy)
	if plan.is_empty():
		return
	var hit_cells: Array[Vector2i] = []
	hit_cells.assign(plan.get("cells", []))
	_draw_cells(hit_cells, COLOR_THREAT)
	var path: Array[Vector2i] = []
	path.assign(plan.get("path", []))
	if not path.is_empty():
		_draw_path(enemy.board_anchor, path, COLOR_ENEMY)
		var ghost: Rect2 = Rect2(Vector2(plan["move_cell"]) * cell_size, Vector2(enemy.footprint) * cell_size).grow(-3)
		draw_rect(ghost, Color(COLOR_ENEMY, 0.35), true)

func _draw_path(start: Vector2i, path: Array, color: Color) -> void:
	var previous: Vector2 = cell_rect(start).get_center()
	for cell: Vector2i in path:
		var point: Vector2 = cell_rect(cell).get_center()
		draw_line(previous, point, color, 2.0)
		previous = point

func _draw_unit(board: BoardData, unit: BaseCombatant, is_acting: bool) -> void:
	if not unit.is_alive():
		return
	var rect: Rect2 = Rect2(Vector2(unit.board_anchor) * cell_size, Vector2(unit.footprint) * cell_size).grow(-3)
	var color: Color = COLOR_NEUTRAL
	if unit.faction == BaseCombatant.FACTIONS.PARTY:
		color = COLOR_PARTY
	elif unit.faction == BaseCombatant.FACTIONS.ENEMY:
		color = COLOR_ENEMY
	draw_rect(rect, color, true)
	if is_acting:
		draw_rect(rect, COLOR_ACTING, false, 2.0)
	var label: String = unit.get_unit_display_name().substr(0, 2)
	draw_string(get_theme_default_font(), rect.position + Vector2(2, rect.size.y * 0.5 + 4), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 2, 10, Color.WHITE)
