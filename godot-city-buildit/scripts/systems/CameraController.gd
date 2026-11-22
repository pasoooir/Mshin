extends Node3D
## Mobile-first city camera: one-finger pan, two-finger pan/pinch/twist,
## target-centred orbit and frame-rate-independent inertia.
##
## The rig origin is always the orbit target. Rotating this node therefore
## moves the camera around the target instead of spinning the view in place.

@export var zoom_speed: float = 0.045
@export var min_zoom: float = 12.0
@export var max_zoom: float = 112.0
@export var world_limit: float = 130.0
@export_range(20.0, 75.0, 1.0) var camera_pitch_degrees: float = 42.0
@export var pan_inertia_damping: float = 6.5
@export var orbit_inertia_damping: float = 10.0
@export var focus_smoothing: float = 8.0
@export_range(0.1, 1.0, 0.05) var pan_screen_sensitivity: float = 0.95

@onready var camera: Camera3D = $Camera3D

var current_zoom: float = 92.0
var is_mouse_panning: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO
var _last_single_touch_position: Vector2 = Vector2.ZERO
var touch_points: Dictionary = {}
var _multi_touch_gesture_active: bool = false
var last_pinch_distance: float = 0.0
var last_pinch_angle: float = 0.0
var last_pinch_centroid: Vector2 = Vector2.ZERO
var pan_velocity: Vector2 = Vector2.ZERO
var orbit_velocity: float = 0.0
var focus_target: Vector3 = Vector3.ZERO
var focus_zoom_target: float = -1.0
var is_focus_animating := false

const PAN_INERTIA_STOP_SPEED := 6.0
const ORBIT_INERTIA_STOP_SPEED := 0.01
const TWO_FINGER_PAN_DEADZONE := 0.8
const PINCH_DEADZONE := 0.35
const TWIST_DEADZONE := 0.002
const MAX_CAMERA_STEP := 1.0 / 20.0
const MAX_PAN_INERTIA_SPEED := 1600.0

func _ready() -> void:
	rotation_degrees = Vector3(0.0, 45.0, 0.0)
	# Frame the open starter city, wide Pacific beach and green inland edge together.
	global_position = Vector3(34.0, 0.0, 0.0)
	_update_camera_transform()
	focus_target = global_position
	# No idle per-frame camera work: wake only for touch, inertia or focus.
	set_process(false)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var step_delta := camera_step_delta(delta)
	if _is_road_mode() or BuildManager.is_moving:
		pan_velocity = Vector2.ZERO
		orbit_velocity = 0.0
		is_focus_animating = false
		_refresh_processing()
		return
	if is_focus_animating:
		global_position = interpolate_focus(global_position, focus_target, step_delta, focus_smoothing)
		if focus_zoom_target > 0.0:
			current_zoom = lerpf(current_zoom, focus_zoom_target, 1.0 - exp(-focus_smoothing * step_delta))
			_update_camera_transform()
		var position_done := global_position.distance_to(focus_target) <= 0.05
		var zoom_done := focus_zoom_target <= 0.0 or absf(current_zoom - focus_zoom_target) <= 0.05
		if position_done:
			global_position = focus_target
		if zoom_done:
			if focus_zoom_target > 0.0:
				current_zoom = focus_zoom_target
				_update_camera_transform()
			focus_zoom_target = -1.0
		if position_done and zoom_done:
			is_focus_animating = false
		_refresh_processing()
		return
	if not touch_points.is_empty() or is_mouse_panning:
		return
	if pan_velocity.length() > PAN_INERTIA_STOP_SPEED:
		_pan(pan_velocity * step_delta)
		pan_velocity = decay_pan_velocity(pan_velocity, step_delta, pan_inertia_damping)
	else:
		pan_velocity = Vector2.ZERO
	if absf(orbit_velocity) > ORBIT_INERTIA_STOP_SPEED:
		rotation_degrees.y = apply_orbit_delta(rotation_degrees.y, orbit_velocity * step_delta)
		orbit_velocity = decay_orbit_velocity(orbit_velocity, step_delta, orbit_inertia_damping)
	else:
		orbit_velocity = 0.0
	_refresh_processing()

func _refresh_processing() -> void:
	set_process(
		is_focus_animating
		or pan_velocity.length() > PAN_INERTIA_STOP_SPEED
		or absf(orbit_velocity) > ORBIT_INERTIA_STOP_SPEED
	)

func focus_on(target_position: Vector3, target_zoom: float = -1.0) -> void:
	# Keep the rig at ground height; its origin is the exact horizontal orbit target.
	focus_target = Vector3(target_position.x, global_position.y, target_position.z)
	focus_zoom_target = clampf(target_zoom, min_zoom, max_zoom) if target_zoom > 0.0 else -1.0
	pan_velocity = Vector2.ZERO
	orbit_velocity = 0.0
	var position_needs_focus := global_position.distance_to(focus_target) > 0.05
	var zoom_needs_focus := focus_zoom_target > 0.0 and absf(current_zoom - focus_zoom_target) > 0.05
	is_focus_animating = position_needs_focus or zoom_needs_focus
	_refresh_processing()

static func camera_step_delta(delta: float) -> float:
	# Preserve the full elapsed time at 20 FPS and above. The old 1/30 s cap
	# silently discarded camera travel on slower phones, making inertia lag.
	# A 50 ms ceiling still prevents a long app pause from causing a teleport.
	return minf(maxf(delta, 0.0), MAX_CAMERA_STEP)

static func clamp_pan_velocity(velocity: Vector2) -> Vector2:
	# Touch drivers can report very large screen_velocity spikes on Android.
	# Bound the inertial tail, not the live finger delta, to prevent jumps.
	if velocity.length_squared() <= MAX_PAN_INERTIA_SPEED * MAX_PAN_INERTIA_SPEED:
		return velocity
	return velocity.normalized() * MAX_PAN_INERTIA_SPEED

static func interpolate_focus(current: Vector3, target: Vector3, delta: float, smoothing: float) -> Vector3:
	var weight := 1.0 - exp(-maxf(0.0, smoothing) * maxf(0.0, delta))
	return current.lerp(target, weight)

static func decay_pan_velocity(velocity: Vector2, delta: float, damping: float) -> Vector2:
	return velocity * exp(-maxf(0.0, damping) * maxf(0.0, delta))

static func decay_orbit_velocity(velocity: float, delta: float, damping: float) -> float:
	return velocity * exp(-maxf(0.0, damping) * maxf(0.0, delta))

static func screen_pan_scale(zoom: float, fov_degrees: float, viewport_height: float, sensitivity: float = 0.82) -> float:
	if viewport_height <= 0.0:
		return 0.0
	return (2.0 * maxf(0.0, zoom) * tan(deg_to_rad(clampf(fov_degrees, 1.0, 179.0)) * 0.5) / viewport_height) * clampf(sensitivity, 0.1, 1.0)

static func pinch_zoom_delta(previous_distance: float, current_distance: float, sensitivity: float, camera_distance: float = 1.0) -> float:
	# Use a distance ratio rather than raw pixels: identical pinch scales must
	# produce identical zoom percentages on different phone resolutions.
	if previous_distance <= 0.001 or current_distance <= 0.001:
		return 0.0
	var exponent := clampf(maxf(0.0, sensitivity) * 10.0, 0.0, 2.0)
	var scale_factor := pow(previous_distance / current_distance, exponent)
	return maxf(0.0, camera_distance) * (scale_factor - 1.0)

static func touch_centroid(first: Vector2, second: Vector2) -> Vector2:
	return (first + second) * 0.5


static func touch_orbit_delta(previous_angle: float, current_angle: float) -> float:
	# Keep a twist crossing the -PI/PI seam as a small continuous movement.
	return wrapf(current_angle - previous_angle, -PI, PI)


static func apply_orbit_delta(current_y_degrees: float, angle_delta_radians: float) -> float:
	# Yaw is normalized but never clamped, so repeated twists can complete full turns.
	return wrapf(current_y_degrees + rad_to_deg(angle_delta_radians), -180.0, 180.0)

func _is_road_mode() -> bool:
	var scene = get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	return road_system != null and road_system.is_road_mode

func _unhandled_input(event: InputEvent) -> void:
	# Detail overlays own the complete pointer session; never move the city behind them.
	var scene := get_tree().current_scene
	var hud := scene.get_node_or_null("HUD") if is_instance_valid(scene) else null
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if is_instance_valid(hud) and hud.has_method("has_active_native_ui_touch") and hud.has_active_native_ui_touch():
			# A HUD-owned finger blocks every world-camera pointer until release.
			touch_points.clear()
			_multi_touch_gesture_active = false
			last_pinch_distance = 0.0
			last_pinch_angle = 0.0
			last_pinch_centroid = Vector2.ZERO
			_last_single_touch_position = Vector2.ZERO
			pan_velocity = Vector2.ZERO
			orbit_velocity = 0.0
			is_mouse_panning = false
			_refresh_processing()
			# Both world handlers must observe a blocked pointer to clear their own state.
			if should_consume_blocked_world_input(event):
				get_viewport().set_input_as_handled()
			return
	if is_instance_valid(hud):
		var production_modal = hud.get("production_overlay")
		var residential_modal = hud.get("residential_overlay")
		if (production_modal is Control and is_instance_valid(production_modal)) or (residential_modal is Control and is_instance_valid(residential_modal)):
			touch_points.clear()
			_multi_touch_gesture_active = false
			last_pinch_distance = 0.0
			last_pinch_angle = 0.0
			last_pinch_centroid = Vector2.ZERO
			_last_single_touch_position = Vector2.ZERO
			is_mouse_panning = false
			pan_velocity = Vector2.ZERO
			orbit_velocity = 0.0
			is_focus_animating = false
			_refresh_processing()
			if should_consume_blocked_world_input(event):
				get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_mouse_panning = event.pressed and not _is_road_mode() and not _is_camera_pan_blocked()
			if event.pressed:
				pan_velocity = Vector2.ZERO
				orbit_velocity = 0.0
				is_focus_animating = false
				last_mouse_position = event.position
			_refresh_processing()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(-2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(2.0)
	elif event is InputEventMouseMotion and is_mouse_panning:
		if _city_input_allows_camera_drag(-1, event.position):
			_pan_between_screen_points(last_mouse_position, event.position)
			pan_velocity = clamp_pan_velocity(event.velocity)
		last_mouse_position = event.position
		_refresh_processing()
	elif event is InputEventScreenTouch:
		if event.pressed:
			# Every pointer-count transition takes control immediately and starts
			# with fresh baselines; stale one-/two-finger velocities never leak.
			pan_velocity = Vector2.ZERO
			orbit_velocity = 0.0
			is_focus_animating = false
			if not touch_points.is_empty():
				_multi_touch_gesture_active = true
			touch_points[event.index] = event.position
			if touch_points.size() == 1:
				_last_single_touch_position = event.position
			else:
				_update_pinch_baseline()
			_refresh_processing()
		else:
			if is_cancelled_touch_release(event):
				_reset_touch_session()
				# Do not consume the event: CityInput must also clear its matching pointer.
				return
			touch_points.erase(event.index)
			if _multi_touch_gesture_active:
				pan_velocity = Vector2.ZERO
				orbit_velocity = 0.0
			_multi_touch_gesture_active = touch_points.size() >= 2
			if touch_points.size() == 1:
				var remaining_ids: Array = touch_points.keys()
				_last_single_touch_position = touch_points[remaining_ids[0]]
			last_pinch_distance = 0.0
			last_pinch_angle = 0.0
			last_pinch_centroid = Vector2.ZERO
		_refresh_processing()
	elif event is InputEventScreenDrag:
		if not touch_points.has(event.index):
			return
		var previous_single_position := _last_single_touch_position
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			# A deliberate drag takes ownership from CityInput's pending tap/hold.
			# This lets the map pan when the gesture starts on a building too.
			if not _is_road_mode() and not BuildManager.is_moving and _city_input_allows_camera_drag(event.index, event.position):
				_pan_between_screen_points(previous_single_position, event.position)
				orbit_velocity = 0.0
				var frame_delta := maxf(get_process_delta_time(), 1.0 / 120.0)
				pan_velocity = clamp_pan_velocity(event.screen_velocity if event.screen_velocity.length_squared() > 0.0 else event.relative / frame_delta)
			_last_single_touch_position = event.position
		elif touch_points.size() >= 2:
			_update_pinch()
		_refresh_processing()

static func should_consume_blocked_world_input(event: InputEvent) -> bool:
	return not (event is InputEventScreenTouch or event is InputEventScreenDrag)

static func is_cancelled_touch_release(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and not event.pressed and event.canceled

func _reset_touch_session() -> void:
	touch_points.clear()
	_multi_touch_gesture_active = false
	last_pinch_distance = 0.0
	last_pinch_angle = 0.0
	last_pinch_centroid = Vector2.ZERO
	_last_single_touch_position = Vector2.ZERO
	pan_velocity = Vector2.ZERO
	orbit_velocity = 0.0
	is_mouse_panning = false
	is_focus_animating = false
	focus_zoom_target = -1.0
	_refresh_processing()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset_touch_session()

func _is_camera_pan_blocked() -> bool:
	var scene := get_tree().current_scene
	var city_input = scene.get_node_or_null("CityInput") if is_instance_valid(scene) else null
	return city_input != null and city_input.has_method("is_camera_pan_blocked") and bool(city_input.is_camera_pan_blocked())

func _city_input_allows_camera_drag(pointer_id: int, screen_position: Vector2) -> bool:
	var scene := get_tree().current_scene
	var city_input = scene.get_node_or_null("CityInput") if is_instance_valid(scene) else null
	if city_input == null:
		return true
	if city_input.has_method("is_camera_pan_blocked") and bool(city_input.is_camera_pan_blocked()):
		return false
	if city_input.has_method("take_over_camera_drag"):
		return bool(city_input.take_over_camera_drag(pointer_id, screen_position))
	return not _is_building_press_pending(pointer_id)

func _is_building_press_pending(pointer_id: int) -> bool:
	var scene = get_tree().current_scene
	var city_input = scene.get_node_or_null("CityInput") if scene else null
	return city_input != null and city_input.has_method("is_building_press_pending") and city_input.is_building_press_pending(pointer_id)

func _ordered_touch_positions() -> Array:
	var ids: Array = touch_points.keys()
	ids.sort()
	var positions: Array = []
	for pointer_id in ids:
		positions.append(touch_points[pointer_id])
	return positions

func _update_pinch_baseline() -> void:
	var points := _ordered_touch_positions()
	if points.size() < 2:
		return
	var vector: Vector2 = points[1] - points[0]
	last_pinch_distance = vector.length()
	last_pinch_angle = vector.angle()
	last_pinch_centroid = touch_centroid(points[0], points[1])

func _update_pinch() -> void:
	var points := _ordered_touch_positions()
	if points.size() < 2:
		return
	var vector: Vector2 = points[1] - points[0]
	var distance: float = vector.length()
	var angle: float = vector.angle()
	var centroid := touch_centroid(points[0], points[1])
	if last_pinch_distance > 0.0:
		# Preserve the ground point under the previous midpoint, then re-anchor
		# it under the new midpoint after applying pan, pinch and twist together.
		var focal_world: Variant = _screen_to_ground(last_pinch_centroid)
		var centroid_delta := centroid - last_pinch_centroid
		if centroid_delta.length() >= TWO_FINGER_PAN_DEADZONE:
			pan_velocity = Vector2.ZERO
		var distance_delta := pinch_zoom_delta(last_pinch_distance, distance, zoom_speed, current_zoom)
		if absf(distance_delta) >= PINCH_DEADZONE:
			_zoom(distance_delta)
		var angle_delta: float = touch_orbit_delta(last_pinch_angle, angle)
		if absf(angle_delta) >= TWIST_DEADZONE:
			rotation_degrees.y = apply_orbit_delta(rotation_degrees.y, angle_delta)
			orbit_velocity = 0.0
		if focal_world != null:
			_keep_ground_point_under_screen(focal_world, centroid)
		last_pinch_distance = distance
		last_pinch_angle = angle
		last_pinch_centroid = centroid
	else:
		_update_pinch_baseline()

func _screen_to_ground(screen_position: Vector2) -> Variant:
	if not is_instance_valid(camera):
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) <= 0.000001:
		return null
	var distance_to_ground := -ray_origin.y / ray_direction.y
	if distance_to_ground < 0.0:
		return null
	return ray_origin + ray_direction * distance_to_ground

static func ground_anchor_correction(anchor: Vector3, projected: Vector3) -> Vector3:
	return Vector3(anchor.x - projected.x, 0.0, anchor.z - projected.z)

func _keep_ground_point_under_screen(ground_point: Vector3, screen_position: Vector2) -> void:
	var after_transform = _screen_to_ground(screen_position)
	if after_transform == null:
		return
	global_position += ground_anchor_correction(ground_point, after_transform)
	global_position.x = clampf(global_position.x, -world_limit, world_limit)
	global_position.z = clampf(global_position.z, -world_limit, world_limit)

func _pan_between_screen_points(previous_position: Vector2, current_position: Vector2) -> void:
	if previous_position.distance_squared_to(current_position) <= 0.0001:
		return
	var previous_ground = _screen_to_ground(previous_position)
	var current_ground = _screen_to_ground(current_position)
	if previous_ground == null or current_ground == null:
		return
	is_focus_animating = false
	global_position += previous_ground - current_ground
	global_position.y = 0.0
	global_position.x = clampf(global_position.x, -world_limit, world_limit)
	global_position.z = clampf(global_position.z, -world_limit, world_limit)

func _pan(screen_delta: Vector2) -> void:
	# Inertia is measured in screen pixels/second, but converted through the
	# same ground-ray mapping as direct dragging at the current camera pose.
	if screen_delta.length_squared() <= 0.0001:
		return
	var center := get_viewport().get_visible_rect().size * 0.5
	_pan_between_screen_points(center, center + screen_delta)

func _zoom(amount: float) -> void:
	current_zoom = clampf(current_zoom + amount, min_zoom, max_zoom)
	_update_camera_transform()

func _update_camera_transform() -> void:
	if camera == null:
		return
	var pitch: float = deg_to_rad(camera_pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * current_zoom, cos(pitch) * current_zoom)
	camera.look_at(global_position, Vector3.UP)
