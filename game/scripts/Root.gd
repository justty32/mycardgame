extends Control

func _exit_tree() -> void:
	# Release pending selections/continuations while autoloads are still alive.
	ActionHandler.clear_all_actions()
	ActionHandler.clear_all_action_interceptors()
