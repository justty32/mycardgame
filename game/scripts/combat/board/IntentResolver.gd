## Pure enemy intent resolution on the board (combat framework Phase 2): intended target, planned
## move cell / path and what the intent hits from there. Shared by ThreatPreview (display), BoardView
## (ghost) and CombatDirector (execution). Deterministic: candidates sort by (rule score, path
## cost, y, x). Queries do not consume RNG or mutate unit positions.
extends RefCounted
class_name IntentResolver

const FAR: int = 1 << 20

## The intent's target among the enemy's opponents (EnemyIntentData.TARGET_RULES).
static func choose_target(board: BoardData, enemy: BaseCombatant, intent: EnemyIntentData) -> BaseCombatant:
	var hero: BaseCombatant = UnitRegistry.get_hero()
	if intent == null:
		return hero
	var rule: int = intent.enemy_intent_target_rule
	if rule == EnemyIntentData.TARGET_RULES.SELF:
		return enemy
	if board == null or rule in [EnemyIntentData.TARGET_RULES.HERO, EnemyIntentData.TARGET_RULES.RANDOM, EnemyIntentData.TARGET_RULES.MARKED]:
		return hero
	var candidates: Array[BaseCombatant] = []
	var local: Array[BaseCombatant] = []
	for unit: BaseCombatant in _target_units(board):
		if unit.is_alive() and BoardPositionQueries.opponents(enemy, unit):
			candidates.append(unit)
			if board.has_unit(unit):
				local.append(unit)
	# A has no cross-board distance. Distance rules first compare actual local units;
	# with no comparable unit, choose a stable UID without inventing a numeric distance.
	if rule in [EnemyIntentData.TARGET_RULES.NEAREST, EnemyIntentData.TARGET_RULES.FARTHEST]:
		if not local.is_empty():
			candidates = local
		else:
			candidates.sort_custom(func(a: BaseCombatant, b: BaseCombatant): return a.unit_uid < b.unit_uid)
			return candidates[0] if not candidates.is_empty() else hero
	var best: BaseCombatant = null
	var best_score: int = 0
	for unit: BaseCombatant in candidates:
		var score: int = 0
		match rule:
			EnemyIntentData.TARGET_RULES.NEAREST:
				score = board.unit_distance(enemy, unit)
			EnemyIntentData.TARGET_RULES.FARTHEST:
				score = FAR - board.unit_distance(enemy, unit)
			EnemyIntentData.TARGET_RULES.LOWEST_HP:
				score = unit.get_combatant_health()
			EnemyIntentData.TARGET_RULES.HIGHEST_HP:
				score = FAR - unit.get_combatant_health()
		if best == null or score < best_score or (score == best_score and unit.unit_uid < best.unit_uid):
			best = unit
			best_score = score
	return best if best != null else hero

## Resolves an intent: {"target", "move_cell", "path", "cells", "targets", "can_hit"}.
## move_cell is the anchor the enemy plans to act from (its anchor when it does not move).
static func resolve(board: BoardData, enemy: BaseCombatant, intent: EnemyIntentData, target: BaseCombatant) -> Dictionary:
	var plan: Dictionary = {"error": "", "source_board_id": enemy.board_id, "target_board_id": target.board_id if is_instance_valid(target) else enemy.board_id, "target": target, "move_cell": enemy.board_anchor, "path": [] as Array[Vector2i], "cells": [] as Array[Vector2i], "targets": [] as Array[BaseCombatant], "can_hit": true}
	if board == null or intent == null or not board.has_unit(enemy):
		if is_instance_valid(target):
			plan["targets"] = [target] as Array[BaseCombatant]
		return plan
	var move_distance: int = intent.enemy_intent_move_distance if intent.enemy_intent_move_distance >= 0 else enemy.move_range
	if is_instance_valid(target) and target != enemy and (board.has_unit(target) or intent.enemy_intent_move == EnemyIntentData.MOVE_MODES.TELEPORT):
		var choice: Array = _choose_move(board, enemy, intent, target, move_distance)
		plan["move_cell"] = choice[0]
		plan["path"] = choice[1]
	var path_targets: Array[BaseCombatant] = []
	if intent.enemy_intent_move == EnemyIntentData.MOVE_MODES.CHARGE and not intent.enemy_intent_path_actions.is_empty():
		for cell: Vector2i in plan["path"]:
			for crossed: BaseCombatant in board.units_in_cells(BoardData.footprint_cells(cell, enemy.footprint)):
				if crossed != enemy and not path_targets.has(crossed):
					path_targets.append(crossed)
	plan["path_targets"] = path_targets
	var attack_anchor: Vector2i = enemy.board_anchor if intent.enemy_intent_move_after else plan["move_cell"]
	var hit: Dictionary = hits_from(board, enemy, attack_anchor, intent, target)
	plan["cells"] = hit["cells"]
	plan["targets"] = hit["targets"]
	plan["can_hit"] = hit["can_hit"]
	plan["error"] = hit.get("error", "")
	plan["target_board_id"] = hit.get("target_board_id", plan["target_board_id"])
	return plan

## What the intent hits when the enemy acts from anchor: {"cells", "targets", "can_hit"}.
## Range -1 (legacy) always hits the target; SINGLE hits the target only.
static func hits_from(board: BoardData, enemy: BaseCombatant, anchor: Vector2i, intent: EnemyIntentData, target: BaseCombatant) -> Dictionary:
	var result: Dictionary = {"cells": [] as Array[Vector2i], "targets": [] as Array[BaseCombatant], "can_hit": false, "target_board_id": "", "error": ""}
	if not is_instance_valid(target) or not target.is_alive():
		return result
	if board == null or intent == null:
		result["targets"] = [target] as Array[BaseCombatant]
		result["can_hit"] = true
		return result
	var target_board: BoardData = board if board.has_unit(target) else BoardData.get_for_unit(target)
	if target_board == null:
		return result
	var target_cell: Vector2i = target.board_anchor
	if target_board == board:
		for cell: Vector2i in board.get_unit_cells(target):
			if board.footprint_distance_to_cell(anchor, enemy.footprint, cell) < board.footprint_distance_to_cell(anchor, enemy.footprint, target_cell):
				target_cell = cell
	var resolved: Dictionary = BoardTargeting.geometry(target_board, enemy, target_cell, intent.enemy_intent_shape, intent.enemy_intent_range, "", anchor)
	if not resolved.valid:
		result["error"] = resolved.error
		return result
	var action_error: String = BoardTargeting.check_action_geometry(target_board, enemy, target_cell, intent.enemy_intent_custom_actions)
	if action_error != "":
		result["error"] = action_error
		return result
	var effect_board: BoardData = BoardTargeting._battlefield_for(target_board).get_board(resolved.board_id)
	result["target_board_id"] = resolved.board_id
	var cells: Array[Vector2i] = []
	cells.assign(resolved.cells)
	result["cells"] = cells
	if intent.enemy_intent_shape == BoardTargeting.TARGET_SHAPES.SINGLE:
		result["cells"] = target_board.get_unit_cells(target)
		result["targets"] = [target] as Array[BaseCombatant]
		result["can_hit"] = true
		return result
	var targets: Array[BaseCombatant] = []
	for unit: BaseCombatant in effect_board.units_in_cells(cells):
		if unit != enemy and BoardPositionQueries.opponents(enemy, unit):
			targets.append(unit)
	result["targets"] = targets
	result["can_hit"] = not targets.is_empty()
	return result

static func _target_units(board: BoardData) -> Array[BaseCombatant]:
	if board == null:
		return []
	return BoardTargeting._battlefield_for(board).get_units()

## [anchor, path] for the intent's move mode.
static func _choose_move(board: BoardData, enemy: BaseCombatant, intent: EnemyIntentData, target: BaseCombatant, move_distance: int) -> Array:
	var stay: Array = [enemy.board_anchor, [] as Array[Vector2i]]
	var mode: int = intent.enemy_intent_move
	var teleport: bool = mode == EnemyIntentData.MOVE_MODES.TELEPORT
	var preview: BaseAction = ActionGenerator.create_actions(enemy, null, [enemy], [{Scripts.ACTION_MOVE_UNIT: {"mode": ActionMoveUnit.MODE_TELEPORT if teleport else ActionMoveUnit.MODE_TO_CELL, "distance": -1 if teleport else move_distance}}], null)[0]
	var processors: Array[ActionInterceptorProcessor] = preview._intercept_action([enemy], true)
	if processors.is_empty() or int(processors[0].get_shadowed_action_values("distance", -1 if teleport else move_distance)) == 0 or (teleport and bool(processors[0].get_shadowed_action_values("teleport_blocked", false))):
		return stay
	if not teleport:
		move_distance = int(processors[0].get_shadowed_action_values("distance", move_distance))
	if teleport:
		return [IntentTeleportResolver.choose(board, enemy, intent, target), [] as Array[Vector2i]]
	if move_distance <= 0:
		return stay
	match mode:
		EnemyIntentData.MOVE_MODES.HOLD:
			return stay
		EnemyIntentData.MOVE_MODES.CHARGE:
			var charged: Array = _charge(board, enemy, target, move_distance)
			if not charged.is_empty():
				return charged
			return _best(board, enemy, intent, target, move_distance, EnemyIntentData.MOVE_MODES.APPROACH)
	return _best(board, enemy, intent, target, move_distance, mode)

## Scores every reachable anchor (including staying) and returns the lowest key.
static func _best(board: BoardData, enemy: BaseCombatant, intent: EnemyIntentData, target: BaseCombatant, move_distance: int, mode: int) -> Array:
	var reachable: Dictionary = board.reachable_cells(enemy, move_distance)
	var intent_range: int = intent.enemy_intent_range
	var preferred: int = intent.enemy_intent_preferred_range if intent.enemy_intent_preferred_range >= 0 else intent_range
	var best_anchor: Vector2i = enemy.board_anchor
	var best_key: int = -1
	var found_flank: bool = false
	for anchor: Vector2i in reachable:
		var path: Array = reachable[anchor]
		var distance: int = board.unit_distance(enemy, target, anchor)
		var primary: int = 0
		var secondary: int = 0
		match mode:
			EnemyIntentData.MOVE_MODES.FLANK:
				if distance != 1:
					continue
				found_flank = true
				primary = BoardPositionQueries.count_adjacent(board, enemy, "OPPONENT", anchor) - 1
				secondary = 0 if BoardPositionQueries.is_flanked(board, enemy, target, anchor) else 1
			EnemyIntentData.MOVE_MODES.APPROACH:
				if intent_range < 0 or distance <= intent_range:
					primary = 0	# in range: shortest path wins
				else:
					primary = 1 + distance
			EnemyIntentData.MOVE_MODES.RETREAT:
				primary = 500 - min(499, _nearest_opponent_distance(board, enemy, anchor))
				secondary = 0 if (intent_range < 0 or distance <= intent_range) else 1
			EnemyIntentData.MOVE_MODES.KEEP_RANGE:
				if preferred < 0:
					primary = 0
				else:
					primary = abs(distance - preferred)
				secondary = 500 - min(499, _nearest_opponent_distance(board, enemy, anchor, target))
		var key: int = BoardData.sort_key([primary, secondary, board.path_cost(enemy, path), anchor.y, anchor.x])
		if best_key < 0 or key < best_key:
			best_key = key
			best_anchor = anchor
	if mode == EnemyIntentData.MOVE_MODES.FLANK and not found_flank:
		return _best(board, enemy, intent, target, move_distance, EnemyIntentData.MOVE_MODES.APPROACH)
	var best_path: Array[Vector2i] = []
	best_path.assign(reachable.get(best_anchor, []))
	return [best_anchor, best_path]

## Straight move along the shared row / column toward the target, stopping adjacent to it or
## before the first blocker, at most move_distance cells.
static func _charge(board: BoardData, enemy: BaseCombatant, target: BaseCombatant, move_distance: int) -> Array:
	var anchor: Vector2i = enemy.board_anchor
	var path: Array[Vector2i] = []
	var spent: int = 0
	if not board.is_in_line(enemy, target):
		# A single alignment step may precede the straight charge.
		var alignment: Vector2i = BaseCombatant.BOARD_ANCHOR_NONE
		var best_key: int = -1
		for offset: Vector2i in BoardData.NEIGHBOURS_FOUR:
			var next: Vector2i = anchor + offset
			if not _charge_can_pass(board, enemy, next) or not _aligned(enemy, next, target):
				continue
			var cost: int = board.step_cost(enemy, anchor, next)
			var key: int = BoardData.sort_key([cost, next.y, next.x])
			if cost <= move_distance and (best_key < 0 or key < best_key):
				best_key = key
				alignment = next
		if alignment == BaseCombatant.BOARD_ANCHOR_NONE:
			return []
		spent = board.step_cost(enemy, anchor, alignment)
		anchor = alignment
		path.append(anchor)
	var direction: Vector2i = BoardTargeting.main_axis_direction(anchor, target.board_anchor, board.rules.displace_tie_axis)
	while spent < move_distance and board.unit_distance(enemy, target, anchor) > 1:
		var next: Vector2i = anchor + direction
		var cost: int = board.step_cost(enemy, anchor, next)
		if direction == Vector2i.ZERO or not _charge_can_pass(board, enemy, next) or spent + cost > move_distance:
			break
		spent += cost
		anchor = next
		path.append(next)
	# Flying may cross occupied anchors but must finish on a free one.
	while not path.is_empty() and not board.can_stand(enemy, path.back()):
		path.pop_back()
	return [path.back() if not path.is_empty() else enemy.board_anchor, path]

static func _charge_can_pass(board: BoardData, enemy: BaseCombatant, cell: Vector2i) -> bool:
	return board.can_pass(enemy, cell) if enemy.ignores_occupancy else board.can_stand(enemy, cell)

static func _aligned(enemy: BaseCombatant, anchor: Vector2i, target: BaseCombatant) -> bool:
	for a: Vector2i in BoardData.footprint_cells(anchor, enemy.footprint):
		for b: Vector2i in BoardData.footprint_cells(target.board_anchor, target.footprint):
			if a.x == b.x or a.y == b.y:
				return true
	return false

## Distance from a hypothetical anchor to the nearest opponent (excluding one unit).
static func _nearest_opponent_distance(board: BoardData, enemy: BaseCombatant, anchor: Vector2i, excluded: BaseCombatant = null) -> int:
	var best: int = FAR
	for unit: BaseCombatant in board.get_units():
		if unit == excluded or not unit.is_alive() or unit.faction == BaseCombatant.FACTIONS.NEUTRAL:
			continue
		if BoardTargeting.faction_matches(enemy, unit, BoardTargeting.TARGET_FACTIONS.OPPONENT):
			best = min(best, board.unit_distance(enemy, unit, anchor))
	return best if best < FAR else 0
