extends Node

const WorldPresentationScript = preload("res://scripts/world/WorldPresentation.gd")


func _ready() -> void:
	var presentation := WorldPresentationScript.new()
	var canopy: ArrayMesh = presentation._create_clustered_canopy_mesh()
	if canopy == null or canopy.get_surface_count() != 1:
		push_error("[VisualPresentationSmoke] Canopy must be a single mesh surface")
		get_tree().quit(1)
		return

	var bounds := canopy.get_aabb()
	if bounds.size.x < 2.5 or bounds.size.y < 1.8 or bounds.size.z < 2.5:
		push_error("[VisualPresentationSmoke] Canopy silhouette is unexpectedly small: %s" % bounds.size)
		get_tree().quit(1)
		return

	var arrays := canopy.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.size() < 100 or normals.size() != vertices.size():
		push_error("[VisualPresentationSmoke] Canopy geometry/normals are incomplete")
		get_tree().quit(1)
		return

	var positions: Array[Vector3] = [Vector3.ZERO, Vector3(5.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)]
	var tree_batch: MultiMeshInstance3D = presentation._create_tree_multimesh("TreeCanopies", canopy, positions, 2.55)
	if tree_batch.multimesh == null or tree_batch.multimesh.instance_count != positions.size():
		push_error("[VisualPresentationSmoke] Tree crowns must remain batched in a MultiMesh")
		get_tree().quit(1)
		return
	# Attach the MultiMeshInstance3D before reading instance transforms. In headless
	# Godot, the RenderingServer-backed MultiMesh state is not reliably observable
	# until the instance enters the scene tree and one frame has been processed.
	add_child(tree_batch)
	await get_tree().process_frame
	var first_transform := tree_batch.multimesh.get_instance_transform(0)
	var second_transform := tree_batch.multimesh.get_instance_transform(1)
	if first_transform.is_equal_approx(second_transform):
		push_error("[VisualPresentationSmoke] Tree instances must have deterministic visual variation; first=%s second=%s" % [first_transform, second_transform])
		tree_batch.queue_free()
		presentation.free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	print("[VisualPresentationSmoke] PASS: clustered canopy geometry, normals, scale and MultiMesh variation")
	tree_batch.queue_free()
	presentation.free()
	await get_tree().process_frame
	get_tree().quit(0)
