## Neutral, fixed three-combat route. Loaded only by demo_act in the pack copy.
## Uses ActData's existing generator hook instead of replacing the shared generator.
extends BaseAction

func perform_action() -> void:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var act_id: String = processor.get_shadowed_action_values("act_id", "demo_act")
		var act_number: int = processor.get_shadowed_action_values("act_number", 1)
		Global.clear_locations()
		Global.player_data.player_act_id = act_id
		Global.player_data.player_act = act_number
		_add_location("location_0", "", LocationData.LOCATION_TYPES.STARTING, 0,
			["demo_location_entry"], act_number)
		_add_location("demo_location_entry", "demo_event_entry", LocationData.LOCATION_TYPES.COMBAT, 1,
			["demo_location_field"], act_number)
		_add_location("demo_location_field", "demo_event_field", LocationData.LOCATION_TYPES.COMBAT, 2,
			["demo_location_final"], act_number)
		_add_location("demo_location_final", "demo_event_final", LocationData.LOCATION_TYPES.BOSS, 3,
			[], act_number)
		Global.player_data.player_location_id = "location_0"

func _add_location(id: String, event_id: String, type: int, floor_number: int,
		next_ids: Array[String], act_number: int) -> void:
	var location: LocationData = LocationData.new()
	location.location_id = id
	location.location_event_object_id = event_id
	location.location_type = type
	location.location_floor = floor_number
	location.location_act = act_number
	location.location_position = Vector2(400, 400 - floor_number * 100)
	location.location_index = Vector2(0, floor_number)
	location.location_next_location_ids = next_ids
	location.location_obfuscated = false
	Global.player_data.location_id_to_location_data[id] = location
