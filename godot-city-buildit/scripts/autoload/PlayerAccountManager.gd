extends Node

signal session_changed(player_id: int, authenticated: bool)
signal profile_loaded(player_id: int, revision: int)
signal profile_save_failed(reason: String)

var player_id: int = 0
var access_token: String = ""
var profile_revision: int = 0
var identity_label: String = ""
var _pending_game_state: Dictionary = {}
var _save_in_flight: bool = false

func is_authenticated() -> bool:
	return player_id > 0 and not access_token.is_empty()

func get_local_save_path() -> String:
	if not is_authenticated():
		return "user://pasoo_city_buildit_save.json"
	return "user://players/%d/pasoo_city_buildit_save.json" % player_id

func get_player_file_path(file_name: String) -> String:
	if not is_authenticated():
		return "user://" + file_name
	return "user://players/%d/%s" % [player_id, file_name.get_file()]

func _api_base() -> String:
	return str(ProjectSettings.get_setting("mshin/account/api_base_url", "")).strip_edges().trim_suffix("/")

func _auth_url() -> String:
	return str(ProjectSettings.get_setting("mshin/account/auth_url", "")).strip_edges().trim_suffix("/")

func _request_json(url: String, method: int, headers: PackedStringArray = PackedStringArray(), payload: Dictionary = {}) -> Dictionary:
	if url.is_empty():
		return {"ok": false, "status": 0, "body": {}, "error": "endpoint_not_configured"}
	var request_node := HTTPRequest.new()
	request_node.timeout = 15.0
	add_child(request_node)
	var request_headers := headers.duplicate()
	if method != HTTPClient.METHOD_GET:
		request_headers.append("Content-Type: application/json")
	var body := JSON.stringify(payload) if not payload.is_empty() else ""
	var request_error := request_node.request(url, request_headers, method, body)
	if request_error != OK:
		request_node.queue_free()
		return {"ok": false, "status": 0, "body": {}, "error": "request_start_failed_%d" % request_error}
	var completed: Array = await request_node.request_completed
	request_node.queue_free()
	var response_code := int(completed[1])
	var response_bytes: PackedByteArray = completed[3]
	var parsed: Variant = JSON.parse_string(response_bytes.get_string_from_utf8())
	var response_body: Dictionary = parsed if parsed is Dictionary else {}
	return {
		"ok": response_code >= 200 and response_code < 300,
		"status": response_code,
		"body": response_body,
		"error": str(response_body.get("error", "http_%d" % response_code))
	}

func bootstrap() -> bool:
	# Synthetic identities exist only in the editor and only when explicitly enabled
	# by the developer's local environment. They are never a production login path.
	if not OS.has_feature("editor") or OS.get_environment("MSHIN_DEV_AUTH") != "1" or _api_base().is_empty():
		return false
	var identity := OS.get_environment("MSHIN_DEV_IDENTITY")
	if identity.is_empty():
		identity = "admin"
	var response := await _request_json(
		_api_base() + "/v1/dev/session",
		HTTPClient.METHOD_POST,
		PackedStringArray(),
		{"identity": identity}
	)
	if not response.ok:
		push_warning("Mshin development sign-in unavailable: " + response.error)
		return false
	_activate_session(response.body, identity)
	if not is_authenticated():
		return false
	await fetch_remote_profile()
	return true

func sign_in_with_google_id_token(id_token: String, nonce: String) -> bool:
	if id_token.is_empty() or nonce.is_empty() or _auth_url().is_empty():
		return false
	var response := await _request_json(
		_auth_url() + "/v1/auth/google",
		HTTPClient.METHOD_POST,
		PackedStringArray(),
		{"id_token": id_token, "nonce": nonce}
	)
	if not response.ok:
		push_warning("Google sign-in failed: " + response.error)
		return false
	_activate_session(response.body, "Google player")
	if not is_authenticated():
		return false
	await fetch_remote_profile()
	return true

func _activate_session(data: Dictionary, label: String) -> void:
	var new_id := int(data.get("user_id", 0))
	var new_token := str(data.get("access_token", ""))
	if new_id < 1 or new_token.is_empty():
		return
	if player_id != new_id:
		profile_revision = 0
		_pending_game_state.clear()
	player_id = new_id
	access_token = new_token
	identity_label = label
	session_changed.emit(player_id, true)

func fetch_remote_profile() -> bool:
	if not is_authenticated() or _api_base().is_empty():
		return false
	var headers := PackedStringArray(["Authorization: Bearer " + access_token])
	var response := await _request_json(_api_base() + "/v1/profile", HTTPClient.METHOD_GET, headers)
	if not response.ok:
		push_warning("Could not restore online player profile: " + response.error)
		return false
	var data: Dictionary = response.body
	if int(data.get("user_id", 0)) != player_id:
		push_error("Profile service returned a mismatched player id.")
		return false
	profile_revision = maxi(0, int(data.get("revision", 0)))
	var game_state: Variant = data.get("game_state")
	if game_state is Dictionary:
		_write_local_game_state(game_state)
	elif player_id == 100001 and OS.get_environment("MSHIN_MIGRATE_LEGACY_SAVE") == "1":
		_migrate_legacy_admin_save()
	profile_loaded.emit(player_id, profile_revision)
	return true

func _write_local_game_state(game_state: Dictionary) -> bool:
	var file_path := get_local_save_path()
	var directory := file_path.get_base_dir()
	var absolute_directory := ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK and not DirAccess.dir_exists_absolute(absolute_directory):
		return false
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(game_state))
	file.close()
	return true

func _migrate_legacy_admin_save() -> void:
	var legacy_path := "user://pasoo_city_buildit_save.json"
	if not FileAccess.file_exists(legacy_path) or FileAccess.file_exists(get_local_save_path()):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
	if parsed is Dictionary and _write_local_game_state(parsed):
		queue_profile_save(parsed)
		print("[PlayerAccountManager] Migrated legacy local city save into development admin profile.")

func queue_profile_save(game_state: Dictionary) -> void:
	if not is_authenticated():
		return
	_pending_game_state = game_state.duplicate(true)
	if not _save_in_flight:
		call_deferred("_flush_pending_save")

func _flush_pending_save() -> void:
	if _save_in_flight or not is_authenticated():
		return
	_save_in_flight = true
	while not _pending_game_state.is_empty() and is_authenticated():
		var snapshot := _pending_game_state.duplicate(true)
		_pending_game_state.clear()
		var headers := PackedStringArray(["Authorization: Bearer " + access_token])
		var response := await _request_json(
			_api_base() + "/v1/profile",
			HTTPClient.METHOD_PUT,
			headers,
			{"expected_revision": profile_revision, "game_state": snapshot}
		)
		if response.ok:
			profile_revision = int(response.body.get("revision", profile_revision + 1))
		else:
			if _pending_game_state.is_empty():
				_pending_game_state = snapshot
			profile_save_failed.emit(response.error)
			push_warning("Online save was not accepted; local account save remains available: " + response.error)
			break
	_save_in_flight = false

func logout() -> void:
	player_id = 0
	access_token = ""
	profile_revision = 0
	identity_label = ""
	_pending_game_state.clear()
	session_changed.emit(0, false)
