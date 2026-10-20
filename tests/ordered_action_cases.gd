extends RefCounted
## Behavioral regression for the opt-in ordered handler. Hook into a live isolated
## combat after the player is waiting and all other actions are idle. victim must be
## a clean living fixture enemy; the helper restores its health/block after the attack.

class CallbackAction extends BaseAction:
	var callback: Callable
	func _init(effect: Callable) -> void:
		callback = effect
	func perform_action() -> void:
		callback.call()

class WaitingAction extends BaseAsyncAction:
	var on_start: Callable
	var on_cancel: Callable
	var synchronous: bool = false
	func perform_action() -> void:
		async_awaiting = true
		if on_start.is_valid():
			on_start.call()
		if synchronous:
			finish_async_action()
	func force_action_end() -> void:
		async_cancelled = true
		if on_cancel.is_valid():
			on_cancel.call()
		finish_async_action()

class QueueChildrenAction extends BaseAction:
	var children: Array[BaseAction] = []
	func perform_action() -> void:
		# The fixture relinquishes ownership immediately. A closure capturing a child
		# would retain it in the caller's suspended stack and invalidate a release test.
		var pending: Array[BaseAction] = children
		children = []
		ActionHandler.add_ordered_actions(pending)

var tree: SceneTree
var check: Callable

func run(scene_tree: SceneTree, assertion: Callable, attacker: BaseCombatant, victim: BaseCombatant) -> void:
	tree = scene_tree
	check = assertion
	check.call(not ActionHandler.actions_being_performed, "ordered cases start with an idle live-combat handler")
	if ActionHandler.actions_being_performed:
		return
	await _mixed_batches()
	await _grandchild_before_sibling()
	await _synchronous_async()
	await _external_during_delay()
	await _async_child_ancestry()
	for nested: bool in [false, true]:
		var released: WeakRef = await _cancel_wait(nested)
		# All fixture locals/coroutine arguments have left scope before checking ownership.
		await tree.process_frame
		await tree.process_frame
		check.call(released.get_ref() == null, "cancelled ordered wait is released after its queue and fixture scope are cleared")
	await _generated_attack_before_continuation(attacker, victim)

func _record(trace: Array[String], label: String) -> BaseAction:
	return CallbackAction.new(func(): trace.append(label))

func _mixed_batches() -> void:
	var trace: Array[String] = []
	var parent := CallbackAction.new(func():
		ActionHandler.add_actions([_record(trace, "A"), _record(trace, "B")], true)
		ActionHandler.add_actions([_record(trace, "C"), _record(trace, "D")])
		ActionHandler.add_actions([_record(trace, "E")], true, true))
	ActionHandler.add_ordered_actions([parent, _record(trace, "continue")])
	await _drain("mixed ordered batches drain")
	check.call(trace == ["E", "D", "C", "A", "B", "continue"], "ordered mixed queue/stack/front batches preserve E,D,C,A,B before continuation: " + str(trace))

func _grandchild_before_sibling() -> void:
	var trace: Array[String] = []
	var child := CallbackAction.new(func():
		trace.append("child")
		ActionHandler.add_actions([_record(trace, "grandchild")], true))
	var parent := CallbackAction.new(func(): ActionHandler.add_ordered_actions([child, _record(trace, "sibling")]))
	ActionHandler.add_ordered_actions([parent, _record(trace, "continue")])
	await _drain("nested ordered descendants drain")
	check.call(trace == ["child", "grandchild", "sibling", "continue"], "grandchild finishes before its parent's sibling and movement continuation")

func _synchronous_async() -> void:
	var trace: Array[String] = []
	var events: Dictionary = {"finished": 0}
	var immediate := WaitingAction.new()
	immediate.synchronous = true
	immediate.on_start = func(): trace.append("immediate")
	immediate.action_async_finished.connect(func(): events.finished += 1)
	var parent := CallbackAction.new(func(): ActionHandler.add_ordered_actions([immediate, _record(trace, "sibling")]))
	ActionHandler.add_ordered_actions([parent, _record(trace, "continue")])
	await _drain("synchronous async child does not await an already-fired signal")
	check.call(events.finished == 1 and trace == ["immediate", "sibling", "continue"], "ordered synchronous async completion emits once and keeps descendants moving")

func _cancel_wait(nested: bool) -> WeakRef:
	var trace: Array[String] = []
	var events: Dictionary = {"finished": 0, "ended": 0}
	var waiting := WaitingAction.new()
	waiting.on_start = func(): trace.append("waiting")
	waiting.on_cancel = func():
		trace.append("cancelled")
		ActionHandler.add_ordered_actions([_record(trace, "injected_ordered")])
		ActionHandler.add_actions([_record(trace, "injected_legacy")])
	waiting.action_async_finished.connect(func():
		events.finished += 1
		ActionHandler.clear_all_actions()
		ActionHandler.add_ordered_actions([_record(trace, "injected_signal")]))
	var ended: Callable = func(): events.ended += 1
	ActionHandler.actions_ended.connect(ended)
	if nested:
		var parent := QueueChildrenAction.new()
		parent.children = [waiting, _record(trace, "child_sibling")]
		ActionHandler.add_ordered_actions([parent, _record(trace, "parent_sibling")])
		parent = null
	else:
		waiting.on_start = func():
			trace.append("waiting")
			ActionHandler.add_ordered_actions([_record(trace, "queued_child")])
		ActionHandler.add_ordered_actions([waiting, _record(trace, "parent_sibling")])
	await _wait_active(waiting)
	check.call(waiting.async_awaiting, "ordered %s cancellation reaches a real suspended action" % ("child" if nested else "parent"))
	ActionHandler.clear_all_actions()
	await tree.process_frame
	await tree.process_frame
	check.call(waiting.async_cancelled and events.finished == 1 and events.ended == 1, "ordered %s cancellation finishes and ends exactly once" % ("child" if nested else "parent"))
	check.call(trace == ["waiting", "cancelled"] and not ActionHandler.actions_being_performed, "clear callbacks cannot resurrect ordered or legacy work; all descendants cancelled")
	ActionHandler.actions_ended.disconnect(ended)
	var released: WeakRef = weakref(waiting)
	waiting = null
	return released

func _external_during_delay() -> void:
	for mode: String in ["enqueue", "stack", "front", "ordered"]:
		var trace: Array[String] = []
		var delayed: BaseAction = _record(trace, "delay")
		delayed.time_delay = 0.01
		ActionHandler.add_ordered_actions([delayed, _record(trace, "continue")])
		check.call(not ActionHandler.action_timer.is_stopped(), "external %s fixture arrives during a real action delay" % mode)
		var external: BaseAction = _record(trace, "external")
		match mode:
			"enqueue": ActionHandler.add_actions([external], true)
			"stack": ActionHandler.add_actions([external])
			"front": ActionHandler.add_actions([external], true, true)
			"ordered": ActionHandler.add_ordered_actions([external])
		if not ActionHandler.action_timer.is_stopped():
			await ActionHandler.action_timer.timeout
		await _drain("external %s during delay drains" % mode)
		var expected: Array[String] = ["delay", "continue", "external"]
		if mode == "front":
			expected = ["delay", "external", "continue"]
		check.call(trace == expected, "independent %s keeps public queue semantics instead of becoming a reaction child: %s" % [mode, str(trace)])

func _async_child_ancestry() -> void:
	var trace: Array[String] = []
	var waiting := WaitingAction.new()
	waiting.on_start = func(): trace.append("waiting")
	ActionHandler.add_ordered_actions([waiting, _record(trace, "continue")])
	await _wait_active(waiting)
	var child: BaseAction = _record(trace, "child")
	child.parent_action = waiting
	ActionHandler.add_actions([child], true)
	waiting.finish_async_action()
	await _drain("asynchronous child identified by ancestry drains")
	check.call(trace == ["waiting", "child", "continue"], "genuine asynchronous descendant still finishes before the parent's continuation")

func _generated_attack_before_continuation(attacker: BaseCombatant, victim: BaseCombatant) -> void:
	if not is_instance_valid(victim) or not victim.is_alive() or victim.get_combatant_health() <= 4:
		check.call(false, "ordered attack fixture has a living target with more than four health")
		return
	var before: int = victim.get_combatant_health()
	var maximum: int = victim.get_combatant_health_max()
	var old_block: int = victim.get_block()
	victim.set_block(0)
	var observed: Array[int] = []
	var parent := CallbackAction.new(func():
		var payload: Array[Dictionary] = [{Scripts.ACTION_ATTACK_GENERATOR: {
			"damage": 2, "number_of_attacks": 2, "time_delay": 0.0,
			"attack_animation_name": AnimationData.ANIMATION_NONE,
			"per_attack_animation_name": AnimationData.ANIMATION_NONE,
		}}]
		ActionHandler.add_actions(ActionGenerator.create_actions(attacker, null, [victim], payload, null)))
	var continuation := CallbackAction.new(func(): observed.append(victim.get_combatant_health()))
	ActionHandler.add_ordered_actions([parent, continuation])
	await _drain("nested production AttackGenerator and continuation drain")
	check.call(observed == [before - 4] and victim.get_combatant_health() == before - 4, "both production generated attacks change health before the following continuation")
	victim.set_health(before, maximum)
	victim.set_block(old_block)

func _wait_active(action: BaseAction) -> void:
	for frame: int in 120:
		if ActionHandler.current_action == action:
			return
		await tree.process_frame
	check.call(false, "ordered fixture reaches the expected suspended action within 120 frames")

func _drain(label: String) -> void:
	for frame: int in 120:
		if not ActionHandler.actions_being_performed:
			check.call(true, label)
			return
		await tree.process_frame
	check.call(false, label)
	ActionHandler.clear_all_actions()
