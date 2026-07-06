class_name StatsHud
extends HBoxContainer

# Bento stat strip: round / gold / life / triumph on fully opaque panels
# (juice_manual.md section 1 bans translucency behind live numeric values).
# Pure presentation - values come straight from GameState; scenes call
# refresh() after any server response that mutates session state.

@export var life_low_threshold: int = 2
@export var value_pop_scale: float = 1.3
@export var value_pop_duration: float = 0.25

@onready var _round_panel: PanelContainer = %RoundPanel
@onready var _gold_panel: PanelContainer = %GoldPanel
@onready var _life_panel: PanelContainer = %LifePanel
@onready var _triumph_panel: PanelContainer = %TriumphPanel
@onready var _round_value: Label = %RoundValue
@onready var _gold_value: Label = %GoldValue
@onready var _life_value: Label = %LifeValue
@onready var _triumph_value: Label = %TriumphValue
@onready var _triumph_icon: TextureRect = %TriumphIcon

func _ready() -> void:
	for panel: PanelContainer in [_round_panel, _gold_panel, _life_panel, _triumph_panel]:
		panel.add_theme_stylebox_override("panel", ThemeBuilder.build_panel_style(
			SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED, 0, true))
	_gold_value.add_theme_color_override("font_color", SynGridPalette.GOLD)
	_triumph_value.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	# Kenney white stencils need a tint to read on dark panels.
	_triumph_icon.self_modulate = SynGridPalette.ACCENT_TEAL
	refresh()

func refresh() -> void:
	_set_value(_round_value, str(GameState.current_round))
	_set_value(_gold_value, str(GameState.gold))
	_set_value(_life_value, str(GameState.life_points))
	_life_value.add_theme_color_override("font_color",
		SynGridPalette.HP_LOW if GameState.life_points <= life_low_threshold
		else SynGridPalette.HP_HIGH)
	_set_value(_triumph_value, str(GameState.triumph_count))

func _set_value(label: Label, new_text: String) -> void:
	if label.text == new_text:
		return
	label.text = new_text
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(value_pop_scale, value_pop_scale)
	create_tween().tween_property(label, "scale", Vector2.ONE, value_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
