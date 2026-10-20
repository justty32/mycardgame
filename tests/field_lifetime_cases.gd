extends RefCounted
## Regression for a field subtree that was expanded before its owner/scope became invalid.
## Run before field_clock_cases, which tears down the real scene.

func run(c) -> void:
	await c.remove_fields()
	var original_anchor: Vector2i = c.player.board_anchor
	var original_hp: int = c.player.get_combatant_health()
	var original_max: int = c.player.get_combatant_health_max()
	var original_block: int = c.player.get_block()
	var original_zoc: int = c.board.rules.zone_of_control
	c.board.rules.zone_of_control = CombatRulesData.ZOC_MODES.NONE
	c.player.set_block(0)
	c._arrange([[c.player, Vector2i(3, 4)]])
	await _expanded_owner_death(c)
	await _expanded_scope_clear(c)
	await c.remove_fields()
	c.player.set_health(original_hp, original_max)
	c.player.set_block(original_block)
	c.board.rules.zone_of_control = original_zoc
	c._arrange([[c.player, original_anchor]])
	c.board.reset_action_state(c.player)
	Global.remove_meta("field_lifetime_observations")

func _marker_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("field_lifetime_marker.gd")

func _expanded_owner_death(c) -> void:
	var owner: BaseCombatant = await c._spawn("board_dummy", Vector2i(6, 4))
	if not c._check(owner != null, "expanded field owner fixture spawns a real enemy"):
		return
	owner.add_status_effect_charges("status_effect_damage_increase", 11)
	var data := FieldData.new("field_lifetime_owner")
	data.field_on_stay_actions.assign([
		{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 10000, "bypass_block": true,
			"ignore_all_interceptors": true, "target_override": BaseAction.TARGET_OVERRIDES.PARENT}},
		{_marker_path(): {"label": "after_owner_death"}},
		{Scripts.ACTION_ATTACK_GENERATOR: {"damage": 6, "time_delay": 0.0,
			"attack_animation_name": AnimationData.ANIMATION_NONE}}
	])
	Global.register_rod(data)
	await c.create_field(data.object_id, [[3, 4]], owner)
	Global.set_meta("field_lifetime_observations", [])
	var hp: int = c.player.get_combatant_health()
	var owner_ref: WeakRef = weakref(owner)
	c.field_controller().on_unit_action_started(c.player)
	await c._wait(c._idle, "expanded field owner death and generated attack complete")
	var observations: Array = Global.get_meta("field_lifetime_observations", [])
	c._check(not is_instance_valid(owner) or not owner.is_alive(), "first already-expanded field child kills its creator")
	c._check(observations == [{"label": "after_owner_death", "owner_null": true}], "following already-expanded payload resolves a dead creator to null at execution")
	c._check(hp - c.player.get_combatant_health() == 6, "generated attack after creator death deals base damage without retaining creator's +11 strength")
	await c.remove_fields()
	if is_instance_valid(owner):
		c.board.remove(owner)
		owner.queue_free()
	owner = null
	await c.flow.process_frame
	await c.flow.process_frame
	c._check(owner_ref.get_ref() == null, "completed field subtree does not retain its dead creator")
	Global._id_to_field_data.erase(data.object_id)

func _expanded_scope_clear(c) -> void:
	var original_controller: FieldController = c.field_controller()
	var destination: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE
	for offset: Vector2i in BoardData.NEIGHBOURS_FOUR:
		if c.board.can_stand(c.player, c.player.board_anchor + offset):
			destination = c.player.board_anchor + offset
			break
	if not c._check(destination != BaseCombatant.BOARD_ANCHOR_NONE, "scope cancellation fixture has a legal next movement cell"):
		return
	var temporary := FieldController.new(c.board)
	var data := FieldData.new("field_lifetime_scope")
	data.field_on_stay_actions.assign([
		{Scripts.ACTION_MOVE_UNIT: {"target_cell": destination, "distance": 1}},
		{Scripts.ACTION_ATTACK_GENERATOR: {"damage": 9, "time_delay": 0.0,
			"attack_animation_name": AnimationData.ANIMATION_NONE}},
		{_marker_path(): {"label": "forbidden_tail"}}
	])
	# The leave observation proves MoveUnit's dispatch and its sequence have run. Its
	# actual ActionHandler delay leaves the occupancy continuation queued for cancellation.
	data.field_on_leave_actions.assign([{_marker_path(): {"label": "dispatch_reached_leave", "time_delay": 0.2}}])
	Global.register_rod(data)
	await c.create_field(data.object_id, [[3, 4]])
	Global.set_meta("field_lifetime_observations", [])
	var hp: int = c.player.get_combatant_health()
	var anchor: Vector2i = c.player.board_anchor
	temporary.on_unit_action_started(c.player)
	var has_observation: Callable = func(): return not (Global.get_meta("field_lifetime_observations", []) as Array).is_empty()
	var reached: bool = await c._wait(has_observation, "field MoveUnit expands dispatch/sequence into a real leave reaction")
	if reached:
		c._check(c.player.board_anchor == anchor and not ActionHandler.action_timer.is_stopped(), "leave reaction is delayed before occupancy commits")
	temporary.clear()
	await c._wait(c._idle, "cleared field subtree drains without movement or trailing effects")
	c._check(c.player.board_anchor == anchor and c.player.get_combatant_health() == hp, "controller clear cancels expanded movement continuation and following generated attack")
	var observations: Array = Global.get_meta("field_lifetime_observations", [])
	c._check(observations == [{"label": "dispatch_reached_leave", "owner_null": false}], "scope cancellation stops every remaining payload marker")
	c._check(c.board.fields.is_empty() and not temporary.active, "cleared temporary field scope releases all board field instances")
	c.board.field_controller = weakref(original_controller)
	Global._id_to_field_data.erase(data.object_id)
