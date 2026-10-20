## Teleport choice is a pure query. RANDOM_EMPTY uses a stable intent/action seed so repainting
## previews cannot advance gameplay RNG or change the announced landing cell.
extends RefCounted
class_name IntentTeleportResolver

static func choose(board: BoardData, enemy: BaseCombatant, intent: EnemyIntentData, target: BaseCombatant) -> Vector2i:
	var candidates: Array[Vector2i] = []
	var rule: int = intent.enemy_intent_teleport_rule
	for cell: Vector2i in board.all_cells():
		if cell == enemy.board_anchor or not board.can_teleport(enemy, cell):
			continue
		if rule == EnemyIntentData.TELEPORT_RULES.ADJACENT_TO_TARGET and (not board.has_unit(target) or board.unit_distance(enemy, target, cell) != 1):
			continue
		if rule == EnemyIntentData.TELEPORT_RULES.MARKED_CELL:
			if intent.enemy_intent_marked_cell != BaseCombatant.BOARD_ANCHOR_NONE:
				if cell != intent.enemy_intent_marked_cell:
					continue
			elif intent.enemy_intent_marked_field_tag == "" or board.get_fields(cell, intent.enemy_intent_marked_field_tag).is_empty():
				continue
		candidates.append(cell)
	if candidates.is_empty():
		return enemy.board_anchor
	if rule == EnemyIntentData.TELEPORT_RULES.RANDOM_EMPTY:
		var seed_text: String = "%s:%s:%s" % [enemy.unit_uid, intent.object_id, enemy.next_action_tick]
		return candidates[posmod(seed_text.hash(), candidates.size())]
	var best: Vector2i = candidates[0]
	var best_key: int = -1
	for cell: Vector2i in candidates:
		var score: int = 0
		if rule == EnemyIntentData.TELEPORT_RULES.FARTHEST_FROM_OPPONENTS:
			score = 500 - mini(499, IntentResolver._nearest_opponent_distance(board, enemy, cell))
		var key: int = BoardData.sort_key([score, cell.y, cell.x])
		if best_key < 0 or key < best_key:
			best = cell
			best_key = key
	return best
