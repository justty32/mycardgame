extends RefCounted
## Production generated-card action must respect cancellation of its frame wait.
func run(tree: SceneTree, check: Callable) -> void:
	for cancelled in [false, true]:
		var action: BaseAsyncAction = load("res://scripts/actions/card_actions/pick_card_actions/ActionCreateCards.gd").new()
		action.init(null, null, [], {"created_card_object_id": "card_attack_basic", "number_of_cards": 1,
			"action_data": [{get_script().resource_path.get_base_dir().path_join("resource_lifecycle_child.gd"): {}}]})
		var events := {"created": 0, "finished": 0}
		var created := func(_card): events.created += 1
		Signals.card_created.connect(created)
		action.action_async_finished.connect(func(): events.finished += 1)
		var before: int = Global.player_data.player_values.get("lifecycle_child_effects", 0)
		ActionHandler.add_action(action)
		check.call(action.picked_cards.size() == 1, "CreateCards prepares one real prototype before frame wait")
		if cancelled:
			ActionHandler.clear_all_actions()
		for frame in range(5):
			await tree.process_frame
		var expected := 0 if cancelled else 1
		check.call(Global.player_data.player_values.get("lifecycle_child_effects", 0) == before + expected, "CreateCards child effect contract cancelled=%s" % cancelled)
		check.call(events.created == expected, "CreateCards emits expected created event cancelled=%s" % cancelled)
		check.call(events.finished == 1 and not ActionHandler.actions_being_performed, "CreateCards completes once cancelled=%s" % cancelled)
		Signals.card_created.disconnect(created)
		var reference: WeakRef = weakref(action)
		action = null
		check.call(reference.get_ref() == null, "CreateCards releases action cancelled=%s" % cancelled)
