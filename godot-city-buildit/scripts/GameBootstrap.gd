extends Node3D

func _ready() -> void:
	call_deferred("_restore_city")

func _restore_city() -> void:
	var status = get_node_or_null("HUD/StatusLabel")
	var restored := SaveManager.load_game()
	var road_system = get_node_or_null("World/RoadSystem")

	# Recover old/empty browser saves before ensuring the starter example exists.
	if road_system and road_system.roads.is_empty():
		road_system.seed_starter_access()

	# Do not gate the example house on load_game() returning false:
	# older saves can be valid while containing roads but zero buildings.
	var has_residential := false
	for building in BuildManager.buildings.values():
		if is_instance_valid(building) and str(building.building_type).begins_with("residential"):
			has_residential = true
			break

	var example_house_placed := false
	if not has_residential and road_system and not road_system.roads.is_empty():
		var candidate_anchors: Array[Vector2i] = []
		for road_cell_variant in road_system.roads.keys():
			var road_cell: Vector2i = road_cell_variant
			candidate_anchors.append(road_cell + Vector2i(0, 1))
			candidate_anchors.append(road_cell + Vector2i(0, -2))
			candidate_anchors.append(road_cell + Vector2i(1, 0))
			candidate_anchors.append(road_cell + Vector2i(-2, 0))

		for anchor in candidate_anchors:
			if BuildManager.can_place_at(anchor, "residential_1"):
				example_house_placed = BuildManager.place_building(anchor, "residential_1")
				if example_house_placed:
					break

	if example_house_placed:
		SaveManager.save_game()

	if status:
		if example_house_placed:
			status.text = "A free example house is beside the road. Select Residential to build another."
		elif has_residential:
			status.text = "City restored. Select Residential to build another house beside a road."
		elif restored:
			status.text = "City restored. Build a road-connected plot to place your first house."
		else:
			status.text = "Welcome! Select Residential and place your first house beside the road."
