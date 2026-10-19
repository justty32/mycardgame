# Validator for checking if at least one remaining enemy is attacking (and its intent can reach its
# target on the board; always true for legacy intents without a range)
# NOTE: See ValidatorCardPlayEnemyAttacking
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var enemies: Array[Node] = Global.get_tree().get_nodes_in_group("enemies")
	for enemy: Enemy in Global.get_tree().get_nodes_in_group("enemies"):
		if enemy.is_alive() and enemy.is_attacking() and enemy.intent_can_hit:
			return true
	return false
