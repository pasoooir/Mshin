extends Node

signal session_changed(player_id: int, authenticated: bool)
signal profile_loaded(player_id: int, revision: int)
signal profile_save_failed(reason: String)
signal authentication_feedback(message: String, success: bool)
signal profile_identity_changed

var player_id: int = 0
var access_token: String = ""
var profile_revision: int = 0
var identity_label: String = ""
var google_avatar_url: String = ""
var google_display_name: String = ""
var _pending_game_state: Dictionary = {}
var _save_in_flight: bool = false
var _last_profile_save_ok: bool = true
var _google_pending_nonces: Dictionary = {}
var _google_callback: Variant
var _last_login_rewards: Dictionary = {}
var _remote_profile_has_game_state: bool = false
var _last_auth_error: String = ""
var _last_login_reward_error: String = ""

func _ready() -> void:
	var preferences := ConfigFile.new()
	if preferences.load("user://account_session.cfg") == OK and bool(preferences.get_value("account", "google_auto_sign_in", false)):
		call_deferred("begin_google_sign_in", true)

func _set_google_auto_sign_in(enabled: bool) -> void:
	var preferences := ConfigFile.new()
	preferences.load("user://account_session.cfg")
	preferences.set_value("account", "google_auto_sign_in", enabled)
	var error := preferences.save("user://account_session.cfg")
	if error != OK:
		push_warning("Could not save Google sign-in preference: %s" % error)

func is_authenticated() -> bool:
	return player_id > 0 and not access_token.is_empty()

func get_local_save_path() -> String:
	if not is_authenticated():
		return "user://pasoo_city_buildit_save.json"
	return "user://players/%d/pasoo_city_buildit_save.json" % player_id


static func should_prefer_local_profile_state(local_state: Variant, remote_state: Variant) -> bool:
	if not local_state is Dictionary:
		return false
	if not remote_state is Dictionary:
		return true
	var local_saved_at := str(local_state.get("saved_at", ""))
	var remote_saved_at := str(remote_state.get("saved_at", ""))
	if local_saved_at.is_empty():
		return false
	if remote_saved_at.is_empty():
		return true
	var local_timestamp := Time.get_unix_time_from_datetime_string(local_saved_at)
	var remote_timestamp := Time.get_unix_time_from_datetime_string(remote_saved_at)
	return local_timestamp > remote_timestamp

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
	_last_auth_error = ""
	_last_login_reward_error = ""
	_last_login_rewards.clear()
	if id_token.is_empty() or nonce.is_empty() or _auth_url().is_empty():
		_last_auth_error = "Google sign-in is not configured. Please retry from Settings."
		return false
	if not await _wait_for_save_manager_ready():
		_last_auth_error = "The city save system is still starting. Please retry Google sign-in."
		return false
	# The Settings action is a sign-out while a Mayor is authenticated. Refuse
	# a second sign-in here so one account can never inherit another account's
	# in-memory city; logout first saves the old account and restores guest state.
	if is_authenticated():
		_last_auth_error = "Sign out of the current Mayor before switching Google accounts."
		return false
	# Preserve the guest city before switching the active save path to a Mayor ID.
	# A first-time account inherits this state once; returning accounts load their
	# own remote game_state before any post-login autosave can run.
	if not SaveManager.save_game(false):
		_last_auth_error = "Your current city could not be saved before Google sign-in."
		return false
	var response := await _request_json(
		_auth_url() + "/v1/auth/google",
		HTTPClient.METHOD_POST,
		PackedStringArray(),
		{"id_token": id_token, "nonce": nonce}
	)
	if not response.ok:
		_last_auth_error = "Google authentication failed: " + response.error
		push_warning(_last_auth_error)
		return false
	_activate_session(response.body, "Google player")
	if not is_authenticated():
		_last_auth_error = "Mshin could not create a player session from the Google response."
		return false
	if not await fetch_remote_profile():
		_last_auth_error = "Google was verified, but the private player JSON profile could not be created or loaded. Check Cloudflare/GitHub storage and retry."
		_clear_failed_session()
		return false
	if not _restore_authenticated_profile_game_state():
		_last_auth_error = "The saved city for this Google account could not be restored. Your guest city has been preserved."
		_clear_failed_session()
		return false
	var reward_result := await claim_login_rewards()
	if not bool(reward_result.get("ok", false)):
		_last_login_reward_error = str(reward_result.get("error", "reward_sync_unavailable"))
	return true

func claim_login_rewards() -> Dictionary:
	if not is_authenticated() or _api_base().is_empty():
		return {"ok": false, "error": "sign_in_required"}
	var headers := PackedStringArray(["Authorization: Bearer " + access_token])
	var response := await _request_json(_api_base() + "/v1/rewards/claim", HTTPClient.METHOD_POST, headers, {})
	if not response.ok:
		push_warning("Could not claim login rewards: " + response.error)
		return {"ok": false, "error": response.error}
	profile_revision = maxi(profile_revision, int(response.body.get("revision", profile_revision)))
	_last_login_rewards = response.body.duplicate(true)
	var balances: Dictionary = response.body.get("balances", {})
	EconomyManager.simoleons = maxi(0, int(balances.get("simoleons", EconomyManager.simoleons)))
	EconomyManager.sim_cash = maxi(0, int(balances.get("sim_cash", EconomyManager.sim_cash)))
	EconomyManager.simoleons_changed.emit(EconomyManager.simoleons)
	EconomyManager.sim_cash_changed.emit(EconomyManager.sim_cash)
	var game_state: Variant = response.body.get("game_state")
	if game_state is Dictionary:
		_write_local_game_state(game_state)
	return response.body

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
	_apply_player_scope()
	session_changed.emit(player_id, true)

func _apply_player_scope() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.set_player_scope(get_player_file_path("audio_settings.cfg"))
	if has_node("/root/HapticsManager"):
		HapticsManager.set_player_scope(get_player_file_path("haptics_settings.cfg"))
	if has_node("/root/GraphicsSettingsManager"):
		GraphicsSettingsManager.set_player_scope(get_player_file_path("graphics_settings.cfg"))
	var scene = get_tree().current_scene
	if scene != null:
		var tutorial = scene.get_node_or_null("TutorialGuide")
		if tutorial != null and tutorial.has_method("set_player_scope"):
			tutorial.set_player_scope(get_player_file_path("tutorial_progress.cfg"))

func fetch_remote_profile() -> bool:
	_remote_profile_has_game_state = false
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
	var local_state: Variant = _read_local_game_state()
	if game_state is Dictionary:
		if should_prefer_local_profile_state(local_state, game_state):
			# Preserve a newer offline snapshot instead of replacing it with an
			# older cloud revision; sync it before exposing the restored session.
			var newer_local_snapshot: Dictionary = local_state
			_remote_profile_has_game_state = true
			if not await save_profile_now(newer_local_snapshot):
				push_error("Could not sync the newer player-scoped local save before profile restore.")
				return false
		else:
			if not _write_local_game_state(game_state):
				push_error("Could not write the authenticated remote profile to its player-scoped local JSON save.")
				return false
			_remote_profile_has_game_state = true
	elif local_state is Dictionary:
		# The cloud profile may have been initialized before a previous offline
		# session could upload its first save. Keep and sync that local snapshot.
		var existing_local_snapshot: Dictionary = local_state
		_remote_profile_has_game_state = true
		if not await save_profile_now(existing_local_snapshot):
			push_error("Could not sync the existing player-scoped local save to its new profile.")
			return false
	elif player_id == 100001 and OS.get_environment("MSHIN_MIGRATE_LEGACY_SAVE") == "1":
		_migrate_legacy_admin_save()
	profile_loaded.emit(player_id, profile_revision)
	return true

func _read_local_game_state() -> Variant:
	var save_path := get_local_save_path()
	if not FileAccess.file_exists(save_path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return parsed if parsed is Dictionary else null


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


func save_profile_now(game_state: Dictionary) -> bool:
	if not is_authenticated() or _api_base().is_empty():
		return false
	_pending_game_state = game_state.duplicate(true)
	while _save_in_flight:
		await get_tree().process_frame
	if not _pending_game_state.is_empty():
		await _flush_pending_save()
	return _last_profile_save_ok and _pending_game_state.is_empty()

func _flush_pending_save() -> void:
	if _save_in_flight or not is_authenticated():
		return
	_save_in_flight = true
	_last_profile_save_ok = true
	var revision_conflict_retries := 0
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
			revision_conflict_retries = 0
		elif int(response.status) == 409:
			# A marketplace transaction or another save may have advanced the
			# profile while this snapshot was in flight. Refresh the revision and
			# preserve the server-owned wallet/warehouse before retrying the save.
			var latest := await _request_json(_api_base() + "/v1/profile", HTTPClient.METHOD_GET, headers)
			if latest.ok and latest.body.get("game_state", {}) is Dictionary:
				profile_revision = maxi(0, int(latest.body.get("revision", profile_revision)))
				var server_state: Dictionary = latest.body.get("game_state", {})
				var server_economy: Dictionary = server_state.get("economy", {})
				var merged_economy: Dictionary = snapshot.get("economy", {}).duplicate(true)
				if server_economy.has("simoleons"):
					merged_economy["simoleons"] = server_economy.simoleons
				snapshot["economy"] = merged_economy
				if server_state.get("storage", {}) is Dictionary:
					snapshot["storage"] = server_state.storage.duplicate(true)
				_pending_game_state = snapshot
				revision_conflict_retries += 1
				if revision_conflict_retries <= 3:
					continue
			if _pending_game_state.is_empty():
				_pending_game_state = snapshot
			profile_save_failed.emit("revision_conflict")
			push_warning("Online save conflicted with a newer profile; latest wallet and inventory were preserved.")
			break
		else:
			_last_profile_save_ok = false
			if _pending_game_state.is_empty():
				_pending_game_state = snapshot
			profile_save_failed.emit(response.error)
			push_warning("Online save was not accepted; local account save remains available: " + response.error)
			break
	_save_in_flight = false

func logout() -> bool:
	var cloud_sync_ok := true
	if is_authenticated() and has_node("/root/SaveManager") and SaveManager.persistence_ready:
		if SaveManager.save_game(false):
			var current_state: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.get_active_save_path()))
			if current_state is Dictionary:
				var current_snapshot: Dictionary = current_state
				cloud_sync_ok = await save_profile_now(current_snapshot)
			else:
				cloud_sync_ok = false
		else:
			cloud_sync_ok = false
	if not cloud_sync_ok:
		authentication_feedback.emit("Cloud sync failed. You are still signed in and your local account save is safe; retry sign-out when the connection is restored.", false)
		return false
	_set_google_auto_sign_in(false)
	_google_pending_nonces.clear()
	_clear_session_state()
	if has_node("/root/SaveManager") and SaveManager.persistence_ready and get_tree().current_scene != null:
		# Return to the guest save instead of leaving another Mayor's city in memory.
		SaveManager.load_game()
	return true


func _clear_session_state() -> void:
	google_avatar_url = ""
	google_display_name = ""
	player_id = 0
	access_token = ""
	profile_revision = 0
	identity_label = ""
	_pending_game_state.clear()
	_last_login_rewards.clear()
	_remote_profile_has_game_state = false
	_apply_player_scope()
	session_changed.emit(0, false)
	profile_identity_changed.emit()


func _clear_failed_session() -> void:
	_clear_session_state()
	if has_node("/root/SaveManager") and SaveManager.persistence_ready and get_tree().current_scene != null:
		SaveManager.load_game()


func _wait_for_save_manager_ready() -> bool:
	if not has_node("/root/SaveManager"):
		return false
	for _frame in range(180):
		if SaveManager.persistence_ready:
			return true
		await get_tree().process_frame
	return SaveManager.persistence_ready


func _restore_authenticated_profile_game_state() -> bool:
	if not _remote_profile_has_game_state:
		return true
	if not has_node("/root/SaveManager") or not SaveManager.persistence_ready or get_tree().current_scene == null:
		return false
	# fetch_remote_profile wrote this account's remote game_state to the active
	# player-specific path. Load it before the post-login autosave can run.
	return SaveManager.load_game()


func begin_google_sign_in(auto_select: bool = false) -> bool:
	if not OS.has_feature("web"):
		if not auto_select:
			authentication_feedback.emit("Google sign-in is available in the web version.", false)
		return false
	var client_id := str(ProjectSettings.get_setting("mshin/account/google_client_id", "")).strip_edges()
	if client_id.is_empty() or not client_id.ends_with(".apps.googleusercontent.com"):
		if not auto_select:
			authentication_feedback.emit("Google sign-in is not configured yet.", false)
		return false
	call_deferred("_request_google_nonce_and_launch", client_id, auto_select)
	return true

func _request_google_nonce_and_launch(client_id: String, auto_select: bool = false) -> void:
	var nonce_response := await _request_json(_auth_url() + "/v1/auth/nonce", HTTPClient.METHOD_GET)
	if not nonce_response.ok:
		if not auto_select:
			authentication_feedback.emit("Could not start secure Google sign-in. Please retry.", false)
		return
	var request_nonce := str(nonce_response.body.get("nonce", ""))
	if request_nonce.length() < 32:
		if not auto_select:
			authentication_feedback.emit("Secure sign-in challenge was invalid. Please retry.", false)
		return
	_google_pending_nonces[request_nonce] = auto_select
	_google_callback = JavaScriptBridge.create_callback(_on_google_credential)
	var window := JavaScriptBridge.get_interface("window")
	window.set("mshinGoogleCredentialCallback", _google_callback)
	var client_id_js := JSON.stringify(client_id)
	var nonce_js := JSON.stringify(request_nonce)
	var script := """
	(function () {
		const clientId = %s;
		const nonce = %s;
		const shouldAutoSelect = %s;
		const callback = function (credential) {
			try { window.mshinGoogleCredentialCallback(credential || null, nonce); }
			finally {
				const overlay = document.getElementById("mshin-google-signin-overlay");
				if (overlay) overlay.remove();
			}
		};
		const initialize = function () {
			try {
				if (!window.google || !window.google.accounts || !window.google.accounts.id) {
					callback(null);
					return;
				}
				window.google.accounts.id.initialize({
					client_id: clientId,
					nonce: nonce,
					auto_select: shouldAutoSelect,
					cancel_on_tap_outside: true,
					callback: function (response) {
						callback(response && response.credential ? response.credential : null);
					}
				});
				if (shouldAutoSelect) {
					window.google.accounts.id.prompt(function (moment) {
						if (moment && (moment.isNotDisplayed() || moment.isSkippedMoment())) {
							window.mshinGoogleCredentialCallback(null, nonce);
						}
					});
					return;
				}
				let overlay = document.getElementById("mshin-google-signin-overlay");
				if (overlay) overlay.remove();
				overlay = document.createElement("div");
				overlay.id = "mshin-google-signin-overlay";
				overlay.setAttribute("role", "dialog");
				overlay.setAttribute("aria-label", "Sign in with Google");
				overlay.style.cssText = "position:fixed;inset:0;z-index:2147483000;display:flex;align-items:center;justify-content:center;padding:20px;background:rgba(3,13,27,.78);backdrop-filter:blur(9px);";
				const card = document.createElement("div");
				card.style.cssText = "position:relative;display:flex;flex-direction:column;align-items:center;gap:18px;min-width:300px;max-width:92vw;padding:30px 26px 24px;border:1px solid rgba(91,215,247,.8);border-radius:22px;background:linear-gradient(145deg,#1c3d5d,#10253d);box-shadow:0 22px 70px rgba(0,0,0,.55);";
				const heading = document.createElement("div");
				heading.textContent = "Connect your city";
				heading.style.cssText = "font:700 22px system-ui,sans-serif;color:#f5fbff;letter-spacing:.3px;";
				const subtitle = document.createElement("div");
				subtitle.textContent = "Sign in securely to save and sync your progress";
				subtitle.style.cssText = "font:14px system-ui,sans-serif;color:#c8dced;text-align:center;max-width:290px;";
				const button = document.createElement("div");
				button.id = "mshin-google-render-button";
				const close = document.createElement("button");
				close.type = "button";
				close.textContent = "Cancel";
				close.style.cssText = "border:0;border-radius:12px;padding:9px 20px;background:rgba(255,255,255,.10);color:#d8ebf7;font:600 14px system-ui,sans-serif;cursor:pointer;";
				close.addEventListener("click", function () { callback(null); });
				card.append(heading, subtitle, button, close);
				overlay.appendChild(card);
				document.body.appendChild(overlay);
				window.google.accounts.id.renderButton(button, {
					type: "standard",
					theme: "outline",
					size: "large",
					text: "continue_with",
					shape: "pill",
					logo_alignment: "left",
					width: Math.min(300, Math.floor(window.innerWidth * .78))
				});
			} catch (_) {
				callback(null);
			}
		};
		const loadIdentity = function () {
			if (window.google && window.google.accounts && window.google.accounts.id) {
				initialize();
				return;
			}
			let loader = document.getElementById("mshin-google-identity-script");
			if (loader) {
				const loadState = loader.dataset.mshinLoadState || "unknown";
				if (loadState !== "loading") {
					// A previous failed/partial load must not poison every later retry.
					loader.remove();
					loader = null;
				} else {
					loader.addEventListener("load", function () {
						loader.dataset.mshinLoadState = "loaded";
						initialize();
					}, { once: true });
					loader.addEventListener("error", function () {
						loader.dataset.mshinLoadState = "failed";
						callback(null);
					}, { once: true });
					return;
				}
			}
			loader = document.createElement("script");
			loader.id = "mshin-google-identity-script";
			loader.dataset.mshinLoadState = "loading";
			loader.src = "https://accounts.google.com/gsi/client";
			loader.async = true;
			loader.defer = true;
			loader.addEventListener("load", function () {
				loader.dataset.mshinLoadState = "loaded";
				initialize();
			}, { once: true });
			loader.addEventListener("error", function () {
				loader.dataset.mshinLoadState = "failed";
				callback(null);
			}, { once: true });
			document.head.appendChild(loader);
		};
		loadIdentity();
	})();
	""" % [client_id_js, nonce_js, str(auto_select).to_lower()]
	JavaScriptBridge.eval(script)
	if not auto_select:
		authentication_feedback.emit("Choose your Google account to continue…", true)



func _update_google_identity_from_token(id_token: String) -> void:
	google_avatar_url = ""
	google_display_name = ""
	var token_parts := id_token.split(".")
	if token_parts.size() < 2:
		return
	var payload_segment := str(token_parts[1]).replace("-", "+").replace("_", "/")
	while payload_segment.length() % 4 != 0:
		payload_segment += "="
	var payload_text := Marshalls.base64_to_utf8(payload_segment)
	var claims: Variant = JSON.parse_string(payload_text)
	if not claims is Dictionary:
		return
	google_avatar_url = str(claims.get("picture", "")).strip_edges()
	google_display_name = str(claims.get("name", claims.get("email", "Google player"))).strip_edges()
	if google_display_name.is_empty():
		google_display_name = "Google player"
	identity_label = google_display_name
	profile_identity_changed.emit()

func _on_google_credential(args: Array) -> void:
	var credential := str(args[0]) if args.size() > 0 and args[0] != null else ""
	var returned_nonce := str(args[1]) if args.size() > 1 else ""
	call_deferred("_complete_google_sign_in", credential, returned_nonce)

func _complete_google_sign_in(id_token: String, nonce: String) -> void:
	if nonce.is_empty() or not _google_pending_nonces.has(nonce):
		return
	var silent_attempt := bool(_google_pending_nonces[nonce])
	_google_pending_nonces.erase(nonce)
	if id_token.is_empty():
		if not silent_attempt:
			authentication_feedback.emit("Google sign-in was cancelled. You can try again whenever you're ready.", false)
		return
	var success := await sign_in_with_google_id_token(id_token, nonce)
	if success:
		_update_google_identity_from_token(id_token)
		_set_google_auto_sign_in(true)
		var reward_parts: PackedStringArray = []
		var welcome: Dictionary = _last_login_rewards.get("welcome", {})
		var daily: Dictionary = _last_login_rewards.get("daily", {})
		if bool(welcome.get("granted", false)):
			reward_parts.append("+%d Simoleons" % int(welcome.get("simoleons", 0)))
			reward_parts.append("+%d SimCash" % int(welcome.get("sim_cash", 0)))
		if bool(daily.get("granted", false)):
			reward_parts.append("+%d daily Simoleons" % int(daily.get("simoleons", 0)))
		var reward_message := " · " + ", ".join(reward_parts) if not reward_parts.is_empty() else ""
		if reward_parts.is_empty() and not _last_login_reward_error.is_empty():
			reward_message = " · city saved; reward sync pending"
		authentication_feedback.emit("Signed in as Mayor #%d%s" % [player_id, reward_message], true)
		if has_node("/root/SaveManager") and SaveManager.persistence_ready:
			SaveManager.save_game()
	elif not silent_attempt:
		var failure_message := _last_auth_error if not _last_auth_error.is_empty() else "Google sign-in failed. Please try again."
		authentication_feedback.emit(failure_message, false)
