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

## Optional explicit slots for internal callers; no serialized N-board policy is introduced.
var layout_slots: Dictionary[String, Rect2] = {}
var layout_error: String = ""

## Compatibility forwarding for callers that still ask for an indexed one/two-board position.
static func view_position(index: int, count: int, view_size: Vector2) -> Vector2:
	var ids: Array = ["single"] if count == 1 else ["left", "right"]
	var slots: Dictionary[String, Rect2] = BoardLayout.compatibility_slots(ids)
	return BoardLayout.centered_position(slots[ids[clampi(index, 0, ids.size() - 1)]], view_size)

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
func sync_board_views() -> bool:
	if _stopped or director == null:
		return false
	var battlefield: CombatBattlefield = director.battlefield
	if battlefield == null:
		return false
	var ids: Array = battlefield.boards.keys()
	var slots: Dictionary[String, Rect2] = layout_slots
	if slots.is_empty():
		slots = BoardLayout.compatibility_slots(ids)
	# A missing presentation policy must not silently truncate or overlap a board collection.
	layout_error = ""
	for id: String in ids:
		if not slots.has(id) or not BoardLayout.valid_slot(slots[id]):
			layout_error = "invalid_layout_slot:" + id
			return false
	var changed: bool = ids != _view_board_ids
	if changed:
		_view_board_ids = ids.duplicate()
		# Reordering existing IDs retains their surfaces and actor mapping.
		for old_id: String in board_views.keys():
			if not ids.has(old_id):
				board_views[old_id].queue_free()
				board_views.erase(old_id)
		board_view = null
	for index: int in ids.size():
		var id: String = ids[index]
		var view: BoardView = board_views.get(id)
		if view == null:
			view = BoardView.new()
			view.board_id = id
			view.name = "BoardView_" + id
			combat.add_child(view)
			# Grid hit surfaces precede real actor subtrees in Control input tree order.
			combat.move_child(view, combat.get_node("Player").get_index())
			board_views[id] = view
		view.set_layout_slot(slots[id], battlefield.get_board(id))
		if index == 0:
			board_view = view
	actor_presentation.views = board_views
	if changed:
		actor_presentation.sync_positions(false)
	return true

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
	layout_slots.clear()
	if is_instance_valid(undo_move_button):
		undo_move_button.queue_free()
	undo_move_button = null
	director = null
	module = null
	combat = null

func _exit_tree() -> void:
	clear()
