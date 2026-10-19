## Player-controlled unit: the action lasts until end_action_requested is served
## (CombatEndAction -> CombatDirector.finish_player_action). Cards are played through the
## normal Hand / HandManager path meanwhile.
extends BaseUnitController
class_name PlayerInputController

func decide(director: CombatDirector, _unit: BaseCombatant) -> Variant:
	await director.wait_for_player_action()
	return null
