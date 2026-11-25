extends Node
## User-selectable render tiers. UI stays at native resolution while 3D
## resolution, shadows and procedural world detail follow device capability.

signal quality_changed(quality: String, settings: Dictionary)

var settings_path := "user://graphics_settings.cfg"
const QUALITY_PRESETS := {
	"low": {
		"label": "Low",
		"scale": 0.54,
		"msaa": Viewport.MSAA_DISABLED,
		"shadows": false,
		"camera_pan_sensitivity": 0.70,
		"terrain_divisions": 96,
		"water_rows": 72,
		"water_columns": 18,
		"grass_instances": 0,
		"shrub_clusters": 0,
		"tree_density": 0.0
	},
	"balanced": {
		"label": "Balanced",
		"scale": 0.84,
		"msaa": Viewport.MSAA_2X,
		"shadows": true,
		"camera_pan_sensitivity": 0.90,
		"terrain_divisions": 160,
		"water_rows": 160,
		"water_columns": 40,
		"grass_instances": 2400,
		"shrub_clusters": 180,
		"tree_density": 1.0
	},
	"high": {
		"label": "High",
		"scale": 1.0,
		"msaa": Viewport.MSAA_4X,
		"shadows": true,
		"camera_pan_sensitivity": 0.95,
		"terrain_divisions": 192,
		"water_rows": 180,
		"water_columns": 48,
		"grass_instances": 3600,
		"shrub_clusters": 240,
		"tree_density": 1.0
	}
}

var quality := "balanced"
var _adaptive_sample_elapsed := 0.0
var _slow_fps_windows := 0
var _fast_fps_windows := 0

const LOW_SCALE_MIN := 0.48
const LOW_SCALE_MAX := 0.62
const ADAPTIVE_SAMPLE_SECONDS := 2.0

func _ready() -> void:
	quality = _default_quality()
	_load_settings()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_apply_quality")


static func is_mobile_target() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
		or DisplayServer.is_touchscreen_available()
	)


static func _default_quality() -> String:
	return "low" if is_mobile_target() else "balanced"


func _on_node_added(node: Node) -> void:
	if node is DirectionalLight3D:
		var preset := get_quality_preset(quality)
		node.shadow_enabled = bool(preset.get("shadows", true))


func _process(delta: float) -> void:
	if quality != "low" or delta <= 0.0:
		return
	_adaptive_sample_elapsed += delta
	if _adaptive_sample_elapsed < ADAPTIVE_SAMPLE_SECONDS:
		return
	_adaptive_sample_elapsed = 0.0
	var measured_fps := float(Engine.get_frames_per_second())
	if measured_fps > 0.0 and measured_fps < 28.0:
		_slow_fps_windows += 1
		_fast_fps_windows = 0
	elif measured_fps >= 40.0:
		_fast_fps_windows += 1
		_slow_fps_windows = 0
	else:
		_slow_fps_windows = 0
		_fast_fps_windows = 0
	if _slow_fps_windows >= 2 or _fast_fps_windows >= 8:
		var viewport := get_tree().root
		if viewport != null:
			viewport.scaling_3d_scale = adaptive_low_scale(viewport.scaling_3d_scale, measured_fps)
		_slow_fps_windows = 0
		_fast_fps_windows = 0


static func adaptive_low_scale(current_scale: float, measured_fps: float) -> float:
	var current := clampf(current_scale, LOW_SCALE_MIN, LOW_SCALE_MAX)
	if measured_fps > 0.0 and measured_fps < 28.0:
		return maxf(LOW_SCALE_MIN, current - 0.06)
	if measured_fps >= 54.0:
		return minf(LOW_SCALE_MAX, current + 0.02)
	return current

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
	viewport.scaling_3d_scale = float(preset.get("scale", 0.62))
	viewport.msaa_3d = int(preset.get("msaa", Viewport.MSAA_DISABLED))
	Engine.max_fps = 60
	_adaptive_sample_elapsed = 0.0
	_slow_fps_windows = 0
	_fast_fps_windows = 0
	set_process(quality == "low")
	var scene := get_tree().current_scene
	if is_instance_valid(scene):
		for light in scene.find_children("*", "DirectionalLight3D", true, false):
			if light is DirectionalLight3D:
				light.shadow_enabled = bool(preset.get("shadows", true))

func set_player_scope(path: String) -> void:
	settings_path = path
	quality = _default_quality()
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
	var saved_quality := str(config.get_value("graphics", "quality", quality))
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
