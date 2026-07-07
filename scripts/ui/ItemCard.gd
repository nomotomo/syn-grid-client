class_name ItemCard
extends PanelContainer

# Reusable, presentation-only item card. Every screen (Shop, Grid-Prep,
# Combat Replay) instances scenes/ui/ItemCard.tscn and drives it via
# set_item_data() / play_pop() / play_snap_bounce(). It never touches
# shop/grid/economy logic - callers connect to the signals below and decide
# what happens next. The card owns every tween that animates itself, so
# scale/rotation animations can never fight across owners.
#
# Neon Grimoire visual model:
#   * Tier-colored panel border (bronze/silver/gold/epic) built from
#     SynGridPalette.tint_for_tier(item.level).
#   * Category tint radial background wash (%TintBg) - warm crimson for
#     MELEE, forest for RANGED, purple for ARCANE, steel for SHIELD.
#   * Icon fills the top 55% of the card.
#   * Stat pips (%AtkPip / %DefPip / %SpdPip) sit in a 14% band under the
#     icon and read out base_attributes returned by the server.
#   * Cost chip (%BadgeLabel) top-left, tier chip (%TierLabel) top-right.

signal card_pressed(item_data: Dictionary)
signal drag_started(card: ItemCard)
signal drag_ended(card: ItemCard, drop_global_pos: Vector2)

@export var card_size: Vector2 = Vector2(140, 168)

# Shop slots are tap-to-buy and must never enter the drag lifecycle.
@export var draggable: bool = true

# Card pop (juice_manual.md section 2 - play_card_pop reference implementation).
@export var card_pop_duration: float = 0.12
@export var card_pop_settle_duration: float = 0.06
@export var card_stagger_interval: float = 0.04

# Drag-and-drop tilt (juice_manual.md section 2).
@export var drag_tilt_scale: float = 0.04
@export var drag_tilt_max: float = deg_to_rad(15.0)
@export var drag_lerp_weight: float = 0.65
@export var drag_spring_duration: float = 0.15
@export var drag_threshold_px: float = 6.0

# Hover / pickup feedback (juice_manual.md section 2 - no visible property
# moves without an overshoot curve, including these).
@export var hover_scale: float = 1.05
@export var drag_lift_scale: float = 1.08
@export var scale_pop_duration: float = 0.12
@export var scale_settle_duration: float = 0.10
@export var drag_shadow_size: int = 14

# Grid snap bounce (juice_manual.md section 2).
@export var snap_squish_duration: float = 0.06
@export var snap_bounce_duration: float = 0.08
@export var snap_settle_duration: float = 0.04

# Combat replay match-ending shatter (issue #28).
@export var shatter_duration: float = 0.35

# Neon Grimoire card treatment.
@export var tint_bg_alpha: float = 0.14
@export var tint_bg_alpha_dragging: float = 0.24

@onready var _tint_bg: ColorRect = %TintBg
@onready var _icon_rect: ColorRect = %IconRect
@onready var _icon_texture: TextureRect = %IconTexture
@onready var _name_label: Label = %NameLabel
@onready var _badge_label: Label = %BadgeLabel
@onready var _tier_label: Label = %TierLabel
@onready var _atk_pip: Label = %AtkPip
@onready var _def_pip: Label = %DefPip
@onready var _spd_pip: Label = %SpdPip

var _item_data: Dictionary = {}
var _dragging: bool = false
var _press_start_pos: Vector2 = Vector2.ZERO
var _drag_target_pos: Vector2 = Vector2.ZERO
var _scale_tween: Tween = null
var _tier_color: Color = SynGridPalette.TIER_BRONZE

func _ready() -> void:
	custom_minimum_size = card_size
	# All scale/rotation juice pivots on the card centre; the Control default
	# (top-left) makes pops and tilts look lopsided.
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	_apply_rest_style()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _icon_path_for(item: Dictionary) -> String:
	var category := String(item.get("weapon_category", "")).to_lower()
	if category == "":
		category = "shield"
	var display_name := String(item.get("name", item.get("template_name", "")))
	var slug := display_name.to_lower().replace(" ", "_")
	return "res://assets/sprites/items/icon_%s_%s.png" % [category, slug]

func set_item_data(item: Dictionary) -> void:
	_item_data = item
	_name_label.text = String(item.get("name", item.get("template_name", "?")))

	var path := _icon_path_for(item)
	if ResourceLoader.exists(path):
		_icon_texture.texture = load(path)
		_icon_texture.visible = true
		_icon_rect.visible = false
	else:
		_icon_texture.visible = false
		_icon_rect.visible = true
		_icon_rect.color = SynGridPalette.tint_for_weapon_category(item.get("weapon_category", ""))

	# Category tint radial wash across the card.
	var cat_tint := SynGridPalette.tint_for_weapon_category(item.get("weapon_category", ""))
	_tint_bg.color = Color(cat_tint.r, cat_tint.g, cat_tint.b, tint_bg_alpha)

	# Tier ring color from level (bronze/silver/gold/epic).
	var level := int(item.get("level", 1))
	_tier_color = SynGridPalette.tint_for_tier(level)

	# Cost chip (shop only) OR level chip (bench/grid).
	if item.has("buy_price"):
		_badge_label.text = "%dg" % int(item["buy_price"])
		_badge_label.visible = true
	else:
		_badge_label.visible = false

	if level > 1:
		_tier_label.text = _roman(level)
		_tier_label.add_theme_color_override("font_color", _tier_color)
		_tier_label.visible = true
	else:
		_tier_label.visible = false

	# Stat pips - drawn from server-provided base_attributes so this card never
	# invents numbers. Each pip carries its own colored glyph so the eye can
	# scan an entire shop row at once. Glyphs are ASCII so the project's
	# pixel font renders them cleanly (Unicode geometric shapes are missing).
	var attrs: Dictionary = item.get("base_attributes", {}) as Dictionary
	_set_pip(_atk_pip, "A", _pip_value(attrs, ["base_dmg", "attack", "atk"]),
			SynGridPalette.DANGER)
	_set_pip(_def_pip, "D", _pip_value(attrs, ["armor_rating", "defense", "def"]),
			SynGridPalette.ACCENT_SILVER)
	_set_pip(_spd_pip, "S", _pip_value(attrs, ["attack_speed", "speed", "spd"]),
			SynGridPalette.ACCENT_TEAL)

	_apply_rest_style()

func _pip_value(attrs: Dictionary, keys: Array) -> int:
	for k in keys:
		if attrs.has(k):
			return int(round(float(attrs[k])))
	return -1

func _set_pip(label: Label, glyph: String, value: int, color: Color) -> void:
	if value < 0:
		label.text = ""
		return
	label.text = "%s %d" % [glyph, value]
	label.add_theme_color_override("font_color", color)

func _roman(n: int) -> String:
	# Small helper - enough for tier labels 1..10; anything higher wraps to arabic.
	var table := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	if n <= 0 or n > 10:
		return str(n)
	var out := ""
	var v := n
	for pair: Array in table:
		while v >= int(pair[0]):
			out += String(pair[1])
			v -= int(pair[0])
	return out

func _apply_rest_style() -> void:
	add_theme_stylebox_override("panel", ThemeBuilder.build_panel_style(
		_tier_color, SynGridPalette.PANEL_BG_ELEVATED, 0, true))

func _apply_drag_style() -> void:
	add_theme_stylebox_override("panel", ThemeBuilder.build_panel_style(
		SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_HOVER, drag_shadow_size))

func play_pop(stagger_idx: int) -> void:
	_kill_scale_tween()
	scale = Vector2.ZERO
	_scale_tween = create_tween().set_parallel(false)
	_scale_tween.tween_interval(stagger_idx * card_stagger_interval)
	_scale_tween.tween_property(self, "scale", Vector2(1.1, 1.1), card_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), card_pop_settle_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

# Y-axis squish -> overshoot bounce -> settle, per the contract's grid snap
# spec. Called by the grid scene on a locally-valid placement.
func play_snap_bounce() -> void:
	_kill_scale_tween()
	scale = Vector2.ONE
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale:y", 0.75, snap_squish_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_scale_tween.tween_property(self, "scale:y", 1.05, snap_bounce_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_scale_tween.tween_property(self, "scale:y", 1.0, snap_settle_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

## Combat-replay telemetry hook: parents a decoration (e.g. DamageMeter) inside
## the plain Content control, not the PanelContainer root. The root runs a
## container sort pass that calls fit_child_in_rect on every direct child and
## overrides manual anchors/position; Content is a plain Control, so anchors
## set from outside stick - the same way every built-in decoration already does.
func add_overlay(node: Control) -> void:
	$Content.add_child(node)

func play_shatter() -> void:
	_kill_scale_tween()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.2, 0.4), shatter_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "modulate:a", 0.0, shatter_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _gui_input(event: InputEvent) -> void:
	# Use each event's own position data rather than get_global_mouse_position(),
	# which reflects live input-server/cursor state and isn't reliable for
	# touch-emulated-mouse input on the mobile targets this client ships to.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = false
			_press_start_pos = event.global_position
			_drag_target_pos = global_position
		else:
			if _dragging:
				_end_drag(event.global_position)
			else:
				card_pressed.emit(_item_data)
			_dragging = false
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not _dragging and draggable and event.global_position.distance_to(_press_start_pos) > drag_threshold_px:
			_begin_drag()
		if _dragging:
			rotation = clamp(event.relative.x * drag_tilt_scale, -drag_tilt_max, drag_tilt_max)
			_drag_target_pos += event.relative

func _begin_drag() -> void:
	_dragging = true
	_apply_drag_style()
	# Pull the category tint slightly forward while held.
	var c := _tint_bg.color
	_tint_bg.color = Color(c.r, c.g, c.b, tint_bg_alpha_dragging)
	_tween_scale(Vector2(drag_lift_scale, drag_lift_scale), scale_pop_duration, Tween.TRANS_ELASTIC)
	drag_started.emit(self)

## Scene-level recovery when a release event is missed or a new drag supersedes
## this one. No-op if the card is not mid-drag.
func force_end_drag(drop_global_pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	_end_drag(drop_global_pos)

func _end_drag(drop_global_pos: Vector2) -> void:
	_apply_rest_style()
	var c := _tint_bg.color
	_tint_bg.color = Color(c.r, c.g, c.b, tint_bg_alpha)
	var tween_before_drop := _scale_tween
	drag_ended.emit(self, drop_global_pos)
	_spring_rotation_to_zero()
	# If the drop handler already started its own card animation (e.g.
	# play_snap_bounce on a valid placement), leave it alone; otherwise settle
	# the drag-lift scale back to rest.
	if _scale_tween == tween_before_drop:
		_tween_scale(Vector2.ONE, scale_settle_duration, Tween.TRANS_BACK)

func _physics_process(_delta: float) -> void:
	if _dragging:
		global_position = global_position.lerp(_drag_target_pos, drag_lerp_weight)

func _on_mouse_entered() -> void:
	if _dragging:
		return
	_tween_scale(Vector2(hover_scale, hover_scale), scale_pop_duration, Tween.TRANS_ELASTIC)

func _on_mouse_exited() -> void:
	if _dragging:
		return
	_tween_scale(Vector2.ONE, scale_settle_duration, Tween.TRANS_BACK)

func _tween_scale(target: Vector2, duration: float, trans: Tween.TransitionType) -> void:
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", target, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(trans)

func _kill_scale_tween() -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()

func _spring_rotation_to_zero() -> void:
	create_tween().tween_property(self, "rotation", 0.0, drag_spring_duration) \
		.set_trans(Tween.TRANS_SPRING)
