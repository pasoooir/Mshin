extends Node3D
## Procedural, mobile-friendly green mountain horizon surrounding the playable map.
## Four batched ridge meshes, one grass plane and two MultiMesh detail batches
## replace an exposed world edge with a continuous natural backdrop.

const LAND_SIZE := Vector2(1000.0, 1000.0)
const RIDGE_INNER_RADIUS := 170.0
const RIDGE_OUTER_RADIUS := 330.0
const RIDGE_HALF_LENGTH := 330.0
const RIDGE_SEGMENTS := 64
const RIDGE_DEPTH_STEPS := 14
const SHRUB_COUNT := 320
const GRASS_COUNT := 760

func _ready() -> void:
	_build_backdrop_land()
	_build_mountain_ridges()
	_build_mountain_shrubs()
	_build_mountain_grass()


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
	if (world_position.x > 49.0 && world_position.x < 160.0 && abs(world_position.z) < 96.0) {
		discard;
	}
	float grain = sin(world_position.x * 0.12 + world_position.z * 0.08) * cos(world_position.z * 0.11 - world_position.x * 0.06);
	ALBEDO = vec3(0.16, 0.31, 0.18) + vec3(grain * 0.012);
	ROUGHNESS = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_mountain_ridges() -> void:
	for side in range(4):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for along_index in range(RIDGE_SEGMENTS):
			var t0 := lerpf(-RIDGE_HALF_LENGTH, RIDGE_HALF_LENGTH, float(along_index) / RIDGE_SEGMENTS)
			var t1 := lerpf(-RIDGE_HALF_LENGTH, RIDGE_HALF_LENGTH, float(along_index + 1) / RIDGE_SEGMENTS)
			for depth_index in range(RIDGE_DEPTH_STEPS):
				var d0 := float(depth_index) / RIDGE_DEPTH_STEPS
				var d1 := float(depth_index + 1) / RIDGE_DEPTH_STEPS
				_add_ridge_vertex(surface, side, t0, d0)
				_add_ridge_vertex(surface, side, t1, d0)
				_add_ridge_vertex(surface, side, t0, d1)
				_add_ridge_vertex(surface, side, t1, d0)
				_add_ridge_vertex(surface, side, t1, d1)
				_add_ridge_vertex(surface, side, t0, d1)
		surface.generate_normals()
		var ridge := MeshInstance3D.new()
		ridge.name = ["NorthMountainRidge", "SouthMountainRidge", "WestMountainRidge", "EastMountainRidge"][side]
		ridge.mesh = surface.commit()
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ridge.material_override = material
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ridge)


func _add_ridge_vertex(surface: SurfaceTool, side: int, along: float, depth: float) -> void:
	var point := _ridge_point(side, along, depth)
	surface.set_color(_ridge_color(along, depth, side))
	surface.set_uv(Vector2(along * 0.012, depth * 5.0))
	surface.add_vertex(point)


func _ridge_point(side: int, along: float, depth: float) -> Vector3:
	var radius := lerpf(RIDGE_INNER_RADIUS, RIDGE_OUTER_RADIUS, depth)
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


func _ridge_height(along: float, depth: float, side: int) -> float:
	var end_fade := smoothstep(0.0, 1.0, clampf((RIDGE_HALF_LENGTH - absf(along)) / 72.0, 0.0, 1.0))
	var rolling_peaks := 0.5 + 0.5 * sin(along * 0.031 + float(side) * 1.7) + 0.16 * cos(along * 0.073 - float(side))
	var peak_height := 34.0 + rolling_peaks * 23.0
	return peak_height * pow(maxf(0.0, sin(PI * depth)), 0.82) * end_fade


func _ridge_color(along: float, depth: float, side: int) -> Color:
	var slope := sin(PI * depth)
	var variation := 0.5 + 0.5 * sin(along * 0.11 + float(side) * 2.3)
	var dark_green := Color("#1D4027")
	var meadow_green := Color("#315B35")
	var color := dark_green.lerp(meadow_green, 0.24 + slope * 0.46)
	return color.lerp(Color("#426B3A"), variation * slope * 0.12)


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
