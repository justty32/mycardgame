extends RefCounted
## Direct compatibility start after genuine victory: explicit event differs from location event.

func run(c) -> void:
	c._check(c.director.prepared_encounter == null and c.combat.prepared_encounter == null, "normal stop invalidates the sole active preparation")
	c.combat.combat_module.queue_free()
	await c.flow.process_frame
	await c.flow.process_frame
	c.combat._compose_board_module()
	c._check(c.combat.combat_module == null, "no-argument compose cannot resurrect a stopped encounter")
	var current: EventData = Global.get_player_event_data()
	var original_actions: Array[Dictionary] = current.event_initial_combat_actions.duplicate(true)
	current.event_initial_combat_actions.assign([{Scripts.ACTION_ADD_MONEY: {"money_amount": 97}}])
	var explicit := EventData.new("direct_prepared_start")
	explicit.event_encounter_object_id = "board_flow_encounter"
	explicit.event_initial_combat_actions.assign([{Scripts.ACTION_ADD_MONEY: {"money_amount": 7}}])
	var money: int = Global.player_data.player_money
	var generation: int = c.director.get_generation()
	# Exercise the Director compatibility entry while the normal start signal initializes
	# stats/deck/UI subscribers. Only the scene forwarding callback is replaced here.
	c.signals.combat_started.disconnect(c.combat._on_combat_started)
	c.signals.combat_started.emit(current.object_id)
	c.signals.combat_started.connect(c.combat._on_combat_started)
	c.director.begin_combat(explicit)
	# Mutation after the synchronous preparation must not change the awaited start actions.
	explicit.event_initial_combat_actions[0][Scripts.ACTION_ADD_MONEY].money_amount = 50
	await c._wait(func(): return c.director.is_player_action_pending() and c._idle(), "direct explicit-event start reaches a real player action")
	c._check(Global.player_data.player_money == money + 7, "start executes prepared explicit-event action once instead of location event or changed source")
	c._check(c.director.event.object_id == "direct_prepared_start" and c.director.encounter.object_id == "board_flow_encounter" and Global.get_alive_enemies().size() == 2, "direct compatibility entry prepares explicit encounter and admits its actual first wave")
	c._check(c.combat.prepared_encounter == c.director.prepared_encounter and c.director.get_generation() > generation, "next direct start publishes one fresh preparation and generation")
	current.event_initial_combat_actions.assign(original_actions)
