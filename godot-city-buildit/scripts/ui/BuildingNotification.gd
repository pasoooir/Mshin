extends RefCounted
## Notification state is derived from the authoritative building/production
## model. This object carries presentation metadata only.
enum Type {
	PRODUCTION_READY = 100,
	STORAGE_FULL = 90,
	UPGRADE_READY = 80,
	NEEDS_MATERIALS = 40,
	IDLE = 10
}

var building_id: String = ""
var type: int = Type.IDLE
var item_id: String = ""
var quantity: int = 0
var missing_text: String = ""
var priority: int = 0
var detail: String = ""

func _init(p_building_id: String = "", p_type: int = Type.IDLE, p_item_id: String = "", p_quantity: int = 0, p_missing_text: String = "") -> void:
	building_id = p_building_id
	type = p_type
	item_id = p_item_id
	quantity = p_quantity
	missing_text = p_missing_text
