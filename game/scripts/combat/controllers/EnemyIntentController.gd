## Enemy unit: performs the intent decided when it last entered the timeline
## (Enemy.decide_next_intent), targeting the hero. Board movement and shapes arrive in Phase 2.
extends BaseUnitController
class_name EnemyIntentController

func decide(director: CombatDirector, unit: BaseCombatant) -> Variant:
	await director.perform_enemy_intent(unit as Enemy)
	return null
