extends Node
## User-selectable 3D render quality. UI remains at native resolution; only
## the 3D render buffer and MSAA level are changed.

signal quality_changed(quality: String, settings: Dictionary)

var settings_path := "user://graphics_settings.cfg"
const QUALITY_PRESETS := {
	"low": {"label": "Low", "scale": 0.70, "msaa": Viewport.MSAA_DISABLED},
	"balanced": {"label": "Balanced", "scale": 0.85, "msaa": Viewport.MSAA_2X},
	"high": {"label": "High", "scale": 1.0, "msaa": Viewport.MSAA_4X}
}

var quality := "balanced"

func _ready() -> void:
	_load_settings()
	call_deferred("_apply_quality")

func set_quality(value: String) -> bool:
	if not QUALITY_PRESETS.has(value):
		return false
	if quality == value:
		_apply_quality()
		return true
	quality = value
	_apply_quality()
	_save_settings()
	quality_changed.emit(quality, get_quality_preset(quality))
	return true

func _apply_quality() -> void:
	if not is_inside_tree():
		return
	var viewport := get_tree().root
	if viewport == null:
		return
	var preset := get_quality_preset(quality)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = float(preset.get("scale", 0.85))
	viewport.msaa_3d = int(preset.get("msaa", Viewport.MSAA_2X))

func set_player_scope(path: String) -> void:
	settings_path = path
	quality = "balanced"
	_load_settings()
	_apply_quality()

func to_save_dict() -> Dictionary:
	return {"quality": quality}

func from_save_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	var saved_quality := str(data.get("quality", "balanced"))
	if QUALITY_PRESETS.has(saved_quality):
		quality = saved_quality
		_apply_quality()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var saved_quality := str(config.get_value("graphics", "quality", "balanced"))
	if QUALITY_PRESETS.has(saved_quality):
		quality = saved_quality

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", quality)
	var directory := ProjectSettings.globalize_path(settings_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(directory)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("[GraphicsSettingsManager] Could not save graphics quality: %s" % error_string(error))
	elif SaveManager.persistence_ready:
		SaveManager.save_game()

static func get_quality_preset(value: String) -> Dictionary:
	if not QUALITY_PRESETS.has(value):
		return {}
	return QUALITY_PRESETS[value].duplicate(true)

static func get_quality_names() -> PackedStringArray:
	return PackedStringArray(["low", "balanced", "high"])
