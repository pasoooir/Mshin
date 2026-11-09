extends RefCounted
## Backward-compatible facade; all texture paths and loads live in Icons.gd.
const Icons = preload("res://scripts/ui/Icons.gd")

static func texture_for(icon_name: String) -> Texture2D:
	return Icons.get_icon_tex(icon_name)

static func make_icon(icon_name: String, display_size: Vector2 = Vector2(64, 64)) -> TextureRect:
	return Icons.make_icon(icon_name, display_size)

static func get_icon_keys() -> Array[String]:
	return Icons.get_icon_keys()

static func validate_sheets() -> bool:
	return Icons.validate_all_icons()

static func validate_required_build_icons() -> bool:
	return Icons.validate_required_build_icons()

static func validate_all_icons() -> bool:
	return Icons.validate_all_icons()
