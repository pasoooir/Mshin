extends RefCounted
class_name BuildingNotification
## Runtime notification data. Notifications are derived from authoritative
## building/production/storage state and are intentionally not saved separately.

enum Type {
	PRODUCTION_READY,
	IDLE,
	UPGRADE_READY,
	STORAGE_FULL,
	NEEDS_MATERIALS
}

const PRIORITIES := {
	Type.PRODUCTION_READY: 100,
	Type.STORAGE_FULL: 90,
	Type.UPGRADE_READY: 80,
	Type.NEEDS_MATERIALS: 60,
	Type.IDLE: 10
}

var type: int
var building_id: String
var item_id: String
var count: int
var priority: int
var detail: String

func _init(
	p_building_id: String = "",
	p_type: int = Type.IDLE,
	p_item_id: String = "",
	p_count: int = 1,
	p_detail: String = ""
) -> void:
	building_id = p_building_id
	type = p_type
	item_id = p_item_id
	count = maxi(1, p_count)
	priority = int(PRIORITIES.get(type, 0))
	detail = p_detail

static func make(
	building_id: String,
	type: int,
	item_id: String = "",
	count: int = 1,
	detail: String = ""
) -> BuildingNotification:
	return BuildingNotification.new(building_id, type, item_id, count, detail)
