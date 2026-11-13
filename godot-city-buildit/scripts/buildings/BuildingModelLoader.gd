extends RefCounted
class_name BuildingModelLoader

const MODEL_ROOT := "res://assets/models/"

static func is_supported_model_path(model_path: String) -> bool:
	if not model_path.begins_with(MODEL_ROOT):
		return false
	if model_path.contains("..") or model_path.contains("\\"):
		return false
	var extension := model_path.get_extension().to_lower()
	return extension == "glb" or extension == "gltf"

static func load_model_scene(model_path: String) -> PackedScene:
	if not is_supported_model_path(model_path):
		return null
	if not ResourceLoader.exists(model_path):
		return null
	var resource := ResourceLoader.load(model_path)
	return resource as PackedScene

static func attach_model(parent: Node3D, model_path: String, model_scale: Vector3 = Vector3.ONE) -> Node3D:
	var packed_scene := load_model_scene(model_path)
	if packed_scene == null:
		return null
	var instance: Node = packed_scene.instantiate()
	var model_root := instance as Node3D
	if model_root == null:
		instance.free()
		return null
	model_root.scale = model_scale
	parent.add_child(model_root)
	return model_root
