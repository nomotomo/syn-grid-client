extends Control

# C5: drag-drop grid placement + synergy shader (juice_manual.md sections 2/3).
# Placement is entirely client-owned (client-architecture.md section 4) - the
# squish/bounce/particle plays immediately on a locally-valid drop; validate_grid
# runs in the background purely to fetch synergy glow data, and a failure there
# just means no glow, not a rejected placement.

const ITEM_CARD_SCENE: PackedScene = preload("res://scenes/ui/ItemCard.tscn")
const SYNERGY_BORDER_SCENE: PackedScene = preload("res://scenes/ui/SynergyBorder.tscn")

@export var cell_size: Vector2 = Vector2(150, 150)
@export var grid_columns: int = 4
@export var grid_rows: int = 4
@export var grid_top_margin_ratio: float = 0.14
@export var bench_top_margin_ratio: float = 0.66
@export var synergy_strip_width: float = 20.0
@export var caption_gap: float = 44.0
@export var snap_particle_lifetime: float = 0.3
@export var synergy_chime_stagger: float = 0.08

@onready var _background: ColorRect = %Background
@onready var _stats_hud: StatsHud = %StatsHud
@onready var _grid_caption: Label = %GridCaption
@onready var _grid_area: Control = %GridArea
@onready var _grid_container: GridContainer = %GridContainer
@onready var _synergy_layer: Control = %SynergyLayer
@onready var _bench_panel: PanelContainer = %BenchPanel
@onready var _bench_caption: Label = %BenchCaption
@onready var _bench_row: HBoxContainer = %BenchRow
@onready var _drag_layer: Control = %DragLayer
@onready var _status_label: Label = %StatusLabel

var _cells: Array[GridCell] = []
var _cards_by_item_id: Dictionary = {}
var _synergy_borders: Array[SynergyBorder] = []
var _known_synergy_keys: Dictionary = {}

var _dragging_card: ItemCard = null
var _dragging_origin: Node = null
var _highlighted_cell: GridCell = null

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_background.color = SynGridPalette.PANEL_BG
	_layout_screen()
	_build_cells()
	_render_initial_state()
	_stats_hud.refresh()
	ApiClient.validate_grid_completed.connect(_on_validate_grid_completed)
	ApiClient.validate_grid_failed.connect(_on_validate_grid_failed)
	AudioManager.play_prep_bgm()

# Cells are sized card + panel margins so occupied and empty cells stay the
# same size and the grid never shifts as items land.
func _cell_outer_size() -> Vector2:
	return cell_size + Vector2.ONE * (ThemeBuilder.PANEL_CONTENT_MARGIN * 2.0)

func _layout_screen() -> void:
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
	for i in GameState.bench_items.size():
		var card := _spawn_card(GameState.bench_items[i], _bench_row)
		card.play_pop(i)

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

func _on_card_drag_ended(card: ItemCard, drop_pos: Vector2) -> void:
	if _highlighted_cell != null:
		_highlighted_cell.highlight(false)
		_highlighted_cell = null

	var target_cell: GridCell = null
	for cell in _cells:
		if cell.get_global_rect().has_point(drop_pos):
			target_cell = cell
			break

	var origin := _dragging_origin
	_dragging_card = null
	_dragging_origin = null

	if target_cell != null and not target_cell.has_card():
		_place_card(card, target_cell)
	elif target_cell == null and origin is GridCell and _bench_row.get_global_rect().has_point(drop_pos):
		_unplace_card(card)
	else:
		_return_card_to(card, origin)

func _return_card_to(card: ItemCard, origin: Node) -> void:
	_drag_layer.remove_child(card)
	origin.add_child(card)

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
	ApiClient.validate_grid(GameState.to_grid_payload(grid_columns, grid_rows))

func _unplace_card(card: ItemCard) -> void:
	_drag_layer.remove_child(card)
	_bench_row.add_child(card)

	var item: Dictionary = card.get("_item_data")
	_move_item_to_bench(item)
	_cards_by_item_id.erase(item.get("item_id", ""))

	_status_label.text = "returned %s to bench" % item.get("name", "?")
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

# -- Juice: snap particle ring (juice_manual.md section 2; the card itself
# owns the squish/bounce tween via ItemCard.play_snap_bounce) --

func _spawn_snap_particles(cell: GridCell) -> void:
	var particles := CPUParticles2D.new()
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	particles.emission_ring_radius = cell_size.x * 0.4
	particles.emission_ring_inner_radius = cell_size.x * 0.32
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 24
	particles.lifetime = snap_particle_lifetime
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 40.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.9, 0.8, 0.6))
	grad.set_color(1, Color(0.0, 0.9, 0.8, 0.0))
	particles.color_ramp = grad

	_synergy_layer.add_child(particles)
	particles.global_position = cell.get_global_rect().get_center()
	particles.emitting = true
	get_tree().create_timer(snap_particle_lifetime + 0.1).timeout.connect(particles.queue_free)

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
