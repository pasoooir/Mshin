extends Node3D

const CargoShipVisualScript = preload("res://scripts/world/CargoShipVisual.gd")
const MeadowLivestockScript = preload("res://scripts/world/MeadowLivestock.gd")

const TERRAIN_HALF_DEPTH := 90.0
const TERRAIN_LEFT := -90.0
const TERRAIN_DIVISIONS := 48
const CITY_HALF_EXTENT := 40

# Permanent six-lane divided motorway at the city entrance. Keep the access
# opening aligned with the seeded Gateway connector and outside the build grid.
const HIGHWAY_CENTER_X := -55.0
const HIGHWAY_ASPHALT_WIDTH := 24.0
const HIGHWAY_SHOULDER_WIDTH := 26.8
const HIGHWAY_LENGTH := 190.0
const HIGHWAY_LANE_COUNT := 6
const HIGHWAY_MEDIAN_WIDTH := 0.8
const HIGHWAY_LAMP_COUNT := 12
const MEADOW_SHEEP_COUNT := 12
const MEADOW_CATTLE_COUNT := 3

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
	_build_environment()
	_build_terrain()
	_build_land_expansion_markers()
	_build_city_grid()
	_build_coastal_highway()
	_build_highway_lighting()
	_build_tree_belts()
	_build_grass_detail()
	_build_meadow_livestock()
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
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.08
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.82, 0.82)
	environment.fog_density = 0.00125
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
		_:
			sky_material.sky_top_color = Color(0.12, 0.34, 0.55)
			sky_material.sky_horizon_color = Color(0.72, 0.84, 0.91)
			sky_material.ground_bottom_color = Color(0.13, 0.19, 0.17)
			sky_material.ground_horizon_color = Color(0.55, 0.63, 0.61)
			environment.fog_light_color = Color(0.72, 0.82, 0.82)

func _on_region_changed(_region_id: String) -> void:
	refresh_region_appearance()

func refresh_region_appearance() -> void:
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if is_instance_valid(world_environment) and world_environment.environment != null and world_environment.environment.sky != null:
		var sky_material := world_environment.environment.sky.sky_material as ProceduralSkyMaterial
		if is_instance_valid(sky_material):
			_apply_region_climate(sky_material, world_environment.environment)
	for node_name in ["NaturalTerrain", "CoastalWater", "ShallowWater", "LandExpansionMarkers"]:
		var old_node := get_node_or_null(node_name)
		if is_instance_valid(old_node):
			old_node.free()
	_build_terrain()
	_build_land_expansion_markers()


func _on_land_expansion_changed() -> void:
	for node_name in ["NaturalTerrain", "CoastalWater", "ShallowWater", "LandExpansionMarkers"]:
		var old_node := get_node_or_null(node_name)
		if is_instance_valid(old_node):
			old_node.free()
	_build_terrain()
	_build_land_expansion_markers()


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
	var terrain_material := StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.albedo_texture = _create_grass_texture()
	terrain_material.roughness = 1.0
	terrain_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain.material_override = terrain_material
	add_child(terrain)

	var water := MeshInstance3D.new()
	water.name = "CoastalWater"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(110.0, 190.0)
	water_mesh.subdivide_width = 48
	water_mesh.subdivide_depth = 48
	water.mesh = water_mesh
	water.position = Vector3(104.0, -0.18, 0.0)
	water.material_override = _create_water_material()
	add_child(water)

	var shallow_water := MeshInstance3D.new()
	shallow_water.name = "ShallowWater"
	var shallow_mesh := PlaneMesh.new()
	shallow_mesh.size = Vector2(8.0, 190.0)
	shallow_mesh.subdivide_width = 8
	shallow_mesh.subdivide_depth = 48
	shallow_water.mesh = shallow_mesh
	shallow_water.position = Vector3(54.0, -0.12, 0.0)
	shallow_water.material_override = _create_shallow_water_material()
	add_child(shallow_water)

func _add_terrain_vertex(surface: SurfaceTool, point: Vector3) -> void:
	# World-space UVs keep the subtle ground grain consistent across the terrain mesh.
	surface.set_uv(Vector2(point.x * 0.16, point.z * 0.16))
	var coast := _coastline(point.z)
	var broad_noise := sin(point.x * 0.31 + point.z * 0.17) * cos(point.z * 0.23 - point.x * 0.11)
	var fine_noise := sin(point.x * 1.7 + point.z * 2.3) * cos(point.z * 1.35 - point.x * 0.8)
	var blend := clampf((broad_noise * 0.72 + fine_noise * 0.28 + 1.0) * 0.5, 0.0, 1.0)
	var color: Color
	if point.x > coast - 7.0:
		# Keep a natural wet-sand transition at the shoreline.
		color = Color("#9A8057").lerp(Color("#D5C18E"), blend)
	elif point.x > coast - 13.0:
		# Sparse coastal scrub blends the grass into the beach instead of a hard edge.
		color = Color("#587744").lerp(Color("#A49A61"), blend * 0.58)
	else:
		# A brighter temperate meadow: several green families with restrained
		# olive and dry-grass variation, never a flat monochrome green carpet.
		var grass_palette: Array[Color] = [
			Color("#397B36"), Color("#47883A"),
			Color("#559443"), Color("#679A49"),
			Color("#4A873F"), Color("#739B4D")
		]
		var palette_index := int(abs(floor(point.x * 0.31 + point.z * 0.19))) % grass_palette.size()
		color = grass_palette[palette_index].lerp(Color("#A0A15B"), blend * 0.20)
		if fine_noise > 0.58:
			color = color.lerp(Color("#315F31"), 0.13)
		elif fine_noise < -0.62:
			color = color.lerp(Color("#8E9C50"), 0.10)
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
	var in_east_pasture := point.x >= -42.0 and point.x <= 44.0
	var in_west_pasture := point.x >= -90.0 and point.x <= -69.0
	if absf(point.z) >= 80.0 and absf(point.z) <= 90.0 and (in_east_pasture or in_west_pasture):
		color = color.lerp(Color("#B99A68"), 0.52)
	if not LandExpansionManager.is_world_position_unlocked(point):
		color = color.lerp(Color("#302B24"), 0.34)
	surface.set_color(color)
	surface.add_vertex(point)

func _coastline(z: float) -> float:
	return 51.0 + sin(z * 0.045) * 2.2 + cos(z * 0.021) * 1.1


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
	add_child(marker)

func _build_city_grid() -> void:
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	for coordinate in range(-CITY_HALF_EXTENT, CITY_HALF_EXTENT + 1, 8):
		lines.set_color(Color(0.72, 0.82, 0.68, 0.30))
		lines.add_vertex(Vector3(float(coordinate), 0.035, -CITY_HALF_EXTENT))
		lines.add_vertex(Vector3(float(coordinate), 0.035, CITY_HALF_EXTENT))
		lines.add_vertex(Vector3(-CITY_HALF_EXTENT, 0.035, float(coordinate)))
		lines.add_vertex(Vector3(CITY_HALF_EXTENT, 0.035, float(coordinate)))
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
		median_multimesh.set_instance_transform(index, Transform3D(basis, Vector3(HIGHWAY_CENTER_X, 0.435, side * 49.5)))
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
	access_mesh.size = Vector3(27.5, 0.16, 4.6)
	access_mesh.subdivide_width = 4
	access_mesh.subdivide_depth = 2
	access_road.mesh = access_mesh
	access_road.position = Vector3(-30.25, 0.095, 0.0)
	var connector_asphalt := highway_asphalt.duplicate() as StandardMaterial3D
	connector_asphalt.uv1_scale = Vector3(14.0, 3.0, 1.0)
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
		for segment in range(-15, 16):
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
	for x in [-82.0, -74.0, -30.0, -14.0, 12.0, 28.0, 42.0]:
		positions.append(Vector3(x, 0.0, -68.0 + sin(x * 0.1) * 4.0))
		positions.append(Vector3(x + 4.0, 0.0, 68.0 + cos(x * 0.12) * 4.0))
	for z in [-52.0, -28.0, 26.0, 48.0]:
		positions.append(Vector3(-76.0 + sin(z) * 3.0, 0.0, z))
	for z in [-58.0, -36.0, 22.0, 46.0]:
		positions.append(Vector3(44.0 + sin(z * 0.08) * 2.0, 0.0, z))

	# All tree geometry is measured from y=0: root flare touches the terrain,
	# trunk bottom is exactly at ground height, and the crown overlaps the trunk.
	var root_mesh := CylinderMesh.new()
	root_mesh.top_radius = 0.24
	root_mesh.bottom_radius = 0.34
	root_mesh.height = 0.16
	var bark_material := StandardMaterial3D.new()
	bark_material.vertex_color_use_as_albedo = true
	bark_material.albedo_texture = _create_bark_texture()
	bark_material.roughness = 1.0
	root_mesh.material = bark_material

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 2.5
	trunk_mesh.material = bark_material

	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.35
	canopy_mesh.height = 2.5
	var canopy_material := StandardMaterial3D.new()
	canopy_material.vertex_color_use_as_albedo = true
	canopy_material.albedo_texture = _create_foliage_texture()
	canopy_material.roughness = 0.96
	canopy_mesh.material = canopy_material

	var tree_shadows := _create_tree_shadow_multimesh(positions)
	add_child(tree_shadows)
	var roots := _create_tree_multimesh("TreeRootBases", root_mesh, positions, 0.08)
	var trunks := _create_tree_multimesh("TreeTrunks", trunk_mesh, positions, 1.25)
	var crowns := _create_tree_multimesh("TreeCanopies", canopy_mesh, positions, 2.55)
	add_child(roots)
	add_child(trunks)
	add_child(crowns)


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
		Color(0.52, 0.78, 0.38), Color(0.39, 0.68, 0.31),
		Color(0.62, 0.75, 0.32), Color(0.31, 0.59, 0.29),
		Color(0.72, 0.79, 0.40), Color(0.42, 0.62, 0.25)
	]
	for index in range(positions.size()):
		var scale := 0.82 + float((index * 7) % 5) * 0.09
		var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		var origin := positions[index] + Vector3(0.0, height_offset * scale, 0.0)
		multimesh.set_instance_transform(index, Transform3D(basis, origin))
		if node_name == "TreeCanopies":
			multimesh.set_instance_color(index, foliage_palette[index % foliage_palette.size()])
		elif node_name == "TreeTrunks":
			multimesh.set_instance_color(index, trunk_palette[index % trunk_palette.size()])
		else:
			multimesh.set_instance_color(index, root_palette[index % root_palette.size()])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
			var value := clampf(0.93 + broad * 0.025 + fine * 0.018, 0.86, 1.0)
			var green := clampf(value + 0.025, 0.0, 1.0)
			var blue := clampf(value - 0.055, 0.0, 1.0)
			var texel := Color(value, green, blue, 1.0)
			if speckle > 0.992:
				texel = texel.lerp(Color("#C0B276"), 0.30)
			image.set_pixel(x, y, texel)
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
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform vec4 deep_color : source_color = vec4(0.015, 0.20, 0.38, 1.0);
uniform vec4 blue_color : source_color = vec4(0.035, 0.43, 0.62, 1.0);
uniform vec4 turquoise_color : source_color = vec4(0.12, 0.67, 0.70, 1.0);
uniform float wave_height = 0.11;
varying vec3 world_position;
void vertex() {
	vec3 p = VERTEX;
	float wave_a = sin((p.x * 0.22) + (p.z * 0.12) + TIME * 1.15);
	float wave_b = cos((p.x * 0.11) - (p.z * 0.19) + TIME * 0.82);
	p.y += (wave_a * 0.55 + wave_b * 0.45) * wave_height;
	VERTEX = p;
	world_position = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}
void fragment() {
	float bands = sin(world_position.x * 0.075 + world_position.z * 0.045 + TIME * 0.45);
	float depth_mix = smoothstep(-0.9, 0.9, bands);
	vec3 water_color = mix(deep_color.rgb, blue_color.rgb, depth_mix);
	float turquoise = smoothstep(0.25, 0.95, sin(world_position.x * 0.035 + world_position.z * 0.018));
	water_color = mix(water_color, turquoise_color.rgb, turquoise * 0.42);
	float ripple = pow(max(0.0, sin(world_position.x * 0.62 + world_position.z * 0.18 + TIME * 1.8)), 18.0);
	ALBEDO = water_color + vec3(ripple * 0.16);
	ROUGHNESS = 0.22;
	METALLIC = 0.08;
	SPECULAR = 0.72;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _create_shallow_water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
void fragment() {
	float ripple = sin(UV.x * 42.0 + TIME * 1.2) * cos(UV.y * 17.0 - TIME * 0.7);
	vec3 lagoon = mix(vec3(0.10, 0.56, 0.62), vec3(0.25, 0.76, 0.73), ripple * 0.18 + 0.35);
	ALBEDO = lagoon;
	ROUGHNESS = 0.3;
	SPECULAR = 0.65;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _build_grass_detail() -> void:
	# Sparse, instanced grass blades add real depth without creating thousands of scene nodes.
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.075, 0.34, 0.055)
	var blade_material := StandardMaterial3D.new()
	blade_material.vertex_color_use_as_albedo = true
	blade_material.roughness = 0.92
	blade_mesh.material = blade_material
	var positions: Array[Vector3] = []
	for index in range(900):
		var x := -42.0 + fposmod(float(index) * 17.31, 82.0)
		var z := -84.0 + fposmod(float(index) * 29.17, 168.0)
		if x > 30.0 or absf(z) < 43.0 and x > -40.0:
			continue
		if x > _coastline(z) - 14.0:
			continue
		positions.append(Vector3(x, 0.14, z))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = blade_mesh
	multimesh.instance_count = positions.size()
	var grass_palette: Array[Color] = [Color(0.20, 0.42, 0.13), Color(0.34, 0.51, 0.17), Color(0.52, 0.55, 0.22), Color(0.65, 0.48, 0.22), Color(0.13, 0.33, 0.15)]
	for index in range(positions.size()):
		var scale := 0.55 + float((index * 13) % 9) * 0.12
		var rotation := Basis(Vector3.UP, float(index % 12) * 0.5236).scaled(Vector3(scale, scale, scale))
		multimesh.set_instance_transform(index, Transform3D(rotation, positions[index]))
		multimesh.set_instance_color(index, grass_palette[index % grass_palette.size()])
	var grass := MultiMeshInstance3D.new()
	grass.name = "ColorfulGrassDetail"
	grass.multimesh = multimesh
	add_child(grass)

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
	_register_livestock_part(flock, sheep_legs, sheep_positions.size(), 0, leg_offsets)

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
	_register_livestock_part(flock, cow_legs, cattle_positions.size(), sheep_positions.size(), leg_offsets)


func _register_livestock_part(flock: Node3D, instance: MultiMeshInstance3D, animal_count: int, owner_offset: int, local_offsets: Array[Vector3]) -> void:
	var owners: Array[int] = []
	var offsets: Array[Vector3] = []
	for animal_index in range(animal_count):
		for local_offset in local_offsets:
			owners.append(owner_offset + animal_index)
			offsets.append(local_offset)
	flock.call("register_part", instance, owners, offsets)


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


func _build_shoreline_details() -> void:
	# A pale wet-sand band and scattered shoreline rocks soften the land-to-water transition.
	for index in range(38):
		var z := -88.0 + float(index) * 4.6
		var x := _coastline(z) - 1.8
		var pebble := MeshInstance3D.new()
		var pebble_mesh := SphereMesh.new()
		pebble_mesh.radius = 0.28 + float(index % 3) * 0.09
		pebble_mesh.height = 0.22
		pebble.mesh = pebble_mesh
		pebble.position = Vector3(x + sin(float(index) * 4.1) * 1.8, 0.05, z)
		var pebble_material := StandardMaterial3D.new()
		var stone_palette: Array[Color] = [Color(0.55, 0.53, 0.46), Color(0.69, 0.65, 0.55), Color(0.42, 0.46, 0.43)]
		pebble_material.albedo_color = stone_palette[index % stone_palette.size()]
		pebble_material.roughness = 0.95
		pebble.material_override = pebble_material
		add_child(pebble)

func _build_cargo_ship_visual() -> void:
	var ship := CargoShipVisualScript.new()
	ship.name = "CargoShipVisual"
	add_child(ship)

func _build_sunlight() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "CoastalWarmSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.70)
	sun.light_energy = 0.34
	# One directional shadow source keeps building and tree shadows coherent.
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.40
	sun.shadow_blur = 1.0
	sun.shadow_bias = 0.045
	sun.shadow_normal_bias = 0.85
	sun.directional_shadow_max_distance = 88.0
	add_child(sun)


func _add_headless_test_markers() -> void:
	# These names are part of the smoke-test scene contract; they intentionally
	# contain no MeshInstance3D nodes and therefore allocate no render meshes.
	for marker_name in ["NaturalTerrain", "CoastalWater", "BuildablePlotGrid", "LandExpansionMarkers", "CoastalHighway", "HighwayLighting", "MeadowLivestock", "CargoShipVisual"]:
		var marker := Node3D.new()
		marker.name = marker_name
		add_child(marker)
