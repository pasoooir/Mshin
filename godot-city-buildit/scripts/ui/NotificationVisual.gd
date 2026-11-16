extends Button
## Screen-space tap target projected from a world-space building roof anchor.
## It faces the active camera by construction and gently bobs without changing
## its projected anchor. Distance LOD scales the complete touch target and icon.
var _anchor_position := Vector2.ZERO
var _phase := 0.0
var _lod_scale := 1.0

func _process(delta: float) -> void:
	_phase += delta
	position = _anchor_position + Vector2(0.0, sin(_phase * 2.0) * 2.4)

func set_anchor_position(value: Vector2) -> void:
	_anchor_position = value
	position = value

func set_lod_distance(distance: float) -> void:
	if distance < 45.0:
		_lod_scale = 1.0
	elif distance < 85.0:
		_lod_scale = 0.78
	elif distance < 125.0:
		_lod_scale = 0.55
	else:
		_lod_scale = 0.34
	scale = Vector2.ONE * _lod_scale
