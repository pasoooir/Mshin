extends Node3D
## Procedural, mobile-friendly green mountain horizon surrounding the playable map.
## Four batched ridge meshes, one grass plane and two MultiMesh detail batches
## replace an exposed world edge with a continuous natural backdrop.

const LAND_SIZE := Vector2(1000.0, 1000.0)
const RIDGE_INNER_RADIUS := 68.0
const RIDGE_OUTER_RADIUS := 205.0
const RIDGE_HALF_LENGTH := 470.0
const RIDGE_SEGMENTS := 96
const RIDGE_DEPTH_STEPS := 20
const RIDGE_FAR_SEGMENTS := 32
const RIDGE_FAR_DEPTH_STEPS := 10
const RIDGE_LOD_DISTANCE := 190.0
const RIDGE_DETAIL_DISTANCE := 215.0
const RIDGE_ROCK_COUNT := 72
const ROCK_FRACTURE_GROOVE_COUNT := 3
const ROCK_FOOT_PEBBLE_COUNT := 4
const SHRUB_COUNT := 320
const GRASS_COUNT := 760
const EUCALYPT_COUNT := 44
const TUNNEL_CENTER_X := -55.0

signal generation_completed
const TUNNEL_CUTOUT_HALF_WIDTH := 28.0
const TUNNEL_OPENING_WIDTH := 42.0
const TUNNEL_WALL_HEIGHT := 15.0
const MIN_CAMERA_FAR_CLIP := 720.0

func _ready() -> void:
	# Spread procedural generation over separate rendered frames. The playable
	# city appears immediately instead of waiting for every mountain mesh and
	# vegetation batch to be built synchronously during scene startup.
	_build_backdrop_land()
	await get_tree().process_frame
	_build_mountain_ridges()
	await get_tree().process_frame
	_build_mountain_rock_outcrops()
	await get_tree().process_frame
	_build_highway_tunnels()
	await get_tree().process_frame
	_build_mountain_shrubs()
	_build_mountain_grass()
	await get_tree().process_frame
	_build_mountain_eucalypts()
	generation_completed.emit()


func _build_backdrop_land() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "DistantGreenGround"
	var plane := PlaneMesh.new()
	plane.size = LAND_SIZE
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	ground.mesh = plane
	ground.position.y = -0.14
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Keep the existing coastal water visible through the green backdrop.
	if (world_position.x >= 49.0 && world_position.x <= 159.0 && abs(world_position.z) <= 95.0) {
		discard;
	}
	float grain = sin(world_position.x * 0.12 + world_position.z * 0.08) * cos(world_position.z * 0.11 - world_position.x * 0.06);
	ALBEDO = vec3(0.22, 0.43, 0.24) + vec3(grain * 0.018);
	ROUGHNESS = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_mountain_ridges() -> void:
	var names := ["NorthMountainRidge", "SouthMountainRidge", "WestMountainRidge", "EastMountainRidge"]
	for side in range(4):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var near_ridge := MeshInstance3D.new()
		near_ridge.name = names[side]
		near_ridge.mesh = _create_ridge_mesh(side, RIDGE_SEGMENTS, RIDGE_DEPTH_STEPS)
		near_ridge.material_override = material
		near_ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		near_ridge.visibility_range_end = RIDGE_LOD_DISTANCE
		near_ridge.visibility_range_end_margin = 12.0
		add_child(near_ridge)
		var far_ridge := MeshInstance3D.new()
		far_ridge.name = names[side] + "FarLOD"
		far_ridge.mesh = _create_ridge_mesh(side, RIDGE_FAR_SEGMENTS, RIDGE_FAR_DEPTH_STEPS)
		far_ridge.material_override = material
		far_ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		far_ridge.visibility_range_begin = RIDGE_LOD_DISTANCE
		far_ridge.visibility_range_begin_margin = 12.0
		far_ridge.visibility_range_end = MIN_CAMERA_FAR_CLIP
		add_child(far_ridge)


func _create_ridge_mesh(side: int, along_segments: int, depth_steps: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for along_index in range(along_segments):
		var t0 := lerpf(-RIDGE_HALF_LENGTH, RIDGE_HALF_LENGTH, float(along_index) / along_segments)
		var t1 := lerpf(-RIDGE_HALF_LENGTH, RIDGE_HALF_LENGTH, float(along_index + 1) / along_segments)
		for depth_index in range(depth_steps):
			var d0 := float(depth_index) / depth_steps
			var d1 := float(depth_index + 1) / depth_steps
			_add_ridge_vertex(surface, side, t0, d0)
			_add_ridge_vertex(surface, side, t1, d0)
			_add_ridge_vertex(surface, side, t0, d1)
			_add_ridge_vertex(surface, side, t1, d0)
			_add_ridge_vertex(surface, side, t1, d1)
			_add_ridge_vertex(surface, side, t0, d1)
	surface.generate_normals()
	return surface.commit()


func _is_tunnel_portal_vegetation_exclusion(side: int, along: float, depth: float) -> bool:
	if side > 1 or absf(along - TUNNEL_CENTER_X) > TUNNEL_CUTOUT_HALF_WIDTH:
		return false
	return depth <= 0.12 or depth >= 0.88

func _hidden_multimesh_instance_transform() -> Transform3D:
	# Unwritten MultiMesh slots default to identity and would appear in the city.
	return Transform3D(Basis.IDENTITY, Vector3(0.0, -10000.0, 0.0))


func _add_ridge_vertex(surface: SurfaceTool, side: int, along: float, depth: float) -> void:
	var point := _ridge_point(side, along, depth)
	surface.set_color(_ridge_color(along, depth, side))
	surface.set_uv(Vector2(along * 0.012, depth * 5.0))
	surface.add_vertex(point)


func _ridge_point(side: int, along: float, depth: float) -> Vector3:
	var radius := lerpf(RIDGE_INNER_RADIUS, RIDGE_OUTER_RADIUS, depth) + _ridge_radial_offset(along, depth, side)
	var height := _ridge_height(along, depth, side)
	match side:
		0:
			return Vector3(along, height, -radius)
		1:
			return Vector3(along, height, radius)
		2:
			return Vector3(-radius, height, along)
		_:
			return Vector3(radius, height, along)


func _ridge_radial_offset(along: float, depth: float, side: int) -> float:
	# Break the mathematically straight ridge walls into long eroded shoulders,
	# shallow gullies and exposed rock ribs. The same deterministic field is
	# sampled by both LOD meshes, so the silhouette does not morph at the switch.
	var slope_mask := pow(maxf(0.0, sin(PI * depth)), 1.15)
	var broad_shoulder := sin(along * 0.038 + float(side) * 2.1) * 8.0
	var broken_spur := sin(along * 0.091 - depth * 8.0 + float(side) * 1.37) * 3.8
	var erosion_cut := cos(along * 0.153 + depth * 17.0 - float(side)) * 1.65
	return (broad_shoulder + broken_spur + erosion_cut) * slope_mask


func _ridge_height(along: float, depth: float, side: int) -> float:
	var end_fade := smoothstep(0.0, 1.0, clampf((RIDGE_HALF_LENGTH - absf(along)) / 42.0, 0.0, 1.0))
	var slope_mask := pow(maxf(0.0, sin(PI * depth)), 0.82)
	var rolling_peaks := 0.5 + 0.5 * sin(along * 0.031 + float(side) * 1.7) + 0.16 * cos(along * 0.073 - float(side))
	var sharp_crag := pow(maxf(0.0, sin(along * 0.067 + float(side) * 2.7)), 5.0) * 13.0
	var broken_faces := sin(along * 0.137 + depth * 19.0 + float(side) * 1.9) * 3.2
	var cross_gullies := cos(along * 0.047 - depth * 31.0 + float(side) * 0.8) * 2.1
	var peak_height := 62.0 + rolling_peaks * 46.0 + sharp_crag + broken_faces + cross_gullies
	return maxf(0.0, peak_height * slope_mask * end_fade)


func _ridge_color(along: float, depth: float, side: int) -> Color:
	# Grassy lower slopes and ridgelines are interrupted by exposed, weathered
	# sediment bands. The deterministic bands are vertex colors on the same
	# four ridge meshes: no extra material passes or draw calls are introduced.
	var slope_cover := sin(PI * depth)
	var height := _ridge_height(along, depth, side)
	var variation := 0.5 + 0.5 * sin(along * 0.11 + float(side) * 2.3)
	var dark_green := Color("#294C2C")
	var meadow_green := Color("#60964A")
	var grass := dark_green.lerp(meadow_green, 0.22 + slope_cover * 0.55)
	grass = grass.lerp(Color("#9AB85D"), variation * slope_cover * 0.22)
	var strata_wave := sin(along * 0.047 + depth * 23.0 + float(side) * 1.9)
	var exposed_rock := smoothstep(0.18, 0.78, absf(cos(PI * depth))) * smoothstep(24.0, 58.0, height)
	var band_mask := smoothstep(0.05, 0.72, strata_wave) * exposed_rock
	var rock_base := Color("#716C5B").lerp(Color("#8C8068"), 0.35 + variation * 0.28)
	var dark_strata := Color("#4E5148")
	var layered_rock := dark_strata.lerp(rock_base, smoothstep(-0.25, 0.55, strata_wave))
	return grass.lerp(layered_rock, clampf(band_mask * 0.88, 0.0, 0.88))


func _build_highway_tunnels() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("#777E78")
	concrete.roughness = 0.94
	var interior := StandardMaterial3D.new()
	interior.albedo_color = Color("#202723")
	interior.roughness = 1.0
	var road_edge := StandardMaterial3D.new()
	road_edge.albedo_color = Color("#B5B9AE")
	road_edge.roughness = 0.9
	for side in [0, 1]:
		var side_sign := -1.0 if side == 0 else 1.0
		var tunnel_name := "NorthHighwayTunnel" if side == 0 else "SouthHighwayTunnel"
		var tunnel := Node3D.new()
		tunnel.name = tunnel_name
		var center_z := side_sign * (RIDGE_INNER_RADIUS + RIDGE_OUTER_RADIUS) * 0.5
		var length := RIDGE_OUTER_RADIUS - RIDGE_INNER_RADIUS
		for wall_side in [-1.0, 1.0]:
			_make_tunnel_box(tunnel, "InteriorSideWall", Vector3(2.0, TUNNEL_WALL_HEIGHT, length), Vector3(TUNNEL_CENTER_X + wall_side * (TUNNEL_OPENING_WIDTH * 0.5), TUNNEL_WALL_HEIGHT * 0.5, center_z), interior)
		_make_tunnel_box(tunnel, "InteriorCeiling", Vector3(TUNNEL_OPENING_WIDTH + 2.0, 2.0, length), Vector3(TUNNEL_CENTER_X, TUNNEL_WALL_HEIGHT + 1.0, center_z), interior)
		_make_tunnel_box(tunnel, "TunnelRoadEdgeNorth", Vector3(0.45, 0.16, length), Vector3(TUNNEL_CENTER_X - TUNNEL_OPENING_WIDTH * 0.5 + 1.0, 0.12, center_z), road_edge)
		_make_tunnel_box(tunnel, "TunnelRoadEdgeSouth", Vector3(0.45, 0.16, length), Vector3(TUNNEL_CENTER_X + TUNNEL_OPENING_WIDTH * 0.5 - 1.0, 0.12, center_z), road_edge)
		for portal_index in range(2):
			var portal_radius := RIDGE_INNER_RADIUS if portal_index == 0 else RIDGE_OUTER_RADIUS
			var portal_z := side_sign * portal_radius
			var portal_prefix := "InnerPortal" if portal_index == 0 else "OuterPortal"
			for frame_side in [-1.0, 1.0]:
				_make_tunnel_box(tunnel, portal_prefix + "Pillar", Vector3(3.0, TUNNEL_WALL_HEIGHT + 1.0, 4.0), Vector3(TUNNEL_CENTER_X + frame_side * (TUNNEL_OPENING_WIDTH * 0.5 + 1.5), (TUNNEL_WALL_HEIGHT + 1.0) * 0.5, portal_z), concrete)
			_make_tunnel_box(tunnel, portal_prefix + "Lintel", Vector3(TUNNEL_OPENING_WIDTH + 7.0, 3.0, 4.0), Vector3(TUNNEL_CENTER_X, TUNNEL_WALL_HEIGHT + 0.5, portal_z), concrete)
			# A stepped crown, flared retaining wings and amber portal markers
			# give the opening a readable road-engineering silhouette at distance.
			_make_tunnel_box(tunnel, portal_prefix + "CrownCap", Vector3(TUNNEL_OPENING_WIDTH + 10.0, 0.65, 4.8), Vector3(TUNNEL_CENTER_X, TUNNEL_WALL_HEIGHT + 2.15, portal_z), concrete)
			for wing_side in [-1.0, 1.0]:
				var wing := _make_tunnel_box(tunnel, portal_prefix + "RetainingWing", Vector3(8.0, 9.0, 3.2), Vector3(TUNNEL_CENTER_X + wing_side * 25.0, 4.5, portal_z + side_sign * 3.2), concrete)
				wing.rotation.y = -wing_side * 0.28 * side_sign
			var reflector_material := StandardMaterial3D.new()
			reflector_material.albedo_color = Color("#E6B64E")
			reflector_material.emission_enabled = true
			reflector_material.emission = Color("#A87928")
			reflector_material.emission_energy_multiplier = 0.22
			for marker_side in [-1.0, 1.0]:
				_make_tunnel_box(tunnel, portal_prefix + "AmberReflector", Vector3(0.34, 0.72, 0.16), Vector3(TUNNEL_CENTER_X + marker_side * (TUNNEL_OPENING_WIDTH * 0.5 + 1.5), 3.2, portal_z + side_sign * 2.12), reflector_material)
			if portal_index == 0:
				var dark_mouth := StandardMaterial3D.new()
				dark_mouth.albedo_color = Color("#101713")
				dark_mouth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_make_tunnel_box(tunnel, portal_prefix + "DarkInteriorMouth", Vector3(TUNNEL_OPENING_WIDTH - 2.0, TUNNEL_WALL_HEIGHT - 1.5, 0.18), Vector3(TUNNEL_CENTER_X, (TUNNEL_WALL_HEIGHT - 1.5) * 0.5, portal_z + side_sign * 1.8), dark_mouth)
		# Repeated ceiling ribs and short centerline dashes use two MultiMeshes
		# per tunnel, avoiding a node per lamp/marking along the 180 m bore.
		var rib_mesh := BoxMesh.new()
		rib_mesh.size = Vector3(TUNNEL_OPENING_WIDTH - 1.0, 0.22, 0.42)
		var rib_batch := MultiMesh.new()
		rib_batch.transform_format = MultiMesh.TRANSFORM_3D
		rib_batch.mesh = rib_mesh
		rib_batch.instance_count = 12
		for rib_index in range(12):
			var z := side_sign * (RIDGE_INNER_RADIUS + 10.0 + float(rib_index) * 14.0)
			rib_batch.set_instance_transform(rib_index, Transform3D(Basis.IDENTITY, Vector3(TUNNEL_CENTER_X, TUNNEL_WALL_HEIGHT - 0.1, z)))
		var ribs := MultiMeshInstance3D.new()
		ribs.name = "TunnelCeilingRibs"
		ribs.multimesh = rib_batch
		ribs.material_override = road_edge
		ribs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tunnel.add_child(ribs)
		var dash_mesh := BoxMesh.new()
		dash_mesh.size = Vector3(0.22, 0.025, 2.2)
		var dash_batch := MultiMesh.new()
		dash_batch.transform_format = MultiMesh.TRANSFORM_3D
		dash_batch.mesh = dash_mesh
		dash_batch.instance_count = 18
		for dash_index in range(18):
			var z := side_sign * (RIDGE_INNER_RADIUS + 5.0 + float(dash_index) * 9.5)
			dash_batch.set_instance_transform(dash_index, Transform3D(Basis.IDENTITY, Vector3(TUNNEL_CENTER_X, 0.205, z)))
		var dashes := MultiMeshInstance3D.new()
		dashes.name = "TunnelCenterlineDashes"
		dashes.multimesh = dash_batch
		dashes.material_override = road_edge
		dashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tunnel.add_child(dashes)
		add_child(tunnel)


func _make_tunnel_box(parent: Node3D, node_name: String, dimensions: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = dimensions
	instance.mesh = box
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance



func _create_rock_outcrop_mesh() -> ArrayMesh:
	# A fractured sandstone mass built from four deliberately discontinuous
	# height bands. Deep radial notches are part of the silhouette, not decals.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SECTORS := 18
	var ring_foot: Array[Vector3] = []
	var ring_lower: Array[Vector3] = []
	var ring_middle: Array[Vector3] = []
	var ring_crown: Array[Vector3] = []
	var fracture_sectors: Array[int] = [2, 8, 14]
	for index in range(SECTORS):
		var angle := TAU * float(index) / float(SECTORS)
		var a := sin(float(index) * 2.31 + 0.7)
		var b := cos(float(index) * 3.17 + 1.4)
		var c := sin(float(index) * 4.73 + 0.2)
		var notch := 0.0
		for fracture_sector in fracture_sectors:
			var distance := mini(absi(index - fracture_sector), SECTORS - absi(index - fracture_sector))
			if distance == 0:
				notch = 0.29
			elif distance == 1:
				notch = 0.13
		var angle_jitter := angle + a * 0.055
		var foot_radius := 0.82 + a * 0.13 + b * 0.055
		var lower_radius := 0.73 + b * 0.15 + c * 0.06 - notch * 0.52
		var middle_radius := 0.64 + c * 0.14 - a * 0.07 - notch
		var crown_radius := 0.47 + a * 0.12 + b * 0.05 - notch * 0.72
		var foot_y := -0.07 + b * 0.07
		var lower_y := 0.30 + a * 0.16
		var middle_y := 0.82 + b * 0.23
		var crown_y := 1.30 + c * 0.24
		ring_foot.append(Vector3(cos(angle_jitter) * foot_radius, foot_y, sin(angle_jitter) * foot_radius))
		ring_lower.append(Vector3(cos(angle_jitter + 0.025) * lower_radius, lower_y, sin(angle_jitter + 0.025) * lower_radius))
		ring_middle.append(Vector3(cos(angle_jitter - 0.035) * middle_radius, middle_y, sin(angle_jitter - 0.035) * middle_radius))
		ring_crown.append(Vector3(cos(angle_jitter + 0.045) * crown_radius, crown_y, sin(angle_jitter + 0.045) * crown_radius))

	var peak_a := Vector3(0.30, 2.08, -0.22)
	var peak_b := Vector3(-0.38, 1.72, 0.28)
	var peak_c := Vector3(0.04, 1.91, 0.48)
	var bottom_center := Vector3(0.0, -0.13, 0.0)
	for index in range(SECTORS):
		var next_index := (index + 1) % SECTORS
		var variation := 0.82 + 0.16 * sin(float(index) * 2.07 + 0.6)
		var lower_color := Color(0.36, 0.34, 0.29) * variation
		var middle_color := Color(0.53, 0.46, 0.36) * (0.88 + 0.12 * cos(float(index) * 1.81))
		var upper_color := Color(0.66, 0.58, 0.45) * (0.86 + 0.14 * sin(float(index) * 2.77))
		# Foot and lower ledge: alternating triangulation creates sharp facets.
		surface.set_color(lower_color)
		surface.add_vertex(ring_foot[index])
		surface.add_vertex(ring_lower[index])
		surface.add_vertex(ring_foot[next_index])
		surface.set_color(lower_color * 0.78)
		surface.add_vertex(ring_foot[next_index])
		surface.add_vertex(ring_lower[index])
		surface.add_vertex(ring_lower[next_index])
		# Middle strata: radial insets form three deep, angular fracture gulfs.
		surface.set_color(middle_color)
		surface.add_vertex(ring_lower[index])
		surface.add_vertex(ring_middle[index])
		surface.add_vertex(ring_lower[next_index])
		surface.set_color(middle_color * 0.72)
		surface.add_vertex(ring_lower[next_index])
		surface.add_vertex(ring_middle[index])
		surface.add_vertex(ring_middle[next_index])
		# Upper broken shoulders are not a smooth cone; each facet terminates
		# at one of three offset peaks, producing an unmistakable split crown.
		var apex := peak_a if index < 6 else (peak_b if index < 12 else peak_c)
		surface.set_color(upper_color)
		surface.add_vertex(ring_middle[index])
		surface.add_vertex(ring_crown[index])
		surface.add_vertex(ring_middle[next_index])
		surface.set_color(upper_color * 0.88)
		surface.add_vertex(ring_middle[next_index])
		surface.add_vertex(ring_crown[index])
		surface.add_vertex(ring_crown[next_index])
		surface.set_color(upper_color * (0.88 if index % 2 == 0 else 0.68))
		surface.add_vertex(ring_crown[index])
		surface.add_vertex(apex)
		surface.add_vertex(ring_crown[next_index])
		# Dark, recessed V cuts continue from the upper fractures into the foot.
		if fracture_sectors.has(index):
			var angle := TAU * float(index) / float(SECTORS)
			_append_rock_fracture_groove(surface, angle, 1.0 + float(index % 3) * 0.16)
		# A darker basal facet gives the mesh a grounded, undercut foot.
		surface.set_color(lower_color * 0.58)
		# Reverse winding so the closed underside faces downward.
		surface.add_vertex(bottom_center)
		surface.add_vertex(ring_foot[index])
		surface.add_vertex(ring_foot[next_index])

	# Join the three offset crown peaks into a closed, fractured roof.
	surface.set_color(Color(0.43, 0.39, 0.32))
	surface.add_vertex(peak_a)
	surface.add_vertex(peak_b)
	surface.add_vertex(ring_crown[6])
	surface.set_color(Color(0.36, 0.34, 0.29))
	surface.add_vertex(peak_b)
	surface.add_vertex(peak_c)
	surface.add_vertex(ring_crown[12])
	surface.set_color(Color(0.48, 0.42, 0.34))
	surface.add_vertex(peak_c)
	surface.add_vertex(peak_a)
	surface.add_vertex(ring_crown[0])
	# Broken talus is fused into the same surface and remains a single draw call.
	_append_rock_foot_pebbles(surface)
	surface.generate_normals()
	return surface.commit()

func _append_rock_fracture_groove(surface: SurfaceTool, angle: float, strength: float) -> void:
	# A broad V-shaped inset: dark floor sits behind two lighter fractured lips.
	var radial := Vector3(cos(angle), 0.0, sin(angle))
	var tangent := Vector3(-radial.z, 0.0, radial.x)
	var lower := radial * 0.43 + Vector3(0.0, 0.18, 0.0)
	var middle := radial * 0.34 + Vector3(0.0, 0.76, 0.0)
	var upper := radial * 0.39 + Vector3(0.0, 1.34, 0.0)
	var width := 0.095 * strength
	var lower_left := lower - tangent * width
	var lower_right := lower + tangent * width
	var middle_left := middle - tangent * width * 0.76
	var middle_right := middle + tangent * width * 0.76
	var upper_left := upper - tangent * width * 0.34
	var upper_right := upper + tangent * width * 0.34
	surface.set_color(Color(0.055, 0.062, 0.058))
	surface.add_vertex(lower_left)
	surface.add_vertex(middle_left)
	surface.add_vertex(lower_right)
	surface.add_vertex(lower_right)
	surface.add_vertex(middle_left)
	surface.add_vertex(middle_right)
	surface.add_vertex(middle_left)
	surface.add_vertex(upper_left)
	surface.add_vertex(middle_right)
	surface.add_vertex(middle_right)
	surface.add_vertex(upper_left)
	surface.add_vertex(upper_right)
	# Thin mineral lips catch light on both sides of the inset.
	surface.set_color(Color(0.76, 0.66, 0.49) * strength)
	surface.add_vertex(lower_left - tangent * 0.025)
	surface.add_vertex(middle_left - tangent * 0.020)
	surface.add_vertex(lower_left)
	surface.add_vertex(middle_right)
	surface.add_vertex(upper_right + tangent * 0.012)
	surface.add_vertex(upper_right)

func _append_rock_foot_pebbles(surface: SurfaceTool) -> void:
	for pebble_index in range(ROCK_FOOT_PEBBLE_COUNT):
		var angle := TAU * float(pebble_index) / 4.0 + 0.42
		var radial_distance := 0.62 + float(pebble_index % 2) * 0.075
		var center := Vector3(cos(angle) * radial_distance, -0.005, sin(angle) * radial_distance)
		var radius := 0.105 + float(pebble_index % 2) * 0.025
		var height := 0.095 + float(pebble_index % 3) * 0.018
		var tone := 0.76 + float(pebble_index % 3) * 0.07
		_append_rock_pebble(surface, center, radius, height, tone)


func _append_rock_pebble(surface: SurfaceTool, center: Vector3, radius: float, height: float, tone: float) -> void:
	var sides := 5
	var ring: Array[Vector3] = []
	for index in range(sides):
		var angle := TAU * float(index) / float(sides)
		var wobble := 0.88 + 0.12 * sin(float(index) * 2.7 + tone)
		ring.append(center + Vector3(cos(angle) * radius * wobble, 0.0, sin(angle) * radius * wobble))
	var top := center + Vector3(0.018, height, -0.012)
	var bottom := center + Vector3(0.0, -height * 0.20, 0.0)
	for index in range(sides):
		var next_index := (index + 1) % sides
		var pebble_color := Color(0.43, 0.405, 0.35) * tone
		surface.set_color(pebble_color)
		surface.add_vertex(ring[index])
		surface.add_vertex(top)
		surface.add_vertex(ring[next_index])
		surface.set_color(pebble_color * 0.72)
		surface.add_vertex(bottom)
		surface.add_vertex(ring[next_index])
		surface.add_vertex(ring[index])


func _create_rock_surface_material() -> ShaderMaterial:
	# Triplanar mineral weathering with chipped polygonal fracture networks.
	# All detail is evaluated in world space: no imported textures, UV seams,
	# extra mesh surfaces or additional draw submissions.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
varying vec3 rock_world_position;
varying vec3 rock_world_normal;
varying float rock_local_height;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash31(i);
	float b = hash31(i + vec3(1.0, 0.0, 0.0));
	float c = hash31(i + vec3(0.0, 1.0, 0.0));
	float d = hash31(i + vec3(1.0, 1.0, 0.0));
	float e = hash31(i + vec3(0.0, 0.0, 1.0));
	float f1 = hash31(i + vec3(1.0, 0.0, 1.0));
	float g = hash31(i + vec3(0.0, 1.0, 1.0));
	float h = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
		mix(mix(e, f1, f.x), mix(g, h, f.x), f.y), f.z);
}

float stone_fbm(vec3 p) {
	float n = 0.0;
	n += value_noise(p) * 0.57;
	n += value_noise(p * 2.13) * 0.28;
	n += value_noise(p * 4.37) * 0.15;
	return n;
}

// Distance between the two closest cellular feature points creates broken,
// branching mineral boundaries instead of the previous parallel sine stripes.
float cellular_edge(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 feature = offset + hash22(cell + offset) * 0.82 + 0.09;
			float distance_to_feature = length(local - feature);
			if (distance_to_feature < nearest) {
				second = nearest;
				nearest = distance_to_feature;
			} else if (distance_to_feature < second) {
				second = distance_to_feature;
			}
		}
	}
	return second - nearest;
}

void vertex() {
	rock_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rock_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	// World-space offset keeps the contact band consistent across rock scales.
	rock_local_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
}

void fragment() {
	vec3 n = abs(normalize(rock_world_normal));
	vec3 p = rock_world_position;
	vec3 tri_weights = pow(max(n, vec3(0.001)), vec3(4.0));
	tri_weights /= max(dot(tri_weights, vec3(1.0)), 0.001);

	float grain_x = stone_fbm(vec3(p.yz * 1.75, 0.0));
	float grain_y = stone_fbm(vec3(p.xz * 1.75, 0.0));
	float grain_z = stone_fbm(vec3(p.xy * 1.75, 0.0));
	float grain = dot(vec3(grain_x, grain_y, grain_z), tri_weights);
	float fine_grain = dot(vec3(
		stone_fbm(vec3(p.yz * 7.6, 0.0)),
		stone_fbm(vec3(p.xz * 7.6, 0.0)),
		stone_fbm(vec3(p.xy * 7.6, 0.0))
	), tri_weights);

	// Three axis projections hide stretching on steep and horizontal faces.
	float crack_x = cellular_edge(p.yz * 1.82 + vec2(grain_x * 0.34));
	float crack_y = cellular_edge(p.xz * 1.82 + vec2(grain_y * 0.34));
	float crack_z = cellular_edge(p.xy * 1.82 + vec2(grain_z * 0.34));
	float crack_edge = dot(vec3(crack_x, crack_y, crack_z), tri_weights);
	float fracture_core = 1.0 - smoothstep(0.028, 0.125, crack_edge);
	float fracture_rim = smoothstep(0.12, 0.22, crack_edge) * (1.0 - smoothstep(0.22, 0.34, crack_edge));

	float strata_noise = stone_fbm(p * vec3(0.12, 0.20, 0.12));
	float strata = sin(p.y * 1.18 + strata_noise * 4.4 + grain * 2.6);
	float sediment = smoothstep(-0.34, 0.46, strata);
	float pores = smoothstep(0.68, 0.91, fine_grain);
	float micro_weathering = mix(0.91, 1.08, fine_grain);

	vec3 dark_mineral = vec3(0.19, 0.205, 0.195);
	vec3 warm_sandstone = vec3(0.59, 0.53, 0.42);
	vec3 cool_slate = vec3(0.34, 0.37, 0.35);
	vec3 base_stone = mix(dark_mineral, warm_sandstone, grain);
	base_stone = mix(base_stone, cool_slate, smoothstep(0.56, 0.88, grain_x) * 0.24);
	base_stone *= mix(0.78, 1.13, sediment);
	base_stone *= mix(vec3(0.72), vec3(1.0), COLOR.rgb);
	base_stone *= micro_weathering;
	base_stone *= 1.0 - fracture_core * 0.82;
	base_stone *= 1.0 - pores * 0.10;
	base_stone = mix(base_stone, base_stone * 1.38, fracture_rim * 0.48);

	// Cheap contact occlusion: no extra light, shadow caster or render pass.
	float contact_band = 1.0 - smoothstep(-0.035, 0.52, rock_local_height);
	float contact_occlusion = mix(1.0, 0.38, contact_band);
	base_stone *= contact_occlusion;

	ALBEDO = base_stone;
	ROUGHNESS = mix(0.88, 0.99, pores);
	METALLIC = 0.0;
	SPECULAR = 0.12;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _build_mountain_rock_outcrops() -> void:
	var rock_mesh := _create_rock_outcrop_mesh()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = rock_mesh
	batch.instance_count = RIDGE_ROCK_COUNT
	var palette: Array[Color] = [Color("#777365"), Color("#8A806C"), Color("#665F53"), Color("#9A8D75")]
	for index in range(RIDGE_ROCK_COUNT):
		var side := index % 4
		var row := int(index / 4)
		var along := -RIDGE_HALF_LENGTH * 0.86 + fposmod(float(row) * 47.3 + float(side) * 17.0, RIDGE_HALF_LENGTH * 1.72)
		var depth := 0.28 + float((row * 17 + side * 9) % 42) / 100.0
		if _is_tunnel_portal_vegetation_exclusion(side, along, depth):
			batch.set_instance_transform(index, _hidden_multimesh_instance_transform())
			continue
		var point := _ridge_point(side, along, depth)
		var size := 1.6 + float((index * 11) % 13) * 0.32
		var yaw := float((index * 67) % 360) * PI / 180.0
		var scale := Vector3(size * (0.72 + float(index % 3) * 0.17), size * (0.78 + float(index % 4) * 0.16), size * (0.68 + float(index % 5) * 0.12))
		var transform := Transform3D(Basis(Vector3.UP, yaw).scaled(scale), point + Vector3(0.0, -0.25, 0.0))
		batch.set_instance_transform(index, transform)
		batch.set_instance_color(index, palette[index % palette.size()])
	var rocks := MultiMeshInstance3D.new()
	rocks.name = "MountainNearRockOutcrops"
	rocks.multimesh = batch
	rocks.material_override = _create_rock_surface_material()
	# Rocks use shader-based basal occlusion and geometric recesses only; no
	# per-rock shadow casters are submitted to the mobile directional shadow map.
	rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rocks.visibility_range_end = RIDGE_DETAIL_DISTANCE
	rocks.visibility_range_end_margin = 14.0
	add_child(rocks)


func _build_mountain_shrubs() -> void:
	var shrub_mesh := SphereMesh.new()
	shrub_mesh.radius = 1.0
	shrub_mesh.height = 1.5
	shrub_mesh.radial_segments = 7
	shrub_mesh.rings = 4
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = shrub_mesh
	multimesh.instance_count = SHRUB_COUNT
	var palette: Array[Color] = [Color("#173A22"), Color("#20472A"), Color("#285331"), Color("#315B35")]
	for index in range(SHRUB_COUNT):
		var side := index % 4
		var row := int(index / 4)
		var along := -RIDGE_HALF_LENGTH * 0.88 + fposmod(float(row) * 37.17, RIDGE_HALF_LENGTH * 1.76)
		var depth := 0.18 + float((row * 7) % 58) / 100.0
		if _is_tunnel_portal_vegetation_exclusion(side, along, depth):
			multimesh.set_instance_transform(index, _hidden_multimesh_instance_transform())
			continue
		var point := _ridge_point(side, along, depth)
		var scale := 1.0 + float((index * 13) % 11) * 0.13
		var basis := Basis(Vector3.UP, float((index * 29) % 360) * PI / 180.0).scaled(Vector3(scale, scale * 0.72, scale))
		multimesh.set_instance_transform(index, Transform3D(basis, point + Vector3(0.0, 0.65 * scale, 0.0)))
		multimesh.set_instance_color(index, palette[index % palette.size()])
	var shrubs := MultiMeshInstance3D.new()
	shrubs.name = "DarkGreenMountainShrubs"
	shrubs.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	shrubs.material_override = material
	shrubs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shrubs)


func _build_mountain_grass() -> void:
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.16, 0.72, 0.14)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = blade_mesh
	multimesh.instance_count = GRASS_COUNT
	var palette: Array[Color] = [Color("#23492B"), Color("#315B32"), Color("#3B6638"), Color("#1C4227")]
	for index in range(GRASS_COUNT):
		var side := index % 4
		var row := int(index / 4)
		var along := -RIDGE_HALF_LENGTH * 0.91 + fposmod(float(row) * 19.73, RIDGE_HALF_LENGTH * 1.82)
		var depth := 0.12 + float((row * 11) % 72) / 100.0
		if _is_tunnel_portal_vegetation_exclusion(side, along, depth):
			multimesh.set_instance_transform(index, _hidden_multimesh_instance_transform())
			continue
		var point := _ridge_point(side, along, depth)
		var scale := 0.55 + float((index * 5) % 9) * 0.12
		var yaw := float((index * 47) % 360) * PI / 180.0
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
		multimesh.set_instance_transform(index, Transform3D(basis, point + Vector3(0.0, 0.32 * scale, 0.0)))
		multimesh.set_instance_color(index, palette[index % palette.size()])
	var grass := MultiMeshInstance3D.new()
	grass.name = "MountainDarkGrass"
	grass.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	grass.material_override = material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)



func _build_mountain_eucalypts() -> void:
	# Silvery Australian gums: tapered leaning trunks and asymmetrical clustered
	# crowns. Trunks and foliage remain two shared MultiMesh submissions.
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.105
	trunk_mesh.bottom_radius = 0.30
	trunk_mesh.height = 6.2
	trunk_mesh.radial_segments = 7
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color("#BDB39A")
	trunk_material.roughness = 1.0
	var crown_mesh := _create_mountain_eucalypt_crown_mesh()
	var crown_material := StandardMaterial3D.new()
	crown_material.vertex_color_use_as_albedo = true
	crown_material.roughness = 1.0
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = EUCALYPT_COUNT
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.use_colors = true
	crowns.mesh = crown_mesh
	crowns.instance_count = EUCALYPT_COUNT
	var foliage: Array[Color] = [
		Color("#617F72"), Color("#7F9481"), Color("#526F68"),
		Color("#8A9A83"), Color("#49685E"), Color("#708A78")
	]
	for index in range(EUCALYPT_COUNT):
		var side := index % 4
		var row := int(index / 4)
		var along := -RIDGE_HALF_LENGTH * 0.84 + fposmod(float(row) * 53.7 + float(side) * 29.0, RIDGE_HALF_LENGTH * 1.68)
		var depth := 0.24 + float((row * 13 + side * 7) % 48) / 100.0
		if _is_tunnel_portal_vegetation_exclusion(side, along, depth):
			var hidden_transform := _hidden_multimesh_instance_transform()
			trunks.set_instance_transform(index, hidden_transform)
			crowns.set_instance_transform(index, hidden_transform)
			continue
		var point := _ridge_point(side, along, depth)
		var tree_scale := 0.78 + float((index * 7) % 11) * 0.105
		var yaw := float((index * 41) % 360) * PI / 180.0
		var lean := deg_to_rad(-10.0 + float((index * 17) % 23))
		var yaw_basis := Basis(Vector3.UP, yaw)
		var trunk_basis := yaw_basis * Basis(Vector3(0.0, 0.0, 1.0), lean)
		var trunk_origin := point + Vector3(0.0, 3.05 * tree_scale, 0.0)
		var crown_offset := yaw_basis * Vector3(sin(lean) * 1.1, 6.0 * tree_scale, cos(lean) * 0.12)
		var crown_origin := point + crown_offset
		var trunk_scale := Vector3(tree_scale * (0.82 + float(index % 3) * 0.12), tree_scale, tree_scale * (0.82 + float(index % 4) * 0.09))
		var crown_scale := Vector3(0.76 + float(index % 4) * 0.10, 1.18 + float((index * 3) % 5) * 0.13, 0.70 + float((index * 7) % 4) * 0.12)
		trunks.set_instance_transform(index, Transform3D(trunk_basis.scaled(trunk_scale), trunk_origin))
		crowns.set_instance_transform(index, Transform3D(yaw_basis.scaled(crown_scale * tree_scale), crown_origin))
		crowns.set_instance_color(index, foliage[index % foliage.size()])
	var trunk_batch := MultiMeshInstance3D.new()
	trunk_batch.name = "AustralianEucalyptTrunks"
	trunk_batch.multimesh = trunks
	trunk_batch.material_override = trunk_material
	trunk_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trunk_batch)
	var crown_batch := MultiMeshInstance3D.new()
	crown_batch.name = "AustralianEucalyptCanopies"
	crown_batch.multimesh = crowns
	crown_batch.material_override = crown_material
	crown_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crown_batch)


func _create_mountain_eucalypt_crown_mesh() -> ArrayMesh:
	# Four offset leaf masses make the gum crown asymmetric without adding draw calls.
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 9
	sphere.rings = 6
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := [
		[Vector3(0.0, 0.0, 0.0), Vector3(0.72, 1.0, 0.72)],
		[Vector3(-0.48, 0.16, 0.12), Vector3(0.58, 0.76, 0.62)],
		[Vector3(0.44, -0.08, -0.18), Vector3(0.62, 0.82, 0.56)],
		[Vector3(0.10, 0.36, 0.42), Vector3(0.52, 0.68, 0.54)]
	]
	for lobe in lobes:
		var offset: Vector3 = lobe[0]
		var scale: Vector3 = lobe[1]
		surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY.scaled(scale), offset))
	return surface.commit()

