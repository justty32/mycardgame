## Enemy intent preview on the board (combat framework Phase 2): per enemy the intended target,
## planned move cell / path and hit cells (IntentResolver), and per unit the damage expected before
## its next action. Owned by CombatDirector; refreshed when units move, spawn, die, the timeline or
## an intent changes. Replaces Player.update_incoming_damage_amount's sum over all enemies; with the
## legacy defaults (range -1, HOLD, equal speeds) the totals are identical.
extends RefCounted
class_name ThreatPreview

var director: CombatDirector = null
## enemy unit_uid -> IntentResolver plan (see IntentResolver.resolve()).
var plans: Dictionary[String, Dictionary] = {}

func _init(combat_director: CombatDirector = null) -> void:
	director = combat_director

## Re-resolves every living enemy's current intent and refreshes its intent display.
func refresh() -> void:
	plans.clear()
	for enemy: Enemy in Global.get_alive_enemies():
		if enemy.enemy_data == null:
			continue
		var board: BoardData = BoardData.get_for_unit(enemy)
		var intent: EnemyIntentData = enemy.enemy_data.get_current_intent()
		var target: BaseCombatant = IntentResolver.choose_target(board, enemy, intent)
		var plan: Dictionary = IntentResolver.resolve(board, enemy, intent, target)
		plans[enemy.unit_uid] = plan
		enemy.apply_intent_plan(plan)
		enemy.update_enemy_intent()

func get_plan(enemy: BaseCombatant) -> Dictionary:
	if enemy == null:
		return {}
	return plans.get(enemy.unit_uid, {})

## Pure Phase 4 scoring seam. Positive hazard is damage; healing / block are negative.
## opportunity_damage describes leaving this anchor, with the current action's ZOC dedup state.
func position_costs(unit: BaseCombatant, anchor: Vector2i) -> Dictionary:
	var result: Dictionary = {"hazard": 0.0, "opportunity_damage": 0}
	if director == null or unit == null:
		return result
	var board: BoardData = BoardData.get_for_unit(unit)
	if board == null:
		return result
	if board.field_controller != null:
		var fields: FieldController = board.field_controller.get_ref() as FieldController
		if fields != null:
			result["hazard"] = fields.preview_hazard(anchor, unit)
	result["opportunity_damage"] = board.preview_opportunity_damage(unit, anchor)
	return result

## Whether the enemy's current intent can hit its target (true without a plan: legacy behavior).
func can_hit(enemy: BaseCombatant) -> bool:
	var plan: Dictionary = get_plan(enemy)
	return plan.is_empty() or bool(plan.get("can_hit", true))

## Damage the unit is expected to take from enemy intents that act before its next action.
## The acting unit's next action is projected with the default delay plus its paid-move delay.
func incoming_damage_for(unit: BaseCombatant) -> int:
	if unit == null:
		return 0
	var unit_next: int = unit.next_action_tick
	if director != null and director.timeline != null and director.acting_unit == unit:
		unit_next = director.current_tick + director.timeline.wait_for(director.rules.default_action_delay + unit.action_extra_delay, unit.speed)
	var total: int = 0
	for enemy: Enemy in Global.get_alive_enemies():
		var plan: Dictionary = get_plan(enemy)
		if plan.is_empty() or plan.get("error", "") not in ["", "out_of_range"]:
			continue
		if director != null and director.is_running and enemy != director.acting_unit and enemy.next_action_tick >= unit_next:
			continue
		if plan.get("can_hit", false) and (plan.get("targets", []) as Array).has(unit):
			total += enemy.enemy_intent_attack_damage * enemy.enemy_intent_number_of_attacks
		if (plan.get("path_targets", []) as Array).has(unit):
			var intent: EnemyIntentData = enemy.enemy_data.get_current_intent()
			if intent != null:
				total += int(FieldPreview.preview_actions(intent.enemy_intent_path_actions, enemy, unit, false, false))
	return total
