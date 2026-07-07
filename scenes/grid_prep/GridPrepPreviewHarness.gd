extends Control

# Dev-only: seeds GameState with sample data then instances GridPrepScene
# (the merged shop + grid prep screen), so shop, placement, drag, snap, and
# synergy feel can be checked with F6. Not one of the production screens.
#
# Modes (both save a PNG then quit):
#   SYNGRID_SCREENSHOT=/path/out.png                  - offline: seeded shop
#       cache + bench, drives placements, injects a validate_grid response.
#   SYNGRID_SCREENSHOT=/path/out.png SYNGRID_LIVE=1   - live: authenticates,
#       real round grant + shop roll, buys the cheapest slot, places it.

const SAMPLE_BENCH_ITEMS: Array[Dictionary] = [
	{"item_id": "preview-1", "name": "Shortsword", "item_type": "WEAPON", "weapon_category": "MELEE", "level": 1, "dimensions": {"width": 1, "height": 1}, "placement_coords": null},
	{"item_id": "preview-2", "name": "Longbow", "item_type": "WEAPON", "weapon_category": "RANGED", "level": 1, "dimensions": {"width": 1, "height": 1}, "placement_coords": null},
	{"item_id": "preview-3", "name": "Arcane Staff", "item_type": "WEAPON", "weapon_category": "ARCANE", "level": 2, "dimensions": {"width": 1, "height": 1}, "placement_coords": null},
	{"item_id": "preview-4", "name": "Iron Buckler", "item_type": "ARMOR", "weapon_category": "", "level": 1, "dimensions": {"width": 1, "height": 1}, "placement_coords": null},
	{"item_id": "preview-5", "name": "Healing Draught", "item_type": "POTION", "weapon_category": "", "level": 1, "dimensions": {"width": 1, "height": 1}, "placement_coords": null},
	{"item_id": "preview-6", "name": "Hunting Spear", "item_type": "WEAPON", "weapon_category": "MELEE", "level": 2, "dimensions": {"width": 1, "height": 2}, "placement_coords": null},
]

const SAMPLE_SHOP_SLOTS: Array[Dictionary] = [
	{"template_name": "Shortsword", "item_type": "WEAPON", "weapon_category": "MELEE", "buy_price": 3, "base_attributes": {"base_dmg": 12.0}},
	{"template_name": "Longbow", "item_type": "WEAPON", "weapon_category": "RANGED", "buy_price": 3, "base_attributes": {"base_dmg": 16.0}},
	{"template_name": "Iron Buckler", "item_type": "ARMOR", "weapon_category": "", "buy_price": 2, "base_attributes": {"armor_rating": 20.0}},
	{"template_name": "Ember Wand", "item_type": "WEAPON", "weapon_category": "ARCANE", "buy_price": 9, "base_attributes": {"base_dmg": 24.0}},
]

var _grid: Control

func _ready() -> void:
	if OS.get_environment("SYNGRID_SCREENSHOT") != "" and OS.get_environment("SYNGRID_LIVE") == "1":
		_run_live_verify(OS.get_environment("SYNGRID_SCREENSHOT"))
		return

	GameState.player_id = "preview-player"
	var grid_size := 5
	if OS.get_environment("SYNGRID_GRID_SIZE") != "":
		grid_size = int(OS.get_environment("SYNGRID_GRID_SIZE"))
	GameState.current_round = maxi(4, grid_size)
	GameState.grid_columns = grid_size
	GameState.grid_rows = grid_size
	GameState.gold = 7
	GameState.life_points = 4
	GameState.triumph_count = 2
	GameState.bench_items = SAMPLE_BENCH_ITEMS.duplicate(true)
	GameState.equipped_items = []
	# Pre-seed the round grant and shop cache so the offline scene renders the
	# shop row without any network round-trip (the Ember Wand at 9g also
	# exercises the unaffordable dim at 7 gold).
	GameState.gold_awarded_round = GameState.current_round
	GameState.current_shop_slots = SAMPLE_SHOP_SLOTS.duplicate(true)
	GameState.shop_round = GameState.current_round

	_instance_grid()

	if OS.get_environment("SYNGRID_SCREENSHOT") != "":
		_run_offline_verify(OS.get_environment("SYNGRID_SCREENSHOT"))

func _instance_grid() -> void:
	var grid_scene: PackedScene = preload("res://scenes/grid_prep/GridPrepScene.tscn")
	_grid = grid_scene.instantiate()
	add_child(_grid)

func _run_offline_verify(screenshot_path: String) -> void:
	# The placements below fire real validate_grid calls that fail without the
	# Go server, and the failure handler clears synergy borders - unhook it so
	# the injected synergy stays visible for the screenshot.
	ApiClient.validate_grid_failed.disconnect(_grid._on_validate_grid_failed)
	# Let card pops, theme, and BGM settle.
	for _i in 40:
		await get_tree().process_frame
	# Drive two real placements through the scene's drag lifecycle.
	# Place multi-cell spear first, then adjacent 1x1 weapons for synergy check.
	_auto_place_item("preview-6", Vector2i(0, 0))
	for _i in 20:
		await get_tree().process_frame
	_auto_place_item("preview-1", Vector2i(2, 1))
	for _i in 20:
		await get_tree().process_frame
	_auto_place_item("preview-2", Vector2i(3, 1))
	# No Go server in this harness, so exercise the synergy glow shader +
	# chime path by injecting a validate_grid response shaped like the real one.
	_grid._on_validate_grid_completed(ApiClient.normalize_validate_grid_response({"synergies": [
		{"source_item_id": "preview-1", "target_item_id": "preview-2",
			"direction": "EAST", "modifier_pct": 15.0},
	]}))
	for _i in 50:
		await get_tree().process_frame
	var grid_bottom: float = _grid._grid_area.position.y + _grid._grid_area.size.y
	var bench_top: float = _grid.get_node("%BenchRow").offset_top
	print("auto-verify: grid %dx%d cell=%.0f grid_bottom=%.0f bench_top=%.0f gap=%.0f" % [
		_grid.grid_rows, _grid.grid_columns, _grid._layout_cell_size.y,
		grid_bottom, bench_top, bench_top - grid_bottom])
	print("auto-verify: %d synergy border(s) on screen" % _grid._synergy_borders.size())
	print("auto-verify: %d shop card(s) on screen" % _grid.get_node("%ShopRow").get_child_count())
	_save_and_quit(screenshot_path)

func _run_live_verify(screenshot_path: String) -> void:
	# Live mode uses a real server. Authenticate gives us a starting balance,
	# and we intentionally SKIP the round-start gold grant here so the harness
	# can reliably afford purchases (otherwise the grant may overwrite the
	# balance depending on server rules).
	GameState.current_round = 1
	GameState.gold_awarded_round = GameState.current_round
	# Lambdas capture locals by value in GDScript; a Dictionary is shared by
	# reference so the signal handler's write is visible to the wait loop.
	var state := {"authed": false}
	ApiClient.authenticate_completed.connect(func(data: Dictionary) -> void:
		GameState.hydrate_from_auth(data)
		state["authed"] = true, CONNECT_ONE_SHOT)
	# Use a unique device id so the harness always starts from a fresh
	# server-side profile (avoids stale low-gold runs).
	var device_id := "live-harness-%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	GameState.player_id = device_id
	ApiClient.authenticate(device_id)
	for _i in 120:
		if state["authed"]:
			break
		await get_tree().process_frame
	if not state["authed"]:
		printerr("live-verify: authenticate did not complete")
		get_tree().quit(1)
		return

	_instance_grid()
	# Wait for the shop row to populate (roll_shop is async).
	for _i in 240:
		if _grid.get_node("%ShopRow").get_child_count() > 0:
			break
		await get_tree().process_frame
	if _grid.get_node("%ShopRow").get_child_count() == 0:
		printerr("live-verify: shop did not populate")
		get_tree().quit(1)
		return

	# Exercise live validate_grid synergies. Prefer the observed playtest pair,
	# but retry/reroll and fall back to buying/placing additional items instead
	# of silently producing an empty screenshot.
	var validate_state := {"has_synergy": false, "last_fail": ""}
	ApiClient.validate_grid_completed.connect(func(data: Dictionary) -> void:
		validate_state["has_synergy"] = not data.get("synergies", []).is_empty()
	)
	ApiClient.validate_grid_failed.connect(func(_code: int, reason: String) -> void:
		validate_state["last_fail"] = reason
	)

	var attempts := 0
	while attempts < 3 and not validate_state["has_synergy"]:
		attempts += 1

		# Attempt to buy a known-synergy pair if present/affordable.
		for template_name in ["Iron Sword", "Leather Armor"]:
			for card: ItemCard in _grid.get_node("%ShopRow").get_children():
				var slot: Dictionary = card.get("_item_data")
				if String(slot.get("template_name", "")) != template_name:
					continue
				if int(slot.get("buy_price", 999999)) > GameState.gold:
					break
				_grid._on_shop_card_pressed(slot)
				for _i in 45:
					await get_tree().process_frame
				break

		# Fallback: buy cheapest affordable until we have several bench items to place.
		var safety_iters := 0
		while _grid.get_node("%BenchRow").get_child_count() < 4 and safety_iters < 6:
			safety_iters += 1
			var cheapest: Dictionary = {}
			for card: ItemCard in _grid.get_node("%ShopRow").get_children():
				var slot: Dictionary = card.get("_item_data")
				var price := int(slot.get("buy_price", 999999))
				if price <= GameState.gold and (cheapest.is_empty() or price < int(cheapest.get("buy_price", 999999))):
					cheapest = slot
			if cheapest.is_empty():
				break
			_grid._on_shop_card_pressed(cheapest)
			for _i in 45:
				await get_tree().process_frame

		# Place the known pair explicitly adjacent if present.
		# Server bench ordering is not purchase ordering, so never rely on
		# bench index 0 here.
		var filled: Dictionary = {}
		var sword := _bench_card_for_name("Iron Sword")
		if sword != null:
			_auto_place_item_by_card(sword, Vector2i(1, 1))
			filled["1,1"] = true
			for _i in 30:
				await get_tree().process_frame
		var armor := _bench_card_for_name("Leather Armor")
		if armor != null:
			_auto_place_item_by_card(armor, Vector2i(2, 1))
			filled["2,1"] = true
			for _i in 30:
				await get_tree().process_frame

		# Fill remaining contiguous slots with whatever is left on the bench.
		# Keep x within grid columns (0-indexed).
		var max_x := maxi(0, GameState.grid_columns - 1)
		for x in range(1, max_x + 1):
			var key := "%d,%d" % [x, 1]
			if filled.has(key):
				continue
			if _grid.get_node("%BenchRow").get_child_count() == 0:
				break
			var cell: GridCell = _grid._cell_at(x, 1)
			if cell == null:
				continue
			_auto_place(0, Vector2i(x, 1))
			for _i in 30:
				await get_tree().process_frame

		# Wait for validate_grid to return at least one synergy.
		for _i in 240:
			if validate_state["has_synergy"]:
				break
			await get_tree().process_frame

		# If still no synergy, force a reroll and try again.
		if not validate_state["has_synergy"]:
			ApiClient.roll_shop(GameState.current_round)
			for _i in 90:
				await get_tree().process_frame

	if not validate_state["has_synergy"]:
		printerr("live-verify: did not exercise a synergy after %d attempt(s) (gold=%d bench=%d equipped=%d) - failing loud" % [
			attempts, GameState.gold, GameState.bench_items.size(), GameState.equipped_items.size()
		])
		if validate_state["last_fail"] != "":
			printerr("live-verify: last validate_grid_failed reason=%s" % validate_state["last_fail"])
		get_tree().quit(1)
		return

	for _i in 50:
		await get_tree().process_frame

	print("live-verify: gold=%d bench=%d equipped=%d slots=%d status=%s" % [
		GameState.gold,
		GameState.bench_items.size(),
		GameState.equipped_items.size(),
		_grid.get_node("%ShopRow").get_child_count(),
		_grid.get_node("%StatusLabel").text])
	_save_and_quit(screenshot_path)

func _bench_card_for_name(item_name: String) -> ItemCard:
	for child in _grid.get_node("%BenchRow").get_children():
		var candidate := child as ItemCard
		if candidate != null and String(candidate.get("_item_data").get("name", "")) == item_name:
			return candidate
	return null

func _auto_place_item_by_card(card: ItemCard, cell_coords: Vector2i) -> void:
	var cell: GridCell = _grid._cell_at(cell_coords.x, cell_coords.y)
	_grid._on_card_drag_started(card)
	_grid._on_card_drag_ended(card, cell.get_global_rect().get_center())

func _auto_place_item(item_id: String, cell_coords: Vector2i) -> void:
	var bench_row: HBoxContainer = _grid.get_node("%BenchRow")
	var card: ItemCard = null
	for child in bench_row.get_children():
		var candidate := child as ItemCard
		if candidate != null and candidate.get("_item_data").get("item_id", "") == item_id:
			card = candidate
			break
	if card == null:
		push_error("auto-verify: no bench card for item_id %s" % item_id)
		return
	var cell: GridCell = _grid._cell_at(cell_coords.x, cell_coords.y)
	_grid._on_card_drag_started(card)
	_grid._on_card_drag_ended(card, cell.get_global_rect().get_center())

func _auto_place(bench_idx: int, cell_coords: Vector2i) -> void:
	var bench_row: HBoxContainer = _grid.get_node("%BenchRow")
	if bench_row.get_child_count() <= bench_idx:
		push_error("auto-verify: no bench card at index %d" % bench_idx)
		return
	var card: ItemCard = bench_row.get_child(bench_idx)
	var cell: GridCell = _grid._cell_at(cell_coords.x, cell_coords.y)
	_grid._on_card_drag_started(card)
	_grid._on_card_drag_ended(card, cell.get_global_rect().get_center())

func _save_and_quit(screenshot_path: String) -> void:
	var tex := get_viewport().get_texture()
	if tex != null:
		var image := tex.get_image()
		if image != null:
			image.save_png(screenshot_path)
			print("auto-verify: screenshot saved to ", screenshot_path)
		else:
			print("auto-verify: no image buffer (headless) - skipping screenshot")
	else:
		print("auto-verify: no viewport texture (headless) - skipping screenshot")
	get_tree().quit()
