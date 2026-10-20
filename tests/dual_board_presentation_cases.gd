extends RefCounted
## Inspect the actual Root sprite/HUD tree and dispatch handlers only. This never sends input
## events, opens a window, takes a screenshot or claims visual/readability verification.

func run(c) -> void:
	# SceneTree script runs have a 64x64 dummy viewport. Establish the game's logical canvas
	# in this headless fixture; no OS window or hardware input is created or controlled.
	c.root.size = Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 1200)), int(ProjectSettings.get_setting("display/window/size/viewport_height", 700)))
	await c.flow.process_frame
	c.combat.sync_board_views()
	await c.snap_presentation()
	var hero: Player = c.player as Player
	var enemy: Enemy = c.enemy as Enemy
	await c._wait(func(): return not hero.animation_player.is_playing(), "initial run-start animation completes before standing-foot assertions")
	await c.snap_presentation()
	_audit_animation_tracks(c)
	var hero_parent: Node = hero.get_parent()
	var enemy_parent: Node = enemy.get_parent()
	var hero_uid: String = hero.unit_uid
	var enemy_uid: String = enemy.unit_uid
	var controller: BaseUnitController = hero.controller
	var next_tick: int = hero.next_action_tick
	var timeline_contains: bool = c.director.timeline.has(hero)
	var sprite: AnimatedSprite2D = hero.animated_sprite_2d
	var hp: LayeredHealthBar = hero.layered_health_bar
	var intent: HBoxContainer = enemy.enemy_intent
	var start: BoardPosition = BoardPosition.from_unit(hero)
	_assert_unit(c, hero, "initial hero")
	_assert_unit(c, enemy, "initial enemy")
	c._check(not enemy_parent is Container, "board enemy has a stable free-position parent, never an HBox layout owner")
	c._check(hero.is_ancestor_of(hp) and enemy.is_ancestor_of(intent) and hero.is_ancestor_of(hero.selection_button), "HP/intent/hitbox remain under their owning actual unit")
	c._check(c.combat.board_views["party"].get_index() < hero.get_index() and c.combat.board_views["enemy"].get_index() < hero.get_index(), "grid surfaces precede actor subtrees for Control hit testing")

	var events: Dictionary = {"spawned": 0, "removed": 0, "board": 0, "enemy": 0, "tween_has_committed_anchor": false}
	var on_spawn: Callable = func(_unit): events.spawned += 1
	var on_remove: Callable = func(_unit): events.removed += 1
	var on_board: Callable = func(_id, _cell): events.board += 1
	var on_enemy: Callable = func(_unit): events.enemy += 1
	Signals.unit_spawned.connect(on_spawn)
	Signals.unit_removed.connect(on_remove)
	Signals.board_cell_clicked.connect(on_board)
	var on_commit: Callable = func(unit, _from_id, _from, to_id, to):
		if unit == hero and to_id == "enemy":
			events.tween_has_committed_anchor = unit.board_id == str(to_id) and unit.board_anchor == to and c.combat.actor_presentation._tweens.has(hero_uid)
	Signals.enemy_clicked.connect(on_enemy)
	Signals.unit_board_moved.connect(on_commit)
	enemy.selection_button.button_up.emit()
	c._check(events.board == 1 and events.enemy == 0, "actual actor button dispatches one board event without duplicate legacy enemy event")
	c._check(BoardPosition.from_unit(hero).equals(start), "enemy-board click without a card cannot walk the hero across boards")

	await _intent_preview(c, enemy)

	# A real movement request and the real optional Undo button, without physical input.
	var old_undo: bool = c.director.rules.move_undo_allowed
	c.director.rules.move_undo_allowed = true
	var points: int = hero.move_points
	var moved: int = hero.cells_moved_this_action
	Signals.board_cell_clicked.emit("party", Vector2i(2, 4))
	await c._wait(func(): return c._idle() and hero.board_anchor == Vector2i(2, 4), "presentation move completes through board handler")
	await c.flow.process_frame
	c._check(c.combat.undo_move_button.visible and not c.combat.undo_move_button.disabled, "allowed reversible movement exposes an enabled Undo button")
	c.combat.undo_move_button.button_up.emit()
	await c.snap_presentation()
	c._check(BoardPosition.from_unit(hero).equals(start) and hero.move_points == points and hero.cells_moved_this_action == moved, "Undo button restores position and movement resources through Director gate")
	c.director.rules.move_undo_allowed = old_undo
	await c.flow.process_frame
	c._check(not c.combat.undo_move_button.visible, "Undo is hidden when the content rule disables it")

	await c.create_field("field_probe_clock", [start.cell], hero, {"board_id": "party"})
	Signals.board_cell_hovered.emit("party", start.cell)
	await c.flow.process_frame
	var party_view: BoardView = c.combat.board_views["party"]
	c._check(party_view.tooltip_text.contains("x1") and party_view.tooltip_text.contains("300 ticks") and hero.selection_button.tooltip_text == party_view.tooltip_text, "field hover and actual actor hitbox expose stack and remaining ticks")
	c._check(c.combat.board_views["enemy"].tooltip_text == "", "other board at identical coordinates does not inherit field tooltip")
	await c.run_actions(hero, [], [{c.REMOVE_FIELD: {"board_id": "party"}}])
	var before_sprite: Vector2 = sprite.global_position
	var before_root: Vector2 = hero.global_position
	c.enemy_board.set_blocked(Vector2i(2, 4), true)
	await c.transfer(hero, "enemy", Vector2i(2, 4))
	await c.snap_presentation()
	c._check(hero.global_position.is_equal_approx(before_root) and sprite.global_position.is_equal_approx(before_sprite), "rejected transfer leaves actual actor and sprite transforms unchanged")
	c.enemy_board.set_blocked(Vector2i(2, 4), false)
	await c.transfer(hero, "enemy", Vector2i(2, 4))
	await c.snap_presentation()
	_assert_unit(c, hero, "transferred hero")
	c._check(events.tween_has_committed_anchor, "movement tween interpolates only visuals after board identity and anchor are already committed")
	c._check(not sprite.global_position.is_equal_approx(before_sprite), "transfer moves the real sprite, not only a grid marker")
	await c.transfer(hero, "party", start.cell)
	await c.run_actions(hero, [enemy], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "SWAP"}}])
	await c.snap_presentation()
	_assert_unit(c, hero, "swapped hero")
	_assert_unit(c, enemy, "swapped enemy")
	c._check(hero.get_parent() == hero_parent and enemy.get_parent() == enemy_parent and hero.animated_sprite_2d == sprite and hero.layered_health_bar == hp and enemy.enemy_intent == intent, "transfer/swap preserve actual sprite/HUD/intent nodes and stable parents")
	c._check(hero.unit_uid == hero_uid and enemy.unit_uid == enemy_uid and UnitRegistry.get_unit(hero_uid) == hero and UnitRegistry.get_unit(enemy_uid) == enemy and events.spawned == 0 and events.removed == 0, "presentation moves never unregister or recreate units")
	c._check(hero.controller == controller and hero.next_action_tick == next_tick and c.director.timeline.has(hero) == timeline_contains, "presentation transfer/swap retain the controller and single CTB membership/tick")
	await c.run_actions(hero, [enemy], [{Scripts.ACTION_DISPLACE_UNIT: {"mode": "SWAP"}}])
	await c.snap_presentation()
	var semantic: BoardPosition = BoardPosition.from_unit(hero)
	var standing_root: Vector2 = hero.global_position
	hero.play_attack_animation()
	hero.animation_player.advance(0.05)
	c._check(BoardPosition.from_unit(hero).equals(semantic) and hero.global_position.is_equal_approx(standing_root), "existing attack AnimationPlayer leaves root standing transform and semantic board position intact")
	await c._wait(func(): return not hero.animation_player.is_playing(), "existing attack animation completes headlessly")
	await c.snap_presentation()
	_assert_unit(c, hero, "post-animation hero")
	Signals.unit_spawned.disconnect(on_spawn)
	Signals.unit_removed.disconnect(on_remove)
	Signals.board_cell_clicked.disconnect(on_board)
	Signals.enemy_clicked.disconnect(on_enemy)
	Signals.unit_board_moved.disconnect(on_commit)

func _intent_preview(c, enemy: Enemy) -> void:
	var intent: EnemyIntentData = enemy.enemy_data.get_current_intent()
	var original_mode: int = intent.enemy_intent_move
	var original_rule: int = intent.enemy_intent_teleport_rule
	var original_cell: Vector2i = intent.enemy_intent_marked_cell
	intent.enemy_intent_move = EnemyIntentData.MOVE_MODES.TELEPORT
	intent.enemy_intent_teleport_rule = EnemyIntentData.TELEPORT_RULES.MARKED_CELL
	intent.enemy_intent_marked_cell = Vector2i(1, 1)
	c.director.refresh_threats()
	await c.snap_presentation()
	var source: BoardView = c.combat.board_views[enemy.board_id]
	var descriptor: Dictionary = source.enemy_movement_preview(enemy)
	c._check(descriptor.teleport and descriptor.has_destination and descriptor.cell == Vector2i(1, 1) and descriptor.path.is_empty(), "pathless TELEPORT still produces a destination marker on the enemy's source board")
	c._check(not c.combat.board_views["party"].enemy_movement_preview(enemy).has_destination, "teleport destination marker never leaks to another board at the same local cell")
	var marker: Label = enemy.enemy_intent.get_node("MovementMode")
	c._check(marker.visible and marker.text == "TP", "actual enemy intent row displays the teleport fallback mode label")
	# Temporarily put this slow dummy inside the visible projection; no CTB action advances.
	var original_tick: int = enemy.next_action_tick
	enemy.next_action_tick = c.director.current_tick + 1
	c.combat.timeline_bar.refresh()
	var found: bool = false
	for entry: Node in c.combat.timeline_bar.entry_container.get_children():
		if not entry.is_queued_for_deletion() and entry.get_meta("unit_uid", "") == enemy.unit_uid:
			entry.mouse_entered.emit()
			found = source.hovered_enemy == enemy and c.combat.board_views["party"].hovered_enemy == enemy
			entry.mouse_exited.emit()
			break
	c._check(found and source.hovered_enemy == null, "timeline entry hover routes to the same board preview and exit clears it")
	enemy.next_action_tick = original_tick
	c.combat.timeline_bar.refresh()
	intent.enemy_intent_move = original_mode
	intent.enemy_intent_teleport_rule = original_rule
	intent.enemy_intent_marked_cell = original_cell
	c.director.refresh_threats()
	await c.snap_presentation()

## Destructive run-end assertions are deliberately called after all other dual-board groups.
func run_exit(c) -> void:
	var hero: Player = c.player as Player
	await c.snap_presentation()
	var presentation: BoardActorPresentation = c.combat.actor_presentation
	var state: Dictionary = presentation._actors[hero.unit_uid]
	var original_position: Vector2 = state["position"]
	var original_scale: Vector2 = state["scale"]
	var board_scale: Vector2 = hero.scale
	var uid: String = hero.unit_uid
	var destination: Vector2i = Vector2i(0, 4)
	var view: BoardView = c.combat.board_views["enemy"]
	var foot: Vector2 = view.global_position + Vector2(destination.x + 0.5, destination.y + 1) * view.cell_size - Vector2(0, 4)
	var expected: Vector2 = foot - (state["foot"] as Vector2) * hero.scale
	var killed: Dictionary = {"seen": false, "position": Vector2.ZERO}
	var on_killed: Callable = func(unit):
		if unit == hero:
			killed.seen = true
			killed.position = hero.global_position
	Signals.player_killed.connect(on_killed)
	var lethal := FieldData.new("dual_presentation_lethal")
	lethal.field_on_enter_actions.assign([{Scripts.ACTION_DIRECT_DAMAGE: {"damage": 99999, "bypass_block": true}}])
	Global.register_rod(lethal)
	await c.create_field(lethal.object_id, [destination], hero, {"board_id": "enemy"})
	await c.transfer(hero, "enemy", destination)
	c._check(killed.seen and (killed.position as Vector2).is_equal_approx(expected), "lethal destination field displays the committed destination before the death callback")
	Signals.player_killed.disconnect(on_killed)
	var summary: Node = c.game_root.get_node("RunScreen/RunSummaryOverlay")
	await c._wait(func(): return summary.visible and not hero.animation_player.is_playing(), "actual hero death animation reaches defeat summary")
	c._check(hero.global_position.is_equal_approx(expected), "death animation preserves the last committed board root position")
	summary.end_run_button.button_up.emit()
	await c._wait(func(): return not Global.is_run and c._idle(), "End Run handler finishes the defeated run")
	c._check(hero.position.is_equal_approx(original_position) and hero.scale.is_equal_approx(original_scale), "run exit restores the persistent hero's pre-combat position and scale")
	await c.flow.process_frame
	await c.flow.process_frame
	c._check(not is_instance_valid(presentation) and c.combat.actor_presentation == null and c.combat.board_views.is_empty(), "run exit releases presentation actor references and cancels movement tweens")
	await _start_second_run(c)
	c._check(c.player == hero and hero.unit_uid == uid and hero.scale.is_equal_approx(board_scale), "same Root starts a new run with the same hero identity and no cumulative board scaling")
	_assert_unit(c, hero, "second-run hero")

func _start_second_run(c) -> void:
	c.game_root.get_node("TitleScreen/MainMenu/VBoxContainer/NewRunButton").button_up.emit()
	var menu: Node = c.game_root.get_node("TitleScreen/NewRunMenu")
	menu._on_character_selected("character_red")
	menu.seed_input.text = "20261019"
	menu.start_run_button.pressed.emit()
	await c._wait(func(): return Global.is_run, "second run starts through existing menu handlers")
	var options: Node = c.game_root.get_node("RunScreen/RunStartOptions")
	var option: Node = options.starting_option_container.get_child(0)
	option.dialogue_option_clicked.emit(option)
	await c._wait(func(): return c.map.is_visible_in_tree() and c.map.can_travel, "second-run start option opens map")
	var destination: LocationData = null
	for location: LocationData in Global.get_next_locations():
		if location.location_type == LocationData.LOCATION_TYPES.COMBAT:
			destination = location
			break
	if not c._check(destination != null, "second run has an adjacent combat destination"):
		return
	destination.location_event_object_id = "board_flow_event"
	for button: Node in c.map.location_container.get_children():
		if button.location_data == destination:
			button.button_up.emit()
			break
	await c._wait(c._player_ready, "second-run hero becomes ready on rebuilt battlefield")
	c.battlefield = c.director.battlefield
	c.party_board = c.battlefield.get_board("party")
	c.enemy_board = c.battlefield.get_board("enemy")
	c.board = c.party_board
	c.enemy = c.enemy_board.get_unit_at(Vector2i(3, 4))
	await c._wait(func(): return not c.player.animation_player.is_playing(), "second-run start animation completes before standing-foot assertions")
	c.combat.sync_board_views()
	await c.snap_presentation()
	c._check(c.director.battlefield.boards.size() == 2 and hero_on_party(c), "second run rebuilds independent boards after prior death teardown")

func hero_on_party(c) -> bool:
	return c.player.board_id == "party" and c.director.battlefield.get_board_for_unit(c.player) == c.director.battlefield.get_board("party")

func _assert_unit(c, unit: BaseCombatant, label: String) -> void:
	var view: BoardView = c.combat.board_views[unit.board_id]
	var sprite: AnimatedSprite2D = unit.animated_sprite_2d
	print("PRESENTATION ORIGIN ", label, " scene_file=", unit.scene_file_path, " sprite_path=", unit.get_path_to(sprite), " captured_before_animation=", unit.presentation_sprite_origin_captured, " ready_origin=", unit.presentation_sprite_origin, " ready_offset=", unit.presentation_sprite_offset, " live_offset=", sprite.offset, " cached_foot=", c.combat.actor_presentation._actors[unit.unit_uid]["foot"])
	print("PRESENTATION GEOMETRY ", label, " viewport=", unit.get_viewport_rect(), " sprite=", sprite.global_position, " root=", unit.global_position, " visible_transform=", unit.get_node("Visible").get_transform(), " sprite_transform=", sprite.transform, " scale=", unit.scale, " unclipped=", _not_clipped(sprite), " foot=", view.unit_footpoint(unit))
	c._check(unit.presentation_sprite_origin_captured and unit.presentation_sprite_origin == c.combat.actor_presentation._authored_sprite_origin(unit), label + " canonical origin comes from pre-animation ready capture")
	c._check(sprite.is_visible_in_tree() and unit.layered_health_bar.is_visible_in_tree(), label + " actual sprite and HP nodes are visible in the scene tree")
	c._check(unit.global_position.is_equal_approx(c.combat.actor_presentation.target_position_for(unit)), label + " root maps to its board/footprint destination")
	c._check(view.get_global_rect().has_point(sprite.global_position), label + " actual sprite origin lies on the owning board surface")
	c._check(unit.get_viewport_rect().has_point(sprite.global_position) and _not_clipped(sprite), label + " actual sprite origin is inside viewport and unclipped ancestors")
	var frames: SpriteFrames = sprite.sprite_frames
	var animation: StringName = &"idle" if frames.has_animation(&"idle") else sprite.animation
	var texture: Texture2D = frames.get_frame_texture(animation, 0)
	var feet: Vector2 = sprite.global_position + (sprite.offset + Vector2(0, texture.get_height() * (0.5 if sprite.centered else 1.0))) * sprite.global_scale
	c._check(feet.is_equal_approx(view.unit_footpoint(unit)), label + " actual sprite feet align with the footprint bottom center")
	c._check(unit.z_index >= 1 and unit.z_index < 10, label + " actor depth remains above grids and below existing modal overlays")

func _not_clipped(sprite: AnimatedSprite2D) -> bool:
	var node: Node = sprite.get_parent()
	while node != null:
		if node is Control and node.clip_contents and not node.get_global_rect().has_point(sprite.global_position):
			return false
		node = node.get_parent()
	return true

## Read-only inspection of the actual compressed animation libraries. Track keys are evidence,
## not guessed from animation names; running this does not play or rewrite any animation.
func _audit_animation_tracks(c) -> void:
	var root_transform_safe: bool = true
	for resource_path: String in ["res://animations/Player.res", "res://animations/Enemy.res", "res://animations/Combatant.res"]:
		var library: AnimationLibrary = load(resource_path) as AnimationLibrary
		for animation_name: StringName in library.get_animation_list():
			var animation: Animation = library.get_animation(animation_name)
			for index: int in animation.get_track_count():
				var path: String = str(animation.track_get_path(index))
				if not (path.contains("position") or path.contains("offset") or path.contains("scale") or path.contains("rotation")):
					continue
				var keys: Array = []
				for key: int in animation.track_get_key_count(index):
					keys.append([animation.track_get_key_time(index, key), animation.track_get_key_value(index, key)])
				print("PRESENTATION ANIMATION_TRACK ", resource_path, " ", animation_name, " path=", path, " keys=", keys)
				if path.get_slice(":", 0) in ["", "."]:
					root_transform_safe = false
	c._check(root_transform_safe, "actual animation libraries animate child transforms rather than the board-owned root transform")
