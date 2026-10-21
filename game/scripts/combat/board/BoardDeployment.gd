## Pure placement policy. Produces positions/candidates; never creates units or mutates occupancy.
extends RefCounted
class_name BoardDeployment

var _definitions: Dictionary = {}
var error: String = ""
var explicit: bool = false
var _hero: Dictionary = {}
var _spawn: Dictionary = {}
var _party_id: String = ""
var _enemy_id: String = ""

func _init(definitions: Dictionary = {}, party_id: String = "", enemy_id: String = "") -> void:
	if not definitions.has(party_id) or not definitions.has(enemy_id):
		error = "invalid_deployment_board"
		return
	for id: String in definitions:
		var config: Dictionary = definitions[id]
		_definitions[id] = {"size": config.size, "deploy_cells": config.get("deploy_cells", []).duplicate(true), "spawn_zone_cells": config.get("spawn_zone_cells", []).duplicate(true)}
	_party_id = party_id
	_enemy_id = enemy_id

func default_board_id(faction: int) -> String:
	if explicit:
		return "" # Explicit policy never infers placement from faction.
	return _party_id if faction == BaseCombatant.FACTIONS.PARTY else _enemy_id

func deploy_cells(id: String) -> Array[Vector2i]:
	var config: Dictionary = _definitions.get(id, {})
	if config.is_empty():
		return []
	if explicit:
		return EncounterData.cells_from_json(config.deploy_cells)
	var cells: Array[Vector2i] = EncounterData.cells_from_json(config.deploy_cells)
	return cells if not cells.is_empty() else default_deploy_cells(id)

func default_deploy_cells(id: String) -> Array[Vector2i]:
	if not _definitions.has(id) or explicit:
		return []
	var size: Vector2i = _definitions[id].size
	var cells: Array[Vector2i] = [Vector2i(int(size.x / 2), size.y - 1)]
	for y: int in range(size.y - 1, max(-1, size.y - 3), -1):
		for x: int in size.x:
			if not cells.has(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells

func spawn_cells(id: String) -> Array[Vector2i]:
	var config: Dictionary = _definitions.get(id, {})
	if config.is_empty():
		return []
	var cells: Array[Vector2i] = EncounterData.cells_from_json(config.spawn_zone_cells)
	if cells.is_empty() and not explicit:
		var size: Vector2i = config.size
		for y: int in min(2, size.y):
			for x: int in size.x:
				cells.append(Vector2i(x, y))
	return cells

func spawn_origin(id: String = "") -> Vector2i:
	if explicit:
		return _spawn.get("cell", BaseCombatant.BOARD_ANCHOR_NONE) if id == "" or id == _spawn.get("board_id", "") else BaseCombatant.BOARD_ANCHOR_NONE
	if id == "":
		id = _enemy_id
	if not _definitions.has(id):
		return BaseCombatant.BOARD_ANCHOR_NONE
	var size: Vector2i = _definitions[id].size
	return Vector2i(int(size.x / 2), 0)

func hero_location(faction: int) -> Dictionary:
	if explicit:
		return _hero.duplicate(true)
	var id: String = default_board_id(faction)
	var cells: Array[Vector2i] = deploy_cells(id)
	return {"board_id": id, "cell": cells[0] if not cells.is_empty() else BaseCombatant.BOARD_ANCHOR_NONE}

func resolve_spawn_location(entry: Dictionary, faction: int = BaseCombatant.FACTIONS.ENEMY) -> Dictionary:
	if explicit:
		var location: Dictionary = _spawn.duplicate(true)
		for key: String in ["board_id", "cell"]:
			if entry.has(key):
				location[key] = entry[key]
		return _checked_location(_definitions, location)
	var id: String = str(entry.get("board_id", ""))
	if id == "":
		id = default_board_id(faction)
	var cell: Vector2i = EncounterData.cell_from_json(entry.get("cell", null))
	var config: Dictionary = _definitions.get(id, {})
	if config.is_empty():
		return {"board_id": id, "cell": BaseCombatant.BOARD_ANCHOR_NONE}
	var size: Vector2i = config.size
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		cell = spawn_origin(id)
	return {"board_id": id, "cell": cell}

static func from_explicit(definitions: Dictionary, settings: Dictionary) -> BoardDeployment:
	var policy := BoardDeployment.new()
	policy.error = ""
	policy.explicit = true
	if settings.get("policy", "") != "explicit_positions":
		policy.error = "invalid_deployment_policy"
		return policy
	policy._definitions = definitions.duplicate(true)
	policy._hero = _checked_location(definitions, settings.get("hero", {}))
	policy._spawn = _checked_location(definitions, settings.get("spawn", {}))
	if policy._hero.get("error", "") != "" or (settings.has("spawn") and policy._spawn.get("error", "") != ""):
		policy.error = "invalid_board_deployment"
	return policy

static func _checked_location(definitions: Dictionary, value: Variant) -> Dictionary:
	var invalid: Dictionary = {"board_id": "", "cell": BaseCombatant.BOARD_ANCHOR_NONE, "error": "missing_board_location"}
	if not value is Dictionary or not value.get("board_id") is String or not definitions.has(value.board_id):
		return invalid
	var size: Vector2i = EncounterData.cell_from_json(definitions[value.board_id].size)
	if not BoardSetup._valid_cell(value.get("cell"), size):
		return invalid
	return {"board_id": value.board_id, "cell": EncounterData.cell_from_json(value.cell)}

func detached_copy() -> BoardDeployment:
	var copy := BoardDeployment.new()
	copy._definitions = _definitions.duplicate(true)
	copy.error = error
	copy.explicit = explicit
	copy._party_id = _party_id
	copy._enemy_id = _enemy_id
	copy._hero = _hero.duplicate(true)
	copy._spawn = _spawn.duplicate(true)
	return copy
