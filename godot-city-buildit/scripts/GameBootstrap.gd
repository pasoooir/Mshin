extends Node3D

func _ready() -> void:
	call_deferred("_restore_city")

func _restore_city() -> void:
	var status = get_node_or_null("HUD/StatusLabel")
	var restored := SaveManager.load_game()
	var road_system = get_node_or_null("World/RoadSystem")
	# Older browser saves may exist but contain no roads. Recover those empty worlds too.
	if road_system and road_system.roads.is_empty():
		road_system.seed_starter_access()
	if restored:
		if status:
			status.text = "Saved city restored. Your city will autosave every 30 seconds."
	else:
		if status:
			status.text = "Welcome to your coastal city. Start with a house beside the highway connector."
