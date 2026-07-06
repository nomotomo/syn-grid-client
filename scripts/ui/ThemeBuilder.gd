class_name ThemeBuilder
extends RefCounted

# Builds the Syn-Grid Theme resource at runtime from SynGridPalette constants
# instead of a hand-authored .tres. This guarantees every screen's styling
# stays in sync with the palette with zero drift, and avoids shipping a
# hand-typed Theme sub-resource graph that has never been load-tested in the
# Godot editor.
#
# Scenes opt in by setting `theme = ThemeBuilder.get_theme()` on their root;
# Labels pick a type variation below via `theme_type_variation`.

const PIXEL_FONT_PATH: String = "res://assets/fonts/syn_grid_pixel.ttf"

const DEFAULT_FONT_SIZE: int = 16
const PANEL_BORDER_WIDTH: int = 1
const PANEL_CORNER_RADIUS: int = 16
const PANEL_GLOW_MARGIN: int = 6
const PANEL_CONTENT_MARGIN: float = 8.0

# Label type variations (name -> [font_size, color]).
const LABEL_VARIATIONS: Dictionary = {
	"CardNameLabel":  [12, SynGridPalette.TEXT_PRIMARY],
	"BadgeLabel":     [12, SynGridPalette.GOLD],
	"CaptionLabel":   [12, SynGridPalette.TEXT_DIM],
	"HudTitleLabel":  [12, SynGridPalette.TEXT_DIM],
	"HudValueLabel":  [28, SynGridPalette.TEXT_PRIMARY],
	"TitleLabel":     [72, SynGridPalette.TEXT_PRIMARY],
}

static var _cached_theme: Theme = null

static func get_theme() -> Theme:
	if _cached_theme == null:
		_cached_theme = _build_theme()
	return _cached_theme

# Shared rounded neon-glass panel look: flat opaque fill, thin border, optional
# colored outer glow (HUD pills, item slots) or plain drop shadow (drag lift).
static func build_panel_style(border_color: Color, bg_color: Color,
		shadow_size: int = 0, with_glow: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.set_corner_radius_all(PANEL_CORNER_RADIUS)
	style.content_margin_left = PANEL_CONTENT_MARGIN
	style.content_margin_right = PANEL_CONTENT_MARGIN
	style.content_margin_top = PANEL_CONTENT_MARGIN
	style.content_margin_bottom = PANEL_CONTENT_MARGIN
	if with_glow:
		style.shadow_color = border_color
		style.shadow_color.a = 0.35
		style.shadow_size = PANEL_GLOW_MARGIN
	elif shadow_size > 0:
		style.shadow_size = shadow_size
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	return style

static func _build_theme() -> Theme:
	var theme := Theme.new()

	# Pixel font activates automatically once sourced (juice_manual.md
	# section 6) and dropped at PIXEL_FONT_PATH - no code change needed.
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		theme.default_font = load(PIXEL_FONT_PATH)
	theme.default_font_size = DEFAULT_FONT_SIZE

	theme.set_stylebox("panel", "PanelContainer",
		build_panel_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED))

	theme.set_stylebox("normal", "Button",
		build_panel_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED))
	theme.set_stylebox("hover", "Button",
		build_panel_style(SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_ELEVATED))
	theme.set_stylebox("pressed", "Button",
		build_panel_style(SynGridPalette.ACCENT_PURPLE, SynGridPalette.PANEL_BG_ELEVATED))
	theme.set_stylebox("disabled", "Button",
		build_panel_style(Color(0.30, 0.32, 0.35, 0.4), SynGridPalette.PANEL_BG))
	theme.set_color("font_color", "Button", SynGridPalette.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", SynGridPalette.TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "Button", SynGridPalette.TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", SynGridPalette.TEXT_DIM)

	theme.set_stylebox("normal", "LineEdit",
		build_panel_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG))
	theme.set_stylebox("focus", "LineEdit",
		build_panel_style(SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG))
	theme.set_color("font_color", "LineEdit", SynGridPalette.TEXT_PRIMARY)
	theme.set_color("caret_color", "LineEdit", SynGridPalette.ACCENT_TEAL)

	theme.set_color("font_color", "Label", SynGridPalette.TEXT_PRIMARY)

	for variation_name: String in LABEL_VARIATIONS:
		var spec: Array = LABEL_VARIATIONS[variation_name]
		theme.set_type_variation(variation_name, "Label")
		theme.set_font_size("font_size", variation_name, spec[0])
		theme.set_color("font_color", variation_name, spec[1])

	return theme
