extends Control
## Lightweight, self-contained Level Up celebration.
## Uses a small number of CanvasItem draw calls so it remains smooth on mobile.

signal finished

const EFFECT_DURATION := 2.75
const PARTICLE_COUNT := 68

var _elapsed := 0.0
var _particles: Array[Dictionary] = []
var _reward_simoleons: Label
var _reward_keys: Label
var _center_card: PanelContainer
var _rewards_grid: GridContainer
var _card_style: StyleBoxFlat
var _rng := RandomNumberGenerator.new()
var _completed := false

func _ready() -> void:
	name = "LevelUpCelebration"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	z_index = 100
	_rng.randomize()
	_create_particles()
	_create_message_card()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	set_process(false)

func play(new_level: int, simoleons: int, keys: int) -> void:
	_elapsed = 0.0
	_completed = false
	visible = true
	modulate.a = 1.0
	set_process(true)
	_reward_simoleons.text = "+0 Simoleons"
	_reward_keys.text = "+0 Golden Keys"

	var tween := create_tween()
	tween.set_parallel(true)
	var card := get_node("CenterCard") as Control
	card.scale = Vector2(0.72, 0.72)
	card.modulate.a = 0.0
	tween.tween_property(card, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.24)
	# Reward counters animate concurrently with the card entrance.
	tween.tween_method(_set_simoleon_reward, 0.0, float(simoleons), 1.0)
	tween.tween_method(_set_key_reward, 0.0, float(keys), 0.82)
	queue_redraw()

func _create_particles() -> void:
	_particles.clear()
	for index in range(PARTICLE_COUNT):
		_particles.append({
			"angle": _rng.randf_range(0.0, TAU),
			"speed": _rng.randf_range(115.0, 430.0),
			"size": _rng.randf_range(2.0, 5.5),
			"delay": _rng.randf_range(0.0, 0.16),
			"life": _rng.randf_range(1.15, 1.95),
			"gold": _rng.randf() > 0.24
		})

func _create_message_card() -> void:
	var card := PanelContainer.new()
	_center_card = card
	card.name = "CenterCard"
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	var card_width := minf(get_viewport_rect().size.x * 0.92, 560.0)
	card.offset_left = -card_width * 0.5
	card.offset_right = card_width * 0.5
	card.offset_top = -132.0
	card.offset_bottom = 132.0
	card.pivot_offset = Vector2(card_width * 0.5, 132.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	_card_style = style
	style.bg_color = Color(0.035, 0.075, 0.12, 0.94)
	style.border_color = Color(1.0, 0.78, 0.28, 0.95)
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(1.0, 0.68, 0.12, 0.38)
	style.shadow_size = 22
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", style)
	add_child(card)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 8)
	card.add_child(layout)

	var title := Label.new()
	title.name = "LevelUpTitle"
	title.text = "LEVEL UP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#FFD34F"))
	title.add_theme_color_override("font_shadow_color", Color(0.45, 0.20, 0.02, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "MayorCongratulations"
	subtitle.text = "Congratulations Mayor!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	layout.add_child(subtitle)

	var divider := HSeparator.new()
	layout.add_child(divider)

	var rewards := GridContainer.new()
	rewards.name = "LevelUpRewardsGrid"
	_rewards_grid = rewards
	rewards.columns = 2
	rewards.add_theme_constant_override("h_separation", 20)
	rewards.add_theme_constant_override("v_separation", 8)
	layout.add_child(rewards)

	_reward_simoleons = Label.new()
	_reward_simoleons.name = "SimoleonReward"
	_reward_simoleons.text = "+0 Simoleons"
	_reward_simoleons.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_simoleons.add_theme_font_size_override("font_size", 20)
	_reward_simoleons.add_theme_color_override("font_color", Color("#FFD34F"))
	rewards.add_child(_reward_simoleons)

	_reward_keys = Label.new()
	_reward_keys.name = "GoldenKeyReward"
	_reward_keys.text = "+0 Golden Keys"
	_reward_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_keys.add_theme_font_size_override("font_size", 20)
	_reward_keys.add_theme_color_override("font_color", Color("#FFE7A0"))
	rewards.add_child(_reward_keys)

func _apply_responsive_layout(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_center_card):
		return
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport_rect().size
	var compact := viewport_size.x < 900.0
	var card_width := minf(viewport_size.x * 0.92, 560.0)
	var card_height := 240.0 if compact else 264.0
	_center_card.offset_left = -card_width * 0.5
	_center_card.offset_right = card_width * 0.5
	_center_card.offset_top = -card_height * 0.5
	_center_card.offset_bottom = card_height * 0.5
	_center_card.pivot_offset = Vector2(card_width * 0.5, card_height * 0.5)
	if _card_style:
		var inset := 14.0 if compact else 22.0
		_card_style.content_margin_left = inset
		_card_style.content_margin_right = inset
		_card_style.content_margin_top = 14.0 if compact else 18.0
		_card_style.content_margin_bottom = 14.0 if compact else 18.0
	if _rewards_grid:
		_rewards_grid.columns = 1 if compact else 2
	var title := find_child("LevelUpTitle", true, false) as Label
	if title:
		title.add_theme_font_size_override("font_size", 30 if compact else 48)
	var subtitle := find_child("MayorCongratulations", true, false) as Label
	if subtitle:
		subtitle.add_theme_font_size_override("font_size", 18 if compact else 24)
	if _reward_simoleons:
		_reward_simoleons.add_theme_font_size_override("font_size", 16 if compact else 20)
	if _reward_keys:
		_reward_keys.add_theme_font_size_override("font_size", 16 if compact else 20)


func _set_simoleon_reward(value: float) -> void:
	if is_instance_valid(_reward_simoleons):
		_reward_simoleons.text = "+%s Simoleons" % _format_reward(roundi(value))

func _set_key_reward(value: float) -> void:
	if is_instance_valid(_reward_keys):
		var count := roundi(value)
		var key_name := "Golden Key" if count == 1 else "Golden Keys"
		_reward_keys.text = "+%s %s" % [_format_reward(count), key_name]

func _format_reward(value: int) -> String:
	var raw := str(value)
	var formatted := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length() - index) % 3 == 0:
			formatted += ","
		formatted += raw.substr(index, 1)
	return formatted

func _gui_input(_event: InputEvent) -> void:
	# Consume taps during the short celebration so city tools cannot activate underneath it.
	accept_event()

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= EFFECT_DURATION and not _completed:
		_completed = true
		set_process(false)
		finished.emit()
		return
	if _elapsed > EFFECT_DURATION - 0.38:
		modulate.a = clampf((EFFECT_DURATION - _elapsed) / 0.38, 0.0, 1.0)

func _draw() -> void:
	var center := size * 0.5
	# A short, bright flash fades quickly instead of washing out the whole scene.
	var flash_alpha := 0.58 * exp(-_elapsed * 5.2)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.82, 0.38, flash_alpha))

	# Expanding golden shockwave rings.
	for ring_index in range(3):
		var ring_time := maxf(0.0, _elapsed - float(ring_index) * 0.12)
		var radius := 28.0 + ring_time * (300.0 + ring_index * 48.0)
		var alpha := clampf(1.0 - ring_time / 1.25, 0.0, 1.0) * 0.72
		if alpha > 0.0:
			draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 0.78, 0.24, alpha), 4.0, true)

	# Lightweight radial particles: fixed count, no nodes or physics bodies.
	for particle in _particles:
		var age := _elapsed - float(particle["delay"])
		var life := float(particle["life"])
		if age < 0.0 or age >= life:
			continue
		var direction := Vector2(cos(float(particle["angle"])), sin(float(particle["angle"])))
		var distance := float(particle["speed"]) * age
		var point := center + direction * distance + Vector2(0.0, 95.0 * age * age)
		var alpha := 1.0 - age / life
		var tint := Color(1.0, 0.82, 0.30, alpha) if bool(particle["gold"]) else Color(0.72, 0.94, 1.0, alpha)
		var radius := float(particle["size"]) * (0.7 + alpha * 0.55)
		draw_line(point - direction * radius * 2.8, point, Color(tint.r, tint.g, tint.b, alpha * 0.55), maxf(1.0, radius * 0.8), true)
		draw_circle(point, radius, tint)
