# Ends the acting player unit's action (formerly "ends the turn") when processed
# See CombatEndAction for different levels of immediacy for ending actions
extends BaseAction

func perform_action():
	var end_turn_immediacy_level: int = get_action_value("end_turn_immediacy_level", CombatEndAction.END_ACTION_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS)
	Signals.end_action_requested.emit(end_turn_immediacy_level)
