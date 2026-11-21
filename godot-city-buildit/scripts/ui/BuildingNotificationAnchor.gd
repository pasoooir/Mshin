extends Node3D
## Lightweight world-space building notifications. Existing screen-space buttons
## remain as reliable touch targets; these billboards provide the in-world cue.
const Icons = preload("res://scripts/ui/Icons.gd")
const NotificationData = preload("res://scripts/ui/BuildingNotification.gd")

const MAX_VISIBLE := 2
const BOB_HEIGHT := 0.13
const BOB_SPEED := 1.8
const FULL_ICON_DISTANCE := 42.0
const DOT_DISTANCE := 72.0

var _notifications: Array = []
var _icons: Array[Sprite3D] = []
var _count_labels: Array[Label3D] = []
var _base_y := 0.0

func _ready() -> void:
	_base_y = position.y

func set_notifications(notifications: Array) -> void:
	var ordered := notifications.duplicate()
	ordered.sort_custom(func(a: BuildingNotification, b: BuildingNotification) -> bool:
		return a.priority > b.priority
	)
	if ordered.size() > MAX_VISIBLE:
		ordered.resize(MAX_VISIBLE)
	_notifications = ordered
	_rebuild_visuals()

func get_visible_notification_count() -> int:
	return _notifications.size()

func _rebuild_visuals() -> void:
	for child in get_children():
		child.queue_free()
	_icons.clear()
	_count_labels.clear()
	# Avoid allocating Sprite3D renderer resources in headless CI.
	if DisplayServer.get_name() == "headless":
		return
	for index in range(_notifications.size()):
		var data: BuildingNotification = _notifications[index]
		var root := Node3D.new()
		root.name = "WorldNotification_%d" % index
		root.position = Vector3((float(index) - float(_notifications.size() - 1) * 0.5) * 1.0, 0.0, 0.0)
		add_child(root)
		var sprite := Sprite3D.new()
		sprite.name = "Icon"
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.008
		sprite.shaded = false
		sprite.texture = _icon_for(data)
		sprite.modulate = _color_for(data.type)
		sprite.no_depth_test = true
		root.add_child(sprite)
		_icons.append(sprite)
		var count := Label3D.new()
		count.name = "Count"
		count.text = "×%d" % data.quantity if data.type == NotificationData.Type.PRODUCTION_READY and data.quantity > 1 else ""
		count.font_size = 24
		count.outline_size = 6
		count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		count.position = Vector3(0.28, -0.28, 0.0)
		count.modulate = Color("#FFF6D4")
		root.add_child(count)
		_count_labels.append(count)

func _icon_for(data: BuildingNotification) -> Texture2D:
	match data.type:
		NotificationData.Type.PRODUCTION_READY:
			return Icons.get_icon_tex(data.item_id)
		NotificationData.Type.UPGRADE_READY:
			return Icons.get_icon_tex("hard_hat")
		NotificationData.Type.STORAGE_FULL:
			return Icons.get_tex("status", "storage_full")
		NotificationData.Type.NEEDS_MATERIALS:
			return Icons.get_icon_tex(data.item_id) if not data.item_id.is_empty() else Icons.get_icon_tex("warning")
		_:
			return Icons.get_icon_tex("industrial")

func _color_for(kind: int) -> Color:
	match kind:
		NotificationData.Type.PRODUCTION_READY: return Color.WHITE
		NotificationData.Type.UPGRADE_READY: return Color("#FFD84D")
		NotificationData.Type.STORAGE_FULL: return Color("#FF7770")
		NotificationData.Type.NEEDS_MATERIALS: return Color("#FFC66D")
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
				_icons[index].hide()
	else:
		for icon in _icons:
			icon.show()
			icon.modulate.a = 1.0
	scale = Vector3.ONE * scale_factor
