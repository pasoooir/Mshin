extends Node3D

var _road_system_cache: Node
var _expansion_preview_active := false

const CargoShipVisualScript = preload("res://scripts/world/CargoShipVisual.gd")
const MeadowLivestockScript = preload("res://scripts/world/MeadowLivestock.gd")
const StylizedFoliageSystemScript = preload("res://scripts/world/StylizedFoliageSystem.gd")

const TERRAIN_HALF_DEPTH := 145.0
const TERRAIN_LEFT := -120.0
const TERRAIN_DIVISIONS := 128
const CITY_HALF_EXTENT := 40

# Permanent six-lane divided motorway at the city entrance. Keep the access
# opening aligned with the seeded Gateway connector and outside the build grid.
const HIGHWAY_CENTER_X := -55.0
const HIGHWAY_ASPHALT_WIDTH := 24.0
const HIGHWAY_SHOULDER_WIDTH := 26.8
const HIGHWAY_LENGTH := 700.0
const HIGHWAY_LANE_COUNT := 6
const HIGHWAY_MEDIAN_WIDTH := 0.8
const HIGHWAY_LAMP_COUNT := 12
const MEADOW_SHEEP_COUNT := 12
const MEADOW_CATTLE_COUNT := 3
const ENVIRONMENT_SMALL_DETAIL_END := 145.0
const ENVIRONMENT_SMALL_DETAIL_MARGIN := 22.0
const TREE_BELT_DETAIL_END := 420.0
const TREE_BELT_DETAIL_MARGIN := 36.0
const COASTAL_GREEN_PALETTE := [
	Color("#536B45"), Color("#66764A"), Color("#77734B"),
	Color("#465F43"), Color("#7B8052"), Color("#5D7048")
]
const COASTLINE_BASE_X := 110.0
const BEACH_WIDTH := 26.0
const PROMENADE_OFFSET := 12.0
const PALM_COUNT := 24

func _ready() -> void:
	# Headless CI validates simulation and placement logic, not GPU geometry.
	# Preserve the stable scene contract with lightweight Node3D markers while
	# skipping all procedural meshes and MultiMesh resources.
	if DisplayServer.get_name() == "headless":
		_add_headless_test_markers()
		print("[WorldPresentation] Procedural visuals skipped in headless test mode")
		return
	RegionManager.region_changed.connect(_on_region_changed)
	LandExpansionManager.land_changed.connect(_on_land_expansion_changed)
	BuildManager.placement_mode_changed.connect(_refresh_build_grid_visibility)
	_road_system_cache = get_parent().get_node_or_null("RoadSystem")
	if is_instance_valid(_road_system_cache) and _road_system_cache.has_signal("road_mode_changed"):
		_road_system_cache.connect("road_mode_changed", Callable(self, "_on_road_mode_changed"))
	_build_environment()
	_build_terrain()
	_build_meadow_biome_overlays()
	_build_sandy_beach()
	_build_land_expansion_markers()
	_build_city_grid()
	_build_coastal_highway()
	_build_highway_lighting()
	_build_tree_belts()
	_build_grass_detail()
	# Retire the isolated timber strip; render a proper surf edge instead.
	_build_shoreline_foam()
	_build_beach_palms()
	_build_shoreline_details()
	_build_cargo_ship_visual()
	_build_sunlight()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.34, 0.55)
	sky_material.sky_horizon_color = Color(0.72, 0.84, 0.91)
	sky_material.ground_bottom_color = Color(0.13, 0.19, 0.17)
	sky_material.ground_horizon_color = Color(0.55, 0.63, 0.61)
	_apply_region_climate(sky_material, environment)
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.96
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.82, 0.82)
	environment.fog_density = 0.00065
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world_environment.environment = environment
	add_child(world_environment)


func _apply_region_climate(sky_material: ProceduralSkyMaterial, environment: Environment) -> void:
	var climate := str(RegionManager.get_active_region().get("climate", "temperate"))
	match climate:
		"tropical":
			sky_material.sky_top_color = Color("#176A9A")
			sky_material.sky_horizon_color = Color("#A7DCE7")
			sky_material.ground_bottom_color = Color("#285B4B")
			sky_material.ground_horizon_color = Color("#6C9B84")
			environment.fog_light_color = Color("#A9D5D5")
		"arctic":
			sky_material.sky_top_color = Color("#405A79")
			sky_material.sky_horizon_color = Color("#D4E2EB")
			sky_material.ground_bottom_color = Color("#899BA7")
			sky_material.ground_horizon_color = Color("#C0D0D8")
			environment.fog_light_color = Color("#C4D4DF")
		"desert":
			sky_material.sky_top_color = Color("#9A603A")
			sky_material.sky_horizon_color = Color("#F0C88E")
			sky_material.ground_bottom_color = Color("#8B6B43")
			sky_material.ground_horizon_color = Color("#C7A36B")
			environment.fog_light_color = Color("#E6C89D")
		"lush":
			sky_material.sky_top_color = Color("#226A75")
			sky_material.sky_horizon_color = Color("#B7D9A8")
			sky_material.ground_bottom_color = Color("#244C32")
			sky_material.ground_horizon_color = Color("#6E9860")
			environment.fog_light_color = Color("#B9D4AE")
		"mediterranean":
			sky_material.sky_top_color = Color("#3977A5")
			sky_material.sky_horizon_color = Color("#E8D0A3")
			sky_material.ground_bottom_color = Color("#596342")
			sky_material.ground_horizon_color = Color("#A9A078")
			environment.fog_light_color = Color("#D9D0B7")
		"temperate":
			# Pacific coastal climate: clear blue sky, luminous horizon and rich green land.
			sky_material.sky_top_color = Color("#287BB0")
			sky_material.sky_horizon_color = Color("#B8D9D1")
			sky_material.ground_bottom_color = Color("#245A35")
			sky_material.ground_horizon_color = Color("#A4C98D")
			environment.fog_light_color = Color("#C7E5D5")
		_:
			sky_material.sky_top_color = Color("#287BB0")
			sky_material.sky_horizon_color = Color("#B8D9D1")
			sky_material.ground_bottom_color = Color("#315B39")
			sky_material.ground_horizon_color = Color("#83A96F")
			environment.fog_light_color = Color("#C0D8C4")

func _on_region_changed(_region_id: String) -> void:
	refresh_region_appearance()

func refresh_region_appearance() -> void:
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if is_instance_valid(world_environment) and world_environment.environment != null and world_environment.environment.sky != null:
		var sky_material := world_environment.environment.sky.sky_material as ProceduralSkyMaterial
		if is_instance_valid(sky_material):
			_apply_region_climate(sky_material, world_environment.environment)
	for node_name in ["NaturalTerrain", "MeadowBiomePatches", "CoastalWater", "ShallowWater", "LandExpansionMarkers", "BuildablePlotGrid"]:
		var old_node := get_node_or_null(node_name)
		if is_instance_valid(old_node):
			old_node.free()
	_build_terrain()
	_build_meadow_biome_overlays()
	_build_land_expansion_markers()
	_build_city_grid()


func _on_land_expansion_changed() -> void:
	for node_name in ["NaturalTerrain", "MeadowBiomePatches", "CoastalWater", "ShallowWater", "LandExpansionMarkers", "BuildablePlotGrid"]:
		var old_node := get_node_or_null(node_name)
		if is_instance_valid(old_node):
			old_node.free()
	_build_terrain()
	_build_meadow_biome_overlays()
	_build_land_expansion_markers()
	_build_city_grid()


func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions := TERRAIN_DIVISIONS
	for z_index in range(divisions):
		var z0 := -TERRAIN_HALF_DEPTH + (float(z_index) / divisions) * TERRAIN_HALF_DEPTH * 2.0
		var z1 := -TERRAIN_HALF_DEPTH + (float(z_index + 1) / divisions) * TERRAIN_HALF_DEPTH * 2.0
		var coast0 := _coastline(z0)
		var coast1 := _coastline(z1)
		for x_index in range(divisions):
			var u0 := float(x_index) / divisions
			var u1 := float(x_index + 1) / divisions
			var x00 := lerpf(TERRAIN_LEFT, coast0, u0)
			var x10 := lerpf(TERRAIN_LEFT, coast0, u1)
			var x01 := lerpf(TERRAIN_LEFT, coast1, u0)
			var x11 := lerpf(TERRAIN_LEFT, coast1, u1)
			_add_terrain_vertex(surface, Vector3(x00, 0.0, z0))
			_add_terrain_vertex(surface, Vector3(x01, 0.0, z1))
			_add_terrain_vertex(surface, Vector3(x10, 0.0, z0))
			_add_terrain_vertex(surface, Vector3(x10, 0.0, z0))
			_add_terrain_vertex(surface, Vector3(x01, 0.0, z1))
			_add_terrain_vertex(surface, Vector3(x11, 0.0, z1))
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "NaturalTerrain"
	terrain.mesh = surface.commit()
	var terrain_material := _create_natural_ground_material()
	terrain.material_override = terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)

	# Both water bands follow the exact sampled coastline instead of using
	# fixed rectangles. This keeps the beach and sea aligned to the sampled coastline
	# without exposing terrain slivers or burying the shoreline.
	var water := MeshInstance3D.new()
	water.name = "CoastalWater"
	water.mesh = _create_coastal_water_mesh(32.0, 1100.0, 280, 72, 0.015)
	water.material_override = _create_water_material()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	var shallow_water := MeshInstance3D.new()
	shallow_water.name = "ShallowWater"
	shallow_water.mesh = _create_coastal_water_mesh(0.16, 34.0, 280, 28, 0.008)
	shallow_water.material_override = _create_shallow_water_material()
	shallow_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shallow_water)


func _create_coastal_water_mesh(shore_offset: float, far_edge: float, rows: int, columns: int, water_y: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows):
		var z0 := lerpf(-TERRAIN_HALF_DEPTH, TERRAIN_HALF_DEPTH, float(row) / float(rows))
		var z1 := lerpf(-TERRAIN_HALF_DEPTH, TERRAIN_HALF_DEPTH, float(row + 1) / float(rows))
		var coast_x0 := _coastline(z0)
		var coast_x1 := _coastline(z1)
		var near_x0 := coast_x0 + shore_offset
		var near_x1 := coast_x1 + shore_offset
		# Values up to 100 m are coast-relative shallow-water widths; larger values are fixed offshore bounds.
		var far_x0 := coast_x0 + far_edge if far_edge <= 100.0 else far_edge
		var far_x1 := coast_x1 + far_edge if far_edge <= 100.0 else far_edge
		for column in range(columns):
			var u0 := float(column) / float(columns)
			var u1 := float(column + 1) / float(columns)
			var x00 := lerpf(near_x0, far_x0, u0)
			var x10 := lerpf(near_x0, far_x0, u1)
			var x01 := lerpf(near_x1, far_x1, u0)
			var x11 := lerpf(near_x1, far_x1, u1)
			var uv00 := Vector2(u0, float(row) / rows)
			var uv10 := Vector2(u1, float(row) / rows)
			var uv01 := Vector2(u0, float(row + 1) / rows)
			var uv11 := Vector2(u1, float(row + 1) / rows)
			surface.set_uv(uv00)
			surface.add_vertex(Vector3(x00, water_y, z0))
			surface.set_uv(uv01)
			surface.add_vertex(Vector3(x01, water_y, z1))
			surface.set_uv(uv10)
			surface.add_vertex(Vector3(x10, water_y, z0))
			surface.set_uv(uv10)
			surface.add_vertex(Vector3(x10, water_y, z0))
			surface.set_uv(uv01)
			surface.add_vertex(Vector3(x01, water_y, z1))
			surface.set_uv(uv11)
			surface.add_vertex(Vector3(x11, water_y, z1))
	surface.generate_normals()
	return surface.commit()


func _build_sandy_beach() -> void:
	# A dedicated, continuous sand ribbon guarantees a readable beach in the
	# Compatibility renderer even when terrain shader detail is distance-culled.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const Z_SEGMENTS := 220
	const X_SEGMENTS := 10
	for row in range(Z_SEGMENTS):
		var z0 := lerpf(-TERRAIN_HALF_DEPTH, TERRAIN_HALF_DEPTH, float(row) / float(Z_SEGMENTS))
		var z1 := lerpf(-TERRAIN_HALF_DEPTH, TERRAIN_HALF_DEPTH, float(row + 1) / float(Z_SEGMENTS))
		var coast0 := _coastline(z0)
		var coast1 := _coastline(z1)
		for column in range(X_SEGMENTS):
			var u0 := float(column) / float(X_SEGMENTS)
			var u1 := float(column + 1) / float(X_SEGMENTS)
			var x00 := lerpf(coast0 - BEACH_WIDTH, coast0 + 0.42, u0)
			var x10 := lerpf(coast0 - BEACH_WIDTH, coast0 + 0.42, u1)
			var x01 := lerpf(coast1 - BEACH_WIDTH, coast1 + 0.42, u0)
			var x11 := lerpf(coast1 - BEACH_WIDTH, coast1 + 0.42, u1)
			var p00 := Vector3(x00, _terrain_height(x00, z0) + 0.045, z0)
			var p10 := Vector3(x10, _terrain_height(x10, z0) + 0.045, z0)
			var p01 := Vector3(x01, _terrain_height(x01, z1) + 0.045, z1)
			var p11 := Vector3(x11, _terrain_height(x11, z1) + 0.045, z1)
			var grain := sin(z0 * 0.31 + u0 * 17.0) * 0.035 + cos(z1 * 0.19 - u1 * 13.0) * 0.025
			var dry_sand := Color(0.79, 0.69, 0.51).lerp(Color(0.91, 0.82, 0.64), 0.5 + grain)
			var wetness0 := smoothstep(0.78, 1.0, u0)
			var wetness1 := smoothstep(0.78, 1.0, u1)
			var c00 := dry_sand.lerp(Color(0.55, 0.52, 0.42), wetness0 * 0.52)
			var c10 := dry_sand.lerp(Color(0.55, 0.52, 0.42), wetness1 * 0.52)
			var c01 := dry_sand.lerp(Color(0.55, 0.52, 0.42), wetness0 * 0.52)
			var c11 := dry_sand.lerp(Color(0.55, 0.52, 0.42), wetness1 * 0.52)
			surface.set_color(c00)
			surface.set_uv(Vector2(u0 * 3.0, float(row) / Z_SEGMENTS * 8.0))
			surface.add_vertex(p00)
			surface.set_color(c01)
			surface.set_uv(Vector2(u0 * 3.0, float(row + 1) / Z_SEGMENTS * 8.0))
			surface.add_vertex(p01)
			surface.set_color(c10)
			surface.set_uv(Vector2(u1 * 3.0, float(row) / Z_SEGMENTS * 8.0))
			surface.add_vertex(p10)
			surface.set_color(c10)
			surface.set_uv(Vector2(u1 * 3.0, float(row) / Z_SEGMENTS * 8.0))
			surface.add_vertex(p10)
			surface.set_color(c01)
			surface.set_uv(Vector2(u0 * 3.0, float(row + 1) / Z_SEGMENTS * 8.0))
			surface.add_vertex(p01)
			surface.set_color(c11)
			surface.set_uv(Vector2(u1 * 3.0, float(row + 1) / Z_SEGMENTS * 8.0))
			surface.add_vertex(p11)
	surface.generate_normals()
	var beach := MeshInstance3D.new()
	beach.name = "ContinuousSandyBeach"
	beach.mesh = surface.commit()
	var beach_shader := Shader.new()
	beach_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
varying vec3 beach_world;
void vertex() {
	beach_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float grain = sin(beach_world.x * 1.31 + beach_world.z * 0.87) * 0.018
		+ cos(beach_world.x * 0.47 - beach_world.z * 1.19) * 0.012;
	float wet = smoothstep(0.80, 1.0, UV.x);
	vec3 dry_sand = vec3(0.70, 0.55, 0.37) + vec3(grain);
	vec3 damp_sand = vec3(0.43, 0.37, 0.27) + vec3(grain * 0.35);
	ALBEDO = mix(dry_sand, damp_sand, wet * 0.78);
	ROUGHNESS = 0.98;
	SPECULAR = 0.06;
}
"""
	var material := ShaderMaterial.new()
	material.shader = beach_shader
	beach.material_override = material
	beach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beach)


func _build_meadow_biome_overlays() -> void:
	# The compatibility renderer can flatten subtle procedural shader variation
	# at the mobile overview distance. Add a single deterministic, vertex-colour
	# patch mesh so meadow/soil/olive fields remain visibly distinct in WebGL.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	var palette: Array[Color] = [
		Color("#77815A"), Color("#8C8258"), Color("#6C7E50"),
		Color("#566F46"), Color("#82664C"), Color("#98865D"),
		Color("#687A54")
	]
	var base_edge := Color("#25723D")
	var patch_count := 190
	for patch_index in range(patch_count):
		var center_x := rng.randf_range(-112.0, 88.0)
		var center_z := rng.randf_range(-136.0, 136.0)
		if center_x > _coastline(center_z) - BEACH_WIDTH - 14.0:
			continue
		if absf(center_x - HIGHWAY_CENTER_X) < 15.5 or _is_city_road_footprint(center_x, center_z):
			continue
		var in_starter_city := absf(center_x) < 34.0 and absf(center_z) < 34.0
		var radius_x := rng.randf_range(2.4, 4.2) if in_starter_city else rng.randf_range(4.5, 8.8)
		var radius_z := radius_x * rng.randf_range(0.62, 1.42)
		var rotation := rng.randf_range(0.0, TAU)
		var patch_color: Color = palette[patch_index % palette.size()].lerp(base_edge, 0.38)
		if in_starter_city:
			# Keep future building plots readable: subtle sage and dry-grass
			# islands add texture without looking like prebuilt landscaping.
			patch_color = Color("#71835A").lerp(Color("#A08D61"), rng.randf_range(0.08, 0.34)).lerp(base_edge, 0.48)
		var ring_levels := [0.0, 0.28, 0.55, 0.78, 1.0]
		var segments := 32
		var ring_points: Array = []
		for ring_value in ring_levels:
			var ring: Array[Vector3] = []
			for segment in range(segments):
				var angle := TAU * float(segment) / float(segments)
				var edge_noise := 1.0 + sin(angle * 2.0 + float(patch_index) * 0.71) * 0.15 + cos(angle * 5.0 - float(patch_index) * 0.37) * 0.10 + sin(angle * 9.0 + float(patch_index) * 0.23) * 0.055 + cos(angle * 13.0 - float(patch_index) * 0.19) * 0.03
				var local_x := cos(angle) * radius_x * float(ring_value) * edge_noise
				var local_z := sin(angle) * radius_z * float(ring_value) * edge_noise
				var rotated_x := local_x * cos(rotation) - local_z * sin(rotation)
				var rotated_z := local_x * sin(rotation) + local_z * cos(rotation)
				var point_x := center_x + rotated_x
				var point_z := center_z + rotated_z
				ring.append(Vector3(point_x, _terrain_height(point_x, point_z) + 0.052, point_z))
			ring_points.append(ring)
		for ring_index in range(ring_levels.size() - 1):
			var inner_ring: Array = ring_points[ring_index]
			var outer_ring: Array = ring_points[ring_index + 1]
			var inner_mix := float(ring_index) / float(ring_levels.size() - 1)
			var outer_mix := float(ring_index + 1) / float(ring_levels.size() - 1)
			var tone := 1.0 + sin(float(patch_index) * 0.41 + float(ring_index) * 0.7) * 0.035
				var inner_color := (patch_color * tone).lerp(base_edge, inner_mix)
				var outer_color := (patch_color * tone).lerp(base_edge, outer_mix)
			for segment in range(segments):
				var next_segment := (segment + 1) % segments
				var p00: Vector3 = inner_ring[segment]
				var p01: Vector3 = inner_ring[next_segment]
				var p10: Vector3 = outer_ring[segment]
				var p11: Vector3 = outer_ring[next_segment]
				surface.set_color(inner_color)
				surface.add_vertex(p00)
				surface.set_color(outer_color)
				surface.add_vertex(p10)
				surface.set_color(inner_color)
				surface.add_vertex(p01)
				surface.set_color(inner_color)
				surface.add_vertex(p01)
				surface.set_color(outer_color)
				surface.add_vertex(p10)
				surface.set_color(outer_color)
				surface.add_vertex(p11)
	surface.generate_normals()
	var patches := MeshInstance3D.new()
	patches.name = "MeadowBiomePatches"
	patches.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	patches.material_override = material
	patches.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patches.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(patches)


func _add_terrain_vertex(surface: SurfaceTool, point: Vector3) -> void:
	# Stable world-space texture scale plus restrained relief outside the build grid.
	surface.set_uv(Vector2(point.x * 0.16, point.z * 0.16))
	var coast := _coastline(point.z)
	var broad_noise := sin(point.x * 0.071 + point.z * 0.047) * cos(point.z * 0.083 - point.x * 0.052)
	var fine_noise := sin(point.x * 0.73 + point.z * 0.91) * cos(point.z * 0.67 - point.x * 0.58)
	var blend := clampf((broad_noise * 0.78 + fine_noise * 0.22 + 1.0) * 0.5, 0.0, 1.0)
	var color: Color
	if point.x > coast - 8.0:
		color = Color("#B79A68").lerp(Color("#E7D2A2"), blend)
	elif point.x > coast - BEACH_WIDTH:
		color = Color("#C2AA78").lerp(Color("#E2CB98"), blend * 0.62)
	elif point.x > coast - BEACH_WIDTH - 12.0:
		color = Color("#6B9653").lerp(Color("#B1B978"), blend * 0.45)
	else:
		# Bake broad biome patches into the mesh vertex colors as well as the
		# shader. This keeps terrain variation visible in WebGL/Compatibility.
		var macro_patch := sin(point.x * 0.026 + point.z * 0.019) * cos(point.z * 0.034 - point.x * 0.021)
		var secondary_patch := sin(point.x * 0.091 - point.z * 0.073) * cos(point.z * 0.107 + point.x * 0.063)
		var patch_mix := clampf(0.5 + macro_patch * 0.34 + secondary_patch * 0.16, 0.0, 1.0)
		var palette_index := int(abs(floor(point.x * 0.31 + point.z * 0.19))) % COASTAL_GREEN_PALETTE.size()
		var deep_grass := Color("#455B3D")
		var fresh_grass := Color("#85845A")
		var meadow_color := deep_grass.lerp(fresh_grass, patch_mix)
		color = COASTAL_GREEN_PALETTE[palette_index].lerp(meadow_color, 0.78)
		var biome_soil_mask := smoothstep(0.34, 0.78, macro_patch * 0.62 + secondary_patch * 0.38)
		color = color.lerp(Color("#A08A63"), biome_soil_mask * 0.48)
	# Visible baked soil/grass breakup supplements the shader texture at every camera distance.
	var rock_field := sin(point.x * 0.105 + point.z * 0.071) * cos(point.z * 0.137 - point.x * 0.063)
	var dry_patch_mask := smoothstep(0.48, 0.82, rock_field) * smoothstep(30.0, 70.0, absf(point.z))
	color = color.lerp(Color("#B0A078"), dry_patch_mask * 0.22)
	var climate := str(RegionManager.get_active_region().get("climate", "temperate"))
	match climate:
		"arctic":
			color = color.lerp(Color("#DCE7EC"), 0.72)
		"desert":
			color = color.lerp(Color("#B58B55"), 0.68)
		"tropical":
			color = color.lerp(Color("#2F6F43"), 0.30)
		"lush":
			color = color.lerp(Color("#3E783C"), 0.42)
		"mediterranean":
			color = color.lerp(Color("#8C875B"), 0.38)
	var park_edge := smoothstep(48.0, 82.0, absf(point.z))
	if point.x < 58.0 and point.x > -112.0:
		color = color.lerp(Color("#637A4B"), 0.08 + park_edge * 0.05)
	if not LandExpansionManager.is_world_position_unlocked(point):
		color = color.lerp(Color("#36523A"), 0.12)
	var terrain_point := point
	terrain_point.y = _terrain_height(point.x, point.z)
	# Compatibility-safe baked-style cavity shading: preserve a perfectly level build zone.
	color *= _terrain_vertex_ao(point.x, point.z)
	surface.set_color(color)
	surface.add_vertex(terrain_point)


func _terrain_vertex_ao(x: float, z: float) -> float:
	# Four height samples approximate local cavity darkening without SSAO/SSIL.
	# This is evaluated once while building the terrain mesh, not per frame.
	const SAMPLE_DISTANCE := 1.5
	var center := _terrain_height(x, z)
	var north := _terrain_height(x, z - SAMPLE_DISTANCE)
	var south := _terrain_height(x, z + SAMPLE_DISTANCE)
	var west := _terrain_height(x - SAMPLE_DISTANCE, z)
	var east := _terrain_height(x + SAMPLE_DISTANCE, z)
	var average_neighbour_height := (north + south + west + east) * 0.25
	var cavity := maxf(0.0, average_neighbour_height - center)
	var slope_x := (east - west) / (SAMPLE_DISTANCE * 2.0)
	var slope_z := (south - north) / (SAMPLE_DISTANCE * 2.0)
	var slope := Vector2(slope_x, slope_z).length()
	return clampf(1.0 - cavity * 0.10 - slope * 0.012, 0.86, 1.0)


func _terrain_height(x: float, z: float) -> float:
	# The initial owned city is 48 x 48 m. Keep it level, then blend into
	# visible rolling grassland immediately outside its true boundary.
	if absf(x - HIGHWAY_CENTER_X) < 14.0:
		return 0.0
	var distance_from_city := maxf(absf(x) - 24.0, absf(z) - 24.0)
	var relief_mask := smoothstep(-1.0, 9.0, distance_from_city)
	# Stronger, still gentle relief makes the surrounding meadow read as land,
	# while the owned starter plots, highway corridor and beach remain level.
	var broad := sin(x * 0.071 + z * 0.049) * 1.62
	var cross := cos(z * 0.113 - x * 0.087) * 0.82
	var rolling := sin(x * 0.19 - z * 0.16) * cos(z * 0.21 + x * 0.13) * 0.34
	var fine := sin(x * 0.61 + z * 0.47) * 0.13
	var natural_relief := (broad + cross + rolling + fine) * relief_mask
	# The last 14 m of beach gently settle to the sea datum. The water mesh
	# begins just offshore, so neither land nor ocean floats above the other.
	var beach_fade := smoothstep(0.0, 30.0, _coastline(z) - x)
	return natural_relief * beach_fade

func _coastline(z: float) -> float:
	return COASTLINE_BASE_X + sin(z * 0.032) * 7.0 + sin(z * 0.071) * 3.2 + sin(z * 0.013) * 4.0


func _build_land_expansion_markers() -> void:
	var tiles := LandExpansionManager.get_available_expansion_tiles()
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	for tile in tiles:
		var x0 := float(tile.x * LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var z0 := float(tile.y * LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var x1 := x0 + float(LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var z1 := z0 + float(LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var corners := [Vector3(x0, 0.055, z0), Vector3(x1, 0.055, z0), Vector3(x1, 0.055, z1), Vector3(x0, 0.055, z1)]
		for edge in range(4):
			lines.set_color(Color(1.0, 0.76, 0.30, 0.86))
			lines.add_vertex(corners[edge])
			lines.add_vertex(corners[(edge + 1) % 4])
	var marker := MeshInstance3D.new()
	marker.name = "LandExpansionMarkers"
	marker.mesh = lines.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker.material_override = material
	marker.visible = _expansion_preview_active
	add_child(marker)

func set_expansion_preview_visible(active: bool) -> void:
	_expansion_preview_active = active
	var marker := get_node_or_null("LandExpansionMarkers")
	if is_instance_valid(marker):
		marker.visible = active

func _build_city_grid() -> void:
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	for tile in LandExpansionManager.get_owned_tiles():
		var x0 := float(tile.x * LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var z0 := float(tile.y * LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var x1 := x0 + float(LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var z1 := z0 + float(LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		for cell_step in range(0, LandExpansionManager.TILE_CELLS + 1, 4):
			var x := x0 + float(cell_step) * BuildManager.GRID_SIZE
			var z := z0 + float(cell_step) * BuildManager.GRID_SIZE
			lines.set_color(Color(0.57, 0.70, 0.55, 0.17))
			lines.add_vertex(Vector3(x, 0.035, z0))
			lines.add_vertex(Vector3(x, 0.035, z1))
			lines.add_vertex(Vector3(x0, 0.035, z))
			lines.add_vertex(Vector3(x1, 0.035, z))
	var grid_instance := MeshInstance3D.new()
	grid_instance.name = "BuildablePlotGrid"
	grid_instance.mesh = lines.commit()
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.vertex_color_use_as_albedo = true
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.no_depth_test = false
	grid_instance.material_override = grid_material
	add_child(grid_instance)
	_refresh_build_grid_visibility()


func _on_road_mode_changed(_active: bool) -> void:
	_refresh_build_grid_visibility()


func _refresh_build_grid_visibility(_active: bool = false) -> void:
	var grid_instance := get_node_or_null("BuildablePlotGrid")
	if not is_instance_valid(grid_instance):
		return
	grid_instance.visible = _is_build_overlay_active()


func _is_build_overlay_active() -> bool:
	if BuildManager.is_placing:
		return true
	if not is_instance_valid(_road_system_cache):
		return false
	return bool(_road_system_cache.get("is_road_mode")) or bool(_road_system_cache.get("is_road_upgrade_mode"))


func _build_coastal_highway() -> void:
	# The highway is a permanent landmark, not a buildable city road. Its
	# carriageways, shoulders, median and connector are deliberately separate.
	var shoulder := MeshInstance3D.new()
	shoulder.name = "HighwayShoulder"
	var shoulder_mesh := BoxMesh.new()
	shoulder_mesh.size = Vector3(HIGHWAY_SHOULDER_WIDTH, 0.08, HIGHWAY_LENGTH)
	shoulder.mesh = shoulder_mesh
	shoulder.position = Vector3(HIGHWAY_CENTER_X, 0.11, 0.0)
	var shoulder_material := StandardMaterial3D.new()
	shoulder_material.albedo_color = Color("#777D79")
	shoulder_material.roughness = 1.0
	shoulder.material_override = shoulder_material
	add_child(shoulder)

	var highway := MeshInstance3D.new()
	highway.name = "CoastalHighway"
	var highway_mesh := BoxMesh.new()
	highway_mesh.size = Vector3(HIGHWAY_ASPHALT_WIDTH, 0.16, HIGHWAY_LENGTH)
	highway_mesh.subdivide_width = 2
	highway_mesh.subdivide_depth = 32
	highway.mesh = highway_mesh
	highway.position = Vector3(HIGHWAY_CENTER_X, 0.075, 0.0)
	var highway_asphalt := _create_asphalt_material()
	# Keep the motorway visibly asphalt-dark under the bright Pacific sun.
	highway_asphalt.albedo_color = Color("#737A76")
	highway_asphalt.uv1_scale = Vector3(12.0, 96.0, 1.0)
	highway.material_override = highway_asphalt
	highway.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(highway)

	# Contrasting shoulder strips sit just inside the asphalt edge and are
	# batched into one draw call for mobile rendering.
	var shoulder_strip_mesh := BoxMesh.new()
	shoulder_strip_mesh.size = Vector3(1.45, 0.012, HIGHWAY_LENGTH - 2.0)
	var shoulder_strips := MultiMesh.new()
	shoulder_strips.transform_format = MultiMesh.TRANSFORM_3D
	shoulder_strips.mesh = shoulder_strip_mesh
	shoulder_strips.instance_count = 2
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		shoulder_strips.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(HIGHWAY_CENTER_X + side * 10.25, 0.163, 0.0)))
	var shoulder_strip_instance := MultiMeshInstance3D.new()
	shoulder_strip_instance.name = "HighwayShoulderStrips"
	shoulder_strip_instance.multimesh = shoulder_strips
	var shoulder_strip_material := StandardMaterial3D.new()
	shoulder_strip_material.albedo_color = Color("#A0A4A0")
	shoulder_strip_material.roughness = 1.0
	shoulder_strip_instance.material_override = shoulder_strip_material
	add_child(shoulder_strip_instance)

	# Three lanes in each direction. Four dashed separators are one MultiMesh,
	# not 124 individual MeshInstance3D nodes.
	_add_highway_lane_dashes()
	for edge_x in [HIGHWAY_CENTER_X - 11.35, HIGHWAY_CENTER_X + 11.35]:
		_add_road_marking(Vector3(edge_x, 0.164, 0.0), Vector3(0.12, 0.012, HIGHWAY_LENGTH - 2.0), Color("#E8ECE8"))
	for shoulder_line_x in [HIGHWAY_CENTER_X - 9.7, HIGHWAY_CENTER_X + 9.7]:
		_add_road_marking(Vector3(shoulder_line_x, 0.164, 0.0), Vector3(0.10, 0.012, HIGHWAY_LENGTH - 2.0), Color("#DDE2DE"))
	for median_line_x in [HIGHWAY_CENTER_X - 0.52, HIGHWAY_CENTER_X + 0.52]:
		_add_road_marking(Vector3(median_line_x, 0.164, 0.0), Vector3(0.085, 0.012, HIGHWAY_LENGTH - 2.0), Color("#F2C84B"))

	# Concrete median is interrupted only at the city access crossing.
	var median_mesh := BoxMesh.new()
	median_mesh.size = Vector3(HIGHWAY_MEDIAN_WIDTH, 0.56, HIGHWAY_LENGTH)
	var median_multimesh := MultiMesh.new()
	median_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	median_multimesh.mesh = median_mesh
	median_multimesh.instance_count = 2
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.48))
		median_multimesh.set_instance_transform(index, Transform3D(basis, Vector3(HIGHWAY_CENTER_X, 0.435, side * 178.0)))
	var median := MultiMeshInstance3D.new()
	median.name = "HighwayConcreteMedian"
	median.multimesh = median_multimesh
	var median_material := StandardMaterial3D.new()
	median_material.albedo_color = Color("#AEB3AF")
	median_material.roughness = 0.94
	median.material_override = median_material
	median.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(median)

	# One batched guardrail mesh: continuous on the outer edge and opened on
	# the city-facing side so the connector and sidewalks remain unobstructed.
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.14, 0.58, HIGHWAY_LENGTH)
	var rails := MultiMesh.new()
	rails.transform_format = MultiMesh.TRANSFORM_3D
	rails.mesh = rail_mesh
	rails.instance_count = 3
	rails.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(HIGHWAY_CENTER_X - 13.35, 0.46, 0.0)))
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.48))
		rails.set_instance_transform(index + 1, Transform3D(basis, Vector3(HIGHWAY_CENTER_X + 13.35, 0.46, side * 49.5)))
	var guardrails := MultiMeshInstance3D.new()
	guardrails.name = "HighwayGuardrails"
	guardrails.multimesh = rails
	var guardrail_material := StandardMaterial3D.new()
	guardrail_material.albedo_color = Color("#C0C6C8")
	guardrail_material.metallic = 0.62
	guardrail_material.roughness = 0.48
	guardrails.material_override = guardrail_material
	guardrails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(guardrails)

	# The existing sidewalks stop at the access opening, preserving the city
	# pedestrian edge while avoiding a floating strip across the carriageway.
	_add_sidewalk_segment(-49.5, 91.0)
	_add_sidewalk_segment(49.5, 91.0)

	var access_road := MeshInstance3D.new()
	access_road.name = "HighwayCityConnector"
	var access_mesh := BoxMesh.new()
	access_mesh.size = Vector3(52.5, 0.16, 8.0)
	access_mesh.subdivide_width = 4
	access_mesh.subdivide_depth = 2
	access_road.mesh = access_mesh
	access_road.position = Vector3(-42.75, 0.095, 0.0)
	var connector_asphalt := highway_asphalt.duplicate() as StandardMaterial3D
	connector_asphalt.uv1_scale = Vector3(24.0, 5.0, 1.0)
	access_road.material_override = connector_asphalt
	access_road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	add_child(access_road)



func _build_highway_lighting() -> void:
	# Twelve full-size motorway luminaires, batched by geometry to keep the
	# permanent landmark inexpensive on mobile GPUs.
	var pole_positions: Array[Vector3] = []
	var arm_positions: Array[Vector3] = []
	var head_positions: Array[Vector3] = []
	var emitter_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		var pole_x: float = HIGHWAY_CENTER_X + float(side) * 14.8
		var inward: float = -float(side)
		for z in [-70.0, -42.0, -14.0, 14.0, 42.0, 70.0]:
			pole_positions.append(Vector3(pole_x, 4.2, z))
			arm_positions.append(Vector3(pole_x + inward * 1.35, 7.95, z))
			head_positions.append(Vector3(pole_x + inward * 2.55, 7.88, z))
			emitter_positions.append(Vector3(pole_x + inward * 2.55, 7.77, z))

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.075
	pole_mesh.bottom_radius = 0.14
	pole_mesh.height = 8.4
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color("#59636A")
	pole_material.metallic = 0.72
	pole_material.roughness = 0.42
	var poles := _make_world_multimesh("MotorwayLightPoles", pole_mesh, pole_positions, pole_material)
	poles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(2.8, 0.13, 0.13)
	var arm_material := StandardMaterial3D.new()
	arm_material.albedo_color = Color("#69747A")
	arm_material.metallic = 0.68
	arm_material.roughness = 0.44
	var arms := _make_world_multimesh("MotorwayLightArms", arm_mesh, arm_positions, arm_material)
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.95, 0.18, 0.52)
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color("#343D42")
	head_material.metallic = 0.38
	head_material.roughness = 0.5
	var heads := _make_world_multimesh("MotorwayLuminaireHousings", head_mesh, head_positions, head_material)
	var emitter_mesh := BoxMesh.new()
	emitter_mesh.size = Vector3(0.70, 0.035, 0.34)
	var emitter_material := StandardMaterial3D.new()
	emitter_material.albedo_color = Color("#F7E9B7")
	emitter_material.emission_enabled = true
	emitter_material.emission = Color("#F4DFA2")
	emitter_material.emission_energy_multiplier = 0.35
	var emitters := _make_world_multimesh("MotorwayLuminairePanels", emitter_mesh, emitter_positions, emitter_material)

	var lighting_root := Node3D.new()
	lighting_root.name = "HighwayLighting"
	add_child(lighting_root)
	for component in [poles, arms, heads, emitters]:
		lighting_root.add_child(component)


func _make_world_multimesh(node_name: String, mesh: Mesh, positions: Array[Vector3], material: Material) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for index in range(positions.size()):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, positions[index]))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	return instance


func _add_highway_lane_dashes() -> void:
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.09, 0.012, 3.0)
	var lane_positions: Array[Vector3] = []
	for lane_x in [
		HIGHWAY_CENTER_X - 6.6, HIGHWAY_CENTER_X - 3.3,
		HIGHWAY_CENTER_X + 3.3, HIGHWAY_CENTER_X + 6.6
	]:
		for segment in range(-55, 56):
			lane_positions.append(Vector3(lane_x, 0.164, float(segment) * 6.0))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dash_mesh
	multimesh.instance_count = lane_positions.size()
	for index in range(lane_positions.size()):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, lane_positions[index]))
	var markings := MultiMeshInstance3D.new()
	markings.name = "HighwayLaneDashes"
	markings.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#E9ECE8")
	markings.material_override = material
	add_child(markings)


func _add_sidewalk_segment(center_z: float, length_z: float) -> void:
	var sidewalk := MeshInstance3D.new()
	sidewalk.name = "RoadsideSidewalk"
	var sidewalk_mesh := BoxMesh.new()
	sidewalk_mesh.size = Vector3(1.05, 0.12, length_z)
	sidewalk.mesh = sidewalk_mesh
	sidewalk.position = Vector3(-42.92, 0.075, center_z)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.57, 0.59, 0.56)
	concrete.roughness = 1.0
	sidewalk.material_override = concrete
	add_child(sidewalk)

	var curb := MeshInstance3D.new()
	curb.name = "RoadsideCurb"
	var curb_mesh := BoxMesh.new()
	curb_mesh.size = Vector3(0.18, 0.20, length_z)
	curb.mesh = curb_mesh
	curb.position = Vector3(-43.53, 0.12, center_z)
	var curb_material := StandardMaterial3D.new()
	curb_material.albedo_color = Color(0.73, 0.75, 0.70)
	curb_material.roughness = 0.95
	curb.material_override = curb_material
	add_child(curb)

func _add_road_marking(position: Vector3, size: Vector3, color: Color) -> void:
	var marking := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	marking.mesh = mesh
	marking.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marking.material_override = material
	add_child(marking)

func _build_tree_belts() -> void:
	var positions: Array[Vector3] = []
	for x in [-84.0, -76.0, -62.0, -48.0, -30.0, -14.0, 8.0, 26.0, 42.0]:
		positions.append(Vector3(x, _terrain_height(x, -68.0), -68.0 + sin(x * 0.1) * 4.0))
		positions.append(Vector3(x + 3.0, _terrain_height(x, 68.0), 68.0 + cos(x * 0.12) * 4.0))
	for z in [-78.0, -56.0, -34.0, 28.0, 52.0, 76.0]:
		positions.append(Vector3(-78.0 + sin(z * 0.7) * 3.0, _terrain_height(-78.0, z), z))
		positions.append(Vector3(43.0 + sin(z * 0.08) * 2.0, _terrain_height(43.0, z), z))
	# Extra irregular gum trees create a broken, natural edge rather than a fence-like row.
	for index in range(20):
		var x := -74.0 + fposmod(float(index) * 17.3, 116.0)
		var z := -58.0 + fposmod(float(index) * 29.1, 116.0)
		if absf(x) < 26.0 and absf(z) < 26.0:
			continue
		if absf(x - HIGHWAY_CENTER_X) < 15.0 or x > _coastline(z) - BEACH_WIDTH - 8.0 or _is_city_road_footprint(x, z):
			continue
		positions.append(Vector3(x, _terrain_height(x, z), z))
	# A broader landscaped urban greenbelt replaces the old sparse rural fringe.
	# Keep all foliage outside owned plots and away from roads and the beach.
	for index in range(216):
		var x := -116.0 + fposmod(float(index) * 29.17, 188.0)
		var z := -86.0 + fposmod(float(index) * 43.71, 172.0)
		if LandExpansionManager.is_world_position_unlocked(Vector3(x, 0.0, z)):
			continue
		if absf(x - HIGHWAY_CENTER_X) < 16.0 or x > _coastline(z) - BEACH_WIDTH - 8.0:
			continue
		if _is_city_road_footprint(x, z):
			continue
		positions.append(Vector3(x, _terrain_height(x, z), z))
	# Irregular woodland groves with open gaps between them, not a perimeter fence.
	var grove_centers := [Vector2(-94.0, -112.0), Vector2(-28.0, -112.0), Vector2(54.0, -108.0), Vector2(-92.0, 112.0), Vector2(-18.0, 108.0), Vector2(62.0, 104.0)]
	for grove_index in range(grove_centers.size()):
		var center: Vector2 = grove_centers[grove_index]
		for tree_index in range(30):
			var angle := float(tree_index) * 2.399963 + float(grove_index) * 0.73
			var radius := 5.0 + sqrt(float(tree_index) / 30.0) * 23.0
			var x := center.x + cos(angle) * radius
			var z := center.y + sin(angle) * radius * 0.82
			var point := Vector3(x, 0.0, z)
			if LandExpansionManager.is_world_position_unlocked(point) or absf(x - HIGHWAY_CENTER_X) < 17.0:
				continue
			if x > _coastline(z) - BEACH_WIDTH - 10.0 or _is_city_road_footprint(x, z):
				continue
			positions.append(Vector3(x, _terrain_height(x, z), z))

	var root_mesh := CylinderMesh.new()
	root_mesh.top_radius = 0.24
	root_mesh.bottom_radius = 0.34
	root_mesh.height = 0.16
	var bark_material := StandardMaterial3D.new()
	bark_material.vertex_color_use_as_albedo = true
	bark_material.albedo_texture = _create_bark_texture()
	bark_material.roughness = 1.0
	root_mesh.material = bark_material
	var trunk_mesh := _create_branched_tree_trunk_mesh(bark_material)
	# Tree trunks and contact shadows remain separate, inexpensive shared batches.
	# The old sphere-lobe crowns are replaced by a four-species crossed-card system
	# with chunked MultiMeshes and three distance-based geometry tiers.
	var tree_shadows := _create_tree_shadow_multimesh(positions)
	add_child(tree_shadows)
	var roots := _create_tree_multimesh("TreeRootBases", root_mesh, positions, 0.08)
	var trunks := _create_tree_multimesh("TreeTrunks", trunk_mesh, positions, 1.40)

	var foliage_system := StylizedFoliageSystemScript.new()
	foliage_system.name = "StylizedFoliageSystem"
	foliage_system.configure_tree_positions(positions, 2026)
	add_child(foliage_system)
	add_child(roots)
	add_child(trunks)


func _create_branched_tree_trunk_mesh(bark_material: Material) -> ArrayMesh:
	# One reusable low-poly trunk mesh with four tapered primary branches.
	# Branches are merged into the same surface to avoid extra draw calls.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(bark_material)

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.25
	trunk.height = 2.8
	trunk.radial_segments = 8
	surface.append_from(trunk, 0, Transform3D.IDENTITY)

	for branch_index in range(4):
		var yaw := TAU * float(branch_index) / 4.0 + 0.28
		var branch := CylinderMesh.new()
		branch.top_radius = 0.045
		branch.bottom_radius = 0.095
		branch.height = 1.25
		branch.radial_segments = 6
		var tilt := deg_to_rad(31.0 + float(branch_index % 2) * 7.0)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), tilt)
		var origin := Vector3(cos(yaw) * 0.20, 0.82 + float(branch_index % 2) * 0.25, sin(yaw) * 0.20)
		surface.append_from(branch, 0, Transform3D(basis, origin))

	return surface.commit()


func _create_conifer_canopy_mesh() -> ArrayMesh:
	# Three overlapping tapered tiers create a readable evergreen silhouette.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in range(3):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.035
		cone.bottom_radius = 1.0 - float(tier) * 0.16
		cone.height = 1.65
		cone.radial_segments = 10
		cone.rings = 3
		var scale := Vector3(1.0 - float(tier) * 0.17, 1.0, 1.0 - float(tier) * 0.17)
		var offset := Vector3(0.0, -0.42 + float(tier) * 0.66, 0.0)
		surface.append_from(cone, 0, Transform3D(Basis.IDENTITY.scaled(scale), offset))
	return surface.commit()


func _create_umbrella_canopy_mesh() -> ArrayMesh:
	# Broad flattened crown with offset lobes, visually distinct from the round gum tree.
	var lobe := SphereMesh.new()
	lobe.radius = 1.0
	lobe.height = 1.25
	lobe.radial_segments = 14
	lobe.rings = 8
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := [
		[Vector3(0.0, 0.0, 0.0), Vector3(1.25, 0.68, 1.12)],
		[Vector3(-0.78, -0.12, 0.02), Vector3(0.78, 0.58, 0.78)],
		[Vector3(0.76, -0.10, 0.04), Vector3(0.82, 0.62, 0.76)],
		[Vector3(0.02, -0.08, -0.76), Vector3(0.84, 0.60, 0.78)],
		[Vector3(-0.02, -0.06, 0.74), Vector3(0.82, 0.58, 0.78)]
	]
	for lobe_data in lobes:
		var offset: Vector3 = lobe_data[0]
		var scale: Vector3 = lobe_data[1]
		surface.append_from(lobe, 0, Transform3D(Basis.IDENTITY.scaled(scale), offset))
	return surface.commit()

func _create_clustered_canopy_mesh() -> ArrayMesh:
	# Low-poly ellipsoids intersect deliberately to form a single coherent
	# broadleaf crown. The mesh is authored once and instanced across the belt.
	var lobe := SphereMesh.new()
	lobe.radius = 1.0
	lobe.height = 1.9
	lobe.radial_segments = 16
	lobe.rings = 10
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := [
		[Vector3(0.0, 0.0, 0.0), Vector3(1.00, 0.82, 0.92)],
		[Vector3(-0.68, -0.12, 0.02), Vector3(0.72, 0.70, 0.78)],
		[Vector3(0.66, -0.08, 0.08), Vector3(0.76, 0.72, 0.82)],
		[Vector3(0.02, 0.12, -0.66), Vector3(0.78, 0.74, 0.70)],
		[Vector3(-0.04, 0.18, 0.64), Vector3(0.76, 0.76, 0.72)],
		[Vector3(0.02, 0.68, -0.02), Vector3(0.66, 0.72, 0.66)]
	]
	for lobe_data in lobes:
		var offset: Vector3 = lobe_data[0]
		var scale: Vector3 = lobe_data[1]
		var transform := Transform3D(Basis.IDENTITY.scaled(scale), offset)
		surface.append_from(lobe, 0, transform)
	return surface.commit()


func _tree_instance_transform(index: int, position: Vector3, height_offset: float) -> Transform3D:
	# Gentle individual lean, variable trunk/crown proportions and asymmetry.
	var scale := 1.35 + float((index * 7) % 7) * 0.105
	var width_variation := 0.82 + float((index * 3) % 6) * 0.085
	var height_variation := 0.82 + float((index * 7) % 6) * 0.105
	var depth_variation := 0.78 + float((index * 11) % 6) * 0.10
	var yaw := float((index * 37) % 360) * PI / 180.0
	var lean := deg_to_rad(-9.0 + float((index * 13) % 19))
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), lean)
	basis = basis.scaled(Vector3(scale * width_variation, scale * height_variation, scale * depth_variation))
	var origin := position + Vector3(0.0, height_offset * scale * height_variation, 0.0)
	return Transform3D(basis, origin)

func _create_tree_multimesh(node_name: String, mesh: Mesh, positions: Array[Vector3], height_offset: float) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.use_colors = true
	multimesh.instance_count = positions.size()
	var trunk_palette: Array[Color] = [
		Color(0.43, 0.27, 0.16), Color(0.52, 0.34, 0.21),
		Color(0.36, 0.23, 0.15), Color(0.58, 0.39, 0.25)
	]
	var root_palette: Array[Color] = [
		Color(0.42, 0.29, 0.19), Color(0.50, 0.35, 0.23),
		Color(0.36, 0.25, 0.17), Color(0.55, 0.39, 0.26)
	]
	var foliage_palette: Array[Color] = [
		Color(0.39, 0.59, 0.43), Color(0.47, 0.64, 0.49),
		Color(0.55, 0.66, 0.48), Color(0.31, 0.52, 0.43),
		Color(0.62, 0.70, 0.54), Color(0.42, 0.57, 0.45)
	]
	for index in range(positions.size()):
		multimesh.set_instance_transform(index, _tree_instance_transform(index, positions[index], height_offset))
		if node_name == "TreeCanopies":
			multimesh.set_instance_color(index, foliage_palette[index % foliage_palette.size()])
		elif node_name == "TreeTrunks":
			multimesh.set_instance_color(index, trunk_palette[index % trunk_palette.size()])
		else:
			multimesh.set_instance_color(index, root_palette[index % root_palette.size()])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	# The tree belt already has one batched, soft contact-shadow pass. Rendering
	# every root/trunk/canopy into the directional shadow map multiplies shadow
	# caster work without a visible quality gain at the camera's normal distance.
	# Keep the detailed geometry and its baked-style contact shadows; skip only
	# the three redundant real-time shadow-caster batches.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = TREE_BELT_DETAIL_END
	instance.visibility_range_end_margin = TREE_BELT_DETAIL_MARGIN
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return instance


func _create_tree_shadow_multimesh(positions: Array[Vector3]) -> MultiMeshInstance3D:
	# One batched radial alpha mesh gives each tree a soft, stable contact shadow.
	# It is deliberately unlit and does not cast shadows, so the mobile cost is one draw.
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var p := Vector2((float(x) + 0.5) / 63.0 * 2.0 - 1.0, (float(y) + 0.5) / 63.0 * 2.0 - 1.0)
			var radius := p.length()
			var alpha := 0.0
			if radius < 1.0:
				alpha = pow(1.0 - radius * radius, 2.2) * 0.62
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var shadow_texture := ImageTexture.create_from_image(image)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.albedo_color = Color(0.13, 0.105, 0.075, 0.34)
	shadow_material.albedo_texture = shadow_texture
	shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow_material.no_depth_test = false
	shadow_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(3.8, 2.8)
	shadow_mesh.material = shadow_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = shadow_mesh
	multimesh.instance_count = positions.size()
	for index in range(positions.size()):
		var scale := 0.82 + float((index * 7) % 5) * 0.09
		var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		multimesh.set_instance_transform(index, Transform3D(basis, positions[index] + Vector3(0.0, 0.018, 0.0)))
	var shadows := MultiMeshInstance3D.new()
	shadows.name = "TreeContactShadows"
	shadows.multimesh = multimesh
	shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadows.visibility_range_end = TREE_BELT_DETAIL_END
	shadows.visibility_range_end_margin = TREE_BELT_DETAIL_MARGIN
	shadows.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return shadows


func _create_bark_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var grain := fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)
			var ridge := 0.5 + 0.5 * sin(float(x) * 0.82 + sin(float(y) * 0.19) * 1.4)
			var shade := clampf(0.70 + ridge * 0.20 + grain * 0.10, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	return ImageTexture.create_from_image(image)


func _create_foliage_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var broad := sin(float(x) * 0.31 + float(y) * 0.17) * cos(float(y) * 0.27 - float(x) * 0.13)
			var fine := fposmod(sin(float(x) * 91.7 + float(y) * 37.3) * 19341.7, 1.0)
			var shade := clampf(0.76 + broad * 0.12 + fine * 0.12, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	return ImageTexture.create_from_image(image)


# Procedural textures are generated locally at startup: no CDN, external asset or runtime download.
func _create_grass_texture() -> Texture2D:
	# Subtle green/olive mottling and sparse dry-grass flecks modulate the
	# vertex palette. This is a small local tile, not a flat green overlay.
	const TEXTURE_SIZE := 128
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		var angle_y := TAU * float(y) / float(TEXTURE_SIZE)
		for x in range(TEXTURE_SIZE):
			var angle_x := TAU * float(x) / float(TEXTURE_SIZE)
			var broad := sin(angle_x * 2.0 + cos(angle_y * 3.0)) * cos(angle_y * 2.0 - sin(angle_x * 3.0))
			var fine := sin(angle_x * 31.0 + angle_y * 23.0) * 0.5 + cos(angle_x * 43.0 - angle_y * 37.0) * 0.5
			var speckle := sin(angle_x * 79.0 + cos(angle_y * 67.0)) * cos(angle_y * 71.0 - sin(angle_x * 83.0))
			var value := clampf(0.66 + broad * 0.10 + fine * 0.055, 0.42, 0.82)
			var green := clampf(value * 1.16 + 0.035, 0.0, 1.0)
			var blue := clampf(value * 0.72, 0.0, 1.0)
			var texel := Color(value * 0.88, green, blue, 1.0)
			if speckle > 0.975:
				texel = texel.lerp(Color("#B0A16A"), 0.18)
			image.set_pixel(x, y, texel)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)



func _create_natural_ground_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap;
uniform sampler2D sand_texture : source_color, filter_linear_mipmap;
varying vec3 world_position;

float terrain_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float terrain_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = terrain_hash(cell);
	float b = terrain_hash(cell + vec2(1.0, 0.0));
	float c = terrain_hash(cell + vec2(0.0, 1.0));
	float d = terrain_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}
float terrain_fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += terrain_noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float coastline = 110.0 + sin(world_position.z * 0.032) * 7.0 + sin(world_position.z * 0.071) * 3.2 + sin(world_position.z * 0.013) * 4.0;
	float transition_noise = sin(world_position.z * 0.19 + world_position.x * 0.07) * 1.4;
	float sand_mask = smoothstep(coastline - 26.0 + transition_noise, coastline + 1.4 + transition_noise, world_position.x);
	vec2 ground_uv = UV * 0.62;
	vec2 world_xz = world_position.xz;

	// A layered, world-space meadow: broad fields first, then irregular
	// dry-grass islands, exposed earth, and fine mottling. These masks are
	// deliberately high-contrast enough to survive the mobile overview camera.
	float broad_field = terrain_fbm(world_xz * 0.019 + vec2(7.0, 13.0));
	float mid_field = terrain_fbm(world_xz * 0.052 + vec2(23.0, 5.0));
	float dry_field = terrain_noise(world_xz * 0.031 + vec2(47.0, 31.0));
	float soil_field = terrain_noise(world_xz * 0.094 + vec2(11.0, 59.0));
	float micro_grain = terrain_noise(world_xz * 1.65);
	float cell_shape = terrain_noise(world_xz * 0.041 + vec2(37.0, 19.0));

	float sunlit_mask = smoothstep(0.31, 0.68, broad_field);
	float olive_mask = smoothstep(0.35, 0.69, mid_field);
	float dry_mask = smoothstep(0.39, 0.68, dry_field);
	float soil_core = 1.0 - smoothstep(0.24, 0.47, cell_shape);
	float soil_patch_mask = smoothstep(0.59, 0.79, soil_field) * (0.42 + soil_core * 0.58);
	soil_patch_mask *= 0.72 + dry_mask * 0.28;

	vec3 deep_meadow = vec3(0.245, 0.335, 0.205);
	vec3 sunlit_sage = vec3(0.455, 0.475, 0.305);
	vec3 dry_olive = vec3(0.565, 0.505, 0.335);
	vec3 straw_grass = vec3(0.635, 0.565, 0.390);
	vec3 exposed_soil = vec3(0.405, 0.305, 0.205);
	vec3 warm_earth = vec3(0.505, 0.385, 0.265);

	vec3 meadow = mix(deep_meadow, sunlit_sage, sunlit_mask);
	meadow = mix(meadow, dry_olive, olive_mask * 0.56);
	meadow = mix(meadow, straw_grass, dry_mask * 0.54);
	meadow = mix(meadow, mix(exposed_soil, warm_earth, soil_field), clamp(soil_patch_mask * 0.78, 0.0, 0.68));

	// Retain the locally generated grass texture as a restrained fine-scale
	// overlay; the world-space biome colors remain the dominant visual read.
	vec3 sampled_grass = texture(grass_texture, ground_uv * 0.72).rgb;
	meadow = mix(meadow, meadow * sampled_grass * 1.55, 0.16);
	meadow *= 0.88 + micro_grain * 0.25;
	meadow *= mix(0.92, 1.06, terrain_noise(world_xz * 0.34 + vec2(3.0, 71.0)));
	// Baked vertex color gently carries climate/region tint without washing out
	// the designed soil and dry-field colors.
	meadow *= mix(vec3(0.94), COLOR.rgb, 0.22);

	vec3 sand = texture(sand_texture, ground_uv * 0.38).rgb * COLOR.rgb;
	float wet_sand = smoothstep(coastline - 8.0, coastline - 0.7, world_position.x);
	vec3 damp_sand = sand * vec3(0.78, 0.82, 0.83);
	sand = mix(sand, damp_sand, wet_sand * 0.72);
	float dune_ripple = sin(world_position.z * 0.42 + world_position.x * 0.16) * 0.018;
	sand += vec3(dune_ripple);
	ALBEDO = mix(meadow, sand, sand_mask);
	ROUGHNESS = mix(0.98, 0.84, sand_mask);
	SPECULAR = 0.12;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grass_texture", _create_grass_texture())
	material.set_shader_parameter("sand_texture", _create_sand_texture())
	return material


func _create_sand_texture() -> Texture2D:
	const TEXTURE_SIZE := 256
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		var angle_y := TAU * float(y) / float(TEXTURE_SIZE)
		for x in range(TEXTURE_SIZE):
			var angle_x := TAU * float(x) / float(TEXTURE_SIZE)
			# Periodic multi-scale grain keeps the fallback seamless at tile edges.
			var dune := sin(angle_x * 2.0 + cos(angle_y * 3.0)) * 0.5 + cos(angle_y * 2.0 - sin(angle_x * 3.0)) * 0.5
			var grain := sin(angle_x * 31.0 + angle_y * 23.0) * 0.5 + cos(angle_x * 43.0 - angle_y * 37.0) * 0.5
			var fine := sin(angle_x * 79.0 + cos(angle_y * 67.0)) * cos(angle_y * 71.0 - sin(angle_x * 83.0))
			var value := clampf(0.68 + dune * 0.055 + grain * 0.035 + fine * 0.018, 0.54, 0.82)
			image.set_pixel(x, y, Color(value * 1.0, value * 0.91, value * 0.73, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _create_asphalt_material() -> StandardMaterial3D:
	# Medium charcoal-gray asphalt with several scales of aggregate grain.
	# Periodic noise layers keep the texture seamless across the long motorway.
	const TEXTURE_SIZE := 256
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(TEXTURE_SIZE * TEXTURE_SIZE)
	for y in range(TEXTURE_SIZE):
		var angle_y := TAU * float(y) / float(TEXTURE_SIZE)
		for x in range(TEXTURE_SIZE):
			var angle_x := TAU * float(x) / float(TEXTURE_SIZE)
			var broad := sin(angle_x * 2.0 + cos(angle_y * 3.0)) * 0.55 + cos(angle_y * 2.0 - sin(angle_x * 3.0)) * 0.45
			var medium := sin(angle_x * 7.0 + angle_y * 5.0) * 0.5 + cos(angle_x * 11.0 - angle_y * 9.0) * 0.5
			var grain := sin(angle_x * 37.0 + angle_y * 29.0) * 0.5 + cos(angle_x * 53.0 - angle_y * 47.0) * 0.5
			var fine_grain := sin(angle_x * 83.0 + angle_y * 71.0) * 0.5 + cos(angle_x * 97.0 - angle_y * 89.0) * 0.5
			var aggregate_signal := sin(angle_x * 61.0 + cos(angle_y * 73.0)) * cos(angle_y * 67.0 - sin(angle_x * 59.0))
			var aggregate := 0.018 if aggregate_signal > 0.985 else (-0.018 if aggregate_signal < -0.985 else 0.0)
			var height_value := clampf(0.235 + broad * 0.032 + medium * 0.018 + grain * 0.009 + fine_grain * 0.004 + aggregate, 0.12, 0.34)
			heights[y * TEXTURE_SIZE + x] = height_value
			image.set_pixel(x, y, Color(height_value * 0.92, height_value * 0.96, height_value * 1.02, 1.0))
	var normal_image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var left := heights[y * TEXTURE_SIZE + posmod(x - 1, TEXTURE_SIZE)]
			var right := heights[y * TEXTURE_SIZE + posmod(x + 1, TEXTURE_SIZE)]
			var up := heights[posmod(y - 1, TEXTURE_SIZE) * TEXTURE_SIZE + x]
			var down := heights[posmod(y + 1, TEXTURE_SIZE) * TEXTURE_SIZE + x]
			var dx := (right - left) * 4.0
			var dy := (down - up) * 4.0
			normal_image.set_pixel(x, y, Color(0.5 - dx, 0.5 - dy, 1.0, 1.0))
	image.generate_mipmaps()
	normal_image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.normal_enabled = true
	material.normal_texture = ImageTexture.create_from_image(normal_image)
	material.normal_scale = 0.24
	material.roughness = 0.97
	material.metallic = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material

func _create_water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
varying vec3 world_position;
varying float wave_normal_x;
varying float wave_normal_z;
void vertex() {
	vec3 p = VERTEX;
	float phase_a = p.x * 0.041 + p.z * 0.033 + TIME * 0.72;
	float phase_b = p.x * 0.019 - p.z * 0.057 + TIME * 0.43;
	float phase_c = p.x * 0.13 + p.z * 0.105 + TIME * 1.18;
	float wave_a = sin(phase_a);
	float wave_b = cos(phase_b);
	float wave_c = sin(phase_c);
	p.y += (wave_a * 0.52 + wave_b * 0.34 + wave_c * 0.14) * 0.32;
	wave_normal_x = cos(phase_a) * 0.018 + sin(phase_b) * 0.010 + cos(phase_c) * 0.006;
	wave_normal_z = cos(phase_a) * 0.014 - sin(phase_b) * 0.014 + cos(phase_c) * 0.005;
	VERTEX = p;
	world_position = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}
void fragment() {
	float u = clamp(UV.x, 0.0, 1.0);
	vec3 coastal_teal = vec3(0.015, 0.16, 0.22);
	vec3 coastal_blue = vec3(0.009, 0.09, 0.22);
	vec3 mediterranean_blue = vec3(0.005, 0.04, 0.17);
	vec3 pacific_blue = vec3(0.002, 0.014, 0.085);
	vec3 water_color = mix(coastal_teal, coastal_blue, smoothstep(0.0, 0.055, u));
	water_color = mix(water_color, mediterranean_blue, smoothstep(0.07, 0.34, u));
	water_color = mix(water_color, pacific_blue, smoothstep(0.34, 0.96, u));
	float long_swell = sin(world_position.x * 0.024 + world_position.z * 0.018 + TIME * 0.25);
	float cross_swell = cos(world_position.x * 0.052 - world_position.z * 0.037 + TIME * 0.39);
	float fine_ripple = sin(world_position.x * 0.29 + world_position.z * 0.21 + TIME * 1.1);
	float wave_light = long_swell * 0.006 + cross_swell * 0.0035 + fine_ripple * 0.0015;
	NORMAL = normalize(vec3(-wave_normal_x, 1.0, -wave_normal_z));
	float view_facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float fresnel = pow(1.0 - view_facing, 5.0);
	float crest = pow(max(0.0, sin(world_position.x * 0.18 + world_position.z * 0.14 + TIME * 0.62)), 24.0);
	float sun_glint = crest * 0.025 * (0.35 + 0.65 * fresnel);
	ALBEDO = max(vec3(0.0), water_color + vec3(wave_light + sun_glint));
	ALBEDO = mix(ALBEDO, vec3(0.30, 0.48, 0.62), fresnel * 0.08);
	ROUGHNESS = mix(0.30, 0.43, u);
	METALLIC = 0.0;
	SPECULAR = 0.48;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _create_shallow_water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
varying float shallow_wave_x;
varying float shallow_wave_z;
void vertex() {
	vec3 p = VERTEX;
	float phase_a = p.x * 0.42 + p.z * 0.27 + TIME * 0.85;
	float phase_b = p.x * 0.23 - p.z * 0.51 + TIME * 0.58;
	float phase_c = p.x * 0.96 + p.z * 0.72 + TIME * 1.35;
	p.y += (sin(phase_a) * 0.52 + cos(phase_b) * 0.33 + sin(phase_c) * 0.15) * 0.16;
	shallow_wave_x = cos(phase_a) * 0.060 + sin(phase_b) * 0.035 + cos(phase_c) * 0.020;
	shallow_wave_z = cos(phase_a) * 0.040 - sin(phase_b) * 0.070 + cos(phase_c) * 0.018;
	VERTEX = p;
}
void fragment() {
	float broad = sin(UV.x * 23.0 + UV.y * 7.0 + TIME * 0.20);
	float ripple = sin(UV.x * 86.0 + TIME * 1.05) * cos(UV.y * 39.0 - TIME * 0.68);
	float caustic = pow(max(0.0, sin(UV.x * 29.0 + sin(UV.y * 19.0 + TIME * 0.24) * 1.6) * cos(UV.y * 25.0 - TIME * 0.28)), 6.0);
	vec3 shallow_teal = vec3(0.018, 0.15, 0.23);
	vec3 shallow_azure = vec3(0.012, 0.09, 0.23);
	vec3 water = mix(shallow_teal, shallow_azure, smoothstep(0.12, 0.94, UV.x));
	water += vec3(caustic * 0.020 + broad * 0.003 + ripple * 0.001);
	NORMAL = normalize(vec3(-shallow_wave_x, 1.0, -shallow_wave_z));
	ALBEDO = water;
	ROUGHNESS = 0.30;
	SPECULAR = 0.50;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _is_city_road_footprint(x: float, z: float) -> bool:
	# RoadSystem is a scene node, not an autoload singleton. Resolve it from
	# the active scene once, then reuse the reference for scatter placement.
	var cell := Vector2i(floori(x / BuildManager.GRID_SIZE), floori(z / BuildManager.GRID_SIZE))
	if not is_instance_valid(_road_system_cache):
		var scene := get_tree().current_scene
		if scene == null:
			return false
		_road_system_cache = scene.find_child("RoadSystem", true, false)
	if not is_instance_valid(_road_system_cache) or not _road_system_cache.has_method("has_road"):
		return false
	return bool(_road_system_cache.call("has_road", cell))

func _build_grass_detail() -> void:
	# Each instance is a multi-blade tussock, not a single rectangular stalk.
	var blade_mesh := _create_meadow_grass_clump_mesh()
	var blade_material := StandardMaterial3D.new()
	blade_material.vertex_color_use_as_albedo = true
	blade_material.roughness = 0.98
	blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var positions: Array[Vector3] = []
	for index in range(2400):
		var x := -118.0 + fposmod(float(index) * 19.37, 194.0)
		var z := -88.0 + fposmod(float(index) * 31.73, 176.0)
		if absf(x) < 26.0 and absf(z) < 26.0:
			continue
		if absf(x - HIGHWAY_CENTER_X) < 14.0 or _is_city_road_footprint(x, z):
			continue
		var creek_x := 36.0 + sin(z * 0.045) * 2.0
		if absf(x - creek_x) < 5.0 or x > _coastline(z) - 13.0:
			continue
		positions.append(Vector3(x, _terrain_height(x, z) + 0.025, z))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = blade_mesh
	multimesh.instance_count = positions.size()
	var grass_palette: Array[Color] = [
		Color("#426C35"), Color("#71934A"), Color("#A0A05A"),
		Color("#557D43"), Color("#879B58"), Color("#355D35")
	]
	for index in range(positions.size()):
		var scale := 0.72 + float((index * 13) % 11) * 0.09
		var tilt := deg_to_rad(-12.0 + float((index * 7) % 25))
		var yaw := float(index % 12) * 0.5236
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), tilt)
		basis = basis.scaled(Vector3(scale, scale, scale))
		multimesh.set_instance_transform(index, Transform3D(basis, positions[index]))
		multimesh.set_instance_color(index, grass_palette[index % grass_palette.size()])
	var grass := MultiMeshInstance3D.new()
	grass.name = "ColorfulGrassDetail"
	grass.multimesh = multimesh
	grass.material_override = blade_material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	grass.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	grass.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(grass)


func _create_meadow_grass_clump_mesh() -> ArrayMesh:
	# Five crossed tapered blades give every instance a readable tuft silhouette.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade_index in range(5):
		var angle := TAU * float(blade_index) / 5.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-direction.z, 0.0, direction.x)
		var blade_height := 0.78 + float((blade_index * 7) % 4) * 0.13
		var lean := direction * (0.18 + float(blade_index % 3) * 0.07)
		var base := Vector3.ZERO
		var tip := lean + Vector3(0.0, blade_height, 0.0)
		var left := base - tangent * 0.085
		var right := base + tangent * 0.085
		var color := Color("#4B7439").lerp(Color("#91A956"), float(blade_index) * 0.09)
		surface.set_color(color)
		surface.add_vertex(left)
		surface.add_vertex(right)
		surface.add_vertex(tip)
		surface.add_vertex(tip)
		surface.add_vertex(right)
		surface.add_vertex(left)
	surface.generate_normals()
	return surface.commit()

func _build_meadow_livestock() -> void:
	# Livestock stays in two sandy grazing strips beyond the playable city boundary.
	# The controller refuses asphalt, connected roads and any land later unlocked by the player.
	var sheep_positions: Array[Vector3] = []
	for index in range(MEADOW_SHEEP_COUNT):
		var column := index % 6
		var north := index < 6
		var x := -34.0 + float(column) * 13.2
		if index < 3:
			x = -84.0 + float(index) * 5.0
		var z := -85.0 if north else 85.0
		sheep_positions.append(Vector3(x, 0.0, z))
	var cattle_positions: Array[Vector3] = [
		Vector3(-80.0, 0.0, -85.0), Vector3(1.0, 0.0, 85.0), Vector3(27.0, 0.0, -85.0)
	]

	var flock := MeadowLivestockScript.new()
	flock.name = "MeadowLivestock"
	flock.configure(sheep_positions, cattle_positions)
	add_child(flock)

	var wool_mesh := SphereMesh.new()
	wool_mesh.radius = 0.76
	wool_mesh.height = 1.35
	var wool_material := StandardMaterial3D.new()
	wool_material.albedo_color = Color("#F0EBDD")
	wool_material.roughness = 0.98
	var sheep_bodies := _make_world_multimesh("SheepWoolBodies", wool_mesh, _animal_body_positions(sheep_positions, 0.88), wool_material)
	flock.add_child(sheep_bodies)
	_register_livestock_part(flock, sheep_bodies, sheep_positions.size(), 0, [Vector3(0.0, 0.88, 0.0)])

	var tuft_mesh := SphereMesh.new()
	tuft_mesh.radius = 0.31
	tuft_mesh.height = 0.58
	var tuft_positions: Array[Vector3] = []
	for origin in sheep_positions:
		for offset in [Vector3(-0.28, 1.15, -0.34), Vector3(0.20, 1.18, -0.32), Vector3(-0.28, 1.16, 0.34), Vector3(0.22, 1.18, 0.34)]:
			tuft_positions.append(origin + offset)
	var tufts := _make_world_multimesh("SheepWoolTufts", tuft_mesh, tuft_positions, wool_material)
	flock.add_child(tufts)
	_register_livestock_part(flock, tufts, sheep_positions.size(), 0, [Vector3(-0.28, 1.15, -0.34), Vector3(0.20, 1.18, -0.32), Vector3(-0.28, 1.16, 0.34), Vector3(0.22, 1.18, 0.34)])

	var sheep_head_mesh := SphereMesh.new()
	sheep_head_mesh.radius = 0.30
	sheep_head_mesh.height = 0.66
	var sheep_head_material := StandardMaterial3D.new()
	sheep_head_material.albedo_color = Color("#514A40")
	sheep_head_material.roughness = 0.92
	var sheep_heads := _make_world_multimesh("SheepHeads", sheep_head_mesh, _animal_head_positions(sheep_positions, 0.92), sheep_head_material)
	flock.add_child(sheep_heads)
	_register_livestock_part(flock, sheep_heads, sheep_positions.size(), 0, [Vector3(0.68, 0.92, 0.0)])

	var sheep_leg_mesh := CylinderMesh.new()
	sheep_leg_mesh.top_radius = 0.055
	sheep_leg_mesh.bottom_radius = 0.075
	sheep_leg_mesh.height = 0.62
	var leg_material := StandardMaterial3D.new()
	leg_material.albedo_color = Color("#4A4037")
	leg_material.roughness = 0.95
	var leg_offsets: Array[Vector3] = [Vector3(-0.42, 0.32, -0.42), Vector3(-0.42, 0.32, 0.42), Vector3(0.42, 0.32, -0.42), Vector3(0.42, 0.32, 0.42)]
	var sheep_legs := _make_world_multimesh("SheepLegs", sheep_leg_mesh, _animal_leg_positions(sheep_positions, 0.32), leg_material)
	flock.add_child(sheep_legs)
	_register_livestock_part(flock, sheep_legs, sheep_positions.size(), 0, leg_offsets, true)

	var cow_body_mesh := SphereMesh.new()
	cow_body_mesh.radius = 0.95
	cow_body_mesh.height = 1.55
	var cow_material := StandardMaterial3D.new()
	cow_material.albedo_color = Color("#E8E2D5")
	cow_material.roughness = 0.98
	var cow_bodies := _make_world_multimesh("CattleBodies", cow_body_mesh, _animal_body_positions(cattle_positions, 1.02), cow_material)
	flock.add_child(cow_bodies)
	_register_livestock_part(flock, cow_bodies, cattle_positions.size(), sheep_positions.size(), [Vector3(0.0, 1.02, 0.0)])

	var patch_mesh := SphereMesh.new()
	patch_mesh.radius = 0.43
	patch_mesh.height = 0.18
	var patch_material := StandardMaterial3D.new()
	patch_material.albedo_color = Color("#574333")
	patch_material.roughness = 1.0
	var patch_positions: Array[Vector3] = []
	for origin in cattle_positions:
		patch_positions.append(origin + Vector3(0.10, 1.16, -0.56))
		patch_positions.append(origin + Vector3(-0.34, 1.15, 0.48))
	var patches := _make_world_multimesh("CattleCoatPatches", patch_mesh, patch_positions, patch_material)
	flock.add_child(patches)
	_register_livestock_part(flock, patches, cattle_positions.size(), sheep_positions.size(), [Vector3(0.10, 1.16, -0.56), Vector3(-0.34, 1.15, 0.48)])

	var cow_head_mesh := SphereMesh.new()
	cow_head_mesh.radius = 0.38
	cow_head_mesh.height = 0.72
	var cow_head_material := StandardMaterial3D.new()
	cow_head_material.albedo_color = Color("#6B5140")
	cow_head_material.roughness = 0.96
	var cow_heads := _make_world_multimesh("CattleHeads", cow_head_mesh, _animal_head_positions(cattle_positions, 1.02), cow_head_material)
	flock.add_child(cow_heads)
	_register_livestock_part(flock, cow_heads, cattle_positions.size(), sheep_positions.size(), [Vector3(0.68, 1.02, 0.0)])

	var cow_legs := _make_world_multimesh("CattleLegs", sheep_leg_mesh, _animal_leg_positions(cattle_positions, 0.36), leg_material)
	flock.add_child(cow_legs)
	_register_livestock_part(flock, cow_legs, cattle_positions.size(), sheep_positions.size(), leg_offsets, true)


func _register_livestock_part(flock: Node3D, instance: MultiMeshInstance3D, animal_count: int, owner_offset: int, local_offsets: Array[Vector3], animate_legs: bool = false) -> void:
	var owners: Array[int] = []
	var offsets: Array[Vector3] = []
	for animal_index in range(animal_count):
		for local_offset in local_offsets:
			owners.append(owner_offset + animal_index)
			offsets.append(local_offset)
	flock.call("register_part", instance, owners, offsets, animate_legs)


func _animal_body_positions(origins: Array[Vector3], height: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for origin in origins:
		result.append(origin + Vector3(0.0, height, 0.0))
	return result


func _animal_head_positions(origins: Array[Vector3], height: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for origin in origins:
		result.append(origin + Vector3(0.68, height, 0.0))
	return result


func _animal_leg_positions(origins: Array[Vector3], body_height: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for origin in origins:
		for offset in [Vector3(-0.42, 0.32, -0.42), Vector3(-0.42, 0.32, 0.42), Vector3(0.42, 0.32, -0.42), Vector3(0.42, 0.32, 0.42)]:
			result.append(origin + offset)
	return result


func _build_dirt_tracks() -> void:
	# Three eroded dirt spurs peel away from the motorway into the outer meadow.
	# All ribbons share one vertex-colored surface and one draw call.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var starts: Array[float] = [-69.0, -5.0, 67.0]
	var finishes: Array[float] = [-48.0, 22.0, 46.0]
	for road_index in range(3):
		var previous_left := Vector3.ZERO
		var previous_right := Vector3.ZERO
		for step in range(29):
			var t := float(step) / 28.0
			var x := lerpf(HIGHWAY_CENTER_X, -17.0 + float(road_index) * 1.5, t)
			var z := lerpf(starts[road_index], finishes[road_index], t) + sin(t * PI) * (float(road_index) - 1.0) * 7.0
			var width := 2.25 - t * 0.55 + sin(t * PI * 4.0 + float(road_index)) * 0.16
			var center_y := _terrain_height(x, z) + 0.055
			var left := Vector3(x, center_y + 0.012, z - width)
			var right := Vector3(x, center_y + 0.012, z + width)
			if step > 0:
				var tint := 0.82 + 0.12 * sin(float(step * 7 + road_index * 11))
				var dust := Color(0.43, 0.34, 0.23) * tint
				var edge := Color(0.30, 0.27, 0.20) * tint
				surface.set_color(edge)
				surface.set_uv(Vector2(float(step) * 0.4, 0.0))
				surface.add_vertex(previous_left)
				surface.set_color(dust)
				surface.set_uv(Vector2(float(step) * 0.4, 1.0))
				surface.add_vertex(previous_right)
				surface.set_color(dust)
				surface.set_uv(Vector2(float(step) * 0.4 + 0.4, 0.0))
				surface.add_vertex(left)
				surface.set_color(dust)
				surface.add_vertex(left)
				surface.add_vertex(previous_right)
				surface.set_color(edge)
				surface.add_vertex(right)
			previous_left = left
			previous_right = right
	surface.generate_normals()
	var roads := MeshInstance3D.new()
	roads.name = "NaturalDirtTracks"
	roads.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	roads.material_override = material
	roads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roads)


func _build_creek_channel() -> void:
	# A shallow incised creek: lowered bed, sloped eroded banks and a separate
	# narrow water ribbon. It is real cross-section geometry, not a flat plane.
	var bank_surface := SurfaceTool.new()
	bank_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water_surface := SurfaceTool.new()
	water_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS := 44
	var offsets: Array[float] = [-4.0, -2.0, -1.05, 1.05, 2.0, 4.0]
	for step in range(STEPS):
		var z0 := -84.0 + float(step) / float(STEPS - 1) * 168.0
		var z1 := -84.0 + float(step + 1) / float(STEPS - 1) * 168.0
		var x0 := 36.0 + sin(z0 * 0.045) * 2.0
		var x1 := 36.0 + sin(z1 * 0.045) * 2.0
		var heights: Array[float] = [0.01, -0.18, -0.73, -0.73, -0.18, 0.01]
		for band in range(offsets.size() - 1):
			var p00 := Vector3(x0 + offsets[band], _terrain_height(x0 + offsets[band], z0) + heights[band], z0)
			var p01 := Vector3(x1 + offsets[band], _terrain_height(x1 + offsets[band], z1) + heights[band], z1)
			var p10 := Vector3(x0 + offsets[band + 1], _terrain_height(x0 + offsets[band + 1], z0) + heights[band + 1], z0)
			var p11 := Vector3(x1 + offsets[band + 1], _terrain_height(x1 + offsets[band + 1], z1) + heights[band + 1], z1)
			var sediment := Color("#756448") if band == 0 or band == 4 else Color("#574B39")
			bank_surface.set_color(sediment)
			bank_surface.add_vertex(p00)
			bank_surface.add_vertex(p01)
			bank_surface.add_vertex(p10)
			bank_surface.set_color(Color("#8C7955") if band == 1 or band == 3 else sediment)
			bank_surface.add_vertex(p10)
			bank_surface.add_vertex(p01)
			bank_surface.add_vertex(p11)
		var water_y0 := _terrain_height(x0, z0) - 0.43 + sin(z0 * 0.24) * 0.025
		var water_y1 := _terrain_height(x1, z1) - 0.43 + sin(z1 * 0.24) * 0.025
		water_surface.set_color(Color("#2E8D9A"))
		water_surface.add_vertex(Vector3(x0 - 0.92, water_y0, z0))
		water_surface.add_vertex(Vector3(x1 - 0.92, water_y1, z1))
		water_surface.add_vertex(Vector3(x0 + 0.92, water_y0, z0))
		water_surface.add_vertex(Vector3(x0 + 0.92, water_y0, z0))
		water_surface.add_vertex(Vector3(x1 - 0.92, water_y1, z1))
		water_surface.add_vertex(Vector3(x1 + 0.92, water_y1, z1))
	bank_surface.generate_normals()
	water_surface.generate_normals()
	var banks := MeshInstance3D.new()
	banks.name = "ErodedCreekBanksAndBed"
	banks.mesh = bank_surface.commit()
	var bank_material := StandardMaterial3D.new()
	bank_material.vertex_color_use_as_albedo = true
	bank_material.roughness = 1.0
	banks.material_override = bank_material
	banks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(banks)
	var water := MeshInstance3D.new()
	water.name = "MeadowCreekWater"
	water.mesh = water_surface.commit()
	water.material_override = _create_water_material()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_build_creek_rock_edges()


func _build_creek_rock_edges() -> void:
	# One low-poly stone mesh, instanced along both eroded creek banks.
	var stone := SphereMesh.new()
	stone.radius = 1.0
	stone.height = 1.0
	stone.radial_segments = 7
	stone.rings = 4
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = stone
	batch.instance_count = 104
	var palette: Array[Color] = [Color("#777568"), Color("#A09278"), Color("#5E625A"), Color("#88765D")]
	for index in range(104):
		var z := -82.0 + float(index) * 1.58
		var center_x := 36.0 + sin(z * 0.045) * 2.0
		var side := -1.0 if index % 2 == 0 else 1.0
		var size := 0.20 + float((index * 7) % 6) * 0.075
		var x := center_x + side * (2.1 + float(index % 3) * 0.65)
		var scale := Vector3(size * (1.0 + float(index % 3) * 0.25), size * 0.48, size * 0.72)
		var basis := Basis(Vector3.UP, float(index * 47 % 360) * PI / 180.0).scaled(scale)
		batch.set_instance_transform(index, Transform3D(basis, Vector3(x, _terrain_height(x, z) + 0.05, z)))
		batch.set_instance_color(index, palette[index % palette.size()])
	var rocks := MultiMeshInstance3D.new()
	rocks.name = "CreekBankStoneBatch"
	rocks.multimesh = batch
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	rocks.material_override = material
	rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rocks.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	rocks.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	rocks.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(rocks)


func _build_meadow_shrubs_and_stones() -> void:
	# Scrub is concentrated around the city perimeter as well as the outer meadow.
	var shrub_mesh := _create_meadow_shrub_mesh()
	var shrub_batch := MultiMesh.new()
	shrub_batch.transform_format = MultiMesh.TRANSFORM_3D
	shrub_batch.use_colors = true
	shrub_batch.mesh = shrub_mesh
	var shrub_positions: Array[Vector3] = []
	for index in range(360):
		var x := -118.0 + fposmod(float(index) * 23.71, 190.0)
		var z := -86.0 + fposmod(float(index) * 37.19, 172.0)
		if absf(x) < 26.0 and absf(z) < 26.0:
			continue
		if absf(x - HIGHWAY_CENTER_X) < 15.0 or x > _coastline(z) - 14.0:
			continue
		var creek_x := 36.0 + sin(z * 0.045) * 2.0
		if absf(x - creek_x) < 6.0 or _is_city_road_footprint(x, z):
			continue
		shrub_positions.append(Vector3(x, _terrain_height(x, z) + 0.85, z))
	# A deterministic broken ring keeps larger scrub visible from the city camera.
	for index in range(72):
		var angle := TAU * float(index) / 72.0
		var radius := 27.5 + sin(float(index) * 2.7) * 1.3
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if absf(x - HIGHWAY_CENTER_X) < 16.0 or x > _coastline(z) - 15.0 or _is_city_road_footprint(x, z):
			continue
		var creek_x := 36.0 + sin(z * 0.045) * 2.0
		if absf(x - creek_x) < 6.0:
			continue
		shrub_positions.append(Vector3(x, _terrain_height(x, z) + 0.9, z))
	shrub_batch.instance_count = shrub_positions.size()
	var shrub_palette: Array[Color] = [Color("#456A3C"), Color("#71834B"), Color("#536F52"), Color("#8B9256"), Color("#3D6046")]
	for index in range(shrub_positions.size()):
		var size := 0.88 + float((index * 11) % 9) * 0.105
		var yaw := float(index * 31 % 360) * PI / 180.0
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(size * 1.25, size, size * 0.92))
		shrub_batch.set_instance_transform(index, Transform3D(basis, shrub_positions[index]))
		shrub_batch.set_instance_color(index, shrub_palette[index % shrub_palette.size()])
	var shrubs := MultiMeshInstance3D.new()
	shrubs.name = "AustralianMeadowScrub"
	shrubs.multimesh = shrub_batch
	var shrub_material := StandardMaterial3D.new()
	shrub_material.vertex_color_use_as_albedo = true
	shrub_material.roughness = 1.0
	shrubs.material_override = shrub_material
	shrubs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shrubs.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	shrubs.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	shrubs.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(shrubs)

	var stone_mesh := SphereMesh.new()
	stone_mesh.radius = 1.0
	stone_mesh.height = 1.0
	stone_mesh.radial_segments = 7
	stone_mesh.rings = 4
	var stone_batch := MultiMesh.new()
	stone_batch.transform_format = MultiMesh.TRANSFORM_3D
	stone_batch.use_colors = true
	stone_batch.mesh = stone_mesh
	var stone_positions: Array[Vector3] = []
	for index in range(300):
		var x := -118.0 + fposmod(float(index) * 29.31, 190.0)
		var z := -87.0 + fposmod(float(index) * 41.17, 174.0)
		if absf(x) < 25.0 and absf(z) < 25.0:
			continue
		if absf(x - HIGHWAY_CENTER_X) < 14.0 or x > _coastline(z) - 10.0 or _is_city_road_footprint(x, z):
			continue
		stone_positions.append(Vector3(x, _terrain_height(x, z) + 0.12, z))
	for index in range(96):
		var angle := TAU * float(index) / 96.0
		var radius := 25.5 + float(index % 4) * 1.5
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if absf(x - HIGHWAY_CENTER_X) < 14.0 or x > _coastline(z) - 10.0 or _is_city_road_footprint(x, z):
			continue
		stone_positions.append(Vector3(x, _terrain_height(x, z) + 0.12, z))
	stone_batch.instance_count = stone_positions.size()
	var stone_palette: Array[Color] = [Color("#77766A"), Color("#9B8D75"), Color("#62665E"), Color("#8B795F")]
	for index in range(stone_positions.size()):
		var size := 0.18 + float((index * 5) % 8) * 0.095
		var basis := Basis(Vector3.UP, float(index * 53 % 360) * PI / 180.0).scaled(Vector3(size * 1.25, size * 0.48, size * 0.88))
		stone_batch.set_instance_transform(index, Transform3D(basis, stone_positions[index]))
		stone_batch.set_instance_color(index, stone_palette[index % stone_palette.size()])
	var stones := MultiMeshInstance3D.new()
	stones.name = "MeadowFieldstoneBatch"
	stones.multimesh = stone_batch
	var stone_material := StandardMaterial3D.new()
	stone_material.vertex_color_use_as_albedo = true
	stone_material.roughness = 1.0
	stones.material_override = stone_material
	stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stones.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	stones.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	stones.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(stones)

func _create_meadow_shrub_mesh() -> ArrayMesh:
	# Three irregular intersecting leaf masses make a readable scrub silhouette.
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.8
	sphere.radial_segments = 8
	sphere.rings = 5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.72, 0.78, 0.70)), Vector3.ZERO))
	surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.58, 0.60, 0.56)), Vector3(-0.48, -0.12, 0.10)))
	surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.62, 0.68, 0.58)), Vector3(0.43, -0.08, -0.18)))
	return surface.commit()



func _build_coastal_promenade() -> void:
	# A continuous timber promenade follows the curved Pacific shoreline.
	# One vertex-colored mesh keeps this landmark to a single draw call.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 120
	for step in range(SEGMENTS):
		var z0 := lerpf(-89.0, 89.0, float(step) / float(SEGMENTS))
		var z1 := lerpf(-89.0, 89.0, float(step + 1) / float(SEGMENTS))
		var x0 := _coastline(z0) - PROMENADE_OFFSET
		var x1 := _coastline(z1) - PROMENADE_OFFSET
		var p00 := Vector3(x0 - 2.2, _terrain_height(x0 - 2.2, z0) + 0.22, z0)
		var p01 := Vector3(x1 - 2.2, _terrain_height(x1 - 2.2, z1) + 0.22, z1)
		var p10 := Vector3(x0 + 2.2, _terrain_height(x0 + 2.2, z0) + 0.22, z0)
		var p11 := Vector3(x1 + 2.2, _terrain_height(x1 + 2.2, z1) + 0.22, z1)
		var plank_tint := 0.90 + 0.08 * sin(float(step) * 0.73)
		surface.set_color(Color(0.48, 0.31, 0.18) * plank_tint)
		surface.add_vertex(p00)
		surface.set_color(Color(0.58, 0.39, 0.23) * plank_tint)
		surface.add_vertex(p01)
		surface.set_color(Color(0.53, 0.35, 0.20) * plank_tint)
		surface.add_vertex(p10)
		surface.add_vertex(p10)
		surface.add_vertex(p01)
		surface.add_vertex(p11)
	surface.generate_normals()
	var promenade := MeshInstance3D.new()
	promenade.name = "PacificCoastalPromenade"
	promenade.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.82
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	promenade.material_override = material
	promenade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(promenade)


func _build_beach_palms() -> void:
	# Palms form a loose landscaped edge between the green park and wide sand.
	# Trunks and crowns each use one MultiMesh for mobile-friendly draw calls.
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 6.2
	trunk_mesh.radial_segments = 7
	var frond_mesh := _create_palm_frond_mesh()
	var trunk_batch := MultiMesh.new()
	trunk_batch.transform_format = MultiMesh.TRANSFORM_3D
	trunk_batch.mesh = trunk_mesh
	trunk_batch.instance_count = PALM_COUNT
	var crown_batch := MultiMesh.new()
	crown_batch.transform_format = MultiMesh.TRANSFORM_3D
	crown_batch.mesh = frond_mesh
	crown_batch.use_colors = true
	crown_batch.instance_count = PALM_COUNT
	for index in range(PALM_COUNT):
		var z := -83.0 + float(index) * 7.2 + sin(float(index) * 1.7) * 1.8
		var x := _coastline(z) - BEACH_WIDTH - 12.0 + sin(float(index) * 2.3) * 2.4
		var base := Vector3(x, _terrain_height(x, z), z)
		var yaw := float(index * 47 % 360) * PI / 180.0
		var trunk_basis := Basis(Vector3.UP, yaw).scaled(Vector3(1.0, 1.0 + float(index % 4) * 0.04, 1.0))
		trunk_batch.set_instance_transform(index, Transform3D(trunk_basis, base + Vector3(0.0, 3.1, 0.0)))
		var crown_basis := Basis(Vector3.UP, yaw).scaled(Vector3(0.96 + float(index % 3) * 0.08, 0.96, 0.96 + float(index % 2) * 0.1))
		crown_batch.set_instance_transform(index, Transform3D(crown_basis, base + Vector3(0.0, 6.1, 0.0)))
		crown_batch.set_instance_color(index, Color("#397A43") if index % 3 == 0 else Color("#4D914B"))
	var trunks := MultiMeshInstance3D.new()
	trunks.name = "PacificPalmTrunks"
	trunks.multimesh = trunk_batch
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("#A77A4D")
	bark.roughness = 0.95
	trunks.material_override = bark
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trunks)
	var crowns := MultiMeshInstance3D.new()
	crowns.name = "PacificPalmCrowns"
	crowns.multimesh = crown_batch
	var leaves := StandardMaterial3D.new()
	leaves.vertex_color_use_as_albedo = true
	leaves.roughness = 0.88
	leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	crowns.material_override = leaves
	crowns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowns)


func _create_palm_frond_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf_index in range(9):
		var angle := TAU * float(leaf_index) / 9.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var previous_left := Vector3.ZERO
		var previous_right := Vector3.ZERO
		for segment in range(7):
			var t := float(segment) / 6.0
			var next_t := float(segment + 1) / 6.0
			var center := direction * (t * 4.0) + Vector3(0.0, -1.75 * t * t, 0.0)
			var next_center := direction * (next_t * 4.0) + Vector3(0.0, -1.75 * next_t * next_t, 0.0)
			var side := Vector3(-direction.z, 0.0, direction.x)
			var width := sin(t * PI) * 0.24 + 0.03
			var next_width := sin(next_t * PI) * 0.24 + 0.014
			var left := center - side * width
			var right := center + side * width
			var next_left := next_center - side * next_width
			var next_right := next_center + side * next_width
			if segment > 0:
				surface.set_color(Color("#4E914A"))
				surface.add_vertex(previous_left)
				surface.add_vertex(next_left)
				surface.add_vertex(previous_right)
				surface.add_vertex(previous_right)
				surface.add_vertex(next_left)
				surface.add_vertex(next_right)
			previous_left = left
			previous_right = right
	surface.generate_normals()
	return surface.commit()



func _build_shoreline_foam() -> void:
	# Broken, naturally irregular surf line readable at mobile zoom levels.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 220
	for step in range(SEGMENTS):
		var z0 := lerpf(-TERRAIN_HALF_DEPTH, TERRAIN_HALF_DEPTH, float(step) / float(SEGMENTS))
		var z1 := lerpf(-TERRAIN_HALF_DEPTH, TERRAIN_HALF_DEPTH, float(step + 1) / float(SEGMENTS))
		var wave0 := sin(z0 * 0.31) * 0.62 + cos(z0 * 0.17) * 0.42
		var wave1 := sin(z1 * 0.31) * 0.62 + cos(z1 * 0.17) * 0.42
		var coast0 := _coastline(z0)
		var coast1 := _coastline(z1)
		var inner0 := Vector3(coast0 + 0.7 + wave0, 0.065, z0)
		var outer0 := Vector3(coast0 + 3.1 + wave0 * 1.4, 0.065, z0)
		var inner1 := Vector3(coast1 + 0.7 + wave1, 0.065, z1)
		var outer1 := Vector3(coast1 + 3.1 + wave1 * 1.4, 0.065, z1)
		var foam_strength := 0.38 + 0.24 * (0.5 + 0.5 * sin(float(step) * 0.73))
		surface.set_color(Color(0.88, 0.96, 0.96, foam_strength))
		surface.add_vertex(inner0)
		surface.set_color(Color(0.96, 0.99, 1.0, 0.04))
		surface.add_vertex(inner1)
		surface.set_color(Color(0.94, 0.98, 0.98, foam_strength * 0.72))
		surface.add_vertex(outer0)
		surface.add_vertex(outer0)
		surface.add_vertex(inner1)
		surface.add_vertex(outer1)
	var foam := MeshInstance3D.new()
	foam.name = "PacificShoreFoam"
	foam.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	foam.material_override = material
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam)


func _build_shoreline_details() -> void:
	# One low-poly MultiMesh replaces 38 independent pebble nodes/materials.
	# Per-instance scale, yaw and color preserve the varied natural shoreline.
	var pebbles := _create_shoreline_pebble_multimesh()
	add_child(pebbles)


func _create_shoreline_pebble_multimesh() -> MultiMeshInstance3D:
	const PEBBLE_COUNT := 38
	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radius = 1.0
	pebble_mesh.height = 2.0
	pebble_mesh.radial_segments = 10
	pebble_mesh.rings = 5
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = pebble_mesh
	multimesh.instance_count = PEBBLE_COUNT
	for index in range(PEBBLE_COUNT):
		multimesh.set_instance_transform(index, _shoreline_pebble_transform(index))
		multimesh.set_instance_color(index, _shoreline_pebble_color(index))
	var pebble_material := StandardMaterial3D.new()
	pebble_material.vertex_color_use_as_albedo = true
	pebble_material.roughness = 0.95
	var pebbles := MultiMeshInstance3D.new()
	pebbles.name = "ShorelinePebbleBatch"
	pebbles.multimesh = multimesh
	pebbles.material_override = pebble_material
	# Small ground stones add no useful cast shadows; disabling them saves mobile shadow work.
	pebbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pebbles.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	pebbles.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	pebbles.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return pebbles


func _shoreline_pebble_transform(index: int) -> Transform3D:
	var z := -88.0 + float(index) * 4.6
	var x := _coastline(z) - 1.8 + sin(float(index) * 4.1) * 1.8
	var radius := 0.28 + float(index % 3) * 0.09
	var yaw := float((index * 41) % 360) * PI / 180.0
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(radius, 0.11, radius * (0.82 + float(index % 4) * 0.06)))
	return Transform3D(basis, Vector3(x, 0.05, z))


func _shoreline_pebble_color(index: int) -> Color:
	var stone_palette: Array[Color] = [
		Color(0.55, 0.53, 0.46),
		Color(0.69, 0.65, 0.55),
		Color(0.42, 0.46, 0.43)
	]
	return stone_palette[index % stone_palette.size()]

func _build_cargo_ship_visual() -> void:
	_build_passenger_harbor()
	var ship := CargoShipVisualScript.new()
	ship.name = "CargoShipVisual"
	add_child(ship)


func _build_passenger_harbor() -> void:
	var harbor := Node3D.new()
	harbor.name = "PassengerHarbor"
	add_child(harbor)

	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color("#92734F")
	deck_material.roughness = 0.92
	var edge_material := StandardMaterial3D.new()
	edge_material.albedo_color = Color("#D5C6A8")
	edge_material.roughness = 0.86
	var support_material := StandardMaterial3D.new()
	support_material.albedo_color = Color("#66513D")
	support_material.roughness = 1.0

	# A compact timber pier links the beach to the deep-water side of the coast.
	_add_harbor_box(harbor, "HarborApproach", Vector3(157.0, 0.59, -22.0), Vector3(18.0, 0.34, 6.8), deck_material)
	_add_harbor_box(harbor, "PierDeck", Vector3(175.0, 0.66, -22.0), Vector3(18.0, 0.34, 9.0), deck_material)
	_add_harbor_box(harbor, "PierOuterEdge", Vector3(175.0, 0.84, -26.48), Vector3(18.0, 0.10, 0.18), edge_material)
	_add_harbor_box(harbor, "PierInnerEdge", Vector3(175.0, 0.84, -17.52), Vector3(18.0, 0.10, 0.18), edge_material)

	for index in range(7):
		var x := 167.0 + float(index) * 2.7
		for z in [-25.6, -18.4]:
			var pile := MeshInstance3D.new()
			pile.name = "PierSupport_%02d_%s" % [index, str(z)]
			var pile_mesh := CylinderMesh.new()
			pile_mesh.top_radius = 0.16
			pile_mesh.bottom_radius = 0.22
			pile_mesh.height = 1.65
			pile.mesh = pile_mesh
			pile.position = Vector3(x, -0.10, z)
			pile.material_override = support_material
			harbor.add_child(pile)

	# A short sloped gangway meets the ferry bow at the scheduled berth.
	var gangway := MeshInstance3D.new()
	gangway.name = "FerryGangway"
	var gangway_mesh := BoxMesh.new()
	gangway_mesh.size = Vector3(6.0, 0.16, 2.5)
	gangway.mesh = gangway_mesh
	gangway.position = Vector3(187.0, 0.91, -22.0)
	gangway.rotation.z = deg_to_rad(3.0)
	gangway.material_override = edge_material
	harbor.add_child(gangway)

	# The terminal sits on the dry side of the pier; its glazing faces the water.
	var terminal_material := StandardMaterial3D.new()
	terminal_material.albedo_color = Color("#E7DDC8")
	terminal_material.roughness = 0.88
	_add_harbor_box(harbor, "FerryTerminal", Vector3(156.8, 1.55, -22.0), Vector3(7.0, 2.7, 8.0), terminal_material)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color("#5A9AAE")
	glass_material.metallic = 0.08
	glass_material.roughness = 0.24
	_add_harbor_box(harbor, "TerminalWaterfrontWindows", Vector3(160.36, 1.72, -22.0), Vector3(0.08, 1.15, 5.6), glass_material)
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("#B85D43")
	roof_material.roughness = 0.9
	_add_harbor_box(harbor, "TerminalRoof", Vector3(156.8, 2.98, -22.0), Vector3(7.5, 0.22, 8.5), roof_material)

	var sign := Label3D.new()
	sign.name = "PassengerFerrySign"
	sign.text = "FERRY  •  TERMINAL"
	sign.font_size = 42
	sign.pixel_size = 0.012
	sign.position = Vector3(160.7, 2.4, -22.0)
	sign.rotation.y = deg_to_rad(90.0)
	sign.modulate = Color("#F6F0E3")
	harbor.add_child(sign)


func _add_harbor_box(parent: Node3D, node_name: String, box_position: Vector3, dimensions: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = box_position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _build_sunlight() -> void:
	add_child(_create_warm_fill_light())


func _create_warm_fill_light() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "CoastalWarmSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.70)
	sun.light_energy = 0.34
	# The main scene's key DirectionalLight3D owns the single shadow map.
	# This warm secondary light remains as a soft fill, but must not allocate a
	# second directional shadow map or create conflicting duplicate shadows.
	sun.shadow_enabled = false
	sun.light_specular = 0.35
	return sun


func _add_headless_test_markers() -> void:
	# These names are part of the smoke-test scene contract; they intentionally
	# contain no MeshInstance3D nodes and therefore allocate no render meshes.
	for marker_name in ["NaturalTerrain", "CoastalWater", "BuildablePlotGrid", "LandExpansionMarkers", "CoastalHighway", "HighwayLighting", "PacificCoastalPromenade", "PacificPalmTrunks", "PacificPalmCrowns", "PassengerHarbor", "CargoShipVisual"]:
		var marker := Node3D.new()
		marker.name = marker_name
		add_child(marker)
