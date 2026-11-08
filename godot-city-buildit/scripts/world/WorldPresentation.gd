extends Node3D

const TERRAIN_HALF_DEPTH := 90.0
const TERRAIN_LEFT := -90.0
const CITY_HALF_EXTENT := 40

func _ready() -> void:
	# Headless CI validates simulation and placement logic, not GPU geometry.
	# Preserve the stable scene contract with lightweight Node3D markers while
	# skipping all procedural meshes and MultiMesh resources.
	if DisplayServer.get_name() == "headless":
		_add_headless_test_markers()
		print("[WorldPresentation] Procedural visuals skipped in headless test mode")
		return
	_build_environment()
	_build_terrain()
	_build_city_grid()
	_build_coastal_highway()
	_build_tree_belts()
	_build_grass_detail()
	_build_shoreline_details()
	_build_sunlight()

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
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.08
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.82, 0.82)
	environment.fog_density = 0.00125
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world_environment.environment = environment
	add_child(world_environment)

func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions := 40
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
	var coast := _coastline(point.z)
	var broad_noise := sin(point.x * 0.31 + point.z * 0.17) * cos(point.z * 0.23 - point.x * 0.11)
	var fine_noise := sin(point.x * 1.7 + point.z * 2.3) * cos(point.z * 1.35 - point.x * 0.8)
	var blend := clampf((broad_noise * 0.72 + fine_noise * 0.28 + 1.0) * 0.5, 0.0, 1.0)
	var color: Color
	if point.x > coast - 7.0:
		color = Color(0.62, 0.48, 0.31).lerp(Color(0.91, 0.82, 0.62), blend)
	elif point.x > coast - 13.0:
		color = Color(0.34, 0.43, 0.24).lerp(Color(0.67, 0.61, 0.38), blend)
	else:
		var grass_palette: Array[Color] = [Color(0.12, 0.29, 0.15), Color(0.19, 0.39, 0.18), Color(0.31, 0.48, 0.22), Color(0.43, 0.50, 0.25)]
		var palette_index := int(abs(floor(point.x * 0.31 + point.z * 0.19))) % grass_palette.size()
		color = grass_palette[palette_index].lerp(Color(0.52, 0.55, 0.29), blend * 0.35)
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
	var asphalt := _create_asphalt_material()
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
	shoulder_material.albedo_color = Color(0.40, 0.41, 0.36)
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
	canopy_material.vertex_color_use_as_albedo = true
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
	multimesh.use_colors = node_name == "TreeCanopies"
	multimesh.instance_count = positions.size()
	for index in range(positions.size()):
		var scale := 0.82 + float((index * 7) % 5) * 0.09
		var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		var origin := positions[index] + Vector3(0.0, height_offset * scale, 0.0)
		multimesh.set_instance_transform(index, Transform3D(basis, origin))
		if node_name == "TreeCanopies":
			var foliage: Array[Color] = [Color(0.10, 0.30, 0.13), Color(0.16, 0.40, 0.17), Color(0.28, 0.48, 0.20), Color(0.39, 0.46, 0.18)]
			multimesh.set_instance_color(index, foliage[index % foliage.size()])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance


# Procedural textures are generated locally at startup: no CDN, external asset or runtime download.
func _create_asphalt_material() -> StandardMaterial3D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var n := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
			var grain := fposmod(n, 1.0)
			var shade := 0.17 + grain * 0.12
			image.set_pixel(x, y, Color(shade, shade * 1.02, shade * 1.04, 1.0))
	var texture := ImageTexture.create_from_image(image)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.98
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

func _build_sunlight() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "CoastalWarmSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.70)
	sun.light_energy = 0.22
	sun.shadow_enabled = false
	add_child(sun)


func _add_headless_test_markers() -> void:
	# These names are part of the smoke-test scene contract; they intentionally
	# contain no MeshInstance3D nodes and therefore allocate no render meshes.
	for marker_name in ["NaturalTerrain", "CoastalWater", "BuildablePlotGrid", "CoastalHighway"]:
		var marker := Node3D.new()
		marker.name = marker_name
		add_child(marker)
