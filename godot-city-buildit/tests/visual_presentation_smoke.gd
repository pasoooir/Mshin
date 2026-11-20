extends Node

const WorldPresentationScript = preload("res://scripts/world/WorldPresentation.gd")
const DistantMountainBackdropScript = preload("res://scripts/world/DistantMountainBackdrop.gd")


func _ready() -> void:
	var presentation := WorldPresentationScript.new()
	add_child(presentation)
	var backdrop := DistantMountainBackdropScript.new()
	presentation.add_child(backdrop)
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
		if near_ridge.visibility_range_end != DistantMountainBackdropScript.RIDGE_LOD_DISTANCE or far_ridge.visibility_range_begin != DistantMountainBackdropScript.RIDGE_LOD_DISTANCE or far_ridge.visibility_range_end != DistantMountainBackdropScript.MIN_CAMERA_FAR_CLIP:
			push_error("[VisualPresentationSmoke] Mountain LOD visibility ranges must meet without a gap")
			get_tree().quit(1)
			return
		var near_vertices: PackedVector3Array = near_ridge.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var far_vertices: PackedVector3Array = far_ridge.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if near_vertices.size() <= far_vertices.size() * 3:
			push_error("[VisualPresentationSmoke] Near mountain geometry must carry materially more silhouette detail than far LOD")
			get_tree().quit(1)
			return
	var rock_outcrops := backdrop.get_node_or_null("MountainNearRockOutcrops") as MultiMeshInstance3D
	if rock_outcrops == null or rock_outcrops.multimesh.instance_count != DistantMountainBackdropScript.RIDGE_ROCK_COUNT or rock_outcrops.visibility_range_end != DistantMountainBackdropScript.RIDGE_DETAIL_DISTANCE:
		push_error("[VisualPresentationSmoke] Near rock outcrops must be one fixed-size MultiMesh with a bounded visibility range")
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
	if rock_vertices.size() < 180 or rock_normals.size() != rock_vertices.size() or rock_bounds.size.x < 1.25 or rock_bounds.size.y < 1.65 or rock_bounds.size.z < 1.25:
		push_error("[VisualPresentationSmoke] Near rock mesh must contain chipped silhouette geometry, recessed facets and complete normals")
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
	if rock_material == null or rock_material.shader == null or not rock_material.shader.code.contains("cellular_edge") or not rock_material.shader.code.contains("stone_fbm") or not rock_material.shader.code.contains("fracture_core") or not rock_material.shader.code.contains("tri_weights"):
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
	if key_light == null or not key_light.shadow_enabled or key_light.shadow_opacity < 0.25 or key_light.shadow_blur < 0.5 or key_light.directional_shadow_max_distance < DistantMountainBackdropScript.RIDGE_DETAIL_DISTANCE:
		push_error("[VisualPresentationSmoke] Main directional shadow map must cover near rocks with controlled softness and opacity")
		shadow_scene.free()
		get_tree().quit(1)
		return
	shadow_scene.free()
	if rock_outcrops.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON or rock_outcrops.visibility_range_end != DistantMountainBackdropScript.RIDGE_DETAIL_DISTANCE:
		push_error("[VisualPresentationSmoke] Rock shadows must be enabled only inside the bounded near-detail range")
		get_tree().quit(1)
		return
	if absf(backdrop._ridge_radial_offset(83.0, 0.48, 0)) < 0.5 or absf(backdrop._ridge_radial_offset(-217.0, 0.63, 2)) < 0.5:
		push_error("[VisualPresentationSmoke] Mountain ridge silhouette must contain deterministic lateral erosion and irregular rock shoulders")
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
	if DistantMountainBackdropScript.RIDGE_INNER_RADIUS < 100.0 or DistantMountainBackdropScript.RIDGE_OUTER_RADIUS > city_camera.far:
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
