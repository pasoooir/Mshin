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
	var graphics_manager := root.get_node_or_null("GraphicsSettingsManager")
	var account_manager := root.get_node_or_null("account_manager")
	var hud := current_scene.get_node_or_null("HUD")
	var alert_layer := current_scene.get_node_or_null("HUD/BuildingNotificationLayer")
	var citizen_feedback := current_scene.get_node_or_null("CitizenFeedback")
	if game_manager == null or save_manager == null or graphics_manager == null or account_manager == null or hud == null or alert_layer == null or citizen_feedback == null:
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
	var notification_overlay := hud.find_child("NotificationSettingsDialogOverlay", true, false) as Control
	if notification_dialog == null or notification_overlay == null or not notification_overlay.visible or notification_overlay.mouse_filter != Control.MOUSE_FILTER_STOP or building_toggle == null or updates_toggle == null:
		push_error("[NotificationPreferencesSmoke] Notification form did not open as an input-owning HUD modal with both controls.")
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
	var notification_close := notification_overlay.find_child("SettingsDialogClose", true, false) as Button
	if notification_close == null:
		push_error("[NotificationPreferencesSmoke] Notification sub-form has no close action.")
		quit(1)
		return
	notification_close.pressed.emit()
	await process_frame
	if hud.find_child("NotificationSettingsDialogOverlay", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Notification close action did not release modal input.")
		quit(1)
		return

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
	var about_overlay := hud.find_child("SettingsAboutDialogOverlay", true, false) as Control
	if about_dialog == null or about_overlay == null or not about_overlay.visible or graphics_select == null or master_slider == null:
		push_error("[NotificationPreferencesSmoke] About form is missing its functional controls or HUD-owned modal.")
		quit(1)
		return
	var quality_names: PackedStringArray = graphics_manager.get_quality_names()
	var current_quality_index := quality_names.find(str(graphics_manager.quality))
	var next_quality_index := (current_quality_index + 1) % quality_names.size()
	graphics_select.item_selected.emit(next_quality_index)
	master_slider.value_changed.emit(35.0)
	await create_timer(0.8).timeout
	var audio_graphics_state: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_manager.get_active_save_path()))
	var saved_audio: Dictionary = audio_graphics_state.get("preferences", {}).get("audio", {}) if audio_graphics_state is Dictionary else {}
	var saved_graphics: Dictionary = audio_graphics_state.get("preferences", {}).get("graphics", {}) if audio_graphics_state is Dictionary else {}
	if absf(float(saved_audio.get("master_volume", -1.0)) - 0.35) > 0.01:
		push_error("[NotificationPreferencesSmoke] Master volume slider did not persist to player JSON.")
		quit(1)
		return
	if str(saved_graphics.get("quality", "")) != quality_names[next_quality_index]:
		push_error("[NotificationPreferencesSmoke] Graphics quality selection did not persist to player JSON.")
		quit(1)
		return
	var about_close := about_overlay.find_child("SettingsDialogClose", true, false) as Button
	if about_close == null:
		push_error("[NotificationPreferencesSmoke] About sub-form has no close action.")
		quit(1)
		return
	about_close.pressed.emit()
	await process_frame
	if hud.find_child("SettingsAboutDialogOverlay", true, false) != null:
		push_error("[NotificationPreferencesSmoke] About close action did not release modal input.")
		quit(1)
		return

	# Wallet must display current balances without a dead, disabled purchase button.
	var wallet_button := hud.find_child("SettingsWalletButton", true, false) as Button
	if wallet_button == null:
		push_error("[NotificationPreferencesSmoke] Wallet action button is missing.")
		quit(1)
		return
	wallet_button.pressed.emit()
	await process_frame
	var wallet_dialog := hud.find_child("SettingsWalletDialog", true, false) as AcceptDialog
	var wallet_overlay := hud.find_child("SettingsWalletDialogOverlay", true, false) as Control
	if wallet_dialog == null or wallet_overlay == null or not wallet_overlay.visible or hud.find_child("WalletTopUpDisabled", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Wallet action did not open a useful, non-dead HUD modal.")
		quit(1)
		return
	var purchase_info_button := hud.find_child("WalletTopUpInfo", true, false) as Button
	if purchase_info_button == null:
		push_error("[NotificationPreferencesSmoke] Wallet must explain the current purchase availability.")
		quit(1)
		return
	purchase_info_button.pressed.emit()
	await process_frame
	var purchase_info_overlay := hud.find_child("WalletPurchaseInfoDialogOverlay", true, false) as Control
	if purchase_info_overlay == null or not purchase_info_overlay.visible:
		push_error("[NotificationPreferencesSmoke] Wallet purchase information did not open as a usable sub-form.")
		quit(1)
		return
	var purchase_close := purchase_info_overlay.find_child("SettingsDialogClose", true, false) as Button
	if purchase_close == null:
		push_error("[NotificationPreferencesSmoke] Wallet purchase information has no close action.")
		quit(1)
		return
	purchase_close.pressed.emit()
	await process_frame
	if hud.find_child("WalletPurchaseInfoDialogOverlay", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Closing purchase information did not release input.")
		quit(1)
		return
	wallet_dialog.hide()
	wallet_dialog.queue_free()
	await process_frame

	# Guest city registration must be a real, responsive HUD modal with working actions.
	var rename_button := hud.find_child("SettingsChangeCityNameButton", true, false) as Button
	if rename_button == null:
		push_error("[NotificationPreferencesSmoke] Change City Name action button is missing.")
		quit(1)
		return
	rename_button.pressed.emit()
	await process_frame
	var city_dialog := current_scene.find_child("ChangeCityNameDialog", true, false) as Control
	if city_dialog == null or city_dialog.get_parent() != hud:
		push_error("[NotificationPreferencesSmoke] City registration modal must open as a HUD-root layer above Settings.")
		quit(1)
		return
	if hud.settings_overlay.visible:
		push_error("[NotificationPreferencesSmoke] Settings must be suspended while city registration owns input.")
		quit(1)
		return
	var city_form_scroll := city_dialog.find_child("CityNameFormScroll", true, false) as ScrollContainer
	var city_name_input := city_dialog.find_child("CityNameInput", true, false) as LineEdit
	var city_name_save := city_dialog.find_child("CityNameSave", true, false) as Button
	var city_name_cancel := city_dialog.find_child("CityNameCancel", true, false) as Button
	var city_validation := city_dialog.find_child("CityNameValidation", true, false) as Label
	if city_form_scroll == null or city_name_input == null or city_name_save == null or city_name_cancel == null or city_validation == null:
		push_error("[NotificationPreferencesSmoke] City registration must expose a scrollable form, input, validation and working Save/Cancel actions.")
		quit(1)
		return
	if city_form_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or city_form_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		push_error("[NotificationPreferencesSmoke] City registration must scroll vertically without horizontal overflow.")
		quit(1)
		return
	if city_name_input.max_length != 28:
		push_error("[NotificationPreferencesSmoke] City name must enforce its 28-character limit.")
		quit(1)
		return

	var original_city_name := str(game_manager.city_name)
	city_name_input.text = "Discard This Name"
	city_name_cancel.pressed.emit()
	await process_frame
	if current_scene.find_child("ChangeCityNameDialog", true, false) != null or str(game_manager.city_name) != original_city_name:
		push_error("[NotificationPreferencesSmoke] Cancel must close registration without changing the active city.")
		quit(1)
		return
	if not hud.settings_overlay.visible:
		push_error("[NotificationPreferencesSmoke] Cancel must restore the Settings panel.")
		quit(1)
		return

	rename_button.pressed.emit()
	await process_frame
	city_dialog = current_scene.find_child("ChangeCityNameDialog", true, false) as Control
	if city_dialog == null:
		push_error("[NotificationPreferencesSmoke] City registration must reopen after Cancel.")
		quit(1)
		return
	city_name_input = city_dialog.find_child("CityNameInput", true, false) as LineEdit
	city_name_save = city_dialog.find_child("CityNameSave", true, false) as Button
	city_validation = city_dialog.find_child("CityNameValidation", true, false) as Label
	city_name_input.text = ""
	city_name_input.text_changed.emit("")
	if not city_name_save.disabled:
		push_error("[NotificationPreferencesSmoke] Empty city name must disable Save.")
		quit(1)
		return
	city_name_input.text = "   "
	city_name_input.text_changed.emit("   ")
	if not city_name_save.disabled:
		push_error("[NotificationPreferencesSmoke] Whitespace-only city name must disable Save.")
		quit(1)
		return
	city_name_input.text = " Test Harbor "
	city_name_input.text_changed.emit(" Test Harbor ")
	if city_name_save.disabled:
		push_error("[NotificationPreferencesSmoke] Valid city name must enable Save.")
		quit(1)
		return

	var save_events := [0]
	save_manager.save_completed.connect(func(_path: String) -> void: save_events[0] += 1, CONNECT_ONE_SHOT)
	city_name_save.pressed.emit()
	await process_frame
	await process_frame
	if str(game_manager.city_name) != "Test Harbor":
		push_error("[NotificationPreferencesSmoke] Guest city name was not applied and trimmed.")
		quit(1)
		return
	if save_events[0] != 1:
		push_error("[NotificationPreferencesSmoke] Save City must trigger one successful local JSON save event.")
		quit(1)
		return
	var saved_city: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_manager.get_active_save_path()))
	if not saved_city is Dictionary or str(saved_city.get("game", {}).get("city_name", "")) != "Test Harbor":
		push_error("[NotificationPreferencesSmoke] City name was not persisted in the active player JSON.")
		quit(1)
		return
	if current_scene.find_child("ChangeCityNameDialog", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Successful city registration must close the modal.")
		quit(1)
		return
	if not hud.settings_overlay.visible:
		push_error("[NotificationPreferencesSmoke] Successful registration must restore the Settings panel.")
		quit(1)
		return

	rename_button.pressed.emit()
	await process_frame
	city_dialog = current_scene.find_child("ChangeCityNameDialog", true, false) as Control
	city_name_input = city_dialog.find_child("CityNameInput", true, false) as LineEdit
	if city_name_input.text != "Test Harbor":
		push_error("[NotificationPreferencesSmoke] Reopening city registration must load the saved city name.")
		quit(1)
		return
	city_dialog.find_child("CityNameCancel", true, false).pressed.emit()
	await process_frame

	# Help must reopen the interactive tutorial instead of doing nothing.
	var help_button := hud.find_child("SettingsHelpButton", true, false) as Button
	var guide := current_scene.get_node_or_null("TutorialGuide")
	if help_button == null or guide == null or not guide.has_method("open_help"):
		push_error("[NotificationPreferencesSmoke] Help action or tutorial guide is missing.")
		quit(1)
		return
	hud._show_settings_panel()
	await process_frame
	help_button = hud.find_child("SettingsHelpButton", true, false) as Button
	help_button.pressed.emit()
	await process_frame
	var guide_panel := guide.get("_panel") as Control
	if guide_panel == null or not guide_panel.visible:
		push_error("[NotificationPreferencesSmoke] Help button did not reopen the tutorial guide.")
		quit(1)
		return
	guide_panel.hide()

	# Google profile claims are display-only metadata. The avatar is shown in a
	# large circular frame at the upper-left of Settings after authentication.
	var fake_claims := {"name": "Mshin Mayor", "email": "mayor@example.test", "picture": "https://images.example.test/mshin-avatar.jpg"}
	var encoded_claims := Marshalls.utf8_to_base64(JSON.stringify(fake_claims)).replace("+", "-").replace("/", "_").trim_suffix("=")
	account_manager._update_google_identity_from_token("header." + encoded_claims + ".signature")
	if account_manager.google_display_name != "Mshin Mayor" or account_manager.google_avatar_url != "https://images.example.test/mshin-avatar.jpg":
		push_error("[NotificationPreferencesSmoke] Google ID token profile claims were not decoded for display.")
		quit(1)
		return
	account_manager.google_avatar_url = ""
	account_manager.player_id = 987654
	account_manager.access_token = "smoke-test-token"
	hud._show_settings_panel()
	await process_frame
	var avatar_frame := hud.find_child("SettingsProfileAvatarFrame", true, false) as Control
	var avatar_texture := hud.find_child("SettingsProfileAvatar", true, false) as TextureRect
	if avatar_frame == null or not avatar_frame.visible or avatar_frame.custom_minimum_size.x < 70.0 or avatar_texture == null:
		push_error("[NotificationPreferencesSmoke] Authenticated Settings must show the circular Gmail profile avatar in its header.")
		quit(1)
		return
	account_manager.player_id = 0
	account_manager.access_token = ""
	account_manager.google_avatar_url = ""
	account_manager.google_display_name = ""
	hud._close_settings_panel()

	print("[NotificationPreferencesSmoke] PASS")
	quit(0)
