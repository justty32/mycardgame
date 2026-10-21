extends Control

@onready var scroll_container = $ScrollContainer
@onready var location_container = $ScrollContainer/LocationContainer
@onready var back_button: Button = $BackButton

@onready var map_button = %MapButton

var can_travel: bool = false	# if clicking on a location brings you to the next location
var _pending_scroll: Callable

## Adds a margin to the bottom of the map display
const MAP_Y_MARGIN: float = 150

func _ready():
	map_button.button_up.connect(_on_map_button_up)
	back_button.button_up.connect(_on_back_button_up)
	
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	
	Signals.player_killed.connect(_on_player_killed)
	Signals.dialogue_ended.connect(_on_dialogue_ended)
	
	Signals.chest_opened.connect(_on_chest_opened)
	Signals.shop_opened.connect(_on_shop_opened)
	
	Signals.map_location_selected.connect(_on_map_location_selected)
	
func populate_locations(locations: Array[LocationData] = Global.get_all_act_locations()):
	clear_locations()
	
	var next_locations: Array[LocationData] = Global.get_next_locations()
	var max_y: float = 0.0 # the highest location position, used to determine container size
	
	var current_map_location: MapLocation = null
	
	for location_data in locations:
		if location_data.location_type == LocationData.LOCATION_TYPES.STARTING:
			continue	# starting area not displayed
		
		var map_location: MapLocation = Scenes.MAP_LOCATION.instantiate()
		location_container.add_child(map_location)
		map_location.init(location_data)
		
		map_location.map_location_button_up.connect(_on_map_location_button_up)
		
		max_y = max(max_y, location_data.location_position.y)
		
		# flash the locations the player can travel to
		if can_travel:
			if next_locations.has(location_data):
				map_location.flash_location()
				current_map_location = map_location
		
		#if location_data == Global.get_player_location_data():
			#current_map_location = map_location
	
	# set the size of the container to make scrolling posible
	location_container.custom_minimum_size.y = max_y + MAP_Y_MARGIN
	location_container.size.y = max_y + MAP_Y_MARGIN
	
	# Wait for layout without suspending this function with the whole location
	# array on its stack. The map owns and cancels this one-shot callback.
	var location_ref: WeakRef = weakref(current_map_location) if current_map_location != null else null
	_pending_scroll = _restore_scroll.bind(location_ref, max_y)
	get_tree().process_frame.connect(_pending_scroll, CONNECT_ONE_SHOT)

func _restore_scroll(location_ref: WeakRef, max_y: float) -> void:
	_pending_scroll = Callable()
	var current_map_location: MapLocation = location_ref.get_ref() if location_ref != null else null
	if is_instance_valid(current_map_location) and current_map_location.is_inside_tree():
		current_map_location.grab_focus()
	else:
		# presumably the invisible starting location, set to bottom
		scroll_container.scroll_vertical = max_y
	

func clear_locations() -> void:
	_cancel_pending_scroll()
	for child in location_container.get_children():
		child.queue_free()

func _cancel_pending_scroll() -> void:
	if _pending_scroll.is_valid() and get_tree().process_frame.is_connected(_pending_scroll):
		get_tree().process_frame.disconnect(_pending_scroll)
	_pending_scroll = Callable()

func _exit_tree() -> void:
	_cancel_pending_scroll()

func show_map():
	populate_locations()
	visible = true

func hide_map():
	visible = false

func _on_map_button_up():
	show_map()

func _on_map_location_button_up(map_location: MapLocation):
	# map must be in travel mode
	if can_travel:
		# must be adjacent to player location
		var current: LocationData = Global.get_player_location_data()
		var unfinished_combat: bool = current != null and not current.location_visited and current.location_type in [LocationData.LOCATION_TYPES.COMBAT, LocationData.LOCATION_TYPES.MINIBOSS, LocationData.LOCATION_TYPES.BOSS]
		var retry_current: bool = unfinished_combat and map_location.location_data == current
		if retry_current or (not unfinished_combat and Global.get_next_locations().has(map_location.location_data)):
			# visit the location
			ActionGenerator.generate_visition_location(map_location.location_data.location_id)
	
func _on_map_location_selected(location_data: LocationData):
	# disable travel mode
	can_travel = false
	hide_map()

func _on_combat_started(_event_id: String):
	can_travel = false

func _on_combat_ended():
	can_travel = true

func _on_player_killed(_player: Player) -> void:
	hide_map()
	clear_locations()

func _on_chest_opened():
	can_travel = true

func _on_shop_opened():
	can_travel = true

func _on_dialogue_ended():
	var player: Player = Global.get_player()
	if player.is_alive():
		can_travel = true
		show_map()
	else:
		hide_map()

func _on_back_button_up():
	hide_map()
	get_combined_minimum_size()
