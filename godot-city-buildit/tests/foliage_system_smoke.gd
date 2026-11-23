extends SceneTree

const FoliageSystemScript = preload("res://scripts/world/StylizedFoliageSystem.gd")
const SeasonManagerScript = preload("res://scripts/world/FoliageSeasonManager.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var system = FoliageSystemScript.new()
    root.add_child(system)

    var sample_positions: Array[Vector3] = [
        Vector3(2.0, 0.0, 3.0),
        Vector3(12.0, 0.0, 8.0),
        Vector3(70.0, 0.0, 4.0),
        Vector3(-72.0, 0.0, -5.0),
        Vector3(15.0, 0.0, 18.0),
        Vector3(25.0, 0.0, 26.0),
        Vector3(42.0, 0.0, -21.0),
        Vector3(88.0, 0.0, 72.0)
    ]
    system.configure_tree_positions(sample_positions, 77123)

    if system.get_tree_count() != sample_positions.size():
        _fail("Tree count does not match supplied placement points.")
        return
    if system.get_chunk_count() < 3:
        _fail("Foliage must be spatially partitioned into independent 64 m chunks.")
        return
    var canopy_alignment_checked := false
    for chunk in system.get_children():
        if not chunk.name.begins_with("FoliageChunk_"):
            continue
        var canopy_lod := chunk.get_node_or_null("TreeCanopies_Species0_LOD0") as MultiMeshInstance3D
        if canopy_lod != null and canopy_lod.multimesh != null and canopy_lod.multimesh.instance_count > 0:
            var canopy_y := canopy_lod.multimesh.get_instance_transform(0).origin.y
            if canopy_y > 8.5:
                _fail("Broadleaf canopy crown is too high above its trunk attachment.")
                return
            canopy_alignment_checked = true
    if not canopy_alignment_checked:
        _fail("Foliage smoke did not find a broadleaf canopy for trunk alignment.")
        return

    for lod in range(3):
        if system.get_lod_instance_count(lod) != sample_positions.size():
            _fail("Every tree must have exactly one instance in each LOD tier.")
            return

    var winter_density := float(SeasonManagerScript.new().call("_season_density", 3))
    if winter_density < 0.48:
        _fail("Winter foliage density is too low to survive the shader alpha-scissor threshold.")
        return

    var shader_source := FileAccess.get_file_as_string("res://shaders/stylized_foliage.gdshader")
    for required in [
        "ALPHA_SCISSOR_THRESHOLD = 0.32",
        "INSTANCE_CUSTOM.b",
        "fake_sss_strength",
        "snow_amount",
        "wind_strength"
    ]:
        if not shader_source.contains(required):
            _fail("Foliage shader is missing required feature: " + required)
            return

    var season_script_source := FileAccess.get_file_as_string("res://scripts/world/FoliageSeasonManager.gd")
    for required in [
        "enum Season",
        "Season.SPRING",
        "Season.SUMMER",
        "Season.AUTUMN",
        "Season.WINTER",
        "change_season",
        "_set_leaf_fall_ratio"
    ]:
        if not season_script_source.contains(required):
            _fail("Season manager is missing required feature: " + required)
            return

    system.set_season(2, 0.05)
    await create_timer(0.12).timeout
    var season_manager = system.get_node_or_null("SeasonManager")
    if season_manager == null or int(season_manager.get("current_season")) != 2:
        _fail("Autumn season transition did not reach its requested state.")
        return
    print("[FoliageSystemSmoke] PASS trees=%d chunks=%d lod_instances=%d/%d/%d winter_density=%.2f" % [
        system.get_tree_count(),
        system.get_chunk_count(),
        system.get_lod_instance_count(0),
        system.get_lod_instance_count(1),
        system.get_lod_instance_count(2),
        winter_density
    ])
    system.queue_free()
    quit(0)


func _fail(message: String) -> void:
    push_error("[FoliageSystemSmoke] " + message)
    quit(1)
