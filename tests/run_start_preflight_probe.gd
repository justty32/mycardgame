extends RefCounted
## Explicit configuration negative cases. Never starts a valid run or replaces live player data.
func run(check: Callable) -> void:
	var source: CharacterData = Global.get_character_data("character_red")
	check.call(source != null, "run preflight has its legacy source character")
	if source == null: return
	var character: CharacterData = source.duplicate(true)
	character.object_id = "preflight_character"
	character.character_player_id = "preflight_player"
	var prototype := PlayerData.new("preflight_player")
	prototype.set_serializable_properties_from_json_patch({"properties": {"object_id": "preflight_player", "player_character_object_id": "preflight_character"}, "patch_data": {}})
	Global.register_rod(character)
	Global.register_rod(prototype)
	var custom := ActData.new("preflight_custom_act")
	Global.register_rod(custom)
	var count: Array[int] = [0]
	var observed: Callable = func(): count[0] += 1
	Signals.run_started.connect(observed)
	check.call(prototype.player_act_id == "act_1" and Global.get_run_start_rejection_reason(character.object_id) == "", "missing starting Act field retains valid act_1 default")
	prototype.player_act_id = custom.object_id
	check.call(Global.get_run_start_rejection_reason(character.object_id) == "", "registered custom starting Act passes pure preflight")
	for id: String in ["", "preflight_missing_act"]:
		prototype.player_act_id = id
		var player_before: PlayerData = Global.player_data
		var run_before: bool = Global.is_run
		var uid_before: int = PrototypeData.unique_id_counter
		var save_existed: bool = FileLoader.has_save_file()
		var saved: String = FileAccess.get_file_as_string("res://external/saves/save.json") if save_existed else ""
		var state: String = JSON.stringify(player_before.get_serializable_properties_to_json_patch())
		var queue_before: int = ActionHandler.current_action_queue.size() + ActionHandler.action_stack.size()
		check.call(Global.get_run_start_rejection_reason(character.object_id) == "unknown_starting_act", "invalid starting Act has a deterministic rejection: " + id)
		check.call(not Global.start_run(character.object_id, 1234), "invalid starting Act returns false before beginning run: " + id)
		check.call(Global.player_data == player_before and Global.is_run == run_before and JSON.stringify(player_before.get_serializable_properties_to_json_patch()) == state, "rejected run leaves live player identity and serialized state unchanged: " + id)
		check.call(PrototypeData.unique_id_counter == uid_before and count[0] == 0 and ActionHandler.current_action_queue.size() + ActionHandler.action_stack.size() == queue_before, "rejected run consumes no prototype UID or action/run signal: " + id)
		check.call(FileLoader.has_save_file() == save_existed and (not save_existed or FileAccess.get_file_as_string("res://external/saves/save.json") == saved), "rejected run preserves checkpoint existence and bytes: " + id)
	Signals.run_started.disconnect(observed)
	Global._id_to_character_data.erase(character.object_id)
	Global._id_to_player_data.erase(prototype.object_id)
	Global._id_to_act_data.erase(custom.object_id)
