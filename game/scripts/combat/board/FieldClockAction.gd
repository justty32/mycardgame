## Dynamically advances all boards' field clocks together. After each boundary its
## entire generated subtree completes, then the next boundary is selected afresh.
## Newly created/refreshed fields therefore behave identically in bulk and small steps.
extends BaseAction
class_name FieldClockAction

var _controllers: Array[WeakRef] = []
var _generations: Array[int] = []
var previous_tick: int
var target_tick: int

func _init(controllers: Array[FieldController], previous: int, target: int) -> void:
	previous_tick = previous
	target_tick = target
	resolve_children_immediately = true
	for controller: FieldController in controllers:
		_controllers.append(weakref(controller))
		_generations.append(controller.generation)

func perform_action() -> void:
	if target_tick <= previous_tick:
		return
	var chosen: Dictionary = {}
	var controller: FieldController = null
	for index: int in _controllers.size():
		var candidate: FieldController = _controllers[index].get_ref()
		if candidate == null or not candidate.active or candidate.generation != _generations[index]:
			continue
		var boundary: Dictionary = candidate.next_tick_boundary(previous_tick, target_tick)
		# Equal ticks retain board insertion order; each controller retains field order.
		if not boundary.is_empty() and (chosen.is_empty() or boundary.tick < chosen.tick):
			chosen = boundary
			controller = candidate
	if chosen.is_empty():
		return
	var instance: FieldInstance = chosen.instance
	if chosen.event == "tick":
		var interval: int = instance.field_data.field_tick_interval
		instance.next_tick = int(chosen.tick) + interval if interval > 0 else -1
	var event := FieldEventAction.new(controller, chosen.event, instance.cell, null, instance)
	event.scheduled_revision = instance.revision
	event.scheduled_tick = chosen.tick
	# This clock intentionally carries no one field's owner/cancellation scope. Individual
	# events have their own scope; all boards' generations are rechecked on every iteration.
	ActionHandler.add_ordered_actions([event, self])
