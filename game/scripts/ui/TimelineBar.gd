## Combat HUD strip listing the current tick and the next projected actions of the timeline
## ("name@tick"), read from CombatDirector.project_timeline(). Labels are rebuilt on every
## timeline_changed / combat_tick_advanced; hidden outside combat. A WaveLabel ("Wave i/n", built at
## runtime after the tick label) shows the current wave for encounters with more than one wave.
extends HBoxContainer

## How many upcoming actions to show (the acting unit counts as the first entry).
const PROJECTION_COUNT: int = 8

@onready var tick_label: Label = $TickLabel
@onready var entry_container: HBoxContainer = $Entries
var wave_label: Label = null

func _ready() -> void:
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_run_ended)
	Signals.timeline_changed.connect(refresh)
	Signals.combat_tick_advanced.connect(_on_combat_tick_advanced)
	Signals.unit_action_started.connect(_on_unit_action_started)
	Signals.wave_started.connect(_on_wave_changed)
	Signals.wave_cleared.connect(_on_wave_changed)
	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.visible = false
	add_child(wave_label)
	move_child(wave_label, tick_label.get_index() + 1)
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
	var wave_count: int = director.waves.get_wave_count() if director.waves != null else 0
	wave_label.visible = wave_count > 1
	if wave_label.visible:
		wave_label.text = "Wave %d/%d" % [max(1, director.waves.current_wave + 1), wave_count]
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

func _on_wave_changed(_wave_index: int) -> void:
	refresh()
