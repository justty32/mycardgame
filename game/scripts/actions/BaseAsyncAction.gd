## Abstract class for all asynchronous actions which require some kind of indefinite waiting period
## before the action is allowed to finish.
## During the async period ActionHandler will lock and wait until the action finishes.
## The typical use flow is to have perform_action() set up an await 
## of some kind (eg network, animation, user input like card picking), after which it
## calls perform_async_action() which then emits action_async_finished
extends BaseAction
class_name BaseAsyncAction

## Flag used to check if the action is currently await'ing a signal
var async_awaiting: bool = false
var async_finished: bool = false
var async_cancelled: bool = false

# Caching this allows you to use the same interceptors between perform_action() and perform_async_action()
# without producing side effects multiple times.
var _interceptor_processors_cached: bool = false
var _cached_interceptor_processors: Array[ActionInterceptorProcessor] = []

func _init() -> void:
	action_async_finished.connect(_on_async_finished)

func begin_async_action() -> void:
	async_finished = false
	async_cancelled = false
	async_awaiting = false
	_clear_interceptor_cache()

func finish_async_action() -> void:
	if not async_finished:
		action_async_finished.emit()

func _on_async_finished() -> void:
	async_finished = true
	async_awaiting = false
	_clear_interceptor_cache()

func _clear_interceptor_cache() -> void:
	_cached_interceptor_processors.clear()
	_interceptor_processors_cached = false

### Override

## Async actions should use perform_action() to define an await callback, and
## override perform_async_action() for the actual effect.
func perform_action() -> void:
	# 1) perform interception and cache it (optional)
	# 2) set up async event here
	# 3) async_awaiting = true
	# 4) await some_callback_signal
	# 5) async_awaiting = false
	# 6) perform_async_action()
	breakpoint

## Override this to fill with interceptable action logic, then emit action_async_finished
func perform_async_action() -> void:
	finish_async_action()

## Override this. This method prevents possibility of infinite hanging asyncs.
func force_action_end() -> void:
	async_cancelled = true
	finish_async_action()

### Keep

func is_async_action() -> bool:
	return true

# Overridden to allow caching of results
func _intercept_action(targets: Array[BaseCombatant] = get_adjusted_action_targets(), preview_mode: bool = false) -> Array[ActionInterceptorProcessor]:
	# Previews must neither consume the execution cache nor suppress real effects.
	if preview_mode:
		return super(targets, true)
	if not _interceptor_processors_cached:
		_cached_interceptor_processors = super(targets, preview_mode)
		_interceptor_processors_cached = true
	return _cached_interceptor_processors
