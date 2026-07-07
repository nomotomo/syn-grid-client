class_name HpBar
extends Control

# Combat HP + shield bar. Values come straight from TickEvent after-fields -
# this component never computes damage. The HP number sits on a fully opaque
# backing (juice contract section 1 bans glass behind live numeric values).

@export var fill_tween_duration: float = 0.08
@export var hp_low_pct: float = 0.3
@export var shield_strip_height: float = 12.0
@export var segment_count: int = 10  # COMBAT_MAX_HP / 100.0 at the 1000 baseline

var _max_hp: float = 1000.0
var _max_shield: float = 0.0
var _hp: float = 1000.0
var _shield: float = 0.0

var _bg: ColorRect
var _hp_fill: ColorRect
var _shield_fill: ColorRect
var _segment_dividers: Array = []  # Array[ColorRect]
var _text: Label

func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = SynGridPalette.PANEL_BG_ELEVATED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = SynGridPalette.HP_HIGH
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_fill)
	_shield_fill = ColorRect.new()
	_shield_fill.color = Color(SynGridPalette.ACCENT_TEAL, 0.45)
	_shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shield_fill)
	for i in segment_count - 1:
		var divider := ColorRect.new()
		divider.color = Color(SynGridPalette.PANEL_BG, 0.8)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(divider)
		_segment_dividers.append(divider)
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 20)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	resized.connect(_relayout)
	_relayout()
	_apply(false)

func setup(max_hp: float, initial_shield: float) -> void:
	_max_hp = maxf(max_hp, 1.0)
	_hp = max_hp
	_shield = initial_shield
	_max_shield = initial_shield
	_apply(false)

# Server-authoritative after-values from a TickEvent (or the log's finals).
func set_state(hp: float, shield: float) -> void:
	_hp = maxf(hp, 0.0)
	_shield = maxf(shield, 0.0)
	_max_shield = maxf(_max_shield, _shield)
	_apply(true)

func _relayout() -> void:
	var hp_height := size.y - shield_strip_height
	_bg.position = Vector2.ZERO
	_bg.size = size
	_hp_fill.position = Vector2.ZERO
	_hp_fill.size = Vector2(_hp_fill.size.x, hp_height)
	_shield_fill.position = Vector2(0, hp_height)
	_shield_fill.size = Vector2(_shield_fill.size.x, shield_strip_height)
	_text.position = Vector2.ZERO
	_text.size = Vector2(size.x, hp_height)
	for i in _segment_dividers.size():
		var x := size.x * float(i + 1) / float(segment_count)
		var divider: ColorRect = _segment_dividers[i]
		divider.position = Vector2(x - 1.0, 0.0)
		divider.size = Vector2(2.0, hp_height)

func _apply(animate: bool) -> void:
	var hp_w := clampf(_hp / _max_hp, 0.0, 1.0) * size.x
	var shield_w := 0.0 if _max_shield <= 0.0 \
		else clampf(_shield / _max_shield, 0.0, 1.0) * size.x
	var hp_color := SynGridPalette.HP_LOW if _hp / _max_hp <= hp_low_pct \
		else SynGridPalette.HP_HIGH
	_text.text = str(int(round(_hp)))
	_hp_fill.color = Color(hp_color, 0.35)
	_text.add_theme_color_override("font_color", hp_color)
	if animate:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_hp_fill, "size:x", hp_w, fill_tween_duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_shield_fill, "size:x", shield_w, fill_tween_duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		_hp_fill.size.x = hp_w
		_shield_fill.size.x = shield_w
