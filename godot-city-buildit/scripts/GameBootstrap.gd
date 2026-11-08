extends Node3D

func _ready() -> void:
	call_deferred("_restore_city")

func _restore_city() -> void:
	var status = get_node_or_null("HUD/StatusLabel")
	SaveManager.load_game()
	var road_system = get_node_or_null("World/RoadSystem")

	# Keep the free starter road access, but never place a sample house.
	if road_system and road_system.roads.is_empty():
		road_system.seed_starter_access()

	# Remove the old automatically-generated sample house from existing saves.
	# The previous bootstrap always tried (0, 1) first on a fresh starter road.
	var old_sample := BuildManager.building_at_cell(Vector2i(0, 1))
	var removed_old_sample := false
	if is_instance_valid(old_sample) and old_sample.building_type == "residential_1" and old_sample.grid_pos == Vector2i(0, 1):
		BuildManager.unregister_building(old_sample.building_id)
		old_sample.queue_free()
		removed_old_sample = true

	if removed_old_sample:
		SaveManager.save_game()

	if status:
		status.text = "Your city is ready. Select Residential and place your first house beside a road."
