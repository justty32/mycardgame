## Pure enemy intent resolution on the board (combat framework Phase 2): intended target, planned
## move cell / path and what the intent hits from there. Shared by ThreatPreview (display), BoardView
## (ghost) and CombatDirector (execution). Deterministic: candidates sort by (rule score, path
## length, y, x). FLANK falls back to APPROACH and TELEPORT to HOLD until Phase 2b.
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
	var best: BaseCombatant = null
	var best_score: int = 0
	for unit: BaseCombatant in board.get_units():
		if not unit.is_alive() or not BoardTargeting.faction_matches(enemy, unit, BoardTargeting.TARGET_FACTIONS.OPPONENT) or unit.faction == BaseCombatant.FACTIONS.NEUTRAL:
			continue
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
		if best == null or score < best_score:
			best = unit
			best_score = score
	return best if best != null else hero

## Resolves an intent: {"target", "move_cell", "path", "cells", "targets", "can_hit"}.
## move_cell is the anchor the enemy plans to act from (its anchor when it does not move).
static func resolve(board: BoardData, enemy: BaseCombatant, intent: EnemyIntentData, target: BaseCombatant) -> Dictionary:
	var plan: Dictionary = {"target": target, "move_cell": enemy.board_anchor, "path": [] as Array[Vector2i], "cells": [] as Array[Vector2i], "targets": [] as Array[BaseCombatant], "can_hit": true}
	if board == null or intent == null or not board.has_unit(enemy):
		if target != null:
			plan["targets"] = [target] as Array[BaseCombatant]
		return plan
	var move_distance: int = intent.enemy_intent_move_distance if intent.enemy_intent_move_distance >= 0 else enemy.move_range
	if target != null and board.has_unit(target) and target != enemy:
		var choice: Array = _choose_move(board, enemy, intent, target, move_distance)
		plan["move_cell"] = choice[0]
		plan["path"] = choice[1]
	var hit: Dictionary = hits_from(board, enemy, plan["move_cell"], intent, target)
	plan["cells"] = hit["cells"]
	plan["targets"] = hit["targets"]
	plan["can_hit"] = hit["can_hit"]
	return plan

## What the intent hits when the enemy acts from anchor: {"cells", "targets", "can_hit"}.
## Range -1 (legacy) always hits the target; SINGLE hits the target only.
static func hits_from(board: BoardData, enemy: BaseCombatant, anchor: Vector2i, intent: EnemyIntentData, target: BaseCombatant) -> Dictionary:
	var result: Dictionary = {"cells": [] as Array[Vector2i], "targets": [] as Array[BaseCombatant], "can_hit": true}
	if target == null:
		result["can_hit"] = false
		return result
	if board == null or not board.has_unit(target):
		result["targets"] = [target] as Array[BaseCombatant]
		return result
	var in_range: bool = intent.enemy_intent_range < 0 or board.unit_distance(enemy, target, anchor) <= intent.enemy_intent_range
	if not in_range:
		result["can_hit"] = false
		return result
	var shape: int = intent.enemy_intent_shape
	if shape == BoardTargeting.TARGET_SHAPES.SINGLE:
		result["cells"] = board.get_unit_cells(target)
		result["targets"] = [target] as Array[BaseCombatant]
		return result
	var cells: Array[Vector2i] = BoardTargeting.cells_in_shape(board, anchor, target.board_anchor, shape, intent.enemy_intent_range)
	result["cells"] = cells
	var targets: Array[BaseCombatant] = []
	for unit: BaseCombatant in board.units_in_cells(cells):
		if unit != enemy and BoardTargeting.faction_matches(enemy, unit, BoardTargeting.TARGET_FACTIONS.OPPONENT):
			targets.append(unit)
	result["targets"] = targets
	result["can_hit"] = not targets.is_empty()
	return result

## [anchor, path] for the intent's move mode.
static func _choose_move(board: BoardData, enemy: BaseCombatant, intent: EnemyIntentData, target: BaseCombatant, move_distance: int) -> Array:
	var stay: Array = [enemy.board_anchor, [] as Array[Vector2i]]
	if move_distance <= 0:
		return stay
	var mode: int = intent.enemy_intent_move
	match mode:
		EnemyIntentData.MOVE_MODES.HOLD, EnemyIntentData.MOVE_MODES.TELEPORT:
			return stay
		EnemyIntentData.MOVE_MODES.CHARGE:
			if board.is_in_line(enemy, target):
				return _charge(board, enemy, target, move_distance)
			return _best(board, enemy, intent, target, move_distance, EnemyIntentData.MOVE_MODES.APPROACH)
		EnemyIntentData.MOVE_MODES.FLANK:
			return _best(board, enemy, intent, target, move_distance, EnemyIntentData.MOVE_MODES.APPROACH)
	return _best(board, enemy, intent, target, move_distance, mode)

## Scores every reachable anchor (including staying) and returns the lowest key.
static func _best(board: BoardData, enemy: BaseCombatant, intent: EnemyIntentData, target: BaseCombatant, move_distance: int, mode: int) -> Array:
	var reachable: Dictionary = board.reachable_cells(enemy, move_distance)
	var intent_range: int = intent.enemy_intent_range
	var preferred: int = intent.enemy_intent_preferred_range if intent.enemy_intent_preferred_range >= 0 else intent_range
	var best_anchor: Vector2i = enemy.board_anchor
	var best_key: int = -1
	for anchor: Vector2i in reachable:
		var path: Array = reachable[anchor]
		var distance: int = board.unit_distance(enemy, target, anchor)
		var primary: int = 0
		var secondary: int = 0
		match mode:
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
		var key: int = BoardData.sort_key([primary, secondary, len(path), anchor.y, anchor.x])
		if best_key < 0 or key < best_key:
			best_key = key
			best_anchor = anchor
	var best_path: Array[Vector2i] = []
	best_path.assign(reachable.get(best_anchor, []))
	return [best_anchor, best_path]

## Straight move along the shared row / column toward the target, stopping adjacent to it or
## before the first blocker, at most move_distance cells.
static func _charge(board: BoardData, enemy: BaseCombatant, target: BaseCombatant, move_distance: int) -> Array:
	var direction: Vector2i = BoardTargeting.main_axis_direction(enemy.board_anchor, target.board_anchor, board.rules.displace_tie_axis)
	var anchor: Vector2i = enemy.board_anchor
	var path: Array[Vector2i] = []
	for step: int in move_distance:
		if board.unit_distance(enemy, target, anchor) <= 1:
			break
		var next: Vector2i = anchor + direction
		if not board.can_stand(enemy, next):
			break
		anchor = next
		path.append(next)
	return [anchor, path]

## Distance from a hypothetical anchor to the nearest opponent (excluding one unit).
static func _nearest_opponent_distance(board: BoardData, enemy: BaseCombatant, anchor: Vector2i, excluded: BaseCombatant = null) -> int:
	var best: int = FAR
	for unit: BaseCombatant in board.get_units():
		if unit == excluded or not unit.is_alive() or unit.faction == BaseCombatant.FACTIONS.NEUTRAL:
			continue
		if BoardTargeting.faction_matches(enemy, unit, BoardTargeting.TARGET_FACTIONS.OPPONENT):
			best = min(best, board.unit_distance(enemy, unit, anchor))
	return best if best < FAR else 0
