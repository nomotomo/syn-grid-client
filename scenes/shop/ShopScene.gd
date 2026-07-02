class_name ShopScene
extends Control

# C4: Shop phase - card roll pop, buy/sell flow (juice_manual.md section 2 for
# every tween, section 5 for the reroll/merge SFX). The shop roll is
# deterministic per player + round on the server, so the "roll" moment is shop
# entry; slots stay purchasable repeatedly (each buy debits and adds a copy,
# which is how triple-merges are assembled). All prices, balances, and merge
# outcomes come from server responses - the client never computes them.

const ITEM_CARD_SCENE: PackedScene = preload("res://scenes/ui/ItemCard.tscn")
const GRID_PREP_SCENE_PATH: String = "res://scenes/grid_prep/GridPrepScene.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/MainMenu.tscn"

@export var sell_shrink_duration: float = 0.15
@export var pending_sell_alpha: float = 0.5
@export var unaffordable_tint: Color = Color(0.45, 0.45, 0.5, 0.65)
@export var merge_particle_lifetime: float = 0.4
@export var press_squish_scale: float = 0.94
@export var press_squish_duration: float = 0.05
@export var press_release_duration: float = 0.10

@onready var _background: ColorRect = %Background
@onready var _stats_hud: StatsHud = %StatsHud
@onready var _hub_button: Button = %HubButton
@onready var _shop_caption: Label = %ShopCaption
@onready var _shop_row: HBoxContainer = %ShopRow
@onready var _bench_row: HBoxContainer = %BenchRow
@onready var _recycler_panel: PanelContainer = %RecyclerPanel
@onready var _deploy_button: Button = %DeployButton
@onready var _status_label: Label = %StatusLabel
@onready var _drag_layer: Control = %DragLayer

var _dragging_card: ItemCard = null
var _drag_origin: Node = null
var _pending_sell_card: ItemCard = null
var _purchase_in_flight: bool = false
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
	_shop_caption.text = "REQUISITION - ROUND %d" % GameState.current_round

	ApiClient.roll_shop_completed.connect(_on_roll_shop_completed)
	ApiClient.roll_shop_failed.connect(_on_roll_shop_failed)
	ApiClient.purchase_item_completed.connect(_on_purchase_item_completed)
	ApiClient.purchase_item_failed.connect(_on_purchase_item_failed)
	ApiClient.sell_item_completed.connect(_on_sell_item_completed)
	ApiClient.sell_item_failed.connect(_on_sell_item_failed)
	ApiClient.award_round_gold_completed.connect(_on_award_round_gold_completed)
	ApiClient.award_round_gold_failed.connect(_on_award_round_gold_failed)

	_hub_button.pressed.connect(_on_hub_pressed)
	_deploy_button.pressed.connect(_on_deploy_pressed)

	AudioManager.play_prep_bgm()
	_stats_hud.refresh()
	_render_bench()
	_request_round_grant()
	_request_shop()

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
	_set_status("ROUND GRANT +%dG" % int(data.get("gold_awarded", 0)))

func _on_award_round_gold_failed(_code: int, reason: String) -> void:
	_set_status("GRANT FAILED - %s" % reason)

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
	_set_status("SHOP ROLL FAILED - %s" % reason)

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
		_set_status("REQUISITIONED")

func _on_purchase_item_failed(_code: int, reason: String) -> void:
	_purchase_in_flight = false
	_set_status("PURCHASE FAILED - %s" % reason)

func _celebrate_merge(merged_item: Dictionary) -> void:
	_set_status("TRIPLE-MERGE - LV%d %s" % [int(merged_item.get("level", 2)),
		String(merged_item.get("name", "?")).to_upper()])
	for card: ItemCard in _bench_row.get_children():
		if card.get("_item_data").get("item_id", "") == merged_item.get("item_id", ""):
			_spawn_merge_burst(card.get_global_rect().get_center())
			return

# Rising chime + particle impact (juice contract section 5 SFX matrix).
func _spawn_merge_burst(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	particles.emission_ring_radius = 60.0
	particles.emission_ring_inner_radius = 20.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 32
	particles.lifetime = merge_particle_lifetime
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	var grad := Gradient.new()
	grad.set_color(0, Color(SynGridPalette.ACCENT_PURPLE, 0.9))
	grad.set_color(1, Color(SynGridPalette.ACCENT_TEAL, 0.0))
	particles.color_ramp = grad
	_drag_layer.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	get_tree().create_timer(merge_particle_lifetime + 0.1).timeout.connect(particles.queue_free)

# -- Bench + sell flow --

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
		var card: ItemCard = ITEM_CARD_SCENE.instantiate()
		_bench_row.add_child(card)
		card.set_item_data(item)
		card.drag_started.connect(_on_card_drag_started)
		card.drag_ended.connect(_on_card_drag_ended)
		var item_id: String = item.get("item_id", "")
		fresh_ids[item_id] = true
		if not _known_bench_ids.has(item_id):
			card.play_pop(pop_idx)
			pop_idx += 1
	_known_bench_ids = fresh_ids

func _on_card_drag_started(card: ItemCard) -> void:
	_dragging_card = card
	_drag_origin = card.get_parent()
	var pos := card.global_position
	_drag_origin.remove_child(card)
	_drag_layer.add_child(card)
	card.global_position = pos
	AudioManager.play_item_drag()

func _process(_delta: float) -> void:
	if _dragging_card == null:
		return
	var center := _dragging_card.global_position + _dragging_card.size / 2.0
	var hot := _recycler_panel.get_global_rect().has_point(center)
	_recycler_panel.add_theme_stylebox_override("panel",
		_recycler_hot_style if hot else _recycler_rest_style)

func _on_card_drag_ended(card: ItemCard, drop_pos: Vector2) -> void:
	var origin := _drag_origin
	_dragging_card = null
	_drag_origin = null
	_recycler_panel.add_theme_stylebox_override("panel", _recycler_rest_style)

	if _recycler_panel.get_global_rect().has_point(drop_pos) and _pending_sell_card == null:
		_sell_card(card)
	else:
		_drag_layer.remove_child(card)
		origin.add_child(card)
	if _bench_dirty:
		_bench_dirty = false
		_render_bench()

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
	_set_status("RECYCLED +%dG" % credited)
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
	_set_status("SELL FAILED - %s" % reason)
	if _pending_sell_card != null:
		var card := _pending_sell_card
		_pending_sell_card = null
		card.modulate.a = 1.0
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		_drag_layer.remove_child(card)
		_bench_row.add_child(card)

# -- Navigation --

func _on_deploy_pressed() -> void:
	await _pulse(_deploy_button).finished
	get_tree().change_scene_to_file(GRID_PREP_SCENE_PATH)

func _on_hub_pressed() -> void:
	await _pulse(_hub_button).finished
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

# -- Juice helpers (contract section 2: never linear) --

func _pulse(control: Control) -> Tween:
	control.pivot_offset = control.size / 2.0
	var tw := create_tween()
	tw.tween_property(control, "scale", Vector2(press_squish_scale, press_squish_scale),
		press_squish_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(control, "scale", Vector2.ONE, press_release_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tw

func _set_status(text: String) -> void:
	_status_label.text = text
