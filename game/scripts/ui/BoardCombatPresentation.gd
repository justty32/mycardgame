## Optional board surfaces, actor mapping and Undo UI. No instance exists for NONE combat.
extends Node
class_name BoardCombatPresentation

var director: CombatDirector = null
var module: BoardCombatModule = null
var combat: Control = null
var board_view: BoardView = null
var board_views: Dictionary[String, BoardView] = {}
var actor_presentation: BoardActorPresentation = null
var undo_move_button: Button = null
var _view_board_ids: Array = []
var _stopped: bool = true

func setup(value: CombatDirector, board_module: BoardCombatModule) -> void:
	director = value
	module = board_module
	combat = director.get_parent()
	_stopped = false
	Signals.combat_ended.connect(_on_display_ended)
	Signals.run_ended.connect(_on_display_ended)
	actor_presentation = BoardActorPresentation.new()
	actor_presentation.name = "BoardActorPresentation"
	add_child(actor_presentation)
	undo_move_button = Button.new()
	undo_move_button.name = "UndoMoveButton"
	undo_move_button.text = "Undo Move"
	undo_move_button.position = Vector2(1080, 576)
	undo_move_button.size = Vector2(112, 40)
	undo_move_button.visible = false
	undo_move_button.button_up.connect(_on_undo_move_button_up)
	combat.add_child(undo_move_button)
	module.card_adapter.bind_hand(combat.get_node("Hand") as Hand)
	set_process(true)
	sync_board_views()

## Rebuild grid surfaces only; actual actor parents/registry identities remain stable.
func sync_board_views() -> void:
	if _stopped or director == null:
		return
	var battlefield: CombatBattlefield = director.battlefield
	if battlefield == null:
		return
	var ids: Array = battlefield.boards.keys()
	if ids == _view_board_ids:
		return
	_view_board_ids = ids.duplicate()
	actor_presentation.clear()
	for old_view: BoardView in board_views.values():
		old_view.queue_free()
	board_views.clear()
	board_view = null
	for index: int in ids.size():
		var view := BoardView.new()
		view.board_id = ids[index]
		view.panel_position = Vector2(70 + index * 570, 170) if ids.size() > 1 else Vector2(360, 170)
		view.position = view.panel_position
		view.name = "BoardView_" + ids[index]
		combat.add_child(view)
		# Grid hit surfaces precede real actor subtrees in Control input tree order.
		combat.move_child(view, combat.get_node("Player").get_index())
		view._resize(battlefield.get_board(ids[index]))
		board_views[ids[index]] = view
		if index == 0:
			board_view = view
	actor_presentation.views = board_views
	actor_presentation.sync_positions(false)

func _process(_delta: float) -> void:
	if _stopped or director == null:
		return
	if director.is_running:
		sync_board_views()
	undo_move_button.visible = director.is_running and director.rules != null and director.rules.move_undo_allowed
	undo_move_button.disabled = module == null or not module.can_player_undo_move()

func _on_undo_move_button_up() -> void:
	if not _stopped and module != null:
		module.request_player_undo_move()

## Runtime may stop on hero death before the death animation ends. Retain its final pose.
func stop() -> void:
	_stopped = true
	set_process(false)
	if module != null and module.card_adapter != null:
		module.card_adapter.unbind_hand()
	if is_instance_valid(undo_move_button):
		undo_move_button.visible = false
		undo_move_button.disabled = true
	for view: BoardView in board_views.values():
		view.set_process(false)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.visible = false
	if is_instance_valid(actor_presentation):
		actor_presentation.set_process(false)
		# Director handles player_killed before actor signal subscribers. Snap dead actors
		# to their already committed target before releasing them into the retired set.
		actor_presentation.snap_dead_actors()
		actor_presentation.clear()

func _on_display_ended() -> void:
	clear()

## Final disposal at combat/run end, new setup or scene exit restores the persistent hero.
func clear() -> void:
	stop()
	if Signals.combat_ended.is_connected(_on_display_ended):
		Signals.combat_ended.disconnect(_on_display_ended)
	if Signals.run_ended.is_connected(_on_display_ended):
		Signals.run_ended.disconnect(_on_display_ended)
	if is_instance_valid(actor_presentation):
		actor_presentation._on_display_ended()
		actor_presentation.queue_free()
	actor_presentation = null
	for view: BoardView in board_views.values():
		view.queue_free()
	board_views.clear()
	board_view = null
	_view_board_ids.clear()
	if is_instance_valid(undo_move_button):
		undo_move_button.queue_free()
	undo_move_button = null
	director = null
	module = null
	combat = null

func _exit_tree() -> void:
	clear()
