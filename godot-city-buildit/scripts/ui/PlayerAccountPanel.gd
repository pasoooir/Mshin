extends CanvasLayer

var _panel: PanelContainer
var _status: Label
var _action: Button

func _ready() -> void:
	layer = 45
	_build_ui()
	PlayerAccountManager.session_changed.connect(_on_session_changed)
	PlayerAccountManager.authentication_feedback.connect(_on_authentication_feedback)
	_refresh()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "PlayerAccountPanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -350.0
	_panel.offset_right = -12.0
	_panel.offset_top = 112.0
	_panel.offset_bottom = 174.0
	_panel.custom_minimum_size = Vector2(338.0, 62.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.12, 0.88)
	style.border_color = Color(0.28, 0.68, 0.92, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_panel.add_child(row)

	_status = Label.new()
	_status.name = "AccountStatus"
	_status.text = "Player account · Guest"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_status)

	_action = Button.new()
	_action.name = "AccountAction"
	_action.text = "Sign in"
	_action.custom_minimum_size = Vector2(104.0, 40.0)
	_action.focus_mode = Control.FOCUS_NONE
	_action.pressed.connect(_on_action_pressed)
	row.add_child(_action)

func _refresh() -> void:
	if not is_instance_valid(_status) or not is_instance_valid(_action):
		return
	if PlayerAccountManager.is_authenticated():
		_status.text = "Connected · Mayor #%d" % PlayerAccountManager.player_id
		_action.text = "Sign out"
	else:
		_status.text = "Player account · Guest"
		_action.text = "Sign in with Google"

func _on_action_pressed() -> void:
	if PlayerAccountManager.is_authenticated():
		_action.disabled = true
		await PlayerAccountManager.logout()
		_refresh()
		_action.disabled = false
		return
	_action.disabled = true
	var started := PlayerAccountManager.begin_google_sign_in()
	if not started:
		_action.disabled = false

func _on_session_changed(_player_id: int, _authenticated: bool) -> void:
	_refresh()

func _on_authentication_feedback(message: String, success: bool) -> void:
	if is_instance_valid(_status):
		_status.text = message
	if is_instance_valid(_action):
		_action.disabled = false
		_action.text = "Sign out" if success and PlayerAccountManager.is_authenticated() else "Sign in with Google"
