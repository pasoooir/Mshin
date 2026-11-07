extends CanvasLayer

@onready var level_label: Label = $TopLeft/LevelBox/LevelLabel
@onready var population_label: Label = $TopLeft/PopBox/PopLabel
@onready var happiness_icon: Label = $TopLeft/HappinessBox/HappyIcon
@onready var storage_label: Label = $TopLeft/StorageBox/StorageLabel
@onready var simoleons_label: Label = $TopLeft/MoneyBox/MoneyLabel
@onready var keys_label: Label = $TopRight/KeysBox/KeysLabel
@onready var status_label: Label = $StatusLabel
@onready var power_label: Label = $TopRight/PowerBox/PowerLabel
@onready var water_label: Label = $TopRight/WaterBox/WaterLabel

func _ready() -> void:
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.population_changed.connect(_on_population_changed)
	GameManager.happiness_changed.connect(_on_happiness_changed)
	EconomyManager.simoleons_changed.connect(_on_simoleons_changed)
	EconomyManager.keys_changed.connect(_on_keys_changed)
	StorageManager.storage_changed.connect(_on_storage_changed)
	BuildManager.placement_mode_changed.connect(_on_placement_mode)
	ServiceManager.power_changed.connect(_on_power_changed)
	ServiceManager.water_changed.connect(_on_water_changed)
	_update_all()
	status_label.text = "Build a road, then place a house and factory beside it. Collect metal, build supplies and upgrade the house."

func _update_all() -> void:
	_on_level_changed(GameManager.level)
	_on_population_changed(GameManager.population)
	_on_happiness_changed(GameManager.happiness)
	_on_simoleons_changed(EconomyManager.simoleons)
	_on_keys_changed(EconomyManager.golden_keys)
	_on_storage_changed()
	_on_power_changed(ServiceManager.total_power, ServiceManager.used_power)
	_on_water_changed(ServiceManager.total_water, ServiceManager.used_water)

func _on_level_changed(level: int) -> void:
	level_label.text = str(level)

func _on_population_changed(population: int) -> void:
	population_label.text = str(population)

func _on_happiness_changed(value: float) -> void:
	if value >= 80: happiness_icon.text = "😊"
	elif value >= 50: happiness_icon.text = "😐"
	else: happiness_icon.text = "😢"

func _on_simoleons_changed(_amount: int) -> void:
	simoleons_label.text = EconomyManager.get_formatted_simoleons()

func _on_keys_changed(amount: int) -> void:
	keys_label.text = str(amount)

func _on_storage_changed() -> void:
	storage_label.text = StorageManager.get_storage_ratio()

func _on_power_changed(total: int, used: int) -> void:
	if power_label:
		power_label.text = "%d/%d" % [used, total]

func _on_water_changed(total: int, used: int) -> void:
	if water_label:
		water_label.text = "%d/%d" % [used, total]

func _on_placement_mode(active: bool) -> void:
	if active:
		status_label.text = "Placement mode — tap a clear plot beside a road. Cancel with X."
	else:
		status_label.text = ""

func _on_roads_pressed() -> void:
	BuildManager.cancel_placement()
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
	if road_system:
		road_system.set_road_mode(true)
		status_label.text = "Road mode — tap the ground (50 §)"

func _on_residential_pressed() -> void:
	BuildManager.select_building("residential_1")

func _on_commercial_pressed() -> void:
	BuildManager.select_building("building_supplies")

func _on_industrial_pressed() -> void:
	BuildManager.select_building("industrial_1")

func _on_services_pressed() -> void:
	if BuildManager.selected_building_type == "power_wind":
		BuildManager.select_building("water_tower")
	else:
		BuildManager.select_building("power_wind")
	status_label.text = "Utility selected. Tap the utility icon again to switch between power and water."

func _on_storage_pressed() -> void:
	BuildManager.cancel_placement()
	var items = StorageManager.get_all_items()
	if items.is_empty():
		status_label.text = "Storage is empty."
	else:
		var inventory_text = "📦 "
		for item_id in items:
			inventory_text += str(item_id) + "×" + str(items[item_id]) + "  "
		status_label.text = inventory_text

func _on_trade_pressed() -> void:
	BuildManager.cancel_placement()
	var orders = TradeManager.get_orders()
	status_label.text = "Trade — %d active orders." % orders.size()

func _on_cancel_pressed() -> void:
	BuildManager.cancel_placement()
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
	if road_system:
		road_system.set_road_mode(false)
	status_label.text = "Cancelled."
