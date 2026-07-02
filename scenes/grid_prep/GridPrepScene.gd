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
@export var bench_top_margin_ratio: float = 0.625
@export var recycler_top_ratio: float = 0.73
@export var start_button_top_ratio: float = 0.80
@export var synergy_strip_width: float = 20.0
@export var caption_gap: float = 44.0
@export var snap_particle_lifetime: float = 0.3
@export var merge_particle_lifetime: float = 0.4
@export var synergy_chime_stagger: float = 0.08
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

var _cells: Array[GridCell] = []
var _cards_by_item_id: Dictionary = {}
var _synergy_borders: Array[SynergyBorder] = []
var _known_synergy_keys: Dictionary = {}

var _dragging_card: ItemCard = null
var _dragging_origin: Node = null
var _highlighted_cell: GridCell = null

var _purchase_in_flight: bool = false
var _match_in_flight: bool = false
var _pending_sell_card: ItemCard = null
var _known_bench_ids: Dictionary = {}
var _bench_dirty: bool = false
var _recycler_rest_style: StyleBoxFlat
var _recycler_hot_style: StyleBoxFlat

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_background.color = SynGridPalette.PANEL_BG
	_recycler_rest_style = ThemeBuilder.build_panel_style(
		SynGridPalette.DANGER * Color(1, 1, 1, 0.35), SynGridPalette.PANEL_BG)
	_recycler_hot_style = ThemeBuilder.build_panel_style(
		SynGridPalette.DANGER, SynGridPalette.PANEL_BG_ELEVATED)
	_recycler_panel.add_theme_stylebox_override("panel", _recycler_rest_style)
	_shop_caption.text = "REQUISITION - ROUND %d - TAP TO BUY" % GameState.current_round

	_layout_screen()
	_build_cells()
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
	return cell_size + Vector2.ONE * (ThemeBuilder.PANEL_CONTENT_MARGIN * 2.0)

func _layout_screen() -> void:
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

	var bench_top := size.y * bench_top_margin_ratio
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
	_bench_panel.position = Vector2(24.0, bench_top - caption_gap - 12.0)
	_bench_panel.size = Vector2(size.x - 48.0, cell_size.y + caption_gap + 36.0)
	_bench_panel.add_theme_stylebox_override("panel",
		ThemeBuilder.build_panel_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG))
	_bench_caption.position = Vector2(40.0, bench_top - caption_gap)
	_bench_caption.size = Vector2(size.x - 80.0, caption_gap - 12.0)

	_recycler_panel.position = Vector2(24.0, size.y * recycler_top_ratio)
	_recycler_panel.size = Vector2(size.x - 48.0, 100.0)

	_start_match_button.position = Vector2(40.0, size.y * start_button_top_ratio)
	_start_match_button.size = Vector2(size.x - 80.0, 140.0)

func _build_cells() -> void:
	for y in grid_rows:
		for x in grid_columns:
			var cell := GridCell.new()
			cell.setup(x, y, _cell_outer_size())
			_grid_container.add_child(cell)
			_cells.append(cell)

func _cell_at(x: int, y: int) -> GridCell:
	if x < 0 or x >= grid_columns or y < 0 or y >= grid_rows:
		return null
	return _cells[y * grid_columns + x]

func _render_initial_state() -> void:
	_render_bench()
	for item in GameState.equipped_items:
		var coords = item.get("placement_coords")
		if coords == null:
			continue
		var cell := _cell_at(int(coords.get("x", 0)), int(coords.get("y", 0)))
		if cell == null or cell.has_card():
			continue
		var card := _spawn_card(item, cell)
		_cards_by_item_id[item.get("item_id", "")] = card

func _spawn_card(item: Dictionary, parent: Node) -> ItemCard:
	var card: ItemCard = ITEM_CARD_SCENE.instantiate()
	parent.add_child(card)
	card.set_item_data(item)
	card.drag_started.connect(_on_card_drag_started)
	card.drag_ended.connect(_on_card_drag_ended)
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

	# Triple-merge detection: the server destroys three Level 1 copies and
	# returns one unseen Level 2+ item in their place.
	var merged_item: Dictionary = {}
	for item: Dictionary in bench:
		if int(item.get("level", 1)) >= 2 and not _known_bench_ids.has(item.get("item_id", "")):
			merged_item = item
			break

	GameState.sync_bench_from_server(bench)
	_render_bench()
	_stats_hud.refresh()
	_update_affordability()

	if not merged_item.is_empty():
		AudioManager.play_triple_merge()
		_celebrate_merge(merged_item)
	else:
		AudioManager.play_grid_snap()
		_status_label.text = "REQUISITIONED"

func _on_purchase_item_failed(_code: int, reason: String) -> void:
	_purchase_in_flight = false
	_status_label.text = "PURCHASE FAILED - %s" % reason

func _celebrate_merge(merged_item: Dictionary) -> void:
	_status_label.text = "TRIPLE-MERGE - LV%d %s" % [int(merged_item.get("level", 2)),
		String(merged_item.get("name", "?")).to_upper()]
	for card: ItemCard in _bench_row.get_children():
		if card.get("_item_data").get("item_id", "") == merged_item.get("item_id", ""):
			_spawn_merge_burst(card.get_global_rect().get_center())
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

func _on_card_drag_started(card: ItemCard) -> void:
	_dragging_card = card
	_dragging_origin = card.get_parent()
	var pos := card.global_position
	_dragging_origin.remove_child(card)
	_drag_layer.add_child(card)
	card.global_position = pos
	AudioManager.play_item_drag()

func _process(_delta: float) -> void:
	if _dragging_card == null:
		return
	var center := _dragging_card.global_position + _dragging_card.size / 2.0
	var hover: GridCell = null
	for cell in _cells:
		if cell.get_global_rect().has_point(center):
			hover = cell
			break
	if hover != _highlighted_cell:
		if _highlighted_cell != null:
			_highlighted_cell.highlight(false)
		if hover != null and not hover.has_card():
			hover.highlight(true)
		_highlighted_cell = hover
	_recycler_panel.add_theme_stylebox_override("panel",
		_recycler_hot_style if _recycler_panel.get_global_rect().has_point(center)
		else _recycler_rest_style)

func _on_card_drag_ended(card: ItemCard, drop_pos: Vector2) -> void:
	if _highlighted_cell != null:
		_highlighted_cell.highlight(false)
		_highlighted_cell = null
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
		var target_cell: GridCell = null
		for cell in _cells:
			if cell.get_global_rect().has_point(drop_pos):
				target_cell = cell
				break
		if target_cell != null and not target_cell.has_card():
			_place_card(card, target_cell)
		elif target_cell == null and origin is GridCell and _bench_row.get_global_rect().has_point(drop_pos):
			_unplace_card(card)
		else:
			_return_card_to(card, origin)

	if _bench_dirty:
		_bench_dirty = false
		_render_bench()

func _return_card_to(card: ItemCard, origin: Node) -> void:
	_drag_layer.remove_child(card)
	origin.add_child(card)

# -- Sell flow --

func _sell_card(card: ItemCard) -> void:
	_pending_sell_card = card
	card.modulate.a = pending_sell_alpha
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ApiClient.sell_item(String(card.get("_item_data").get("item_id", "")))

func _on_sell_item_completed(data: Dictionary) -> void:
	var credited := int(data.get("new_balance", GameState.gold)) - GameState.gold
	GameState.gold = int(data.get("new_balance", GameState.gold))
	GameState.sync_bench_from_server(data.get("updated_grid", {}).get("bench_reserve", []))
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

func _on_start_match_pressed() -> void:
	if _match_in_flight:
		return
	_match_in_flight = true
	_refresh_start_button()
	_status_label.text = "SEARCHING FOR OPPONENT..."
	ApiClient.start_match(GameState.to_grid_payload(grid_columns, grid_rows))

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
	cell.add_child(card)

	var item: Dictionary = card.get("_item_data")
	_move_item_to_equipped(item, cell.grid_x, cell.grid_y)
	_cards_by_item_id[item.get("item_id", "")] = card

	card.play_snap_bounce()
	_spawn_snap_particles(cell)
	AudioManager.play_grid_snap()

	_status_label.text = "placed %s at (%d, %d)" % [item.get("name", "?"), cell.grid_x, cell.grid_y]
	_refresh_start_button()
	ApiClient.validate_grid(GameState.to_grid_payload(grid_columns, grid_rows))

func _unplace_card(card: ItemCard) -> void:
	_drag_layer.remove_child(card)
	_bench_row.add_child(card)

	var item: Dictionary = card.get("_item_data")
	_move_item_to_bench(item)
	_cards_by_item_id.erase(item.get("item_id", ""))
	_known_bench_ids[item.get("item_id", "")] = true

	_status_label.text = "returned %s to bench" % item.get("name", "?")
	_refresh_start_button()
	ApiClient.validate_grid(GameState.to_grid_payload(grid_columns, grid_rows))

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

func _spawn_snap_particles(cell: GridCell) -> void:
	var particles := _build_ring_particles(
		cell_size.x * 0.4, cell_size.x * 0.32, 24, snap_particle_lifetime,
		20.0, 40.0, 4.0, Color(0.0, 0.9, 0.8, 0.6), Color(0.0, 0.9, 0.8, 0.0))
	_synergy_layer.add_child(particles)
	particles.global_position = cell.get_global_rect().get_center()
	particles.emitting = true
	get_tree().create_timer(snap_particle_lifetime + 0.1).timeout.connect(particles.queue_free)

# Rising chime + particle impact (juice contract section 5 SFX matrix).
func _spawn_merge_burst(pos: Vector2) -> void:
	var particles := _build_ring_particles(
		60.0, 20.0, 32, merge_particle_lifetime,
		60.0, 120.0, 5.0, Color(SynGridPalette.ACCENT_PURPLE, 0.9),
		Color(SynGridPalette.ACCENT_TEAL, 0.0))
	_drag_layer.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	get_tree().create_timer(merge_particle_lifetime + 0.1).timeout.connect(particles.queue_free)

func _build_ring_particles(ring_radius: float, inner_radius: float, amount: int,
		lifetime: float, vel_min: float, vel_max: float, scale_max: float,
		from_color: Color, to_color: Color) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	particles.emission_ring_radius = ring_radius
	particles.emission_ring_inner_radius = inner_radius
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

	var rect := source_cell.get_global_rect()
	var direction: String = synergy.get("direction", "")
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
			return

	var strip: SynergyBorder = SYNERGY_BORDER_SCENE.instantiate()
	_synergy_layer.add_child(strip)
	strip.global_position = strip_pos
	strip.size = strip_size
	strip.fade_in_to(float(synergy.get("modifier_pct", 0.2)))
	_synergy_borders.append(strip)
