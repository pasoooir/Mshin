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

	var hud := current_scene.get_node_or_null("HUD")
	var alert_layer := current_scene.get_node_or_null("HUD/BuildingNotificationLayer")
	var citizen_feedback := current_scene.get_node_or_null("CitizenFeedback")
	if hud == null or alert_layer == null or citizen_feedback == null:
		push_error("[NotificationPreferencesSmoke] Settings notification components are missing.")
		quit(1)
		return
	if alert_layer.are_building_alerts_enabled() or citizen_feedback.are_city_updates_enabled():
		push_error("[NotificationPreferencesSmoke] Saved disabled preferences were not restored.")
		quit(1)
		return

	hud._apply_notification_preference("building_alerts", true)
	hud._apply_notification_preference("city_updates", true)
	if not alert_layer.are_building_alerts_enabled() or not citizen_feedback.are_city_updates_enabled():
		push_error("[NotificationPreferencesSmoke] Enabling preferences did not update live systems.")
		quit(1)
		return

	hud._apply_notification_preference("building_alerts", false)
	hud._apply_notification_preference("city_updates", false)
	if alert_layer.are_building_alerts_enabled() or citizen_feedback.are_city_updates_enabled():
		push_error("[NotificationPreferencesSmoke] Disabling preferences did not update live systems.")
		quit(1)
		return

	print("[NotificationPreferencesSmoke] PASS")
	quit(0)
