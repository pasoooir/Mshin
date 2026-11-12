extends Node

signal city_needs_changed(snapshot: Dictionary)

var _refresh_queued := false
var _last_snapshot: Dictionary = {}

func _ready() -> void:
	if not StorageManager.storage_changed.is_connected(_queue_refresh):
		StorageManager.storage_changed.connect(_queue_refresh)
	if not BuildManager.building_placed.is_connected(_on_building_placed):
		BuildManager.building_placed.connect(_on_building_placed)
	if not BuildManager.building_removed.is_connected(_on_building_removed):
		BuildManager.building_removed.connect(_on_building_removed)
	if not BuildManager.construction_finished.is_connected(_on_construction_finished):
		BuildManager.construction_finished.connect(_on_construction_finished)
	if not GameManager.level_changed.is_connected(_queue_refresh):
		GameManager.level_changed.connect(_queue_refresh)
	if not GameManager.population_changed.is_connected(_queue_refresh):
		GameManager.population_changed.connect(_queue_refresh)
	if not GameManager.xp_changed.is_connected(_on_xp_changed):
		GameManager.xp_changed.connect(_on_xp_changed)
	if not GameManager.happiness_changed.is_connected(_queue_refresh):
		GameManager.happiness_changed.connect(_queue_refresh)
	if not EconomyManager.simoleons_changed.is_connected(_queue_refresh):
		EconomyManager.simoleons_changed.connect(_queue_refresh)
	if not EconomyManager.keys_changed.is_connected(_queue_refresh):
		EconomyManager.keys_changed.connect(_queue_refresh)
	_queue_refresh()

func _on_building_placed(data: Dictionary) -> void:
	var node: Variant = BuildManager.buildings.get(str(data.get("id", "")))
	if is_instance_valid(node):
		_connect_building(node)
	_queue_refresh()

func _on_building_removed(_building_id: String) -> void:
	_queue_refresh()

func _on_construction_finished(building_id: String) -> void:
	var building = BuildManager.buildings.get(building_id)
	if is_instance_valid(building):
		_connect_building(building)
	_queue_refresh()

func _connect_building(building: Node) -> void:
	if not is_instance_valid(building):
		return
	var component = building.get("production_component")
	if is_instance_valid(component) and component.has_signal("slots_changed"):
		if not component.slots_changed.is_connected(_queue_refresh):
			component.slots_changed.connect(_queue_refresh)
	if building.has_signal("upgraded") and not building.upgraded.is_connected(_on_home_upgraded):
		building.upgraded.connect(_on_home_upgraded)

func _on_home_upgraded(_stage: int) -> void:
	_queue_refresh()

func _on_xp_changed(_experience: int, _needed: int) -> void:
	_queue_refresh()

func _queue_refresh(_unused = null) -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_publish_snapshot")

func _publish_snapshot() -> void:
	_refresh_queued = false
	var snapshot := get_city_snapshot()
	_last_snapshot = snapshot
	city_needs_changed.emit(snapshot)

func get_last_snapshot() -> Dictionary:
	if _last_snapshot.is_empty():
		_last_snapshot = get_city_snapshot()
	return _last_snapshot.duplicate(true)

func _item_definition(item_id: String) -> Dictionary:
	if ProductionManager.raw_materials.has(item_id):
		return ProductionManager.raw_materials[item_id]
	if ProductionManager.crafted_items.has(item_id):
		return ProductionManager.crafted_items[item_id]
	return StorageManager.item_definitions.get(item_id, {})

func _item_name(item_id: String) -> String:
	return str(_item_definition(item_id).get("name", item_id.capitalize()))

func _supplier_for(item_id: String) -> Array:
	var result: Array = []
	if ProductionManager.raw_materials.has(item_id):
		for building in BuildManager.buildings.values():
			if not is_instance_valid(building):
				continue
			if str(building.definition.get("category", "")) == "industrial" and ProductionManager.get_factory_material_ids(building.building_type).has(item_id):
				result.append({"building_id":building.building_id,"building_type":building.building_type,"name":str(building.definition.get("name","Factory")),"status":"available" if building.status == "completed" else "constructing"})
	else:
		var recipe := ProductionManager.get_recipe(item_id)
		var shop_id := str(recipe.get("store", "")) if not recipe.is_empty() else ProductionManager.get_catalog_supplier_id(item_id)
		for building in BuildManager.buildings.values():
			if not is_instance_valid(building):
				continue
			if str(building.definition.get("category", "")) == "commercial" and str(building.definition.get("shop_id", "building_supplies" if building.building_type == "shop_chain" else building.building_type)) == shop_id and ProductionManager.get_store_catalog_ids(shop_id).has(item_id):
				var catalog_only := not ProductionManager.get_store_recipe_ids(shop_id).has(item_id)
				var supplier_status := "catalog_only" if catalog_only and building.status == "completed" else ("available" if building.status == "completed" else "constructing")
				result.append({"building_id":building.building_id,"building_type":building.building_type,"name":str(building.definition.get("name","Store")),"status":supplier_status})
	if result.is_empty():
		var target_type := "factory_small" if ProductionManager.raw_materials.has(item_id) else str(ProductionManager.get_recipe(item_id).get("store", ""))
		if target_type == "shop_chain":
			target_type = "building_supplies"
		if target_type.is_empty():
			target_type = ProductionManager.get_catalog_supplier_id(item_id)
		var definition: Dictionary = BuildManager.building_types.get(target_type, {})
		if definition.is_empty() and ProductionManager.raw_materials.has(item_id):
			target_type = "factory_small"
			definition = BuildManager.building_types.get(target_type, {})
		if not definition.is_empty():
			result.append({
				"building_id":"",
				"building_type":target_type,
				"name":str(definition.get("name", "Supplier")),
				"status":"not_built"
			})
	return result

func _production_totals() -> Dictionary:
	var totals := {}
	var orders: Array = []
	var now := int(Time.get_unix_time_from_system())
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or building.status != "completed":
			continue
		var component = building.get("production_component")
		if not is_instance_valid(component):
			continue
		component.refresh_slots()
		for index in range(component.get_slot_count()):
			var slot: Dictionary = component.get_slot(index)
			if slot.is_empty():
				continue
			var item_id := str(slot.get("item_id", ""))
			if item_id.is_empty():
				continue
			if not totals.has(item_id):
				totals[item_id] = {"producing":0,"ready":0,"next_finish":0}
			var ready := bool(slot.get("ready", false))
			if ready:
				totals[item_id].ready += 1
			else:
				totals[item_id].producing += 1
				var finish := int(slot.get("finish_unix", now))
				if int(totals[item_id].next_finish) == 0 or finish < int(totals[item_id].next_finish):
					totals[item_id].next_finish = finish
			orders.append({
				"building_id":building.building_id,
				"building_name":str(building.definition.get("name","Production")),
				"item_id":item_id,
				"item_name":_item_name(item_id),
				"ready":ready,
				"remaining":maxi(0, int(slot.get("finish_unix", now)) - now),
				"slot":index
			})
	return {"totals":totals,"orders":orders}

func get_city_snapshot() -> Dictionary:
	var production := _production_totals()
	var required := {}
	var remaining_stored := StorageManager.get_all_items()
	var remaining_ready := {}
	var remaining_producing := {}
	for item_id in production.totals:
		remaining_ready[item_id] = int(production.totals[item_id].get("ready", 0))
		remaining_producing[item_id] = int(production.totals[item_id].get("producing", 0))
	var homes: Array = []
	var ready_homes := 0
	var waiting_homes := 0
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or building.status != "completed":
			continue
		if str(building.definition.get("category", "")) != "residential":
			continue
		var stage := int(building.upgrade_stage)
		var requirements: Array = ProductionManager.get_upgrade_requirements(stage)
		var home_needs: Array = []
		var all_stored := true
		for requirement in requirements:
			var item_id := str(requirement.get("item", ""))
			var amount := int(requirement.get("amount", 0))
			if item_id.is_empty() or amount <= 0:
				continue
			required[item_id] = int(required.get(item_id, 0)) + amount
			# Allocate each unit of inventory only once across all homes. This avoids
			# showing the same stored Nail as available to several upgrade plans.
			var stored_available := int(remaining_stored.get(item_id, 0))
			var stored_allocated := mini(stored_available, amount)
			remaining_stored[item_id] = stored_available - stored_allocated
			var still_needed := amount - stored_allocated
			var ready_available := int(remaining_ready.get(item_id, 0))
			var ready_allocated := mini(ready_available, still_needed)
			remaining_ready[item_id] = ready_available - ready_allocated
			still_needed -= ready_allocated
			var producing_available := int(remaining_producing.get(item_id, 0))
			var producing_allocated := mini(producing_available, still_needed)
			remaining_producing[item_id] = producing_available - producing_allocated
			still_needed -= producing_allocated
			if stored_allocated < amount:
				all_stored = false
			home_needs.append({
				"item_id":item_id,
				"name":_item_name(item_id),
				"required":amount,
				"stored":stored_allocated,
				"ready_to_collect":ready_allocated,
				"in_production":producing_allocated,
				"shortage":still_needed,
				"suppliers":_supplier_for(item_id)
			})
		var can_upgrade := stage < 6 and all_stored
		if stage < 6 and can_upgrade:
			ready_homes += 1
		elif stage < 6:
			waiting_homes += 1
		homes.append({
			"building_id":building.building_id,
			"name":str(building.definition.get("name","Residential")),
			"stage":stage,
			"next_stage":mini(stage + 1, 6),
			"population":int(building.current_population),
			"ready":can_upgrade,
			"needs":home_needs
		})
	var item_rows: Array = []
	var critical_count := 0
	for item_variant in required.keys():
		var item_id := str(item_variant)
		var stored := StorageManager.get_count(item_id)
		var demand := int(required[item_id])
		var active: Dictionary = production.totals.get(item_id, {})
		var producing := int(active.get("producing", 0))
		var ready := int(active.get("ready", 0))
		var deficit := maxi(0, demand - stored - producing - ready)
		var suppliers := _supplier_for(item_id)
		var status := "covered"
		if deficit > 0:
			critical_count += 1
			status = "no_supplier" if suppliers.is_empty() else "shortage"
		elif ready > 0:
			status = "ready_to_collect"
		elif producing > 0:
			status = "in_production"
		var finish := int(active.get("next_finish", 0))
		item_rows.append({
			"item_id":item_id,
			"name":_item_name(item_id),
			"stored":stored,
			"required":demand,
			"producing":producing,
			"ready":ready,
			"deficit":deficit,
			"suppliers":suppliers,
			"status":status,
			"eta_seconds":maxi(0, finish - int(Time.get_unix_time_from_system())) if finish > 0 else -1
		})
	item_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.deficit) != int(b.deficit):
			return int(a.deficit) > int(b.deficit)
		return str(a.name) < str(b.name)
	)
	return {
		"storage":{"used":StorageManager.get_used(),"capacity":StorageManager.capacity,"free":StorageManager.get_free()},
		"economy":{"simoleons":EconomyManager.simoleons,"sim_cash":EconomyManager.sim_cash,"keys":EconomyManager.golden_keys},
		"city":{"level":GameManager.level,"population":GameManager.population,"happiness":GameManager.happiness,"experience":GameManager.experience,"xp_needed":GameManager.get_xp_needed()},
		"summary":{"homes":homes.size(),"ready_homes":ready_homes,"waiting_homes":waiting_homes,"critical_items":critical_count,"active_orders":production.orders.size(),"ready_orders":production.orders.filter(func(order: Dictionary) -> bool: return bool(order.ready)).size()},
		"items":item_rows,
		"homes":homes,
		"orders":production.orders
	}

func get_item_name(item_id: String) -> String:
	return _item_name(item_id)

func get_suppliers_for_item(item_id: String) -> Array:
	return _supplier_for(item_id)
