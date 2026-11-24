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
    var species_seen: Dictionary = {}
    for chunk in system.get_children():
        if not chunk.name.begins_with("FoliageChunk_"):
            continue
        var near_lod_count := 0
        var medium_lod_count := 0
        var far_lod_count := 0
        for child in chunk.get_children():
            if not child is MultiMeshInstance3D or not child.name.begins_with("TreeCanopies_"):
                continue
            if child.name.ends_with("_LOD0"):
                near_lod_count += 1
                var is_shadow_budget_species := child.name.begins_with("TreeCanopies_Species0_") or child.name.begins_with("TreeCanopies_Species6_")
                var should_cast_shadow: bool = child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
                if should_cast_shadow != is_shadow_budget_species:
                    _fail("Only the two authored near-canopy shadow batches may cast real shadows.")
                    return
            elif child.name.ends_with("_LOD1"):
                medium_lod_count += 1
                if child.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
                    _fail("Medium canopy LOD must not add mobile shadow-map cost.")
                    return
            elif child.name.ends_with("_LOD2"):
                far_lod_count += 1
                if child.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
                    _fail("Far canopy LOD must not add mobile shadow-map cost.")
                    return
        if near_lod_count == 0 or medium_lod_count == 0 or far_lod_count == 0:
            _fail("Every populated foliage chunk must expose all three canopy LOD tiers.")
            return
        for species_id in range(8):
            var species_canopy := chunk.get_node_or_null("TreeCanopies_Species%d_LOD0" % species_id) as MultiMeshInstance3D
            if species_canopy != null and species_canopy.multimesh != null and species_canopy.multimesh.instance_count > 0:
                species_seen[species_id] = true
                if species_id != 3:
                    var crown_mesh := species_canopy.multimesh.mesh as ArrayMesh
                    var crown_bounds := crown_mesh.get_aabb() if crown_mesh != null else AABB()
                    if crown_mesh == null or crown_bounds.size.x < 1.5 or crown_bounds.size.z < 1.5 or crown_bounds.size.y < 1.2:
                        _fail("Broadleaf and conifer crowns must use real three-dimensional canopy geometry.")
                        return
        var shadow_trunks := chunk.get_node_or_null("TreeTrunks") as MultiMeshInstance3D
        if shadow_trunks == null or shadow_trunks.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
            _fail("Batched trunks must stay shadow-free; the near canopy is the only tree shadow caster.")
            return
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
    var palm_alignment_checked := false
    for chunk in system.get_children():
        if not chunk.name.begins_with("FoliageChunk_"):
            continue
        var palm_lod := chunk.get_node_or_null("TreeCanopies_Species3_LOD0") as MultiMeshInstance3D
        if palm_lod != null and palm_lod.multimesh != null and palm_lod.multimesh.instance_count > 0:
            var palm_crown_y := palm_lod.multimesh.get_instance_transform(0).origin.y
            if palm_crown_y > 3.5:
                _fail("Palm frond crown is too high to connect to its tall trunk.")
                return
            palm_alignment_checked = true
    if not palm_alignment_checked:
        _fail("Foliage smoke did not find a palm crown for trunk alignment.")
        return

    if species_seen.size() != 8:
        _fail("The starter foliage set must expose all eight authored tree silhouettes.")
        return

    var trunk_instances_checked := 0
    for chunk in system.get_children():
        if not chunk.name.begins_with("FoliageChunk_"):
            continue
        var trunk_renderer := chunk.get_node_or_null("TreeTrunks") as MultiMeshInstance3D
        if trunk_renderer == null or trunk_renderer.multimesh == null:
            _fail("Every foliage chunk must contain a batched trunk renderer.")
            return
        var expected_chunk_trees := 0
        for species_id in range(8):
            var canopy := chunk.get_node_or_null("TreeCanopies_Species%d_LOD0" % species_id) as MultiMeshInstance3D
            if canopy != null and canopy.multimesh != null:
                expected_chunk_trees += canopy.multimesh.instance_count
        if trunk_renderer.multimesh.instance_count != expected_chunk_trees:
            _fail("Trunk batch count must equal the number of canopy trees in its chunk.")
            return
        trunk_instances_checked += trunk_renderer.multimesh.instance_count
    if trunk_instances_checked != sample_positions.size():
        _fail("Every supplied tree position must have one batched trunk.")

    var broadleaf_crown_height := float(system.call("_get_tree_crown_height", 0, 0.25))
    var palm_crown_height := float(system.call("_get_tree_crown_height", 3, 0.25))
    if broadleaf_crown_height <= 6.0 or palm_crown_height <= 2.0 or palm_crown_height >= broadleaf_crown_height:
        _fail("Shared species crown-height calculation must preserve tall trees and lower palm crowns.")

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
    print("[FoliageSystemSmoke] PASS trees=%d species=%d chunks=%d lod_instances=%d/%d/%d winter_density=%.2f" % [
        system.get_tree_count(),
        species_seen.size(),
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
