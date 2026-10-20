## Optional combat component, composed by Combat rather than by the CTB core.
## An unmounted combat has no BoardController, FieldController or ThreatPreview.
extends Node
class_name BoardCombatModule

var director: CombatDirector = null
var board_controller: BoardController = null
var threat_preview: ThreatPreview = null
var presentation: BoardCombatPresentation = null
## Changes on every clear/setup; queued requests cannot survive reuse of this same Node.
var generation: int = 0
## Retained weakly after clear so a later tree exit can detach the old instance safely.
var _director_ref: WeakRef = null

func setup(combat_director: CombatDirector, encounter: EncounterData) -> bool:
	clear()
	director = combat_director
	_director_ref = weakref(combat_director)
	board_controller = BoardController.new(director.rules)
	if not board_controller.setup(encounter):
		clear()
		return false
	threat_preview = ThreatPreview.new(director)
	Signals.unit_moved.connect(_on_unit_moved)
	Signals.field_created.connect(_on_field_changed)
	Signals.field_removed.connect(_on_field_changed)
	Signals.field_changed.connect(_on_field_changed)
	Signals.board_changed.connect(_on_board_changed)
	presentation = BoardCombatPresentation.new()
	add_child(presentation)
	presentation.setup(director, self)
	return true

func clear(preserve_presentation: bool = false) -> void:
	generation += 1
	if Signals.unit_moved.is_connected(_on_unit_moved):
		Signals.unit_moved.disconnect(_on_unit_moved)
	if Signals.field_created.is_connected(_on_field_changed):
		Signals.field_created.disconnect(_on_field_changed)
	if Signals.field_removed.is_connected(_on_field_changed):
		Signals.field_removed.disconnect(_on_field_changed)
	if Signals.field_changed.is_connected(_on_field_changed):
		Signals.field_changed.disconnect(_on_field_changed)
	if Signals.board_changed.is_connected(_on_board_changed):
		Signals.board_changed.disconnect(_on_board_changed)
	if is_instance_valid(presentation):
		if preserve_presentation:
			presentation.stop()
		else:
			presentation.clear()
			presentation.queue_free()
			presentation = null
	if board_controller != null:
		# Presentation has captured the death pose. Release only this module's
		# occupancy so a persistent hero cannot enter NONE with a stale anchor.
		if board_controller.battlefield != null:
			for board: BoardData in board_controller.battlefield.boards.values():
				for unit: BaseCombatant in board.get_units():
					board.remove(unit)
					unit.board_id = ""
		board_controller.clear()
	board_controller = null
	threat_preview = null
	director = null

func _exit_tree() -> void:
	var attached_director: CombatDirector = _director_ref.get_ref() as CombatDirector if _director_ref != null else null
	clear()
	if is_instance_valid(attached_director):
		attached_director.detach_board_module(self)
	_director_ref = null

## Admission of a regular summon. Missing board membership in mounted mode is not NONE.
func prepare_spawned_unit(unit: BaseCombatant) -> bool:
	if board_controller == null or board_controller.battlefield == null:
		return false
	if board_controller.get_board_for_unit(unit) != null:
		return true
	return board_controller.place_unit_nearest(unit, board_controller.default_spawn_origin())

func on_unit_spawned(unit: BaseCombatant) -> void:
	var fields: FieldController = FieldController.get_for_unit(unit)
	if fields != null:
		fields.on_unit_spawned(unit)

func on_unit_removed(unit: BaseCombatant) -> void:
	var current: BoardData = board_controller.get_board_for_unit(unit) if board_controller != null else null
	if current != null:
		current.remove(unit)
	refresh_threats()

func on_action_reset(unit: BaseCombatant) -> void:
	if board_controller == null:
		return
	var allowance: int = director.rules.free_move_per_action if unit.faction == BaseCombatant.FACTIONS.PARTY else 0
	unit.reset_action_movement(allowance)
	board_controller.reset_action_state(unit)

func on_action_started(unit: BaseCombatant) -> void:
	var fields: FieldController = FieldController.get_for_unit(unit)
	if fields != null:
		fields.on_unit_action_started(unit)

func advance_fields(previous_tick: int, current_tick: int) -> void:
	if board_controller != null:
		board_controller.advance_fields(previous_tick, current_tick)

func on_card_played(unit: BaseCombatant) -> void:
	if board_controller == null or not is_instance_valid(unit):
		return
	var current: BoardData = board_controller.get_board_for_unit(unit)
	if current != null:
		current.invalidate_undo(unit)
	if not director.rules.move_split_allowed and unit.faction == BaseCombatant.FACTIONS.PARTY:
		unit.move_points = 0
		unit.paid_cells_this_action = max(unit.paid_cells_this_action, director.rules.paid_move_max_cells)

func refresh_threats() -> void:
	if director != null and director.is_running and threat_preview != null:
		threat_preview.refresh()

func _on_unit_moved(_unit: BaseCombatant, _from: Vector2i, _to: Vector2i) -> void:
	_refresh_display()

func _on_field_changed(_instance: FieldInstance) -> void:
	_refresh_display()

func _on_board_changed(_board_id: StringName) -> void:
	_refresh_display()

func _refresh_display() -> void:
	if director != null:
		director.refresh_threats()

func perform_enemy_intent(enemy: Enemy) -> void:
	await BoardEnemyIntent.perform_intent(director, enemy)

func resolve_action_targets(action: BaseAction, override: int, force_dead: bool) -> Array[BaseCombatant]:
	return BoardActionTargets.resolve(action, override, force_dead)

func place_unit_nearest(unit: BaseCombatant, cell: Vector2i) -> bool:
	return board_controller != null and board_controller.place_unit_nearest(unit, cell)

func get_move_budget(unit: BaseCombatant) -> int:
	return board_controller.get_move_budget(unit) if board_controller != null else 0

func request_player_move(unit: BaseCombatant, cell: Vector2i, board_id: String = "") -> bool:
	if board_controller == null or not is_instance_valid(unit) or unit.faction != BaseCombatant.FACTIONS.PARTY:
		return false
	if board_id != "" and board_id != unit.board_id:
		return false
	return board_controller.move_party_unit(unit, cell)

func can_player_undo_move(unit: BaseCombatant) -> bool:
	if board_controller == null or not is_instance_valid(unit) or unit.faction != BaseCombatant.FACTIONS.PARTY:
		return false
	var current: BoardData = board_controller.get_board_for_unit(unit)
	return current != null and current.can_undo_move(unit)

func request_player_undo_move(unit: BaseCombatant) -> bool:
	if not can_player_undo_move(unit):
		return false
	return board_controller.get_board_for_unit(unit).undo_move(unit)
