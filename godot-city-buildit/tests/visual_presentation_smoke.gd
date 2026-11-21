extends Node

const WorldPresentationScript = preload("res://scripts/world/WorldPresentation.gd")
const DistantMountainBackdropScript = preload("res://scripts/world/DistantMountainBackdrop.gd")


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
	if not world_source.contains("grid_instance.visible = BuildManager.is_placing") or not world_source.contains("func _on_placement_mode_changed(active: bool)"):
		push_error("[VisualPresentationSmoke] Build grid must stay hidden until an explicit building-placement action")
		get_tree().quit(1)
		return
	if not world_source.contains("float broad = value_noise(world_position.xz * 0.055)") or not world_source.contains("float dry_patch = smoothstep(0.72, 0.90") or world_source.contains("meadow_fbm"):
		push_error("[VisualPresentationSmoke] Meadow material must include multi-scale natural ground variation")
		get_tree().quit(1)
		return
	if world_source.count("_is_city_road_footprint(x, z)") < 4:
		push_error("[VisualPresentationSmoke] Grass, shrubs and loose field stones must all exclude occupied asphalt tiles")
		get_tree().quit(1)
		return
	var camera_source := FileAccess.get_file_as_string("res://scripts/systems/CameraController.gd")
	if not camera_source.contains("var current_zoom: float = 68.0") or not camera_source.contains("global_position = Vector3(-3.0, 0.0, 0.0)"):
		push_error("[VisualPresentationSmoke] First camera frame must include the starter plots, highway access and coastal environment")
		get_tree().quit(1)
		return
	if not camera_source.contains("func _apply_visual_acceptance_preset()") or not camera_source.contains("new URLSearchParams(window.location.search).get('visual_camera')") or not camera_source.contains('"coast_near"') or not camera_source.contains('"tunnel_far"'):
		push_error("[VisualPresentationSmoke] Explicit WebGL visual-acceptance presets must expose coastline and tunnel camera views without altering the default entry camera")
		get_tree().quit(1)
		return
	var tutorial_source := FileAccess.get_file_as_string("res://scripts/ui/TutorialGuide.gd")
	if not tutorial_source.contains("var desired_height := 218.0 if current_step == 0") or not tutorial_source.contains("The name field is directly visible in the compact coach") or not tutorial_source.contains("_guide_scroll.visible = not is_name_step"):
		push_error("[VisualPresentationSmoke] First-entry coach must stay compact and keep the city view unobstructed")
		get_tree().quit(1)
		return
	if not world_source.contains("cdn.polyhaven.com/asset_img/primary/leafy_grass.png") or not world_source.contains("cdn.polyhaven.com/asset_img/primary/coast_sand_02.png") or not world_source.contains("load_png_from_buffer(body)"):
		push_error("[VisualPresentationSmoke] Grass and coastal sand must use the verified CC0 Poly Haven CDN textures with PNG decoding")
		get_tree().quit(1)
		return
	var road_source := FileAccess.get_file_as_string("res://scripts/systems/RoadSystem.gd")
	if not road_source.contains("cdn.polyhaven.com/asset_img/primary/clean_asphalt.png") or not road_source.contains("load_png_from_buffer(body)"):
		push_error("[VisualPresentationSmoke] City streets and highway must share the same clean CC0 asphalt CDN source")
		get_tree().quit(1)
		return
	var backdrop_source := FileAccess.get_file_as_string("res://scripts/world/DistantMountainBackdrop.gd")
	if not backdrop_source.contains("float coastline = 51.0") or not backdrop_source.contains("field_noise(p * 0.071") or backdrop_source.contains("world_position.x >= 49.0 && world_position.x <= 159.0"):
		push_error("[VisualPresentationSmoke] Distant ground must use natural terrain variation and the same curved ocean opening as the shoreline")
		get_tree().quit(1)
		return
	var backdrop := DistantMountainBackdropScript.new()
	presentation.add_child(backdrop)
	# Mountain generation is intentionally staged across frames at runtime.
	# Wait for the same completion signal in this smoke test before inspecting
	# the generated perimeter, LOD meshes, tunnels and vegetation batches.
	await backdrop.generation_completed
	if backdrop.get_node_or_null("NorthMountainRidge") == null or backdrop.get_node_or_null("SouthMountainRidge") == null or backdrop.get_node_or_null("WestMountainRidge") == null or backdrop.get_node_or_null("EastMountainRidge") == null:
		push_error("[VisualPresentationSmoke] Mountain perimeter must render all four overlapping ridge walls")
		get_tree().quit(1)
		return
	for ridge_name in ["NorthMountainRidge", "SouthMountainRidge", "WestMountainRidge", "EastMountainRidge"]:
		var near_ridge := backdrop.get_node_or_null(ridge_name) as MeshInstance3D
		var far_ridge := backdrop.get_node_or_null(ridge_name + "FarLOD") as MeshInstance3D
		if near_ridge == null or far_ridge == null or near_ridge.mesh == null or far_ridge.mesh == null:
			push_error("[VisualPresentationSmoke] Each mountain wall must provide near and far geometry LODs")
			get_tree().quit(1)
			return
		if near_ridge.visibility_range_end != DistantMountainBackdropScript.RIDGE_LOD_DISTANCE or far_ridge.visibility_range_begin != DistantMountainBackdropScript.RIDGE_LOD_DISTANCE - DistantMountainBackdropScript.RIDGE_LOD_OVERLAP or far_ridge.visibility_range_end != DistantMountainBackdropScript.MIN_CAMERA_FAR_CLIP:
			push_error("[VisualPresentationSmoke] Mountain LOD visibility ranges must retain the configured overlap without a gap")
			get_tree().quit(1)
			return
		var near_vertices: PackedVector3Array = near_ridge.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var far_vertices: PackedVector3Array = far_ridge.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if near_ridge.visibility_range_end_margin != DistantMountainBackdropScript.RIDGE_LOD_FADE_MARGIN or far_ridge.visibility_range_begin_margin != DistantMountainBackdropScript.RIDGE_LOD_FADE_MARGIN or near_ridge.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF or far_ridge.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF or DistantMountainBackdropScript.RIDGE_LOD_OVERLAP < DistantMountainBackdropScript.RIDGE_LOD_FADE_MARGIN:
			push_error("[VisualPresentationSmoke] Mountain LOD cross-fade margins must fit inside the overlap")
			get_tree().quit(1)
			return
		if near_vertices.size() <= far_vertices.size() * 3:
			push_error("[VisualPresentationSmoke] Near mountain geometry must carry materially more silhouette detail than far LOD")
			get_tree().quit(1)
			return
	var rock_outcrops := backdrop.get_node_or_null("MountainNearRockOutcrops") as MultiMeshInstance3D
	if rock_outcrops == null or rock_outcrops.multimesh == null or rock_outcrops.multimesh.mesh == null:
		push_error("[VisualPresentationSmoke] Near rock outcrops must register one initialized MultiMesh with a valid shared mesh")
		get_tree().quit(1)
		return
	if rock_outcrops.multimesh.instance_count != DistantMountainBackdropScript.RIDGE_ROCK_COUNT or rock_outcrops.visibility_range_end != DistantMountainBackdropScript.RIDGE_DETAIL_DISTANCE or not is_finite(rock_outcrops.visibility_range_end) or rock_outcrops.visibility_range_end_margin != DistantMountainBackdropScript.RIDGE_LOD_FADE_MARGIN or rock_outcrops.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF:
		push_error("[VisualPresentationSmoke] Near rock outcrops must be one fixed-size MultiMesh with finite self-faded visibility bounds")
		get_tree().quit(1)
		return
	if DistantMountainBackdropScript.ROCK_FRACTURE_GROOVE_COUNT != 3 or DistantMountainBackdropScript.ROCK_FOOT_PEBBLE_COUNT != 4:
		push_error("[VisualPresentationSmoke] Near rocks must keep three layered fractures and four fused foot stones per shared mesh")
		get_tree().quit(1)
		return
	var hidden_transform: Transform3D = backdrop._hidden_multimesh_instance_transform()
	if hidden_transform.origin.y > -1000.0:
		push_error("[VisualPresentationSmoke] Excluded MultiMesh slots must be moved away from the playable city origin")
		get_tree().quit(1)
		return
	var mountain_source := FileAccess.get_file_as_string("res://scripts/world/DistantMountainBackdrop.gd")
	if not mountain_source.contains("render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;"):
		push_error("[VisualPresentationSmoke] Fractured rock material must render its chipped facets from both sides")
		get_tree().quit(1)
		return
	for hidden_assignment in [
		"batch.set_instance_transform(index, _hidden_multimesh_instance_transform())",
		"multimesh.set_instance_transform(index, _hidden_multimesh_instance_transform())",
		"trunks.set_instance_transform(index, hidden_transform)",
		"crowns.set_instance_transform(index, hidden_transform)"
	]:
		if not mountain_source.contains(hidden_assignment):
			push_error("[VisualPresentationSmoke] Every excluded mountain batch slot must receive an explicit hidden transform: " + hidden_assignment)
			get_tree().quit(1)
			return
	var rock_mesh := backdrop._create_rock_outcrop_mesh() as ArrayMesh
	if rock_mesh == null or rock_mesh.get_surface_count() != 1:
		push_error("[VisualPresentationSmoke] Chipped near rocks must stay one reusable mesh surface")
		get_tree().quit(1)
		return
	var rock_arrays := rock_mesh.surface_get_arrays(0)
	var rock_vertices: PackedVector3Array = rock_arrays[Mesh.ARRAY_VERTEX]
	var rock_normals: PackedVector3Array = rock_arrays[Mesh.ARRAY_NORMAL]
	var rock_bounds := rock_mesh.get_aabb()
	if rock_vertices.size() < 500 or rock_normals.size() != rock_vertices.size() or rock_bounds.size.x < 1.25 or rock_bounds.size.y < 2.0 or rock_bounds.size.z < 1.25:
		push_error("[VisualPresentationSmoke] Near rock mesh must contain dense multi-peak fracture geometry, attached talus and complete normals")
		get_tree().quit(1)
		return
	var view_directions: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK,
		Vector3.UP, Vector3.DOWN
	]
	for direction in view_directions:
		var facing_count := 0
		for normal in rock_normals:
			if normal.dot(direction) > 0.24:
				facing_count += 1
		if facing_count < 3:
			push_error("[VisualPresentationSmoke] Rock facets must expose readable surfaces from all six camera-side directions")
			get_tree().quit(1)
			return
	var rock_material := rock_outcrops.material_override as ShaderMaterial
	if rock_material == null or rock_material.shader == null or not rock_material.shader.code.contains("cellular_edge") or not rock_material.shader.code.contains("stone_fbm") or not rock_material.shader.code.contains("fracture_core") or not rock_material.shader.code.contains("tri_weights") or not rock_material.shader.code.contains("contact_occlusion") or not rock_material.shader.code.contains("rock_local_height") or not rock_material.shader.code.contains("stone_fbm(vec3(p.yz") or not rock_material.shader.code.contains("stone_fbm(vec3(p.xz") or not rock_material.shader.code.contains("stone_fbm(vec3(p.xy"):
		push_error("[VisualPresentationSmoke] Near rocks must use triplanar mineral grain, cellular fracture edges and controlled roughness")
		get_tree().quit(1)
		return
	var main_scene_for_shadows := load("res://scenes/main.tscn") as PackedScene
	if main_scene_for_shadows == null:
		push_error("[VisualPresentationSmoke] Main scene must load for rock shadow validation")
		get_tree().quit(1)
		return
	var shadow_scene := main_scene_for_shadows.instantiate()
	var key_light := shadow_scene.get_node_or_null("World/DirectionalLight3D") as DirectionalLight3D
	if key_light == null or not key_light.shadow_enabled or key_light.shadow_opacity < 0.25 or key_light.shadow_blur < 0.5 or absf(key_light.directional_shadow_max_distance - DistantMountainBackdropScript.RIDGE_DETAIL_DISTANCE) > 0.01:
		push_error("[VisualPresentationSmoke] Main directional shadow map must cover near rocks with controlled softness and opacity")
		shadow_scene.free()
		get_tree().quit(1)
		return
	shadow_scene.free()
	if rock_outcrops.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or rock_outcrops.visibility_range_end != DistantMountainBackdropScript.RIDGE_DETAIL_DISTANCE:
		push_error("[VisualPresentationSmoke] Rock contact occlusion must stay shader-based; individual outcrop shadow casting is disabled for mobile")
		get_tree().quit(1)
		return
	if absf(backdrop._ridge_radial_offset(83.0, 0.48, 0)) < 0.5 or absf(backdrop._ridge_radial_offset(-217.0, 0.63, 2)) < 0.5:
		push_error("[VisualPresentationSmoke] Mountain ridge silhouette must contain deterministic lateral erosion and irregular rock shoulders")
		get_tree().quit(1)
		return

	# All four tunnel mouths must sit beneath a continuous mountain crown.
	# The portal cap tops out at 17.5 m; 58 m gives at least 40.5 m of rock above it.
	for ridge_side in [0, 1]:
		for portal_depth in [0.0, 1.0]:
			for portal_x in [DistantMountainBackdropScript.TUNNEL_CENTER_X - 21.0, DistantMountainBackdropScript.TUNNEL_CENTER_X, DistantMountainBackdropScript.TUNNEL_CENTER_X + 21.0]:
				var crown_height := backdrop._ridge_height(portal_x, portal_depth, ridge_side)
				if crown_height < DistantMountainBackdropScript.TUNNEL_CROWN_MIN_HEIGHT:
					push_error("[VisualPresentationSmoke] Mountain crown must cover every north/south inner/outer tunnel opening; got %.2f m at side %d, x %.1f, depth %.1f" % [crown_height, ridge_side, portal_x, portal_depth])
					get_tree().quit(1)
					return
	if DistantMountainBackdropScript.TUNNEL_CROWN_MIN_HEIGHT - (DistantMountainBackdropScript.TUNNEL_WALL_HEIGHT + 2.5) < 25.0:
		push_error("[VisualPresentationSmoke] Mountain crown must rise at least 25 m above the tunnel crown cap")
		get_tree().quit(1)
		return

	# Verify the actual generated near/far ridge meshes retain the crown at both
	# portal radii, not merely the height helper's theoretical return value.
	for ridge_name in ["NorthMountainRidge", "SouthMountainRidge"]:
		for lod_suffix in ["", "FarLOD"]:
			var crown_ridge := backdrop.get_node(ridge_name + lod_suffix) as MeshInstance3D
			var crown_vertices: PackedVector3Array = crown_ridge.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for portal_radius in [DistantMountainBackdropScript.RIDGE_INNER_RADIUS, DistantMountainBackdropScript.RIDGE_OUTER_RADIUS]:
				var sampled_minimum := INF
				for crown_vertex in crown_vertices:
					if absf(crown_vertex.x - DistantMountainBackdropScript.TUNNEL_CENTER_X) <= DistantMountainBackdropScript.TUNNEL_CROWN_PLATEAU_HALF_WIDTH and absf(absf(crown_vertex.z) - portal_radius) < 0.01:
						sampled_minimum = minf(sampled_minimum, crown_vertex.y)
				if sampled_minimum < DistantMountainBackdropScript.TUNNEL_CROWN_MIN_HEIGHT - 0.01:
					push_error("[VisualPresentationSmoke] Generated " + ridge_name + lod_suffix + " mesh loses the mountain crown at portal radius %.1f m (height %.2f m)" % [portal_radius, sampled_minimum])
					get_tree().quit(1)
					return
	if backdrop.get_node_or_null("NorthHighwayTunnel") == null or backdrop.get_node_or_null("SouthHighwayTunnel") == null:
		push_error("[VisualPresentationSmoke] The regional highway must pass through north and south mountain tunnels")
		get_tree().quit(1)
		return
	if not backdrop._is_tunnel_portal_vegetation_exclusion(0, -55.0, 0.05) or not backdrop._is_tunnel_portal_vegetation_exclusion(1, -55.0, 0.95) or backdrop._is_tunnel_portal_vegetation_exclusion(2, -55.0, 0.05) or backdrop._is_tunnel_portal_vegetation_exclusion(0, -55.0, 0.5):
		push_error("[VisualPresentationSmoke] Only the actual north/south tunnel mouths must exclude obstructing vegetation; the mountain crown stays continuous")
		get_tree().quit(1)
		return
	if not backdrop._is_tunnel_road_detail_exclusion(0, -55.0) or not backdrop._is_tunnel_road_detail_exclusion(1, -55.0) or backdrop._is_tunnel_road_detail_exclusion(0, -27.0) or backdrop._is_tunnel_road_detail_exclusion(2, -55.0):
		push_error("[VisualPresentationSmoke] Mountain rocks, shrubs and trees must stay outside the complete highway tunnel clearance")
		get_tree().quit(1)
		return
	if not is_equal_approx(WorldPresentationScript.HIGHWAY_LENGTH, 700.0) or not is_equal_approx(WorldPresentationScript.HIGHWAY_CENTER_X, -55.0):
		push_error("[VisualPresentationSmoke] The continuous regional road must span both tunnel portals on the existing highway axis")
		get_tree().quit(1)
		return
	var north_tunnel := backdrop.get_node("NorthHighwayTunnel")
	var south_tunnel := backdrop.get_node("SouthHighwayTunnel")
	if north_tunnel.get_child_count() < 9 or south_tunnel.get_child_count() < 9:
		push_error("[VisualPresentationSmoke] Both tunnels must include a roof, side walls and framed inner/outer portals")
		get_tree().quit(1)
		return
	for tunnel in [north_tunnel, south_tunnel]:
		if tunnel.get_node_or_null("InnerPortalCrownCap") == null or tunnel.get_node_or_null("InnerPortalRetainingWing") == null or tunnel.get_node_or_null("InnerPortalAmberReflector") == null or tunnel.get_node_or_null("TunnelCeilingRibs") == null or tunnel.get_node_or_null("TunnelCenterlineDashes") == null:
			push_error("[VisualPresentationSmoke] Tunnel portals must include layered crowns, retaining wings, amber markers, ceiling ribs and lane dashes")
			get_tree().quit(1)
			return
	if backdrop.get_node_or_null("AustralianEucalyptTrunks") == null or backdrop.get_node_or_null("AustralianEucalyptCanopies") == null:
		push_error("[VisualPresentationSmoke] Australian eucalypts must render as two batched trunk/canopy meshes")
		get_tree().quit(1)
		return
	var trunk_batch := backdrop.get_node("AustralianEucalyptTrunks") as MultiMeshInstance3D
	var canopy_batch := backdrop.get_node("AustralianEucalyptCanopies") as MultiMeshInstance3D
	if trunk_batch.multimesh.instance_count != DistantMountainBackdropScript.EUCALYPT_COUNT or canopy_batch.multimesh.instance_count != DistantMountainBackdropScript.EUCALYPT_COUNT or trunk_batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or canopy_batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		push_error("[VisualPresentationSmoke] Eucalypts must stay in fixed-size mobile batches without distant-tree shadows")
		get_tree().quit(1)
		return
	if backdrop._ridge_color(-120.0, 0.52, 0).is_equal_approx(backdrop._ridge_color(110.0, 0.52, 0)):
		push_error("[VisualPresentationSmoke] Mountain ridge vertex palette must vary across sediment bands and grassy slopes")
		get_tree().quit(1)
		return
	var world_visual_source := FileAccess.get_file_as_string("res://scripts/world/WorldPresentation.gd")
	for required_visual_feature in [
		"func _terrain_height(",
		"func _build_dirt_tracks(",
		"func _build_creek_channel(",
		"func _build_creek_rock_edges(",
		"func _build_meadow_shrubs_and_stones(",
		"func _create_meadow_shrub_mesh(",
		"func _build_near_city_rock_outcrops(",
		"func _create_meadow_grass_clump_mesh(",
		"NearCityFracturedRockBatch",
		"Vector2(-18.0, -27.0)",
		"distance_from_city := maxf(absf(x) - 24.0, absf(z) - 24.0)",
		"absf(x) < 26.0 and absf(z) < 26.0",
		"AustralianMeadowScrub",
		"MeadowFieldstoneBatch",
		"NaturalDirtTracks",
		"ErodedCreekBanksAndBed",
		"MeadowCreekWater"
	]:
		if not world_visual_source.contains(required_visual_feature):
			push_error("[VisualPresentationSmoke] Living Australian ground is missing a required near-camera feature: " + required_visual_feature)
			get_tree().quit(1)
			return
	if not world_visual_source.contains("range(2400)") or not world_visual_source.contains("range(150)") or not world_visual_source.contains("range(110)"):
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
	if city_camera == null or city_camera.far < DistantMountainBackdropScript.MIN_CAMERA_FAR_CLIP:
		push_error("[VisualPresentationSmoke] Camera far clip must include both distant mountain ridges and outer tunnel portals")
		main_instance.free()
		get_tree().quit(1)
		return
	if DistantMountainBackdropScript.RIDGE_INNER_RADIUS < 60.0 or DistantMountainBackdropScript.RIDGE_OUTER_RADIUS > city_camera.far:
		push_error("[VisualPresentationSmoke] Mountain ring must remain inside the camera visible world distance")
		main_instance.free()
		get_tree().quit(1)
		return
	if WorldPresentationScript.AUSTRALIAN_GRASSLAND_PALETTE.size() < 5 or WorldPresentationScript.AUSTRALIAN_GRASSLAND_PALETTE[0].g <= WorldPresentationScript.AUSTRALIAN_GRASSLAND_PALETTE[0].r:
		push_error("[VisualPresentationSmoke] Starter temperate terrain must use a green grassland palette")
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
	print("[VisualPresentationSmoke] PASS: Australian grassland palette, visible mountain/tunnel range, clustered canopy geometry, tree batching and shoreline detail")
	tree_batch.free()
	presentation.free()
	get_tree().quit(0)
