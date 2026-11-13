extends RefCounted
## Single source of truth for local transparent PNG UI and catalog icons.
const ROOT := "res://assets/icons/"
const FALLBACK := "res://assets/icons/ui/placeholder.png"

const RAW_IDS := ["metal", "wood", "plastic", "seeds", "minerals", "chemicals", "textiles", "sugar_spices", "glass", "animal_feed", "electrical"]
const CRAFTED_IDS := ["nails", "planks", "bricks", "cement", "glue", "paint", "hammer", "measuring_tape", "shovel", "cooking_utensils", "ladder", "drill", "chair", "table", "home_textiles", "cupboard", "couch", "vegetables", "flour_bag", "cream", "corn", "cheese", "beef", "ice_cream_sandwich", "pizza", "burger", "cheese_fries", "lemonade_bottle", "popcorn", "bread_roll", "bbq_grill", "microwave_oven", "fruit_berries", "tree_sapling", "donuts", "green_smoothie", "cherry_cheesecake", "frozen_yogurt", "coffee", "refrigerator", "lighting_system", "tv", "grass", "garden_furniture", "lawn_mower", "fire_pit", "garden_gnome", "cap", "shoes", "watch", "business_suit", "backpack", "tennis_racket", "sports_drink", "soccer_shoes", "protein_bar", "ping_pong_table", "block_letters", "kite", "teddy_bear", "game_console", "forged_iron", "carved_wood", "cut_stone", "tapestries", "stained_glass", "wool_shirt", "picnic_basket", "apple_jam", "tiramisu", "churros", "profiterole", "mochi", "pavlova"]
const RESIDENTIAL_IDS := ["residential_1", "residential_2", "residential_villa", "residential_apartment", "residential_farm"]
const COMMERCIAL_IDS := ["building_supplies", "shop_chain", "restaurant_traditional", "fast_food", "art_supplies", "hardware_store", "farmers_market", "furniture_store", "gardening_supplies", "donut_shop", "home_appliances", "fashion_store", "sports_shop", "toy_store", "restoration_office", "farmers_store", "dessert_shop"]
const INDUSTRIAL_IDS := ["factory_small", "factory_basic", "factory_mass", "factory_hightech", "factory_nano", "industrial_1", "industrial_2", "industrial_3"]
const SERVICE_IDS := ["power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear", "water_tower", "water_pump", "sewage_small", "sewage_basic", "sewage_deluxe", "waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling", "fire_station_small", "fire_station", "fire_station_deluxe", "police_station", "police_small", "police_basic", "police_precinct", "clinic_small", "clinic", "hospital", "town_hall", "epic_department", "trade_depot", "global_trade_hq", "cargo_port"]
const SPECIALIZATION_IDS := ["park_small"]
const SERVICE_GROUP_IDS := ["power", "water", "sewage", "waste", "fire", "police", "health", "government", "trade"]
const SPECIALIZATION_GROUP_IDS := ["parks", "education", "transportation", "entertainment", "gambling", "landmarks", "worship"]
const UI_IDS := ["placeholder", "storage", "trade", "save", "cancel", "close", "collect", "lock", "back", "confirm", "bulldoze", "build_menu", "settings", "info", "plus", "city_needs", "money", "population", "happiness", "level", "warning", "check", "arrow_left", "arrow_right", "services", "commercial", "industrial", "road", "residential", "parks", "hard_hat", "simoleons", "golden_key", "fire", "power", "water", "park", "police", "health", "sewage", "waste", "government", "education", "transportation", "entertainment", "gambling", "beach", "mountain", "landmark", "global_trade", "epic", "regions", "fallback"]
const ROAD_IDS := ["road", "road_build", "road_upgrade", "road_bulldoze"]
const STATUS_IDS := ["smoke", "no_power", "no_water", "no_fire_coverage", "storage_full", "ready_collect", "upgrading", "abandoned"]
static var _texture_cache: Dictionary = {}

static func path(category: String, id: String) -> String:
	return "%s%s/%s.png" % [ROOT, category, id]

static func get_tex(category: String, id: String) -> Texture2D:
	var icon_path := path(category, id)
	if not ResourceLoader.exists(icon_path):
		var svg_path := "%s%s/%s.svg" % [ROOT, category, id]
		if ResourceLoader.exists(svg_path):
			icon_path = svg_path
	if _texture_cache.has(icon_path):
		return _texture_cache[icon_path] as Texture2D
	if ResourceLoader.exists(icon_path):
		var texture := load(icon_path) as Texture2D
		if texture != null:
			_texture_cache[icon_path] = texture
			return texture
	if ResourceLoader.exists(FALLBACK):
		var fallback := load(FALLBACK) as Texture2D
		_texture_cache[icon_path] = fallback
		return fallback
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

static func get_advisor_tex() -> Texture2D:
	for candidate in ["res://assets/icons/ui/advisor.png"]:
		if ResourceLoader.exists(candidate):
			var texture := load(candidate) as Texture2D
			if texture != null:
				return texture
	return get_icon_tex("hard_hat")

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

static func get_icon_keys() -> Array[String]:
	var keys: Array[String] = []
	for icon_id in UI_IDS:
		keys.append(str(icon_id))
	for icon_id in RAW_IDS + CRAFTED_IDS + RESIDENTIAL_IDS + COMMERCIAL_IDS + INDUSTRIAL_IDS + SERVICE_IDS + SPECIALIZATION_IDS:
		if not keys.has(str(icon_id)):
			keys.append(str(icon_id))
	return keys

static func validate_required_build_icons() -> bool:
	var valid := true
	for icon_id in ["road", "residential", "commercial", "industrial", "services", "parks", "bulldoze", "hard_hat"]:
		var texture := get_icon_tex(icon_id)
		if texture == null or texture.get_image() == null or texture.get_image().is_empty():
			push_error("Required PNG build icon failed to load: " + icon_id)
			valid = false
	return valid

static func validate_all_icons() -> bool:
	var valid := validate_required_build_icons()
	var catalog := {
		"ui": UI_IDS,
		"raw": RAW_IDS,
		"crafted": CRAFTED_IDS,
		"residential": RESIDENTIAL_IDS,
		"commercial": COMMERCIAL_IDS,
		"industrial": INDUSTRIAL_IDS,
		"services": SERVICE_IDS,
		"specializations": SPECIALIZATION_IDS,
		"roads": ROAD_IDS,
		"status": STATUS_IDS
	}
	for category in catalog:
		for icon_id in catalog[category]:
			var icon_path := path(str(category), str(icon_id))
			var svg_path := "%s%s/%s.svg" % [ROOT, str(category), str(icon_id)]
			if not ResourceLoader.exists(icon_path) and not ResourceLoader.exists(svg_path):
				push_error("Missing local PNG/SVG icon resource: " + icon_path)
				valid = false
	return valid
