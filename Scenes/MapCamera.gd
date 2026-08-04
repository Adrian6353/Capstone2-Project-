extends Camera2D

class_name MapCamera

## Camera movement settings
@export var drag_speed: float = 1.0
@export var click_movement_speed: float = 500.0
@export var zoom_speed: float = 0.3
@export var zoom_smoothing: float = 12.0
@export var min_zoom: float = 1.1
@export var max_zoom: float = 3.0
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 0.2
@export var drag_friction: float = 0.88
@export var drag_smoothing: float = 18.0

## Private variables
var is_dragging: bool = false
var drag_start_position: Vector2
var camera_start_position: Vector2
var last_mouse_screen_pos: Vector2
var target_position: Vector2
var is_moving_to_target: bool = false
var map_bounds: Rect2i
var last_zoom: Vector2 = Vector2.ONE
var target_zoom: float = 1.0
var drag_velocity: Vector2 = Vector2.ZERO
var velocity_history: Array[Vector2] = []
const VELOCITY_HISTORY_SIZE: int = 5

## Touch input tracking
var touch_points: Dictionary = {}
var last_pinch_distance: float = 0.0
var last_touch_midpoint: Vector2 = Vector2.ZERO
var _touch_panning: bool = false  # true while a finger is actively panning (suppresses mouse-motion double-pan)

func _ready():
	# Enable smoothing for better experience
	set_physics_process(true)
	target_position = global_position
	target_zoom = zoom.x
	
	# Set camera limits for 2-player gameplay on 3840x2160 map
	# (double the size of Map 1: 1920x1080)
	limit_left = 0
	limit_top = 0
	limit_right = 3840
	limit_bottom = 2160
	
	# Store map bounds for camera clamping
	map_bounds = Rect2i(0, 0, 3840, 2160)

func _input(event: InputEvent):
	# Handle mouse scroll for zoom (like Google Maps)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
			get_tree().root.set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()
			get_tree().root.set_input_as_handled()
			return
		
		# Middle mouse button drag (like Google Maps)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				start_drag()
			else:
				end_drag()
			get_tree().root.set_input_as_handled()
			return
	
	# Handle mouse motion for dragging (skip when touch is already handling the pan)
	elif event is InputEventMouseMotion and is_dragging and not _touch_panning:
		handle_drag_motion(event)
		get_tree().root.set_input_as_handled()
		return

	# --- Touch input: one-finger pan, two-finger pan + pinch-to-zoom ---
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() == 1:
				# First finger down: begin single-finger pan
				_touch_panning = true
				is_dragging = true
				drag_velocity = Vector2.ZERO
				velocity_history.clear()
				target_position = global_position
			elif touch_points.size() == 2:
				# Second finger added: switch to pinch-zoom mode
				var positions = touch_points.values()
				last_pinch_distance = positions[0].distance_to(positions[1])
				last_touch_midpoint = (positions[0] + positions[1]) / 2.0
				is_dragging = true
				drag_velocity = Vector2.ZERO
				velocity_history.clear()
				target_position = global_position
		else:
			touch_points.erase(event.index)
			if touch_points.size() == 0:
				# All fingers lifted
				_touch_panning = false
				if is_dragging:
					end_drag()
				last_pinch_distance = 0.0
			elif touch_points.size() == 1:
				# One finger left after pinch — back to single-finger mode
				_touch_panning = true
				last_pinch_distance = 0.0
		get_tree().root.set_input_as_handled()
		return

	elif event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			# Single-finger pan: use the drag delta directly
			var movement: Vector2 = -event.relative / zoom.x * drag_speed
			target_position += movement
			if movement.length() > 0.5:
				velocity_history.append(movement)
				if velocity_history.size() > VELOCITY_HISTORY_SIZE:
					velocity_history.pop_front()
			get_tree().root.set_input_as_handled()
		elif touch_points.size() == 2 and last_pinch_distance > 0.0:
			var positions = touch_points.values()
			var new_midpoint = (positions[0] + positions[1]) / 2.0
			var new_distance = positions[0].distance_to(positions[1])

			# Pan: translate midpoint delta into world-space movement
			var midpoint_delta = new_midpoint - last_touch_midpoint
			var movement = -midpoint_delta / zoom.x * drag_speed
			target_position += movement
			if movement.length() > 0.5:
				velocity_history.append(movement)
				if velocity_history.size() > VELOCITY_HISTORY_SIZE:
					velocity_history.pop_front()

			# Pinch: scale target_zoom by the ratio of finger distances
			var zoom_factor = new_distance / last_pinch_distance
			target_zoom = clamp(target_zoom * zoom_factor, min_zoom, max_zoom)

			last_touch_midpoint = new_midpoint
			last_pinch_distance = new_distance
			get_tree().root.set_input_as_handled()
		return

func _physics_process(delta: float):
	# Smoothly follow target_position while dragging
	if is_dragging:
		global_position = global_position.lerp(target_position, drag_smoothing * delta)

	# Apply drag momentum after releasing the mouse
	if not is_dragging and drag_velocity.length() > 0.5:
		global_position += drag_velocity
		target_position = global_position
		drag_velocity *= drag_friction
		clamp_camera_position()

	# Smooth camera movement toward target position
	if is_moving_to_target:
		if smoothing_enabled:
			global_position = global_position.lerp(target_position, smoothing_speed)
			# Stop moving if very close to target
			if global_position.distance_to(target_position) < 5:
				global_position = target_position
				is_moving_to_target = false
		else:
			global_position = target_position
			is_moving_to_target = false
	
	# Smoothly interpolate zoom toward target_zoom each frame
	var new_zoom = lerp(zoom.x, target_zoom, zoom_smoothing * delta)
	zoom = Vector2(new_zoom, new_zoom)

	# Only clamp if zoom has changed significantly and NOT dragging
	if not is_dragging and zoom.distance_to(last_zoom) > 0.01:
		clamp_camera_position()
		last_zoom = zoom

func start_drag():
	"""Start dragging the camera with middle mouse button"""
	is_dragging = true
	drag_velocity = Vector2.ZERO
	velocity_history.clear()
	last_mouse_screen_pos = get_viewport().get_mouse_position()
	drag_start_position = global_position
	camera_start_position = global_position
	target_position = global_position
	is_moving_to_target = false  # Disable smooth lerp for immediate response

func end_drag():
	"""End dragging the camera"""
	is_dragging = false
	# Compute release velocity as average of recent frames
	if velocity_history.size() > 0:
		var avg = Vector2.ZERO
		for v in velocity_history:
			avg += v
		drag_velocity = avg / velocity_history.size()
	velocity_history.clear()
	clamp_camera_position()  # Final clamp when drag ends

func handle_drag_motion(_event: InputEventMouseMotion):
	"""Accumulate drag into target_position using screen-space delta"""
	var current_screen_pos = get_viewport().get_mouse_position()
	var screen_delta = current_screen_pos - last_mouse_screen_pos
	# Convert screen pixels to world units
	var movement = -screen_delta / zoom.x * drag_speed

	target_position += movement
	# Only record frames with meaningful movement so micro-jitter while
	# holding still doesn't overwrite the real velocity
	if movement.length() > 0.5:
		velocity_history.append(movement)
		if velocity_history.size() > VELOCITY_HISTORY_SIZE:
			velocity_history.pop_front()
	last_mouse_screen_pos = current_screen_pos

func move_camera_to_click():
	"""Move camera to clicked location (left click)"""
	var mouse_pos = get_global_mouse_position()
	target_position = mouse_pos
	is_moving_to_target = true

func zoom_in():
	"""Zoom in when scrolling up"""
	target_zoom = clamp(target_zoom + zoom_speed, min_zoom, max_zoom)

func zoom_out():
	"""Zoom out when scrolling down"""
	target_zoom = clamp(target_zoom - zoom_speed, min_zoom, max_zoom)

func clamp_camera_position():
	"""Clamp camera position to map bounds"""
	var viewport_size = get_viewport_rect().size / zoom
	var half_width = viewport_size.x / 2
	var half_height = viewport_size.y / 2
	
	# Clamp with extra safety margin at edges
	var min_x = map_bounds.position.x + half_width
	var max_x = map_bounds.position.x + map_bounds.size.x - half_width
	var min_y = map_bounds.position.y + half_height
	var max_y = map_bounds.position.y + map_bounds.size.y - half_height
	
	global_position.x = clamp(global_position.x, min_x, max_x)
	global_position.y = clamp(global_position.y, min_y, max_y)
	
	# Only round when NOT dragging and NOT coasting to prevent jitter
	if not is_dragging and drag_velocity.length() < 0.5:
		global_position = global_position.round()

func update_map_bounds(new_bounds: Rect2i):
	"""Update the camera's map boundaries"""
	map_bounds = new_bounds
	limit_left = new_bounds.position.x
	limit_top = new_bounds.position.y
	limit_right = new_bounds.position.x + new_bounds.size.x
	limit_bottom = new_bounds.position.y + new_bounds.size.y

func set_camera_position(pos: Vector2):
	"""Instantly set camera position"""
	global_position = pos
	target_position = pos
	clamp_camera_position()

func set_camera_position_smooth(pos: Vector2):
	"""Smoothly move camera to position"""
	target_position = pos
	is_moving_to_target = true
