extends RefCounted
## Single source of truth for local transparent PNG UI and catalog icons.
const ROOT := "res://assets/icons/"
const FALLBACK := "res://assets/icons/ui/placeholder.png"

const RAW_IDS := ["metal", "wood", "plastic", "seeds", "minerals", "chemicals", "textiles", "sugar_spices", "glass", "animal_feed", "electrical"]
const CRAFTED_IDS := ["nails", "planks", "bricks", "cement", "glue", "paint", "hammer", "measuring_tape", "shovel", "chair", "table", "vegetables"]
const RESIDENTIAL_IDS := ["residential_1", "residential_2", "residential_villa", "residential_apartment", "residential_farm"]
const COMMERCIAL_IDS := ["building_supplies", "shop_chain", "restaurant_traditional", "fast_food", "art_supplies", "hardware_store", "farmers_market", "furniture_store"]
const INDUSTRIAL_IDS := ["factory_small", "factory_basic", "factory_mass", "factory_hightech", "factory_nano", "industrial_1", "industrial_2", "industrial_3"]
const SERVICE_IDS := ["power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear", "water_tower", "water_pump", "sewage_small", "sewage_basic", "sewage_deluxe", "waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling", "fire_station_small", "fire_station", "fire_station_deluxe", "police_station", "police_small", "police_basic", "police_precinct", "clinic_small", "clinic", "hospital", "town_hall"]
const SPECIALIZATION_IDS := ["park_small"]
const SERVICE_GROUP_IDS := ["power", "water", "sewage", "waste", "fire", "police", "health", "government"]
const SPECIALIZATION_GROUP_IDS := ["parks", "education", "transportation", "entertainment", "gambling", "landmarks", "worship"]

static func path(category: String, id: String) -> String:
	return "%s%s/%s.png" % [ROOT, category, id]

static func get_tex(category: String, id: String) -> Texture2D:
	var icon_path := path(category, id)
	if ResourceLoader.exists(icon_path):
		var texture := load(icon_path) as Texture2D
		if texture != null:
			return texture
	if ResourceLoader.exists(FALLBACK):
		return load(FALLBACK) as Texture2D
	push_error("Missing icon and fallback: %s" % icon_path)
	return null

static func category_for_id(id: String) -> String:
	if RAW_IDS.has(id):
		return "raw"
	if CRAFTED_IDS.has(id):
		return "crafted"
	if RESIDENTIAL_IDS.has(id):
		return "residential"
	if COMMERCIAL_IDS.has(id):
		return "commercial"
	if INDUSTRIAL_IDS.has(id):
		return "industrial"
	if SERVICE_IDS.has(id) or SERVICE_GROUP_IDS.has(id):
		return "services"
	if SPECIALIZATION_IDS.has(id) or SPECIALIZATION_GROUP_IDS.has(id):
		return "specializations"
	if id in ["road", "road_build", "road_upgrade", "road_bulldoze"]:
		return "roads"
	return "ui"

static func resolved_id(id: String) -> String:
	if SERVICE_GROUP_IDS.has(id):
		return "group_" + id
	if SPECIALIZATION_GROUP_IDS.has(id):
		return "group_" + id
	return id

static func get_icon_tex(id: String) -> Texture2D:
	return get_tex(category_for_id(id), resolved_id(id))

static func make_icon(id: String, display_size: Vector2 = Vector2(64, 64)) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = get_icon_tex(id)
	icon.custom_minimum_size = display_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE
	return icon

static func make_item_icon(category: String, id: String, display_size: Vector2 = Vector2(32, 32)) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = get_tex(category, id)
	icon.custom_minimum_size = display_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
