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
	{"item_id": "preview-1", "name": "Shortsword", "item_type": "WEAPON", "weapon_category": "MELEE", "level": 1, "placement_coords": null},
	{"item_id": "preview-2", "name": "Longbow", "item_type": "WEAPON", "weapon_category": "RANGED", "level": 1, "placement_coords": null},
	{"item_id": "preview-3", "name": "Arcane Staff", "item_type": "WEAPON", "weapon_category": "ARCANE", "level": 2, "placement_coords": null},
	{"item_id": "preview-4", "name": "Iron Buckler", "item_type": "ARMOR", "weapon_category": "", "level": 1, "placement_coords": null},
	{"item_id": "preview-5", "name": "Healing Draught", "item_type": "POTION", "weapon_category": "", "level": 1, "placement_coords": null},
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
	GameState.current_round = 3
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
	_auto_place(0, Vector2i(1, 1))
	for _i in 20:
		await get_tree().process_frame
	_auto_place(0, Vector2i(2, 1))
	# No Go server in this harness, so exercise the synergy glow shader +
	# chime path by injecting a validate_grid response shaped like the real one.
	_grid._on_validate_grid_completed({"synergies": [
		{"source_item_id": "preview-1", "target_item_id": "preview-2",
			"direction": "EAST", "modifier_pct": 0.25},
	]})
	for _i in 50:
		await get_tree().process_frame
	print("auto-verify: %d synergy border(s) on screen" % _grid._synergy_borders.size())
	print("auto-verify: %d shop card(s) on screen" % _grid.get_node("%ShopRow").get_child_count())
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

	_instance_grid()
	# Real award_round_gold + roll_shop round-trips.
	for _i in 90:
		await get_tree().process_frame

	# Buy the cheapest affordable slot for real.
	var cheapest: Dictionary = {}
	for card: ItemCard in _grid.get_node("%ShopRow").get_children():
		var slot: Dictionary = card.get("_item_data")
		var price := int(slot.get("buy_price", 999999))
		if price <= GameState.gold and (cheapest.is_empty() or price < int(cheapest.get("buy_price", 999999))):
			cheapest = slot
	if cheapest.is_empty():
		printerr("live-verify: no affordable slot")
	else:
		_grid._on_shop_card_pressed(cheapest)
	for _i in 90:
		await get_tree().process_frame

	# Place the purchased item on the grid; the real validate_grid response
	# drives any synergy glow.
	if _grid.get_node("%BenchRow").get_child_count() > 0:
		_auto_place(0, Vector2i(1, 1))
	for _i in 60:
		await get_tree().process_frame

	print("live-verify: gold=%d bench=%d equipped=%d slots=%d status=%s" % [
		GameState.gold,
		GameState.bench_items.size(),
		GameState.equipped_items.size(),
		_grid.get_node("%ShopRow").get_child_count(),
		_grid.get_node("%StatusLabel").text])
	_save_and_quit(screenshot_path)

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
	var image := get_viewport().get_texture().get_image()
	image.save_png(screenshot_path)
	print("auto-verify: screenshot saved to ", screenshot_path)
	get_tree().quit()
