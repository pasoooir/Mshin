extends Node

## Browser haptics for mobile Web builds.
## The Vibration API is optional and may be unavailable or blocked by the browser.
const PLACE_DURATION_MS := 18
const COLLECT_DURATION_MS := 26
const MAX_PULSE_DURATION_MS := 40
var settings_path := "user://haptics_settings.cfg"

var enabled := true

func _ready() -> void:
	_load_settings()

func get_pulse_duration_ms(event_name: String) -> int:
	match event_name:
		"place":
			return PLACE_DURATION_MS
		"collect":
			return COLLECT_DURATION_MS
		_:
			return 0

func pulse_for(event_name: String) -> bool:
	return pulse(get_pulse_duration_ms(event_name))

func pulse(duration_ms: int) -> bool:
	if not enabled or duration_ms <= 0:
		return false
	var safe_duration := get_safe_pulse_duration_ms(duration_ms)
	if OS.has_feature("web"):
		# Keep the request synchronous inside the originating browser gesture.
		# Safari/Firefox and devices with vibration disabled safely return false.
		var result: Variant = JavaScriptBridge.eval(
			"typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function' ? navigator.vibrate(%d) : false" % safe_duration
		)
		return result is bool and result
	if OS.has_feature("android") or OS.has_feature("ios"):
		# Godot maps this API to Android/iOS handheld vibration. Android exports
		# must declare the VIBRATE permission; the Android preset does so.
		Input.vibrate_handheld(safe_duration)
		return true
	return false

func set_enabled(value: bool) -> void:
	enabled = value
	_save_settings()

func get_safe_pulse_duration_ms(duration_ms: int) -> int:
	return clampi(duration_ms, 1, MAX_PULSE_DURATION_MS) if duration_ms > 0 else 0

static func get_backend_for_features(features: PackedStringArray) -> String:
	if features.has("web"):
		return "web"
	if features.has("android"):
		return "android_native"
	if features.has("ios"):
		return "ios_native"
	return "unsupported"

func set_player_scope(path: String) -> void:
	settings_path = path
	enabled = true
	_load_settings()

func to_save_dict() -> Dictionary:
	return {"enabled": enabled}

func from_save_dict(data: Dictionary) -> void:
	if not data.is_empty():
		enabled = bool(data.get("enabled", true))

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		enabled = bool(config.get_value("haptics", "enabled", true))

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("haptics", "enabled", enabled)
	var directory := ProjectSettings.globalize_path(settings_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(directory)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("[HapticsManager] Could not save haptic settings: %s" % error_string(error))
	elif SaveManager.persistence_ready:
		SaveManager.save_game()
