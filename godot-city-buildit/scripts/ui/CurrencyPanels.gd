extends Control
## Distinct SimCash-to-Simoleons exchange and SimCash store overlays.
const Icons = preload("res://scripts/ui/Icons.gd")
const CONVERSION_OPTIONS := [5, 10, 25, 50]
var _active_panel := ""
var _selected_conversion := 5
var _selected_product_id := ""
var _pending_order_id := ""
var _content: VBoxContainer
var _status: Label
var _scale := 1.0

func _ready() -> void:
	name = "CurrencyPanels"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 300
	hide()

func open_conversion() -> void:
	_active_panel = "conversion"
	_build_shell("CONVERT SIMCASH", "Exchange premium currency for everyday city funds.")
	_build_conversion()
	show()

func open_store() -> void:
	_active_panel = "store"
	_selected_product_id = ""
	_build_shell("SIMCASH STORE", "Choose a premium currency pack.")
	_build_store()
	show()

func close_panel() -> void:
	_active_panel = ""
	_pending_order_id = ""
	hide()
	for child in get_children(): child.queue_free()

func _build_shell(title_text: String, subtitle_text: String) -> void:
	for child in get_children(): child.queue_free()
	var viewport := get_viewport_rect().size
	_scale = clampf(minf(viewport.x / 1280.0, viewport.y / 720.0), 0.78, 1.12)
	var backdrop := Button.new()
	backdrop.name = "CurrencyPopupBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.flat = true
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.add_theme_stylebox_override("normal", _flat_style(Color(0.015, 0.035, 0.06, 0.80)))
	backdrop.add_theme_stylebox_override("hover", _flat_style(Color(0.015, 0.035, 0.06, 0.80)))
	backdrop.add_theme_stylebox_override("pressed", _flat_style(Color(0.015, 0.035, 0.06, 0.80)))
	backdrop.pressed.connect(close_panel)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.name = "CurrencyPopupCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)
	var card := PanelContainer.new()
	card.name = "CurrencyPopupCard"
	card.custom_minimum_size = Vector2(minf(660.0, viewport.x - 24.0), minf(520.0, viewport.y - 20.0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _card_style())
	center.add_child(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 9)
	card.add_child(outer)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_stack)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", int(25 * _scale))
	title.add_theme_color_override("font_color", Color("#FFF0BE"))
	title.add_theme_color_override("font_shadow_color", Color("#071C2C"))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title_stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", int(13 * _scale))
	subtitle.add_theme_color_override("font_color", Color("#C7DFEC"))
	title_stack.add_child(subtitle)
	var close := Button.new()
	close.name = "CloseCurrencyPopup"
	close.text = "✕"
	close.custom_minimum_size = Vector2(46, 42) * _scale
	close.add_theme_font_size_override("font_size", int(22 * _scale))
	close.add_theme_stylebox_override("normal", _button_style(Color("#A83D4A")))
	close.add_theme_stylebox_override("hover", _button_style(Color("#D34C5A")))
	close.pressed.connect(close_panel)
	header.add_child(close)
	var line := ColorRect.new()
	line.custom_minimum_size.y = 2
	line.color = Color("#5CA6C9")
	outer.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.name = "CurrencyPopupScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	_status = Label.new()
	_status.name = "CurrencyPopupStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("#FFE5A6"))
	_status.add_theme_font_size_override("font_size", int(13 * _scale))
	outer.add_child(_status)

func _build_conversion() -> void:
	_content.add_child(_balance_panel())
	_content.add_child(_notice("Mshin exchange rate", "1 SimCash = %s Simoleons. This is the current Mshin game rate, not an official EA conversion quote." % _fmt(EconomyManager.SIMCASH_TO_SIMOLEONS_RATE)))
	var heading := _label("SELECT EXCHANGE AMOUNT", 15, Color("#F7D77D"))
	_content.add_child(heading)
	for amount in CONVERSION_OPTIONS:
		var button := Button.new()
		button.custom_minimum_size.y = 48 * _scale
		button.text = "%s SimCash     →     %s Simoleons%s" % [_fmt(amount), _fmt(amount * EconomyManager.SIMCASH_TO_SIMOLEONS_RATE), "   ✓" if amount == _selected_conversion else ""]
		button.add_theme_font_size_override("font_size", int(16 * _scale))
		button.add_theme_stylebox_override("normal", _button_style(Color("#2D8C70") if amount == _selected_conversion else Color("#24546D")))
		button.add_theme_stylebox_override("hover", _button_style(Color("#347D9D")))
		button.pressed.connect(_select_conversion.bind(amount))
		_content.add_child(button)
	var preview := _label("You receive %s Simoleons." % _fmt(_selected_conversion * EconomyManager.SIMCASH_TO_SIMOLEONS_RATE), 18, Color("#FFF0BE"))
	preview.name = "ConversionPreview"
	_content.add_child(preview)
	var confirm := Button.new()
	confirm.name = "ConfirmSimCashConversion"
	confirm.text = "CONFIRM EXCHANGE"
	confirm.custom_minimum_size.y = 52 * _scale
	confirm.add_theme_font_size_override("font_size", int(17 * _scale))
	confirm.add_theme_stylebox_override("normal", _button_style(Color("#2D9B70")))
	confirm.pressed.connect(_confirm_conversion)
	_content.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size.y = 42 * _scale
	cancel.add_theme_stylebox_override("normal", _button_style(Color("#40566A")))
	cancel.pressed.connect(close_panel)
	_content.add_child(cancel)
	var market_heading := _label("CITY SUPPLY MARKET", 16, Color("#F7D77D"))
	market_heading.name = "CitySupplyMarketHeading"
	_content.add_child(market_heading)
	_content.add_child(_notice("Buy unlocked resources with Simoleons", "Purchase raw materials and crafted goods directly into your warehouse. Prices are Mshin market prices, not official EA Global Trade HQ prices."))
	for item_id in _get_market_item_ids():
		_content.add_child(_market_item_row(item_id))
	if EconomyManager.sim_cash < _selected_conversion:
		_status.text = "Not enough SimCash for this exchange."

func _select_conversion(amount: int) -> void:
	_selected_conversion = amount
	_build_shell("CONVERT SIMCASH", "Exchange premium currency for everyday city funds.")
	_build_conversion()

func _confirm_conversion() -> void:
	var result := EconomyManager.convert_sim_cash_to_simoleons(_selected_conversion)
	if not bool(result.get("success", false)):
		_status.text = "Exchange failed: %s" % str(result.get("reason", "unknown"))
		return
	if has_node("/root/SaveManager"): SaveManager.save_game()
	_build_shell("EXCHANGE COMPLETE", "Your city balances have been updated.")
	_content.add_child(_notice("Conversion successful", "%s SimCash spent\n%s Simoleons received" % [_fmt(int(result.simcash_spent)), _fmt(int(result.simoleons_granted))]))
	_add_store_return_button()

func _build_store() -> void:
	_content.add_child(_balance_panel())
	_content.add_child(_notice("SANDBOX PAYMENT MODE", "The bank hand-off is simulated only. No card details are collected and no real money is charged. Product prices will be configured after merchant and gateway onboarding."))
	var boosts_heading := _label("CITY PROGRESS BOOSTS", 16, Color("#F7D77D"))
	boosts_heading.name = "CityProgressBoostsHeading"
	_content.add_child(boosts_heading)
	_content.add_child(_notice("Use SimCash to save time", "Finish active factory/store production, construction and upgrades. Mshin quote: 1 SimCash per started minute remaining. Access and service requirements still apply."))
	_add_active_progress_boosts()
	_content.add_child(_label("COMMERCIAL QUEUE SLOTS", 16, Color("#F7D77D")))
	_add_store_slot_expansions()
	_content.add_child(_label("SIMCASH PACKS", 16, Color("#F7D77D")))
	for product in PaymentManager.get_catalog():
		_content.add_child(_product_card(product))
	var history := Button.new()
	history.text = "PURCHASE HISTORY"
	history.custom_minimum_size.y = 44 * _scale
	history.add_theme_stylebox_override("normal", _button_style(Color("#40566A")))
	history.pressed.connect(_show_history)
	_content.add_child(history)

func _product_card(product: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 96 * _scale
	panel.add_theme_stylebox_override("panel", _inner_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(76, 76) * _scale
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var asset := "res://assets/icons/ui/currency/%s.png" % str(product.id)
	if not ResourceLoader.exists(asset): asset = "res://assets/icons/ui/currency/simcash_bundle.png"
	icon.texture = load(asset) as Texture2D if ResourceLoader.exists(asset) else Icons.get_icon_tex("money")
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	info.add_child(_label(str(product.name), 16, Color.WHITE))
	info.add_child(_label("%s base  +  %s bonus  =  %s SimCash" % [_fmt(int(product.base_amount)), _fmt(int(product.bonus_amount)), _fmt(int(product.total_amount))], 13, Color("#B7EBC4")))
	info.add_child(_label("Price configured when live gateway is connected", 11, Color("#B8D5E5")))
	var select := Button.new()
	select.text = "SELECT"
	select.custom_minimum_size = Vector2(92, 46) * _scale
	select.add_theme_stylebox_override("normal", _button_style(Color("#2D8C70")))
	select.pressed.connect(_select_product.bind(str(product.id)))
	row.add_child(select)
	return panel

func _select_product(product_id: String) -> void:
	var product := PaymentManager.get_product(product_id)
	if product.is_empty():
		_status.text = "Product is unavailable."
		return
	_selected_product_id = product_id
	_build_shell("ORDER REVIEW", "Review the SimCash pack before the simulated payment hand-off.")
	_content.add_child(_notice(str(product.name), "%s base SimCash + %s bonus = %s SimCash." % [_fmt(int(product.base_amount)), _fmt(int(product.bonus_amount)), _fmt(int(product.total_amount))]))
	_content.add_child(_notice("Payment amount", "No real price or charge is applied in sandbox mode. The live price will be supplied by the payment gateway after merchant onboarding."))
	var confirm := Button.new()
	confirm.name = "CreateSandboxOrder"
	confirm.text = "CONTINUE TO TEST PAYMENT"
	confirm.custom_minimum_size.y = 54 * _scale
	confirm.add_theme_stylebox_override("normal", _button_style(Color("#2D9B70")))
	confirm.pressed.connect(_create_order)
	_content.add_child(confirm)
	var back := Button.new()
	back.text = "BACK TO STORE"
	back.custom_minimum_size.y = 42 * _scale
	back.add_theme_stylebox_override("normal", _button_style(Color("#40566A")))
	back.pressed.connect(open_store)
	_content.add_child(back)

func _create_order() -> void:
	var result := PaymentManager.create_order(_selected_product_id)
	if not bool(result.get("success", false)):
		_status.text = "Order could not be created: %s" % str(result.get("reason", "unknown"))
		return
	_pending_order_id = str(result.order.order_id)
	_build_shell("TEST PAYMENT HAND-OFF", "This is the only simulated stage. It does not contact a bank.")
	_content.add_child(_notice("Sandbox order created", "Order: %s\nPack: %s\nSimCash after success: %s\nReal charge: none" % [_pending_order_id, str(result.order.product_name), _fmt(int(result.order.grant_amount))]))
	_content.add_child(_label("Select a simulated gateway result:", 14, Color("#D9EAF4")))
	for outcome in ["success", "failed", "cancelled"]:
		var button := Button.new()
		button.custom_minimum_size.y = 48 * _scale
		button.text = "SIMULATE " + outcome.to_upper()
		var tint := Color("#2D9B70") if outcome == "success" else (Color("#A83D4A") if outcome == "failed" else Color("#40566A"))
		button.add_theme_stylebox_override("normal", _button_style(tint))
		button.pressed.connect(_finish_order.bind(outcome))
		_content.add_child(button)

func _finish_order(outcome: String) -> void:
	var result := PaymentManager.complete_sandbox_order(_pending_order_id, outcome)
	if not bool(result.get("success", false)):
		_build_shell("PAYMENT NOT COMPLETED", "No currency is granted unless the simulated provider reports success.")
		_content.add_child(_notice("No SimCash granted", "Status: %s\nReason: %s\nYour balance has not been increased." % [outcome.to_upper(), str(result.get("reason", "not successful"))]))
	else:
		_build_shell("PURCHASE COMPLETE", "Sandbox transaction recorded. No real money was charged.")
		_content.add_child(_notice("SimCash added", "%s SimCash credited to your city.\nOrder: %s" % [_fmt(int(result.order.grant_amount)), _pending_order_id]))
	_add_store_return_button()


func _get_market_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for item_id in ProductionManager.raw_materials.keys():
		if int(ProductionManager.raw_materials[item_id].get("level", 1)) <= GameManager.level:
			ids.append(str(item_id))
	for item_id in ProductionManager.crafted_items.keys():
		var item: Dictionary = ProductionManager.crafted_items[item_id]
		if int(item.get("level", 1)) <= GameManager.level and bool(item.get("unlock_level_verified", true)):
			ids.append(str(item_id))
	return ids

func _market_item_row(item_id: String) -> Control:
	var definition := ProductionManager.get_item_definition(item_id)
	var price := EconomyManager.get_market_buy_price(item_id)
	if definition.is_empty() or price <= 0:
		return Control.new()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _inner_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_label(str(definition.get("name", item_id)), 14, Color.WHITE))
	info.add_child(_label("%s Simoleons each · Warehouse %d/%d" % [_fmt(price), StorageManager.get_used(), StorageManager.capacity], 11, Color("#B8D5E5")))
	row.add_child(info)
	for amount in [1, 5]:
		var buy := Button.new()
		buy.text = "BUY %d\n%s" % [amount, _fmt(price * amount)]
		buy.custom_minimum_size = Vector2(76, 48) * _scale
		buy.add_theme_stylebox_override("normal", _button_style(Color("#2D8C70")))
		buy.pressed.connect(_buy_market_item.bind(item_id, amount))
		row.add_child(buy)
	return panel

func _buy_market_item(item_id: String, amount: int) -> void:
	var result := EconomyManager.buy_market_item(item_id, amount)
	if not bool(result.get("success", false)):
		_status.text = "Purchase failed: %s" % str(result.get("reason", "unknown"))
		return
	_build_shell("MATERIALS PURCHASED", "Your warehouse has been updated.")
	_content.add_child(_notice(str(ProductionManager.get_item_definition(item_id).get("name", item_id)), "%d added · %s Simoleons spent" % [amount, _fmt(int(result.total_cost))]))
	var back := Button.new()
	back.text = "BACK TO CITY FUNDS"
	back.pressed.connect(open_conversion)
	_content.add_child(back)
	if has_node("/root/SaveManager"):
		SaveManager.save_game()

func _add_active_progress_boosts() -> void:
	var found := false
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building):
			continue
		if building.production_component is ProductionComponent:
			var component: ProductionComponent = building.production_component
			for index in range(component.get_slot_count()):
				var quote := component.get_slot_speedup_quote(index)
				if quote.is_empty():
					continue
				found = true
				var item := ProductionManager.get_item_definition(str(quote.item_id))
				var button := Button.new()
				button.text = "Finish %s · %ds · %d SimCash" % [str(item.get("name", quote.item_id)), int(quote.remaining_seconds), int(quote.simcash_cost)]
				button.custom_minimum_size.y = 44 * _scale
				button.add_theme_stylebox_override("normal", _button_style(Color("#277C9B")))
				button.pressed.connect(_speed_up_component_slot.bind(component, index))
				_content.add_child(button)
		else:
			var production_quote := building.get_legacy_production_speedup_quote()
			if not production_quote.is_empty():
				found = true
				_add_speedup_button("Finish %s production" % str(building.current_product), production_quote, building.speed_up_legacy_production)
		var construction_quote := building.get_construction_speedup_quote()
		if not construction_quote.is_empty():
			found = true
			_add_speedup_button("Finish %s construction" % str(building.definition.get("name", building.building_type)), construction_quote, building.speed_up_construction)
		var upgrade_quote := building.get_upgrade_speedup_quote()
		if not upgrade_quote.is_empty():
			found = true
			_add_speedup_button("Finish %s upgrade" % str(building.definition.get("name", building.building_type)), upgrade_quote, building.speed_up_upgrade)
	if not found:
		_content.add_child(_notice("No active timers", "Start production, construct a building or begin an upgrade to see instant-finish offers here."))

func _add_speedup_button(label_text: String, quote: Dictionary, callback: Callable) -> void:
	var button := Button.new()
	button.text = "%s · %ds · %d SimCash" % [label_text, int(quote.remaining_seconds), int(quote.simcash_cost)]
	button.custom_minimum_size.y = 44 * _scale
	button.add_theme_stylebox_override("normal", _button_style(Color("#277C9B")))
	button.pressed.connect(_run_building_speedup.bind(callback))
	_content.add_child(button)

func _run_building_speedup(callback: Callable) -> void:
	var result: Dictionary = callback.call()
	if not bool(result.get("success", false)):
		_status.text = "Speed-up failed: %s" % str(result.get("reason", "not available"))
		return
	_build_shell("CITY PROGRESS BOOSTED", "SimCash was spent and the selected timer was completed.")
	_content.add_child(_notice("Time saved", "%d SimCash spent." % int(result.get("cost", 0))))
	_add_store_return_button()
	if has_node("/root/SaveManager"):
		SaveManager.save_game()

func _speed_up_component_slot(component: ProductionComponent, slot_index: int) -> void:
	var result := component.speed_up_slot(slot_index)
	if not bool(result.get("success", false)):
		_status.text = "Speed-up failed: %s" % str(result.get("reason", "not available"))
		return
	_build_shell("PRODUCTION COMPLETED", "The finished item is waiting to be collected.")
	_content.add_child(_notice("Ready to collect", "%s · %d SimCash spent" % [str(ProductionManager.get_item_definition(str(result.get("item_id", ""))).get("name", "Item")), int(result.get("cost", 0))]))
	_add_store_return_button()
	if has_node("/root/SaveManager"):
		SaveManager.save_game()

func _add_store_slot_expansions() -> void:
	var found := false
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or not (building.production_component is ProductionComponent):
			continue
		var component: ProductionComponent = building.production_component
		var cost := component.get_next_store_queue_slot_cost()
		if cost <= 0:
			continue
		found = true
		var button := Button.new()
		button.text = "%s · Add slot %d · %d SimCash" % [str(building.definition.get("name", building.building_type)), component.get_slot_count() + 1, cost]
		button.custom_minimum_size.y = 42 * _scale
		button.add_theme_stylebox_override("normal", _button_style(Color("#277C9B")))
		button.pressed.connect(_purchase_store_slot.bind(component, cost))
		_content.add_child(button)
	if not found:
		_content.add_child(_notice("No eligible commercial stores", "Build a supported commercial building to expand its production queue."))

func _purchase_store_slot(component: ProductionComponent, cost: int) -> void:
	if not component.purchase_store_queue_slot(cost):
		_status.text = "Slot purchase failed. Check SimCash and store capacity."
		return
	if has_node("/root/SaveManager"):
		SaveManager.save_game()
	open_store()

func _show_history() -> void:
	_build_shell("PURCHASE HISTORY", "Local sandbox order history saved with your city.")
	var recent := PaymentManager.get_recent_orders(20)
	if recent.is_empty():
		_content.add_child(_notice("No orders yet", "Your test purchases will appear here after an order is created."))
	else:
		for order in recent:
			_content.add_child(_notice(str(order.get("product_name", "SimCash order")), "%s SimCash · %s · %s" % [_fmt(int(order.get("grant_amount", 0))), str(order.get("status", "")).to_upper(), Time.get_datetime_string_from_unix_time(int(order.get("created_at", 0)))]))
	_add_store_return_button()

func _add_store_return_button() -> void:
	var button := Button.new()
	button.text = "RETURN TO STORE"
	button.custom_minimum_size.y = 46 * _scale
	button.add_theme_stylebox_override("normal", _button_style(Color("#40566A")))
	button.pressed.connect(open_store)
	_content.add_child(button)

func _balance_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _inner_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	row.add_child(_balance_item("simcash_bundle.png", EconomyManager.sim_cash, "SimCash"))
	row.add_child(_balance_item("simoleons_coins.png", EconomyManager.simoleons, "Simoleons"))
	return panel

func _balance_item(asset_name: String, amount: int, currency_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38) * _scale
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://assets/icons/ui/currency/" + asset_name
	icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else Icons.get_icon_tex("money" if currency_name == "SimCash" else "simoleons")
	row.add_child(icon)
	row.add_child(_label("%s  %s" % [_fmt(amount), currency_name], 16, Color.WHITE))
	return row

func _notice(title_text: String, body_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _inner_style())
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)
	stack.add_child(_label(title_text, 15, Color("#FFE29A")))
	var body := _label(body_text, 13, Color("#E2EFF7"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(body)
	return panel

func _label(value: String, size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", int(size * _scale))
	label.add_theme_color_override("font_color", tint)
	return label

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102B43")
	style.border_color = Color("#69B9D9")
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 16 * _scale
	style.content_margin_right = 16 * _scale
	style.content_margin_top = 13 * _scale
	style.content_margin_bottom = 13 * _scale
	return style

func _inner_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1B405B")
	style.border_color = Color("#5A8FAE")
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.content_margin_left = 10 * _scale
	style.content_margin_right = 10 * _scale
	style.content_margin_top = 8 * _scale
	style.content_margin_bottom = 8 * _scale
	return style

func _button_style(tint: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = tint.lightened(0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style

func _flat_style(tint: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	return style

func _fmt(value: int) -> String:
	return "%s" % value
