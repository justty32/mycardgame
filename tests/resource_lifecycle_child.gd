extends BaseAction
func perform_action() -> void:
	Global.player_data.player_values["lifecycle_child_effects"] = Global.player_data.player_values.get("lifecycle_child_effects", 0) + 1
