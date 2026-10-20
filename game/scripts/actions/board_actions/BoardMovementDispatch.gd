## Serial multi-target movement; interception and field-owner resolution happen at execution.
extends BaseAction
class_name BoardMovementDispatch

var source: BaseAction
var mover_ref: WeakRef
var method: StringName

func _init(action: BaseAction, unit: BaseCombatant, callback: StringName) -> void:
	source = action
	mover_ref = weakref(unit) if is_instance_valid(unit) else null
	method = callback
	inherit_execution_context(source)

func perform_action() -> void:
	if not source.prepare_execution():
		return
	var unit: BaseCombatant = mover_ref.get_ref() if mover_ref != null else null
	if not is_instance_valid(unit) or not unit.is_alive():
		return
	var board: BoardData = BoardData.get_for_unit(unit)
	if board != null:
		for processor: ActionInterceptorProcessor in source._intercept_action([unit]):
			source.call(method, board, unit, processor)
