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

const WEAPON_EAST_RECEPTOR: Array[Dictionary] = [
	{"direction": "EAST", "accepts_type": "WEAPON", "modifier_pct": 15.0},
]
const WEAPON_WEST_RECEPTOR: Array[Dictionary] = [
	{"direction": "WEST", "accepts_type": "WEAPON", "modifier_pct": 15.0},
]

const SAMPLE_BENCH_ITEMS: Array[Dictionary] = [
	{"item_id": "preview-1", "name": "Shortsword", "item_type": "WEAPON", "weapon_category": "MELEE", "level": 1, "dimensions": {"width": 1, "height": 1}, "placement_coords": null, "synergy_receptors": WEAPON_EAST_RECEPTOR, "sell_price": 2},
	{"item_id": "preview-2", "name": "Longbow", "item_type": "WEAPON", "weapon_category": "RANGED", "level": 1, "dimensions": {"width": 1, "height": 1}, "placement_coords": null, "synergy_receptors": WEAPON_WEST_RECEPTOR},
	{"item_id": "preview-3", "name": "Arcane Staff", "item_type": "WEAPON", "weapon_category": "ARCANE", "level": 2, "dimensions": {"width": 1, "height": 1}, "placement_coords": null, "synergy_receptors": WEAPON_EAST_RECEPTOR},
	{"item_id": "preview-4", "name": "Iron Buckler", "item_type": "ARMOR", "weapon_category": "", "level": 1, "dimensions": {"width": 1, "height": 1}, "placement_coords": null, "sell_price": 2},
	{"item_id": "preview-5", "name": "Healing Draught", "item_type": "POTION", "weapon_category": "", "level": 1, "dimensions": {"width": 1, "height": 1}, "placement_coords": null},
	{"item_id": "preview-6", "name": "Hunting Spear", "item_type": "WEAPON", "weapon_category": "MELEE", "level": 2, "dimensions": {"width": 1, "height": 2}, "placement_coords": null},
]

const SAMPLE_SHOP_SLOTS: Array[Dictionary] = [
	{"template_name": "Shortsword", "item_type": "WEAPON", "weapon_category": "MELEE", "buy_price": 3, "base_attributes": {"base_dmg": 12.0}},
	{"template_name": "Longbow", "item_type": "WEAPON", "weapon_category": "RANGED", "buy_price": 3, "base_attributes": {"base_dmg": 16.0}},
	{"template_name": "Iron Buckler", "item_type": "ARMOR", "weapon_category": "", "buy_price": 2, "base_attributes": {"armor_rating": 20.0}},
	{"template_name": "Ember Wand", "item_type": "WEAPON", "weapon_category": "ARCANE", "buy_price": 9, "base_attributes": {"base_dmg": 24.0}},
]

# Contract-shaped purchase payload for offline regression (merges may be empty).
const SAMPLE_PURCHASE_NO_MERGE: Dictionary = {
	"new_balance": 4,
	"merges": [],
	"updated_grid": {
		"bench_reserve": [],
		"columns": 5,
		"rows": 5,
	},
}

var _grid: Control
var _validate_grid_call_count: int = 0

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
	ApiClient.validate_grid_failed.disconnect(_grid._on_validate_grid_failed)
	ApiClient.validate_grid_completed.connect(func(_data: Dictionary) -> void:
		_validate_grid_call_count += 1
	)
	ApiClient.validate_grid_failed.connect(func(_code: int, _reason: String) -> void:
		_validate_grid_call_count += 1
	)
	for _i in 40:
		await get_tree().process_frame

	await _assert_merge_regressions()
	await _assert_auto_arrange_single_validate()
	_reset_harness_grid()

	for _i in 40:
		await get_tree().process_frame

	# Place a receptor-equipped pair so mid-drag preview has a neighbor to link.
	_auto_place_item("preview-1", Vector2i(1, 1))
	for _i in 20:
		await get_tree().process_frame
	_auto_place_item("preview-2", Vector2i(2, 1))
	for _i in 20:
		await get_tree().process_frame

	# Mid-drag screenshot: hover Arcane Staff west of Shortsword for preview strip.
	# Start/end via the same direct scene-handler path `_auto_place_item_by_card`
	# uses - do NOT mix that with simulated mouse-up. ItemCard._dragging is only
	# set inside ItemCard._begin_drag(), so a simulated release + force_end_drag
	# no-ops and leaves the card stuck mid-drag with a stale preview strip.
	var drag_card := _bench_card_for_id("preview-3")
	var hover_cell: GridCell = null
	if drag_card != null:
		_simulate_mouse_button(MOUSE_BUTTON_LEFT, true)
		_grid._on_card_drag_started(drag_card)
		hover_cell = _grid._cell_at(0, 1)
		drag_card.global_position = hover_cell.get_global_rect().get_center() - drag_card.size / 2.0
		for _i in 25:
			await get_tree().process_frame
		var preview_count: int = _grid._preview_borders.size()
		print("auto-verify: %d preview border(s) mid-drag (anchor=%s)" % [
			preview_count, str(_grid._highlight_anchor)])
		if preview_count <= 0:
			push_error("auto-verify: expected preview synergy border mid-drag, got 0")
		# Save the screenshot while the mouse is still held so the preview strip is visible.
		_save_png(screenshot_path)
		# End the same way we started: direct scene-handler call (not simulated mouse-up).
		_grid._on_card_drag_ended(drag_card, hover_cell.get_global_rect().get_center())
		_simulate_mouse_button(MOUSE_BUTTON_LEFT, false)
		for _i in 10:
			await get_tree().process_frame
		if _grid._preview_borders.size() != 0:
			push_error("auto-verify: preview borders must clear after drag end (got %d)" %
				_grid._preview_borders.size())
		else:
			print("auto-verify: preview borders cleared after drag end")

	# Recycler sell-price preview: hover a bench item over the recycler panel.
	# preview-1/2/3 are on the grid after the synergy block; use preview-4 (still on bench).
	var sell_drag_card := _bench_card_for_id("preview-4")
	if sell_drag_card != null:
		_simulate_mouse_button(MOUSE_BUTTON_LEFT, true)
		_grid._on_card_drag_started(sell_drag_card)
		var recycler_center: Vector2 = _grid.get_node("%RecyclerPanel").get_global_rect().get_center()
		sell_drag_card.global_position = recycler_center - sell_drag_card.size / 2.0
		for _i in 15:
			await get_tree().process_frame
		var label_text: String = _grid.get_node("%RecyclerLabel").text
		print("auto-verify: recycler label mid-hover = '%s'" % label_text)
		if not label_text.begins_with("SELL: +"):
			push_error("auto-verify: expected recycler label to show a sell-price preview, got '%s'" % label_text)
		_save_png(_sell_preview_path_for(screenshot_path))
		_grid._on_card_drag_ended(sell_drag_card, recycler_center)
		_simulate_mouse_button(MOUSE_BUTTON_LEFT, false)
		for _i in 10:
			await get_tree().process_frame
		var reset_text: String = _grid.get_node("%RecyclerLabel").text
		if reset_text.begins_with("SELL: +"):
			push_error("auto-verify: recycler label must reset after drag end, still showing '%s'" % reset_text)
	else:
		push_error("auto-verify: no bench card for preview-4 (sell-price preview)")

	_grid._on_validate_grid_completed(ApiClient.normalize_validate_grid_response({"synergies": [
		{"source_item_id": "preview-1", "target_item_id": "preview-2",
			"direction": "EAST", "modifier_pct": 15.0},
	]}))
	for _i in 30:
		await get_tree().process_frame

	var grid_bottom: float = _grid._grid_area.position.y + _grid._grid_area.size.y
	var bench_top: float = _grid.get_node("%BenchRow").offset_top
	print("auto-verify: grid %dx%d cell=%.0f grid_bottom=%.0f bench_top=%.0f gap=%.0f" % [
		_grid.grid_rows, _grid.grid_columns, _grid._layout_cell_size.y,
		grid_bottom, bench_top, bench_top - grid_bottom])
	print("auto-verify: %d synergy border(s) on screen" % _grid._synergy_borders.size())
	print("auto-verify: %d preview border(s) after drag end" % _grid._preview_borders.size())
	print("auto-verify: %d shop card(s) on screen" % _grid.get_node("%ShopRow").get_child_count())
	# Keep the mid-drag screenshot as the primary artifact; also save a
	# separate confirmed-synergy/layout artifact for regression coverage.
	_save_and_quit(_confirmed_path_for(screenshot_path))

func _confirmed_path_for(path: String) -> String:
	if path.ends_with(".png"):
		return path.substr(0, path.length() - 4) + "_confirmed.png"
	return path + "_confirmed.png"

func _sell_preview_path_for(path: String) -> String:
	if path.ends_with(".png"):
		return path.substr(0, path.length() - 4) + "_sell_preview.png"
	return path + "_sell_preview.png"

func _reset_harness_grid() -> void:
	_grid.queue_free()
	GameState.bench_items = SAMPLE_BENCH_ITEMS.duplicate(true)
	GameState.equipped_items = []
	_instance_grid()
	ApiClient.validate_grid_failed.disconnect(_grid._on_validate_grid_failed)

func _assert_merge_regressions() -> void:
	var bench_snapshot := GameState.bench_items.duplicate(true)
	var no_merge_payload := SAMPLE_PURCHASE_NO_MERGE.duplicate(true)
	no_merge_payload["updated_grid"]["bench_reserve"] = bench_snapshot
	var rings_before := _count_tier_rings()
	_grid._on_purchase_item_completed(no_merge_payload)
	for _i in 30:
		await get_tree().process_frame
	var rings_after_empty := _count_tier_rings() - rings_before
	if rings_after_empty != 0:
		push_error("auto-verify: empty merges[] must produce zero merge flashes (got %d)" % rings_after_empty)
	else:
		print("auto-verify: empty merges[] produced zero flashes")

	var dual_merge_payload := {
		"new_balance": 1,
		"merges": [
			{"consumed_item_ids": ["a", "b", "c"], "produced_item": {
				"item_id": "preview-3", "name": "Arcane Staff", "level": 2}},
			{"consumed_item_ids": ["d", "e", "f"], "produced_item": {
				"item_id": "preview-6", "name": "Hunting Spear", "level": 3}},
		],
		"updated_grid": {
			"bench_reserve": bench_snapshot,
			"columns": GameState.grid_columns,
			"rows": GameState.grid_rows,
		},
	}
	rings_before = _count_tier_rings()
	_grid._on_purchase_item_completed(dual_merge_payload)
	await get_tree().create_timer(0.05).timeout
	var after_first := _count_tier_rings() - rings_before
	await get_tree().create_timer(_grid.merge_flash_stagger + 0.05).timeout
	var after_second := _count_tier_rings() - rings_before
	if after_first < 1 or after_second < 2:
		push_error("auto-verify: two merges[] entries must produce two staggered tier rings (peaks %d, %d)" % [
			after_first, after_second])
	else:
		print("auto-verify: two merges[] produced staggered tier rings (peaks %d, %d)" % [
			after_first, after_second])

func _assert_auto_arrange_single_validate() -> void:
	# Reset grid so AUTO has a full bench to place.
	for child in _grid.get_node("%GridContainer").get_children():
		for c in child.get_children():
			if c is ItemCard:
				child.remove_child(c)
				c.queue_free()
	GameState.equipped_items.clear()
	_grid._occupancy.clear()
	for cell: GridCell in _grid._cells:
		cell.set_occupied(false)
	GameState.bench_items = SAMPLE_BENCH_ITEMS.duplicate(true)
	_grid._render_bench()
	for _i in 20:
		await get_tree().process_frame

	var calls_before := _validate_grid_call_count
	_grid._on_auto_arrange_pressed()
	for _i in 60:
		await get_tree().process_frame
	var delta := _validate_grid_call_count - calls_before
	if delta != 1:
		push_error("auto-verify: AUTO must fire exactly one validate_grid (got %d)" % delta)
	else:
		print("auto-verify: AUTO fired exactly one validate_grid call")

func _count_tier_rings() -> int:
	var n := 0
	for child in _grid.get_node("%DragLayer").get_children():
		if child is TierRing:
			n += 1
	return n

func _run_live_verify(screenshot_path: String) -> void:
	GameState.current_round = 1
	GameState.gold_awarded_round = GameState.current_round
	var state := {"authed": false}
	ApiClient.authenticate_completed.connect(func(data: Dictionary) -> void:
		GameState.hydrate_from_auth(data)
		state["authed"] = true, CONNECT_ONE_SHOT)
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
	for _i in 240:
		if _grid.get_node("%ShopRow").get_child_count() > 0:
			break
		await get_tree().process_frame
	if _grid.get_node("%ShopRow").get_child_count() == 0:
		printerr("live-verify: shop did not populate")
		get_tree().quit(1)
		return

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

		for _i in 240:
			if validate_state["has_synergy"]:
				break
			await get_tree().process_frame

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

func _simulate_mouse_button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = get_viewport().get_mouse_position()
	Input.parse_input_event(event)

func _bench_card_for_name(item_name: String) -> ItemCard:
	for child in _grid.get_node("%BenchRow").get_children():
		var candidate := child as ItemCard
		if candidate != null and String(candidate.get("_item_data").get("name", "")) == item_name:
			return candidate
	return null

func _bench_card_for_id(item_id: String) -> ItemCard:
	for child in _grid.get_node("%BenchRow").get_children():
		var candidate := child as ItemCard
		if candidate != null and String(candidate.get("_item_data").get("item_id", "")) == item_id:
			return candidate
	return null

func _auto_place_item_by_card(card: ItemCard, cell_coords: Vector2i) -> void:
	var cell: GridCell = _grid._cell_at(cell_coords.x, cell_coords.y)
	_grid._on_card_drag_started(card)
	_grid._on_card_drag_ended(card, cell.get_global_rect().get_center())

func _auto_place_item(item_id: String, cell_coords: Vector2i) -> void:
	var card := _bench_card_for_id(item_id)
	if card == null:
		push_error("auto-verify: no bench card for item_id %s" % item_id)
		return
	_auto_place_item_by_card(card, cell_coords)

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
	_save_png(screenshot_path)
	await AudioManager.release_bgm_before_quit()
	get_tree().quit()

func _save_png(screenshot_path: String) -> void:
	var tex := get_viewport().get_texture()
	if tex != null:
		var image := tex.get_image()
		if image != null:
			image.save_png(screenshot_path)
			print("auto-verify: screenshot saved to ", screenshot_path)
			return
		print("auto-verify: no image buffer (headless) - skipping screenshot")
		return
	print("auto-verify: no viewport texture (headless) - skipping screenshot")
