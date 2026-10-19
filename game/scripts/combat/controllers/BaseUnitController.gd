## Decides what a unit does during its own action on the combat timeline.
## CombatDirector awaits decide(); a player controller waits for input, an enemy controller
## performs the current intent. Phase 4 adds AI party controllers returning an AiPlan.
extends RefCounted
class_name BaseUnitController

## Performs the unit's action. May await. Returns the plan (null until AiPlan exists).
func decide(_director: CombatDirector, _unit: BaseCombatant) -> Variant:
	return null
