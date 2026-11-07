extends Node3D

@export var move_speed := 15.0
@export var zoom_speed := 0.15
@export var min_zoom := 8.0
@export var max_zoom := 45.0
@export var rotation_x := -45.0
@export var rotation_y := 45.0
@export var world_limit := 55.0
@onready var camera: Camera3D = $Camera3D
var is_panning := false
var last_pan_position := Vector2.ZERO
var current_zoom := 25.0
var touch_points: Dictionary = {}
var last_pinch_distance := 0.0

func _ready() -> void:
	rotation_degrees = Vector3(rotation_x, rotation_y, 0.0)
	_update_camera_zoom()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_panning = event.pressed
			last_pan_position = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_speed * 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_speed * 3.0)
	elif event is InputEventMouseMotion and is_panning:
		_pan(event.position - last_pan_position)
		last_pan_position = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
			last_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			_pan(event.relative)
		elif touch_points.size() >= 2:
			var positions: Array = touch_points.values()
			var distance: float = positions[0].distance_to(positions[1])
			if last_pinch_distance > 0.0:
				_zoom((last_pinch_distance - distance) * zoom_speed * 0.05)
			last_pinch_distance = distance

func _pan(screen_delta: Vector2) -> void:
	var right := global_transform.basis.x
	var forward := global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	global_position += (-right * screen_delta.x - forward * screen_delta.y) * (current_zoom * 0.002)
	global_position.x = clampf(global_position.x, -world_limit, world_limit)
	global_position.z = clampf(global_position.z, -world_limit, world_limit)

func _zoom(amount: float) -> void:
	current_zoom = clampf(current_zoom + amount, min_zoom, max_zoom)
	_update_camera_zoom()

func _update_camera_zoom() -> void:
	if camera:
		camera.position.z = current_zoom
