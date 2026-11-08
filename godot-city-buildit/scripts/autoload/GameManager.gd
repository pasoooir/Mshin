extends Node

signal level_changed(new_level: int)
signal population_changed(new_pop: int)
signal happiness_changed(new_value: float)
signal xp_changed(xp: int, needed: int)
signal level_up_rewarded(new_level: int, simoleons: int, keys: int)

var level: int = 1
var experience: int = 0
var population: int = 0
var max_population: int = 100
var happiness: float = 100.0
var city_name: String = "Pasoo City"

func _ready() -> void:
	print("[GameManager] ", city_name, " - Level ", level)

func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	experience += amount
	var needed := get_xp_needed()
	while experience >= needed and level < 60:
		experience -= needed
		level += 1
		level_changed.emit(level)
		print("[GameManager] ★ LEVEL UP → ", level)
		if has_node("/root/LevelProgression"):
			LevelProgression.on_level_up(level)
		var reward := level * 100
		EconomyManager.add_simoleons(reward)
		EconomyManager.add_keys(1)
		level_up_rewarded.emit(level, reward, 1)
		needed = get_xp_needed()
	xp_changed.emit(experience, get_xp_needed())

func get_xp_needed() -> int:
	if has_node("/root/LevelProgression"):
		return LevelProgression.get_xp_for_level(level + 1)
	return level * 80

func set_population(value: int) -> void:
	population = clamp(value, 0, 999999)
	population_changed.emit(population)
	if has_node("/root/LevelProgression"):
		LevelProgression.check_population_unlocks(population)

func add_population(amount: int) -> void:
	set_population(population + amount)

func set_happiness(value: float) -> void:
	happiness = clamp(value, 0.0, 100.0)
	happiness_changed.emit(happiness)

func get_happiness_status() -> String:
	if happiness >= 80: return "happy"
	elif happiness >= 50: return "neutral"
	else: return "unhappy"
