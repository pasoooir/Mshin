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
		# A free example house demonstrates the required road-side placement rule.
		# Its 2x2 footprint touches the starter asphalt road along its north edge.
		var example_house_placed := BuildManager.place_building(Vector2i(0, 1), "residential_1")
		if example_house_placed:
			SaveManager.save_game()
		if status:
			status.text = "Example house placed beside the road. Select Residential to build another; every house needs road access."
