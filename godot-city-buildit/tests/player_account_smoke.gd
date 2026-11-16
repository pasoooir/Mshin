extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var account = root.get_node_or_null("PlayerAccountManager")
	var save_manager = root.get_node_or_null("SaveManager")
	if account == null or save_manager == null:
		push_error("[PlayerAccountSmoke] Required autoload is missing.")
		quit(1)
		return
	account._activate_session({"user_id": 100001, "access_token": "test-token-a"}, "admin")
	var path_a := save_manager.get_active_save_path()
	if path_a != "user://players/100001/pasoo_city_buildit_save.json":
		push_error("[PlayerAccountSmoke] Player A save path is not isolated: " + path_a)
		quit(1)
		return
	account._activate_session({"user_id": 100002, "access_token": "test-token-b"}, "player2")
	var path_b := save_manager.get_active_save_path()
	if path_b != "user://players/100002/pasoo_city_buildit_save.json" or path_a == path_b:
		push_error("[PlayerAccountSmoke] Player B reused Player A save path.")
		quit(1)
		return
	account.logout()
	if save_manager.get_active_save_path() != "user://pasoo_city_buildit_save.json":
		push_error("[PlayerAccountSmoke] Guest fallback path changed unexpectedly.")
		quit(1)
		return
	print("[PlayerAccountSmoke] PASS")
	quit(0)
