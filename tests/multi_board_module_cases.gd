extends RefCounted

func run(c) -> void:
	var rules := CombatRulesData.new()
	for count: int in [1, 2, 3, 7]:
		var raw: Dictionary = fixture(count)
		var setup: BoardSetup = BoardSetup.from_explicit(raw, rules)
		c._check(setup.is_valid() and setup.get_board_ids().size() == count, "explicit board count %s has no one/two-board ceiling" % count)
		var world := CombatBattlefield.new(setup, rules)
		c._check(world.valid and world.boards.keys() == setup.get_board_ids(), "explicit board order and stable IDs survive geometry %s" % count)
		raw.boards[0].size[0] = 99
		c._check(setup.get_config("zone_0").size == Vector2i(5, 5), "normalized geometry detaches source arrays %s" % count)
	var reordered: Dictionary = fixture(3)
	reordered.boards.reverse()
	var setup: BoardSetup = BoardSetup.from_explicit(reordered, rules)
	c._check(setup.get_board_ids() == ["zone_2", "zone_1", "zone_0"] and setup.deployment.hero_location(0).board_id == "zone_0", "world order never selects hero destination")
	var missing: Dictionary = fixture(3)
	missing.erase("deployment")
	c._check(BoardSetup.from_explicit(missing, rules).error == "invalid_deployment_policy", "positive board collection requires explicit hero deployment")
	missing = fixture(3)
	missing.presentation.slots.pop_back()
	c._check(BoardSetup.from_explicit(missing, rules).error == "invalid_board_layout", "positive boards require complete layout")
	missing = fixture(3)
	missing.boards.append(missing.boards[0].duplicate(true))
	c._check(BoardSetup.from_explicit(missing, rules).error == "invalid_board_id", "duplicate stable board IDs fail before building geometry")
	setup = BoardSetup.from_explicit(fixture(2), rules)
	c._check(setup.deployment.resolve_spawn_location({"board_id": "missing", "cell": [0, 0]}).get("error", "") != "", "new policy never replaces unknown destination with a faction home")
	var no_spawn: Dictionary = fixture(1)
	no_spawn.deployment.erase("spawn")
	setup = BoardSetup.from_explicit(no_spawn, rules)
	c._check(setup.is_valid() and setup.deployment.resolve_spawn_location({}).get("error", "") != "" and setup.deployment.resolve_spawn_location({"board_id": "zone_0", "cell": [1, 1]}).get("error", "") == "", "spawn default is optional only when the caller provides complete positions")

	var copied: BoardSetup = setup.detached_copy()
	copied.layout_slots.clear()
	copied.deployment._hero.board_id = "mutated"
	c._check(not setup.layout_slots.is_empty() and setup.deployment.hero_location(0).board_id == "zone_0", "detached prepared copy isolates layout and policy mutations")
	var field_board := BoardData.new(Vector2i(5, 5), rules)
	var fields := FieldController.new(field_board)
	fields.published = false
	var observed: Array = []
	var on_created: Callable = func(instance: FieldInstance): observed.append(["created", instance.stacks, field_board.get_fields(instance.cell).has(instance)])
	var on_changed: Callable = func(instance: FieldInstance): observed.append(["changed", instance.stacks, field_board.get_fields(instance.cell).has(instance)])
	var on_removed: Callable = func(instance: FieldInstance): observed.append(["removed", instance.stacks, field_board.get_fields(instance.cell).has(instance)])
	Signals.field_created.connect(on_created)
	Signals.field_changed.connect(on_changed)
	Signals.field_removed.connect(on_removed)
	var data := FieldData.new()
	data.object_id = "multi_board_stack"
	data.field_stack_policy = FieldData.STACK_POLICIES.STACK
	fields.create_field(data, Vector2i.ZERO)
	fields.create_field(data, Vector2i.ZERO)
	c._check(observed.is_empty(), "trial fields never publish created or changed")
	fields.publish_fields()
	c._check(observed == [["created", 1, true], ["changed", 2, true]], "commit replays initial operations preserving callback membership and stack state")
	fields.clear()
	observed.clear()
	fields = FieldController.new(field_board)
	fields.published = false
	fields.create_field(data, Vector2i.ZERO, null, 0, 0)
	fields.publish_fields()
	c._check(observed == [["created", 1, true], ["removed", 1, false]], "zero duration setup preserves created then removed callback state")
	fields.clear()
	observed.clear()
	fields = FieldController.new(field_board)
	fields.published = false
	fields.create_field(data, Vector2i.ZERO)
	fields.clear()
	c._check(observed.is_empty(), "discarded setup emits no created changed or removed")
	Signals.field_created.disconnect(on_created)
	Signals.field_changed.disconnect(on_changed)
	Signals.field_removed.disconnect(on_removed)

static func fixture(count: int) -> Dictionary:
	var raw: Dictionary = {"version": 1, "boards": [], "deployment": {"policy": "explicit_positions", "hero": {"board_id": "zone_0", "cell": [2, 4]}, "spawn": {"board_id": "zone_0", "cell": [2, 0]}}, "presentation": {"slots": []}}
	for index: int in count:
		var id: String = "zone_%s" % index
		raw.boards.append({"id": id, "size": [5, 5]})
		raw.presentation.slots.append({"board_id": id, "rect": [index * 100, 100, 90, 90]})
	return raw
