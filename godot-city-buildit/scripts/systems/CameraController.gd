extends Node3D

@export var zoom_speed: float = 0.15
@export var min_zoom: float = 12.0
@export var max_zoom: float = 55.0
@export var world_limit: float = 90.0
@export var camera_pitch_degrees: float = 48.0
@export var pan_inertia_damping: float = 8.0
@export var orbit_inertia_damping: float = 10.0
@export var focus_smoothing: float = 8.0

@onready var camera: Camera3D = $Camera3D

var current_zoom: float = 30.0
var is_mouse_panning: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO
var touch_points: Dictionary = {}
var last_pinch_distance: float = 0.0
var last_pinch_angle: float = 0.0
var pan_velocity: Vector2 = Vector2.ZERO
var orbit_velocity: float = 0.0
var focus_target: Vector3 = Vector3.ZERO
var is_focus_animating := false

const PAN_INERTIA_STOP_SPEED := 6.0
const ORBIT_INERTIA_STOP_SPEED := 0.01

func _ready() -> void:
	rotation_degrees = Vector3(0.0, 45.0, 0.0)
	# Frame the starter highway and first adjacent build plots on entry.
	global_position = Vector3(-9.0, 0.0, 2.5)
	_update_camera_transform()
	focus_target = global_position

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _is_road_mode() or BuildManager.is_moving:
		pan_velocity = Vector2.ZERO
		orbit_velocity = 0.0
		is_focus_animating = false
		return
	if is_focus_animating:
		global_position = interpolate_focus(global_position, focus_target, delta, focus_smoothing)
		if global_position.distance_to(focus_target) <= 0.05:
			global_position = focus_target
			is_focus_animating = false
		return
	if not touch_points.is_empty() or is_mouse_panning:
		return
	if pan_velocity.length() > PAN_INERTIA_STOP_SPEED:
		_pan(pan_velocity * delta)
		pan_velocity = decay_pan_velocity(pan_velocity, delta, pan_inertia_damping)
	else:
		pan_velocity = Vector2.ZERO
	if absf(orbit_velocity) > ORBIT_INERTIA_STOP_SPEED:
		rotation_degrees.y += rad_to_deg(orbit_velocity * delta)
		orbit_velocity = decay_orbit_velocity(orbit_velocity, delta, orbit_inertia_damping)
	else:
		orbit_velocity = 0.0

func focus_on(target_position: Vector3) -> void:
	focus_target = Vector3(target_position.x, global_position.y, target_position.z)
	pan_velocity = Vector2.ZERO
	orbit_velocity = 0.0
	is_focus_animating = global_position.distance_to(focus_target) > 0.05

static func interpolate_focus(current: Vector3, target: Vector3, delta: float, smoothing: float) -> Vector3:
	var weight := 1.0 - exp(-maxf(0.0, smoothing) * maxf(0.0, delta))
	return current.lerp(target, weight)

static func decay_pan_velocity(velocity: Vector2, delta: float, damping: float) -> Vector2:
	return velocity * exp(-maxf(0.0, damping) * maxf(0.0, delta))

static func decay_orbit_velocity(velocity: float, delta: float, damping: float) -> float:
	return velocity * exp(-maxf(0.0, damping) * maxf(0.0, delta))

func _is_road_mode() -> bool:
	var scene = get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	return road_system != null and road_system.is_road_mode

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_mouse_panning = event.pressed and not _is_road_mode() and not _is_building_press_pending(-1)
			if event.pressed:
				pan_velocity = Vector2.ZERO
				orbit_velocity = 0.0
				is_focus_animating = false
			last_mouse_position = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(-2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(2.0)
	elif event is InputEventMouseMotion and is_mouse_panning:
		if not _is_building_press_pending(-1):
			_pan(event.position - last_mouse_position)
			pan_velocity = event.velocity
		last_mouse_position = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			pan_velocity = Vector2.ZERO
			orbit_velocity = 0.0
			is_focus_animating = false
			touch_points[event.index] = event.position
			if touch_points.size() >= 2:
				_update_pinch_baseline()
		else:
			touch_points.erase(event.index)
			last_pinch_distance = 0.0
			last_pinch_angle = 0.0
	elif event is InputEventScreenDrag:
		if not touch_points.has(event.index):
			return
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			# CityInput owns the active pointer while a building is being relocated.
			# Do not move the camera underneath the drag preview.
			if not _is_road_mode() and not BuildManager.is_moving and not _is_building_press_pending(event.index):
				_pan(event.relative)
				orbit_velocity = 0.0
				var frame_delta := maxf(get_process_delta_time(), 1.0 / 120.0)
				pan_velocity = event.screen_velocity if event.screen_velocity.length_squared() > 0.0 else event.relative / frame_delta
		elif touch_points.size() >= 2:
			_update_pinch(event.relative)

func _is_building_press_pending(pointer_id: int) -> bool:
	var scene = get_tree().current_scene
	var city_input = scene.get_node_or_null("CityInput") if scene else null
	return city_input != null and city_input.has_method("is_building_press_pending") and city_input.is_building_press_pending(pointer_id)

func _update_pinch_baseline() -> void:
	var points: Array = touch_points.values()
	var vector: Vector2 = points[1] - points[0]
	last_pinch_distance = vector.length()
	last_pinch_angle = vector.angle()

func _update_pinch(_relative: Vector2) -> void:
	var points: Array = touch_points.values()
	if points.size() < 2:
		return
	var vector: Vector2 = points[1] - points[0]
	var distance: float = vector.length()
	var angle: float = vector.angle()
	if last_pinch_distance > 0.0:
		_zoom((last_pinch_distance - distance) * zoom_speed * 0.06)
		var angle_delta: float = wrapf(angle - last_pinch_angle, -PI, PI)
		rotation_degrees.y += rad_to_deg(angle_delta)
		var frame_delta := maxf(get_process_delta_time(), 1.0 / 120.0)
		orbit_velocity = angle_delta / frame_delta
	last_pinch_distance = distance
	last_pinch_angle = angle

func _pan(screen_delta: Vector2) -> void:
	is_focus_animating = false
	var right: Vector3 = global_transform.basis.x
	var forward: Vector3 = global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	global_position += (-right * screen_delta.x - forward * screen_delta.y) * (current_zoom * 0.00125)
	global_position.x = clampf(global_position.x, -world_limit, world_limit)
	global_position.z = clampf(global_position.z, -world_limit, world_limit)

func _zoom(amount: float) -> void:
	current_zoom = clampf(current_zoom + amount, min_zoom, max_zoom)
	_update_camera_transform()

func _update_camera_transform() -> void:
	if camera == null:
		return
	var pitch: float = deg_to_rad(camera_pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * current_zoom, cos(pitch) * current_zoom)
	camera.look_at(global_position, Vector3.UP)
