extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _tap_control(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await process_frame
			break
		ancestor = ancestor.get_parent()
	var viewport := control.get_viewport()
	var pointer_position := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pointer_position
	press.pressed = true
	viewport.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = pointer_position
	release.pressed = false
	viewport.push_input(release, true)
	await process_frame

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
	var audio_manager := root.get_node_or_null("AudioManager")
	var account_manager := root.get_node_or_null("PlayerAccountManager")
	var hud := current_scene.get_node_or_null("HUD")
	var alert_layer := current_scene.get_node_or_null("HUD/BuildingNotificationLayer")
	var citizen_feedback := current_scene.get_node_or_null("CitizenFeedback")
	if game_manager == null or save_manager == null or graphics_manager == null or audio_manager == null or account_manager == null or hud == null or alert_layer == null or citizen_feedback == null:
		push_error("[NotificationPreferencesSmoke] Settings notification components are missing.")
		quit(1)
		return
	if alert_layer.are_building_alerts_enabled() or citizen_feedback.are_city_updates_enabled():
		push_error("[NotificationPreferencesSmoke] Saved disabled preferences were not restored.")
		quit(1)
		return

	save_manager.persistence_ready = true
	save_manager.is_loading = false
	var settings_action := hud.find_child("SettingsAction", true, false) as Button
	if settings_action == null:
		push_error("[NotificationPreferencesSmoke] Main Settings gear action is missing.")
		quit(1)
		return
	await _tap_control(settings_action)
	await process_frame
	if hud.settings_overlay == null or not hud.settings_overlay.visible:
		push_error("[NotificationPreferencesSmoke] Tapping the main Settings gear did not open the Settings panel.")
		quit(1)
		return
	var google_action := hud.find_child("SettingsGoogleAccountAction", true, false) as Button
	if google_action == null:
		push_error("[NotificationPreferencesSmoke] Google sign-in action is missing.")
		quit(1)
		return
	var gmail_button_content := google_action.get_node_or_null("GmailButtonContent") as Control
	var gmail_icon := google_action.find_child("GmailIcon", true, false) as TextureRect
	if gmail_button_content == null or not gmail_button_content.visible or gmail_icon == null or gmail_icon.texture == null or gmail_icon.custom_minimum_size.x < 40.0:
		push_error("[NotificationPreferencesSmoke] Guest sign-in button must show a large, visible Gmail icon beside the Google action.")
		quit(1)
		return
	await _tap_control(google_action)
	if google_action.disabled or not str(hud.find_child("SettingsAccountStatus", true, false).text).contains("web version"):
		push_error("[NotificationPreferencesSmoke] Google sign-in button did not return a useful platform-specific result.")
		quit(1)
		return
	var cancel_nonce := "smoke-google-cancel-nonce-0123456789abcdef"
	account_manager._google_pending_nonces[cancel_nonce] = false
	google_action.disabled = true
	await account_manager._complete_google_sign_in("", cancel_nonce)
	await process_frame
	if google_action.disabled or account_manager._google_pending_nonces.has(cancel_nonce) or not str(hud.find_child("SettingsAccountStatus", true, false).text).contains("cancelled"):
		push_error("[NotificationPreferencesSmoke] A cancelled Google prompt must release the sign-in button and clear its one-time pending nonce.")
		quit(1)
		return
	var original_music_enabled := bool(audio_manager.music_enabled)
	var original_sfx_enabled := bool(audio_manager.sfx_enabled)
	var music_toggle := hud.find_child("MusicToggle", true, false) as Button
	var sfx_toggle := hud.find_child("SfxToggle", true, false) as Button
	if music_toggle == null or sfx_toggle == null:
		push_error("[NotificationPreferencesSmoke] Music and sound switches are missing.")
		quit(1)
		return
	await _tap_control(music_toggle)
	await _tap_control(sfx_toggle)
	await create_timer(0.8).timeout
	var saved_toggle_state: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_manager.get_active_save_path()))
	var saved_toggle_audio: Dictionary = saved_toggle_state.get("preferences", {}).get("audio", {}) if saved_toggle_state is Dictionary else {}
	if bool(saved_toggle_audio.get("music_enabled", original_music_enabled)) != (not original_music_enabled) or bool(saved_toggle_audio.get("sfx_enabled", original_sfx_enabled)) != (not original_sfx_enabled):
		push_error("[NotificationPreferencesSmoke] Music and sound switches did not persist to the player JSON.")
		quit(1)
		return
	await _tap_control(music_toggle)
	await _tap_control(sfx_toggle)
	await create_timer(0.8).timeout
	var notification_button := hud.find_child("SettingsNotificationsButton", true, false) as Button
	if notification_button == null:
		push_error("[NotificationPreferencesSmoke] Notification Settings action button is missing.")
		quit(1)
		return
	await _tap_control(notification_button)
	await process_frame
	var notification_dialog := hud.find_child("NotificationSettingsDialog", true, false) as AcceptDialog
	var building_toggle := hud.find_child("BuildingAlertsToggle", true, false) as CheckButton
	var updates_toggle := hud.find_child("CityUpdatesToggle", true, false) as CheckButton
	var notification_overlay := hud.find_child("NotificationSettingsDialogOverlay", true, false) as Control
	if notification_dialog == null or notification_overlay == null or not notification_overlay.visible or notification_overlay.mouse_filter != Control.MOUSE_FILTER_STOP or building_toggle == null or updates_toggle == null:
		push_error("[NotificationPreferencesSmoke] Notification form did not open as an input-owning HUD modal with both controls.")
		quit(1)
		return
	await _tap_control(building_toggle)
	await _tap_control(updates_toggle)
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
	await _tap_control(notification_close)
	await process_frame
	if hud.find_child("NotificationSettingsDialogOverlay", true, false) != null or hud.find_child("NotificationSettingsDialog", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Notification close action did not release both modal layers.")
		quit(1)
		return
	# The native Window close request (Escape / platform close) must release
	# the visible HUD overlay through the same synchronous cleanup path.
	notification_button = hud.find_child("SettingsNotificationsButton", true, false) as Button
	await _tap_control(notification_button)
	await process_frame
	notification_dialog = hud.find_child("NotificationSettingsDialog", true, false) as AcceptDialog
	if notification_dialog == null:
		push_error("[NotificationPreferencesSmoke] Notification form could not reopen after closing.")
		quit(1)
		return
	notification_dialog.close_requested.emit()
	await process_frame
	if hud.find_child("NotificationSettingsDialogOverlay", true, false) != null or hud.find_child("NotificationSettingsDialog", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Platform close request left a stale notification input layer.")
		quit(1)
		return

	# The About form exposes real graphics and audio controls, not decorative placeholders.
	var about_button := hud.find_child("SettingsAboutButton", true, false) as Button
	if about_button == null:
		push_error("[NotificationPreferencesSmoke] About action button is missing.")
		quit(1)
		return
	await _tap_control(about_button)
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
	await _tap_control(about_close)
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
	await _tap_control(wallet_button)
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
	await _tap_control(purchase_info_button)
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
	await _tap_control(purchase_close)
	await process_frame
	if hud.find_child("WalletPurchaseInfoDialogOverlay", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Closing purchase information did not release input.")
		quit(1)
		return
	var wallet_close := wallet_overlay.find_child("SettingsDialogClose", true, false) as Button
	if wallet_close == null:
		push_error("[NotificationPreferencesSmoke] Wallet sub-form has no close action.")
		quit(1)
		return
	await _tap_control(wallet_close)
	await process_frame
	if hud.find_child("SettingsWalletDialogOverlay", true, false) != null or hud.find_child("SettingsWalletDialog", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Wallet close action did not release both modal layers.")
		quit(1)
		return
	# Reopening Settings while a sub-form is still open must not leave any
	# transparent modal overlay above the game.
	wallet_button = hud.find_child("SettingsWalletButton", true, false) as Button
	await _tap_control(wallet_button)
	await process_frame
	hud._show_settings_panel()
	await process_frame
	if hud.find_child("SettingsWalletDialogOverlay", true, false) != null or hud.find_child("SettingsWalletDialog", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Reopening Settings left a stale wallet modal or input overlay.")
		quit(1)
		return

	# City registration is locked for guests and becomes available only after Google authentication.
	var rename_button := hud.find_child("SettingsChangeCityNameButton", true, false) as Button
	if rename_button == null:
		push_error("[NotificationPreferencesSmoke] Change City Name action button is missing.")
		quit(1)
		return
	if not rename_button.disabled:
		push_error("[NotificationPreferencesSmoke] City registration must remain locked until Google sign-in succeeds.")
		quit(1)
		return
	await _tap_control(rename_button)
	await process_frame
	if current_scene.find_child("ChangeCityNameDialog", true, false) != null:
		push_error("[NotificationPreferencesSmoke] Guest users must not be able to open city registration.")
		quit(1)
		return

	# Simulate the authenticated session boundary; the real Google-token path is
	# covered independently by the signed OIDC Worker integration test.
	account_manager.player_id = 987654
	account_manager.access_token = "smoke-test-token"
	account_manager.google_display_name = "Smoke Mayor"
	account_manager.google_avatar_url = ""
	hud._refresh_settings_account_section()
	rename_button = hud.find_child("SettingsChangeCityNameButton", true, false) as Button
	if rename_button == null or rename_button.disabled:
		push_error("[NotificationPreferencesSmoke] Google-authenticated players must be able to register their city.")
		quit(1)
		return
	await _tap_control(rename_button)
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
	await _tap_control(city_name_cancel)
	await process_frame
	if current_scene.find_child("ChangeCityNameDialog", true, false) != null or str(game_manager.city_name) != original_city_name:
		push_error("[NotificationPreferencesSmoke] Cancel must close registration without changing the active city.")
		quit(1)
		return
	if not hud.settings_overlay.visible:
		push_error("[NotificationPreferencesSmoke] Cancel must restore the Settings panel.")
		quit(1)
		return

	await _tap_control(rename_button)
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

	# Force the offline branch for this UI smoke. The account-scoped local JSON
	# write is asserted here; the online profile contract is tested by Worker tests.
	var original_api_base := str(ProjectSettings.get_setting("mshin/account/api_base_url", ""))
	ProjectSettings.set_setting("mshin/account/api_base_url", "")
	var save_events := [0]
	save_manager.save_completed.connect(func(_path: String) -> void: save_events[0] += 1, CONNECT_ONE_SHOT)
	await _tap_control(city_name_save)
	await process_frame
	await process_frame
	ProjectSettings.set_setting("mshin/account/api_base_url", original_api_base)
	if str(game_manager.city_name) != "Test Harbor":
		push_error("[NotificationPreferencesSmoke] Authenticated city name was not applied and trimmed.")
		quit(1)
		return
	if save_events[0] != 1:
		push_error("[NotificationPreferencesSmoke] Save City must trigger one successful local JSON save event.")
		quit(1)
		return
	if save_manager.get_active_save_path() != "user://players/987654/pasoo_city_buildit_save.json":
		push_error("[NotificationPreferencesSmoke] Registered city must save under the authenticated numeric player ID.")
		quit(1)
		return
	var saved_city: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_manager.get_active_save_path()))
	if not saved_city is Dictionary or str(saved_city.get("game", {}).get("city_name", "")) != "Test Harbor":
		push_error("[NotificationPreferencesSmoke] City name was not persisted in the authenticated player's local JSON.")
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

	await _tap_control(rename_button)
	await process_frame
	city_dialog = current_scene.find_child("ChangeCityNameDialog", true, false) as Control
	city_name_input = city_dialog.find_child("CityNameInput", true, false) as LineEdit
	if city_name_input.text != "Test Harbor":
		push_error("[NotificationPreferencesSmoke] Reopening city registration must load the saved city name.")
		quit(1)
		return
	await _tap_control(city_dialog.find_child("CityNameCancel", true, false) as Control)
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
	await _tap_control(help_button)
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
	var settings_heading := hud.find_child("SettingsHeading", true, false) as HBoxContainer
	var settings_title := hud.find_child("SettingsTitle", true, false) as Label
	if avatar_frame == null or not avatar_frame.visible or avatar_frame.custom_minimum_size.x < 70.0 or avatar_texture == null or settings_heading == null or settings_title == null or avatar_frame.get_parent() != settings_heading or avatar_frame.get_index() >= settings_title.get_index():
		push_error("[NotificationPreferencesSmoke] Authenticated Settings must show the large circular Gmail avatar at the upper-left of its header.")
		quit(1)
		return
	google_action = hud.find_child("SettingsGoogleAccountAction", true, false) as Button
	var original_signout_api_base := str(ProjectSettings.get_setting("mshin/account/api_base_url", ""))
	var original_signout_persistence_ready: bool = bool(save_manager.get("persistence_ready"))
	ProjectSettings.set_setting("mshin/account/api_base_url", "")
	save_manager.persistence_ready = true
	await _tap_control(google_action)
	await process_frame
	if not account_manager.is_authenticated() or not avatar_frame.visible:
		push_error("[NotificationPreferencesSmoke] Sign-out must keep the session active when its final cloud save fails.")
		quit(1)
		return
	save_manager.persistence_ready = false
	await _tap_control(google_action)
	await process_frame
	save_manager.persistence_ready = original_signout_persistence_ready
	ProjectSettings.set_setting("mshin/account/api_base_url", original_signout_api_base)
	if not account_manager.is_authenticated() or not avatar_frame.visible:
		push_error("[NotificationPreferencesSmoke] Sign-out must be blocked while the local save system is not ready.")
		quit(1)
		return
	account_manager._clear_session_state()
	if save_manager.persistence_ready:
		save_manager.load_game()

	# Exercise the actual image-decoding callback without relying on Google's
	# live CDN: valid image bytes must replace the placeholder; invalid bytes
	# must release the URL guard so a later retry can succeed.
	account_manager.player_id = 987654
	account_manager.access_token = "smoke-test-token"
	account_manager.google_avatar_url = "https://images.example.test/mshin-avatar.png"
	hud._settings_avatar_request_url = account_manager.google_avatar_url
	hud._show_settings_panel()
	await process_frame
	avatar_frame = hud.find_child("SettingsProfileAvatarFrame", true, false) as Control
	avatar_texture = hud.find_child("SettingsProfileAvatar", true, false) as TextureRect
	var placeholder := hud.find_child("SettingsProfileAvatarFallback", true, false) as Label
	var generated_avatar := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	generated_avatar.fill(Color("#5BD7F7"))
	var avatar_bytes := generated_avatar.save_png_to_buffer()
	var invalid_request := HTTPRequest.new()
	hud.add_child(invalid_request)
	hud._settings_avatar_request_url = account_manager.google_avatar_url
	hud._on_settings_profile_avatar_downloaded(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray([1, 2, 3]), invalid_request, account_manager.google_avatar_url)
	if hud._settings_avatar_request_url != "" or avatar_texture.texture != null or not placeholder.visible:
		push_error("[NotificationPreferencesSmoke] Invalid avatar data must preserve the fallback and allow retry.")
		quit(1)
		return
	var valid_request := HTTPRequest.new()
	hud.add_child(valid_request)
	hud._settings_avatar_request_url = account_manager.google_avatar_url
	hud._on_settings_profile_avatar_downloaded(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), avatar_bytes, valid_request, account_manager.google_avatar_url)
	if avatar_texture.texture == null or placeholder.visible or not avatar_frame.visible:
		push_error("[NotificationPreferencesSmoke] Valid avatar image bytes did not replace the profile placeholder.")
		quit(1)
		return
	var oversized_image := Image.create(1025, 2, false, Image.FORMAT_RGBA8)
	oversized_image.fill(Color.WHITE)
	var oversized_request := HTTPRequest.new()
	hud.add_child(oversized_request)
	hud._settings_avatar_request_url = account_manager.google_avatar_url
	hud._on_settings_profile_avatar_downloaded(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), oversized_image.save_png_to_buffer(), oversized_request, account_manager.google_avatar_url)
	if hud._settings_avatar_request_url != "" or avatar_texture.texture != null or not placeholder.visible:
		push_error("[NotificationPreferencesSmoke] Oversized avatar images must be rejected safely.")
		quit(1)
		return
	account_manager._clear_session_state()
	if save_manager.persistence_ready:
		save_manager.load_game()

	var settings_close := hud.find_child("SettingsClose", true, false) as Button
	if settings_close == null:
		push_error("[NotificationPreferencesSmoke] Settings panel has no close action.")
		quit(1)
		return
	await _tap_control(settings_close)
	await process_frame
	if hud.settings_overlay != null:
		push_error("[NotificationPreferencesSmoke] Settings close action did not close the panel.")
		quit(1)
		return

	print("[NotificationPreferencesSmoke] PASS")
	quit(0)
