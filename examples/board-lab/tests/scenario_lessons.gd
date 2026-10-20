extends RefCounted
## Every state change below comes from authored cards, map buttons, or ordinary movement.

func entry(c) -> bool:
	var ui: RefCounted = c.ui
	var enemy: BaseCombatant = Global.get_alive_enemies()[0]
	if not c.check(enemy.enemy_data.object_id == "demo_enemy_sentry" and enemy.board_anchor == Vector2i(2, 2), "entry deploys the authored sentry at enemy 2,2"): return false
	c.check(HandManager.player_hand.size() == 10 and Global.player_data.player_energy == 5, "entry draws original ten cards with five energy")
	# A real illegal cross-board direction request must not consume its card or fee.
	var rejected: Node = ui.find_card("demo_push")
	var energy: int = Global.player_data.player_energy
	var count: int = c.played
	rejected.card_selected.emit(rejected)
	if c.hand.current_selected_card == rejected:
		Signals.board_cell_clicked.emit(enemy.board_id, enemy.board_anchor)
	await c.process_frame
	c.check(ui.find_card("demo_push") == rejected and c.played == count and Global.player_data.player_energy == energy, "cross-board push is rejected before card or energy consumption")
	c.hand._on_background_button_up()
	var input_cases: RefCounted = load(get_script().resource_path.get_base_dir().path_join("scenario_input_cases.gd")).new()
	if not await input_cases.run(c, enemy): return false
	var hero_uid: String = c.player.unit_uid
	var enemy_uid: String = enemy.unit_uid
	if not await ui.play("demo_field", "enemy", Vector2i(2, 3)): return false
	var board: BoardData = c.director.battlefield.get_board("enemy")
	var fields: FieldController = FieldController.for_board(board)
	c.check(board.get_fields(Vector2i(2, 3), "demo_hazard").size() == 1, "field card creates an actual hazard on the selected empty enemy cell")
	if not await ui.play("demo_cross_step", "enemy", Vector2i(2, 3)): return false
	c.check(c.player.board_id == "enemy" and c.player.board_anchor == Vector2i(2, 3) and c.player.unit_uid == hero_uid, "cross-step card transfers the real hero with stable UID")
	var hp: int = c.player.get_combatant_health()
	if not await ui.walk(Vector2i(1, 3)): return false
	c.check(hp - c.player.get_combatant_health() == 3, "leaving adjacent hostile control consumes exactly three HP through a real opportunity attack")
	hp = c.player.get_combatant_health()
	if not await ui.walk(Vector2i(2, 3)): return false
	c.check(c.player.get_combatant_health() == hp, "same-action return does not duplicate the sentry opportunity attack")
	var enemy_hp: int = enemy.get_combatant_health()
	if not await ui.play("demo_swap", enemy.board_id, enemy.board_anchor): return false
	c.check(c.player.board_anchor == Vector2i(2, 2) and enemy.board_anchor == Vector2i(2, 3) and enemy.unit_uid == enemy_uid, "swap card exchanges real occupied cells with stable enemy UID")
	c.check(enemy_hp - enemy.get_combatant_health() == 5, "swapped enemy entering the authored field suffers five damage")
	var block: int = c.player.get_block()
	if not await ui.play("demo_guard"): return false
	c.check(c.player.get_block() == block + 8, "guard card grants its actual eight block")
	enemy_hp = enemy.get_combatant_health()
	if not await ui.end_turn(): return false
	c.check(enemy_hp - enemy.get_combatant_health() == 2, "enemy action starts with two field stay damage before its guard intent")
	c.check(enemy.get_block() == 2, "sentry then executes the authored guard intent")
	var protection: int = enemy.get_combatant_health() + enemy.get_block()
	if not await ui.play("demo_push", enemy.board_id, enemy.board_anchor): return false
	c.check(enemy.board_anchor == Vector2i(2, 4) and protection - enemy.get_combatant_health() - enemy.get_block() == 3, "same-board push moves one cell then deals three collision damage at the boundary")
	if not await ui.walk(Vector2i(2, 3)): return false
	if not await ui.fight(): return false
	return c.check(not fields.active and board.fields.is_empty() and c.director.battlefield == null, "natural entry victory clears authored fields and releases the board world")

func field(c) -> bool:
	var enemies: Array = Global.get_alive_enemies()
	if not c.check(enemies.size() == 2, "second authored encounter contains two real enemies"): return false
	var a: BaseCombatant = enemies[0]
	var b: BaseCombatant = enemies[1]
	if a.enemy_data.object_id != "demo_enemy_anchor":
		a = enemies[1]
		b = enemies[0]
	var hp_a: int = a.get_combatant_health()
	var hp_b: int = b.get_combatant_health()
	if not await c.ui.play("demo_pulse", a.board_id, a.board_anchor): return false
	c.check(hp_a - a.get_combatant_health() == 6 and hp_b - b.get_combatant_health() == 6, "local cross-shaped pulse hits both adjacent enemies for six each")
	var original_hero: BoardPosition = BoardPosition.from_unit(c.player)
	var original_enemy: BoardPosition = BoardPosition.from_unit(a)
	var hero_uid: String = c.player.unit_uid
	var enemy_uid: String = a.unit_uid
	if not await c.ui.play("demo_swap", a.board_id, a.board_anchor): return false
	c.check(c.player.board_id == original_enemy.board_id and c.player.board_anchor == original_enemy.cell and a.board_id == original_hero.board_id and a.board_anchor == original_hero.cell, "real swap card atomically exchanges occupants across the two boards")
	c.check(c.player.unit_uid == hero_uid and a.unit_uid == enemy_uid and a.faction == BaseCombatant.FACTIONS.ENEMY, "cross-board swap preserves UID and enemy faction")
	if not await c.ui.play("demo_strike", a.board_id, a.board_anchor): return false
	c.check(not a.is_alive() and b.is_alive() and Global.is_player_in_combat(), "killing the party-board invader alone does not end combat")
	return await c.ui.fight()
