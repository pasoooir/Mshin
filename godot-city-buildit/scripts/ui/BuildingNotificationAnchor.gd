extends Node3D
## True world-space, camera-facing notification stack attached to a building.
signal notification_pressed(notification: BuildingNotification)

const Icons = preload("res://scripts/ui/Icons.gd")
const MAX_VISIBLE := 2
const BOB_HEIGHT := 0.13
const BOB_SPEED := 1.8
const FULL_ICON_DISTANCE := 42.0
const DOT_DISTANCE := 72.0

var _notifications: Array[BuildingNotification] = []
var _icons: Array[Sprite3D] = []
var _counts: Array[Label3D] = []
var _hit_areas: Array[Area3D] = []
var _base_y := 0.0
var _signature := ""

func _ready() -> void:
	_base_y = position.y

func set_anchor_position(value: Vector3) -> void:
	position = value
	_base_y = value.y

func set_notifications(notifications: Array[BuildingNotification]) -> void:
	var ordered := notifications.duplicate()
	ordered.sort_custom(func(a: BuildingNotification, b: BuildingNotification) -> bool:
		return a.priority > b.priority
	)
	if ordered.size() > MAX_VISIBLE:
		ordered.resize(MAX_VISIBLE)
	var next_signature := ""
	for notification in ordered:
		next_signature += "%s:%s:%d:%d:%s|" % [notification.type, notification.item_id, notification.count, notification.priority, notification.detail]
	if next_signature == _signature:
		return
	_signature = next_signature
	_notifications = ordered
	_rebuild_visuals()

func _rebuild_visuals() -> void:
	for child in get_children():
		child.queue_free()
	_icons.clear()
	_counts.clear()
	_hit_areas.clear()
	for index in range(_notifications.size()):
		var data := _notifications[index]
		var root := Node3D.new()
		root.name = "Notification_%d" % index
		root.position = Vector3((float(index) - float(_notifications.size() - 1) * 0.5) * 1.15, 0.0, 0.0)
		add_child(root)

		var sprite := Sprite3D.new()
		sprite.name = "Icon"
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.010
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture = _icon_for(data)
		sprite.modulate = _color_for(data.type)
		sprite.position = Vector3.ZERO
		sprite.no_depth_test = true
		root.add_child(sprite)
		_icons.append(sprite)

		if data.type == BuildingNotification.Type.IDLE:
			var idle_label := Label3D.new()
			idle_label.text = "Zzz"
			idle_label.font_size = 48
			idle_label.outline_size = 8
			idle_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			idle_label.position = Vector3(0.0, 0.52, 0.0)
			idle_label.modulate = Color("#8ED8FF")
			root.add_child(idle_label)

		var count_label := Label3D.new()
		count_label.name = "Count"
		count_label.text = "×%d" % data.count if data.count > 1 else ""
		count_label.font_size = 28
		count_label.outline_size = 7
		count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		count_label.position = Vector3(0.42, -0.30, 0.0)
		count_label.modulate = Color("#FFF6D4")
		root.add_child(count_label)
		_counts.append(count_label)

		var area := Area3D.new()
		area.name = "TapArea"
		area.input_ray_pickable = true
		area.collision_layer = 1
		area.collision_mask = 0
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.78
		collision.shape = sphere
		area.add_child(collision)
		root.add_child(area)
		area.input_event.connect(_on_area_input_event.bind(index))
		_hit_areas.append(area)

func _icon_for(data: BuildingNotification) -> Texture2D:
	match data.type:
		BuildingNotification.Type.PRODUCTION_READY:
			return Icons.get_icon_tex(data.item_id)
		BuildingNotification.Type.UPGRADE_READY:
			return Icons.get_icon_tex("hard_hat")
		BuildingNotification.Type.STORAGE_FULL:
			return Icons.get_tex("status", "storage_full")
		BuildingNotification.Type.NEEDS_MATERIALS:
			return Icons.get_icon_tex("warning")
		_:
			return Icons.get_icon_tex("industrial")

func _color_for(type: int) -> Color:
	match type:
		BuildingNotification.Type.PRODUCTION_READY: return Color.WHITE
		BuildingNotification.Type.UPGRADE_READY: return Color("#FFD84D")
		BuildingNotification.Type.STORAGE_FULL: return Color("#FF7770")
		BuildingNotification.Type.NEEDS_MATERIALS: return Color("#FFC66D")
		_: return Color("#A8DFFF")

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		visible = false
		return
	visible = true
	var distance := camera.global_position.distance_to(global_position)
	var bob := sin(float(Time.get_ticks_msec()) / 1000.0 * BOB_SPEED) * BOB_HEIGHT
	position.y = _base_y + bob
	var scale_factor := 1.0
	if distance > FULL_ICON_DISTANCE:
		scale_factor = lerpf(1.0, 0.48, clampf((distance - FULL_ICON_DISTANCE) / (DOT_DISTANCE - FULL_ICON_DISTANCE), 0.0, 1.0))
	if distance >= DOT_DISTANCE:
		scale_factor = 0.30
		for index in range(_icons.size()):
			_icons[index].modulate.a = 0.82
			if index > 0:
				_icons[index].visible = false
	else:
		for icon in _icons:
			icon.visible = true
			icon.modulate.a = 1.0
	scale = Vector3.ONE * scale_factor

func _on_area_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, index: int) -> void:
	var activated := event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	activated = activated or (event is InputEventScreenTouch and event.pressed)
	if activated and index >= 0 and index < _notifications.size():
		notification_pressed.emit(_notifications[index])
