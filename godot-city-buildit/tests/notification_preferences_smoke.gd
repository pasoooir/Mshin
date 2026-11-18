extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := ConfigFile.new()
	config.set_value("notifications", "building_alerts", false)
	config.set_value("notifications", "city_updates", false)
	if config.save("user://notification_preferences.cfg") != OK:
		push_error("[NotificationPreferencesSmoke] Could not prepare preferences.")
		quit(1)
		return

	var scene_resource := load("res://scenes/main.tscn") as PackedScene
	if scene_resource == null:
		push_error("[NotificationPreferencesSmoke] Main scene could not be loaded.")
		quit(1)
		return
	if change_scene_to_packed(scene_resource) != OK:
		push_error("[NotificationPreferencesSmoke] Main scene could not be started.")
		quit(1)
		return
	await process_frame
	await process_frame

	var game_manager := root.get_node_or_null("GameManager")
	var save_manager := root.get_node_or_null("SaveManager")
	var hud := current_scene.get_node_or_null("HUD")
	var alert_layer := current_scene.get_node_or_null("HUD/BuildingNotificationLayer")
	var citizen_feedback := current_scene.get_node_or_null("CitizenFeedback")
	if game_manager == null or save_manager == null or hud == null or alert_layer == null or citizen_feedback == null:
		push_error("[NotificationPreferencesSmoke] Settings notification components are missing.")
		quit(1)
		return
	if alert_layer.are_building_alerts_enabled() or citizen_feedback.are_city_updates_enabled():
		push_error("[NotificationPreferencesSmoke] Saved disabled preferences were not restored.")
		quit(1)
		return

	save_manager.persistence_ready = true
	save_manager.is_loading = false
	hud._show_settings_panel()
	await process_frame
	var notification_button := hud.find_child("SettingsNotificationsButton", true, false) as Button
	if notification_button == null:
		push_error("[NotificationPreferencesSmoke] Notification Settings action button is missing.")
		quit(1)
		return
	notification_button.pressed.emit()
	await process_frame
	var notification_dialog := hud.find_child("NotificationSettingsDialog", true, false) as AcceptDialog
	var building_toggle := hud.find_child("BuildingAlertsToggle", true, false) as CheckButton
	var updates_toggle := hud.find_child("CityUpdatesToggle", true, false) as CheckButton
	if notification_dialog == null or building_toggle == null or updates_toggle == null:
		push_error("[NotificationPreferencesSmoke] Notification form did not open with both controls.")
		quit(1)
		return
	building_toggle.toggled.emit(true)
	updates_toggle.toggled.emit(true)
	if not alert_layer.are_building_alerts_enabled() or not citizen_feedback.are_city_updates_enabled():
		push_error("[NotificationPreferencesSmoke] Notification toggle events did not update live systems.")
		quit(1)
		return
	if not save_manager.save_game():
		push_error("[NotificationPreferencesSmoke] Could not write the city JSON after changing notification preferences.")
		quit(1)
		return
	var saved_preferences: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_manager.get_active_save_path()))
	var saved_notification_data: Dictionary = saved_preferences.get("preferences", {}).get("notifications", {}) if saved_preferences is Dictionary else {}
	if not bool(saved_notification_data.get("building_alerts", false)) or not bool(saved_notification_data.get("city_updates", false)):
		push_error("[NotificationPreferencesSmoke] Notification preferences were not written to the player JSON save.")
		quit(1)
		return
	save_manager._notification_preferences = {"building_alerts": false, "city_updates": false}
	if not save_manager.load_game():
		push_error("[NotificationPreferencesSmoke] Could not reload the saved notification preferences.")
		quit(1)
		return
	if not alert_layer.are_building_alerts_enabled() or not citizen_feedback.are_city_updates_enabled():
		push_error("[NotificationPreferencesSmoke] Notification preferences were not restored from JSON.")
		quit(1)
		return
	notification_dialog.hide()
	notification_dialog.queue_free()

	# The About form exposes real graphics and audio controls, not decorative placeholders.
	var about_button := hud.find_child("SettingsAboutButton", true, false) as Button
	if about_button == null:
		push_error("[NotificationPreferencesSmoke] About action button is missing.")
		quit(1)
		return
	about_button.pressed.emit()
	await process_frame
	var about_dialog := hud.find_child("SettingsAboutDialog", true, false) as AcceptDialog
	var graphics_select := hud.find_child("GraphicsQualitySelect", true, false) as OptionButton
	var master_slider := hud.find_child("MasterVolumeSlider", true, false) as HSlider
	if about_dialog == null or graphics_select == null or master_slider == null:
		push_error("[NotificationPreferencesSmoke] About form is missing its functional graphics/audio controls.")
		quit(1)
		return
	graphics_select.item_selected.emit(GraphicsSettingsManager.get_quality_names().find(GraphicsSettingsManager.quality))
	master_slider.value_changed.emit(35.0)
	await create_timer(0.8).timeout
	var audio_graphics_state: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_manager.get_active_save_path()))
	var saved_audio: Dictionary = audio_graphics_state.get("preferences", {}).get("audio", {}) if audio_graphics_state is Dictionary else {}
	if absf(float(saved_audio.get("master_volume", -1.0)) - 0.35) > 0.01:
		push_error("[NotificationPreferencesSmoke] Master volume slider did not persist to player JSON.")
		quit(1)
		return
	about_dialog.hide()
	about_dialog.queue_free()

	# Wallet must display current balances without a dead, disabled purchase button.
	var wallet_button := hud.find_child("SettingsWalletButton", true, false) as Button
	if wallet_button == null:
		push_error("[NotificationPreferencesSmoke] Wallet action button is missing.")
		quit(1)
		return
	wallet_button.pressed.emit()
	await process_frame
	var wallet_dialog := hud.find_child("SettingsWalletDialog", true, false) as AcceptDialog
	if wallet_dialog == null or hud.find_child("WalletTopUpDisabled", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Wallet action did not open a useful, non-dead wallet view.")
		quit(1)
		return
	wallet_dialog.hide()
	wallet_dialog.queue_free()

	# Guest players can change the city name and persist it locally without a Google login.
	var rename_button := hud.find_child("SettingsChangeCityNameButton", true, false) as Button
	if rename_button == null:
		push_error("[NotificationPreferencesSmoke] Change City Name action button is missing.")
		quit(1)
		return
	rename_button.pressed.emit()
	await process_frame
	var city_dialog := current_scene.get_node_or_null("HUD/ChangeCityNameDialog")
	if city_dialog == null:
		push_error("[NotificationPreferencesSmoke] Guest city-name dialog did not open.")
		quit(1)
		return
	var city_name_input := city_dialog.get_node_or_null("CityNameInput") as LineEdit
	if city_name_input == null:
		push_error("[NotificationPreferencesSmoke] City-name input is missing.")
		quit(1)
		return
	city_name_input.text = "Test Harbor"
	city_dialog.confirmed.emit()
	await process_frame
	await process_frame
	if str(game_manager.city_name) != "Test Harbor":
		push_error("[NotificationPreferencesSmoke] Guest city name was not applied.")
		quit(1)
		return
	var saved_city: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_manager.get_active_save_path()))
	if not saved_city is Dictionary or str(saved_city.get("game", {}).get("city_name", "")) != "Test Harbor":
		push_error("[NotificationPreferencesSmoke] Guest city name was not persisted locally.")
		quit(1)
		return

	print("[NotificationPreferencesSmoke] PASS")
	quit(0)
