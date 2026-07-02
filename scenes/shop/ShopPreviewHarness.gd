extends Control

# Dev-only: instances ShopScene for F6 preview and scripted screenshot checks
# (same pattern as the grid-prep and main-menu harnesses).
#
# Modes (both save a PNG then quit):
#   SYNGRID_SCREENSHOT=/path/out.png                  - offline: injects fake
#       roll/purchase/sell responses and drives the buy, triple-merge, and
#       drag-to-recycler flows with no Go server.
#   SYNGRID_SCREENSHOT=/path/out.png SYNGRID_LIVE=1   - live: authenticates,
#       lets the real server grant gold + roll the shop, buys the cheapest
#       affordable slot for real.

var _shop: ShopScene

func _ready() -> void:
	if OS.get_environment("SYNGRID_SCREENSHOT") != "" and OS.get_environment("SYNGRID_LIVE") == "1":
		_run_live_verify(OS.get_environment("SYNGRID_SCREENSHOT"))
		return
	_seed_offline_state()
	_instance_shop()
	if OS.get_environment("SYNGRID_SCREENSHOT") != "":
		_run_offline_verify(OS.get_environment("SYNGRID_SCREENSHOT"))

func _seed_offline_state() -> void:
	GameState.player_id = "preview-player"
	GameState.current_round = 2
	GameState.gold = 9
	GameState.life_points = 4
	GameState.triumph_count = 1
	GameState.gold_awarded_round = 2   # suppress the real round-grant call
	GameState.current_shop_slots = []
	GameState.shop_round = 0
	GameState.equipped_items = []
	GameState.bench_items = [
		{"item_id": "bench-sword-1", "name": "Shortsword", "item_type": "WEAPON",
			"weapon_category": "MELEE", "level": 1, "placement_coords": null},
		{"item_id": "bench-sword-2", "name": "Shortsword", "item_type": "WEAPON",
			"weapon_category": "MELEE", "level": 1, "placement_coords": null},
		{"item_id": "bench-buckler", "name": "Iron Buckler", "item_type": "ARMOR",
			"weapon_category": "", "level": 1, "placement_coords": null},
	]

func _instance_shop() -> void:
	var shop_scene: PackedScene = preload("res://scenes/shop/ShopScene.tscn")
	_shop = shop_scene.instantiate()
	add_child(_shop)

func _run_offline_verify(screenshot_path: String) -> void:
	# The scene's _ready fired real roll/award calls with no valid session -
	# unhook the failure handlers so injected happy-path state wins.
	ApiClient.roll_shop_failed.disconnect(_shop._on_roll_shop_failed)
	ApiClient.award_round_gold_failed.disconnect(_shop._on_award_round_gold_failed)
	ApiClient.purchase_item_failed.disconnect(_shop._on_purchase_item_failed)
	ApiClient.sell_item_failed.disconnect(_shop._on_sell_item_failed)
	for _i in 30:
		await get_tree().process_frame

	# 1. Shop roll pops in with the reroll clatter.
	_shop._on_roll_shop_completed({"slots": [
		{"template_name": "Shortsword", "item_type": "WEAPON", "weapon_category": "MELEE",
			"buy_price": 3, "base_attributes": {"base_dmg": 12.0, "act_cooldown": 15.0}},
		{"template_name": "Longbow", "item_type": "WEAPON", "weapon_category": "RANGED",
			"buy_price": 3, "base_attributes": {"base_dmg": 16.0, "act_cooldown": 22.0}},
		{"template_name": "Iron Buckler", "item_type": "ARMOR", "weapon_category": "",
			"buy_price": 2, "base_attributes": {"armor_rating": 20.0}},
		{"template_name": "Ember Wand", "item_type": "WEAPON", "weapon_category": "ARCANE",
			"buy_price": 4, "base_attributes": {"base_dmg": 24.0, "act_cooldown": 30.0, "mana_cost": 30.0}},
	]})
	for _i in 30:
		await get_tree().process_frame

	# 2. Buying a third Shortsword triggers the server-side triple-merge:
	# the trio is destroyed and one unseen Level 2 item returns.
	_shop._on_purchase_item_completed({
		"new_balance": 6,
		"updated_grid": {"bench_reserve": [
			{"item_id": "bench-buckler", "name": "Iron Buckler", "item_type": "ARMOR",
				"weapon_category": "", "level": 1, "placement_coords": null},
			{"item_id": "merged-sword-lv2", "name": "Shortsword", "item_type": "WEAPON",
				"weapon_category": "MELEE", "level": 2, "placement_coords": null},
		]},
	})
	for _i in 40:
		await get_tree().process_frame

	# 3. Drag the buckler onto the recycler and complete the sell.
	var buckler: ItemCard = null
	for card: ItemCard in _shop.get_node("%BenchRow").get_children():
		if card.get("_item_data").get("item_id", "") == "bench-buckler":
			buckler = card
			break
	if buckler != null:
		_shop._on_card_drag_started(buckler)
		_shop._on_card_drag_ended(buckler,
			_shop.get_node("%RecyclerPanel").get_global_rect().get_center())
		_shop._on_sell_item_completed({
			"new_balance": 7,
			"updated_grid": {"bench_reserve": [
				{"item_id": "merged-sword-lv2", "name": "Shortsword", "item_type": "WEAPON",
					"weapon_category": "MELEE", "level": 2, "placement_coords": null},
			]},
		})
	else:
		push_error("auto-verify: buckler card not found on bench")
	for _i in 40:
		await get_tree().process_frame

	print("auto-verify: bench card count=%d status=%s" % [
		_shop.get_node("%BenchRow").get_child_count(),
		_shop.get_node("%StatusLabel").text])
	_save_and_quit(screenshot_path)

func _run_live_verify(screenshot_path: String) -> void:
	GameState.current_round = 1
	# Lambdas capture locals by value in GDScript; a Dictionary is shared by
	# reference so the signal handler's write is visible to the wait loop.
	var state := {"authed": false}
	ApiClient.authenticate_completed.connect(func(data: Dictionary) -> void:
		GameState.hydrate_from_auth(data)
		state["authed"] = true, CONNECT_ONE_SHOT)
	ApiClient.authenticate(GameState.get_or_create_device_id())
	for _i in 120:
		if state["authed"]:
			break
		await get_tree().process_frame
	if not state["authed"]:
		printerr("live-verify: authenticate did not complete")
		get_tree().quit(1)
		return

	_instance_shop()
	# Real award_round_gold + roll_shop round-trips.
	for _i in 90:
		await get_tree().process_frame

	# Buy the cheapest affordable slot for real.
	var cheapest: Dictionary = {}
	for card: ItemCard in _shop.get_node("%ShopRow").get_children():
		var slot: Dictionary = card.get("_item_data")
		var price := int(slot.get("buy_price", 999999))
		if price <= GameState.gold and (cheapest.is_empty() or price < int(cheapest.get("buy_price", 999999))):
			cheapest = slot
	if cheapest.is_empty():
		printerr("live-verify: no affordable slot")
	else:
		_shop._on_shop_card_pressed(cheapest)
	for _i in 90:
		await get_tree().process_frame

	print("live-verify: gold=%d bench=%d slots=%d status=%s" % [
		GameState.gold,
		GameState.bench_items.size(),
		_shop.get_node("%ShopRow").get_child_count(),
		_shop.get_node("%StatusLabel").text])
	_save_and_quit(screenshot_path)

func _save_and_quit(screenshot_path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(screenshot_path)
	print("auto-verify: screenshot saved to ", screenshot_path)
	get_tree().quit()
