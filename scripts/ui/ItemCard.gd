class_name ItemCard
extends PanelContainer

# Reusable, presentation-only item card. Every screen (Shop, Grid-Prep,
# Combat Replay) instances scenes/ui/ItemCard.tscn and drives it via
# set_item_data() / play_pop() / play_snap_bounce(). It never touches
# shop/grid/economy logic - callers connect to the signals below and decide
# what happens next. The card owns every tween that animates itself, so
# scale/rotation animations can never fight across owners.

signal card_pressed(item_data: Dictionary)
signal drag_started(card: ItemCard)
signal drag_ended(card: ItemCard, drop_global_pos: Vector2)

@export var card_size: Vector2 = Vector2(150, 150)

# Card pop (juice_manual.md section 2 - play_card_pop reference implementation).
@export var card_pop_duration: float = 0.12
@export var card_pop_settle_duration: float = 0.06
@export var card_stagger_interval: float = 0.04

# Drag-and-drop tilt (juice_manual.md section 2).
@export var drag_tilt_scale: float = 0.04
@export var drag_tilt_max: float = 0.35
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

@onready var _icon_rect: ColorRect = %IconRect
@onready var _name_label: Label = %NameLabel
@onready var _badge_label: Label = %BadgeLabel

var _item_data: Dictionary = {}
var _dragging: bool = false
var _press_start_pos: Vector2 = Vector2.ZERO
var _drag_target_pos: Vector2 = Vector2.ZERO
var _scale_tween: Tween = null
var _rest_style: StyleBoxFlat
var _drag_style: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = card_size
	# All scale/rotation juice pivots on the card centre; the Control default
	# (top-left) makes pops and tilts look lopsided.
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	_rest_style = ThemeBuilder.build_panel_style(
		SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED)
	_drag_style = ThemeBuilder.build_panel_style(
		SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_ELEVATED, drag_shadow_size)
	add_theme_stylebox_override("panel", _rest_style)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_item_data(item: Dictionary) -> void:
	_item_data = item
	_name_label.text = String(item.get("name", item.get("template_name", "?")))
	_icon_rect.color = SynGridPalette.tint_for_weapon_category(item.get("weapon_category", ""))

	if item.has("buy_price"):
		_badge_label.text = "%dg" % int(item["buy_price"])
		_badge_label.visible = true
	elif int(item.get("level", 1)) > 1:
		_badge_label.text = "Lv%d" % int(item["level"])
		_badge_label.visible = true
	else:
		_badge_label.visible = false

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
		if not _dragging and event.global_position.distance_to(_press_start_pos) > drag_threshold_px:
			_begin_drag()
		if _dragging:
			rotation = clamp(event.relative.x * drag_tilt_scale, -drag_tilt_max, drag_tilt_max)
			_drag_target_pos += event.relative

func _begin_drag() -> void:
	_dragging = true
	add_theme_stylebox_override("panel", _drag_style)
	_tween_scale(Vector2(drag_lift_scale, drag_lift_scale), scale_pop_duration, Tween.TRANS_ELASTIC)
	drag_started.emit(self)

func _end_drag(drop_global_pos: Vector2) -> void:
	add_theme_stylebox_override("panel", _rest_style)
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
