## Starts/Forces combat in a given event id.
## If event_object_id is empty, uses the current location's event.
extends BaseAction

func perform_action() -> void:
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for action_interceptor_processor in action_interceptor_processors:
		var event_object_id: String = get_action_value("event_object_id", "")
		
		# simulate combat starting for the given event
		var director: CombatDirector = Global.get_combat_director()
		if director != null:
			director.get_parent().request_combat_start(event_object_id)
