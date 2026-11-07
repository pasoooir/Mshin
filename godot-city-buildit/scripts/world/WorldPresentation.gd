extends Node3D

const TERRAIN_HALF_DEPTH := 90.0
const TERRAIN_LEFT := -90.0
const CITY_HALF_EXTENT := 40.0

func _ready() -> void:
	_build_environment()
	_build_terrain()
	_build_city_grid()
	_build_coastal_highway()
	_build_tree_belts()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.34, 0.55)
	sky_material.sky_horizon_color = Color(0.72, 0.84, 0.91)
	sky_material.ground_bottom_color = Color(0.13, 0.19, 0.17)
	sky_material.ground_horizon_color = Color(0.55, 0.63, 0.61)
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.75, 0.79)
	environment.fog_density = 0.0018
	world_environment.environment = environment
	add_child(world_environment)

func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions := 64
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
	terrain_material.roughness = 1.0
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain.material_override = terrain_material
	add_child(terrain)

	var water := MeshInstance3D.new()
	water.name = "CoastalWater"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(110.0, 190.0)
	water.mesh = water_mesh
	water.position = Vector3(104.0, -0.18, 0.0)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.055, 0.34, 0.48)
	water_material.roughness = 0.24
	water_material.metallic = 0.12
	water_material.clearcoat_enabled = true
	water_material.clearcoat = 0.32
	water.material_override = water_material
	add_child(water)

	var shallow_water := MeshInstance3D.new()
	shallow_water.name = "ShallowWater"
	var shallow_mesh := PlaneMesh.new()
	shallow_mesh.size = Vector2(8.0, 190.0)
	shallow_water.mesh = shallow_mesh
	shallow_water.position = Vector3(54.0, -0.12, 0.0)
	var shallow_material := StandardMaterial3D.new()
	shallow_material.albedo_color = Color(0.22, 0.62, 0.68)
	shallow_material.roughness = 0.38
	shallow_water.material_override = shallow_material
	add_child(shallow_water)

func _add_terrain_vertex(surface: SurfaceTool, point: Vector3) -> void:
	var coast := _coastline(point.z)
	var noise := sin(point.x * 0.31 + point.z * 0.17) * cos(point.z * 0.23 - point.x * 0.11)
	var color: Color
	if point.x > coast - 7.0:
		color = Color(0.73, 0.64, 0.46).lerp(Color(0.88, 0.80, 0.62), (noise + 1.0) * 0.5)
	else:
		color = Color(0.16, 0.34, 0.19).lerp(Color(0.31, 0.48, 0.25), (noise + 1.0) * 0.5)
	surface.set_color(color)
	surface.add_vertex(point)

func _coastline(z: float) -> float:
	return 51.0 + sin(z * 0.045) * 2.2 + cos(z * 0.021) * 1.1

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
	var highway := MeshInstance3D.new()
	highway.name = "CoastalHighway"
	var highway_mesh := BoxMesh.new()
	highway_mesh.size = Vector3(8.0, 0.16, 190.0)
	highway.mesh = highway_mesh
	highway.position = Vector3(-48.0, 0.06, 0.0)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.105, 0.12, 0.14)
	asphalt.roughness = 0.96
	highway.material_override = asphalt
	add_child(highway)
	_add_road_marking(Vector3(-48.0, 0.15, 0.0), Vector3(0.13, 0.015, 188.0), Color(1.0, 0.76, 0.18))
	for lane_x in [-50.0, -46.0]:
		for segment in range(-15, 16):
			_add_road_marking(Vector3(lane_x, 0.151, float(segment) * 6.0), Vector3(0.075, 0.012, 3.0), Color(0.88, 0.91, 0.89))
	for edge_x in [-52.0, -44.0]:
		_add_road_marking(Vector3(edge_x, 0.15, 0.0), Vector3(0.12, 0.012, 188.0), Color(0.82, 0.84, 0.80))
	var shoulder := MeshInstance3D.new()
	shoulder.name = "HighwayShoulder"
	var shoulder_mesh := BoxMesh.new()
	shoulder_mesh.size = Vector3(9.2, 0.08, 190.0)
	shoulder.mesh = shoulder_mesh
	shoulder.position = Vector3(-48.0, 0.015, 0.0)
	var shoulder_material := StandardMaterial3D.new()
	shoulder_material.albedo_color = Color(0.34, 0.36, 0.34)
	shoulder_material.roughness = 1.0
	shoulder.material_override = shoulder_material
	add_child(shoulder)
	# Keep the asphalt on top of the shoulder while retaining a visible verge.
	highway.position.y = 0.075
	var guardrail_material := StandardMaterial3D.new()
	guardrail_material.albedo_color = Color(0.62, 0.66, 0.67)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.12, 0.55, 190.0)
		rail.mesh = rail_mesh
		rail.position = Vector3(-48.0 + side * 4.75, 0.46, 0.0)
		rail.material_override = guardrail_material
		add_child(rail)
	var access_road := MeshInstance3D.new()
	access_road.name = "HighwayCityConnector"
	var access_mesh := BoxMesh.new()
	access_mesh.size = Vector3(30.0, 0.10, 4.2)
	access_road.mesh = access_mesh
	access_road.position = Vector3(-32.0, 0.13, 0.0)
	access_road.material_override = asphalt
	add_child(access_road)

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
	for x in [-76.0, -64.0, -30.0, -14.0, 12.0, 28.0, 42.0]:
		positions.append(Vector3(x, 0.0, -68.0 + sin(x * 0.1) * 4.0))
		positions.append(Vector3(x + 4.0, 0.0, 68.0 + cos(x * 0.12) * 4.0))
	for z in [-52.0, -28.0, 26.0, 48.0]:
		positions.append(Vector3(-76.0 + sin(z) * 3.0, 0.0, z))
	for z in [-58.0, -36.0, 22.0, 46.0]:
		positions.append(Vector3(44.0 + sin(z * 0.08) * 2.0, 0.0, z))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 2.5
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.30, 0.19, 0.12)
	trunk_material.roughness = 1.0
	trunk_mesh.material = trunk_material
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.35
	canopy_mesh.height = 2.5
	var canopy_material := StandardMaterial3D.new()
	canopy_material.albedo_color = Color(0.13, 0.34, 0.17)
	canopy_material.roughness = 0.92
	canopy_mesh.material = canopy_material
	var trunks := _create_tree_multimesh("TreeTrunks", trunk_mesh, positions, 1.0)
	var crowns := _create_tree_multimesh("TreeCanopies", canopy_mesh, positions, 2.35)
	add_child(trunks)
	add_child(crowns)

func _create_tree_multimesh(node_name: String, mesh: Mesh, positions: Array[Vector3], height_offset: float) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for index in range(positions.size()):
		var scale := 0.82 + float((index * 7) % 5) * 0.09
		var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		var origin := positions[index] + Vector3(0.0, height_offset * scale, 0.0)
		multimesh.set_instance_transform(index, Transform3D(basis, origin))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance
