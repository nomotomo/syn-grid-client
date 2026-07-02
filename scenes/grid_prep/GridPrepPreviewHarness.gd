extends Control

# Dev-only: seeds GameState.bench_items with sample data then instances
# GridPrepScene, so placement/drag/snap/particle feel can be checked with F6
# with no Go server required. Not one of the six production screens.
#
# Auto-verify mode: set SYNGRID_SCREENSHOT=/path/out.png and run the scene;
# it drives a couple of placements through the scene's drag handlers, saves a
# screenshot, and quits - used for scripted visual checks from the CLI.

const SAMPLE_BENCH_ITEMS: Array[Dictionary] = [
	{"item_id": "preview-1", "name": "Shortsword", "item_type": "WEAPON", "weapon_category": "MELEE", "level": 1, "placement_coords": null},
	{"item_id": "preview-2", "name": "Longbow", "item_type": "WEAPON", "weapon_category": "RANGED", "level": 1, "placement_coords": null},
	{"item_id": "preview-3", "name": "Arcane Staff", "item_type": "WEAPON", "weapon_category": "ARCANE", "level": 2, "placement_coords": null},
	{"item_id": "preview-4", "name": "Iron Buckler", "item_type": "ARMOR", "weapon_category": "", "level": 1, "placement_coords": null},
	{"item_id": "preview-5", "name": "Healing Draught", "item_type": "POTION", "weapon_category": "", "level": 1, "placement_coords": null},
]

var _grid: Control

func _ready() -> void:
	GameState.player_id = "preview-player"
	GameState.current_round = 3
	GameState.gold = 7
	GameState.life_points = 4
	GameState.triumph_count = 2
	GameState.bench_items = SAMPLE_BENCH_ITEMS.duplicate(true)
	GameState.equipped_items = []

	var grid_scene: PackedScene = preload("res://scenes/grid_prep/GridPrepScene.tscn")
	_grid = grid_scene.instantiate()
	add_child(_grid)

	var screenshot_path := OS.get_environment("SYNGRID_SCREENSHOT")
	if screenshot_path != "":
		_run_auto_verify(screenshot_path)

func _run_auto_verify(screenshot_path: String) -> void:
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
	var image := get_viewport().get_texture().get_image()
	image.save_png(screenshot_path)
	print("auto-verify: screenshot saved to ", screenshot_path)
	get_tree().quit()

func _auto_place(bench_idx: int, cell_coords: Vector2i) -> void:
	var bench_row: HBoxContainer = _grid.get_node("%BenchRow")
	if bench_row.get_child_count() <= bench_idx:
		push_error("auto-verify: no bench card at index %d" % bench_idx)
		return
	var card: ItemCard = bench_row.get_child(bench_idx)
	var cell: GridCell = _grid._cell_at(cell_coords.x, cell_coords.y)
	_grid._on_card_drag_started(card)
	_grid._on_card_drag_ended(card, cell.get_global_rect().get_center())
