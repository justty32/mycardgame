## Owns only presentation transforms. The unit, HUD, animation paths and registry identity stay
## together under their original parent; interpolated positions never become gameplay coordinates.
extends Node
class_name BoardActorPresentation

const MOVE_SECONDS: float = 0.16
## Actor scale follows the board's cell size (cell / 128, capped at 0.65).
static func actor_scale_for(cell_size: float) -> float:
	return minf(0.65, cell_size / 128.0)

var views: Dictionary[String, BoardView] = {}
var _actors: Dictionary = {}
var _tweens: Dictionary = {}
var _retired: Dictionary = {}
## Last synced layout signature; per-frame work is a cheap comparison, the full sync (tooltips,
## markers, tweens) runs only when units, anchors, views or presentation signals changed.
var _sync_signature: String = ""
var _sync_dirty: bool = true
## Number of full sync passes (headless contract checks).
var sync_count: int = 0

func _ready() -> void:
	for changed: Signal in [Signals.field_created, Signals.field_removed, Signals.field_changed, Signals.board_changed, Signals.unit_spawned, Signals.unit_removed]:
		changed.connect(_mark_dirty.unbind(1))
	Signals.enemy_intent_changed.connect(_mark_dirty)
	Signals.timeline_changed.connect(_mark_dirty)
	Signals.unit_board_moved.connect(_on_position_committed)
	Signals.enemy_killed.connect(_on_actor_killed)
	Signals.player_killed.connect(_on_actor_killed)
	Signals.run_ended.connect(_on_display_ended)
	Signals.combat_ended.connect(_on_display_ended)

func _on_position_committed(_unit: BaseCombatant, _from_id: StringName, _from: Vector2i, _to_id: StringName, _to: Vector2i) -> void:
	# Geometry is committed before leave/enter effects. Capture its visual destination now,
	# including both sides of a swap, before a synchronous lethal reaction can remove a unit.
	get_parent().sync_board_views()
	sync_positions(true)

func _on_actor_killed(unit: BaseCombatant) -> void:
	if is_instance_valid(unit) and _actors.has(unit.unit_uid):
		_stop_tween(unit.unit_uid)
		unit.global_position = _actors[unit.unit_uid]["target"]

## Presentation stop on hero death: dead actors keep their committed board target.
func snap_dead_actors() -> void:
	for state: Dictionary in _actors.values():
		var unit: Variant = state["unit"]
		if is_instance_valid(unit) and not unit.is_alive():
			_on_actor_killed(unit)

func _process(_delta: float) -> void:
	var signature: String = _layout_signature()
	if _sync_dirty or signature != _sync_signature:
		sync_positions(true)

func _mark_dirty() -> void:
	_sync_dirty = true

func _layout_signature() -> String:
	var director: CombatDirector = Global.get_combat_director()
	if director == null or not director.is_running or director.battlefield == null:
		return "" if _actors.is_empty() else "stopped"
	var parts: PackedStringArray = []
	for id: String in views:
		var view: BoardView = views[id]
		if is_instance_valid(view):
			parts.append("%s:%s:%s:%s" % [id, view.global_position, view.cell_size, view.visible])
	for unit: BaseCombatant in director.battlefield.get_units():
		if is_instance_valid(unit):
			parts.append("%s:%s:%s:%s:%s" % [unit.unit_uid, unit.board_id, unit.board_anchor, unit.footprint, unit.is_inside_tree()])
	return "|".join(parts)

func target_position_for(unit: BaseCombatant) -> Vector2:
	var view: BoardView = views.get(unit.board_id)
	if view == null:
		return unit.global_position
	var state: Dictionary = _actors.get(unit.unit_uid, {})
	var foot: Vector2 = state["foot"] if state.has("foot") else _standing_foot(unit)
	return view.unit_footpoint(unit) - foot * unit.scale

func _standing_foot(unit: BaseCombatant) -> Vector2:
	var sprite: AnimatedSprite2D = unit.animated_sprite_2d
	var rest_offset: Vector2 = unit.presentation_sprite_offset if unit.presentation_sprite_origin_captured else sprite.offset
	var foot: Vector2 = _authored_sprite_origin(unit) + rest_offset
	var frames: SpriteFrames = sprite.sprite_frames
	if frames != null:
		var animation: StringName = &"idle" if frames.has_animation(&"idle") else sprite.animation
		if frames.has_animation(animation) and frames.get_frame_count(animation) > 0:
			var texture: Texture2D = frames.get_frame_texture(animation, 0)
			if texture != null:
				foot.y += texture.get_height() * (0.5 if sprite.centered else 1.0)
	return foot

## Run-start and attack animations can already be offset when combat begins. Use the scene's
## authored standing origin instead of freezing an in-flight animation position into the mapping.
func _authored_sprite_origin(unit: BaseCombatant) -> Vector2:
	if unit.presentation_sprite_origin_captured:
		return unit.presentation_sprite_origin
	if unit.scene_file_path != "":
		var scene: PackedScene = load(unit.scene_file_path) as PackedScene
		if scene != null:
			var scene_state: SceneState = scene.get_state()
			var path: NodePath = unit.get_path_to(unit.animated_sprite_2d)
			for index: int in scene_state.get_node_count():
				if str(scene_state.get_node_path(index)).trim_prefix("./") != str(path).trim_prefix("./"):
					continue
				for property: int in scene_state.get_node_property_count(index):
					if scene_state.get_node_property_name(index, property) == &"position":
						return scene_state.get_node_property_value(index, property)
	return unit.animated_sprite_2d.position

func sync_positions(animate: bool = false) -> void:
	sync_count += 1
	_sync_dirty = false
	_sync_signature = _layout_signature()
	var director: CombatDirector = Global.get_combat_director()
	if director == null or not director.is_running or director.battlefield == null:
		clear()
		return
	var present: Dictionary = {}
	for unit: BaseCombatant in director.battlefield.get_units():
		if not is_instance_valid(unit) or not unit.is_inside_tree():
			continue
		var view: BoardView = views.get(unit.board_id)
		if view == null:
			continue
		present[unit.unit_uid] = true
		var first: bool = not _actors.has(unit.unit_uid)
		if first:
			_capture(unit)
		unit.scale = Vector2.ONE * actor_scale_for(view.cell_size)
		var target: Vector2 = target_position_for(unit)
		# Each actor owns its complete sprite/HUD/hitbox subtree. Feet provide stable depth order.
		unit.z_index = 1 + clampi(int(7.0 * (unit.board_anchor.y + unit.footprint.y) / view.get_board().size.y), 0, 7)
		var state: Dictionary = _actors[unit.unit_uid]
		unit.selection_button.tooltip_text = view.field_tooltip(unit.board_anchor)
		var marker: Label = state.get("mode_marker")
		if marker != null:
			marker.text = movement_mode_label(unit as Enemy)
			marker.visible = marker.text != ""
		if first or not animate or not (state["target"] as Vector2).is_equal_approx(target):
			_stop_tween(unit.unit_uid)
			state["target"] = target
			if animate and not first:
				var tween: Tween = create_tween()
				_tweens[unit.unit_uid] = tween
				tween.tween_property(unit, "global_position", target, MOVE_SECONDS)
			else:
				unit.global_position = target
	for uid: String in _actors.keys():
		if not present.has(uid):
			_release(uid)

func _capture(unit: BaseCombatant) -> void:
	var button: Button = unit.selection_button
	var original: Callable = Callable(unit, "_on_selection_button_up")
	var had_original: bool = button.button_up.is_connected(original)
	if had_original:
		button.button_up.disconnect(original)
	var click: Callable = _on_actor_clicked.bind(unit)
	var hover: Callable = _on_actor_hovered.bind(unit)
	button.button_up.connect(click)
	button.mouse_entered.connect(hover)
	_actors[unit.unit_uid] = {
		"unit": unit, "position": unit.position, "scale": unit.scale, "z": unit.z_index,
		"filter": unit.mouse_filter, "click": click, "hover": hover,
		"original": original, "had_original": had_original, "target": unit.global_position,
		"foot": _standing_foot(unit), "tooltip": button.tooltip_text,
	}
	unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unit is Enemy:
		var marker := Label.new()
		marker.name = "MovementMode"
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(unit as Enemy).enemy_intent.add_child(marker)
		_actors[unit.unit_uid]["mode_marker"] = marker

func _on_actor_clicked(unit: BaseCombatant) -> void:
	# One accepted click emits one board event, never both board and legacy enemy click events.
	if is_instance_valid(unit) and unit.is_alive():
		Signals.board_cell_clicked.emit(unit.board_id, unit.board_anchor)

func _on_actor_hovered(unit: BaseCombatant) -> void:
	if is_instance_valid(unit) and unit.is_alive():
		Signals.board_cell_hovered.emit(unit.board_id, unit.board_anchor)

func _stop_tween(uid: String) -> void:
	var tween: Tween = _tweens.get(uid)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(uid)

func _release(uid: String) -> void:
	_stop_tween(uid)
	var state: Dictionary = _actors[uid]
	var unit: Variant = state["unit"]
	var marker: Variant = state.get("mode_marker")
	if is_instance_valid(marker):
		marker.queue_free()
	if is_instance_valid(unit):
		var button: Button = unit.selection_button
		if is_instance_valid(button):
			button.tooltip_text = state["tooltip"]
			if button.button_up.is_connected(state["click"]):
				button.button_up.disconnect(state["click"])
			if button.mouse_entered.is_connected(state["hover"]):
				button.mouse_entered.disconnect(state["hover"])
			if state["had_original"] and not button.button_up.is_connected(state["original"]):
				button.button_up.connect(state["original"])
		# A dying actor keeps its last board position until its existing death animation frees it.
		if unit.is_alive():
			unit.position = state["position"]
			unit.scale = state["scale"]
			unit.z_index = state["z"]
		else:
			_retired[uid] = state
		unit.mouse_filter = state["filter"]
	_actors.erase(uid)

func clear() -> void:
	for uid: String in _actors.keys():
		_release(uid)

func _on_display_ended() -> void:
	clear()
	# The hero node survives run changes. Keep its death pose through the animation, then
	# restore the pre-combat transform before the same node can represent a new run.
	for state: Dictionary in _retired.values():
		var unit: Variant = state["unit"]
		if is_instance_valid(unit):
			unit.position = state["position"]
			unit.scale = state["scale"]
			unit.z_index = state["z"]
	_retired.clear()

func _exit_tree() -> void:
	if Signals.unit_board_moved.is_connected(_on_position_committed):
		Signals.unit_board_moved.disconnect(_on_position_committed)
	if Signals.enemy_killed.is_connected(_on_actor_killed):
		Signals.enemy_killed.disconnect(_on_actor_killed)
	if Signals.player_killed.is_connected(_on_actor_killed):
		Signals.player_killed.disconnect(_on_actor_killed)
	if Signals.run_ended.is_connected(_on_display_ended):
		Signals.run_ended.disconnect(_on_display_ended)
	if Signals.combat_ended.is_connected(_on_display_ended):
		Signals.combat_ended.disconnect(_on_display_ended)
	_on_display_ended()
	views.clear()

## Text fallbacks keep movement intentions legible without requiring content-specific art.
static func movement_mode_label(enemy: Enemy) -> String:
	if enemy == null or enemy.enemy_data == null:
		return ""
	var intent: EnemyIntentData = enemy.enemy_data.get_current_intent()
	if intent == null:
		return ""
	var labels: Array[String] = ["", "->", "<-", "<->", "FLANK", "CHARGE", "TP"]
	return labels[intent.enemy_intent_move] if intent.enemy_intent_move >= 0 and intent.enemy_intent_move < labels.size() else "?"
