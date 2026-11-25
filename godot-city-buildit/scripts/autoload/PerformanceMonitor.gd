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
var _draw_call_samples: Array[float] = []
var _rendered_object_samples: Array[float] = []
var _rendered_primitive_samples: Array[float] = []
var _video_memory_samples: Array[float] = []
var _node_count_samples: Array[float] = []
var _process_time_ms_samples: Array[float] = []
var _physics_process_time_ms_samples: Array[float] = []
var _texture_memory_samples: Array[float] = []
var _buffer_memory_samples: Array[float] = []
var _static_memory_samples: Array[float] = []
var _camera_previous_position := Vector3.ZERO
var _camera_has_previous_position := false
var _camera_movement_frames := 0
var _camera_total_distance := 0.0
var _camera_min_zoom := INF
var _camera_max_zoom := -INF
var _camera_active_frames := 0

func start_benchmark(duration_seconds: float = 30.0) -> bool:
	if benchmark_running:
		return false
	benchmark_duration_seconds = clampf(duration_seconds, 5.0, 120.0)
	elapsed_seconds = 0.0
	_clear_samples()
	_reset_camera_metrics()
	benchmark_running = true
	benchmark_started.emit(benchmark_duration_seconds)
	return true

func cancel_benchmark() -> void:
	benchmark_running = false
	elapsed_seconds = 0.0
	_clear_samples()

func _clear_samples() -> void:
	_frame_times.clear()
	_draw_call_samples.clear()
	_rendered_object_samples.clear()
	_rendered_primitive_samples.clear()
	_video_memory_samples.clear()
	_node_count_samples.clear()
	_process_time_ms_samples.clear()
	_physics_process_time_ms_samples.clear()
	_texture_memory_samples.clear()
	_buffer_memory_samples.clear()
	_static_memory_samples.clear()

func _capture_render_metrics() -> void:
	# Performance monitors expose the most recently rendered frame. Sampling
	# them throughout the benchmark makes the report representative of the run.
	_draw_call_samples.append(maxf(0.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_rendered_object_samples.append(maxf(0.0, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	_rendered_primitive_samples.append(maxf(0.0, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	_video_memory_samples.append(maxf(0.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
	_node_count_samples.append(maxf(0.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_process_time_ms_samples.append(maxf(0.0, Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	_physics_process_time_ms_samples.append(maxf(0.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	_texture_memory_samples.append(maxf(0.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
	_buffer_memory_samples.append(maxf(0.0, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)))
	_static_memory_samples.append(maxf(0.0, Performance.get_monitor(Performance.MEMORY_STATIC)))

func _capture_camera_metrics() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var camera_rig := scene.get_node_or_null("CameraRig")
	if not is_instance_valid(camera_rig):
		return
	var camera_position: Vector3 = camera_rig.global_position
	if _camera_has_previous_position:
		var distance := camera_position.distance_to(_camera_previous_position)
		if distance > 0.02:
			_camera_movement_frames += 1
			_camera_total_distance += distance
	_camera_previous_position = camera_position
	_camera_has_previous_position = true
	var zoom_value := float(camera_rig.get("current_zoom"))
	if zoom_value > 0.0:
		_camera_min_zoom = minf(_camera_min_zoom, zoom_value)
		_camera_max_zoom = maxf(_camera_max_zoom, zoom_value)
	var touch_points: Variant = camera_rig.get("touch_points")
	var is_panning: bool = bool(camera_rig.get("is_mouse_panning")) or (touch_points is Dictionary and not touch_points.is_empty())
	var pan_velocity: Variant = camera_rig.get("pan_velocity")
	if pan_velocity is Vector2 and pan_velocity.length() > 6.0:
		is_panning = true
	if is_panning:
		_camera_active_frames += 1

func _reset_camera_metrics() -> void:
	_camera_previous_position = Vector3.ZERO
	_camera_has_previous_position = false
	_camera_movement_frames = 0
	_camera_total_distance = 0.0
	_camera_min_zoom = INF
	_camera_max_zoom = -INF
	_camera_active_frames = 0

func _process(delta: float) -> void:
	if not benchmark_running or delta <= 0.0:
		return
	_frame_times.append(delta)
	_capture_render_metrics()
	_capture_camera_metrics()
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
		"graphics_quality": GraphicsSettingsManager.quality,
		"graphics_preset": GraphicsSettingsManager.get_quality_preset(GraphicsSettingsManager.quality),
		"render_metrics": _build_render_metrics_report(),
		"cpu_metrics": _build_cpu_metrics_report(),
		"memory_metrics": _build_memory_metrics_report(),
		"camera_metrics": _build_camera_metrics_report(),
		"gpu_timing": {"available": false, "note": "Godot 4.3 GL Compatibility does not expose portable per-frame GPU execution time or GPU utilization. Video/texture/buffer memory are reported separately."},
		"scenario": "manual_camera_pan_and_zoom",
		"instructions": "During the full benchmark, continuously pan across the city and perform several zoom-in/zoom-out gestures. Keep the game in the foreground.",
		"report_path": REPORT_PATH,
		"scope": "Foreground gameplay frame loop on the physical device that ran this benchmark; not a CI or synthetic scene benchmark."
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
	_clear_samples()

func _build_render_metrics_report() -> Dictionary:
	return {
		"sample_count": _draw_call_samples.size(),
		"sampling_scope": "Per-frame samples collected during the complete foreground benchmark interval.",
		"draw_calls": summarize_numeric_samples(_draw_call_samples),
		"rendered_objects": summarize_numeric_samples(_rendered_object_samples),
		"rendered_primitives": summarize_numeric_samples(_rendered_primitive_samples),
		"video_memory_bytes": summarize_numeric_samples(_video_memory_samples),
		"node_count": summarize_numeric_samples(_node_count_samples),
		# Retain legacy last-frame fields for consumers of older reports.
		"draw_calls_last_frame": int(_last_sample(_draw_call_samples)),
		"rendered_objects_last_frame": int(_last_sample(_rendered_object_samples)),
		"rendered_primitives_last_frame": int(_last_sample(_rendered_primitive_samples))
	}

func _build_cpu_metrics_report() -> Dictionary:
	return {
		"process_time_ms": summarize_numeric_samples(_process_time_ms_samples),
		"physics_process_time_ms": summarize_numeric_samples(_physics_process_time_ms_samples),
		"note": "Engine process-time monitors are reported in milliseconds; they are not total Android CPU utilization."
	}

func _build_memory_metrics_report() -> Dictionary:
	return {
		"texture_memory_bytes": summarize_numeric_samples(_texture_memory_samples),
		"render_buffer_memory_bytes": summarize_numeric_samples(_buffer_memory_samples),
		"static_memory_bytes": summarize_numeric_samples(_static_memory_samples),
		"video_memory_bytes": summarize_numeric_samples(_video_memory_samples)
	}

func _build_camera_metrics_report() -> Dictionary:
	var movement_percent := float(_camera_movement_frames) * 100.0 / float(_frame_times.size()) if not _frame_times.is_empty() else 0.0
	var active_percent := float(_camera_active_frames) * 100.0 / float(_frame_times.size()) if not _frame_times.is_empty() else 0.0
	return {
		"movement_frames": _camera_movement_frames,
		"movement_frame_percent": snappedf(movement_percent, 0.1),
		"active_pan_frames": _camera_active_frames,
		"active_pan_frame_percent": snappedf(active_percent, 0.1),
		"total_camera_distance_world_units": snappedf(_camera_total_distance, 0.01),
		"zoom_min": snappedf(_camera_min_zoom, 0.01) if _camera_min_zoom != INF else 0.0,
		"zoom_max": snappedf(_camera_max_zoom, 0.01) if _camera_max_zoom != -INF else 0.0
	}

static func _last_sample(samples: Array[float]) -> float:
	return samples.back() if not samples.is_empty() else 0.0

static func summarize_numeric_samples(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {"sample_count": 0, "average": 0.0, "p95": 0.0, "max": 0.0, "last": 0.0}
	var sorted_samples: Array[float] = samples.duplicate()
	var total := 0.0
	var maximum := 0.0
	for sample in samples:
		var safe_sample := maxf(sample, 0.0)
		total += safe_sample
		maximum = maxf(maximum, safe_sample)
	sorted_samples.sort()
	var p95_index := clampi(int(ceil(float(sorted_samples.size()) * 0.95)) - 1, 0, sorted_samples.size() - 1)
	return {
		"sample_count": samples.size(),
		"average": snappedf(total / float(samples.size()), 0.01),
		"p95": snappedf(sorted_samples[p95_index], 0.01),
		"max": snappedf(maximum, 0.01),
		"last": snappedf(maxf(samples.back(), 0.0), 0.01)
	}

static func summarize_frame_times(frame_times: Array[float]) -> Dictionary:
	if frame_times.is_empty():
		return {
			"frame_count": 0,
			"average_fps": 0.0,
			"average_frame_ms": 0.0,
			"p95_frame_ms": 0.0,
			"max_frame_ms": 0.0,
			"frames_within_60fps_budget_percent": 0.0,
			"frames_within_30fps_budget_percent": 0.0,
			"target_60fps_pass": false,
			"target_30fps_pass": false
		}
	var total_seconds := 0.0
	var max_frame_seconds := 0.0
	var frames_within_budget := 0
	var frames_within_30fps_budget := 0
	var sorted_times: Array[float] = frame_times.duplicate()
	for frame_seconds in frame_times:
		var safe_frame_seconds := maxf(frame_seconds, 0.0)
		total_seconds += safe_frame_seconds
		max_frame_seconds = maxf(max_frame_seconds, safe_frame_seconds)
		if safe_frame_seconds <= 1.0 / 60.0:
			frames_within_budget += 1
		if safe_frame_seconds <= 1.0 / 30.0:
			frames_within_30fps_budget += 1
	sorted_times.sort()
	var average_fps := float(frame_times.size()) / total_seconds if total_seconds > 0.0 else 0.0
	var average_frame_ms := total_seconds * 1000.0 / float(frame_times.size())
	var p95_index := clampi(int(ceil(float(sorted_times.size()) * 0.95)) - 1, 0, sorted_times.size() - 1)
	var p95_frame_seconds := sorted_times[p95_index]
	var p95_frame_ms := p95_frame_seconds * 1000.0
	var max_frame_ms := max_frame_seconds * 1000.0
	var under_budget_percent := float(frames_within_budget) * 100.0 / float(frame_times.size())
	var under_30fps_budget_percent := float(frames_within_30fps_budget) * 100.0 / float(frame_times.size())
	return {
		"frame_count": frame_times.size(),
		"average_fps": snappedf(average_fps, 0.01),
		"average_frame_ms": snappedf(average_frame_ms, 0.01),
		"p95_frame_ms": snappedf(p95_frame_ms, 0.01),
		"max_frame_ms": snappedf(max_frame_ms, 0.01),
		"frames_within_60fps_budget_percent": snappedf(under_budget_percent, 0.1),
		"frames_within_30fps_budget_percent": snappedf(under_30fps_budget_percent, 0.1),
		"target_60fps_pass": average_fps >= 60.0 and p95_frame_seconds <= 1.0 / 60.0,
		"target_30fps_pass": average_fps >= 30.0 and p95_frame_seconds <= 1.0 / 30.0
	}
