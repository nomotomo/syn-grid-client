class_name SynGridPalette
extends RefCounted

# Single source of truth for every color in the "Neon Grimoire" theme
# (evolves the earlier "Dark Fantasy Cyber-Grid" spec). No scene, script,
# or theme resource should hardcode a hex value - reference these
# constants instead so the whole client stays in sync.
#
# Neon is punctuation, not background. Panels stay on PANEL_BG / _ELEVATED;
# ACCENT_* / GOLD / DANGER only appear on borders, glyphs, and pips.

# --- Panel elevation ladder (rung 0 -> 3). --------------------------------
# L0 - popover backdrops, grid cell sockets, "pressed" wells
const VOID: Color = Color(0.04, 0.04, 0.06)
# L1 - scene canvas (juice_manual.md section 1 baseline)
const PANEL_BG: Color = Color(0.08, 0.08, 0.10)
# L2 - resting panels, HUD pills, item cards
const PANEL_BG_ELEVATED: Color = Color(0.12, 0.12, 0.15)
# L3 - hovered / focused / dragging
const PANEL_BG_HOVER: Color = Color(0.15, 0.15, 0.19)

# --- Neon accents - copied verbatim from assets/shaders/synergy_glow.gdshader.
const ACCENT_TEAL: Color = Color(0.0, 0.96, 0.83)     # #00F5D4
const ACCENT_PURPLE: Color = Color(0.48, 0.18, 0.75)  # #7B2FBE
# NEW: warm warning tone (enemy team ring, timer < 30%, low-priority alert)
const ACCENT_AMBER: Color = Color(0.83, 0.51, 0.24)   # #D4823E
# NEW: cool metallic (shield tier, silver rank, epic rarity ring)
const ACCENT_SILVER: Color = Color(0.72, 0.77, 0.82)  # #B8C4D0

# --- Borders (etched circuit-line borders on interactive panels/cards). ---
const BORDER_DIM: Color = Color(0.0, 0.96, 0.83, 0.25)
const BORDER_ACTIVE: Color = Color(0.0, 0.96, 0.83, 0.9)
# NEW: chrome-bevel highlight (top 1px of Level 2+ panels)
const BORDER_HIGHLIGHT: Color = Color(0.0, 0.96, 0.83, 0.08)

# --- Text. ---------------------------------------------------------------
# Parchment-tinted off-white gives the grimoire feel without hurting legibility
# on VOID / PANEL_BG. Pure white reads too "modern SaaS".
const TEXT_PRIMARY: Color = Color(0.91, 0.89, 0.85)   # #E8E4D8 parchment
const TEXT_DIM: Color = Color(0.55, 0.58, 0.62)

# --- Live numeric values. juice_manual.md section 1 bans glassmorphic panels
# behind these, so they must stay legible directly on PANEL_BG/PANEL_BG_ELEVATED.
const GOLD: Color = Color(0.95, 0.78, 0.29)           # #F2C74A warmed
const HP_HIGH: Color = Color(0.0, 0.96, 0.83)
const HP_LOW: Color = Color(0.85, 0.10, 0.10)

# Crimson - danger + fatal HP + defeat wordmark (juice_manual.md section 4).
const DANGER: Color = Color(0.85, 0.10, 0.10)

# --- Rarity / tier tints (used on ItemCard tier ring). --------------------
const TIER_BRONZE: Color = Color(0.78, 0.50, 0.29)
const TIER_SILVER: Color = Color(0.72, 0.77, 0.82)
const TIER_GOLD: Color = Color(0.95, 0.78, 0.29)
const TIER_EPIC: Color = Color(0.48, 0.18, 0.75)

# --- Weapon category tints (ColorRect fallback when no sprite matches;
# also drives ItemCard radial background wash).
const ITEM_TYPE_TINT: Dictionary = {
        "MELEE": Color(0.75, 0.30, 0.25),
        "RANGED": Color(0.35, 0.65, 0.35),
        "ARCANE": Color(0.48, 0.18, 0.75),
        "": Color(0.45, 0.45, 0.50),
}

static func tint_for_weapon_category(weapon_category: String) -> Color:
        return ITEM_TYPE_TINT.get(weapon_category, ITEM_TYPE_TINT[""])

# Map an integer tier (1..N, server-provided) to its ring color.
static func tint_for_tier(tier: int) -> Color:
        match tier:
                1: return TIER_BRONZE
                2: return TIER_SILVER
                3: return TIER_GOLD
                _:
                        if tier >= 4:
                                return TIER_EPIC
                        return TIER_BRONZE
