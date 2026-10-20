## Singleton maintaining actions taken and registered interceptors for each combatant.
## See: BaseAction, BaseActionInterceptor, ActionInterceptorProcessor, and ActionGenerator
extends Node

@onready var action_timer: Timer = Timer.new()

# actions
var action_stack: Array[Array] = []	# stack of queues of BaseActions
var current_action_queue: Array[BaseAction] = []
var current_action: BaseAction = null # the current action being invoked
var actions_being_performed: bool = false	# flag to prevent multiple actions being performed simultaneously and check for blocking
var _action_generation: int = 0 # invalidates a suspended loop when a run is cleared
var _clearing_actions: bool = false
var _ordered_child_count: int = 0
var _perform_call_active: bool = false

# action interceptors
var _registered_action_interceptor_object_ids: Dictionary	= {}	# maps an object to a sorted list of registered action interceptor ids used when the object is involved in an action

# signals
signal actions_ended	# all actions completed, typically signalling the end of an enemy attack or card play

func _ready():
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.player_killed.connect(_on_player_killed)
	Signals.run_ended.connect(_on_run_ended)
	
	# create and configure a pausable timer
	add_child(action_timer)
	action_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	action_timer.one_shot = true
	action_timer.name = "ActionTimer"

### Actions

func add_action(action: BaseAction, enqueue: bool = false, front_of_queue: bool = false):
	add_actions([action], enqueue, front_of_queue)

## Adds actions to either the top of the stack, or the end of the current queue if enque = true.
## if front_of_queue = true it will place the actions in front of the current queue, effectively always making them
## the next action to take place.
func add_actions(actions: Array[BaseAction], enqueue: bool = false, front_of_queue: bool = false):
	# Cancellation callbacks cannot resurrect work from the run being cleared.
	if _clearing_actions:
		return
	if _is_ordered_child_batch(actions):
		var immediate: Array[BaseAction] = actions.duplicate()
		for child: BaseAction in immediate:
			child.resolve_children_immediately = true
		if not enqueue:
			immediate.reverse() # preserve the existing stack order inside this reaction
		_insert_ordered_children(immediate, not enqueue or front_of_queue)
		return
	if enqueue:
		# adding to queue
		if len(action_stack) == 0:
			if actions_being_performed:
				# actions already being performed
				# adds actions to the current queue
				if front_of_queue:
					current_action_queue = actions + current_action_queue
				else:
					current_action_queue += actions
			else:
				# actions not being performed
				# add the actions as a queue, the push onto stack so it can be popped off in _perform_actions()
				action_stack.append(actions)
		else:
			if front_of_queue:
				current_action_queue = actions + current_action_queue
			else:
				current_action_queue += actions
	else:
		# adding to stack
		# adds each action to top of stack as their own queue
		for action in actions:
			action_stack += [[action]]
	
	if len(actions) > 0:	# automatically perform the actions when they're added
		if not actions_being_performed:	# check to prevent multiple automatic calls of this method
			_perform_actions()

## Executes event steps in order, including nested effects before the following step.
## Existing add_actions callers retain their queue/stack contract outside this opt-in path.
func add_ordered_actions(actions: Array[BaseAction]) -> void:
	if _clearing_actions or actions.is_empty():
		return
	for action: BaseAction in actions:
		action.resolve_children_immediately = true
	if actions_being_performed:
		if _perform_call_active or _is_ordered_child_batch(actions):
			_insert_ordered_children(actions, false)
		else:
			# An independent event arriving during a wait is not the active reaction's child.
			current_action_queue.append_array(actions)
	else:
		action_stack.append(actions)
		_perform_actions()

func _insert_ordered_children(actions: Array[BaseAction], front: bool) -> void:
	var offset: int = 0 if front else min(_ordered_child_count, current_action_queue.size())
	for index: int in actions.size():
		current_action_queue.insert(offset + index, actions[index])
	_ordered_child_count += actions.size()

func _is_ordered_child_batch(actions: Array[BaseAction]) -> bool:
	if not actions_being_performed or current_action == null or not current_action.resolve_children_immediately:
		return false
	if _perform_call_active:
		return true
	if actions.is_empty():
		return false
	for action: BaseAction in actions:
		var ancestor: BaseAction = action.parent_action
		while ancestor != null and ancestor != current_action:
			ancestor = ancestor.parent_action
		if ancestor != current_action:
			return false
	return true

func _perform_actions() -> void:	
	# performs all actions on the action stack
	var generation: int = _action_generation
	actions_being_performed = true
	while len(action_stack) > 0:
		# pop the next queue from the stack
		var action_queue = action_stack.pop_back()
		
		# assign popped queue as current queue
		current_action_queue = []
		current_action_queue.assign(action_queue) # godot typed array shennanigans; re-adding elements to typed array to preserve type integrity
		
		# perform all actions in the queue until empty
		while len(current_action_queue) > 0:
			current_action = current_action_queue.pop_front()
			_ordered_child_count = 0
			# A signal emitted by the action can synchronously clear the handler.
			# Keep the active action alive locally, never dereference mutable state
			# after resuming an await belonging to an earlier run.
			var action: BaseAction = current_action
			if not action.prepare_execution():
				current_action = null
				continue
			# skip short circuited actions
			if action.is_action_short_circuited():
				if not Global.are_remaining_enemies():
					current_action = null
					continue
			# perform action
			if action is BaseAsyncAction:
				action.begin_async_action()
			_perform_call_active = true
			action.perform_action()
			_perform_call_active = false
			if generation != _action_generation:
				return
			# wait for async actions to finish
			if action.is_async_action():
				if not (action is BaseAsyncAction and action.async_finished):
					await action.action_async_finished
			if generation != _action_generation:
				return
			# wait for action delay if one exists
			if action.time_delay > 0.0 and !action.is_instant_action():
				action_timer.start(action.time_delay)
				await action_timer.timeout
				# await get_tree().create_timer(current_action.time_delay).timeout
			else:
				await get_tree().process_frame
			if generation != _action_generation:
				return
			
			current_action = null
	
	actions_being_performed = false
	actions_ended.emit()

## Removes the current async action. Will only remove short circuited actions unless force_end = true.
func _clear_current_async_action(force_end: bool = false) -> void:
	var action: BaseAsyncAction = current_action as BaseAsyncAction
	if action != null and not action.async_finished:
		if action.is_action_short_circuited() or force_end:
			action.force_action_end()
			action.finish_async_action() # idempotent fallback for custom cancellation

func clear_all_actions() -> void:
	if _clearing_actions:
		return
	_clearing_actions = true
	_action_generation += 1
	var was_performing: bool = actions_being_performed
	action_stack.clear()
	current_action_queue.clear()
	_ordered_child_count = 0
	_perform_call_active = false
	# Invalidate and clear queues before resuming a cancelled async continuation.
	_clear_current_async_action(true)
	current_action = null
	if not action_timer.is_stopped():
		action_timer.stop()
		action_timer.timeout.emit()
	actions_being_performed = false
	_clearing_actions = false
	if was_performing:
		actions_ended.emit()

func _exit_tree() -> void:
	clear_all_actions()
	clear_all_action_interceptors()

### Action Interception

func register_action_interceptor(base_combatant: BaseCombatant, action_interceptor_object_id: String) -> void:
	# registers a given action interceptor for an object
	# note that generally speaking any interceptor should only ever have one source of registration. Delegate to status effects with charges if you want multiple things to create the same effect
	var interceptor_ids: Array = _registered_action_interceptor_object_ids.get(base_combatant, [])
	if not interceptor_ids.has(action_interceptor_object_id):
		interceptor_ids.append(action_interceptor_object_id)
	_registered_action_interceptor_object_ids[base_combatant] = interceptor_ids
	
func unregister_action_interceptor(base_combatant: BaseCombatant, action_interceptor_object_id: String) -> void:
	var interceptor_ids: Array = _registered_action_interceptor_object_ids.get(base_combatant, [])
	interceptor_ids.erase(action_interceptor_object_id)
	_registered_action_interceptor_object_ids[base_combatant] = interceptor_ids
	if len(interceptor_ids) == 0:
		_registered_action_interceptor_object_ids.erase(base_combatant)

func clear_all_action_interceptors() -> void:
	_registered_action_interceptor_object_ids.clear()


func _on_combat_ended():
	_clear_current_async_action()

func _on_player_killed(_player: Player):
	clear_all_actions()

func _on_run_ended():
	clear_all_action_interceptors()
	clear_all_actions()
