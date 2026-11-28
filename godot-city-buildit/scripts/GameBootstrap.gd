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
	var city_restore_failed := had_saved_city and not city_restored
	if city_restore_failed:
		push_error("[GameBootstrap] Saved city restoration failed. The JSON save was not overwritten; inspect the preceding SaveManager/BuildManager error for the exact road or building that could not be restored.")
		if status:
			status.text = SaveManager.last_restore_error if not SaveManager.last_restore_error.is_empty() else "City restore failed. Saved city data is preserved."
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
	if status and not city_restore_failed and not account_ready and not tutorial_is_active:
		status.text = "Your city is ready. Select Residential and place your first house beside a road."
	call_deferred("_show_world_render_diagnostics")


func _show_world_render_diagnostics() -> void:
	var world := get_node_or_null("World")
	var presentation := world.get_node_or_null("WorldPresentation") if world != null else null
	var terrain := presentation.get_node_or_null("NaturalTerrain") as MeshInstance3D if presentation != null else null
	var terrain_surfaces := terrain.mesh.get_surface_count() if is_instance_valid(terrain) and terrain.mesh != null else 0
	var world_mesh_count := 0
	var visible_mesh_count := 0
	if world != null:
		for node in world.find_children("*", "MeshInstance3D", true, false):
			world_mesh_count += 1
			var mesh_node := node as MeshInstance3D
			if mesh_node.is_visible_in_tree() and mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
				visible_mesh_count += 1
	var building_count := 0
	for building in BuildManager.buildings.values():
		if is_instance_valid(building):
			building_count += 1
	var road_count := 0
	var road_system := world.get_node_or_null("RoadSystem") if world != null else null
	if road_system != null and road_system.get("roads") is Dictionary:
		road_count = road_system.roads.size()
	var camera_rig := get_node_or_null("CameraRig") as Node3D
	var camera := camera_rig.get_node_or_null("Camera3D") as Camera3D if camera_rig != null else null
	var camera_info := "missing"
	if camera_rig != null and camera != null:
		camera_info = "rig=(%.1f,%.1f,%.1f) rotation=(%.1f,%.1f,%.1f) current=%s mask=%d" % [camera_rig.global_position.x, camera_rig.global_position.y, camera_rig.global_position.z, camera_rig.rotation_degrees.x, camera_rig.rotation_degrees.y, camera_rig.rotation_degrees.z, str(camera.current), camera.cull_mask]
	var terrain_state := "missing"
	if is_instance_valid(terrain):
		terrain_state = "visible=%s surfaces=%d mesh=%s" % [str(terrain.is_visible_in_tree()), terrain_surfaces, terrain.mesh.get_class() if terrain.mesh != null else "null"]
	var diagnostic := "[WorldRender] terrain=%s; world_meshes=%d visible_meshes=%d; buildings=%d roads=%d; camera=%s" % [terrain_state, world_mesh_count, visible_mesh_count, building_count, road_count, camera_info]
	print(diagnostic)
	var status := get_node_or_null("HUD/StatusLabel")
	if status != null:
		status.text = diagnostic
