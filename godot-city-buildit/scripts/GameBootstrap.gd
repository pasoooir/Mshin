extends Node3D

func _ready() -> void:
	call_deferred("_restore_city")

func _restore_city() -> void:
	var status = get_node_or_null("HUD/StatusLabel")
	if SaveManager.load_game():
		if status:
			status.text = "Saved city restored. Your city will autosave every 30 seconds."
	else:
		var road_system = get_node_or_null("World/RoadSystem")
		if road_system:
			road_system.seed_starter_access()
		if status:
			status.text = "Welcome to your coastal city. Start with a house beside the highway connector."
