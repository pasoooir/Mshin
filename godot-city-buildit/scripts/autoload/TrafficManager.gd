extends Node

signal traffic_changed(demand: int, capacity: int, congestion_ratio: float)

# One traffic unit represents a planning allowance for approximately 50
# residents. Road capacity is derived directly from lane count: 2/4/6/8.
# These are Mshin simulation units, not an EA-published vehicle count.
const RESIDENTS_PER_TRAFFIC_UNIT: int = 50
const TRAFFIC_UNITS_PER_LANE: int = 1
const VEHICLE_SPAWN_INTERVAL: float = 4.0
const VEHICLE_SPEED: float = 10.0
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
var _active_vehicle: TrafficVehicle

func _ready() -> void:
	print("[TrafficManager] Road-tier capacity and Gateway vehicle loop online")

func _process(delta: float) -> void:
	if not vehicle_simulation_enabled or is_instance_valid(_active_vehicle):
		return
	_spawn_elapsed += delta
	if _spawn_elapsed >= VEHICLE_SPAWN_INTERVAL:
		_spawn_elapsed = 0.0
		spawn_vehicle_now()

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
	if traffic_demand <= 0:
		congestion_ratio = 0.0
	elif road_capacity <= 0:
		congestion_ratio = 2.0
	else:
		congestion_ratio = float(traffic_demand) / float(road_capacity)
	_validate_active_vehicle_route(connected_roads)
	traffic_changed.emit(traffic_demand, road_capacity, congestion_ratio)

func build_gateway_round_trip_route() -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	var road_system = _get_road_system()
	if not road_system:
		return route
	var connected_roads: Dictionary = road_system.get_gateway_connected_roads()
	var start: Vector2i = road_system.GATEWAY_ROAD_CELL
	if not connected_roads.has(start):
		return route

	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var farthest: Vector2i = start
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
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

	route = outbound.duplicate()
	for index in range(outbound.size() - 2, -1, -1):
		route.append(outbound[index])
	return route

func spawn_vehicle_now() -> TrafficVehicle:
	if is_instance_valid(_active_vehicle):
		return _active_vehicle
	var route := build_gateway_round_trip_route()
	if route.size() < 2:
		return null
	var world := _get_world_parent()
	if not world:
		return null
	var vehicle := TrafficVehicle.new()
	vehicle.route = route
	vehicle.speed = VEHICLE_SPEED
	vehicle.route_completed.connect(_on_vehicle_route_completed)
	world.add_child(vehicle)
	_active_vehicle = vehicle
	return vehicle

func clear_active_vehicle() -> void:
	if is_instance_valid(_active_vehicle):
		_active_vehicle.queue_free()
	_active_vehicle = null

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

func _validate_active_vehicle_route(connected_roads: Dictionary) -> void:
	if not is_instance_valid(_active_vehicle):
		_active_vehicle = null
		return
	for cell in _active_vehicle.route:
		if not connected_roads.has(cell):
			_active_vehicle.queue_free()
			_active_vehicle = null
			return

func _on_vehicle_route_completed() -> void:
	_active_vehicle = null
	_spawn_elapsed = 0.0
