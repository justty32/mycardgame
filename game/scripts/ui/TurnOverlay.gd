extends Control

@onready var turn_label: Label = $TurnLabel

func update_turn_label() -> void:
	# called from animation player at the start of the hero's action
	var tick: int = 0
	var director: CombatDirector = Global.get_combat_director()
	if director != null:
		tick = director.current_tick
	turn_label.text = "Tick %s - Action %s" % [tick, StatsHandler.get_turn_count()]
