## Combat HUD strip listing the current tick and the next projected actions of the timeline
## ("name@tick"), read from CombatDirector.project_timeline(). Labels are rebuilt on every
## timeline_changed / combat_tick_advanced; hidden outside combat.
extends HBoxContainer

## How many upcoming actions to show (the acting unit counts as the first entry).
const PROJECTION_COUNT: int = 8

@onready var tick_label: Label = $TickLabel
@onready var entry_container: HBoxContainer = $Entries

func _ready() -> void:
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_run_ended)
	Signals.timeline_changed.connect(refresh)
	Signals.combat_tick_advanced.connect(_on_combat_tick_advanced)
	Signals.unit_action_started.connect(_on_unit_action_started)
	visible = false

func refresh() -> void:
	for child: Node in entry_container.get_children():
		child.queue_free()
	var director: CombatDirector = Global.get_combat_director()
	if director == null or not director.is_running:
		visible = false
		return
	visible = true
	tick_label.text = "Tick %d" % director.current_tick
	for entry: Dictionary in director.project_timeline(PROJECTION_COUNT):
		var unit: BaseCombatant = entry["unit"]
		var label: Label = Label.new()
		label.text = "%s@%d" % [unit.get_unit_display_name(), entry["tick"]]
		if unit == director.acting_unit:
			label.text = "[%s]" % label.text
		entry_container.add_child(label)

func _on_combat_started(_event_id: String) -> void:
	refresh()

func _on_combat_ended() -> void:
	refresh()

func _on_run_ended() -> void:
	refresh()

func _on_combat_tick_advanced(_previous_tick: int, _current_tick: int) -> void:
	refresh()

func _on_unit_action_started(_unit: BaseCombatant) -> void:
	refresh()
