extends Node3D

func _ready() -> void:
	call_deferred("_restore_city")

func _restore_city() -> void:
	var status = get_node_or_null("HUD/StatusLabel")
	var account_ready: bool = await PlayerAccountManager.bootstrap()
	if account_ready and PlayerAccountManager.is_authenticated() and status:
		status.text = "Welcome back, Mayor #%d" % PlayerAccountManager.player_id
	var had_saved_city := FileAccess.file_exists(SaveManager.get_active_save_path())
	var city_restored := SaveManager.load_game()
	if had_saved_city and not city_restored:
		push_error("[GameBootstrap] Saved city restoration failed. The JSON save was not overwritten; inspect the preceding SaveManager/BuildManager error for the exact road or building that could not be restored.")
		if status:
			status.text = "City restore failed — saved city data is preserved. Please retry after the restore issue is fixed."
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

	SaveManager.persistence_ready = true
	var tutorial_guide = get_tree().current_scene.get_node_or_null("TutorialGuide") if get_tree().current_scene else null
	var tutorial_is_active := is_instance_valid(tutorial_guide) and bool(tutorial_guide.get("tutorial_enabled")) and not bool(tutorial_guide.get("completed"))
	if status and not account_ready and not tutorial_is_active:
		status.text = "Your city is ready. Select Residential and place your first house beside a road."
