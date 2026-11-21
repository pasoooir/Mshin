extends Node

const WorldPresentationScript = preload("res://scripts/world/WorldPresentation.gd")


func _ready() -> void:
	var presentation := WorldPresentationScript.new()
	add_child(presentation)
	# Coastline regression: water geometry must follow the curved beach edge,
	# and the terrain must taper to the sea datum instead of overlapping it.
	var coast_sample := presentation._coastline(0.0)
	if absf(presentation._terrain_height(coast_sample, 0.0)) > 0.01:
		push_error("[VisualPresentationSmoke] Beach terrain must meet the ocean at the sea datum")
		get_tree().quit(1)
		return
	var ocean_mesh := presentation._create_coastal_water_mesh(8.0, 159.0, 24, 4, -0.055)
	var ocean_bounds := ocean_mesh.get_aabb()
	if ocean_mesh.get_surface_count() != 1 or ocean_bounds.position.x < 45.0 or ocean_bounds.end.x < 158.9:
		push_error("[VisualPresentationSmoke] Deep water must be a continuous coastline-following mesh extending offshore")
		get_tree().quit(1)
		return
	var shallow_mesh := presentation._create_coastal_water_mesh(0.12, 8.0, 24, 4, -0.025)
	if shallow_mesh.get_aabb().position.x < 45.0 or shallow_mesh.get_aabb().size.x > 16.0:
		push_error("[VisualPresentationSmoke] Shallow water must remain a narrow continuous band immediately offshore")
		get_tree().quit(1)
		return
	var world_source := FileAccess.get_file_as_string("res://scripts/world/WorldPresentation.gd")
	if world_source.count("_is_city_road_footprint(x, z)") < 6:
		push_error("[VisualPresentationSmoke] Grass, shrubs and loose field stones must all exclude occupied asphalt tiles")
		get_tree().quit(1)
		return
	if presentation.get_node_or_null("DistantMountainBackdrop") != null:
		push_error("[VisualPresentationSmoke] The starter coastal city must not spawn any mountain backdrop")
		get_tree().quit(1)
		return
	if world_source.contains("DistantMountainBackdrop") or world_source.contains("_build_near_city_rock_outcrops"):
		push_error("[VisualPresentationSmoke] Mountain and near-city rock generation must be fully removed from the world presentation")
		get_tree().quit(1)
		return
	var world_visual_source := FileAccess.get_file_as_string("res://scripts/world/WorldPresentation.gd")
	for required_coastal_feature in [
		"const COASTLINE_BASE_X := 110.0",
		"const BEACH_WIDTH := 36.0",
		"func _build_coastal_promenade(",
		"func _build_beach_palms(",
		"func _create_palm_frond_mesh(",
		"PacificCoastalPromenade",
		"PacificPalmTrunks",
		"PacificPalmCrowns",
		"COASTAL_GREEN_PALETTE",
		"_build_coastal_promenade()",
		"_build_beach_palms()"
	]:
		if not world_visual_source.contains(required_coastal_feature):
			push_error("[VisualPresentationSmoke] Los Angeles coastal world is missing: " + required_coastal_feature)
			get_tree().quit(1)
			return
	if presentation._coastline(0.0) < 108.0 or presentation._coastline(0.0) > 112.0:
		push_error("[VisualPresentationSmoke] Pacific shoreline must sit beyond the full starter city footprint")
		get_tree().quit(1)
		return
	var palm_mesh: ArrayMesh = presentation._create_palm_frond_mesh()
	if palm_mesh == null or palm_mesh.get_surface_count() != 1 or palm_mesh.get_aabb().size.x < 5.0 or palm_mesh.get_aabb().size.z < 5.0:
		push_error("[VisualPresentationSmoke] Palm crown must be a single broad radial frond mesh")
		get_tree().quit(1)
		return
	for required_visual_feature in [
		"func _terrain_height(",
		"func _build_dirt_tracks(",
		"func _build_creek_channel(",
		"func _build_creek_rock_edges(",
		"func _build_meadow_shrubs_and_stones(",
		"func _create_meadow_shrub_mesh(",
		"func _create_meadow_grass_clump_mesh(",
		"AustralianMeadowScrub",
		"MeadowFieldstoneBatch",
		"NaturalDirtTracks",
		"ErodedCreekBanksAndBed",
		"MeadowCreekWater"
	]:
		if not world_visual_source.contains(required_visual_feature):
			push_error("[VisualPresentationSmoke] Coastal city ground is missing a required near-camera feature: " + required_visual_feature)
			get_tree().quit(1)
			return
	if not world_visual_source.contains("range(2400)") or not world_visual_source.contains("range(260)") or not world_visual_source.contains("range(220)"):
		push_error("[VisualPresentationSmoke] Near-city grass, scrub and fieldstone density must remain materially higher than the previous sparse edge dressing")
		get_tree().quit(1)
		return
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		push_error("[VisualPresentationSmoke] Main scene must load for far-clip visibility validation")
		get_tree().quit(1)
		return
	var main_instance := main_scene.instantiate()
	var city_camera := main_instance.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if city_camera == null:
		push_error("[VisualPresentationSmoke] Main scene must expose its playable city camera")
		main_instance.free()
		get_tree().quit(1)
		return
	if WorldPresentationScript.COASTAL_GREEN_PALETTE.size() < 5 or WorldPresentationScript.COASTAL_GREEN_PALETTE[0].g <= WorldPresentationScript.COASTAL_GREEN_PALETTE[0].r:
		push_error("[VisualPresentationSmoke] Starter coastal terrain must use a lush Pacific urban-green palette")
		main_instance.free()
		get_tree().quit(1)
		return
	main_instance.free()

	var canopy: ArrayMesh = presentation._create_clustered_canopy_mesh()
	if canopy == null or canopy.get_surface_count() != 1:
		push_error("[VisualPresentationSmoke] Canopy must be a single mesh surface")
		presentation.free()
		get_tree().quit(1)
		return

	var bounds := canopy.get_aabb()
	if bounds.size.x < 2.5 or bounds.size.y < 1.8 or bounds.size.z < 2.5:
		push_error("[VisualPresentationSmoke] Canopy silhouette is unexpectedly small: %s" % bounds.size)
		presentation.free()
		get_tree().quit(1)
		return

	var arrays := canopy.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.size() < 100 or normals.size() != vertices.size():
		push_error("[VisualPresentationSmoke] Canopy geometry/normals are incomplete")
		presentation.free()
		get_tree().quit(1)
		return

	var positions: Array[Vector3] = [Vector3.ZERO, Vector3(5.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)]
	var tree_batch: MultiMeshInstance3D = presentation._create_tree_multimesh("TreeCanopies", canopy, positions, 2.55)
	if tree_batch.multimesh == null or tree_batch.multimesh.instance_count != positions.size():
		push_error("[VisualPresentationSmoke] Tree crowns must remain batched in a MultiMesh")
		tree_batch.free()
		presentation.free()
		get_tree().quit(1)
		return

	# Headless Godot uses a dummy RenderingServer; reading MultiMesh instance
	# transforms back from it returns identity transforms even after writes.
	# Validate the pure transform function used by the production write path.
	var first_transform: Transform3D = presentation._tree_instance_transform(0, positions[0], 2.55)
	var second_transform: Transform3D = presentation._tree_instance_transform(1, positions[1], 2.55)
	var third_transform: Transform3D = presentation._tree_instance_transform(2, positions[2], 2.55)
	if first_transform.is_equal_approx(second_transform) or second_transform.is_equal_approx(third_transform):
		push_error("[VisualPresentationSmoke] Tree instances must have deterministic visual variation; first=%s second=%s third=%s" % [first_transform, second_transform, third_transform])
		tree_batch.free()
		presentation.free()
		get_tree().quit(1)
		return
	if first_transform.origin.distance_to(second_transform.origin) < 4.0:
		push_error("[VisualPresentationSmoke] Tree instance positions were not preserved")
		tree_batch.free()
		presentation.free()
		get_tree().quit(1)
		return

	var pebble_batch: MultiMeshInstance3D = presentation._create_shoreline_pebble_multimesh()
	if pebble_batch.multimesh == null or pebble_batch.multimesh.instance_count != 38:
		push_error("[VisualPresentationSmoke] Shoreline pebbles must be batched into exactly 38 instances")
		pebble_batch.free()
		tree_batch.free()
		presentation.free()
		get_tree().quit(1)
		return
	if not pebble_batch.multimesh.use_colors or pebble_batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		push_error("[VisualPresentationSmoke] Shoreline batch must preserve per-instance color and avoid unnecessary pebble shadows")
		pebble_batch.free()
		tree_batch.free()
		presentation.free()
		get_tree().quit(1)
		return
	var pebble_first: Transform3D = presentation._shoreline_pebble_transform(0)
	var pebble_last: Transform3D = presentation._shoreline_pebble_transform(37)
	if pebble_first.is_equal_approx(pebble_last) or pebble_first.origin.distance_to(pebble_last.origin) < 100.0:
		push_error("[VisualPresentationSmoke] Shoreline pebble transforms must retain the full coast distribution")
		pebble_batch.free()
		tree_batch.free()
		presentation.free()
		get_tree().quit(1)
		return
	if presentation._shoreline_pebble_color(0).is_equal_approx(presentation._shoreline_pebble_color(1)):
		push_error("[VisualPresentationSmoke] Shoreline stones must retain per-instance color variation")
		pebble_batch.free()
		tree_batch.free()
		presentation.free()
		get_tree().quit(1)
		return
	pebble_batch.free()

	var warm_fill_light: DirectionalLight3D = presentation._create_warm_fill_light()
	if warm_fill_light.shadow_enabled or not is_equal_approx(warm_fill_light.light_energy, 0.34):
		push_error("[VisualPresentationSmoke] Warm secondary sunlight must remain a non-shadowing fill light; the main scene key light is the only shadow source")
		warm_fill_light.free()
		tree_batch.free()
		presentation.free()
		get_tree().quit(1)
		return
	warm_fill_light.free()
	print("[VisualPresentationSmoke] PASS: coastal city without mountain backdrop, shoreline continuity, clustered canopy geometry, tree batching and beach detail")
	tree_batch.free()
	presentation.free()
	get_tree().quit(0)
