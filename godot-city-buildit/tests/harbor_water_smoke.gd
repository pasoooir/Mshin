extends SceneTree

const WorldPresentationScript = preload("res://scripts/world/WorldPresentation.gd")
const PassengerFerryScript = preload("res://scripts/world/CargoShipVisual.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := WorldPresentationScript.new()
	root.add_child(presentation)
	presentation.call("_build_passenger_harbor")
	var harbor := presentation.get_node_or_null("PassengerHarbor")
	if harbor == null or harbor.get_node_or_null("PierDeck") == null or harbor.get_node_or_null("FerryTerminal") == null:
		_fail("The live world must build a pier, gangway and passenger terminal.")
		return

	var world_source := FileAccess.get_file_as_string("res://scripts/world/WorldPresentation.gd")
	for required in [
		"vec3 coastal_teal = vec3(0.035, 0.31, 0.39)",
		"vec3 mediterranean_blue = vec3(0.012, 0.145, 0.335)",
		"vec3 pacific_blue = vec3(0.006, 0.065, 0.205)",
		"wave_normal_x",
		"FerryGangway",
		"PassengerHarbor"
	]:
		if not world_source.contains(required):
			_fail("Pacific water or harbor visual is missing: " + required)
			return

	var ferry := PassengerFerryScript.new()
	root.add_child(ferry)
	ferry.set_process(false)
	if ferry.get_waiting_passenger_count() != 8:
		_fail("The arriving ferry must carry eight visible passengers.")
		return

	# Advance the real ferry state machine deterministically while yielding frames
	# so queue_free/reparent operations are processed by the SceneTree.
	for frame in range(100):
		ferry.call("_process", 0.2)
		await process_frame

	if ferry.get_completed_voyages() < 1:
		_fail("The ferry did not reach its harbor berth.")
		return
	if ferry.get_last_voyage_unloaded_count() != 8:
		_fail("All eight passengers must disembark before the ferry departs.")
		return
	if ferry.get_waiting_passenger_count() != 0 or ferry.get_walking_passenger_count() != 0:
		_fail("Passengers must finish walking from the gangway to the terminal.")
		return

	print("[HarborWaterSmoke] PASS: ocean palette, animated waves, pier, terminal and 8-passenger ferry cycle")
	ferry.queue_free()
	presentation.queue_free()
	quit(0)


func _fail(message: String) -> void:
	push_error("[HarborWaterSmoke] " + message)
	quit(1)
