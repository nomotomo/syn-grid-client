class_name StatsHud
extends HBoxContainer

# Bento stat strip: round / gold / life / triumph on fully opaque capsule
# pills (juice_manual.md section 1 bans translucency behind live numeric
# values). Pure presentation - values come straight from GameState; scenes
# call refresh() after any server response that mutates session state.
#
# Neon Grimoire visual model:
#   [ 4px accent bar | icon | title over value ]
# The colored accent bar on the left of each pill matches the resource
# identity (silver=round, gold, teal=hp, purple=triumph) - it stays visible
# even when the number itself is unchanged, keeping the HUD alive.

@export var life_low_threshold: int = 2
@export var value_pop_scale: float = 1.3
@export var value_pop_duration: float = 0.25

@onready var _round_panel: PanelContainer = %RoundPanel
@onready var _gold_panel: PanelContainer = %GoldPanel
@onready var _life_panel: PanelContainer = %LifePanel
@onready var _triumph_panel: PanelContainer = %TriumphPanel
@onready var _round_accent: ColorRect = %RoundAccentBar
@onready var _gold_accent: ColorRect = %GoldAccentBar
@onready var _life_accent: ColorRect = %LifeAccentBar
@onready var _triumph_accent: ColorRect = %TriumphAccentBar
@onready var _round_value: Label = %RoundValue
@onready var _gold_value: Label = %GoldValue
@onready var _life_value: Label = %LifeValue
@onready var _triumph_value: Label = %TriumphValue
@onready var _triumph_icon: TextureRect = %TriumphIcon

func _ready() -> void:
	# Every HUD pill uses the L2 capsule style with a soft border glow so
	# the eye reads them as "chrome buttons on a control panel" rather than
	# generic cards. Each pill also carries a tooltip so a long-press /
	# hover surfaces the resource's meaning (glass legal here per
	# juice_manual.md section 1 - tooltips are non-live overlays).
	_round_panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
		SynGridPalette.ACCENT_SILVER, SynGridPalette.PANEL_BG_ELEVATED, true))
	_gold_panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
		SynGridPalette.GOLD, SynGridPalette.PANEL_BG_ELEVATED, true))
	_life_panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
		SynGridPalette.HP_HIGH, SynGridPalette.PANEL_BG_ELEVATED, true))
	_triumph_panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
		SynGridPalette.ACCENT_PURPLE, SynGridPalette.PANEL_BG_ELEVATED, true))
	_round_panel.tooltip_text = "ROUND\nCurrent round of the season."
	_gold_panel.tooltip_text = "GOLD\nSpent at the shop each round to buy items or refresh the roster."
	_life_panel.tooltip_text = "LIFE\nEach lost match subtracts one life. Reach zero and the season resets."
	_triumph_panel.tooltip_text = "TRIUMPH\nSeason score. Earned by winning matches; climbs the leaderboard."
	_round_accent.color = SynGridPalette.ACCENT_SILVER
	_gold_accent.color = SynGridPalette.GOLD
	_life_accent.color = SynGridPalette.HP_HIGH
	_triumph_accent.color = SynGridPalette.ACCENT_PURPLE
	_gold_value.add_theme_color_override("font_color", SynGridPalette.GOLD)
	_triumph_value.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	refresh()

func refresh() -> void:
	_set_value(_round_value, str(GameState.current_round))
	_set_value(_gold_value, str(GameState.gold))
	_set_value(_life_value, str(GameState.life_points))
	var life_color := SynGridPalette.HP_LOW if GameState.life_points <= life_low_threshold \
		else SynGridPalette.HP_HIGH
	_life_value.add_theme_color_override("font_color", life_color)
	_life_accent.color = life_color
	_life_panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
		life_color, SynGridPalette.PANEL_BG_ELEVATED, true))
	_set_value(_triumph_value, str(GameState.triumph_count))

func _set_value(label: Label, new_text: String) -> void:
	if label.text == new_text:
		return
	label.text = new_text
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(value_pop_scale, value_pop_scale)
	create_tween().tween_property(label, "scale", Vector2.ONE, value_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
