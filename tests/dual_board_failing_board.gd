extends BoardData
## Fault injection at the commit boundary, after ordinary can_stand preflight succeeds.
var fail_next_place: bool = false

func place(unit: BaseCombatant, anchor: Vector2i) -> bool:
	if fail_next_place:
		fail_next_place = false
		return false
	return super.place(unit, anchor)
