extends RefCounted
# 題材 probe：驗 apocalypse 內容包已載入。由 Smoke 經 runner 的 --pack/--pack-tests 呼叫。

func check_loaded(global_data: Node) -> Dictionary:
	var result: Dictionary = {}
	var card: Resource = global_data.get_card_data("apo_card_probe_strike")
	result["APO: probe card registered"] = card != null
	if card == null:
		return result
	result["APO: declared cost and damage"] = card.card_energy_cost == 1 and card.card_values.get("damage") == 6
	result["APO: attack action reference"] = card.card_play_actions.size() == 1 and card.card_play_actions[0].has("res://scripts/actions/combatant_actions/ActionAttackGenerator.gd")
	return result
