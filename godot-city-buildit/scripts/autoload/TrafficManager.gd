extends Node

signal traffic_changed(demand: int, capacity: int, congestion_ratio: float)

# One traffic unit represents a planning allowance for approximately 50
# residents. Road capacity is derived directly from lane count: 2/4/6/8.
# These are Mshin simulation units, not an EA-published vehicle count.
const RESIDENTS_PER_TRAFFIC_UNIT: int = 50
const TRAFFIC_UNITS_PER_LANE: int = 1

var traffic_demand: int = 0
var road_capacity: int = 0
var congestion_ratio: float = 0.0

func _ready() -> void:
	print("[TrafficManager] Road-tier capacity model online")

func recalculate_from_roads() -> void:
	traffic_demand = ceili(float(maxi(0, GameManager.population)) / float(RESIDENTS_PER_TRAFFIC_UNIT))
	road_capacity = 0
	var scene := get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	if road_system:
		var connected_roads: Dictionary = road_system.get_gateway_connected_roads()
		for cell in connected_roads.keys():
			var lane_count := road_system.get_road_level(cell) * 2
			road_capacity += lane_count * TRAFFIC_UNITS_PER_LANE
	if traffic_demand <= 0:
		congestion_ratio = 0.0
	elif road_capacity <= 0:
		congestion_ratio = 2.0
	else:
		congestion_ratio = float(traffic_demand) / float(road_capacity)
	traffic_changed.emit(traffic_demand, road_capacity, congestion_ratio)

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
