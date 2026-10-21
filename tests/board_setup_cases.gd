extends RefCounted

func run(c) -> void:
	var rules := CombatRulesData.new()
	rules.board_mode = -123
	var input: Dictionary = {"west": {"size": Vector2i(5, 4), "blocked_cells": [[0, 0]], "deploy_cells": [[2, 3]]}, "east": {"size": Vector2i(3, 3)}, "reserve": {"size": Vector2i(4, 4)}}
	var setup: BoardSetup = BoardSetup.from_definitions(input, rules)
	var deployment := BoardDeployment.new(input, "west", "east")
	input.west.blocked_cells[0][0] = 3
	var exposed: Dictionary = setup.get_config("west")
	exposed.size = Vector2i(9, 9)
	exposed.deploy_cells[0][0] = 4
	# Geometry and targeting consume spatial rules without interpreting legacy modes.
	var world := CombatBattlefield.new(setup, rules)
	c._check(world.valid and world.boards.keys() == ["west", "east", "reserve"] and world.get_board("west").size == Vector2i(5, 4) and world.get_board("west").is_blocked(Vector2i.ZERO), "normalized geometry consumes three arbitrary IDs independently of legacy mode and input mutations")
	var targeting: Dictionary = CrossBoardPolicy.resolve(world, BoardPosition.new("west", Vector2i(2, 3)), BoardPosition.new("east", Vector2i(1, 0)), BoardTargeting.TARGET_SHAPES.SINGLE)
	c._check(targeting.valid and targeting.cross_board and targeting.board_id == "east" and targeting.distance == null, "normalized targeting uses arbitrary board identity and spatial rules without legacy mode")
	c._check(deployment.hero_location(BaseCombatant.FACTIONS.PARTY) == {"board_id": "west", "cell": Vector2i(2, 3)} and deployment.resolve_spawn_location({}) == {"board_id": "east", "cell": Vector2i(1, 0)}, "explicit deployment policy returns detached positions without creating or occupying units")
	c._check(world.get_units().is_empty() and deployment.resolve_spawn_location({"board_id": "missing"}).cell == BaseCombatant.BOARD_ANCHOR_NONE, "policy does not mutate geometry or silently substitute unknown destinations")
	c._check(not CombatBattlefield.new(BoardSetup.new(), CombatRulesData.new()).valid, "unprepared setup cannot masquerade as validated geometry")
	var invalid: BoardSetup = BoardSetup.from_definitions({"x": {"size": [5, 5], "blocked_cells": [[0.5, 0]]}}, CombatRulesData.new())
	c._check(not invalid.is_valid() and invalid.error == "invalid_board_definition_cells", "normalized factory refuses fractional cells before geometry")
	var invalid_policy := BoardDeployment.new({"x": {"size": Vector2i(5, 5)}}, "missing", "x")
	c._check(invalid_policy.error == "invalid_deployment_board" and setup.deployment == null, "geometry is independent of deployment; selected policy rejects unknown destinations")
	invalid = BoardSetup.from_definitions({"x": {"size": [{}, 0]}}, CombatRulesData.new())
	c._check(invalid.error == "invalid_board_definition_size", "malformed normalized sizes return an error before numeric conversion")
	for mode: int in [CombatRulesData.BOARD_MODES.SINGLE, CombatRulesData.BOARD_MODES.DUAL]:
		var legacy_rules := CombatRulesData.new()
		legacy_rules.board_mode = mode
		var legacy: BoardSetup = BoardSetup.from_legacy(EncounterData.new(), legacy_rules)
		var party: String = "shared" if mode == CombatRulesData.BOARD_MODES.SINGLE else "party"
		var enemy: String = "shared" if mode == CombatRulesData.BOARD_MODES.SINGLE else "enemy"
		c._check(legacy.is_valid() and legacy.deployment.default_board_id(BaseCombatant.FACTIONS.PARTY) == party and legacy.deployment.default_board_id(BaseCombatant.FACTIONS.ENEMY) == enemy, "legacy mode translates once to explicit deployment destinations: %s" % mode)
