## Optional board module (CombatModule), composed by Combat rather than by the CTB core.
## An unmounted combat has no BoardController, FieldController or ThreatPreview, and the core
## never names any class of this folder: removing the module keeps ordinary combat working.
extends CombatModule
class_name BoardCombatModule

const MODULE_ID: StringName = &"board"

var director: CombatDirector = null
var board_controller: BoardController = null
var threat_preview: ThreatPreview = null
var presentation: BoardCombatPresentation = null
## Changes on every clear/setup; queued requests cannot survive reuse of this same Node.
var generation: int = 0
var _committed: bool = false
var setup_error: Dictionary = {"code": "", "detail": ""}
## Retained weakly after clear so a later tree exit can detach the old instance safely.
var _director_ref: WeakRef = null
## Spatial card policy; Combat exposes it as card_play_adapter while this module is mounted.
var card_adapter: BoardCardAdapter = null
var battlefield: CombatBattlefield:
	get:
		return board_controller.battlefield if board_controller != null else null
## Legacy query seam: shared board in SINGLE, party board in DUAL.
var board: BoardData:
	get:
		return board_controller.board if board_controller != null else null
var field_controller: FieldController:
	get:
		return board_controller.field_controller if board_controller != null else null

func _init() -> void:
	card_adapter = BoardCardAdapter.new(self)

func get_module_id() -> StringName:
	return MODULE_ID

func get_card_play_adapter() -> CardPlayAdapter:
	return card_adapter

## The director this module was last set up with (kept weakly across clear()).
func attached_director() -> CombatDirector:
	return _director_ref.get_ref() as CombatDirector if _director_ref != null else null

static func prepare_encounter(encounter: EncounterData, rules: CombatRulesData) -> Dictionary:
	var raw: Variant = encounter.encounter_board_setup
	if not raw is Dictionary:
		return {"ok": false, "code": "invalid_board_setup", "detail": "encounter_board_setup must be an object"}
	var setup: BoardSetup = BoardSetup.from_legacy(encounter, rules) if raw is Dictionary and raw.is_empty() else BoardSetup.from_explicit(raw, rules)
	if not setup.is_valid():
		return {"ok": false, "code": setup.error, "detail": setup.error_detail}
	if setup.explicit and not setup.get_board_ids().is_empty():
		for wave_index: int in encounter.encounter_waves.size():
			var wave: EncounterWaveData = encounter.encounter_waves[wave_index]
			if wave == null:
				continue
			for unit_index: int in wave.wave_units.size():
				var location: Dictionary = setup.deployment.resolve_spawn_location(wave.wave_units[unit_index])
				if location.get("error", "") != "":
					return {"ok": false, "code": "invalid_wave_deployment", "detail": "wave %s unit %s requires a valid board_id/cell or deployment.spawn" % [wave_index, unit_index]}
	return {"ok": true, "code": "", "detail": "", "setup": setup}

func setup(combat_director: CombatDirector, encounter: EncounterData) -> bool:
	clear()
	var result: Dictionary = prepare_encounter(encounter, combat_director.rules)
	if not result.ok:
		setup_error = {"code": result.code, "detail": result.detail}
		return false
	if not setup_prepared(combat_director, encounter, result.setup):
		return false
	commit_setup()
	return true

func setup_prepared(combat_director: CombatDirector, encounter: EncounterData, prepared: Variant) -> bool:
	clear()
	setup_error = {"code": "", "detail": ""}
	director = combat_director
	_director_ref = weakref(combat_director)
	if not prepared is BoardSetup or not prepared.is_valid():
		setup_error = {"code": "unprepared_board_setup", "detail": "module requires a validated BoardSetup"}
		clear()
		return false
	board_controller = BoardController.new(director.rules)
	if not board_controller.setup_prepared(encounter, prepared):
		setup_error = {"code": board_controller.error, "detail": board_controller.error_detail}
		clear()
		return false
	threat_preview = ThreatPreview.new(director)
	return true

func get_setup_generation() -> int:
	return generation

func get_setup_error() -> Dictionary:
	return setup_error.duplicate(true)

func commit_setup() -> void:
	if _committed or board_controller == null or director == null:
		return
	_committed = true
	Signals.unit_moved.connect(_on_unit_moved)
	Signals.field_created.connect(_on_field_changed)
	Signals.field_removed.connect(_on_field_changed)
	Signals.field_changed.connect(_on_field_changed)
	Signals.board_changed.connect(_on_board_changed)
	presentation = BoardCombatPresentation.new()
	presentation.layout_slots.assign(board_controller.board_setup.layout_slots)
	add_child(presentation)
	presentation.setup(director, self)
	board_controller.commit_setup()

func clear(preserve_presentation: bool = false) -> void:
	generation += 1
	_committed = false
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
		attached_director.detach_module(self)
	_director_ref = null

## Admission of a regular summon. Missing board membership in mounted mode is not NONE.
func prepare_spawned_unit(unit: BaseCombatant) -> bool:
	if board_controller == null or board_controller.battlefield == null:
		return false
	if board_controller.get_board_for_unit(unit) != null:
		return true
	var location: Dictionary = board_controller.deployment.resolve_spawn_location({}, unit.faction)
	return location.get("error", "") == "" and board_controller.place_unit_nearest(unit, location.cell, location.board_id)

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

func on_clock_advanced(previous_tick: int, current_tick: int) -> void:
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

func handles_enemy_intents() -> bool:
	return true

func incoming_damage_for(hero: BaseCombatant, recalculate: bool) -> int:
	if threat_preview == null or director == null or not director.is_running:
		return -1
	if recalculate:
		threat_preview.refresh()
	return threat_preview.incoming_damage_for(hero)

func perform_enemy_intent(enemy: Enemy) -> void:
	await BoardEnemyIntent.perform_intent(director, enemy)

func resolve_action_targets(action: BaseAction, override: int, force_dead: bool) -> Array[BaseCombatant]:
	return BoardActionTargets.resolve(action, override, force_dead)

#region Positions (CombatModule spatial hooks)
func places_units() -> bool:
	return board_controller != null and board_controller.battlefield != null

func resolve_spawn_location(unit_entry: Dictionary) -> Dictionary:
	var location: Dictionary = {"board_id": "", "cell": BaseCombatant.BOARD_ANCHOR_NONE}
	if not places_units():
		return location
	return board_controller.deployment.resolve_spawn_location(unit_entry)

func has_zone(zone_id: String) -> bool:
	return places_units() and battlefield.get_board(zone_id) != null

func anchor_fits(zone_id: String, footprint: Vector2i, cell: Vector2i) -> bool:
	var current: BoardData = battlefield.get_board(zone_id) if places_units() else null
	return current != null and current.footprint_fits(footprint, cell)

func nearest_free_anchor(zone_id: String, footprint: Vector2i, cell: Vector2i) -> Vector2i:
	var current: BoardData = battlefield.get_board(zone_id) if places_units() else null
	return current.nearest_empty_anchor_for_footprint(footprint, cell) if current != null else BaseCombatant.BOARD_ANCHOR_NONE

func place_unit_at(unit: BaseCombatant, zone_id: String, anchor: Vector2i) -> bool:
	var current: BoardData = battlefield.get_board(zone_id) if places_units() else null
	return current != null and current.place(unit, anchor)

func place_unit_nearest(unit: BaseCombatant, cell: Vector2i, zone_id: String = "") -> bool:
	return board_controller != null and board_controller.place_unit_nearest(unit, cell, zone_id)
#endregion

#region Player movement (input gated by the core: CombatDirector.can_request_player_input)
func _acting_party_unit() -> BaseCombatant:
	if director == null or not director.can_request_player_input():
		return null
	return director.acting_unit

## Cells the acting party unit can still move this action: free move points plus paid cells.
func get_move_budget(unit: BaseCombatant) -> int:
	return board_controller.get_move_budget(unit) if board_controller != null else 0

## Player movement input (BoardView click on an empty cell): moves the acting party unit along the
## previewed path, spending free move points first, then paid cells (+extra_move_delay_per_cell).
## false = not the player's action, busy, or the cell is not reachable within the budget.
func request_player_move(unit: BaseCombatant, cell: Vector2i, board_id: String = "") -> bool:
	if board_controller == null or not is_instance_valid(unit) or unit.faction != BaseCombatant.FACTIONS.PARTY:
		return false
	if board_id != "" and board_id != unit.board_id:
		return false
	return board_controller.move_party_unit(unit, cell)

## Input entry: only the acting party unit during its pending action.
func request_acting_unit_move(cell: Vector2i, board_id: String = "") -> bool:
	var unit: BaseCombatant = _acting_party_unit()
	return unit != null and request_player_move(unit, cell, board_id)

func can_player_undo_move(unit: BaseCombatant = null) -> bool:
	if unit == null:
		unit = _acting_party_unit()
	if board_controller == null or not is_instance_valid(unit) or unit.faction != BaseCombatant.FACTIONS.PARTY:
		return false
	var current: BoardData = board_controller.get_board_for_unit(unit)
	return current != null and current.can_undo_move(unit)

func request_player_undo_move(unit: BaseCombatant = null) -> bool:
	if unit == null:
		unit = _acting_party_unit()
	if not can_player_undo_move(unit):
		return false
	return board_controller.get_board_for_unit(unit).undo_move(unit)
#endregion
