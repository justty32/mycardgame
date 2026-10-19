## Rooted (combat framework Phase 2): the target cannot move or be displaced. Intercepts
## ActionMoveUnit / ActionDisplaceUnit on the affected unit and sets their "distance" to 0.
## Tied to a status effect (framework test data: status_rooted). No side effects (preview safe).
extends BaseActionInterceptor

func process_action_interception(action_interceptor_processor: ActionInterceptorProcessor, _preview_mode: bool = false) -> int:
	action_interceptor_processor.set_shadowed_action_values("distance", 0)
	return ACTION_ACCEPTENCES.CONTINUE
