extends Node

## Browser haptics for mobile Web builds.
## The Vibration API is optional and may be unavailable or blocked by the browser.
const PLACE_DURATION_MS := 18
const COLLECT_DURATION_MS := 26
const MAX_PULSE_DURATION_MS := 40

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
	if not OS.has_feature("web") or duration_ms <= 0:
		return false
	var safe_duration := clampi(duration_ms, 1, MAX_PULSE_DURATION_MS)
	if safe_duration <= 0:
		return false
	# eval is synchronous so the browser sees this call inside the originating
	# placement touch or Collect button gesture. Unsupported browsers return false.
	var result: Variant = JavaScriptBridge.eval(
		"typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function' ? navigator.vibrate(%d) : false" % safe_duration
	)
	return result is bool and result
