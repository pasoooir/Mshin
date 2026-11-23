extends Node3D
class_name StylizedFoliageSystem

const SeasonManagerScript = preload("res://scripts/world/FoliageSeasonManager.gd")
const CHUNK_SIZE := 64.0
const LOD_BEGIN := [0.0, 38.0, 108.0]
const LOD_END := [46.0, 118.0, 280.0]
const LOD_CARDS := [10, 6, 3]
const LOD_SEGMENTS_X := [3, 2, 1]
const LOD_SEGMENTS_Y := [4, 3, 2]

var _material: ShaderMaterial
var _trunk_material: StandardMaterial3D
var _trunk_mesh: CylinderMesh
var _mesh_cache: Dictionary = {}
var _chunks: Dictionary = {}
var _leaf_emitters: Array[CPUParticles3D] = []
var _lod_instance_counts := [0, 0, 0]
var _tree_count := 0
var _season_manager: Node


func configure_tree_positions(positions: Array[Vector3], seed_value: int = 2026) -> void:
    clear_foliage()
    _tree_count = positions.size()
    if positions.is_empty():
        return

    _material = ShaderMaterial.new()
    _material.shader = load("res://shaders/stylized_foliage.gdshader") as Shader
    _material.set_shader_parameter("leaf_atlas", _create_soft_leaf_atlas())
    _material.set_shader_parameter("seasonal_tint", Color(1.0, 1.0, 1.0, 1.0))
    _material.set_shader_parameter("leaf_density", 1.0)
    _material.set_shader_parameter("snow_amount", 0.0)
    _material.set_shader_parameter("wind_strength", 0.10)
    _material.set_shader_parameter("wind_speed", 0.85)
    _material.set_shader_parameter("fake_sss_strength", 0.28)

    # One tapered low-poly trunk batch per chunk grounds canopy cards without
    # introducing one scene node per tree.
    _trunk_material = StandardMaterial3D.new()
    _trunk_material.vertex_color_use_as_albedo = true
    _trunk_material.albedo_color = Color("#806044")
    _trunk_material.roughness = 1.0
    _trunk_mesh = CylinderMesh.new()
    _trunk_mesh.top_radius = 0.095
    _trunk_mesh.bottom_radius = 0.235
    _trunk_mesh.height = 2.6
    _trunk_mesh.radial_segments = 7
    _trunk_mesh.rings = 2

    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var buckets: Dictionary = {}

    for index in range(positions.size()):
        var world_position := positions[index]
        var chunk_key := Vector2i(
            floori(world_position.x / CHUNK_SIZE),
            floori(world_position.z / CHUNK_SIZE)
        )
        if not buckets.has(chunk_key):
            buckets[chunk_key] = {}
        var species_id := index % 4
        var species_bucket: Dictionary = buckets[chunk_key]
        if not species_bucket.has(species_id):
            species_bucket[species_id] = []
        species_bucket[species_id].append({
            "position": world_position,
            "seed": rng.randf()
        })

    for chunk_key in buckets.keys():
        _build_chunk(chunk_key, buckets[chunk_key])

    _season_manager = SeasonManagerScript.new()
    _season_manager.name = "SeasonManager"
    add_child(_season_manager)
    _season_manager.call("configure", _material, _leaf_emitters)


func _build_chunk(chunk_key: Vector2i, species_buckets: Dictionary) -> void:
    var chunk_root := Node3D.new()
    chunk_root.name = "FoliageChunk_%d_%d" % [chunk_key.x, chunk_key.y]
    chunk_root.position = Vector3(chunk_key.x * CHUNK_SIZE, 0.0, chunk_key.y * CHUNK_SIZE)
    add_child(chunk_root)

    for species_value in species_buckets.keys():
        var species_id := int(species_value)
        var entries: Array = species_buckets[species_value]
        for lod in range(3):
            var mesh_key := "%d_%d" % [species_id, lod]
            if not _mesh_cache.has(mesh_key):
                _mesh_cache[mesh_key] = _create_canopy_mesh(
                    species_id,
                    LOD_CARDS[lod],
                    LOD_SEGMENTS_X[lod],
                    LOD_SEGMENTS_Y[lod]
                )

            var multimesh := MultiMesh.new()
            multimesh.transform_format = MultiMesh.TRANSFORM_3D
            multimesh.use_custom_data = true
            multimesh.mesh = _mesh_cache[mesh_key]
            multimesh.instance_count = entries.size()

            for instance_index in range(entries.size()):
                var entry: Dictionary = entries[instance_index]
                var world_position: Vector3 = entry["position"]
                var local_position := world_position - chunk_root.position
                var stable_random: float = float(entry["seed"])
                var scale_value := 2.05 + fposmod(stable_random * 17.0, 0.72)
                var yaw := stable_random * TAU
                var width_factor := 1.0
                var height_factor := 1.0
                match species_id:
                    1: # Tall, narrow broadleaf.
                        width_factor = 0.82
                        height_factor = 1.20
                    2: # Soft, layered conifer.
                        width_factor = 0.96
                        height_factor = 1.12
                    3: # Fan-palm fronds; beach palms remain separate coastal landmarks.
                        width_factor = 1.18
                        height_factor = 0.88

                var basis := Basis(Vector3.UP, yaw).scaled(
                    Vector3(
                        scale_value * width_factor,
                        scale_value * height_factor,
                        scale_value * width_factor
                    )
                )
                var crown_height_factor := 3.55
                if species_id == 3:
                    # Palm fronds radiate from a lower crown above the tall trunk.
                    crown_height_factor = 2.85
                var crown_position := local_position + Vector3(0.0, crown_height_factor * scale_value, 0.0)
                multimesh.set_instance_transform(
                    instance_index,
                    Transform3D(basis, crown_position)
                )
                multimesh.set_instance_custom_data(
                    instance_index,
                    Color(
                        fposmod(stable_random * 7.31, 1.0),
                        0.88 + fposmod(stable_random * 3.17, 0.12),
                        fposmod(stable_random * 11.7, 1.0),
                        0.90 + fposmod(stable_random * 2.7, 0.10)
                    )
                )

            # A fixed conservative AABB keeps each 64 m batch independently culled.
            multimesh.custom_aabb = AABB(
                Vector3(-6.0, -3.0, -6.0),
                Vector3(CHUNK_SIZE + 12.0, 22.0, CHUNK_SIZE + 12.0)
            )

            var renderer := MultiMeshInstance3D.new()
            renderer.name = "TreeCanopies_Species%d_LOD%d" % [species_id, lod]
            renderer.multimesh = multimesh
            renderer.material_override = _material
            renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            renderer.visibility_range_begin = LOD_BEGIN[lod]
            renderer.visibility_range_end = LOD_END[lod]
            renderer.visibility_range_begin_margin = 7.0
            renderer.visibility_range_end_margin = 8.0
            renderer.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
            chunk_root.add_child(renderer)
            _lod_instance_counts[lod] += entries.size()

    _build_chunk_trunks(chunk_root, species_buckets)
    var leaf_emitter := _create_leaf_fall_emitter()
    leaf_emitter.name = "SeasonalLeafFall"
    chunk_root.add_child(leaf_emitter)
    _leaf_emitters.append(leaf_emitter)
    _chunks[chunk_key] = chunk_root


func _build_chunk_trunks(chunk_root: Node3D, species_buckets: Dictionary) -> void:
    var entries: Array[Dictionary] = []
    for species_value in species_buckets.keys():
        var species_id := int(species_value)
        for entry_value in species_buckets[species_value]:
            entries.append({
                "species": species_id,
                "position": entry_value["position"],
                "seed": float(entry_value["seed"])
            })
    if entries.is_empty():
        return

    var trunks := MultiMesh.new()
    trunks.transform_format = MultiMesh.TRANSFORM_3D
    trunks.use_colors = true
    trunks.mesh = _trunk_mesh
    trunks.instance_count = entries.size()
    var bark_palette := [
        Color("#806044"), Color("#70513C"),
        Color("#6B5846"), Color("#9A7650")
    ]
    for index in range(entries.size()):
        var entry: Dictionary = entries[index]
        var species_id := int(entry["species"])
        var world_position: Vector3 = entry["position"]
        var local_position := world_position - chunk_root.position
        var stable_random := float(entry["seed"])
        var scale_value := 2.05 + fposmod(stable_random * 17.0, 0.72)
        var height_factor := 1.0
        var width_factor := 1.0
        match species_id:
            1:
                height_factor = 1.20
                width_factor = 0.82
            2:
                height_factor = 1.12
                width_factor = 0.96
            3:
                height_factor = 0.88
                width_factor = 1.18
        var height_scale := scale_value * height_factor
        var width_scale := scale_value * width_factor
        var basis := Basis.IDENTITY.scaled(Vector3(width_scale, height_scale, width_scale))
        var trunk_height := _trunk_mesh.height * height_scale
        trunks.set_instance_transform(
            index,
            Transform3D(basis, local_position + Vector3(0.0, trunk_height * 0.5, 0.0))
        )
        trunks.set_instance_color(index, bark_palette[species_id] * (0.94 + stable_random * 0.10))

    trunks.custom_aabb = AABB(
        Vector3(-6.0, -1.0, -6.0),
        Vector3(CHUNK_SIZE + 12.0, 18.0, CHUNK_SIZE + 12.0)
    )
    var trunk_renderer := MultiMeshInstance3D.new()
    trunk_renderer.name = "TreeTrunks"
    trunk_renderer.multimesh = trunks
    trunk_renderer.material_override = _trunk_material
    trunk_renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    trunk_renderer.visibility_range_end = LOD_END[2]
    trunk_renderer.visibility_range_end_margin = 8.0
    trunk_renderer.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    chunk_root.add_child(trunk_renderer)


func _create_canopy_mesh(species_id: int, card_count: int, segments_x: int, segments_y: int) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)

    for card_index in range(card_count):
        var angle := TAU * float(card_index) / float(card_count)
        var right := Vector3(cos(angle), 0.0, -sin(angle))
        var outward := Vector3(sin(angle), 0.0, cos(angle))

        for y_step in range(segments_y):
            var v0 := float(y_step) / float(segments_y)
            var v1 := float(y_step + 1) / float(segments_y)
            for x_step in range(segments_x):
                var u0 := -1.0 + 2.0 * float(x_step) / float(segments_x)
                var u1 := -1.0 + 2.0 * float(x_step + 1) / float(segments_x)

                _add_card_triangle(surface, species_id, right, outward, u0, v0, u0, v1, u1, v0)
                _add_card_triangle(surface, species_id, right, outward, u1, v0, u0, v1, u1, v1)

    return surface.commit()


func _add_card_triangle(
    surface: SurfaceTool,
    species_id: int,
    right: Vector3,
    outward: Vector3,
    u_a: float, v_a: float,
    u_b: float, v_b: float,
    u_c: float, v_c: float
) -> void:
    _add_card_vertex(surface, species_id, right, outward, u_a, v_a)
    _add_card_vertex(surface, species_id, right, outward, u_b, v_b)
    _add_card_vertex(surface, species_id, right, outward, u_c, v_c)


func _add_card_vertex(
    surface: SurfaceTool,
    species_id: int,
    right: Vector3,
    outward: Vector3,
    u: float,
    v: float
) -> void:
    var width := 1.28
    var height := 2.20
    var center_y := 0.04
    match species_id:
        1:
            width = 1.10
            height = 2.65
            center_y = 0.12
        2:
            width = 1.30
            height = 2.42
            center_y = 0.02
        3:
            width = 1.62
            height = 1.85
            center_y = -0.04

    var profile := 1.0
    if species_id == 2:
        profile = lerpf(1.0, 0.24, v)
    else:
        var normalized_height := (v - 0.5) / 0.62
        profile = sqrt(maxf(0.10, 1.0 - normalized_height * normalized_height))
        if species_id == 1:
            profile = pow(profile, 0.72)
        elif species_id == 3:
            profile = 0.82 + profile * 0.18

    var lateral := u * width * profile
    var depth := sin((u + 1.0) * PI * 0.5) * 0.22 + sin(v * PI) * 0.08
    var point: Vector3
    var bent_normal: Vector3
    if species_id == 3:
        # Fan-palm-like radial fronds: each crossed card grows outward and
        # droops from the crown, rather than forming another spherical blob.
        var radial_distance := v * 1.78
        var frond_width := sin(v * PI) * 0.68
        var frond_y := 0.92 - v * 1.28 + sin(v * PI) * 0.12
        point = outward * radial_distance + right * (u * frond_width) + Vector3(0.0, frond_y, 0.0)
        bent_normal = (outward * 0.82 + right * (u * 0.28) + Vector3.UP * 0.18).normalized()
    else:
        point = right * lateral + outward * depth + Vector3(0.0, center_y - height * 0.5 + v * height, 0.0)
        bent_normal = (outward + right * (u * 0.34) + Vector3.UP * ((v - 0.5) * 0.22)).normalized()
    var uv := Vector2((u + 1.0) * 0.5, v)
    var wind_weight := 0.20 + v * 0.80

    surface.set_normal(bent_normal)
    surface.set_uv(uv)
    surface.set_uv2(Vector2(wind_weight, 0.0))
    surface.add_vertex(point)


func _create_soft_leaf_atlas() -> Texture2D:
    # A locally generated, mipmapped leaf-cluster mask with watercolor-like
    # colour breakup and a feathered silhouette edge (no runtime network IO).
    const SIZE := 128
    var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
    for y in range(SIZE):
        for x in range(SIZE):
            var uv := Vector2(float(x) / float(SIZE - 1), float(y) / float(SIZE - 1))
            var alpha := 0.0
            alpha = maxf(alpha, _soft_ellipse(uv, Vector2(0.50, 0.52), Vector2(0.34, 0.43)))
            alpha = maxf(alpha, _soft_ellipse(uv, Vector2(0.29, 0.58), Vector2(0.22, 0.27)))
            alpha = maxf(alpha, _soft_ellipse(uv, Vector2(0.71, 0.57), Vector2(0.22, 0.29)))
            alpha = maxf(alpha, _soft_ellipse(uv, Vector2(0.43, 0.27), Vector2(0.24, 0.24)))
            alpha = maxf(alpha, _soft_ellipse(uv, Vector2(0.66, 0.29), Vector2(0.19, 0.22)))

            var pigment := sin(uv.x * 18.0 + uv.y * 11.0) * cos(uv.y * 15.0 - uv.x * 7.0)
            var fine := sin(uv.x * 91.0 + uv.y * 63.0) * 0.5 + cos(uv.y * 77.0 - uv.x * 83.0) * 0.5
            var light := clampf(0.86 + pigment * 0.075 + fine * 0.035, 0.68, 1.0)
            var leaf_color := Color(0.34 * light, 0.58 * light, 0.23 * light, alpha)
            image.set_pixel(x, y, leaf_color)
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)


func _soft_ellipse(uv: Vector2, center: Vector2, radii: Vector2) -> float:
    var delta := uv - center
    var distance := sqrt(
        pow(delta.x / radii.x, 2.0) +
        pow(delta.y / radii.y, 2.0)
    )
    var t := clampf((distance - 0.78) / 0.34, 0.0, 1.0)
    var smooth := t * t * (3.0 - 2.0 * t)
    return 1.0 - smooth


func _create_leaf_fall_emitter() -> CPUParticles3D:
    var particles := CPUParticles3D.new()
    particles.amount = 10
    particles.lifetime = 4.5
    particles.emitting = false
    particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    particles.emission_box_extents = Vector3(25.0, 2.0, 25.0)
    particles.direction = Vector3(0.0, -1.0, 0.0)
    particles.spread = 32.0
    particles.gravity = Vector3(0.0, -1.25, 0.0)
    particles.initial_velocity_min = 0.18
    particles.initial_velocity_max = 0.72
    particles.angular_velocity_min = -1.2
    particles.angular_velocity_max = 1.2
    particles.scale_amount_min = 0.55
    particles.scale_amount_max = 1.0
    var leaf_quad := QuadMesh.new()
    leaf_quad.size = Vector2(0.12, 0.075)
    var leaf_material := StandardMaterial3D.new()
    leaf_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    leaf_material.albedo_color = Color(0.83, 0.39, 0.12, 1.0)
    leaf_material.roughness = 1.0
    leaf_quad.material = leaf_material
    particles.mesh = leaf_quad
    return particles


func clear_foliage() -> void:
    for child in get_children():
        child.queue_free()
    _chunks.clear()
    _mesh_cache.clear()
    _leaf_emitters.clear()
    _lod_instance_counts = [0, 0, 0]
    _tree_count = 0
    _season_manager = null
    _material = null
    _trunk_material = null
    _trunk_mesh = null


func get_chunk_count() -> int:
    return _chunks.size()


func get_tree_count() -> int:
    return _tree_count


func get_lod_instance_count(lod: int) -> int:
    if lod < 0 or lod >= _lod_instance_counts.size():
        return 0
    return int(_lod_instance_counts[lod])


func set_season(season: int, duration: float = 8.0) -> void:
    if is_instance_valid(_season_manager):
        _season_manager.call("change_season", season, duration)


func set_wind(strength: float, speed: float, direction: Vector3) -> void:
    if _material == null:
        return
    _material.set_shader_parameter("wind_strength", clampf(strength, 0.0, 1.0))
    _material.set_shader_parameter("wind_speed", maxf(speed, 0.0))
    if direction.length_squared() > 0.001:
        _material.set_shader_parameter("wind_direction", direction.normalized())
