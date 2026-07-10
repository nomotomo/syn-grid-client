class_name ThemeBuilder
extends RefCounted

# Builds the Syn-Grid "Neon Grimoire" Theme resource at runtime from
# SynGridPalette constants instead of a hand-authored .tres. This guarantees
# every screen's styling stays in sync with the palette with zero drift.
#
# Scenes opt in by setting `theme = ThemeBuilder.get_theme()` on their root;
# Labels pick a type variation below via `theme_type_variation`.
#
# Elevation model (4 rungs, mirrors SynGridPalette):
#   L0 VOID       - popover backdrops, grid sockets, pressed wells
#   L1 PANEL_BG   - scene canvas
#   L2 ELEVATED   - resting panels/cards/HUD pills          [used by "panel"]
#   L3 HOVER      - hovered/focused/dragging                [used by hover/pressed]

# Font system reconciled 2026-07-10 to the Figma Make design's 3-font model
# (Design Mobile Game UI/src/index.css @theme): Orbitron for display (logo,
# headings, buttons, tabs), Inter for body (descriptions, labels), JetBrains
# Mono for technical text (numbers, IDs, version, tickers). All three are
# variable fonts, so one file per family covers every weight via FontVariation.
# syn_grid_pixel (Press Start 2P) is retained only as a legacy fallback while
# screens are migrated - it is no longer the default.
const DISPLAY_FONT_PATH: String = "res://assets/fonts/Orbitron.ttf"
const BODY_FONT_PATH: String = "res://assets/fonts/Inter.ttf"
const MONO_FONT_PATH: String = "res://assets/fonts/JetBrainsMono.ttf"
const PIXEL_FONT_PATH: String = "res://assets/fonts/syn_grid_pixel.ttf"

const DEFAULT_FONT_SIZE: int = 16
const PANEL_BORDER_WIDTH: int = 1
const PANEL_CORNER_RADIUS: int = 16
const PANEL_GLOW_MARGIN: int = 6
const PANEL_CONTENT_MARGIN: float = 8.0

# Pill-capsule for HUD pills (rounded 999px look via a large radius).
const CAPSULE_CORNER_RADIUS: int = 32
const CAPSULE_CONTENT_MARGIN: float = 10.0

# Button feel.
const BUTTON_CORNER_RADIUS: int = 12
const BUTTON_CONTENT_MARGIN_X: float = 18.0
const BUTTON_CONTENT_MARGIN_Y: float = 12.0

# Primary CTA pill (Play/"Enter the Grid" and any future full-height primary
# action button). Over-specified like CAPSULE_CORNER_RADIUS so Godot clamps
# it to min(width, height)/2 - stays a true pill at any button height instead
# of needing a hand-computed radius per instance.
const CTA_CORNER_RADIUS: int = 999
const CTA_CONTENT_MARGIN_X: float = 48.0
const CTA_CONTENT_MARGIN_Y: float = 16.0

# Label type variations (name -> [font_size, color, font_family, weight]),
# font family/weight mapped to the design's rules (index.css @theme + per-
# element fontFamily in the screen sources): Orbitron display for names/titles/
# badges, JetBrains Mono for numbers/captions/IDs, Inter body for descriptions.
const LABEL_VARIATIONS: Dictionary = {
        "CardNameLabel":  [12, SynGridPalette.TEXT_PRIMARY, "display", 700],
        "BadgeLabel":     [12, SynGridPalette.GOLD,         "mono",    700],
        "CaptionLabel":   [12, SynGridPalette.TEXT_DIM,     "mono",    400],
        "BodyLabel":      [12, SynGridPalette.TEXT_PRIMARY, "body",    400],
        "HudTitleLabel":  [12, SynGridPalette.TEXT_DIM,     "display", 700],
        "HudValueLabel":  [28, SynGridPalette.TEXT_PRIMARY, "mono",    700],
        "StatPipLabel":   [10, SynGridPalette.TEXT_DIM,     "mono",    400],
        "TitleLabel":     [72, SynGridPalette.TEXT_PRIMARY, "display", 900],
}

static var _cached_theme: Theme = null
static var _font_cache: Dictionary = {}

static func get_theme() -> Theme:
        if _cached_theme == null:
                _cached_theme = _build_theme()
        return _cached_theme

# One FontVariation per (family, weight), cached. Variable-font weight axis is
# set via variation_opentype {"wght": N}. Exposed so scenes that build labels
# in code (the logo's two Orbitron-900 lines, HUD number labels, etc.) can pull
# the exact same font instances the theme uses, instead of re-loading TTFs.
static func get_font(family: String, weight: int) -> FontVariation:
        var key := "%s:%d" % [family, weight]
        if _font_cache.has(key):
                return _font_cache[key]
        var path := MONO_FONT_PATH
        match family:
                "display": path = DISPLAY_FONT_PATH
                "body": path = BODY_FONT_PATH
                "mono": path = MONO_FONT_PATH
        var fv := FontVariation.new()
        if ResourceLoader.exists(path):
                fv.base_font = load(path)
        fv.variation_opentype = {"wght": weight}
        _font_cache[key] = fv
        return fv

static func display_font(weight: int = 700) -> FontVariation:
        return get_font("display", weight)

static func body_font(weight: int = 400) -> FontVariation:
        return get_font("body", weight)

static func mono_font(weight: int = 400) -> FontVariation:
        return get_font("mono", weight)

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

# Capsule pill (used by HUD): heavily-rounded corners, tighter horizontal padding,
# optional accent bar rendered by the caller with an anchored ColorRect. Kept
# separate from build_panel_style so item cards etc. keep their 16px radius.
static func build_capsule_style(border_color: Color, bg_color: Color,
                with_glow: bool = true) -> StyleBoxFlat:
        var style := StyleBoxFlat.new()
        style.bg_color = bg_color
        style.border_color = border_color
        style.set_border_width_all(PANEL_BORDER_WIDTH)
        style.set_corner_radius_all(CAPSULE_CORNER_RADIUS)
        style.content_margin_left = CAPSULE_CONTENT_MARGIN + 4.0
        style.content_margin_right = CAPSULE_CONTENT_MARGIN + 4.0
        style.content_margin_top = CAPSULE_CONTENT_MARGIN
        style.content_margin_bottom = CAPSULE_CONTENT_MARGIN
        if with_glow:
                style.shadow_color = border_color
                style.shadow_color.a = 0.30
                style.shadow_size = PANEL_GLOW_MARGIN
        return style

# Button style with tighter content margins + 12px radius (buttons feel
# distinct from panels).
static func build_button_style(border_color: Color, bg_color: Color,
                shadow_size: int = 0, with_glow: bool = false) -> StyleBoxFlat:
        var style := StyleBoxFlat.new()
        style.bg_color = bg_color
        style.border_color = border_color
        style.set_border_width_all(PANEL_BORDER_WIDTH)
        style.set_corner_radius_all(BUTTON_CORNER_RADIUS)
        style.content_margin_left = BUTTON_CONTENT_MARGIN_X
        style.content_margin_right = BUTTON_CONTENT_MARGIN_X
        style.content_margin_top = BUTTON_CONTENT_MARGIN_Y
        style.content_margin_bottom = BUTTON_CONTENT_MARGIN_Y
        if with_glow:
                style.shadow_color = border_color
                style.shadow_color.a = 0.4
                style.shadow_size = PANEL_GLOW_MARGIN + 2
        elif shadow_size > 0:
                style.shadow_size = shadow_size
                style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
        return style

# CTA pill (used by PlayButton and other tall primary actions): same
# corner-radius-clamping trick as build_capsule_style, but with the wider
# horizontal/vertical padding a tall hero button needs. Kept separate from
# build_button_style so ordinary buttons keep their 12px card-like radius.
static func build_cta_style(border_color: Color, bg_color: Color,
                with_glow: bool = true) -> StyleBoxFlat:
        var style := StyleBoxFlat.new()
        style.bg_color = bg_color
        style.border_color = border_color
        style.set_border_width_all(PANEL_BORDER_WIDTH)
        style.set_corner_radius_all(CTA_CORNER_RADIUS)
        style.content_margin_left = CTA_CONTENT_MARGIN_X
        style.content_margin_right = CTA_CONTENT_MARGIN_X
        style.content_margin_top = CTA_CONTENT_MARGIN_Y
        style.content_margin_bottom = CTA_CONTENT_MARGIN_Y
        if with_glow:
                style.shadow_color = border_color
                style.shadow_color.a = 0.4
                style.shadow_size = PANEL_GLOW_MARGIN + 2
        return style

static func _build_theme() -> Theme:
        var theme := Theme.new()

        # Default font is Inter (body) - the design's --font-body, used for the
        # majority of generic UI text. Display (Orbitron) and mono (JetBrains)
        # are applied via type variations below and via Button styling.
        theme.default_font = body_font(400)
        theme.default_font_size = DEFAULT_FONT_SIZE

        # PanelContainer: L2 resting panels.
        theme.set_stylebox("panel", "PanelContainer",
                build_panel_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED))

        # Buttons - primary: dark-fill w/ teal border, hover lifts to L3 + purple
        # accent, pressed inverts to teal fill, disabled hatches to L1.
        theme.set_stylebox("normal", "Button",
                build_button_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED))
        theme.set_stylebox("hover", "Button",
                build_button_style(SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_HOVER, 0, true))
        # "Pressed" reads as an inverted state: teal border darkened to purple
        # accent so the click has clear tactile feedback.
        theme.set_stylebox("pressed", "Button",
                build_button_style(SynGridPalette.ACCENT_PURPLE, SynGridPalette.PANEL_BG_ELEVATED, 0, true))
        theme.set_stylebox("focus", "Button",
                build_button_style(SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_HOVER, 0, true))
        theme.set_stylebox("disabled", "Button",
                build_button_style(Color(0.30, 0.32, 0.35, 0.4), SynGridPalette.PANEL_BG))
        # Buttons use the display font (Orbitron) per the design - AuroraButton
        # and TabBar labels are both font-display/Orbitron bold.
        theme.set_font("font", "Button", display_font(700))
        theme.set_color("font_color", "Button", SynGridPalette.TEXT_PRIMARY)
        theme.set_color("font_hover_color", "Button", SynGridPalette.TEXT_PRIMARY)
        theme.set_color("font_pressed_color", "Button", SynGridPalette.ACCENT_TEAL)
        theme.set_color("font_focus_color", "Button", SynGridPalette.TEXT_PRIMARY)
        theme.set_color("font_disabled_color", "Button", SynGridPalette.TEXT_DIM)

        # LineEdit - sunken well, teal caret.
        theme.set_stylebox("normal", "LineEdit",
                build_panel_style(SynGridPalette.BORDER_DIM, SynGridPalette.VOID))
        theme.set_stylebox("focus", "LineEdit",
                build_panel_style(SynGridPalette.BORDER_ACTIVE, SynGridPalette.VOID, 0, true))
        theme.set_color("font_color", "LineEdit", SynGridPalette.TEXT_PRIMARY)
        theme.set_color("caret_color", "LineEdit", SynGridPalette.ACCENT_TEAL)
        theme.set_color("selection_color", "LineEdit", Color(SynGridPalette.ACCENT_TEAL, 0.35))

        theme.set_color("font_color", "Label", SynGridPalette.TEXT_PRIMARY)

        # Tooltip styling: rounded pill with dim teal border, opaque VOID fill
        # (juice manual bans glass behind LIVE numbers, but tooltips are
        # non-live overlays over static hint text, so they're fair game).
        theme.set_stylebox("panel", "TooltipPanel",
                build_panel_style(SynGridPalette.BORDER_ACTIVE, SynGridPalette.VOID, 0, true))
        theme.set_color("font_color", "TooltipLabel", SynGridPalette.TEXT_PRIMARY)
        theme.set_font_size("font_size", "TooltipLabel", 14)

        for variation_name: String in LABEL_VARIATIONS:
                var spec: Array = LABEL_VARIATIONS[variation_name]
                theme.set_type_variation(variation_name, "Label")
                theme.set_font_size("font_size", variation_name, spec[0])
                theme.set_color("font_color", variation_name, spec[1])
                theme.set_font("font", variation_name, get_font(spec[2], spec[3]))

        return theme
