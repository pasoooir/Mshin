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
	if not save_manager.set_notification_preference("building_alerts", true) or not save_manager.set_notification_preference("city_updates", true):
		push_error("[NotificationPreferencesSmoke] Could not persist notification preferences.")
		quit(1)
		return
	if not alert_layer.are_building_alerts_enabled() or not citizen_feedback.are_city_updates_enabled():
		push_error("[NotificationPreferencesSmoke] Enabling preferences did not update live systems.")
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


	# Guest players can change the city name and persist it locally without a Google login.
	hud._show_change_city_name()
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
