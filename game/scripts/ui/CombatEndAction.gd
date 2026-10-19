# Utility object for CombatDirector: ends the acting player unit's action asynchronously with
# hierarchical levels of immediacy. A request with higher immediacy replaces the waiting one
# (CombatDirector.request_end_action). Formerly CombatEndTurn; behavior unchanged.
extends RefCounted
class_name CombatEndAction

enum END_ACTION_QUEUE_IMMEDIACY {	# Do not rearrange
	WAIT_FOR_ALL_CARD_PLAYS,
	WAIT_FOR_ACTIONS,
	IMMEDIATE
	}

var _director: CombatDirector = null	# the director to call back; null once disabled
var immediacy: int = END_ACTION_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS

func _init(director: CombatDirector, _immediacy: int = END_ACTION_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS):
	_director = director
	immediacy = _immediacy

func wait() -> void:
	match immediacy:
		END_ACTION_QUEUE_IMMEDIACY.IMMEDIATE:
			# forces the action to instantly end, removing all remaining card plays and actions
			HandManager.refund_card_queue()
			ActionHandler.clear_all_actions()
			end_action()
		END_ACTION_QUEUE_IMMEDIACY.WAIT_FOR_ACTIONS:
			# prevents further card plays but finishes the rest of the current action stack
			HandManager.refund_card_queue()
			HandManager.set_disable_hand(true)
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
			end_action()
		END_ACTION_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS, _:
			# default: wait for all queued card plays and their actions before ending the action
			HandManager.set_disable_hand(true)
			while len(HandManager.card_play_queue) > 0 or ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
			end_action()

func disable() -> void:
	_director = null

func end_action() -> void:
	if _director != null:
		_director.finish_player_action(self)
