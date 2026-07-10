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

# --- Neon accents - reconciled 2026-07-10 to the authoritative design tokens
# in the Figma Make source (Design Mobile Game UI/src/index.css @theme block),
# now that the real design source is available locally. Values verified there:
# teal #00F5D4, purple #7B2FBE, amber #FFB627, silver #C8CDD6, crimson #D81E3D.
const ACCENT_TEAL: Color = Color(0.0, 0.96, 0.83)     # #00F5D4
const ACCENT_PURPLE: Color = Color(0.48, 0.18, 0.75)  # #7B2FBE
# Warm warning tone (enemy team ring, timer < 30%, low-priority alert).
# Was #D4823E; corrected to the design's #FFB627.
const ACCENT_AMBER: Color = Color(1.0, 0.714, 0.153)  # #FFB627
# Cool metallic (shield tier, silver rank, epic rarity ring).
# Was #B8C4D0; corrected to the design's #C8CDD6.
const ACCENT_SILVER: Color = Color(0.784, 0.804, 0.839)  # #C8CDD6

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
# GOLD reconciled 2026-07-10 to the design's single amber token (#FFB627);
# the design has no separate gold/amber - the Gold HUD pill and gold-tier item
# borders both use --color-amber. Was #F2C74A.
const GOLD: Color = Color(1.0, 0.714, 0.153)          # #FFB627
const HP_HIGH: Color = Color(0.0, 0.96, 0.83)
# HP_LOW reconciled to the design crimson #D81E3D (was #D91A1A).
const HP_LOW: Color = Color(0.847, 0.118, 0.239)      # #D81E3D

# Crimson - danger + fatal HP + defeat wordmark (juice_manual.md section 4).
# Reconciled to the design crimson #D81E3D (was #D91A1A).
const DANGER: Color = Color(0.847, 0.118, 0.239)      # #D81E3D

# Battle-report heatmap: damage-taken tint (issue #31). No existing blue in
# the neon accents - kept separate from HP / danger so heat reads cleanly.
const HEAT_TAKEN: Color = Color(0.2, 0.4, 0.9)

# --- Rarity / tier tints (used on ItemCard tier ring). --------------------
const TIER_BRONZE: Color = Color(0.78, 0.50, 0.29)
const TIER_SILVER: Color = Color(0.784, 0.804, 0.839)  # #C8CDD6, matches ACCENT_SILVER
const TIER_GOLD: Color = Color(1.0, 0.714, 0.153)      # #FFB627, matches GOLD/amber
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
