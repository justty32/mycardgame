## Owns only optional spatial input connections. No card fees, queues or pile mutation.
extends RefCounted
class_name BoardCardInput

var adapter_ref: WeakRef
var hand_ref: WeakRef

func _init(adapter: BoardCardAdapter, hand: Hand) -> void:
	adapter_ref = weakref(adapter)
	hand_ref = weakref(hand)

func bind() -> void:
	Signals.cell_clicked.connect(_on_cell_clicked)
	Signals.cell_hovered.connect(_on_cell_hovered)
	Signals.board_cell_clicked.connect(_on_board_cell_clicked)
	Signals.board_cell_hovered.connect(_on_board_cell_hovered)

func unbind() -> void:
	for connection: Array in [[Signals.cell_clicked, _on_cell_clicked], [Signals.cell_hovered, _on_cell_hovered], [Signals.board_cell_clicked, _on_board_cell_clicked], [Signals.board_cell_hovered, _on_board_cell_hovered]]:
		if connection[0].is_connected(connection[1]):
			connection[0].disconnect(connection[1])

func _on_cell_clicked(cell: Vector2i) -> void:
	_on_board_cell_clicked("", cell)

func _on_cell_hovered(cell: Vector2i) -> void:
	_on_board_cell_hovered("", cell)

func _on_board_cell_clicked(id: String, cell: Vector2i) -> void:
	var adapter: BoardCardAdapter = adapter_ref.get_ref()
	var hand: Hand = hand_ref.get_ref()
	if adapter != null and is_instance_valid(hand):
		adapter.handle_cell_clicked(hand, id, cell)

func _on_board_cell_hovered(id: String, cell: Vector2i) -> void:
	var adapter: BoardCardAdapter = adapter_ref.get_ref()
	var hand: Hand = hand_ref.get_ref()
	if adapter != null and is_instance_valid(hand):
		adapter.handle_cell_hovered(hand, id, cell)

static func click(adapter: BoardCardAdapter, hand: Hand, id: String, cell: Vector2i) -> void:
	if hand.current_card_pick_action != null:
		return
	var acting: BaseCombatant = hand._get_acting_unit()
	if id == "" and acting != null:
		id = acting.board_id
	if hand.current_selected_card != null:
		var board: BoardData = adapter._battlefield().get_board(id)
		if board == null:
			hand.last_target_rejection = "invalid_board"
			return
		hand.attempt_play_selected_card({"target": board.get_unit_at(cell), "cell": cell, "id": id})
		return
	if hand.hand_disabled or hand.performing_card_right_click:
		return
	var director: CombatDirector = Global.get_combat_director()
	if director != null and acting != null and acting.board_id == id:
		director.request_player_move(cell, id)

static func hover(adapter: BoardCardAdapter, hand: Hand, id: String, cell: Vector2i) -> void:
	if hand.current_selected_card == null:
		return
	var acting: BaseCombatant = hand._get_acting_unit()
	if id == "" and acting != null:
		id = acting.board_id
	var board: BoardData = adapter._battlefield().get_board(id)
	if board != null:
		hand.current_selected_card.update_card_display(board.get_unit_at(cell) as Enemy)
