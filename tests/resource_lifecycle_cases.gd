extends RefCounted
## Fixtures supply an observable interceptor and continuation; lifetime, selection,
## scheduling and cancellation use the production processor/actions/handler.
class WaitingAction extends BaseAsyncAction:
	var executions := 0
	func perform_action() -> void:
		_intercept_action()
		async_awaiting = true
	func perform_async_action() -> void:
		_intercept_action()
		executions += 1
		action_async_finished.emit()

class CountingAction extends BaseAction:
	var executions := 0
	func perform_action() -> void:
		executions += 1

class ImmediateAsyncAction extends BaseAsyncAction:
	func perform_action() -> void:
		action_async_finished.emit()

var check: Callable
var tree: SceneTree
var game_root: Node

func run(scene_tree: SceneTree, assertion: Callable) -> void:
	tree = scene_tree
	check = assertion
	Global.player_data = PlayerData.new()
	game_root = load("res://scenes/Root.tscn").instantiate()
	tree.root.add_child(game_root)
	tree.current_scene = game_root
	await tree.process_frame
	var data := ActionInterceptorData.new()
	data.object_id = "test_lifetime"
	data.action_interceptor_script_path = get_script().resource_path.get_base_dir().path_join("resource_lifecycle_interceptor.gd")
	Global._id_to_action_interceptor_data[data.object_id] = data
	for mode in ["normal", "rejected", "preview"]:
		_test_chain(mode)
	await _test_async_completion()
	await _test_picker_cancel(false, false)
	await _test_picker_cancel(true, false)
	await _test_picker_cancel(false, true)
	await _test_timer_cancel()
	await _test_async_cancel()
	await _test_automatic_pick()
	await _test_reentrant_cancel()
	await _test_immediate_async()
	var creation_cases: RefCounted = load(get_script().resource_path.get_base_dir().path_join("resource_lifecycle_creation.gd")).new()
	await creation_cases.run(tree, check)
	await _test_root_exit()
	Global._id_to_action_interceptor_data.erase(data.object_id)

func _state(reject := false) -> Dictionary:
	return {"refs": [], "previews": 0, "effects": 0, "reject": reject}

func _configure(action: BaseAction, state: Dictionary) -> void:
	action.init(null, null, [], {"probe": state, "amount": 4, "forced_interceptor_ids": ["test_lifetime"]})

func _all_released(refs: Array) -> bool:
	for ref: WeakRef in refs:
		if ref.get_ref() != null:
			return false
	return true

func _test_chain(mode: String) -> void:
	var state := _state(mode == "rejected")
	var action := BaseAction.new()
	_configure(action, state)
	var action_ref: WeakRef = weakref(action)
	var orphan_before := Node.get_orphan_node_ids().size()
	for iteration in range(8):
		var results := action._intercept_action([], mode == "preview")
		check.call(results.size() == (0 if mode == "rejected" else 1), "%s iteration %d acceptance" % [mode, iteration])
		if not results.is_empty():
			check.call(results[0].get_shadowed_action_values("amount", 0) == 7, "%s shadow modifier preserved" % mode)
		results.clear()
	check.call(action.values.amount == 4, mode + " leaves source values unchanged")
	check.call(state.effects == (0 if mode == "preview" else 8), mode + " side effect count")
	check.call(_all_released(state.refs), mode + " releases every processor after returned owner drops")
	check.call(Node.get_orphan_node_ids().size() == orphan_before, mode + " does not accumulate detached Nodes")
	action = null
	check.call(action_ref.get_ref() == null, mode + " releases parent action")

func _test_async_completion() -> void:
	var state := _state()
	var action := WaitingAction.new()
	_configure(action, state)
	var events := {"finished": 0, "ended": 0}
	action.action_async_finished.connect(func(): events.finished += 1)
	var ended := func(): events.ended += 1
	ActionHandler.actions_ended.connect(ended)
	for repetition in range(2):
		ActionHandler.add_action(action)
		check.call(ActionHandler.current_action == action and action.async_awaiting, "async active and handler waiting")
		var preview := action._intercept_action([], true)
		check.call(preview.size() == 1, "async preview accepted")
		preview.clear()
		check.call(state.effects == repetition + 1, "preview does not execute interceptor side effects")
		action.perform_async_action()
		await tree.process_frame
		await tree.process_frame
		check.call(state.effects == repetition + 1, "async execution reuses interception without duplicate effects")
		check.call(events.finished == repetition + 1 and events.ended == repetition + 1, "async completes and handler ends once per reuse")
		check.call(not ActionHandler.actions_being_performed and ActionHandler.current_action == null, "async handler is idle after completion")
		check.call(_all_released(state.refs), "async completion releases all cached and preview processors")
	check.call(action.executions == 2 and state.previews == 2, "same async action executes twice with independent previews")
	ActionHandler.actions_ended.disconnect(ended)
	var reference: WeakRef = weakref(action)
	action = null
	check.call(reference.get_ref() == null, "completed async action is not retained by cache cycle")

func _test_picker_cancel(synchronous: bool, run_leave: bool) -> void:
	var picker := ActionPickCards.new()
	var cards: Array[CardData] = [Global.get_card_data("card_attack_basic"), Global.get_card_data("card_block_basic")]
	picker.init(null, null, [], {"pick_draft_cards": true, "draft_cards": cards, "min_card_amount": 1, "max_card_amount": 1,
		"action_data": []})
	# Observe real child generation using a fixture script; cancellation must bypass it.
	picker.values.action_data = [{get_script().resource_path.get_base_dir().path_join("resource_lifecycle_child.gd"): {}}]
	var events := {"finished": 0, "ended": 0, "requested": 0}
	picker.action_async_finished.connect(func(): events.finished += 1)
	var ended := func(): events.ended += 1
	var request := func(_action):
		events.requested += 1
		if synchronous:
			ActionHandler.clear_all_actions()
	Signals.card_pick_requested.connect(request)
	ActionHandler.actions_ended.connect(ended)
	var confirmed_before := Signals.card_pick_confirmed.get_connections().size()
	var label := "picker " + ("synchronous cancel" if synchronous else ("run leave" if run_leave else "force cancel"))
	ActionHandler.add_action(picker)
	if not synchronous:
		check.call(picker.async_awaiting, label + " reaches real selection wait")
		if run_leave:
			Signals.run_ended.emit()
		else:
			ActionHandler.clear_all_actions()
	await tree.process_frame
	await tree.process_frame
	check.call(events.requested == 1 and events.finished == 1 and events.ended == 1, label + " request/finish/handler end exactly once")
	check.call(not ActionHandler.actions_being_performed and ActionHandler.current_action == null, label + " leaves handler idle")
	check.call(Signals.card_pick_confirmed.get_connections().size() == confirmed_before, label + " releases selection continuation")
	check.call(Global.player_data.player_values.get("lifecycle_child_effects", 0) == 0, label + " produces no child effect")
	Signals.card_pick_requested.disconnect(request)
	ActionHandler.actions_ended.disconnect(ended)
	var reference: WeakRef = weakref(picker)
	picker = null
	check.call(reference.get_ref() == null, label + " releases cancelled action")
	var next := CountingAction.new()
	ActionHandler.add_action(next)
	await tree.process_frame
	await tree.process_frame
	check.call(next.executions == 1 and not ActionHandler.actions_being_performed, label + " permits next action exactly once")

func _test_timer_cancel() -> void:
	var action := CountingAction.new()
	action.time_delay = 20
	ActionHandler.add_action(action)
	check.call(not ActionHandler.action_timer.is_stopped(), "delayed action starts real handler timer")
	ActionHandler.clear_all_actions()
	await tree.process_frame
	check.call(not ActionHandler.actions_being_performed and ActionHandler.action_timer.is_stopped(), "clear cancels timer continuation")
	var reference: WeakRef = weakref(action)
	action = null
	check.call(reference.get_ref() == null, "timer cancellation releases active action")

func _test_async_cancel() -> void:
	var state := _state()
	var action := WaitingAction.new()
	_configure(action, state)
	var events := {"finished": 0, "ended": 0}
	action.action_async_finished.connect(func(): events.finished += 1)
	var ended := func(): events.ended += 1
	ActionHandler.actions_ended.connect(ended)
	ActionHandler.add_action(action)
	check.call(not _all_released(state.refs), "pending async owns active execution cache")
	ActionHandler.clear_all_actions()
	await tree.process_frame
	check.call(_all_released(state.refs), "cancel releases execution cache while caller still owns action")
	check.call(action.executions == 0 and events.finished == 1 and events.ended == 1, "async cancel completes once without effect")
	ActionHandler.actions_ended.disconnect(ended)
	var reference: WeakRef = weakref(action)
	action = null
	check.call(reference.get_ref() == null, "cancelled async action has no cache cycle")

func _test_automatic_pick() -> void:
	for cancelled in [false, true]:
		var picker := ActionPickCards.new()
		picker.init(null, null, [], {"pick_draft_cards": true, "draft_cards": [Global.get_card_data("card_attack_basic")], "min_card_amount": 1, "max_card_amount": 1,
			"action_data": [{get_script().resource_path.get_base_dir().path_join("resource_lifecycle_child.gd"): {}}]})
		var events := {"finished": 0}
		picker.action_async_finished.connect(func(): events.finished += 1)
		var before: int = Global.player_data.player_values.get("lifecycle_child_effects", 0)
		ActionHandler.add_action(picker)
		check.call(picker.picked_cards.size() == 1, "automatic picker chooses real card before frame wait")
		if cancelled:
			ActionHandler.clear_all_actions()
		for frame in range(5):
			await tree.process_frame
		check.call(Global.player_data.player_values.get("lifecycle_child_effects", 0) == before + (0 if cancelled else 1), "automatic pick effect contract cancelled=%s" % cancelled)
		check.call(events.finished == 1 and not ActionHandler.actions_being_performed, "automatic pick finishes exactly once cancelled=%s" % cancelled)
		if cancelled:
			check.call(picker.picked_cards.is_empty(), "cancel removes automatic pending selection")
		var reference: WeakRef = weakref(picker)
		picker = null
		check.call(reference.get_ref() == null, "automatic pick releases action cancelled=%s" % cancelled)

func _test_reentrant_cancel() -> void:
	var action := WaitingAction.new()
	_configure(action, _state())
	var injected := CountingAction.new()
	var events := {"ended": 0, "finished": 0}
	var ended := func(): events.ended += 1
	ActionHandler.actions_ended.connect(ended)
	action.action_async_finished.connect(func():
		events.finished += 1
		if events.finished == 1:
			ActionHandler.clear_all_actions()
			ActionHandler.add_action(injected))
	ActionHandler.add_action(action)
	ActionHandler.clear_all_actions()
	await tree.process_frame
	await tree.process_frame
	check.call(events.finished == 1 and events.ended == 1, "reentrant cancellation completes once")
	check.call(injected.executions == 0 and not ActionHandler.actions_being_performed, "cancel callback cannot resurrect cleared run actions")
	ActionHandler.actions_ended.disconnect(ended)

func _test_root_exit() -> void:
	var picker := ActionPickCards.new()
	picker.init(null, null, [], {"pick_draft_cards": true, "draft_cards": [Global.get_card_data("card_attack_basic"), Global.get_card_data("card_block_basic")], "min_card_amount": 1, "max_card_amount": 1})
	var events := {"finished": 0}
	picker.action_async_finished.connect(func(): events.finished += 1)
	ActionHandler.add_action(picker)
	check.call(picker.async_awaiting, "Root exit fixture has pending selection")
	var location_refs := _populate_map_fixture()
	game_root.queue_free()
	await tree.process_frame
	await tree.process_frame
	check.call(events.finished == 1 and not ActionHandler.actions_being_performed, "Root teardown cancels selection exactly once")
	var reference: WeakRef = weakref(picker)
	picker = null
	check.call(reference.get_ref() == null, "Root teardown releases pending picker")
	check.call(_all_released(location_refs), "same-frame Root teardown releases every pending map layout LocationData")

func _populate_map_fixture() -> Array:
	var start := LocationData.new()
	start.location_id = "lifecycle_start"
	Global.player_data.location_id_to_location_data[start.location_id] = start
	Global.player_data.player_location_id = start.location_id
	var locations: Array[LocationData] = [LocationData.new(), LocationData.new()]
	var refs: Array = [weakref(locations[0]), weakref(locations[1])]
	var map: Control = game_root.get_node("RunScreen/Map")
	map.populate_locations(locations)
	check.call(map.location_container.get_child_count() == 2, "map layout creates both private fixture locations before frame wait")
	return refs

func _test_immediate_async() -> void:
	var action := ImmediateAsyncAction.new()
	var next := CountingAction.new()
	var events := {"finished": 0}
	action.action_async_finished.connect(func(): events.finished += 1)
	ActionHandler.add_action(action)
	ActionHandler.add_action(next, true)
	for frame in range(5):
		await tree.process_frame
	check.call(events.finished == 1, "immediate async emits completion once")
	check.call(next.executions == 1 and not ActionHandler.actions_being_performed, "immediate async completion does not leave handler waiting for a past signal")
	# Clean up through the public cancellation contract only if the assertion failed.
	if ActionHandler.actions_being_performed:
		ActionHandler.clear_all_actions()
	var reference: WeakRef = weakref(action)
	action = null
	check.call(reference.get_ref() == null, "immediately completed async releases action")
