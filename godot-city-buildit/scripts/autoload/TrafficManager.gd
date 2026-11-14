extends Node

signal traffic_changed(demand: int, capacity: int, congestion_ratio: float)
signal fleet_changed(public_count: int, emergency_count: int)

# World scale is 1 unit = 1 metre. A calibrated base of 2.083333 m/s yields
# conservative 30 km/h city (4x) and 120 km/h motorway (16x) speed ceilings.
const RESIDENTS_PER_TRAFFIC_UNIT: int = 50
const TRAFFIC_UNITS_PER_LANE: int = 1
const VEHICLE_BASE_SPEED: float = 2.0833333333
const CITY_SPEED_MULTIPLIER: float = 4.0
const CITY_SPEED_LIMIT_KMH: float = 30.0
const HIGHWAY_SPEED_MULTIPLIER: float = 16.0
const HIGHWAY_SPEED_LIMIT_KMH: float = 120.0
const PUBLIC_SPAWN_INTERVAL: float = 2.0
const HIGHWAY_SPAWN_INTERVAL: float = 1.5
const HIGHWAY_WORLD_X: float = -55.0
const HIGHWAY_GRID_X: int = -28
const HIGHWAY_MIN_GRID_Z: int = -44
const HIGHWAY_MAX_GRID_Z: int = 44
const HIGHWAY_LANE_OFFSETS: Array[float] = [9.1, 5.8, 2.5]
const MAX_HIGHWAY_VEHICLES: int = 12
const EMERGENCY_SPAWN_INTERVAL: float = 12.0
const MAX_PUBLIC_VEHICLES: int = 18
const MAX_EMERGENCY_VEHICLES: int = 8
const MIN_FOLLOWING_GAP: float = 2.25
const SAFE_FOLLOWING_GAP: float = 5.5
const LANE_CENTER_OFFSET: float = 0.32
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var traffic_demand: int = 0
var road_capacity: int = 0
var congestion_ratio: float = 0.0
var vehicle_simulation_enabled: bool = true

var _spawn_elapsed: float = 0.0
var _highway_spawn_elapsed: float = 0.0
var _highway_lane_cursor: int = 0
var _highway_direction_cursor: int = 0
var _emergency_elapsed: float = 0.0
var _active_vehicles: Array[TrafficVehicle] = []
var _active_vehicle: TrafficVehicle
var _station_dispatch_elapsed: Dictionary = {}

func _ready() -> void:
	print("[TrafficManager] Right-hand traffic, multi-vehicle flow and emergency fleets online")

func _process(delta: float) -> void:
	_prune_vehicle_list()
	if not vehicle_simulation_enabled:
		return
	_spawn_elapsed += delta
	if _spawn_elapsed >= PUBLIC_SPAWN_INTERVAL:
		_spawn_elapsed = 0.0
		if _active_city_vehicle_count() < _get_public_vehicle_limit():
			spawn_vehicle_now()
	_highway_spawn_elapsed += delta
	if _highway_spawn_elapsed >= HIGHWAY_SPAWN_INTERVAL:
		_highway_spawn_elapsed = 0.0
		if _active_highway_vehicle_count() < MAX_HIGHWAY_VEHICLES:
			spawn_highway_vehicle_now()
	_update_emergency_dispatch(delta)
	fleet_changed.emit(_active_public_vehicle_count(), _active_emergency_vehicle_count())

func _prune_vehicle_list() -> void:
	var valid: Array[TrafficVehicle] = []
	for vehicle in _active_vehicles:
		if is_instance_valid(vehicle) and not vehicle.is_queued_for_deletion():
			valid.append(vehicle)
	_active_vehicles = valid
	_active_vehicle = null
	for vehicle in _active_vehicles:
		if vehicle.vehicle_kind == "civilian":
			_active_vehicle = vehicle
			break

func _active_public_vehicle_count() -> int:
	return _active_city_vehicle_count() + _active_highway_vehicle_count()

func _active_city_vehicle_count() -> int:
	var count := 0
	for vehicle in _active_vehicles:
		if is_instance_valid(vehicle) and vehicle.vehicle_kind == "civilian":
			count += 1
	return count

func _active_highway_vehicle_count() -> int:
	var count := 0
	for vehicle in _active_vehicles:
		if is_instance_valid(vehicle) and vehicle.vehicle_kind == "highway":
			count += 1
	return count

func _active_emergency_vehicle_count() -> int:
	var count := 0
	for vehicle in _active_vehicles:
		if is_instance_valid(vehicle) and vehicle.vehicle_kind in ["police", "fire"]:
			count += 1
	return count

func _get_public_vehicle_limit() -> int:
	return clampi(4 + int(road_capacity / 10), 4, MAX_PUBLIC_VEHICLES)

func get_speed_multiplier_for_cell(_cell: Vector2i, vehicle_kind: String = "civilian") -> float:
	return HIGHWAY_SPEED_MULTIPLIER if vehicle_kind == "highway" else CITY_SPEED_MULTIPLIER

func get_speed_for_segment(from_cell: Vector2i, to_cell: Vector2i, vehicle_kind: String = "civilian") -> float:
	if vehicle_kind == "highway" and from_cell.x == HIGHWAY_GRID_X and to_cell.x == HIGHWAY_GRID_X:
		return VEHICLE_BASE_SPEED * HIGHWAY_SPEED_MULTIPLIER
	return VEHICLE_BASE_SPEED * CITY_SPEED_MULTIPLIER

func get_safe_vehicle_speed(vehicle: TrafficVehicle, desired_speed: float) -> float:
	if not is_instance_valid(vehicle):
		return 0.0
	var nearest_gap := INF
	for other in _active_vehicles:
		if not is_instance_valid(other) or other == vehicle:
			continue
		if other.route_key != vehicle.route_key or other.lane_direction != vehicle.lane_direction or other.lane_index != vehicle.lane_index:
			continue
		var gap := other.route_distance - vehicle.route_distance
		if gap > 0.0 and gap < nearest_gap:
			nearest_gap = gap
	if nearest_gap <= MIN_FOLLOWING_GAP:
		return 0.0
	if nearest_gap < SAFE_FOLLOWING_GAP:
		return desired_speed * clampf((nearest_gap - MIN_FOLLOWING_GAP) / (SAFE_FOLLOWING_GAP - MIN_FOLLOWING_GAP), 0.0, 1.0)
	# Also protect junctions and intersecting routes from overlapping vehicle bodies.
	var forward := Vector3(float(vehicle.lane_direction.x), 0.0, float(vehicle.lane_direction.y))
	for other in _active_vehicles:
		if not is_instance_valid(other) or other == vehicle:
			continue
		var offset := other.global_position - vehicle.global_position
		var ahead := offset.dot(forward)
		if ahead > 0.0 and ahead < 1.8 and Vector2(offset.x, offset.z).length() < 1.8:
			return 0.0
	return desired_speed

func recalculate_from_roads() -> void:
	traffic_demand = ceili(float(maxi(0, GameManager.population)) / float(RESIDENTS_PER_TRAFFIC_UNIT))
	road_capacity = 0
	var road_system = _get_road_system()
	var connected_roads: Dictionary = {}
	if road_system:
		connected_roads = road_system.get_gateway_connected_roads()
		for cell in connected_roads.keys():
			var road_cell: Vector2i = cell
			var lane_count: int = road_system.get_road_level(road_cell) * 2
			road_capacity += lane_count * TRAFFIC_UNITS_PER_LANE
	_validate_active_vehicle_routes(connected_roads)
	if traffic_demand <= 0:
		congestion_ratio = 0.0
	elif road_capacity <= 0:
		congestion_ratio = 2.0
	else:
		congestion_ratio = float(traffic_demand) / float(road_capacity)
	traffic_changed.emit(traffic_demand, road_capacity, congestion_ratio)

func build_gateway_round_trip_route() -> Array[Vector2i]:
	var road_system = _get_road_system()
	if not road_system:
		return []
	return _build_round_trip_route_from(road_system.GATEWAY_ROAD_CELL)

func _build_round_trip_route_from(start: Vector2i) -> Array[Vector2i]:
	var road_system = _get_road_system()
	if not road_system:
		return []
	var connected_roads: Dictionary = road_system.get_gateway_connected_roads()
	if not connected_roads.has(start):
		return []
	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var farthest: Vector2i = start
	var cursor_index := 0
	while cursor_index < queue.size():
		var current: Vector2i = queue[cursor_index]
		cursor_index += 1
		farthest = current
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if connected_roads.has(neighbor) and not parents.has(neighbor):
				parents[neighbor] = current
				queue.append(neighbor)
	var outbound: Array[Vector2i] = []
	var cursor: Vector2i = farthest
	while cursor != start:
		outbound.push_front(cursor)
		if not parents.has(cursor):
			return []
		cursor = parents[cursor]
	outbound.push_front(start)
	if outbound.size() < 2:
		return []
	var route: Array[Vector2i] = outbound.duplicate()
	for index in range(outbound.size() - 2, -1, -1):
		route.append(outbound[index])
	return route

func _get_station_access_road(station: Node3D) -> Vector2i:
	var road_system = _get_road_system()
	if not road_system or not is_instance_valid(station):
		return Vector2i(2147483647, 2147483647)
	var definition: Dictionary = station.get("definition")
	var anchor: Vector2i = station.get("grid_pos")
	var size: Vector2i = definition.get("size", Vector2i.ONE)
	var candidates: Array[Vector2i] = []
	for x in range(size.x):
		candidates.append(anchor + Vector2i(x, -1))
		candidates.append(anchor + Vector2i(x, size.y))
	for y in range(size.y):
		candidates.append(anchor + Vector2i(-1, y))
		candidates.append(anchor + Vector2i(size.x, y))
	var best := Vector2i(2147483647, 2147483647)
	var best_distance := INF
	for cell in candidates:
		if not road_system.is_road_connected_to_gateway(cell):
			continue
		var distance := BuildManager.grid_to_world(cell).distance_squared_to(station.global_position)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best

func build_station_patrol_route(station: Node3D) -> Array[Vector2i]:
	if not is_instance_valid(station) or str(station.get("status")) != "completed":
		return []
	var definition: Dictionary = station.get("definition")
	if str(definition.get("service_group", "")) not in ["police", "fire"]:
		return []
	var start := _get_station_access_road(station)
	if start.x == 2147483647:
		return []
	return _build_round_trip_route_from(start)

func _station_exit_position(station: Node3D, road_cell: Vector2i) -> Vector3:
	var road_position := BuildManager.grid_to_world(road_cell)
	var direction := Vector3(road_position.x - station.global_position.x, 0.0, road_position.z - station.global_position.z)
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var definition: Dictionary = station.get("definition")
	var size: Vector2i = definition.get("size", Vector2i.ONE)
	var half_width := float(size.x) * BuildManager.GRID_SIZE * 0.5
	var half_depth := float(size.y) * BuildManager.GRID_SIZE * 0.5
	var x_edge_distance := half_width / absf(direction.x) if absf(direction.x) > 0.001 else INF
	var z_edge_distance := half_depth / absf(direction.z) if absf(direction.z) > 0.001 else INF
	var edge_distance := minf(x_edge_distance, z_edge_distance)
	return station.global_position + direction * (edge_distance + 0.15) + Vector3.UP * 0.05

func spawn_vehicle_now() -> TrafficVehicle:
	if _active_city_vehicle_count() >= _get_public_vehicle_limit():
		return null
	var route := build_gateway_round_trip_route()
	if route.size() < 2:
		return null
	var world := _get_world_parent()
	if not world:
		return null
	var vehicle := TrafficVehicle.new()
	vehicle.route = route
	vehicle.vehicle_kind = "civilian"
	vehicle.lane_offset = LANE_CENTER_OFFSET
	vehicle.speed = VEHICLE_BASE_SPEED
	vehicle.route_key = _route_key(route)
	vehicle.lane_index = 0
	vehicle.route_completed.connect(_on_vehicle_route_completed)
	world.add_child(vehicle)
	_active_vehicles.append(vehicle)
	_active_vehicle = vehicle
	return vehicle

func build_highway_route(northbound: bool) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	var first_z := HIGHWAY_MAX_GRID_Z if northbound else HIGHWAY_MIN_GRID_Z
	var last_z := HIGHWAY_MIN_GRID_Z if northbound else HIGHWAY_MAX_GRID_Z
	var step := -1 if northbound else 1
	for z in range(first_z, last_z + step, step):
		route.append(Vector2i(HIGHWAY_GRID_X, z))
	return route

func spawn_highway_vehicle_now() -> TrafficVehicle:
	if _active_highway_vehicle_count() >= MAX_HIGHWAY_VEHICLES:
		return null
	var world := _get_world_parent()
	if not world:
		return null
	var northbound := posmod(_highway_direction_cursor, 2) == 0
	_highway_direction_cursor += 1
	var route := build_highway_route(northbound)
	if route.size() < 2:
		return null
	var vehicle := TrafficVehicle.new()
	vehicle.route = route
	vehicle.vehicle_kind = "highway"
	vehicle.ground_height = 0.15
	vehicle.speed = VEHICLE_BASE_SPEED
	vehicle.route_key = "coastal-highway-northbound" if northbound else "coastal-highway-southbound"
	vehicle.lane_index = _highway_lane_cursor % HIGHWAY_LANE_OFFSETS.size()
	vehicle.lane_offset = HIGHWAY_LANE_OFFSETS[vehicle.lane_index]
	_highway_lane_cursor += 1
	vehicle.route_completed.connect(_on_vehicle_route_completed)
	world.add_child(vehicle)
	_active_vehicles.append(vehicle)
	return vehicle

func spawn_emergency_vehicle(station: Node3D) -> TrafficVehicle:
	if not is_instance_valid(station) or _active_emergency_vehicle_count() >= MAX_EMERGENCY_VEHICLES:
		return null
	var definition: Dictionary = station.get("definition")
	var service_group := str(definition.get("service_group", ""))
	var vehicle_kind := "police" if service_group == "police" else "fire"
	var start := _get_station_access_road(station)
	if start.x == 2147483647:
		return null
	var route := _build_round_trip_route_from(start)
	if route.size() < 2:
		return null
	var world := _get_world_parent()
	if not world:
		return null
	var vehicle := TrafficVehicle.new()
	vehicle.route = route
	vehicle.vehicle_kind = vehicle_kind
	vehicle.station_building_id = str(station.get("building_id"))
	vehicle.lane_offset = LANE_CENTER_OFFSET
	vehicle.initial_position = _station_exit_position(station, start)
	vehicle.use_initial_position = true
	vehicle.speed = VEHICLE_BASE_SPEED
	vehicle.route_key = _route_key(route)
	vehicle.route_completed.connect(_on_vehicle_route_completed)
	world.add_child(vehicle)
	_active_vehicles.append(vehicle)
	return vehicle

func _update_emergency_dispatch(delta: float) -> void:
	for station_value in BuildManager.buildings.values():
		var station = station_value as Node3D
		if not is_instance_valid(station) or str(station.get("status")) != "completed":
			continue
		var definition: Dictionary = station.get("definition")
		var service_group := str(definition.get("service_group", ""))
		if service_group not in ["police", "fire"] or not BuildManager.is_building_operational(station):
			continue
		var station_id := str(station.get("building_id"))
		var elapsed := float(_station_dispatch_elapsed.get(station_id, EMERGENCY_SPAWN_INTERVAL)) + delta
		_station_dispatch_elapsed[station_id] = elapsed
		if elapsed >= EMERGENCY_SPAWN_INTERVAL and not _has_active_station_vehicle(station_id):
			if is_instance_valid(spawn_emergency_vehicle(station)):
				_station_dispatch_elapsed[station_id] = 0.0
	for station_id in _station_dispatch_elapsed.keys():
		if not BuildManager.buildings.has(station_id):
			_station_dispatch_elapsed.erase(station_id)

func _has_active_station_vehicle(station_id: String) -> bool:
	for vehicle in _active_vehicles:
		if is_instance_valid(vehicle) and vehicle.station_building_id == station_id:
			return true
	return false

func _route_key(route: Array[Vector2i]) -> String:
	var parts := PackedStringArray()
	for cell in route:
		parts.append("%d,%d" % [cell.x, cell.y])
	return "|".join(parts)

func clear_active_vehicle() -> void:
	for vehicle in _active_vehicles:
		if is_instance_valid(vehicle):
			vehicle.queue_free()
	_active_vehicles.clear()
	_active_vehicle = null
	_spawn_elapsed = 0.0
	_highway_spawn_elapsed = 0.0
	_emergency_elapsed = 0.0

func get_happiness_penalty() -> float:
	if congestion_ratio >= 1.5:
		return -12.0
	if congestion_ratio >= 1.0:
		return -8.0
	if congestion_ratio >= 0.8:
		return -4.0
	return 0.0

func get_congestion_percent() -> int:
	return roundi(clampf(congestion_ratio, 0.0, 2.0) * 100.0)

func _get_road_system():
	var scene := get_tree().current_scene
	return scene.get_node_or_null("World/RoadSystem") if scene else null

func _get_world_parent() -> Node3D:
	var scene := get_tree().current_scene
	if not scene:
		return null
	return scene.get_node_or_null("World") as Node3D

func _validate_active_vehicle_routes(connected_roads: Dictionary) -> void:
	_prune_vehicle_list()
	for vehicle in _active_vehicles.duplicate():
		if vehicle.vehicle_kind == "highway":
			continue
		for cell in vehicle.route:
			if not connected_roads.has(cell):
				vehicle.queue_free()
				_active_vehicles.erase(vehicle)
				break
	_prune_vehicle_list()

func _on_vehicle_route_completed() -> void:
	_prune_vehicle_list()
