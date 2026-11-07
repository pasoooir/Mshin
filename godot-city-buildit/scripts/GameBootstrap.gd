extends Node3D

func _ready() -> void:
	call_deferred("_restore_city")

func _restore_city() -> void:
	if SaveManager.load_game():
		var status = get_node_or_null("HUD/StatusLabel")
		if status:
			status.text = "Saved city restored. Your city will autosave every 30 seconds."
	else:
		var status = get_node_or_null("HUD/StatusLabel")
		if status:
			status.text = "Welcome! Build a connected road, then a house, factory and Building Supplies shop."
