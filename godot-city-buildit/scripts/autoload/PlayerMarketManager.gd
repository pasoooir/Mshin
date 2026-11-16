extends Node

signal market_changed
signal market_error(message: String)
signal market_transaction_completed(result: Dictionary)

var public_listings: Array[Dictionary] = []
var my_listings: Array[Dictionary] = []
var busy := false

func _api_base() -> String:
	return str(ProjectSettings.get_setting("mshin/account/api_base_url", "")).strip_edges().trim_suffix("/")

func _request_market(path: String, method: int, payload: Dictionary = {}) -> Dictionary:
	if not PlayerAccountManager.is_authenticated():
		return {"ok": false, "error": "sign_in_required", "body": {}}
	var base := _api_base()
	if base.is_empty():
		return {"ok": false, "error": "market_server_not_configured", "body": {}}
	var headers := PackedStringArray(["Authorization: Bearer " + PlayerAccountManager.access_token])
	return await PlayerAccountManager._request_json(base + path, method, headers, payload)

func refresh_market() -> bool:
	var response := await _request_market("/v1/market", HTTPClient.METHOD_GET)
	if not response.ok:
		market_error.emit(str(response.error))
		return false
	public_listings.clear()
	for entry in response.body.get("listings", []):
		if entry is Dictionary:
			public_listings.append(entry.duplicate(true))
	market_changed.emit()
	return true

func refresh_my_shop() -> bool:
	var response := await _request_market("/v1/market/mine", HTTPClient.METHOD_GET)
	if not response.ok:
		market_error.emit(str(response.error))
		return false
	my_listings.clear()
	for entry in response.body.get("listings", []):
		if entry is Dictionary:
			my_listings.append(entry.duplicate(true))
	market_changed.emit()
	return true

func create_listing(item_id: String, quantity: int, unit_price: int) -> Dictionary:
	if busy or item_id.is_empty() or quantity <= 0 or unit_price <= 0:
		return {"success": false, "reason": "invalid_request"}
	busy = true
	var response := await _request_market("/v1/market/list", HTTPClient.METHOD_POST, {
		"item_id": item_id, "quantity": quantity, "unit_price": unit_price
	})
	busy = false
	if not response.ok:
		market_error.emit(str(response.error))
		return {"success": false, "reason": str(response.error), "details": response.body}
	await refresh_my_shop()
	await refresh_market()
	var result: Dictionary = response.body
	result["success"] = true
	market_transaction_completed.emit(result)
	return result

func buy_listing(listing_id: String) -> Dictionary:
	if busy or listing_id.is_empty():
		return {"success": false, "reason": "invalid_request"}
	busy = true
	var response := await _request_market("/v1/market/%s/buy" % listing_id.uri_encode(), HTTPClient.METHOD_POST, {})
	busy = false
	if not response.ok:
		market_error.emit(str(response.error))
		return {"success": false, "reason": str(response.error), "details": response.body}
	await refresh_market()
	await refresh_my_shop()
	var result: Dictionary = response.body
	result["success"] = true
	market_transaction_completed.emit(result)
	return result

func cancel_listing(listing_id: String) -> Dictionary:
	if busy or listing_id.is_empty():
		return {"success": false, "reason": "invalid_request"}
	busy = true
	var response := await _request_market("/v1/market/%s/cancel" % listing_id.uri_encode(), HTTPClient.METHOD_POST, {})
	busy = false
	if not response.ok:
		market_error.emit(str(response.error))
		return {"success": false, "reason": str(response.error), "details": response.body}
	await refresh_my_shop()
	await refresh_market()
	var result: Dictionary = response.body
	result["success"] = true
	market_transaction_completed.emit(result)
	return result
