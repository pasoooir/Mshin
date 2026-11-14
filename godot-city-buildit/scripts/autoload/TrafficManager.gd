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
const MAX_TRAFFIC_STOP_SECONDS: float = 4.0
const CONGESTION_CRAWL_SPEED: float = 1.0
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
var _junction_reservations: Dictionary = {}
var _active_vehicle: TrafficVehicle
var _station_dispatch_elapsed: Dictionary = {}
var _route_destination_cursor: int = 0

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
	var active_ids: Dictionary = {}
	for vehicle in _active_vehicles:
		active_ids[vehicle.get_instance_id()] = true
	for junction_cell in _junction_reservations.keys():
		if not active_ids.has(int(_junction_reservations[junction_cell])):
			_junction_reservations.erase(junction_cell)
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
	if vehicle_kind == "highway" and (from_cell.x == HIGHWAY_GRID_X or to_cell.x == HIGHWAY_GRID_X):
		return VEHICLE_BASE_SPEED * HIGHWAY_SPEED_MULTIPLIER
	return VEHICLE_BASE_SPEED * CITY_SPEED_MULTIPLIER

func is_frontmost_vehicle_in_lane(vehicle: TrafficVehicle) -> bool:
	if not is_instance_valid(vehicle):
		return false
	for other in _active_vehicles:
		if not is_instance_valid(other) or other == vehicle:
			continue
		if other.route_key != vehicle.route_key or other.lane_direction != vehicle.lane_direction or other.lane_index != vehicle.lane_index:
			continue
		if other.route_distance - vehicle.route_distance > 0.0:
			return false
	return true

func is_junction_cell(grid_cell: Vector2i) -> bool:
	var road_system = _get_road_system()
	if not road_system or not road_system.has_road(grid_cell):
		return false
	return road_system.get_road_connections(grid_cell).size() >= 3

func request_junction_entry(vehicle: TrafficVehicle, junction_cell: Vector2i) -> bool:
	if not is_instance_valid(vehicle):
		return false
	if not is_junction_cell(junction_cell):
		return true
	var owner_id := int(_junction_reservations.get(junction_cell, 0))
	var vehicle_id := vehicle.get_instance_id()
	if owner_id == 0 or owner_id == vehicle_id:
		_junction_reservations[junction_cell] = vehicle_id
		return true
	return false

func release_junction_entry(vehicle: TrafficVehicle, junction_cell: Vector2i) -> void:
	if not is_instance_valid(vehicle):
		return
	if int(_junction_reservations.get(junction_cell, 0)) == vehicle.get_instance_id():
		_junction_reservations.erase(junction_cell)

func release_all_junction_entries(vehicle: TrafficVehicle) -> void:
	if not is_instance_valid(vehicle):
		return
	var vehicle_id := vehicle.get_instance_id()
	for junction_cell in _junction_reservations.keys():
		if int(_junction_reservations[junction_cell]) == vehicle_id:
			_junction_reservations.erase(junction_cell)

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
	# A frontmost vehicle that has waited four seconds may claim the blocked
	# movement at crawl speed; following vehicles never bypass their leader.
	if vehicle.congestion_release_active:
		return CONGESTION_CRAWL_SPEED
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

func get_road_cell_vehicle_load(grid_cell: Vector2i) -> int:
	var load := 0
	for vehicle in _active_vehicles:
		if not is_instance_valid(vehicle) or vehicle.vehicle_kind == "highway":
			continue
		if vehicle.route.is_empty():
			continue
		var segment_index := clampi(int(vehicle.get("_segment_index")), 0, vehicle.route.size() - 1)
		if vehicle.route[segment_index] == grid_cell:
			load += 1
		elif segment_index + 1 < vehicle.route.size() and vehicle.route[segment_index + 1] == grid_cell:
			load += 1
	return load

func get_road_cell_travel_cost(grid_cell: Vector2i) -> float:
	var road_system = _get_road_system()
	if not road_system or not road_system.has_road(grid_cell):
		return INF
	var road_level: int = int(road_system.get_road_level(grid_cell))
	var capacity_discount := 1.0 / (1.0 + 0.18 * float(maxi(0, road_level - 1)))
	var congestion_penalty := float(get_road_cell_vehicle_load(grid_cell)) * 2.0
	var junction_penalty := 0.25 if is_junction_cell(grid_cell) else 0.0
	return capacity_discount + congestion_penalty + junction_penalty

func build_route_between(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var road_system = _get_road_system()
	if not road_system:
		return []
	var connected_roads: Dictionary = road_system.get_gateway_connected_roads()
	return _build_low_cost_route(start, goal, connected_roads)

func _build_low_cost_route(start: Vector2i, goal: Vector2i, connected_roads: Dictionary) -> Array[Vector2i]:
	if not connected_roads.has(start) or not connected_roads.has(goal):
		return []
	var distances: Dictionary = {start: 0.0}
	var parents: Dictionary = {start: start}
	var open_cells: Array[Vector2i] = [start]
	var visited: Dictionary = {}
	while not open_cells.is_empty():
		var best_index := 0
		var best_cost := INF
		for index in range(open_cells.size()):
			var candidate: Vector2i = open_cells[index]
			var candidate_cost := float(distances.get(candidate, INF))
			if candidate_cost < best_cost:
				best_cost = candidate_cost
				best_index = index
		var current: Vector2i = open_cells.pop_at(best_index)
		if visited.has(current):
			continue
		visited[current] = true
		if current == goal:
			break
		for direction in CARDINAL_DIRECTIONS:
			var neighbour: Vector2i = current + direction
			if not connected_roads.has(neighbour) or visited.has(neighbour):
				continue
			var next_cost := best_cost + get_road_cell_travel_cost(neighbour)
			if next_cost < float(distances.get(neighbour, INF)):
				distances[neighbour] = next_cost
				parents[neighbour] = current
				if not open_cells.has(neighbour):
					open_cells.append(neighbour)
	if not parents.has(goal):
		return []
	var route: Array[Vector2i] = []
	var cursor := goal
	while cursor != start:
		route.push_front(cursor)
		if not parents.has(cursor):
			return []
		cursor = parents[cursor]
	route.push_front(start)
	return route

func _build_round_trip_route_from(start: Vector2i) -> Array[Vector2i]:
	var road_system = _get_road_system()
	if not road_system:
		return []
	var connected_roads: Dictionary = road_system.get_gateway_connected_roads()
	if not connected_roads.has(start):
		return []
	var queue: Array[Vector2i] = [start]
	var hop_distances: Dictionary = {start: 0}
	var cursor_index := 0
	var farthest_hops := 0
	var farthest_cells: Array[Vector2i] = []
	while cursor_index < queue.size():
		var current: Vector2i = queue[cursor_index]
		cursor_index += 1
		var current_hops := int(hop_distances[current])
		if current_hops > farthest_hops:
			farthest_hops = current_hops
			farthest_cells.clear()
		if current_hops == farthest_hops and current != start:
			farthest_cells.append(current)
		for direction in CARDINAL_DIRECTIONS:
			var neighbour: Vector2i = current + direction
			if connected_roads.has(neighbour) and not hop_distances.has(neighbour):
				hop_distances[neighbour] = current_hops + 1
				queue.append(neighbour)
	if farthest_cells.is_empty():
		return []
	var destination_index := posmod(_route_destination_cursor, farthest_cells.size())
	_route_destination_cursor += 1
	var destination: Vector2i = farthest_cells[destination_index]
	var outbound := _build_low_cost_route(start, destination, connected_roads)
	if outbound.size() < 2:
		return []
	var round_trip: Array[Vector2i] = outbound.duplicate()
	for index in range(outbound.size() - 2, -1, -1):
		round_trip.append(outbound[index])
	return round_trip
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

func build_highway_city_round_trip_route(northbound: bool) -> Array[Vector2i]:
	var road_system = _get_road_system()
	if not road_system:
		return []
	var city_route := build_gateway_round_trip_route()
	if city_route.size() < 2:
		return []
	var entry_z: int = -1
	# _get_road_system() is dynamically typed; explicitly type the constant
	# before using it in Vector2i arithmetic and range bounds.
	var gateway: Vector2i = Vector2i(road_system.GATEWAY_ROAD_CELL)
	var route: Array[Vector2i] = []
	var outer_z := HIGHWAY_MAX_GRID_Z if northbound else HIGHWAY_MIN_GRID_Z
	var step := -1 if northbound else 1
	for z in range(outer_z, entry_z + step, step):
		route.append(Vector2i(HIGHWAY_GRID_X, z))
	for x in range(HIGHWAY_GRID_X + 1, gateway.x + 1):
		route.append(Vector2i(x, entry_z))
	for index in range(1, city_route.size()):
		route.append(city_route[index])
	for x in range(gateway.x - 1, HIGHWAY_GRID_X - 1, -1):
		route.append(Vector2i(x, entry_z))
	var return_step := 1 if northbound else -1
	for z in range(entry_z + return_step, outer_z + return_step, return_step):
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
	var route := build_highway_city_round_trip_route(northbound)
	if route.size() < 2:
		return null
	var vehicle := TrafficVehicle.new()
	vehicle.route = route
	vehicle.vehicle_kind = "highway"
	vehicle.ground_height = 0.15
	vehicle.speed = VEHICLE_BASE_SPEED
	vehicle.route_key = "coastal-highway-city-northbound" if northbound else "coastal-highway-city-southbound"
	vehicle.lane_index = _highway_lane_cursor % HIGHWAY_LANE_OFFSETS.size()
	vehicle.lane_offset = LANE_CENTER_OFFSET
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
	vehicle.route_distance = -vehicle.initial_position.distance_to(vehicle._lane_position(route[0], route[1] - route[0]))
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
	_junction_reservations.clear()
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
