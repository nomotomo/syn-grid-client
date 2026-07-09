extends Control

# C4+C5 merged prep screen: shop requisition, drag-drop grid placement, and
# synergy shader glow on one screen (genre-standard: buy, then immediately
# place). Placement is entirely client-owned - the squish/bounce/particle
# plays on a locally-valid drop; validate_grid runs in the background purely
# to fetch synergy glow data. All prices, balances, and merge outcomes come
# from server responses. Juice: contract section 2 for every tween, section 3
# for the synergy shader, section 5 for the SFX matrix.

const ITEM_CARD_SCENE: PackedScene = preload("res://scenes/ui/ItemCard.tscn")
const SYNERGY_BORDER_SCENE: PackedScene = preload("res://scenes/ui/SynergyBorder.tscn")
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/MainMenu.tscn"
const COMBAT_REPLAY_SCENE_PATH: String = "res://scenes/combat_replay/CombatReplayScene.tscn"

@export var cell_size: Vector2 = Vector2(150, 150)
@export var grid_columns: int = 4
@export var grid_rows: int = 4
@export var shop_caption_ratio: float = 0.11
@export var grid_top_margin_ratio: float = 0.25
@export var section_gap: float = 24.0
@export var recycler_height: float = 100.0
@export var start_button_height: float = 140.0
@export var min_layout_cell_size: float = 72.0
@export var synergy_strip_width: float = 20.0
@export var caption_gap: float = 44.0
@export var snap_particle_lifetime: float = 0.3
@export var merge_particle_lifetime: float = 0.4
@export var synergy_chime_stagger: float = 0.08
@export var preview_intensity_scale: float = 0.5
@export var merge_flash_stagger: float = 0.35
@export var sell_shrink_duration: float = 0.15
@export var pending_sell_alpha: float = 0.5
@export var unaffordable_tint: Color = Color(0.45, 0.45, 0.5, 0.65)

@onready var _background: ColorRect = %Background
@onready var _stats_hud: StatsHud = %StatsHud
@onready var _shop_caption: Label = %ShopCaption
@onready var _shop_panel: PanelContainer = %ShopPanel
@onready var _shop_row: HBoxContainer = %ShopRow
@onready var _grid_caption: Label = %GridCaption
@onready var _grid_area: Control = %GridArea
@onready var _grid_container: GridContainer = %GridContainer
@onready var _synergy_layer: Control = %SynergyLayer
@onready var _bench_panel: PanelContainer = %BenchPanel
@onready var _bench_caption: Label = %BenchCaption
@onready var _bench_row: HBoxContainer = %BenchRow
@onready var _recycler_panel: PanelContainer = %RecyclerPanel
@onready var _start_match_button: Button = %StartMatchButton
@onready var _drag_layer: Control = %DragLayer
@onready var _status_label: Label = %StatusLabel
@onready var _hub_button: Button = %HubButton

var _auto_arrange_button: Button = null

var _cells: Array[GridCell] = []
var _coord_labels: Array[Label] = []
var _cards_by_item_id: Dictionary = {}
var _synergy_borders: Array[SynergyBorder] = []
var _preview_borders: Array[SynergyBorder] = []
var _known_synergy_keys: Dictionary = {}

var _dragging_card: ItemCard = null
var _dragging_origin: Node = null
var _highlighted_cells: Array[GridCell] = []
var _highlight_anchor: GridCell = null
var _highlight_valid: bool = true
var _occupancy: Dictionary = {}

var _start_button_was_ready: bool = false

var _purchase_in_flight: bool = false
var _match_in_flight: bool = false
var _pending_sell_card: ItemCard = null
var _known_bench_ids: Dictionary = {}
var _bench_dirty: bool = false
var _recycler_rest_style: StyleBoxFlat
var _recycler_hot_style: StyleBoxFlat
var _layout_cell_size: Vector2 = Vector2(150, 150)

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_background.color = SynGridPalette.PANEL_BG
	_recycler_rest_style = ThemeBuilder.build_panel_style(
		SynGridPalette.DANGER * Color(1, 1, 1, 0.35), SynGridPalette.PANEL_BG)
	_recycler_hot_style = ThemeBuilder.build_panel_style(
		SynGridPalette.DANGER, SynGridPalette.PANEL_BG_ELEVATED)
	_recycler_panel.add_theme_stylebox_override("panel", _recycler_rest_style)
	_shop_caption.text = "REQUISITION - ROUND %d - TAP TO BUY" % GameState.current_round

	_auto_arrange_button = Button.new()
	_auto_arrange_button.text = "AUTO"
	_auto_arrange_button.pressed.connect(_on_auto_arrange_pressed)
	add_child(_auto_arrange_button)
	_apply_auto_button_style()

	_apply_grid_dimensions_from_state()
	_render_initial_state()
	_stats_hud.refresh()

	ApiClient.validate_grid_completed.connect(_on_validate_grid_completed)
	ApiClient.validate_grid_failed.connect(_on_validate_grid_failed)
	ApiClient.roll_shop_completed.connect(_on_roll_shop_completed)
	ApiClient.roll_shop_failed.connect(_on_roll_shop_failed)
	ApiClient.purchase_item_completed.connect(_on_purchase_item_completed)
	ApiClient.purchase_item_failed.connect(_on_purchase_item_failed)
	ApiClient.sell_item_completed.connect(_on_sell_item_completed)
	ApiClient.sell_item_failed.connect(_on_sell_item_failed)
	ApiClient.award_round_gold_completed.connect(_on_award_round_gold_completed)
	ApiClient.award_round_gold_failed.connect(_on_award_round_gold_failed)
	ApiClient.start_match_completed.connect(_on_start_match_completed)
	ApiClient.start_match_failed.connect(_on_start_match_failed)

	_hub_button.pressed.connect(
		func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH))
	_start_match_button.pressed.connect(_on_start_match_pressed)
	_refresh_start_button()

	AudioManager.play_prep_bgm()
	_request_round_grant()
	_request_shop()

# -- Layout --

# Cells are sized card + panel margins so occupied and empty cells stay the
# same size and the grid never shifts as items land.
func _cell_outer_size() -> Vector2:
	return _layout_cell_size + Vector2.ONE * (ThemeBuilder.PANEL_CONTENT_MARGIN * 2.0)

func _bottom_section_height(bench_cell_h: float) -> float:
	return section_gap + caption_gap + bench_cell_h + section_gap \
		+ recycler_height + section_gap + start_button_height

func _compute_layout_cell_size() -> Vector2:
	var grid_top := size.y * grid_top_margin_ratio
	var bottom_h := _bottom_section_height(cell_size.y)
	var avail_h := size.y - grid_top - caption_gap - bottom_h
	var avail_w := size.x - 48.0
	var max_outer_h := avail_h / maxf(grid_rows, 1)
	var max_outer_w := avail_w / maxf(grid_columns, 1)
	var max_outer := minf(max_outer_h, max_outer_w)
	var export_outer := cell_size.x + ThemeBuilder.PANEL_CONTENT_MARGIN * 2.0
	var outer := minf(max_outer, export_outer)
	var inner := maxf(outer - ThemeBuilder.PANEL_CONTENT_MARGIN * 2.0, min_layout_cell_size)
	return Vector2(inner, inner)

func _layout_screen() -> void:
	_layout_cell_size = _compute_layout_cell_size()
	# Shop strip between the stats HUD and the grid.
	var shop_caption_top := size.y * shop_caption_ratio
	_shop_caption.position = Vector2(40.0, shop_caption_top)
	_shop_caption.size = Vector2(size.x - 80.0, caption_gap - 12.0)
	var shop_panel_top := shop_caption_top + caption_gap - 8.0
	_shop_panel.position = Vector2(24.0, shop_panel_top)
	_shop_panel.size = Vector2(size.x - 48.0, _cell_outer_size().y + 16.0)

	var grid_total := _cell_outer_size() * Vector2(grid_columns, grid_rows)
	_grid_area.size = grid_total
	_grid_area.position = Vector2((size.x - grid_total.x) / 2.0, size.y * grid_top_margin_ratio)
	_grid_container.columns = grid_columns
	_grid_container.add_theme_constant_override("h_separation", 0)
	_grid_container.add_theme_constant_override("v_separation", 0)
	_grid_container.size = grid_total

	_grid_caption.position = Vector2(_grid_area.position.x, _grid_area.position.y - caption_gap)
	_grid_caption.size = Vector2(grid_total.x, caption_gap)

	var grid_bottom := _grid_area.position.y + _grid_area.size.y
	var bench_caption_top := grid_bottom + section_gap
	var bench_top := bench_caption_top + caption_gap - 12.0
	_bench_row.anchor_left = 0.0
	_bench_row.anchor_right = 1.0
	_bench_row.anchor_top = 0.0
	_bench_row.anchor_bottom = 0.0
	_bench_row.offset_left = 40.0
	_bench_row.offset_right = -40.0
	_bench_row.offset_top = bench_top
	_bench_row.offset_bottom = bench_top + cell_size.y

	# Bento backdrop: the bench sits on its own base-elevation panel so it
	# reads as a separate zone without any harsh divider line (contract s.1).
	_bench_panel.position = Vector2(24.0, bench_caption_top - 12.0)
	_bench_panel.size = Vector2(size.x - 48.0, cell_size.y + caption_gap + 36.0)
	_bench_panel.add_theme_stylebox_override("panel",
		ThemeBuilder.build_panel_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG))
	_bench_caption.position = Vector2(40.0, bench_caption_top)
	_bench_caption.size = Vector2(size.x - 80.0, caption_gap - 12.0)

	var recycler_top := bench_top + cell_size.y + section_gap
	_recycler_panel.position = Vector2(24.0, recycler_top)
	_recycler_panel.size = Vector2(size.x - 48.0, recycler_height)

	var start_top := recycler_top + recycler_height + section_gap
	var auto_width := 140.0
	if _auto_arrange_button != null:
		_auto_arrange_button.position = Vector2(40.0, start_top)
		_auto_arrange_button.size = Vector2(auto_width, start_button_height)
		_start_match_button.position = Vector2(40.0 + auto_width + 16.0, start_top)
		_start_match_button.size = Vector2(size.x - 80.0 - auto_width - 16.0, start_button_height)
	else:
		_start_match_button.position = Vector2(40.0, start_top)
		_start_match_button.size = Vector2(size.x - 80.0, start_button_height)

func _apply_grid_dimensions_from_state() -> void:
	grid_columns = GameState.grid_columns
	grid_rows = GameState.grid_rows
	_layout_screen()
	_build_cells()

func _maybe_rebuild_grid_from_state() -> void:
	if grid_columns == GameState.grid_columns and grid_rows == GameState.grid_rows:
		return
	_clear_synergy_borders()
	_known_synergy_keys.clear()
	_apply_grid_dimensions_from_state()
	_render_initial_state()
	_refresh_start_button()

func _build_cells() -> void:
	_clear_grid_cells()
	for y in grid_rows:
		for x in grid_columns:
			var cell := GridCell.new()
			cell.setup(x, y, _cell_outer_size())
			_grid_container.add_child(cell)
			_cells.append(cell)
	_build_coord_labels()

# Neon Grimoire coordinate labels: A/B/C/D across the top of the deployment
# grid and 1/2/3/4 down the left. Sci-fi targeting feel, one-line-of-code cost.
# Labels are children of %GridArea so they layout relative to the grid's own
# top-left origin.
func _build_coord_labels() -> void:
	for label in _coord_labels:
		label.queue_free()
	_coord_labels.clear()
	var outer := _cell_outer_size()
	for x in grid_columns:
		var col_label := Label.new()
		col_label.theme_type_variation = &"CaptionLabel"
		col_label.add_theme_color_override("font_color",
			Color(SynGridPalette.ACCENT_TEAL, 0.55))
		col_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		col_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_label.text = char(65 + x)
		col_label.position = Vector2(x * outer.x, -22.0)
		col_label.size = Vector2(outer.x, 20.0)
		_grid_area.add_child(col_label)
		_coord_labels.append(col_label)
	for y in grid_rows:
		var row_label := Label.new()
		row_label.theme_type_variation = &"CaptionLabel"
		row_label.add_theme_color_override("font_color",
			Color(SynGridPalette.ACCENT_TEAL, 0.55))
		row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_label.text = str(y + 1)
		row_label.position = Vector2(-24.0, y * outer.y)
		row_label.size = Vector2(20.0, outer.y)
		_grid_area.add_child(row_label)
		_coord_labels.append(row_label)

func _clear_grid_cells() -> void:
	for cell in _cells:
		cell.queue_free()
	_cells.clear()
	_occupancy.clear()
	_cards_by_item_id.clear()

func _occ_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _footprint_fits(anchor_x: int, anchor_y: int, item: Dictionary,
		exclude_item_id: String = "") -> bool:
	var footprint := GameState.item_footprint(item)
	if anchor_x < 0 or anchor_y < 0:
		return false
	if anchor_x + footprint.x > grid_columns or anchor_y + footprint.y > grid_rows:
		return false
	for dx in footprint.x:
		for dy in footprint.y:
			var occupant: String = _occupancy.get(_occ_key(anchor_x + dx, anchor_y + dy), "")
			if occupant != "" and occupant != exclude_item_id:
				return false
	return true

func _claim_footprint(anchor_x: int, anchor_y: int, item_id: String, footprint: Vector2i) -> void:
	for dx in footprint.x:
		for dy in footprint.y:
			var key := _occ_key(anchor_x + dx, anchor_y + dy)
			_occupancy[key] = item_id
			var cell := _cell_at(anchor_x + dx, anchor_y + dy)
			if cell != null:
				cell.set_occupied(true)

func _release_footprint(anchor_x: int, anchor_y: int, footprint: Vector2i) -> void:
	for dx in footprint.x:
		for dy in footprint.y:
			var key := _occ_key(anchor_x + dx, anchor_y + dy)
			_occupancy.erase(key)
			var cell := _cell_at(anchor_x + dx, anchor_y + dy)
			if cell != null:
				cell.set_occupied(false)

func _apply_footprint_visual(card: ItemCard, footprint: Vector2i) -> void:
	card.custom_minimum_size = _layout_cell_size * Vector2(footprint.x, footprint.y)

func _reset_footprint_visual(card: ItemCard) -> void:
	card.custom_minimum_size = card.card_size

func _footprint_rect(anchor: GridCell, footprint: Vector2i) -> Rect2:
	var top_left := anchor.get_global_rect().position
	var outer := _cell_outer_size()
	return Rect2(top_left, outer * Vector2(footprint.x, footprint.y))

func _clear_drop_highlight() -> void:
	for cell in _highlighted_cells:
		cell.highlight(false)
	_highlighted_cells.clear()

func _set_drop_highlight(anchor: GridCell, item: Dictionary, valid: bool = true) -> void:
	_clear_drop_highlight()
	if anchor == null:
		return
	var footprint := GameState.item_footprint(item)
	for dx in footprint.x:
		for dy in footprint.y:
			var cell := _cell_at(anchor.grid_x + dx, anchor.grid_y + dy)
			if cell != null:
				cell.highlight(true, valid)
				_highlighted_cells.append(cell)

func _anchor_coords_for_item(item: Dictionary) -> Vector2i:
	var coords: Variant = item.get("placement_coords")
	if coords == null:
		return Vector2i(-1, -1)
	return Vector2i(int(coords.get("x", 0)), int(coords.get("y", 0)))

func _cell_at(x: int, y: int) -> GridCell:
	if x < 0 or x >= grid_columns or y < 0 or y >= grid_rows:
		return null
	return _cells[y * grid_columns + x]

func _render_initial_state() -> void:
	_render_bench()
	for item in GameState.equipped_items:
		var anchor := _anchor_coords_for_item(item)
		if anchor.x < 0:
			continue
		var cell := _cell_at(anchor.x, anchor.y)
		if cell == null or not cell.is_free():
			continue
		if not _footprint_fits(anchor.x, anchor.y, item):
			continue
		var footprint := GameState.item_footprint(item)
		var card := _spawn_card(item, cell)
		_apply_footprint_visual(card, footprint)
		_claim_footprint(anchor.x, anchor.y, item.get("item_id", ""), footprint)
		_cards_by_item_id[item.get("item_id", "")] = card

func _spawn_card(item: Dictionary, parent: Node) -> ItemCard:
	var card: ItemCard = ITEM_CARD_SCENE.instantiate()
	parent.add_child(card)
	card.set_item_data(item)
	card.drag_started.connect(_on_card_drag_started)
	card.drag_ended.connect(_on_card_drag_ended)
	_cards_by_item_id[item.get("item_id", "")] = card
	return card

# -- Round-start gold grant --
# api_contract.md: call at the start of each round; the server computes tier,
# win/loss, and interest. AwardRoundGold credits on every call, so claim it
# exactly once per round via GameState.gold_awarded_round.

func _request_round_grant() -> void:
	if GameState.gold_awarded_round >= GameState.current_round:
		return
	ApiClient.award_round_gold(GameState.current_round, GameState.last_fight_won)

func _on_award_round_gold_completed(data: Dictionary) -> void:
	GameState.gold_awarded_round = GameState.current_round
	GameState.gold = int(data.get("new_balance", GameState.gold))
	AudioManager.play_coin_earn()
	_stats_hud.refresh()
	_update_affordability()
	_status_label.text = "ROUND GRANT +%dG" % int(data.get("gold_awarded", 0))

func _on_award_round_gold_failed(_code: int, reason: String) -> void:
	_status_label.text = "GRANT FAILED - %s" % reason

# -- Shop roll --

func _request_shop() -> void:
	if GameState.shop_round == GameState.current_round and not GameState.current_shop_slots.is_empty():
		# Same round re-entry: the server would return identical slots, so
		# render the cache. Cards still pop (they are newly on screen) but the
		# reroll clatter only plays on a fresh roll.
		_render_shop(GameState.current_shop_slots)
		return
	ApiClient.roll_shop(GameState.current_round)

func _on_roll_shop_completed(data: Dictionary) -> void:
	var slots: Array = data.get("slots", [])
	GameState.current_shop_slots.assign(slots)
	GameState.shop_round = GameState.current_round
	AudioManager.play_shop_reroll()
	_render_shop(slots)

func _on_roll_shop_failed(_code: int, reason: String) -> void:
	_status_label.text = "SHOP ROLL FAILED - %s" % reason

func _render_shop(slots: Array) -> void:
	for child in _shop_row.get_children():
		_shop_row.remove_child(child)
		child.queue_free()
	for i in slots.size():
		var card: ItemCard = ITEM_CARD_SCENE.instantiate()
		_shop_row.add_child(card)
		card.set_item_data(slots[i])
		card.draggable = false
		card.card_pressed.connect(_on_shop_card_pressed)
		card.play_pop(i)
	_update_affordability()

# Presentation only: dim slots the current balance cannot cover. The server
# remains the authority - a desynced client just gets INSUFFICIENT_GOLD back.
func _update_affordability() -> void:
	for card: ItemCard in _shop_row.get_children():
		var price := int(card.get("_item_data").get("buy_price", 0))
		card.modulate = Color.WHITE if price <= GameState.gold else unaffordable_tint

# -- Buy flow --

func _on_shop_card_pressed(item_data: Dictionary) -> void:
	if _purchase_in_flight:
		return
	_purchase_in_flight = true
	ApiClient.purchase_item(String(item_data.get("template_name", "")), GameState.current_round)

func _on_purchase_item_completed(data: Dictionary) -> void:
	_purchase_in_flight = false
	GameState.gold = int(data.get("new_balance", GameState.gold))
	var bench: Array = data.get("updated_grid", {}).get("bench_reserve", [])
	var merges: Array = data.get("merges", [])

	GameState.sync_bench_from_server(bench)
	GameState.sync_grid_dimensions(data.get("updated_grid", {}))
	_maybe_rebuild_grid_from_state()
	_render_bench()
	_stats_hud.refresh()
	_update_affordability()

	if not merges.is_empty():
		for i in merges.size():
			var produced: Dictionary = merges[i].get("produced_item", {})
			get_tree().create_timer(i * merge_flash_stagger).timeout.connect(
				_celebrate_merge.bind(produced))
	else:
		AudioManager.play_grid_snap()
		_status_label.text = "REQUISITIONED"
	AudioManager.play_coin_spend()

func _on_purchase_item_failed(_code: int, reason: String) -> void:
	_purchase_in_flight = false
	_status_label.text = "PURCHASE FAILED - %s" % reason

func _celebrate_merge(merged_item: Dictionary) -> void:
	AudioManager.play_triple_merge()
	_status_label.text = "TRIPLE-MERGE - LV%d %s" % [int(merged_item.get("level", 2)),
		String(merged_item.get("name", "?")).to_upper()]
	var tier_color := SynGridPalette.tint_for_tier(int(merged_item.get("level", 2)))
	for card: ItemCard in _bench_row.get_children():
		if card.get("_item_data").get("item_id", "") == merged_item.get("item_id", ""):
			var pos := card.get_global_rect().get_center()
			_spawn_merge_burst(pos, tier_color)
			_spawn_tier_ring(pos, tier_color)
			return

# -- Bench --

func _render_bench() -> void:
	if _dragging_card != null:
		_bench_dirty = true
		return
	for child in _bench_row.get_children():
		_bench_row.remove_child(child)
		child.queue_free()
	var fresh_ids: Dictionary = {}
	var pop_idx := 0
	for item in GameState.bench_items:
		var card := _spawn_card(item, _bench_row)
		var item_id: String = item.get("item_id", "")
		fresh_ids[item_id] = true
		if not _known_bench_ids.has(item_id):
			card.play_pop(pop_idx)
			pop_idx += 1
	_known_bench_ids = fresh_ids

# -- Drag lifecycle --

func _force_resolve_drag(card: ItemCard) -> void:
	if card == null:
		return
	var drop_pos := card.global_position + card.size / 2.0
	card.force_end_drag(drop_pos)

func _nearest_valid_anchor(drop_pos: Vector2, item: Dictionary,
		exclude_item_id: String = "") -> GridCell:
	var snap_radius := _layout_cell_size.x * 0.5
	var best: GridCell = null
	var best_dist := snap_radius
	for cell in _cells:
		if not _footprint_fits(cell.grid_x, cell.grid_y, item, exclude_item_id):
			continue
		var center := cell.get_global_rect().get_center()
		var dist := drop_pos.distance_to(center)
		if dist < best_dist:
			best_dist = dist
			best = cell
	return best

func _on_card_drag_started(card: ItemCard) -> void:
	if _dragging_card != null and _dragging_card != card:
		_force_resolve_drag(_dragging_card)
	_dragging_card = card
	_dragging_origin = card.get_parent()
	if _dragging_origin is GridCell:
		var item: Dictionary = card.get("_item_data")
		var anchor := _anchor_coords_for_item(item)
		_release_footprint(anchor.x, anchor.y, GameState.item_footprint(item))
	var pos := card.global_position
	_dragging_origin.remove_child(card)
	_drag_layer.add_child(card)
	card.global_position = pos
	AudioManager.play_item_drag()

func _process(_delta: float) -> void:
	if _dragging_card != null and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_force_resolve_drag(_dragging_card)
		return
	if _dragging_card == null:
		return
	var item: Dictionary = _dragging_card.get("_item_data")
	var exclude_id := ""
	if _dragging_origin is GridCell:
		exclude_id = String(item.get("item_id", ""))
	var center := _dragging_card.global_position + _dragging_card.size / 2.0
	var pointer_cell: GridCell = null
	for cell in _cells:
		if cell.get_global_rect().has_point(center):
			pointer_cell = cell
			break
	var valid_anchor := _nearest_valid_anchor(center, item, exclude_id)
	var anchor := valid_anchor if valid_anchor != null else pointer_cell
	var valid := valid_anchor != null
	if anchor != _highlight_anchor or valid != _highlight_valid:
		_highlight_anchor = anchor
		_highlight_valid = valid
		if anchor == null:
			_clear_drop_highlight()
			_clear_preview_synergy()
		else:
			_set_drop_highlight(anchor, item, valid)
			if valid:
				_refresh_preview_synergy(anchor, item)
			else:
				_clear_preview_synergy()
	_recycler_panel.add_theme_stylebox_override("panel",
		_recycler_hot_style if _recycler_panel.get_global_rect().has_point(center)
		else _recycler_rest_style)

func _on_card_drag_ended(card: ItemCard, drop_pos: Vector2) -> void:
	_clear_drop_highlight()
	_clear_preview_synergy()
	_highlight_anchor = null
	_highlight_valid = true
	_recycler_panel.add_theme_stylebox_override("panel", _recycler_rest_style)

	var origin := _dragging_origin
	_dragging_card = null
	_dragging_origin = null

	if _recycler_panel.get_global_rect().has_point(drop_pos):
		# Selling is bench-only: the server prices the sale; equipped items
		# must be benched first so the grid state on screen stays truthful.
		if origin == _bench_row and _pending_sell_card == null:
			_sell_card(card)
		else:
			_return_card_to(card, origin)
			_status_label.text = "ONLY BENCH ITEMS CAN BE RECYCLED"
	else:
		var item: Dictionary = card.get("_item_data")
		var exclude_id := ""
		if origin is GridCell:
			exclude_id = String(item.get("item_id", ""))
		var target_cell := _nearest_valid_anchor(drop_pos, item, exclude_id)
		if target_cell != null and _footprint_fits(target_cell.grid_x, target_cell.grid_y, item, exclude_id):
			_place_card(card, target_cell)
		elif origin is GridCell and _bench_row.get_global_rect().has_point(drop_pos):
			_unplace_card(card)
		else:
			_return_card_to(card, origin)

	if _bench_dirty:
		_bench_dirty = false
		_render_bench()

func _return_card_to(card: ItemCard, origin: Node) -> void:
	_drag_layer.remove_child(card)
	origin.add_child(card)
	if origin is GridCell:
		var item: Dictionary = card.get("_item_data")
		var anchor := _anchor_coords_for_item(item)
		var footprint := GameState.item_footprint(item)
		_apply_footprint_visual(card, footprint)
		_claim_footprint(anchor.x, anchor.y, item.get("item_id", ""), footprint)
	elif origin == _bench_row:
		_reset_footprint_visual(card)

# -- Sell flow --

func _sell_card(card: ItemCard) -> void:
	_pending_sell_card = card
	card.modulate.a = pending_sell_alpha
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ApiClient.sell_item(String(card.get("_item_data").get("item_id", "")))

func _on_sell_item_completed(data: Dictionary) -> void:
	var credited := int(data.get("new_balance", GameState.gold)) - GameState.gold
	GameState.gold = int(data.get("new_balance", GameState.gold))
	if credited > 0:
		AudioManager.play_coin_earn()
	GameState.sync_bench_from_server(data.get("updated_grid", {}).get("bench_reserve", []))
	GameState.sync_grid_dimensions(data.get("updated_grid", {}))
	_maybe_rebuild_grid_from_state()
	_stats_hud.refresh()
	_update_affordability()
	_status_label.text = "RECYCLED +%dG" % credited
	if _pending_sell_card != null:
		var card := _pending_sell_card
		_pending_sell_card = null
		card.pivot_offset = card.size / 2.0
		var tw := create_tween()
		tw.tween_property(card, "scale", Vector2.ZERO, sell_shrink_duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tw.tween_callback(card.queue_free)
	_render_bench()

func _on_sell_item_failed(_code: int, reason: String) -> void:
	_status_label.text = "SELL FAILED - %s" % reason
	if _pending_sell_card != null:
		var card := _pending_sell_card
		_pending_sell_card = null
		card.modulate.a = 1.0
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		_return_card_to(card, _bench_row)

# -- Start match --

func _refresh_start_button() -> void:
	var ready_to_fight := not GameState.equipped_items.is_empty()
	_start_match_button.disabled = not ready_to_fight or _match_in_flight
	_start_match_button.text = "START MATCH" if ready_to_fight else "PLACE AN ITEM TO FIGHT"
	if ready_to_fight and not _start_button_was_ready:
		_apply_start_button_glow()
		_pop_start_button()
	elif not ready_to_fight and _start_button_was_ready:
		_apply_start_button_dim()
	_start_button_was_ready = ready_to_fight

func _apply_start_button_glow() -> void:
	var glow := ThemeBuilder.build_panel_style(
		SynGridPalette.ACCENT_TEAL, SynGridPalette.PANEL_BG_ELEVATED, 0, true)
	var glow_hover := ThemeBuilder.build_panel_style(
		SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_ELEVATED, 0, true)
	var glow_pressed := ThemeBuilder.build_panel_style(
		SynGridPalette.ACCENT_PURPLE, SynGridPalette.PANEL_BG_ELEVATED, 0, true)
	_start_match_button.add_theme_stylebox_override("normal", glow)
	_start_match_button.add_theme_stylebox_override("hover", glow_hover)
	_start_match_button.add_theme_stylebox_override("pressed", glow_pressed)

func _apply_start_button_dim() -> void:
	_start_match_button.remove_theme_stylebox_override("normal")
	_start_match_button.remove_theme_stylebox_override("hover")
	_start_match_button.remove_theme_stylebox_override("pressed")
	_start_match_button.scale = Vector2.ONE

func _apply_auto_button_style() -> void:
	# Secondary action: styled like the rest of the UI, but visually distinct
	# from the primary START MATCH teal glow.
	var normal := ThemeBuilder.build_panel_style(
		SynGridPalette.ACCENT_SILVER, SynGridPalette.PANEL_BG_ELEVATED, 0, true)
	var hover := ThemeBuilder.build_panel_style(
		SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_HOVER, 0, true)
	var pressed := ThemeBuilder.build_panel_style(
		SynGridPalette.ACCENT_PURPLE, SynGridPalette.PANEL_BG_ELEVATED, 0, true)
	_auto_arrange_button.add_theme_stylebox_override("normal", normal)
	_auto_arrange_button.add_theme_stylebox_override("hover", hover)
	_auto_arrange_button.add_theme_stylebox_override("pressed", pressed)

func _pop_start_button() -> void:
	_start_match_button.pivot_offset = _start_match_button.size / 2.0
	_start_match_button.scale = Vector2.ZERO
	var tw := create_tween().set_parallel(false)
	tw.tween_property(_start_match_button, "scale", Vector2(1.1, 1.1), 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(_start_match_button, "scale", Vector2(1.0, 1.0), 0.06) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

func _on_start_match_pressed() -> void:
	if _match_in_flight:
		return
	_match_in_flight = true
	_refresh_start_button()
	_status_label.text = "SEARCHING FOR OPPONENT..."
	ApiClient.start_match(GameState.to_grid_payload())

func _on_start_match_completed(data: Dictionary) -> void:
	_match_in_flight = false
	if String(data.get("status", "")) != "MATCH_STATUS_PLAYED":
		_refresh_start_button()
		_status_label.text = "NO OPPONENT AVAILABLE - TRY AGAIN SOON"
		return
	GameState.last_combat_log = data.get("combat_log", {})
	GameState.opponent_grid = data.get("opponent_grid", {})
	GameState.last_fight_won = GameState.last_combat_log.get("winner_id", "") == GameState.player_id
	get_tree().change_scene_to_file(COMBAT_REPLAY_SCENE_PATH)

func _on_start_match_failed(_code: int, reason: String) -> void:
	_match_in_flight = false
	_refresh_start_button()
	_status_label.text = "MATCH FAILED - %s" % reason

# -- Placement (client-owned; see header comment) --

func _place_card(card: ItemCard, cell: GridCell) -> void:
	_drag_layer.remove_child(card)
	_finish_placement(card, cell, true)

func _finish_placement(card: ItemCard, cell: GridCell, notify_server: bool) -> void:
	var item: Dictionary = card.get("_item_data")
	cell.add_child(card)
	var footprint := GameState.item_footprint(item)
	_apply_footprint_visual(card, footprint)
	_claim_footprint(cell.grid_x, cell.grid_y, item.get("item_id", ""), footprint)
	_move_item_to_equipped(item, cell.grid_x, cell.grid_y)
	_cards_by_item_id[item.get("item_id", "")] = card
	card.play_snap_bounce()
	_spawn_snap_particles(cell, footprint)
	AudioManager.play_grid_snap()
	if notify_server:
		_status_label.text = "placed %s at (%d, %d)" % [item.get("name", "?"), cell.grid_x, cell.grid_y]
		_refresh_start_button()
		ApiClient.validate_grid(GameState.to_grid_payload())

func _on_auto_arrange_pressed() -> void:
	var bench_snapshot: Array[Dictionary] = GameState.bench_items.duplicate()
	for item in bench_snapshot:
		var footprint := GameState.item_footprint(item)
		var best_cell: GridCell = null
		var best_score := -1.0
		for cell in _cells:
			if not _footprint_fits(cell.grid_x, cell.grid_y, item):
				continue
			var score := _score_cell_for_item(cell, footprint, item)
			if score > best_score:
				best_score = score
				best_cell = cell
		if best_cell == null:
			continue
		var card: ItemCard = _cards_by_item_id.get(item.get("item_id", ""))
		if card == null:
			continue
		_bench_row.remove_child(card)
		_finish_placement(card, best_cell, false)
	_render_bench()
	_refresh_start_button()
	ApiClient.validate_grid(GameState.to_grid_payload())

func _unplace_card(card: ItemCard) -> void:
	_drag_layer.remove_child(card)
	_bench_row.add_child(card)

	var item: Dictionary = card.get("_item_data")
	var anchor := _anchor_coords_for_item(item)
	var footprint := GameState.item_footprint(item)
	_release_footprint(anchor.x, anchor.y, footprint)
	_reset_footprint_visual(card)
	_move_item_to_bench(item)
	_cards_by_item_id.erase(item.get("item_id", ""))
	_known_bench_ids[item.get("item_id", "")] = true

	_status_label.text = "returned %s to bench" % item.get("name", "?")
	_refresh_start_button()
	ApiClient.validate_grid(GameState.to_grid_payload())

func _move_item_to_equipped(item: Dictionary, x: int, y: int) -> void:
	var item_id: String = item.get("item_id", "")
	for i in GameState.bench_items.size():
		if GameState.bench_items[i].get("item_id", "") == item_id:
			GameState.bench_items.remove_at(i)
			break
	item["placement_coords"] = {"x": x, "y": y}
	for existing in GameState.equipped_items:
		if existing.get("item_id", "") == item_id:
			existing["placement_coords"] = {"x": x, "y": y}
			return
	GameState.equipped_items.append(item)

func _move_item_to_bench(item: Dictionary) -> void:
	var item_id: String = item.get("item_id", "")
	for i in GameState.equipped_items.size():
		if GameState.equipped_items[i].get("item_id", "") == item_id:
			GameState.equipped_items.remove_at(i)
			break
	item["placement_coords"] = null
	for existing in GameState.bench_items:
		if existing.get("item_id", "") == item_id:
			return
	GameState.bench_items.append(item)

# -- Juice: particles (contract sections 2 and 5) --

func _spawn_snap_particles(cell: GridCell, footprint: Vector2i) -> void:
	var rect := _footprint_rect(cell, footprint)
	var radius: float = minf(rect.size.x, rect.size.y) * 0.2
	var particles := _build_ring_particles(
		radius, radius * 0.8, 24, snap_particle_lifetime,
		20.0, 40.0, 4.0, Color(0.0, 0.9, 0.8, 0.6), Color(0.0, 0.9, 0.8, 0.0))
	_synergy_layer.add_child(particles)
	particles.global_position = rect.get_center()
	particles.emitting = true
	get_tree().create_timer(snap_particle_lifetime + 0.1).timeout.connect(particles.queue_free)

# Rising chime + particle impact (juice contract section 5 SFX matrix).
func _spawn_merge_burst(pos: Vector2, tint: Color) -> void:
	var particles := _build_ring_particles(
		60.0, 20.0, 32, merge_particle_lifetime,
		60.0, 120.0, 5.0, Color(tint, 0.9),
		Color(SynGridPalette.ACCENT_TEAL, 0.0))
	_drag_layer.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	get_tree().create_timer(merge_particle_lifetime + 0.1).timeout.connect(particles.queue_free)

func _spawn_tier_ring(pos: Vector2, tint: Color) -> void:
	var ring := TierRing.new()
	_drag_layer.add_child(ring)
	ring.global_position = pos
	ring.play(tint)

func _build_ring_particles(ring_radius: float, inner_radius: float, amount: int,
		lifetime: float, vel_min: float, vel_max: float, scale_max: float,
		from_color: Color, to_color: Color) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	# Ring emission was added to CPUParticles2D in Godot 4.7. On 4.5 stable we
	# fall back to SPHERE_SURFACE which emits from a circle boundary in 2D -
	# visually identical to a thin ring at the sizes this project uses.
	if "emission_ring_radius" in particles:
		particles.set("emission_shape", 6)  # EMISSION_SHAPE_RING
		particles.set("emission_ring_radius", ring_radius)
		particles.set("emission_ring_inner_radius", inner_radius)
	else:
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
		particles.emission_sphere_radius = ring_radius
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = vel_min
	particles.initial_velocity_max = vel_max
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = scale_max
	var grad := Gradient.new()
	grad.set_color(0, from_color)
	grad.set_color(1, to_color)
	particles.color_ramp = grad
	return particles

# -- Synergy shader glow (juice_manual.md section 3) --

func _on_validate_grid_completed(data: Dictionary) -> void:
	_clear_synergy_borders()
	var synergies: Array = data.get("synergies", [])
	var seen_keys: Dictionary = {}
	var fresh: Array[Dictionary] = []
	for synergy: Dictionary in synergies:
		_spawn_synergy_border(synergy)
		var key := _synergy_key(synergy)
		seen_keys[key] = true
		if not _known_synergy_keys.has(key):
			fresh.append(synergy)
	_known_synergy_keys = seen_keys

	# Rising chime per newly-formed link, pitch ascending with modifier_pct
	# (juice contract section 5 SFX matrix), staggered so stacked links arpeggiate.
	for i in fresh.size():
		var pitch := 1.0 + float(fresh[i].get("modifier_pct", 0.2))
		get_tree().create_timer(i * synergy_chime_stagger).timeout.connect(
			AudioManager.play_synergy_link.bind(pitch))
		_pulse_synergy_pair(fresh[i])

	_status_label.text = "%d synergy link(s) active" % synergies.size()

func _on_validate_grid_failed(_code: int, _reason: String) -> void:
	_clear_synergy_borders()
	_known_synergy_keys.clear()

func _synergy_key(synergy: Dictionary) -> String:
	return "%s>%s:%s" % [
		synergy.get("source_item_id", ""),
		synergy.get("target_item_id", ""),
		synergy.get("direction", ""),
	]

func _pulse_synergy_pair(synergy: Dictionary) -> void:
	var source_card: ItemCard = _cards_by_item_id.get(synergy.get("source_item_id", ""))
	var target_card: ItemCard = _cards_by_item_id.get(synergy.get("target_item_id", ""))
	if source_card != null:
		source_card.play_synergy_pulse()
	if target_card != null:
		target_card.play_synergy_pulse()

func _clear_synergy_borders() -> void:
	for border in _synergy_borders:
		border.fade_out_and_free()
	_synergy_borders.clear()

func _spawn_synergy_border(synergy: Dictionary) -> void:
	var source_card: ItemCard = _cards_by_item_id.get(synergy.get("source_item_id", ""))
	var target_card: ItemCard = _cards_by_item_id.get(synergy.get("target_item_id", ""))
	if source_card == null or target_card == null:
		return
	var source_cell := source_card.get_parent() as GridCell
	if source_cell == null:
		return

	var footprint := GameState.item_footprint(source_card.get("_item_data"))
	var direction: String = synergy.get("direction", "")
	var strip: SynergyBorder = SYNERGY_BORDER_SCENE.instantiate()
	_synergy_layer.add_child(strip)
	_position_strip_on_edge(strip, source_cell, footprint, direction)
	strip.fade_in_to(float(synergy.get("modifier_pct", 0.2)))
	_synergy_borders.append(strip)

func _position_strip_on_edge(strip: SynergyBorder, anchor: GridCell, footprint: Vector2i,
		direction: String) -> void:
	var rect := _footprint_rect(anchor, footprint)
	var half_strip := synergy_strip_width / 2.0
	var strip_pos: Vector2
	var strip_size: Vector2
	match direction:
		"EAST":
			strip_pos = Vector2(rect.position.x + rect.size.x - half_strip, rect.position.y)
			strip_size = Vector2(synergy_strip_width, rect.size.y)
		"WEST":
			strip_pos = Vector2(rect.position.x - half_strip, rect.position.y)
			strip_size = Vector2(synergy_strip_width, rect.size.y)
		"SOUTH":
			strip_pos = Vector2(rect.position.x, rect.position.y + rect.size.y - half_strip)
			strip_size = Vector2(rect.size.x, synergy_strip_width)
		"NORTH":
			strip_pos = Vector2(rect.position.x, rect.position.y - half_strip)
			strip_size = Vector2(rect.size.x, synergy_strip_width)
		_:
			strip.queue_free()
			return
	strip.global_position = strip_pos
	strip.size = strip_size

func _refresh_preview_synergy(anchor: GridCell, item: Dictionary) -> void:
	_clear_preview_synergy()
	var footprint := GameState.item_footprint(item)
	for pair: Dictionary in _neighbors_of(anchor, footprint):
		var neighbor_card: ItemCard = pair.cell.get_card()
		if neighbor_card == null:
			continue
		var modifier := _synergy_match(item, neighbor_card.get("_item_data"), pair.direction)
		if modifier <= 0.0:
			continue
		var strip: SynergyBorder = SYNERGY_BORDER_SCENE.instantiate()
		_synergy_layer.add_child(strip)
		_position_strip_on_edge(strip, anchor, footprint, pair.direction)
		strip.fade_in_to(modifier * preview_intensity_scale)
		_preview_borders.append(strip)

func _clear_preview_synergy() -> void:
	for border in _preview_borders:
		border.fade_out_and_free()
	_preview_borders.clear()

func _synergy_match(item_a: Dictionary, item_b: Dictionary, dir_a_to_b: String) -> float:
	var dir_b_to_a := _opposite_direction(dir_a_to_b)
	var a_receptor := _matching_receptor(item_a, dir_a_to_b, String(item_b.get("item_type", "")))
	var b_receptor := _matching_receptor(item_b, dir_b_to_a, String(item_a.get("item_type", "")))
	return maxf(a_receptor, b_receptor)

func _opposite_direction(dir: String) -> String:
	match dir:
		"NORTH": return "SOUTH"
		"SOUTH": return "NORTH"
		"EAST": return "WEST"
		"WEST": return "EAST"
		_: return ""

func _matching_receptor(item: Dictionary, probe_dir: String, neighbor_type: String) -> float:
	var receptors: Array = item.get("synergy_receptors", [])
	var rotated: bool = item.get("rotated", false)
	for r: Dictionary in receptors:
		var effective_dir := String(r.get("direction", ""))
		if rotated:
			effective_dir = _rotate_dir_cw(effective_dir)
		if effective_dir == probe_dir and String(r.get("accepts_type", "")) == neighbor_type:
			return float(r.get("modifier_pct", 0.0))
	return 0.0

func _rotate_dir_cw(dir: String) -> String:
	match dir:
		"NORTH": return "EAST"
		"EAST": return "SOUTH"
		"SOUTH": return "WEST"
		"WEST": return "NORTH"
		_: return dir

func _neighbors_of(anchor: GridCell, footprint: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dx in footprint.x:
		var north := _cell_at(anchor.grid_x + dx, anchor.grid_y - 1)
		if north != null:
			result.append({cell = north, direction = "NORTH"})
		var south := _cell_at(anchor.grid_x + dx, anchor.grid_y + footprint.y)
		if south != null:
			result.append({cell = south, direction = "SOUTH"})
	for dy in footprint.y:
		var west := _cell_at(anchor.grid_x - 1, anchor.grid_y + dy)
		if west != null:
			result.append({cell = west, direction = "WEST"})
		var east := _cell_at(anchor.grid_x + footprint.x, anchor.grid_y + dy)
		if east != null:
			result.append({cell = east, direction = "EAST"})
	return result

func _score_cell_for_item(anchor: GridCell, footprint: Vector2i, item: Dictionary) -> float:
	var score := 0.0
	for pair: Dictionary in _neighbors_of(anchor, footprint):
		var neighbor_card: ItemCard = pair.cell.get_card()
		if neighbor_card == null:
			continue
		score += _synergy_match(item, neighbor_card.get("_item_data"), pair.direction)
	return score
