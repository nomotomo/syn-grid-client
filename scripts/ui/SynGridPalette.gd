class_name SynGridPalette
extends RefCounted

# Single source of truth for every color in the "Dark Fantasy Cyber-Grid"
# theme. No scene, script, or theme resource should hardcode a hex value -
# reference these constants instead so the whole client stays in sync.

# Panel elevation (juice_manual.md section 1).
const PANEL_BG: Color = Color(0.08, 0.08, 0.10)
const PANEL_BG_ELEVATED: Color = Color(0.12, 0.12, 0.15)

# Neon accents - copied verbatim from assets/shaders/synergy_glow.gdshader's
# color_a / color_b uniforms. Keep these two lines identical to that shader.
const ACCENT_TEAL: Color = Color(0.0, 0.96, 0.83)     # #00F5D4
const ACCENT_PURPLE: Color = Color(0.48, 0.18, 0.75)  # #7B2FBE

# Etched circuit-line borders on interactive panels/cards.
const BORDER_DIM: Color = Color(0.0, 0.96, 0.83, 0.25)
const BORDER_ACTIVE: Color = Color(0.0, 0.96, 0.83, 0.9)

# Text.
const TEXT_PRIMARY: Color = Color(0.92, 0.94, 0.95)
const TEXT_DIM: Color = Color(0.55, 0.58, 0.62)

# Live numeric values. juice_manual.md section 1 bans glassmorphic panels
# behind these, so they must stay legible directly on PANEL_BG/PANEL_BG_ELEVATED.
const GOLD: Color = Color(0.95, 0.78, 0.25)
const HP_HIGH: Color = Color(0.0, 0.96, 0.83)
const HP_LOW: Color = Color(0.85, 0.10, 0.10)

# Crimson reused verbatim from juice_manual.md section 4's crit damage-float spec.
const DANGER: Color = Color(0.85, 0.10, 0.10)

# Icon placeholder tint per weapon_category, until real pixel-art sprites are
# sourced (juice_manual.md section 6).
const ITEM_TYPE_TINT: Dictionary = {
	"MELEE": Color(0.75, 0.30, 0.25),
	"RANGED": Color(0.35, 0.65, 0.35),
	"ARCANE": Color(0.48, 0.18, 0.75),
	"": Color(0.45, 0.45, 0.50),
}

static func tint_for_weapon_category(weapon_category: String) -> Color:
	return ITEM_TYPE_TINT.get(weapon_category, ITEM_TYPE_TINT[""])
