extends Node
## On-device frame-time benchmark. It records the real game loop and never
## substitutes editor/CI measurements for the user's physical device result.

signal benchmark_started(duration_seconds: float)
signal benchmark_progress(elapsed_seconds: float, duration_seconds: float)
signal benchmark_finished(report: Dictionary)

const REPORT_PATH := "user://performance_benchmark_latest.json"
const TARGET_FRAME_MS := 1000.0 / 60.0

var benchmark_running := false
var benchmark_duration_seconds := 30.0
var elapsed_seconds := 0.0
var _frame_times: Array[float] = []

func start_benchmark(duration_seconds: float = 30.0) -> bool:
	if benchmark_running:
		return false
	benchmark_duration_seconds = clampf(duration_seconds, 5.0, 120.0)
	elapsed_seconds = 0.0
	_frame_times.clear()
	benchmark_running = true
	benchmark_started.emit(benchmark_duration_seconds)
	return true

func cancel_benchmark() -> void:
	benchmark_running = false
	elapsed_seconds = 0.0
	_frame_times.clear()

func _process(delta: float) -> void:
	if not benchmark_running or delta <= 0.0:
		return
	_frame_times.append(delta)
	var previous_second := int(elapsed_seconds)
	elapsed_seconds += delta
	if int(elapsed_seconds) > previous_second:
		benchmark_progress.emit(minf(elapsed_seconds, benchmark_duration_seconds), benchmark_duration_seconds)
	if elapsed_seconds >= benchmark_duration_seconds:
		_finish_benchmark()

func _finish_benchmark() -> void:
	benchmark_running = false
	var summary := summarize_frame_times(_frame_times)
	var viewport_size := get_viewport().get_visible_rect().size
	var version_info: Dictionary = Engine.get_version_info()
	var report := {
		"created_at": Time.get_datetime_string_from_system(true),
		"platform": OS.get_name(),
		"device_model": OS.get_model_name(),
		"processor": OS.get_processor_name(),
		"architecture": Engine.get_architecture_name(),
		"processor_count": OS.get_processor_count(),
		"engine_version": str(version_info.get("string", "unknown")),
		"viewport_width": int(viewport_size.x),
		"viewport_height": int(viewport_size.y),
		"target_fps": 60,
		"duration_seconds": benchmark_duration_seconds,
		"summary": summary,
		"render_metrics": {
			"draw_calls_last_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"rendered_objects_last_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			"rendered_primitives_last_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
			"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		},
		"report_path": REPORT_PATH,
		"scope": "Foreground gameplay frame loop on the device that ran this benchmark; not a CI or synthetic scene benchmark."
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	else:
		report["report_path"] = ""
		report["save_error"] = error_string(FileAccess.get_open_error())
		push_warning("[PerformanceMonitor] Could not save benchmark report: %s" % report["save_error"])
	benchmark_finished.emit(report)
	_frame_times.clear()

static func summarize_frame_times(frame_times: Array[float]) -> Dictionary:
	if frame_times.is_empty():
		return {
			"frame_count": 0,
			"average_fps": 0.0,
			"average_frame_ms": 0.0,
			"p95_frame_ms": 0.0,
			"max_frame_ms": 0.0,
			"frames_within_60fps_budget_percent": 0.0,
			"target_60fps_pass": false
		}
	var total_seconds := 0.0
	var max_frame_seconds := 0.0
	var frames_within_budget := 0
	var sorted_times: Array[float] = frame_times.duplicate()
	for frame_seconds in frame_times:
		var safe_frame_seconds := maxf(frame_seconds, 0.0)
		total_seconds += safe_frame_seconds
		max_frame_seconds = maxf(max_frame_seconds, safe_frame_seconds)
		if safe_frame_seconds <= 1.0 / 60.0:
			frames_within_budget += 1
	sorted_times.sort()
	var average_fps := float(frame_times.size()) / total_seconds if total_seconds > 0.0 else 0.0
	var average_frame_ms := total_seconds * 1000.0 / float(frame_times.size())
	var p95_index := clampi(int(ceil(float(sorted_times.size()) * 0.95)) - 1, 0, sorted_times.size() - 1)
	var p95_frame_ms := sorted_times[p95_index] * 1000.0
	var max_frame_ms := max_frame_seconds * 1000.0
	var under_budget_percent := float(frames_within_budget) * 100.0 / float(frame_times.size())
	return {
		"frame_count": frame_times.size(),
		"average_fps": snappedf(average_fps, 0.01),
		"average_frame_ms": snappedf(average_frame_ms, 0.01),
		"p95_frame_ms": snappedf(p95_frame_ms, 0.01),
		"max_frame_ms": snappedf(max_frame_ms, 0.01),
		"frames_under_60fps_percent": snappedf(under_budget_percent, 0.1),
		"target_60fps_pass": average_fps >= 60.0 and p95_frame_ms <= TARGET_FRAME_MS
	}
