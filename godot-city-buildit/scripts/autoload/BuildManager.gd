extends Node

signal building_placed(building_data: Dictionary)
signal building_removed(building_id: String)
signal construction_started(building_id: String)
signal construction_finished(building_id: String)
signal placement_mode_changed(active: bool)

const GRID_SIZE: float = 2.0
const WORLD_HALF_CELLS: int = 40
const BuildingScene = preload("res://scenes/buildings/Building.tscn")
const BUILDING_MODEL_REGISTRY := {
	# Each entry is keyed by an exact gameplay type ID. A category-wide model
	# silently made unrelated shops/factories look like the same building.
	"residential_1": "res://assets/models/residential/villa_house.gltf",
	"residential_villa": "res://assets/models/residential/villa_house.gltf",
	"residential_2": "res://assets/models/residential/apartment_tower.gltf",
	"residential_apartment": "res://assets/models/residential/apartment_tower.gltf",
	"la_glass_tower": "res://assets/models/residential/la_glass_tower.tscn",
	"la_dome_tower": "res://assets/models/residential/la_dome_tower.tscn",
	"la_modern_apartment": "res://assets/models/residential/la_modern_apartment.tscn",
	"la_roof_garden_villa": "res://assets/models/residential/la_roof_garden_villa.tscn",
	"la_office_tower": "res://assets/models/commercial/la_office_tower.tscn",
	"la_commercial_arcade": "res://assets/models/commercial/la_commercial_arcade.tscn",
	"shop_chain": "res://assets/models/commercial/neighborhood_shop.gltf",
	"restaurant_traditional": "res://assets/models/commercial/restaurant_traditional.tscn",
	"fast_food": "res://assets/models/commercial/fast_food.tscn",
	"hardware_store": "res://assets/models/commercial/hardware_store.tscn",
	"farmers_market": "res://assets/models/commercial/farmers_market.tscn",
	"furniture_store": "res://assets/models/commercial/furniture_store.tscn",
	"factory_small": "res://assets/models/industrial/small_factory.gltf",
	"industrial_1": "res://assets/models/industrial/small_factory.gltf"
}

var buildings: Dictionary = {}
# Every occupied grid cell points directly to its building for O(1) interaction and placement checks.
var building_cells: Dictionary = {}
var selected_building_type: String = ""
var is_placing: bool = false
var placement_rotation_quarters: int = 0
var factory_count: int = 0

# Mshin construction BOM profiles. These are explicit game-design defaults,
# not claimed SimCity BuildIt recipes. A per-building construction_bom override
# takes precedence. Bootstrap buildings keep the first production loop reachable.
const CONSTRUCTION_BOM_PROFILES := {
	"residential": {"nails": 1, "metal": 1},
	"commercial": {"nails": 2, "metal": 1},
	"industrial": {"nails": 2, "metal": 2},
	"service": {"nails": 1, "metal": 1},
	"park": {"nails": 1, "wood": 1}
}
const CONSTRUCTION_BOM_BOOTSTRAP_TYPES := ["residential_1", "residential_villa", "factory_small", "industrial_1", "building_supplies", "shop_chain", "power_wind", "water_tower"]

var building_types: Dictionary = {
	"residential_1": {"name":"Small House", "category":"residential", "service_demand":1, "cost":0, "size":Vector2i(2,2), "population":15, "build_time":3.0, "color":Color(0.95,0.72,0.5), "level":1},
	"residential_2": {"name":"Apartment", "category":"residential", "service_demand":2, "cost":0, "size":Vector2i(2,2), "population":28, "build_time":5.0, "color":Color(0.88,0.62,0.68), "level":3},
	# New player-facing residential choices. Legacy residential_1/_2 remain load-compatible.
	"residential_villa": {"name":"Villa House", "category":"residential", "subtype":"villa", "service_demand":1, "cost":0, "size":Vector2i(2,2), "population":15, "build_time":3.0, "color":Color(0.95,0.72,0.5), "level":1},
	"residential_apartment": {"name":"Apartment", "category":"residential", "subtype":"apartment", "service_demand":2, "cost":200, "size":Vector2i(2,2), "population":35, "build_time":5.0, "color":Color(0.88,0.62,0.68), "level":3},
	"residential_farm": {"name":"Farm", "category":"residential", "subtype":"farm", "service_demand":1, "cost":150, "size":Vector2i(2,2), "population":12, "build_time":4.0, "color":Color(0.72,0.78,0.45), "level":2},
	"la_glass_tower": {"name":"LA Glass Tower", "category":"residential", "subtype":"apartment", "service_demand":4, "cost":18000, "size":Vector2i(3,3), "population":110, "build_time":12.0, "color":Color("#75B8C7"), "level":24},
	"la_dome_tower": {"name":"Dome Crown Tower", "category":"residential", "subtype":"apartment", "service_demand":4, "cost":22000, "size":Vector2i(3,3), "population":125, "build_time":13.0, "color":Color("#78AFC0"), "level":28},
	"la_modern_apartment": {"name":"Modern Apartment", "category":"residential", "subtype":"apartment", "service_demand":3, "cost":6500, "size":Vector2i(2,2), "population":62, "build_time":8.0, "color":Color("#D8D4C9"), "level":12},
	"la_roof_garden_villa": {"name":"Roof Garden Villa", "category":"residential", "subtype":"villa", "service_demand":2, "cost":9000, "size":Vector2i(2,2), "population":42, "build_time":9.0, "color":Color("#E6E0D3"), "level":16},
	"island_cottage": {"name":"Island Cottage", "category":"residential", "subtype":"villa", "region":"sunny_isles", "service_demand":1, "cost":25000, "size":Vector2i(2,2), "population":30, "build_time":7.0, "color":Color("#55C8C5"), "level":25},
	"fjord_chalet": {"name":"Fjord Chalet", "category":"residential", "subtype":"villa", "region":"frosty_fjords", "service_demand":1, "cost":30000, "size":Vector2i(2,2), "population":32, "build_time":8.0, "color":Color("#8AAEC8"), "level":30},
	"desert_hacienda": {"name":"Desert Hacienda", "category":"residential", "subtype":"villa", "region":"cactus_canyon", "service_demand":1, "cost":35000, "size":Vector2i(2,2), "population":34, "build_time":8.0, "color":Color("#D9A45E"), "level":35},
	"valley_eco_home": {"name":"Valley Eco Home", "category":"residential", "subtype":"villa", "region":"green_valley", "service_demand":1, "cost":40000, "size":Vector2i(2,2), "population":36, "build_time":9.0, "color":Color("#6FAE70"), "level":40},
	"cliffside_villa": {"name":"Cliffside Villa", "category":"residential", "subtype":"villa", "region":"limestone_cliffs", "service_demand":1, "cost":45000, "size":Vector2i(2,2), "population":38, "build_time":9.0, "color":Color("#D4C5A2"), "level":45},
	"building_supplies": {"name":"Building Supplies", "category":"commercial", "cost":100, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.35,0.68,0.95), "level":1, "production_slots":2},
	# New commercial menu choices. shop_chain keeps the existing Nails recipe path.
	"shop_chain": {"name":"Chain Store", "category":"commercial", "subtype":"chain", "cost":100, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.35,0.68,0.95), "level":1, "production_slots":1},
	"restaurant_traditional": {"name":"Traditional Restaurant", "category":"commercial", "subtype":"restaurant", "cost":400, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.75,0.45,0.30), "level":4, "production_slots":1, "shop_id":"restaurant_traditional"},
	"fast_food": {"name":"Fast Food Restaurant", "category":"commercial", "subtype":"fast_food", "cost":25000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.95,0.55,0.20), "level":25, "production_slots":1},
	"art_supplies": {"name":"Art Supplies Store", "category":"commercial", "subtype":"art", "cost":300, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.55,0.40,0.75), "level":5, "production_slots":1, "shop_id":"art_supplies"},
	"hardware_store": {"name":"Hardware Store", "category":"commercial", "cost":2500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.3,0.55,0.85), "level":4, "production_slots":1},
	"farmers_market": {"name":"Farmer's Market", "category":"commercial", "cost":5000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.4,0.75,0.4), "level":8, "production_slots":1},
	"furniture_store": {"name":"Furniture Store", "category":"commercial", "cost":8000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.6,0.45,0.3), "level":10, "production_slots":1},
	"la_office_tower": {"name":"LA Office Tower", "category":"commercial", "subtype":"office", "cost":42000, "size":Vector2i(3,3), "population":0, "build_time":14.0, "color":Color("#5C91A5"), "level":32},
	"la_commercial_arcade": {"name":"Coastal Commercial Arcade", "category":"commercial", "subtype":"retail", "cost":12500, "size":Vector2i(2,2), "population":0, "build_time":8.0, "color":Color("#D8D1C3"), "level":18},
	"gardening_supplies": {"name":"Gardening Supplies Store", "category":"commercial", "subtype":"gardening_supplies", "cost":13000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.40,0.68,0.38), "level":14, "production_slots":1, "shop_id":"gardening_supplies"},
	"donut_shop": {"name":"Donut Shop", "category":"commercial", "subtype":"donut_shop", "cost":17000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.92,0.55,0.62), "level":18, "production_slots":1, "shop_id":"donut_shop"},
	"home_appliances": {"name":"Home Appliances Store", "category":"commercial", "subtype":"home_appliances", "cost":30000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.36,0.58,0.78), "level":29, "production_slots":1, "shop_id":"home_appliances"},
	"fashion_store": {"name":"Fashion Store", "category":"commercial", "subtype":"fashion_store", "cost":22000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.82,0.48,0.68), "level":19, "production_slots":1, "shop_id":"fashion_store"},
	"sports_shop": {"name":"Sports Shop", "category":"commercial", "subtype":"sports_shop", "cost":80000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.42,0.66,0.46), "level":35, "production_slots":1, "shop_id":"sports_shop"},
	"toy_store": {"name":"Toy Store", "category":"commercial", "subtype":"toy_store", "cost":100000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.90,0.64,0.26), "level":40, "production_slots":1, "shop_id":"toy_store"},
	"restoration_office": {"name":"Restoration Office", "category":"commercial", "subtype":"restoration_office", "cost":250000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.55,0.58,0.64), "level":45, "production_slots":1, "shop_id":"restoration_office"},
	"farmers_store": {"name":"Country Store", "category":"commercial", "subtype":"farmers_store", "cost":300000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.68,0.54,0.34), "level":50, "production_slots":1, "shop_id":"farmers_store"},
	"dessert_shop": {"name":"Dessert Shop", "category":"commercial", "subtype":"dessert_shop", "cost":350000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.90,0.58,0.68), "level":55, "production_slots":1, "shop_id":"dessert_shop"},

	"coconut_grove": {"name":"Coconut Grove", "category":"industrial", "factory_tier":"small", "region":"sunny_isles", "cost":15000, "size":Vector2i(3,3), "population":0, "build_time":7.0, "color":Color("#4BAE9A"), "level":25, "production_slots":2, "regional_factory":true, "counts_toward_factory_limit":false},
	"snowberry_farm": {"name":"Snowberry Farm", "category":"industrial", "factory_tier":"small", "region":"frosty_fjords", "cost":18000, "size":Vector2i(3,3), "population":0, "build_time":8.0, "color":Color("#91B7D1"), "level":30, "production_slots":2, "regional_factory":true, "counts_toward_factory_limit":false},
	"cactus_farm": {"name":"Cactus Farm", "category":"industrial", "factory_tier":"small", "region":"cactus_canyon", "cost":22000, "size":Vector2i(3,3), "population":0, "build_time":8.0, "color":Color("#B88B4E"), "level":35, "production_slots":2, "regional_factory":true, "counts_toward_factory_limit":false},
	"herb_garden": {"name":"Herb Garden", "category":"industrial", "factory_tier":"small", "region":"green_valley", "cost":26000, "size":Vector2i(3,3), "population":0, "build_time":9.0, "color":Color("#5D9D57"), "level":40, "production_slots":2, "regional_factory":true, "counts_toward_factory_limit":false},
	"olive_grove": {"name":"Olive Grove", "category":"industrial", "factory_tier":"small", "region":"limestone_cliffs", "cost":30000, "size":Vector2i(3,3), "population":0, "build_time":9.0, "color":Color("#87965B"), "level":45, "production_slots":2, "regional_factory":true, "counts_toward_factory_limit":false},
	"factory_small": {"name":"Small Factory", "category":"industrial", "factory_tier":"small", "cost":0, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.55,0.55,0.6), "produces":"metal", "level":1, "production_slots":6, "pollution":1, "pollution_radius":12.0},
	"factory_basic": {"name":"Basic Factory", "category":"industrial", "factory_tier":"basic", "cost":500, "size":Vector2i(2,2), "population":0, "population_required":4000, "build_time":5.0, "color":Color(0.48,0.50,0.56), "level":1, "production_slots":6, "pollution":1, "pollution_radius":10.0},
	"factory_mass": {"name":"Mass Production Factory", "category":"industrial", "factory_tier":"mass", "cost":7000, "size":Vector2i(2,2), "population":0, "population_required":27000, "build_time":6.0, "color":Color(0.43,0.47,0.53), "level":1, "production_slots":6, "pollution":1, "pollution_radius":8.0},
	"factory_hightech": {"name":"High-tech Factory", "category":"industrial", "factory_tier":"hightech", "cost":20000, "size":Vector2i(2,2), "population":0, "population_required":80000, "build_time":7.0, "color":Color(0.38,0.54,0.62), "level":1, "production_slots":6, "pollution":1, "pollution_radius":6.0},
	"factory_nano": {"name":"Nano-tech Factory", "category":"industrial", "factory_tier":"nano", "cost":50000, "size":Vector2i(2,2), "population":0, "population_required":1500000, "build_time":8.0, "color":Color(0.34,0.62,0.66), "level":1, "production_slots":6, "pollution":0, "pollution_radius":0.0},
	"industrial_1": {"name":"Small Factory (Legacy)", "category":"industrial", "legacy_only":true, "cost":0, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.55,0.55,0.6), "produces":"metal", "level":1, "production_slots":6, "pollution":1, "pollution_radius":12.0},
	"industrial_2": {"name":"Factory (Legacy)", "category":"industrial", "legacy_only":true, "cost":500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.45,0.45,0.5), "produces":"wood", "level":2, "production_slots":2},
	"industrial_3": {"name":"Factory+ (Legacy)", "category":"industrial", "legacy_only":true, "cost":1500, "size":Vector2i(2,2), "population":0, "build_time":6.0, "color":Color(0.4,0.42,0.48), "produces":"plastic", "level":5, "production_slots":2},
	"power_wind": {"name":"Wind Power Plant", "category":"service", "service_group":"power", "cost":1500, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.7,0.9,0.85), "power":12, "pollution":0, "pollution_radius":0.0, "level":1},
	"power_coal": {"name":"Coal Power Plant", "category":"service", "service_group":"power", "cost":1000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.38,0.39,0.42), "power":12, "pollution":1, "pollution_radius":10.0, "level":1},
	"power_wind_deluxe": {"name":"Deluxe Wind Power Plant", "category":"service", "service_group":"power", "cost":15000, "size":Vector2i(2,2), "population":0, "build_time":6.0, "color":Color(0.62,0.86,0.82), "power":22, "pollution":0, "pollution_radius":0.0, "level":10},
	"power_solar": {"name":"Solar Power Plant", "category":"service", "service_group":"power", "cost":22000, "size":Vector2i(2,4), "population":0, "build_time":7.0, "color":Color(0.95,0.78,0.35), "power":35, "pollution":0, "pollution_radius":0.0, "level":15},
	"power_oil": {"name":"Oil Power Plant", "category":"service", "service_group":"power", "cost":15000, "size":Vector2i(2,4), "population":0, "build_time":7.0, "color":Color(0.42,0.39,0.34), "power":40, "pollution":1, "pollution_radius":8.0, "level":18},
	"power_nuclear": {"name":"Nuclear Power Plant", "category":"service", "service_group":"power", "cost":35000, "size":Vector2i(3,3), "population":0, "build_time":9.0, "color":Color(0.58,0.72,0.62), "power":60, "pollution":1, "pollution_radius":12.0, "level":22},
	"water_tower": {"name":"Water Tower", "category":"service", "service_group":"water", "cost":1500, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.45,0.72,0.95), "water":12, "pollution":0, "pollution_radius":0.0, "level":1},
	"water_pump": {"name":"Water Pumping Station", "category":"service", "service_group":"water", "cost":45000, "size":Vector2i(2,3), "population":0, "build_time":8.0, "color":Color(0.34,0.62,0.86), "water":55, "pollution":0, "pollution_radius":0.0, "level":12},
	"fire_station_small": {"name":"Small Fire Station", "category":"service", "service_group":"fire", "cost":3100, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.96,0.42,0.32), "fire":1, "coverage_tiles":10, "pollution":0, "pollution_radius":0.0, "level":5},
	"fire_station": {"name":"Fire Station", "category":"service", "service_group":"fire", "cost":5500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.92,0.32,0.28), "fire":1, "coverage_tiles":15, "pollution":0, "pollution_radius":0.0, "level":5},
	"fire_station_deluxe": {"name":"Deluxe Fire Station", "category":"service", "service_group":"fire", "cost":21000, "size":Vector2i(4,2), "population":0, "build_time":8.0, "color":Color(0.88,0.24,0.20), "fire":1, "coverage_tiles":22, "pollution":0, "pollution_radius":0.0, "level":5},
	"police_station": {"name":"Police Station", "category":"service", "service_group":"police", "cost":3000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.28,0.42,0.78), "police":1, "level":12},
	"police_small": {"name":"Small Police Station", "category":"service", "service_group":"police", "cost":5100, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.20,0.34,0.68), "police":1, "coverage_tiles":10, "pollution":0, "pollution_radius":0.0, "level":12},
	"police_basic": {"name":"Basic Police Station", "category":"service", "service_group":"police", "cost":9400, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.16,0.29,0.62), "police":1, "coverage_tiles":15, "pollution":0, "pollution_radius":0.0, "level":12},
	"police_precinct": {"name":"Police Precinct", "category":"service", "service_group":"police", "cost":36000, "size":Vector2i(4,2), "population":0, "build_time":8.0, "color":Color(0.12,0.23,0.52), "police":1, "coverage_tiles":24, "pollution":0, "pollution_radius":0.0, "level":12},
	"clinic_small": {"name":"Small Clinic", "category":"service", "service_group":"health", "cost":14000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.34,0.72,0.66), "health":1, "coverage_tiles":10, "pollution":0, "pollution_radius":0.0, "level":16},
	"clinic": {"name":"Clinic", "category":"service", "service_group":"health", "cost":21000, "size":Vector2i(2,2), "population":0, "build_time":6.0, "color":Color(0.24,0.64,0.60), "health":1, "coverage_tiles":15, "pollution":0, "pollution_radius":0.0, "level":16},
	"hospital": {"name":"Hospital", "category":"service", "service_group":"health", "cost":58000, "size":Vector2i(4,2), "population":0, "build_time":9.0, "color":Color(0.18,0.54,0.54), "health":1, "coverage_tiles":24, "pollution":0, "pollution_radius":0.0, "level":16},
	"sewage_small": {"name":"Small Sewage Outflow", "category":"service", "service_group":"sewage", "cost":4000, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.48,0.56,0.39), "sewage":7, "pollution":1, "pollution_radius":10.0, "level":8},
	"sewage_basic": {"name":"Basic Sewage Outflow", "category":"service", "service_group":"sewage", "cost":12000, "size":Vector2i(2,2), "population":0, "build_time":6.0, "color":Color(0.43,0.51,0.38), "sewage":28, "pollution":1, "pollution_radius":12.0, "level":8},
	"sewage_deluxe": {"name":"Deluxe Sewage Treatment Plant", "category":"service", "service_group":"sewage", "cost":35000, "size":Vector2i(2,3), "population":0, "build_time":8.0, "color":Color(0.48,0.68,0.62), "sewage":55, "pollution":0, "pollution_radius":0.0, "level":14},
	"waste_dump_small": {"name":"Small Garbage Dump", "category":"service", "service_group":"waste", "cost":6000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.55,0.48,0.36), "waste":15, "pollution":1, "pollution_radius":10.0, "level":14},
	"waste_dump": {"name":"Garbage Dump", "category":"service", "service_group":"waste", "cost":12000, "size":Vector2i(2,3), "population":0, "build_time":6.0, "color":Color(0.48,0.43,0.35), "waste":31, "pollution":1, "pollution_radius":12.0, "level":14},
	"waste_incinerator": {"name":"Garbage Incinerator", "category":"service", "service_group":"waste", "cost":15000, "size":Vector2i(2,2), "population":0, "build_time":7.0, "color":Color(0.46,0.45,0.43), "waste":40, "pollution":1, "pollution_radius":16.0, "pollution_severity":"heavy", "pollution_label":"Heavy pollution", "level":14},
	"waste_recycling": {"name":"Recycling Center", "category":"service", "service_group":"waste", "cost":60000, "size":Vector2i(3,2), "population":0, "build_time":9.0, "color":Color(0.36,0.72,0.52), "waste":70, "pollution":0, "pollution_radius":0.0, "level":20},
	"town_hall": {"name":"Town Hall", "category":"service", "service_group":"government", "government":1, "cost":500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.72,0.68,0.55), "level":1},
	"epic_projects_department": {"name":"Department of Epic Projects", "category":"service", "service_group":"government", "government":1, "cost":0, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.78,0.66,0.36), "level":16},
	"trade_depot": {"name":"Trade Depot", "category":"service", "service_group":"trade", "trade_role":"depot", "cost":15000, "size":Vector2i(3,2), "population":0, "population_required":8000, "build_time":8.0, "color":Color(0.30,0.62,0.78), "level":1},
	"global_trade_hq": {"name":"Global Trade HQ", "category":"service", "service_group":"trade", "trade_role":"market", "cost":30000, "size":Vector2i(3,3), "population":0, "population_required":10000, "build_time":10.0, "color":Color(0.32,0.48,0.76), "level":1},
	"cargo_port": {"name":"Cargo Port", "category":"service", "service_group":"trade", "trade_role":"ship", "cost":45000, "size":Vector2i(4,3), "population":0, "population_required":20000, "build_time":12.0, "color":Color(0.25,0.55,0.67), "level":1},
	"park_small": {"name":"Small Park", "category":"park", "cost":300, "size":Vector2i(1,1), "population":0, "build_time":3.0, "color":Color(0.35,0.75,0.4), "level":3, "happiness":5}
}

# Exact Mshin-only material bills for distinctive infrastructure tiers. These
# values are game-balance data, not SimCity BuildIt/EA recipes. Any type not in
# this table still receives a deterministic footprint/build-time/unlock BOM.
const CONSTRUCTION_BOM_TYPE_PROFILES := {
	"power_wind": {"nails": 1, "metal": 1},
	"power_coal": {"nails": 3, "metal": 2},
	"power_wind_deluxe": {"nails": 4, "metal": 3, "planks": 2},
	"power_solar": {"nails": 5, "metal": 4, "planks": 2, "bricks": 1},
	"power_oil": {"nails": 5, "metal": 5, "planks": 2, "bricks": 2},
	"power_nuclear": {"nails": 8, "metal": 7, "planks": 3, "bricks": 3, "cement": 3, "glass": 2},
	"water_tower": {"nails": 2, "metal": 1},
	"water_pump": {"nails": 3, "metal": 2, "planks": 1},
	"fire_station_small": {"nails": 2, "metal": 1, "planks": 1},
	"fire_station": {"nails": 3, "metal": 2, "planks": 1},
	"fire_station_deluxe": {"nails": 5, "metal": 4, "planks": 2},
	"police_station": {"nails": 3, "metal": 2, "planks": 1},
	"police_small": {"nails": 2, "metal": 1, "planks": 1},
	"police_basic": {"nails": 3, "metal": 2, "planks": 1},
	"police_precinct": {"nails": 6, "metal": 4, "planks": 2},
	"clinic_small": {"nails": 3, "metal": 2, "planks": 1, "bricks": 1},
	"clinic": {"nails": 4, "metal": 3, "planks": 2, "bricks": 1, "cement": 1},
	"hospital": {"nails": 8, "metal": 6, "planks": 3, "bricks": 3, "cement": 3},
	"sewage_small": {"nails": 2, "metal": 2, "planks": 1},
	"sewage_basic": {"nails": 4, "metal": 3, "planks": 2},
	"sewage_deluxe": {"nails": 6, "metal": 5, "planks": 2, "bricks": 2, "cement": 2},
	"waste_dump_small": {"nails": 3, "metal": 2, "planks": 1, "bricks": 1},
	"waste_dump": {"nails": 4, "metal": 3, "planks": 2, "bricks": 2, "cement": 1},
	"waste_incinerator": {"nails": 5, "metal": 5, "planks": 2, "bricks": 2, "cement": 2},
	"waste_recycling": {"nails": 7, "metal": 6, "planks": 3, "bricks": 3, "cement": 3, "glass": 2},
	"park_small": {"nails": 1, "wood": 2}
}

var is_moving: bool = false
var moving_building: Building = null
var moving_original_grid: Vector2i = Vector2i.ZERO
var moving_preview_valid: bool = false
const MOVABLE_BUILDING_TYPES := [
	"residential_1", "residential_villa", "residential_apartment", "residential_farm", "la_glass_tower", "la_dome_tower", "la_modern_apartment", "la_roof_garden_villa", "island_cottage", "fjord_chalet", "desert_hacienda", "valley_eco_home", "cliffside_villa",
	"building_supplies", "shop_chain", "restaurant_traditional", "fast_food",
	"art_supplies", "hardware_store", "farmers_market", "furniture_store", "la_office_tower", "la_commercial_arcade",
	"factory_small", "factory_basic", "factory_mass", "factory_hightech", "factory_nano", "industrial_1", "industrial_2", "industrial_3", "coconut_grove", "snowberry_farm", "cactus_farm", "herb_garden", "olive_grove",
	"power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear", "water_tower", "water_pump", "fire_station_small", "fire_station", "fire_station_deluxe", "police_station", "police_small", "police_basic", "police_precinct", "clinic_small", "clinic", "hospital", "sewage_small", "sewage_basic", "sewage_deluxe", "waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling", "town_hall", "epic_projects_department", "trade_depot", "global_trade_hq", "cargo_port",
	"park_small"
]

func _ready() -> void:
	# Local GLTF assignment is deliberately exact-type, never category-wide.
	# Unmapped entries keep their own procedural identity geometry until a
	# matching dedicated model is produced and validated.
	for type_id in BUILDING_MODEL_REGISTRY:
		if not building_types.has(type_id):
			push_error("[BuildManager] Model registry references unknown building type: %s" % type_id)
			continue
		var definition: Dictionary = building_types[type_id]
		if definition.has("model_path"):
			continue
		definition["model_path"] = str(BUILDING_MODEL_REGISTRY[type_id])
		definition["model_scale"] = Vector3.ONE
		building_types[type_id] = definition
	print("[BuildManager] Ready: %d building types" % building_types.size())

func get_region_build_lock_reason(type_id: String) -> String:
	if not building_types.has(type_id):
		return "Unknown building type"
	var required_region := str(building_types[type_id].get("region", ""))
	if required_region.is_empty() or required_region == RegionManager.active_region_id:
		return ""
	var region := RegionManager.get_region_definition(required_region)
	return "Available only in %s" % str(region.get("name", required_region))

func get_population_build_lock_reason(type_id: String) -> String:
	if not building_types.has(type_id):
		return "Unknown building type."
	var required_population := int(building_types[type_id].get("population_required", 0))
	if GameManager.population < required_population:
		return "Requires %d population." % required_population
	return ""

func can_build_another_factory() -> bool:
	return factory_count < LevelProgression.get_factory_limit_for_level(GameManager.level)

func can_build_factory_type(type_id: String) -> bool:
	if not building_types.has(type_id):
		return false
	var definition: Dictionary = building_types[type_id]
	if str(definition.get("category", "")) != "industrial":
		return true
	return GameManager.population >= int(definition.get("population_required", 0))

func get_factory_type_population_requirement(type_id: String) -> int:
	return int(building_types.get(type_id, {}).get("population_required", 0))

func get_factory_build_lock_reason(type_id: String) -> String:
	if not building_types.has(type_id):
		return "Unknown factory type."
	var definition: Dictionary = building_types[type_id]
	if str(definition.get("category", "")) != "industrial":
		return ""
	if bool(definition.get("counts_toward_factory_limit", true)) and not can_build_another_factory():
		return "Factory quota full. Reach the next Mayor Level."
	var required_population := int(definition.get("population_required", 0))
	if GameManager.population < required_population:
		return "Requires %s population." % _format_population_for_message(required_population)
	var cost := int(definition.get("cost", 0))
	if not EconomyManager.can_afford(cost):
		return "Need %s coins." % _format_population_for_message(cost)
	return ""

func _format_population_for_message(value: int) -> String:
	# Keep exact values visible instead of rounded shorthand.
	return str(value)

func get_available_buildings(category: String = "") -> Array:
	var result: Array = []
	for key in building_types:
		var definition: Dictionary = building_types[key]
		if bool(definition.get("legacy_only", false)):
			continue
		if int(definition.get("level", 1)) <= GameManager.level and (category == "" or definition.get("category", "") == category):
			# Keep factory tiers visible while locked; eligibility is shown separately.
			result.append(key)
	return result

func select_building(type_id: String) -> void:
	if not building_types.has(type_id):
		push_warning("Unknown building type: " + type_id)
		return
	var definition: Dictionary = building_types[type_id]
	if int(definition.get("level", 1)) > GameManager.level:
		return
	if get_region_build_lock_reason(type_id) != "":
		return
	if get_population_build_lock_reason(type_id) != "":
		return
	if definition.get("category", "") == "industrial" and get_factory_build_lock_reason(type_id) != "":
		return
	selected_building_type = type_id
	placement_rotation_quarters = 0
	is_placing = true
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem") if get_tree().current_scene else null
	if road_system:
		road_system.set_road_mode(false)
	placement_mode_changed.emit(true)

func cancel_placement() -> void:
	selected_building_type = ""
	is_placing = false
	placement_mode_changed.emit(false)
	var scene = get_tree().current_scene
	var ghost = scene.get_node_or_null("GhostPreview") if scene else null
	if ghost:
		ghost.hide_ghost()

func get_footprint_cells(anchor: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			cells.append(anchor + Vector2i(x, y))
	return cells

func is_inside_world(anchor: Vector2i, size: Vector2i = Vector2i.ONE) -> bool:
	return anchor.x >= -WORLD_HALF_CELLS and anchor.y >= -WORLD_HALF_CELLS and anchor.x + size.x <= WORLD_HALF_CELLS and anchor.y + size.y <= WORLD_HALF_CELLS

func is_cell_free(grid_pos: Vector2i, size: Vector2i = Vector2i.ONE, allow_reserved_restore: bool = false) -> bool:
	if not is_inside_world(grid_pos, size):
		return false
	var scene = get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	for cell in get_footprint_cells(grid_pos, size):
		if allow_reserved_restore:
			if not LandExpansionManager.is_cell_unlocked(cell):
				return false
		elif not LandExpansionManager.is_cell_buildable(cell):
			return false
		if road_system and road_system.has_road(cell):
			return false
		if building_cells.has(cell):
			var occupied = building_cells[cell]
			if is_instance_valid(occupied):
				return false
			building_cells.erase(cell)
	return true

func has_road_access(anchor: Vector2i, size: Vector2i) -> bool:
	var scene = get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	if road_system == null:
		return false
	for x in range(size.x):
		var north := anchor + Vector2i(x, -1)
		var south := anchor + Vector2i(x, size.y)
		if road_system.has_road(north) and road_system.is_road_connected_to_gateway(north):
			return true
		if road_system.has_road(south) and road_system.is_road_connected_to_gateway(south):
			return true
	for y in range(size.y):
		var west := anchor + Vector2i(-1, y)
		var east := anchor + Vector2i(size.x, y)
		if road_system.has_road(west) and road_system.is_road_connected_to_gateway(west):
			return true
		if road_system.has_road(east) and road_system.is_road_connected_to_gateway(east):
			return true
	return false

func is_building_operational(building: Node) -> bool:
	if not is_instance_valid(building) or str(building.get("status")) != "completed":
		return false
	var definition: Dictionary = building.get("definition")
	var anchor: Vector2i = building.get("grid_pos")
	var size: Vector2i = definition.get("size", Vector2i(2, 2))
	if not has_road_access(anchor, size):
		return false
	# Production buildings need their catalog-defined local power and water
	# service as well as a Gateway-connected road. Homes retain their existing
	# happiness-penalty model instead of being hard-stopped here.
	if has_node("/root/ServiceManager") and ServiceManager.get_building_operating_profile(building).size() > 0:
		if not ServiceManager.is_building_services_served(building):
			return false
	if has_node("/root/ServiceManager") and ServiceManager.requires_operational_workforce(building):
		if not ServiceManager.is_workforce_served(building):
			return false
	return true

func is_production_building_operational(building: Node) -> bool:
	if not is_instance_valid(building) or str(building.get("status")) != "completed":
		return false
	var definition: Dictionary = building.get("definition")
	var anchor: Vector2i = building.get("grid_pos")
	var size: Vector2i = definition.get("size", Vector2i(2, 2))
	if not has_road_access(anchor, size):
		return false
	# Factories and commercial production stores run on their own production
	# loop. They require a live Gateway-connected road, but not the city's
	# Mshin-only power/water/workforce service simulation. Applying those
	# municipal-service gates can reject a valid order or pause its timer even
	# when every recipe input is already in City Storage.
	var category := str(definition.get("category", ""))
	if category in ["industrial", "commercial"]:
		return true
	return is_building_operational(building)

func _get_building_material_complexity(type_id: String) -> int:
	var definition: Dictionary = building_types.get(type_id, {})
	if definition.is_empty():
		return 0
	var size: Vector2i = definition.get("size", Vector2i.ONE)
	var area := maxi(1, size.x * size.y)
	var build_time := maxf(1.0, float(definition.get("build_time", 4.0)))
	var unlock_level := maxi(1, int(definition.get("level", 1)))
	var area_band := maxi(0, int(ceil(float(area - 4) / 4.0)))
	var time_band := maxi(0, int(ceil((build_time - 4.0) / 2.0)))
	var level_band := maxi(0, int(floor(float(unlock_level - 1) / 20.0)))
	return clampi(1 + area_band + time_band + level_band, 1, 8)

func get_construction_bom(type_id: String) -> Dictionary:
	if not building_types.has(type_id):
		return {}
	var definition: Dictionary = building_types[type_id]
	if definition.has("construction_bom"):
		return definition.get("construction_bom", {}).duplicate(true)
	# Residential and commercial placement follows the catalog Mayor Level and
	# Simoleons cost. The generic Mshin construction BOM must not silently add
	# Nails/Metal/Planks prerequisites to homes and stores: those are production
	# chain inputs, not EA building-placement unlock requirements.
	if str(definition.get("category", "")) in ["residential", "commercial"]:
		return {}
	if CONSTRUCTION_BOM_BOOTSTRAP_TYPES.has(type_id):
		return {}
	if CONSTRUCTION_BOM_TYPE_PROFILES.has(type_id):
		return CONSTRUCTION_BOM_TYPE_PROFILES[type_id].duplicate(true)
	var category := str(definition.get("category", ""))
	var requirements: Dictionary = CONSTRUCTION_BOM_PROFILES.get(category, {}).duplicate(true)
	if requirements.is_empty():
		return {}
	var complexity := _get_building_material_complexity(type_id)
	for item_id in requirements.keys():
		requirements[item_id] = maxi(1, int(requirements[item_id]) * complexity)
	var unlock_level := maxi(1, int(definition.get("level", 1)))
	# The BOM is now resolved per exact building type using footprint,
	# construction duration and unlock tier. Material unlocks are never earlier
	# than the corresponding product's catalog level.
	if unlock_level >= 3 and not ProductionManager.get_item_definition("planks").is_empty():
		requirements["planks"] = maxi(1, int(ceil(float(complexity) / 2.0)))
	if unlock_level >= 13 and not ProductionManager.get_item_definition("bricks").is_empty():
		requirements["bricks"] = maxi(1, int(ceil(float(complexity) / 3.0)))
	if unlock_level >= 14 and not ProductionManager.get_item_definition("cement").is_empty():
		requirements["cement"] = maxi(1, int(ceil(float(complexity) / 3.0)))
	if unlock_level >= 19 and not ProductionManager.get_item_definition("glass").is_empty():
		requirements["glass"] = maxi(1, int(ceil(float(complexity) / 4.0)))
	return requirements

func get_construction_bom_source(type_id: String) -> String:
	if not building_types.has(type_id):
		return ""
	var definition: Dictionary = building_types[type_id]
	if definition.has("construction_bom"):
		return str(definition.get("construction_bom_source", "Mshin building-specific design"))
	if str(definition.get("category", "")) in ["residential", "commercial"]:
		return "No placement material charge — Mayor Level and Simoleons gated"
	if CONSTRUCTION_BOM_BOOTSTRAP_TYPES.has(type_id):
		return "Mshin bootstrap exception — no material charge"
	if CONSTRUCTION_BOM_TYPE_PROFILES.has(type_id):
		return "Mshin exact infrastructure type profile — explicit materials; not an EA recipe"
	return "Mshin per-building profile — footprint/build-time/unlock-tier formula; not an EA recipe"

func get_construction_bom_lock_reason(type_id: String) -> String:
	var requirements := get_construction_bom(type_id)
	if requirements.is_empty():
		return ""
	var missing: Array[String] = []
	for item_id in requirements:
		var required := int(requirements[item_id])
		if required <= 0 or ProductionManager.get_item_definition(str(item_id)).is_empty():
			return "Invalid construction BOM for " + type_id + ": " + str(item_id)
		var available := StorageManager.get_count(str(item_id))
		if available < required:
			missing.append("%s ×%d" % [str(item_id), required - available])
	return "" if missing.is_empty() else "Missing construction materials: " + ", ".join(missing)

func get_non_residential_upgrade_bom(type_id: String, current_stage: int) -> Dictionary:
	if not building_types.has(type_id) or current_stage < 1 or current_stage >= 6:
		return {}
	var definition: Dictionary = building_types[type_id]
	var category := str(definition.get("category", ""))
	if category == "residential" or not ["commercial", "industrial", "service", "park"].has(category):
		return {}
	var stage_profiles: Dictionary = definition.get("non_residential_upgrade_boms", {})
	if stage_profiles.has(str(current_stage)):
		return stage_profiles[str(current_stage)].duplicate(true)
	if stage_profiles.has(current_stage):
		return stage_profiles[current_stage].duplicate(true)
	var base := get_construction_bom(type_id)
	if base.is_empty():
		base = CONSTRUCTION_BOM_PROFILES.get(category, {}).duplicate(true)
	if base.is_empty():
		return {}
	var requirements: Dictionary = {}
	for item_id in base:
		requirements[str(item_id)] = maxi(1, int(base[item_id]) * current_stage)
	var unlock_level := maxi(1, int(definition.get("level", 1)))
	if current_stage >= 2 and unlock_level >= 3 and not ProductionManager.get_item_definition("planks").is_empty():
		requirements["planks"] = int(requirements.get("planks", 0)) + 1
	if current_stage >= 3 and unlock_level >= 13 and not ProductionManager.get_item_definition("bricks").is_empty():
		requirements["bricks"] = int(requirements.get("bricks", 0)) + 1
	if current_stage >= 4 and unlock_level >= 14 and not ProductionManager.get_item_definition("cement").is_empty():
		requirements["cement"] = int(requirements.get("cement", 0)) + 1
	if current_stage >= 5 and unlock_level >= 19 and not ProductionManager.get_item_definition("glass").is_empty():
		requirements["glass"] = int(requirements.get("glass", 0)) + 1
	return requirements

func get_non_residential_upgrade_bom_source(type_id: String, current_stage: int) -> String:
	if not building_types.has(type_id) or current_stage < 1 or current_stage >= 6:
		return ""
	var definition: Dictionary = building_types[type_id]
	var stage_profiles: Dictionary = definition.get("non_residential_upgrade_boms", {})
	if stage_profiles.has(str(current_stage)) or stage_profiles.has(current_stage):
		return str(definition.get("non_residential_upgrade_bom_source", "Mshin exact per-building upgrade stage profile"))
	return "Mshin per-building upgrade profile — construction BOM scaled by stage with unlock-tier materials; not an EA recipe"

func get_bom_catalog_audit() -> Dictionary:
	var errors: Array[String] = []
	var construction_count := 0
	var upgrade_count := 0
	var construction_boms: Dictionary = {}
	var construction_sources: Dictionary = {}
	var non_residential_upgrade_boms: Dictionary = {}
	var upgrade_sources: Dictionary = {}
	for type_variant in building_types.keys():
		var type_id := str(type_variant)
		var definition: Dictionary = building_types[type_id]
		var category := str(definition.get("category", ""))
		var construction := get_construction_bom(type_id)
		construction_boms[type_id] = construction.duplicate(true)
		construction_sources[type_id] = get_construction_bom_source(type_id)
		var level_and_currency_placement := category in ["residential", "commercial"] and not definition.has("construction_bom")
		if CONSTRUCTION_BOM_BOOTSTRAP_TYPES.has(type_id) or level_and_currency_placement:
			if not construction.is_empty():
				errors.append("%s: placement-exempt BOM must remain empty" % type_id)
		else:
			if construction.is_empty():
				errors.append("%s: missing construction BOM" % type_id)
			for item_variant in construction.keys():
				var item_id := str(item_variant)
				var amount := int(construction[item_variant])
				var item_definition := ProductionManager.get_item_definition(item_id)
				if amount <= 0 or item_definition.is_empty():
					errors.append("%s: invalid construction material %s ×%d" % [type_id, item_id, amount])
				elif int(item_definition.get("level", 1)) > int(definition.get("level", 1)):
					errors.append("%s: construction material %s unlocks after the building" % [type_id, item_id])
			construction_count += 1
		if category in ["commercial", "industrial", "service", "park"]:
			var stages: Dictionary = {}
			for stage in range(1, 6):
				var upgrade := get_non_residential_upgrade_bom(type_id, stage)
				stages[str(stage)] = upgrade.duplicate(true)
				if upgrade.is_empty():
					errors.append("%s: missing upgrade BOM at stage %d" % [type_id, stage])
					continue
				if get_non_residential_upgrade_cost(type_id, stage) <= 0 or get_non_residential_upgrade_duration_seconds(type_id, stage) <= 0:
					errors.append("%s: invalid upgrade cost/duration at stage %d" % [type_id, stage])
				for item_variant in upgrade.keys():
					var item_id := str(item_variant)
					if int(upgrade[item_variant]) <= 0 or ProductionManager.get_item_definition(item_id).is_empty():
						errors.append("%s: invalid upgrade material %s at stage %d" % [type_id, item_id, stage])
				upgrade_count += 1
			non_residential_upgrade_boms[type_id] = stages
			upgrade_sources[type_id] = {
				"1": get_non_residential_upgrade_bom_source(type_id, 1),
				"2": get_non_residential_upgrade_bom_source(type_id, 2),
				"3": get_non_residential_upgrade_bom_source(type_id, 3),
				"4": get_non_residential_upgrade_bom_source(type_id, 4),
				"5": get_non_residential_upgrade_bom_source(type_id, 5)
			}
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"building_type_count": building_types.size(),
		"construction_bom_count": construction_count,
		"non_residential_upgrade_bom_count": upgrade_count,
		"exact_type_profile_count": CONSTRUCTION_BOM_TYPE_PROFILES.size(),
		"construction_boms": construction_boms,
		"construction_sources": construction_sources,
		"non_residential_upgrade_boms": non_residential_upgrade_boms,
		"upgrade_sources": upgrade_sources
	}

func get_non_residential_upgrade_cost(type_id: String, current_stage: int) -> int:
	if not building_types.has(type_id) or current_stage < 1 or current_stage >= 6:
		return 0
	var base_cost := maxi(100, roundi(float(building_types[type_id].get("cost", 0)) * 0.08))
	return base_cost * current_stage

func get_non_residential_upgrade_duration_seconds(type_id: String, current_stage: int) -> int:
	if not building_types.has(type_id) or current_stage < 1 or current_stage >= 6:
		return 0
	var build_time := maxf(1.0, float(building_types[type_id].get("build_time", 4.0)))
	return maxi(20, roundi(build_time * 3.0) + current_stage * 15)

func get_non_residential_upgrade_lock_reason(type_id: String, current_stage: int) -> String:
	var requirements := get_non_residential_upgrade_bom(type_id, current_stage)
	if requirements.is_empty():
		return "This building cannot be upgraded further"
	if EconomyManager.simoleons < get_non_residential_upgrade_cost(type_id, current_stage):
		return "Not enough Simoleons"
	var missing: Array[String] = []
	for item_id in requirements:
		var required := int(requirements[item_id])
		if required <= 0 or ProductionManager.get_item_definition(str(item_id)).is_empty():
			return "Invalid upgrade BOM: " + str(item_id)
		var available := StorageManager.get_count(str(item_id))
		if available < required:
			missing.append("%s ×%d" % [str(item_id), required - available])
	return "" if missing.is_empty() else "Missing upgrade materials: " + ", ".join(missing)

func can_place_at(grid_pos: Vector2i, type_id: String = "", rotation_quarters: int = -1, allow_reserved_restore: bool = false) -> bool:
	var chosen: String = type_id if type_id != "" else selected_building_type
	if chosen == "" or not building_types.has(chosen):
		return false
	var definition: Dictionary = building_types[chosen]
	# Restoring a saved city is not a new placement action. Progression,
	# region, population, factory and affordability gates were already satisfied
	# when the building was originally placed; rechecking them against partially
	# restored city totals (especially population, which is rebuilt afterwards)
	# can reject the first saved building and leave the city empty.
	if not allow_reserved_restore:
		if int(definition.get("level", 1)) > GameManager.level:
			return false
		if get_region_build_lock_reason(chosen) != "":
			return false
		if get_population_build_lock_reason(chosen) != "":
			return false
		# Factory gates are checked before affordability and physical placement.
		if definition.get("category", "") == "industrial" and get_factory_build_lock_reason(chosen) != "":
			return false
		if not EconomyManager.can_afford(int(definition.get("cost", 0))):
			return false
		if not get_construction_bom_lock_reason(chosen).is_empty():
			return false
	var applied_rotation := rotation_quarters
	if applied_rotation < 0:
		applied_rotation = placement_rotation_quarters if chosen == selected_building_type else 0
	var size: Vector2i = get_building_size(chosen, applied_rotation)
	if not is_cell_free(grid_pos, size, allow_reserved_restore) or not has_road_access(grid_pos, size):
		return false
	return true

func get_restore_placement_block_reason(grid_pos: Vector2i, type_id: String, rotation_quarters: int = 0) -> String:
	if type_id.is_empty() or not building_types.has(type_id):
		return "unknown building type '%s'" % type_id
	var size := get_building_size(type_id, rotation_quarters)
	if not is_inside_world(grid_pos, size):
		return "footprint %s size %s is outside world bounds" % [str(grid_pos), str(size)]
	var scene = get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	for cell in get_footprint_cells(grid_pos, size):
		if not LandExpansionManager.is_cell_unlocked(cell):
			return "footprint cell %s is locked land" % str(cell)
		if road_system != null and road_system.has_road(cell):
			return "footprint cell %s is occupied by a road" % str(cell)
		if building_cells.has(cell):
			var occupant = building_cells[cell]
			if is_instance_valid(occupant):
				return "footprint cell %s is occupied by building '%s'" % [str(cell), str(occupant.building_type)]
	if not has_road_access(grid_pos, size):
		return "no gateway-connected road adjacent to footprint %s size %s" % [str(grid_pos), str(size)]
	return ""

func can_move_to(grid_pos: Vector2i) -> bool:
	if not is_moving or not is_instance_valid(moving_building):
		return false
	var size: Vector2i = moving_building.definition.get("size", Vector2i(2, 2))
	return is_cell_free(grid_pos, size) and has_road_access(grid_pos, size)

func begin_move(building: Variant) -> bool:
	if is_moving or not is_instance_valid(building) or not (building is Building):
		return false
	var target_building: Building = building as Building
	if not MOVABLE_BUILDING_TYPES.has(target_building.building_type):
		return false
	if buildings.get(target_building.building_id) != target_building:
		return false
	moving_building = target_building
	moving_original_grid = target_building.grid_pos
	for cell in get_footprint_cells(target_building.grid_pos, target_building.definition.get("size", Vector2i(2, 2))):
		if building_cells.get(cell) == target_building:
			building_cells.erase(cell)
	is_moving = true
	moving_preview_valid = false
	target_building.set_move_preview(true, false)
	return true

func preview_move_at(grid_pos: Vector2i) -> bool:
	if not is_moving or not is_instance_valid(moving_building):
		return false
	moving_preview_valid = can_move_to(grid_pos)
	var size: Vector2i = moving_building.definition.get("size", Vector2i(2, 2))
	moving_building.global_position = grid_to_world(grid_pos) + Vector3((size.x - 1) * GRID_SIZE * 0.5, 0.55, (size.y - 1) * GRID_SIZE * 0.5)
	if moving_building.has_method("set_move_preview"):
		moving_building.set_move_preview(true, moving_preview_valid)
	return moving_preview_valid

func invalidate_move_preview() -> void:
	if not is_moving:
		return
	moving_preview_valid = false
	if is_instance_valid(moving_building) and moving_building.has_method("set_move_preview"):
		moving_building.set_move_preview(true, false)

func finish_move() -> bool:
	if not is_moving or not is_instance_valid(moving_building):
		cancel_move()
		return false
	var building := moving_building
	var target := world_to_grid(Vector3(building.global_position.x - (building.definition.get("size", Vector2i(2, 2)).x - 1) * GRID_SIZE * 0.5, 0.0, building.global_position.z - (building.definition.get("size", Vector2i(2, 2)).y - 1) * GRID_SIZE * 0.5))
	if not moving_preview_valid or not can_move_to(target):
		cancel_move()
		return false
	building.grid_pos = target
	var size: Vector2i = building.definition.get("size", Vector2i(2, 2))
	for cell in get_footprint_cells(target, size):
		building_cells[cell] = building
	building.global_position = grid_to_world(target) + Vector3((size.x - 1) * GRID_SIZE * 0.5, 0.0, (size.y - 1) * GRID_SIZE * 0.5)
	if building.has_method("set_move_preview"):
		building.set_move_preview(false, true)
	moving_building = null
	is_moving = false
	moving_preview_valid = false
	ServiceManager.recalculate_from_buildings()
	if has_node("/root/FireHazardManager"):
		FireHazardManager.on_city_changed()
	return true

func cancel_move() -> void:
	if not is_moving:
		return
	var building := moving_building
	if is_instance_valid(building):
		building.grid_pos = moving_original_grid
		var size: Vector2i = building.definition.get("size", Vector2i(2, 2))
		for cell in get_footprint_cells(moving_original_grid, size):
			building_cells[cell] = building
		building.global_position = grid_to_world(moving_original_grid) + Vector3((size.x - 1) * GRID_SIZE * 0.5, 0.0, (size.y - 1) * GRID_SIZE * 0.5)
		if building.has_method("set_move_preview"):
			building.set_move_preview(false, true)
	moving_building = null
	is_moving = false
	moving_preview_valid = false

func move_building_to(building: Node, target: Vector2i) -> bool:
	if not begin_move(building):
		return false
	preview_move_at(target)
	return finish_move()

func place_building_at_world(world_pos: Vector3) -> bool:
	if not is_placing or selected_building_type == "":
		return false
	return place_building(world_to_grid(world_pos))

func place_building(grid_pos: Vector2i, type_id: String = "", saved_stage: int = 1, saved_status: String = "constructing", saved_rotation_quarters: int = -1, allow_reserved_restore: bool = false) -> bool:
	var chosen: String = type_id if type_id != "" else selected_building_type
	var applied_rotation := posmod(placement_rotation_quarters if saved_rotation_quarters < 0 else saved_rotation_quarters, 4)
	if not can_place_at(grid_pos, chosen, applied_rotation, allow_reserved_restore):
		return false
	var definition: Dictionary = building_types[chosen]
	var cost: int = int(definition.get("cost", 0))
	# The saved building's purchase was already paid when it was first
	# placed. Do not reject restoration because the player's current balance
	# is lower than the original catalog price.
	if not allow_reserved_restore and cost > 0 and not EconomyManager.can_afford(cost):
		return false
	var scene = get_tree().current_scene
	var world = scene.get_node_or_null("World/Buildings") if scene else null
	if world == null:
		push_error("Cannot place building: World/Buildings node is missing.")
		return false
	var building_node = BuildingScene.instantiate()
	if building_node == null:
		return false
	var construction_bom := {} if allow_reserved_restore else get_construction_bom(chosen)
	var construction_cost_batches: Dictionary = {}
	if not construction_bom.is_empty():
		var construction_removal: Dictionary = StorageManager.remove_items_with_cost_batches(construction_bom)
		if not bool(construction_removal.get("success", false)):
			building_node.free()
			return false
		construction_cost_batches = construction_removal.get("cost_batches", {}).duplicate(true)
	if not allow_reserved_restore and cost > 0 and not EconomyManager.spend_simoleons(cost):
		if not construction_bom.is_empty():
			StorageManager.restore_items_with_cost_batches(construction_bom, construction_cost_batches)
		building_node.free()
		return false
	building_node.construction_reserved_bom = construction_bom.duplicate(true)
	building_node.construction_reserved_cost_batches = construction_cost_batches.duplicate(true)
	building_node.construction_reserved_simoleons = cost if not allow_reserved_restore else 0
	var building_id: String = "b_%d_%d" % [Time.get_ticks_msec(), buildings.size()]
	var data: Dictionary = {
		"id": building_id,
		"type": chosen,
		"grid_pos": grid_pos,
		"definition": _definition_for_rotation(definition, applied_rotation),
		"rotation_y": float(applied_rotation) * PI * 0.5,
		"status": saved_status,
		"build_time": float(definition.get("build_time", 4.0)),
		"upgrade_stage": clampi(saved_stage, 1, 6)
	}
	world.add_child(building_node)
	var size: Vector2i = _definition_for_rotation(definition, applied_rotation).get("size", Vector2i(2,2))
	building_node.global_position = grid_to_world(grid_pos) + Vector3((size.x - 1) * GRID_SIZE * 0.5, 0.0, (size.y - 1) * GRID_SIZE * 0.5)
	# Register the node and its complete footprint before setup() can emit
	# construction-complete/service events. This keeps population and happiness
	# recalculation from seeing a temporarily empty city during instant restores.
	buildings[building_id] = building_node
	for occupied_cell in get_footprint_cells(grid_pos, size):
		building_cells[occupied_cell] = building_node
	building_node.setup(data)
	if definition.get("category", "") == "industrial" and bool(definition.get("counts_toward_factory_limit", true)):
		factory_count += 1
	construction_started.emit(building_id)
	building_placed.emit(data)
	GameManager.add_experience(3)
	return true

func cancel_construction(building: Building) -> bool:
	if not is_instance_valid(building) or building.status != "constructing":
		return false
	if buildings.get(building.building_id) != building:
		return false
	var refund_total := 0
	for amount_variant in building.construction_reserved_bom.values():
		refund_total += maxi(0, int(amount_variant))
	# The player may have filled storage after starting construction. Never
	# destroy the paid BOM: keep the site and reservation until space is freed.
	if refund_total > StorageManager.get_free():
		return false
	if not building.construction_reserved_bom.is_empty():
		var refund_ok: bool = StorageManager.restore_items_with_cost_batches(building.construction_reserved_bom, building.construction_reserved_cost_batches) if not building.construction_reserved_cost_batches.is_empty() else StorageManager.add_items(building.construction_reserved_bom)
		if not refund_ok:
			return false
	if building.construction_reserved_simoleons > 0:
		EconomyManager.add_simoleons(building.construction_reserved_simoleons)
	building.construction_reserved_bom.clear()
	building.construction_reserved_cost_batches.clear()
	building.construction_reserved_simoleons = 0
	for cell in get_footprint_cells(building.grid_pos, building.definition.get("size", Vector2i(2, 2))):
		if building_cells.get(cell) == building:
			building_cells.erase(cell)
	buildings.erase(building.building_id)
	if str(building.definition.get("category", "")) == "industrial" and bool(building.definition.get("counts_toward_factory_limit", true)):
		factory_count = maxi(0, factory_count - 1)
	var removed_id := building.building_id
	building_removed.emit(removed_id)
	building.queue_free()
	ServiceManager.recalculate_from_buildings()
	if has_node("/root/FireHazardManager"):
		FireHazardManager.on_city_changed()
	return true


func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(floori(world_pos.x / GRID_SIZE), floori(world_pos.z / GRID_SIZE))

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * GRID_SIZE + GRID_SIZE * 0.5, 0.0, grid_pos.y * GRID_SIZE + GRID_SIZE * 0.5)

func get_selected_size() -> Vector2i:
	return get_building_size(selected_building_type, placement_rotation_quarters)

func get_building_size(type_id: String, rotation_quarters: int = 0) -> Vector2i:
	if not building_types.has(type_id):
		return Vector2i(2, 2)
	var size: Vector2i = building_types[type_id].get("size", Vector2i(2, 2))
	return Vector2i(size.y, size.x) if posmod(rotation_quarters, 2) == 1 else size

func _definition_for_rotation(definition: Dictionary, rotation_quarters: int) -> Dictionary:
	var rotated: Dictionary = definition.duplicate(true)
	var size: Vector2i = definition.get("size", Vector2i(2, 2))
	rotated["size"] = Vector2i(size.y, size.x) if posmod(rotation_quarters, 2) == 1 else size
	return rotated

func rotate_placement() -> bool:
	if not is_placing or selected_building_type == "":
		return false
	placement_rotation_quarters = posmod(placement_rotation_quarters + 1, 4)
	return true

func notify_construction_finished(building_id: String) -> void:
	construction_finished.emit(building_id)

func building_at_cell(grid_pos: Vector2i) -> Node:
	var building = building_cells.get(grid_pos)
	if building != null and is_instance_valid(building):
		return building
	if building != null:
		building_cells.erase(grid_pos)
	return null

func unregister_building(building_id: String) -> void:
	var building = buildings.get(building_id)
	if building == null:
		return
	var definition: Dictionary = building.definition
	if building.has_method("set_fire_smoke"):
		building.set_fire_smoke(false)
	var size: Vector2i = definition.get("size", Vector2i(2, 2))
	for cell in get_footprint_cells(building.grid_pos, size):
		if building_cells.get(cell) == building:
			building_cells.erase(cell)
	buildings.erase(building_id)
	if definition.get("category", "") == "industrial" and bool(definition.get("counts_toward_factory_limit", true)):
		factory_count = maxi(0, factory_count - 1)
	# Remove population contributed by completed residential or populated buildings.
	var removed_population := int(building.current_population)
	if removed_population <= 0:
		removed_population = int(definition.get("population", 0))
	if removed_population > 0:
		GameManager.set_population(maxi(0, GameManager.population - removed_population))
	var happiness_bonus := float(definition.get("happiness", 0))
	if happiness_bonus > 0.0:
		GameManager.set_happiness(maxf(0.0, GameManager.happiness - happiness_bonus))
	if has_node("/root/ServiceManager"):
		ServiceManager.recalculate_from_buildings()
	if has_node("/root/FireHazardManager"):
		FireHazardManager.on_city_changed()
	building_removed.emit(building_id)
