extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var account = root.get_node_or_null("PlayerAccountManager")
	var save_manager = root.get_node_or_null("SaveManager")
	var audio = root.get_node_or_null("AudioManager")
	var haptics = root.get_node_or_null("HapticsManager")
	var graphics = root.get_node_or_null("GraphicsSettingsManager")
	if account == null or save_manager == null or audio == null or haptics == null or graphics == null:
		push_error("[PlayerAccountSmoke] Required autoload is missing.")
		quit(1)
		return
	account._activate_session({"user_id": 100001, "access_token": "test-token-a"}, "admin")
	var path_a: String = save_manager.get_active_save_path()
	if str(audio.get("settings_path")) != "user://players/100001/audio_settings.cfg" or str(haptics.get("settings_path")) != "user://players/100001/haptics_settings.cfg" or str(graphics.get("settings_path")) != "user://players/100001/graphics_settings.cfg":
		push_error("[PlayerAccountSmoke] Player A preferences are not account-scoped.")
		quit(1)
		return
	if path_a != "user://players/100001/pasoo_city_buildit_save.json":
		push_error("[PlayerAccountSmoke] Player A save path is not isolated: " + path_a)
		quit(1)
		return
	account._activate_session({"user_id": 100002, "access_token": "test-token-b"}, "player2")
	var path_b: String = save_manager.get_active_save_path()
	if str(audio.get("settings_path")) != "user://players/100002/audio_settings.cfg" or str(haptics.get("settings_path")) != "user://players/100002/haptics_settings.cfg" or str(graphics.get("settings_path")) != "user://players/100002/graphics_settings.cfg":
		push_error("[PlayerAccountSmoke] Player B preferences reused another account.")
		quit(1)
		return
	if path_b != "user://players/100002/pasoo_city_buildit_save.json" or path_a == path_b:
		push_error("[PlayerAccountSmoke] Player B reused Player A save path.")
		quit(1)
		return
	await account.logout()
	if str(audio.get("settings_path")) != "user://audio_settings.cfg" or str(haptics.get("settings_path")) != "user://haptics_settings.cfg" or str(graphics.get("settings_path")) != "user://graphics_settings.cfg":
		push_error("[PlayerAccountSmoke] Guest preference paths did not reset.")
		quit(1)
		return
	if save_manager.get_active_save_path() != "user://pasoo_city_buildit_save.json":
		push_error("[PlayerAccountSmoke] Guest fallback path changed unexpectedly.")
		quit(1)
		return
	print("[PlayerAccountSmoke] PASS")
	quit(0)
