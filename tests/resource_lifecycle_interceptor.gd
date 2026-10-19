extends BaseActionInterceptor
## Observable fixture: exercises the real chain and tracks only weak references.
func process_action_interception(processor: ActionInterceptorProcessor, preview := false) -> int:
	var state: Dictionary = processor.parent_action.values["probe"]
	state.refs.append(weakref(processor))
	if preview:
		state.previews += 1
	else:
		state.effects += 1
	processor.set_shadowed_action_values("amount", processor.get_shadowed_action_values("amount", 0) + 3)
	return ACTION_ACCEPTENCES.REJECTED if state.reject and not preview else ACTION_ACCEPTENCES.CONTINUE
