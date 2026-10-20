# Modifies the damage output of attack actions by strength amount
extends BaseActionInterceptor

const VULNERABLE_DAMAGE_MULTIPLIER: float = 1.5

func process_action_interception(action_interceptor_processor: ActionInterceptorProcessor, _preview_mode: bool = false) -> int:
	# Vulnerability belongs to the target; an ownerless persistent field remains valid.
	var target: BaseCombatant = action_interceptor_processor.target
	if not is_instance_valid(target) or not target.is_alive():
		return ACTION_ACCEPTENCES.REJECTED
	
	var damage: int = action_interceptor_processor.get_shadowed_action_values("damage", 0)
	damage = int(damage * VULNERABLE_DAMAGE_MULTIPLIER)
	action_interceptor_processor.set_shadowed_action_values("damage", damage)
	
	return ACTION_ACCEPTENCES.CONTINUE
