## One board surface. Gameplay positions always include board_id; actor visuals are owned by
## BoardActorPresentation, so this draws terrain, footprints and previews, never surrogate tokens.
extends Control
class_name BoardView

const PANEL_POSITION: Vector2 = Vector2(70, 170)
const PANEL_MAX_SIZE: Vector2 = Vector2(460, 280)
const CELL_SIZE_MAX: float = 64.0

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

var board_id: String = "shared"
var panel_position: Vector2 = PANEL_POSITION
var hovered_enemy: Enemy = null
var _preview_board_id: String = ""
var _preview_cell: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE
var cell_size: float = CELL_SIZE_MAX
var hovered_cell: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE
var _last_selected_card: Variant = null
var _field_textures: Dictionary[String, Texture2D] = {}
## Movement preview cache: reachable_active is a weighted state search, so it is recomputed only
## after a gameplay signal or when the acting unit's movement state differs, never every frame.
var _movement_cache: Dictionary = {}
var _movement_cache_key: String = ""
var _movement_dirty: bool = true
## Number of reachable_active searches run for the movement preview (headless contract checks).
var movement_query_count: int = 0

func _ready() -> void:
	position = panel_position
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	Signals.board_cell_hovered.connect(_on_board_hovered)
	Signals.enemy_hovered.connect(_on_enemy_hovered)
	Signals.field_created.connect(_on_board_changed.unbind(1))
	Signals.field_removed.connect(_on_board_changed.unbind(1))
	Signals.field_changed.connect(_on_board_changed.unbind(1))
	Signals.board_changed.connect(_on_board_changed.unbind(1))
	Signals.unit_moved.connect(_on_board_changed.unbind(3))
	Signals.timeline_changed.connect(_on_board_changed)
	Signals.enemy_intent_changed.connect(_on_board_changed)
	Signals.unit_action_started.connect(_on_board_changed.unbind(1))
	Signals.unit_action_ended.connect(_on_board_changed.unbind(1))
	Signals.enemy_killed.connect(_on_board_changed.unbind(1))
	Signals.unit_removed.connect(_on_board_changed.unbind(1))
	Signals.card_played.connect(_on_board_changed.unbind(1))
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_combat_ended)

func get_board() -> BoardData:
	var battlefield: CombatBattlefield = CombatBattlefield.get_active()
	return battlefield.get_board(board_id) if battlefield != null else null

func _process(_delta: float) -> void:
	var board: BoardData = get_board()
	var director: CombatDirector = Global.get_combat_director()
	var should_show: bool = board != null and director != null and director.is_running
	if should_show != visible:
		visible = should_show
		_movement_dirty = true
		_resize(board, true)
	if visible:
		# Cheap layout check only; redraws are driven by signals, hover and selection changes.
		_resize(board)
		var selected: Variant = HandManager.hand.current_selected_card if HandManager.hand != null else null
		if selected != _last_selected_card:
			_last_selected_card = selected
			queue_redraw()

## Square cells as large as fit PANEL_MAX_SIZE (capped at CELL_SIZE_MAX) for any board size.
static func compute_layout(board_size: Vector2i) -> Dictionary:
	var cells: Vector2 = Vector2(max(1, board_size.x), max(1, board_size.y))
	var fitted: float = minf(CELL_SIZE_MAX, minf(PANEL_MAX_SIZE.x / cells.x, PANEL_MAX_SIZE.y / cells.y))
	return {"cell_size": fitted, "size": cells * fitted}

func _resize(board: BoardData, force_redraw: bool = false) -> void:
	if board == null:
		return
	var layout: Dictionary = compute_layout(board.size)
	var new_cell_size: float = layout.cell_size
	var new_size: Vector2 = layout.size
	if not force_redraw and is_equal_approx(new_cell_size, cell_size) and new_size.is_equal_approx(size):
		return
	cell_size = new_cell_size
	size = new_size
	queue_redraw()

func _on_board_changed() -> void:
	_movement_dirty = true
	if visible:
		_resize(get_board(), true)
		_update_field_tooltip()

func _on_combat_ended() -> void:
	_movement_cache = {}
	_movement_cache_key = ""
	_movement_dirty = true
	hovered_cell = BaseCombatant.BOARD_ANCHOR_NONE
	_preview_cell = BaseCombatant.BOARD_ANCHOR_NONE
	_preview_board_id = ""
	hovered_enemy = null
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
				Signals.board_cell_hovered.emit(board_id, cell)
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var cell: Vector2i = cell_at(event.position)
		if board.is_in_bounds(cell):
			accept_event()
			Signals.board_cell_clicked.emit(board_id, cell)

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
		_draw_fields(board, cell)
	var acting: BaseCombatant = director.acting_unit
	var selected_card: Card = HandManager.hand.current_selected_card if HandManager.hand != null else null
	if selected_card != null and acting != null:
		var battlefield: CombatBattlefield = director.battlefield
		var hovered_board: BoardData = battlefield.get_board(_preview_board_id) if battlefield != null else null
		if hovered_board != null and hovered_board.is_in_bounds(_preview_cell):
			var effect_board: BoardData = BoardTargeting.target_board_for_shape(hovered_board, acting, BoardCardOptions.shape_of(selected_card.card_data))
			if effect_board == board:
				_draw_cells(BoardTargeting.resolve_card_cells(hovered_board, acting, selected_card.card_data, _preview_cell), COLOR_SHAPE)
	elif acting != null and board.has_unit(acting) and acting.faction == BaseCombatant.FACTIONS.PARTY and director.is_player_action_pending():
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
	var module: Variant = director.board_module
	var budget: int = module.get_move_budget(unit) if module != null else 0
	if budget <= 0:
		return
	var reachable: Dictionary = movement_preview(board, unit)
	var font: Font = get_theme_default_font()
	for cell: Vector2i in reachable:
		if (reachable[cell] as Array).is_empty():
			continue
		var rect: Rect2 = cell_rect(cell)
		var paid: int = _paid_steps(board, unit, reachable[cell])
		if paid == 0:
			draw_rect(rect, COLOR_FREE_MOVE, true)
		else:
			for offset: float in [0.25, 0.5, 0.75]:
				draw_line(rect.position + Vector2(rect.size.x * offset, 0), rect.position + Vector2(0, rect.size.y * offset), COLOR_PAID_MOVE, 1.5)
			var extra_ticks: int = director.timeline.wait_for(paid * director.rules.extra_move_delay_per_cell, unit.speed) if director.rules.extra_move_delay_per_cell > 0 else 0
			draw_string(font, rect.position + Vector2(2, rect.size.y - 3), "+%d" % extra_ticks, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_PAID_MOVE)
	if reachable.has(hovered_cell):
		_draw_path(unit.board_anchor, reachable[hovered_cell], COLOR_PATH)

## Cached reachable_active of the acting unit; the same paths are executed on click.
func movement_preview(board: BoardData, unit: BaseCombatant) -> Dictionary:
	var key: String = "%d|%s|%s|%d|%d" % [unit.get_instance_id(), board.board_id, unit.board_anchor, unit.move_points, unit.paid_cells_this_action]
	if _movement_dirty or key != _movement_cache_key:
		_movement_cache = board.reachable_active(unit)
		_movement_cache_key = key
		_movement_dirty = false
		movement_query_count += 1
	return _movement_cache

## Hovered enemy: hit cells, planned path and a ghost token at its planned move cell.
func _draw_enemy_preview(board: BoardData, director: CombatDirector) -> void:
	if director.threat_preview == null:
		return
	var enemy: Enemy = hovered_enemy
	if not is_instance_valid(enemy):
		enemy = board.get_unit_at(hovered_cell) as Enemy
	if enemy == null:
		return
	var plan: Dictionary = director.threat_preview.get_plan(enemy)
	if plan.is_empty():
		return
	var hit_cells: Array[Vector2i] = []
	hit_cells.assign(plan.get("cells", []))
	if str(plan.get("target_board_id", enemy.board_id)) == board_id:
		_draw_cells(hit_cells, COLOR_THREAT)
	var movement: Dictionary = enemy_movement_preview(enemy)
	if movement.has_destination:
		if not movement.path.is_empty():
			_draw_path(enemy.board_anchor, movement.path, COLOR_ENEMY)
		var ghost: Rect2 = Rect2(Vector2(movement.cell) * cell_size, Vector2(enemy.footprint) * cell_size).grow(-3)
		draw_rect(ghost, Color(COLOR_ENEMY, 0.35), true)
		if movement.teleport:
			draw_arc(ghost.get_center(), minf(ghost.size.x, ghost.size.y) * 0.4, 0, TAU, 24, COLOR_ENEMY, 2.0)
			draw_string(get_theme_default_font(), ghost.position + Vector2(2, 12), "TP", HORIZONTAL_ALIGNMENT_LEFT, ghost.size.x, 10, Color.WHITE)

## The same descriptor drives drawing and headless contract checks, including pathless teleport.
func enemy_movement_preview(enemy: Enemy) -> Dictionary:
	var result: Dictionary = {"has_destination": false, "cell": BaseCombatant.BOARD_ANCHOR_NONE, "path": [], "teleport": false}
	var director: CombatDirector = Global.get_combat_director()
	if not is_instance_valid(enemy) or director == null or director.threat_preview == null or get_board() == null:
		return result
	var plan: Dictionary = director.threat_preview.get_plan(enemy)
	var cell: Vector2i = plan.get("move_cell", BaseCombatant.BOARD_ANCHOR_NONE)
	var teleport: bool = enemy.enemy_data.get_current_intent().enemy_intent_move == EnemyIntentData.MOVE_MODES.TELEPORT
	result.merge({"cell": cell, "path": plan.get("path", []), "teleport": teleport}, true)
	result.has_destination = enemy.board_id == board_id and get_board().is_in_bounds(cell) and (cell != enemy.board_anchor or teleport)
	return result

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
	draw_rect(rect, Color(color, 0.35), false, 1.0)
	if is_acting:
		draw_rect(rect, COLOR_ACTING, false, 2.0)

## Global footprint bottom-center used by the complete sprite/HUD/hitbox subtree.
func unit_footpoint(unit: BaseCombatant) -> Vector2:
	return global_position + Vector2(unit.board_anchor.x + unit.footprint.x * 0.5, unit.board_anchor.y + unit.footprint.y) * cell_size - Vector2(0, 4)

func _on_board_hovered(id: String, cell: Vector2i) -> void:
	_preview_board_id = id
	_preview_cell = cell
	hovered_cell = cell if id == board_id else BaseCombatant.BOARD_ANCHOR_NONE
	var battlefield: CombatBattlefield = CombatBattlefield.get_active()
	var source: BoardData = battlefield.get_board(id) if battlefield != null else null
	hovered_enemy = source.get_unit_at(cell) as Enemy if source != null else null
	_update_field_tooltip()
	queue_redraw()

func _on_enemy_hovered(enemy: Enemy) -> void:
	hovered_enemy = enemy
	queue_redraw()

func _paid_steps(board: BoardData, unit: BaseCombatant, path: Array) -> int:
	var remaining: int = unit.move_points
	var previous: Vector2i = unit.board_anchor
	var paid: int = 0
	for cell: Vector2i in path:
		var cost: int = board.step_cost(unit, previous, cell)
		if remaining < cost:
			paid += 1
		remaining = maxi(0, remaining - cost)
		previous = cell
	return paid

## Content-defined field colors/icons stay beneath footprints and all actor subtrees.
func _draw_fields(board: BoardData, cell: Vector2i) -> void:
	var fields: Array[FieldInstance] = board.get_fields(cell)
	if fields.is_empty():
		return
	var rect: Rect2 = cell_rect(cell).grow(-2)
	var color: Color = Color(0.55, 0.35, 0.8, 0.35)
	var data: FieldData = fields[0].field_data
	if data.field_color_id != "":
		var color_data: ColorData = Global.get_color_data(data.field_color_id)
		if color_data != null:
			color = Color(color_data.color, 0.35)
	draw_rect(rect, color, true)
	var icon_size: float = minf(18.0, rect.size.x / 3.0)
	for index: int in fields.size():
		var field: FieldData = fields[index].field_data
		var icon_path: String = field.field_icon_texture_path
		var at: Vector2 = rect.position + Vector2(index % 3, index / 3) * icon_size
		if at.y + icon_size > rect.end.y:
			break
		if icon_path != "":
			if not _field_textures.has(icon_path):
				_field_textures[icon_path] = FileLoader.load_texture(icon_path)
			var texture: Texture2D = _field_textures[icon_path]
			if texture != null:
				draw_texture_rect(texture, Rect2(at, Vector2.ONE * icon_size), false)
		else:
			draw_string(get_theme_default_font(), at + Vector2(1, 10), field.field_name.substr(0, 2), HORIZONTAL_ALIGNMENT_LEFT, icon_size, 9, Color.WHITE)

func _update_field_tooltip() -> void:
	tooltip_text = field_tooltip(hovered_cell)

func field_tooltip(cell: Vector2i) -> String:
	var board: BoardData = get_board()
	var director: CombatDirector = Global.get_combat_director()
	if board == null or director == null or not board.is_in_bounds(cell):
		return ""
	var lines: PackedStringArray = []
	for instance: FieldInstance in board.get_fields(cell):
		var remaining: String = "permanent" if instance.expires_tick < 0 else "%d ticks" % maxi(0, instance.expires_tick - director.current_tick)
		lines.append("%s x%d (%s)" % [instance.field_data.field_name, instance.stacks, remaining])
	return "\n".join(lines)
