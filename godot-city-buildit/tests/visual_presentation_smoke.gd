extends Node

const WorldPresentationScript = preload("res://scripts/world/WorldPresentation.gd")


func _ready() -> void:
	var presentation := WorldPresentationScript.new()
	add_child(presentation)
	# Every visible inland field must belong to the same expandable city domain.
	if not LandExpansionManager.is_cell_inside_coastal_build_boundary(Vector2i(-207, 0)):
		push_error("[VisualPresentationSmoke] Western rendered land must remain expandable")
		get_tree().quit(1)
		return
	if not LandExpansionManager.is_cell_inside_coastal_build_boundary(Vector2i(0, 159)):
		push_error("[VisualPresentationSmoke] Northern/southern rendered land edge must remain expandable")
		get_tree().quit(1)
		return
	if LandExpansionManager.is_cell_inside_coastal_build_boundary(Vector2i(0, 160)):
		push_error("[VisualPresentationSmoke] Expansion must stop at the actual terrain edge")
		get_tree().quit(1)
		return
	# The headless dummy renderer cannot return SurfaceTool.commit() meshes.
	# Validate the exact generation bounds and tessellation inputs directly;
	# real WebGL captures verify the resulting rendered surface.
	if WorldPresentationScript.TERRAIN_LEFT > -419.0 or WorldPresentationScript.TERRAIN_HALF_DEPTH < 319.0 or WorldPresentationScript.TERRAIN_DIVISIONS < 192 or WorldPresentationScript.COASTLINE_BASE_X < 108.0:
		push_error("[VisualPresentationSmoke] Terrain generation bounds must cover the complete mobile camera envelope and coastal edge")
		get_tree().quit(1)
		return
	var shrub_source := FileAccess.get_file_as_string("res://scripts/world/WorldPresentation.gd")
	if not shrub_source.contains("_build_shrubland_detail()") or not shrub_source.contains("CoastalMeadowShrubClusters"):
		push_error("[VisualPresentationSmoke] Natural meadow must include the batched coastal shrubland layer")
		get_tree().quit(1)
		return
	var shrub_mesh := presentation._create_shrub_cluster_mesh()
	if shrub_mesh == null or shrub_mesh.get_surface_count() != 1:
		push_error("[VisualPresentationSmoke] Shrub clusters must use one shared low-poly mesh surface")
		get_tree().quit(1)
		return
	presentation._build_meadow_biome_overlays()
	if presentation.get_node_or_null("MeadowBiomePatches") != null:
		push_error("[VisualPresentationSmoke] Disconnected biome islands must not be rendered over the continuous meadow")
		get_tree().quit(1)
		return
	# Coastline regression: water geometry must follow the curved beach edge,
	# and the terrain must taper to the sea datum instead of overlapping it.
	var coast_sample := presentation._coastline(0.0)
	var owned_plot_ao := presentation._terrain_vertex_ao(0.0, 0.0)
	var natural_terrain_ao := presentation._terrain_vertex_ao(54.0, 54.0)
	if not is_equal_approx(owned_plot_ao, 1.0):
		push_error("[VisualPresentationSmoke] Buildable starter plots must remain evenly lit without terrain cavity shading")
		get_tree().quit(1)
		return
	if natural_terrain_ao < 0.86 or natural_terrain_ao > 1.0 or natural_terrain_ao >= 1.0:
		push_error("[VisualPresentationSmoke] Natural terrain must apply restrained Compatibility-safe vertex cavity shading")
		get_tree().quit(1)
		return
	if absf(presentation._terrain_height(coast_sample, 0.0)) > 0.01:
		push_error("[VisualPresentationSmoke] Beach terrain must meet the ocean at the sea datum")
		get_tree().quit(1)
		return
	var starter_plot_height := presentation._terrain_height(12.0, 12.0)
	var outer_meadow_height := presentation._terrain_height(78.0, -54.0)
	if absf(starter_plot_height) > 0.01:
		push_error("[VisualPresentationSmoke] Starter build plots must remain perfectly level")
		get_tree().quit(1)
		return
	if absf(outer_meadow_height) < 0.65 or absf(outer_meadow_height) > 3.5:
		push_error("[VisualPresentationSmoke] Outer meadow must have visible but restrained rolling terrain relief; sampled height=%s" % outer_meadow_height)
		get_tree().quit(1)
		return
	var ocean_mesh := presentation._create_coastal_water_mesh(8.0, 159.0, 24, 4, -0.055)
	var ocean_bounds := ocean_mesh.get_aabb()
	if ocean_mesh.get_surface_count() != 1 or ocean_bounds.position.x < 45.0 or ocean_bounds.end.x < 158.9:
		push_error("[VisualPresentationSmoke] Deep water must be a continuous coastline-following mesh extending offshore")
		get_tree().quit(1)
		return
	var shallow_mesh := presentation._create_coastal_water_mesh(0.12, 18.0, 24, 8, -0.025)
	if shallow_mesh.get_aabb().position.x < 45.0 or shallow_mesh.get_aabb().size.x > 52.0:
		push_error("[VisualPresentationSmoke] Shallow water must remain a narrow continuous band following the curved shoreline")
		get_tree().quit(1)
		return
	var production_shallow_mesh := presentation._create_coastal_water_mesh(0.16, 34.0, 24, 8, 0.008)
	if production_shallow_mesh.get_aabb().position.x < 80.0:
		push_error("[VisualPresentationSmoke] Production shallow water must start offshore; it must never extend inland across the beach")
		get_tree().quit(1)
		return
	if not FileAccess.get_file_as_string("res://scripts/world/WorldPresentation.gd").contains("coast_x0 + far_edge if far_edge <= 100.0 else far_edge"):
		push_error("[VisualPresentationSmoke] Coast-relative water widths must not be mistaken for absolute world-space coordinates")
		get_tree().quit(1)
		return
	var world_source := FileAccess.get_file_as_string("res://scripts/world/WorldPresentation.gd")
	if not world_source.contains("func _create_ground_detail_texture() -> Texture2D:") or not world_source.contains("material.albedo_texture = _create_ground_detail_texture()"):
		push_error("[VisualPresentationSmoke] Ground detail texture must be generated locally and applied to the terrain material")
		presentation.free()
		get_tree().quit(1)
		return
	for required_foliage_integration in [
		"StylizedFoliageSystemScript",
		"foliage_system.configure_tree_positions(positions, 2026, bark_material.albedo_texture)",
		"TreeRootBases"
	]:
		if not world_source.contains(required_foliage_integration):
			push_error("[VisualPresentationSmoke] Stylized foliage integration is incomplete: " + required_foliage_integration)
			get_tree().quit(1)
			return
	var trunk_foliage_source := FileAccess.get_file_as_string("res://scripts/world/StylizedFoliageSystem.gd")
	for required_trunk_contract in [
		"func _build_chunk_trunks(",
		"_trunk_material.albedo_texture = bark_texture",
		"func _get_tree_crown_height(species_id: int, stable_random: float) -> float:",
		"trunks.set_instance_transform("
	]:
		if not trunk_foliage_source.contains(required_trunk_contract):
			push_error("[VisualPresentationSmoke] Crown-aligned batched tree trunks are incomplete: " + required_trunk_contract)
			get_tree().quit(1)
			return

	var road_source := FileAccess.get_file_as_string("res://scripts/systems/RoadSystem.gd")
	if presentation._is_build_overlay_active():
		push_error("[VisualPresentationSmoke] The placement grid must be hidden during normal city viewing")
		get_tree().quit(1)
		return
	if not road_source.contains("func _append_top_quad(") or road_source.contains("_append_box(asphalt_tool,") or road_source.contains("_append_box(sidewalk_tool,"):
		push_error("[VisualPresentationSmoke] Horizontal road surfaces must use top-face-only geometry to avoid hidden bottom/side triangles")
		get_tree().quit(1)
		return
	if not road_source.contains("const ROAD_RENDER_CHUNK_SIZE: int = 8") or not road_source.contains("func _rebuild_road_render_chunk(") or not road_source.contains("append_from(tile_node.mesh, surface_index, local_transform)") or not road_source.contains("for x in range(chunk_key.x * ROAD_RENDER_CHUNK_SIZE") or not road_source.contains("for z in range(chunk_key.y * ROAD_RENDER_CHUNK_SIZE") or not road_source.contains("func get_road_render_chunk_count()") or road_source.contains("add_child(new_mesh)"):
		push_error("[VisualPresentationSmoke] Road geometry must be batched into editable 8x8 spatial render chunks, not submitted as one scene node per tile")
		get_tree().quit(1)
		return
	if not road_source.contains("instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF"):
		push_error("[VisualPresentationSmoke] Repeated road tiles must not consume the shadow-caster pass")
		get_tree().quit(1)
		return
	if not world_source.contains("grid_instance.visible = _is_build_overlay_active()") or not road_source.contains("signal road_mode_changed(active: bool)"):
		push_error("[VisualPresentationSmoke] Build grid visibility must follow building placement and road editing modes")
		get_tree().quit(1)
		return
	var tutorial_source := FileAccess.get_file_as_string("res://scripts/ui/TutorialGuide.gd")
	if not tutorial_source.contains("_build_coach_toggle_button()") or not tutorial_source.contains("_dismissed = true") or not tutorial_source.contains("_panel.hide()") or not tutorial_source.contains("func _toggle_guide_panel()"):
		push_error("[VisualPresentationSmoke] City Coach must not obscure the opening city view and must remain accessible from a compact toggle")
		get_tree().quit(1)
		return
	var expansion_panel_source := FileAccess.get_file_as_string("res://scripts/ui/LandExpansionPanel.gd")
	if not world_source.contains("marker_root.visible = _expansion_preview_active") or not world_source.contains("PlotOwnershipOverlay") or not world_source.contains("PlotOwnershipBorders") or not world_source.contains("LandExpansionManager.get_available_expansion_tiles()") or not world_source.contains("func set_expansion_preview_visible(active: bool)") or not expansion_panel_source.contains("_set_world_expansion_preview(true)") or not expansion_panel_source.contains("_set_world_expansion_preview(false)"):
		push_error("[VisualPresentationSmoke] Expansion plot outlines must stay hidden during normal play and appear only while the land-expansion panel is open")
		get_tree().quit(1)
		return
	if not expansion_panel_source.contains('Icons.make_item_icon("special"') or not expansion_panel_source.contains("ExpansionItemInventory") or not expansion_panel_source.contains("ExpansionPlotCard_"):
		push_error("[VisualPresentationSmoke] Land expansion selection must show distinct item PNGs and per-plot quantities")
		get_tree().quit(1)
		return
	if not world_source.contains("highway_asphalt.albedo_color = Color(\"#737A76\")"):
		push_error("[VisualPresentationSmoke] Pacific motorway must retain dark asphalt contrast")
		get_tree().quit(1)
		return
	# Compatibility/WebGL terrain uses authored, unshaded vertex colours so the palette
	# is not washed out by stacked lighting or the old procedural spatial shader.
	var terrain_material_source := world_source
	for required_terrain_layer in [
		"func _add_terrain_vertex(surface: SurfaceTool, point: Vector3) -> void:",
		"var macro_field := sin(point.x * 0.019 + point.z * 0.015)",
		"var secondary_field := sin(point.x * 0.043 - point.z * 0.037)",
		"var biome_soil_mask := smoothstep(0.58, 0.88, soil_field)",
		"Color(\"#987B5D\")",
		"func _create_natural_ground_material() -> StandardMaterial3D:",
		"material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED",
		"var field_mix := clampf(0.50 + macro_field * 0.43 + secondary_field * 0.07, 0.0, 1.0)",
		"var meadow_sage := Color(\"#89966D\")",
		"var sunlit_straw := Color(\"#B5A071\")",
		"material.vertex_color_use_as_albedo = true",
		"material.albedo_color = Color.WHITE",
		"render_mode unshaded, cull_disabled;",
		"material.roughness = 0.98",
		"func _build_meadow_biome_overlays() -> void:"
	]:
		if not terrain_material_source.contains(required_terrain_layer):
			push_error("[VisualPresentationSmoke] Compatibility-safe colour-accurate vertex-colour meadow is incomplete: " + required_terrain_layer)
			get_tree().quit(1)
			return
	if world_source.contains("cdn.meshy.ai") or road_source.contains("cdn.meshy.ai") or world_source.contains("HTTPRequest") or road_source.contains("HTTPRequest"):
		push_error("[VisualPresentationSmoke] Terrain and road textures must be fully local; runtime CDN/HTTP requests are forbidden")
		get_tree().quit(1)
		return
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
		"const BEACH_WIDTH := 8.0",
		"func _build_shoreline_foam(",
		"func _build_beach_palms(",
		"func _create_palm_frond_mesh(",
		"PacificShoreFoam",
		"PacificPalmTrunks",
		"PacificPalmCrowns",
		"COASTAL_GREEN_PALETTE",
		"_build_sandy_beach()",
		"_build_shoreline_foam()",
		"_build_beach_palms()"
	]:
		if not world_visual_source.contains(required_coastal_feature):
			push_error("[VisualPresentationSmoke] Los Angeles coastal world is missing: " + required_coastal_feature)
			get_tree().quit(1)
			return
	# The shader coastline assertion is obsolete: the Compatibility-safe
	# vertex-colour terrain uses a dedicated beach mesh driven by _coastline().
	if not world_visual_source.contains("return COASTLINE_BASE_X + sin(z * 0.032) * 7.0 + sin(z * 0.071) * 3.2 + sin(z * 0.013) * 4.0") or not world_visual_source.contains("var coast0 := _coastline(z0)") or not world_visual_source.contains("var coast1 := _coastline(z1)"):
		push_error("[VisualPresentationSmoke] Sandy beach and shoreline must share the curved coastline function")
		get_tree().quit(1)
		return
	if presentation._coastline(0.0) < 108.0 or presentation._coastline(0.0) > 112.0 or absf(presentation._coastline(-120.0) - presentation._coastline(120.0)) < 4.0:
		push_error("[VisualPresentationSmoke] Pacific shoreline must sit beyond the full starter city footprint")
		get_tree().quit(1)
		return
	if presentation.BEACH_WIDTH > 28.0:
		push_error("[VisualPresentationSmoke] The playable shoreline beach must remain a human-scale coastal strip, not a 56 m sand plain")
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
	var graphics_quality_source := FileAccess.get_file_as_string("res://scripts/autoload/GraphicsSettingsManager.gd")
	if not world_visual_source.contains("range(grass_instance_count)") or not world_visual_source.contains("range(cluster_count)") or not world_visual_source.contains("range(360)") or not world_visual_source.contains("range(300)") or not graphics_quality_source.contains('"grass_instances": 3600') or not graphics_quality_source.contains('"shrub_clusters": 240'):
		push_error("[VisualPresentationSmoke] Quality-scaled ground cover must retain full high-preset density while allowing the low mobile preset to reduce draw cost")
		get_tree().quit(1)
		return
	if not world_visual_source.contains("LandExpansionManager.is_world_position_unlocked(Vector3(x, 0.0, z))"):
		push_error("[VisualPresentationSmoke] Natural ground cover must never occupy purchased buildable plots")
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
	var camera_rig := main_instance.get_node_or_null("CameraRig")
	if camera_rig == null or float(camera_rig.get("max_zoom")) > 150.0 or float(camera_rig.get("current_zoom")) > 150.0:
		push_error("[VisualPresentationSmoke] Maximum zoom-out must keep the city, coast and sea inside a useful playable composition")
		main_instance.free()
		get_tree().quit(1)
		return
	var camera_source := FileAccess.get_file_as_string("res://scripts/systems/CameraController.gd")
	if not camera_source.contains("camera.fov = 62.0") or not camera_source.contains("global_position = Vector3(25.0, 0.0, 0.0)") or not camera_source.contains("rotation_degrees = Vector3(0.0, -45.0, 0.0)"):
		push_error("[VisualPresentationSmoke] Opening camera must frame the ocean and buildable city together")
		main_instance.free()
		get_tree().quit(1)
		return
	var wide_ocean: ArrayMesh = presentation._create_coastal_water_mesh(32.0, 1100.0, 180, 48, 0.015)
	if wide_ocean == null or wide_ocean.get_aabb().size.x < 500.0 or wide_ocean.get_aabb().size.z < 280.0:
		push_error("[VisualPresentationSmoke] Pacific ocean must form a broad visible water body, not a narrow shoreline strip")
		main_instance.free()
		get_tree().quit(1)
		return
	var ocean_source := FileAccess.get_file_as_string("res://scripts/world/WorldPresentation.gd")
	if not ocean_source.contains("const TERRAIN_HALF_DEPTH := 320.0") or not ocean_source.contains("const BEACH_WIDTH := 8.0") or not ocean_source.contains("_create_coastal_water_mesh(32.0, 1100.0, water_rows, water_columns, 0.015)") or not ocean_source.contains("cull_disabled, diffuse_burley, specular_schlick_ggx"):
		push_error("[VisualPresentationSmoke] Expanded coastal world bounds and broad ocean mesh must remain in the playable scene")
		main_instance.free()
		get_tree().quit(1)
		return
	presentation.call("_build_sandy_beach")
	var sandy_beach := presentation.get_node_or_null("ContinuousSandyBeach") as MeshInstance3D
	if sandy_beach == null or sandy_beach.mesh == null or sandy_beach.mesh.get_surface_count() == 0:
		push_error("[VisualPresentationSmoke] A continuous visible sandy beach mesh must cover the full coastline")
	presentation.call("_build_shoreline_foam")
	if presentation.get_node_or_null("PacificShoreFoam") == null:
		push_error("[VisualPresentationSmoke] The beach must have a visible irregular surf/foam edge")
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
	var conifer_canopy: ArrayMesh = presentation._create_conifer_canopy_mesh()
	var umbrella_canopy: ArrayMesh = presentation._create_umbrella_canopy_mesh()
	if canopy == null or conifer_canopy == null or umbrella_canopy == null:
		push_error("[VisualPresentationSmoke] Three distinct tree canopy meshes must be generated locally")
		presentation.free()
		get_tree().quit(1)
		return
	var broadleaf_vertices: PackedVector3Array = canopy.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var conifer_vertices: PackedVector3Array = conifer_canopy.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var umbrella_vertices: PackedVector3Array = umbrella_canopy.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if broadleaf_vertices.size() == conifer_vertices.size() or conifer_vertices.size() == umbrella_vertices.size():
		push_error("[VisualPresentationSmoke] Tree species must use distinct canopy geometry, not recolored copies")
		presentation.free()
		get_tree().quit(1)
		return
	if umbrella_canopy.get_aabb().size.x <= conifer_canopy.get_aabb().size.x:
		push_error("[VisualPresentationSmoke] Umbrella crown must be visibly wider than the conifer crown")
		presentation.free()
		get_tree().quit(1)
		return
	var world_ready_source := world_source
	var foliage_source := FileAccess.get_file_as_string("res://scripts/world/StylizedFoliageSystem.gd")
	for foliage_contract in [
		"StylizedFoliageSystemScript",
		"TreeCanopies_Species%d_LOD%d",
		"LOD_CARDS := [10, 6, 3]",
		"CHUNK_SIZE := 64.0",
		"PacificPalmCrowns"
	]:
		var source_to_check := foliage_source if foliage_contract.begins_with("TreeCanopies") or foliage_contract.begins_with("LOD_") or foliage_contract.begins_with("CHUNK_") else world_ready_source
		if not source_to_check.contains(foliage_contract):
			push_error("[VisualPresentationSmoke] Starter greenbelt is missing a foliage-system contract: " + foliage_contract)
			presentation.free()
			get_tree().quit(1)
			return
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
