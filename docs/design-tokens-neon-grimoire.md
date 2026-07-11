# Neon Grimoire Design Tokens — extracted from Figma Make reference

**Jul 2026 update: the design source itself is now vendored in this repo.**
`docs/design-reference/figma-make/` holds the exported Figma Make source (see its README).
For exact values, `docs/design-reference/figma-make/styles/tokens.css` supersedes this doc where they disagree - that file is the design's own token sheet, not an extraction.
This doc remains useful as the Godot-side mapping (which `SynGridPalette.gd` constant corresponds to which design token) and for the reconciliation notes below.

**Figma reference (design intent, browse for layout/composition):**
`https://www.figma.com/make/qlGF5mCe7dWO5rPHmmi11t/Design-Mobile-Game-UI` (requires the team's Figma login).
The published public mirror `https://surly-spout-45387130.figma.site/` was republished Jul 2026 and now matches the vendored export - it is no longer stale and is safe to browse as the rendered reference.
Re-plan context and decisions: `docs/high-level-design/figma-alignment-replan-jul2026.md`.

Cross-reference: `docs/juice_manual.md` (motion/audio contract — unchanged by this doc, this doc
only adds static visual tokens that manual doesn't cover), `scripts/ui/SynGridPalette.gd` (already
has the correct tier/accent hex values — this doc's colors must match that file exactly, not
introduce new ones).

---

## 1. Color tokens

All colors already exist in `SynGridPalette.gd` except where marked **NEW**. Do not invent
additional colors beyond this list.

| Token | Hex | RGB (0-255) | Existing constant | Usage |
|---|---|---|---|---|
| Accent Teal | `#00F5D4` | `0, 245, 212` | `ACCENT_TEAL` | Primary accent, Life-adjacent glow, headline |
| Accent Purple | `#7B2FBE` | `123, 47, 190` | `ACCENT_PURPLE` | Secondary accent, epic tier, Triumph |
| Gold/Amber | `#FFB627` | `255, 182, 39` | close to existing `GOLD`/`TIER_GOLD` — verify exact match, Figma uses `#FFB627` vs current `#F2C74A`, reconcile before implementing | Gold pill, gold tier border, warnings |
| Danger/Life red | `#D81E3D` | `216, 30, 61` | **verify against `DANGER` (`#D91A1A`)** — Figma's Life-pill accent is a slightly different red than the existing DANGER constant; decide whether to unify or keep distinct before implementing | Life pill accent |
| Tier Bronze | `#C7804A` | `199, 128, 74` | `TIER_BRONZE` | Tier I item border |
| Tier Silver | `#C8CDD6` | `200, 205, 214` | `TIER_SILVER`/`ACCENT_SILVER` | Tier II item border |
| Tier Gold | `#FFB627` | `255, 182, 39` | `TIER_GOLD` (reconcile, see above) | Tier III item border |
| Tier Epic | `#7B2FBE` | `123, 47, 190` | `TIER_EPIC` | Tier IV item border |
| Panel background | `#1F1F26` | `31, 31, 38` | matches existing elevated-panel gray already referenced in `juice_manual.md` §1 | HUD pill fill, card fill |
| Panel background (deeper) | `#141419` | `20, 20, 25` | matches `juice_manual.md` §1's base panel gray | Screen background |

**Resolved (Jul 2026 re-plan):** the exported `styles/tokens.css` shows `#FFB627` and `#D81E3D` are deliberate design primitives used consistently across every screen's glow recipes and tier rings.
Decision: update `SynGridPalette.gd` (`GOLD`/`TIER_GOLD` to `#FFB627`, `DANGER` to `#D81E3D`) in one small PR before any Wave 7 visual-pass issue lands.
Tracked as its own issue; see `docs/high-level-design/figma-alignment-replan-jul2026.md` for rationale.
Do not ship two near-duplicate reds/golds in the same palette.

---

## 2. Typography

| Role | Font family | Weight | Notes |
|---|---|---|---|
| Headlines / logo / buttons | `Orbitron` | 900 (logo), 700 (buttons) | Already used in this repo per `MainMenu.gd` CRT/aurora work — confirm it's still the loaded project font |
| Numbers / stats / IDs | `JetBrains Mono` | 700 | Matches existing use in the Profile popover (`MainMenu.gd`) — extend this consistently to all HUD numbers, stat pips, damage numbers |
| Body / labels | inherit from monospace pixel font already in use (`SYN-GRID v2.4.1` style) | — | No change — this is the plain UI font already shipped, keep it for captions/labels, don't replace with Orbitron everywhere |

Letter-spacing on headline/logo text: `6.24px`. Button label letter-spacing: `3px`.

---

## 3. Component recipes

### 3.1 HUD Pill (Round / Gold / Life / Triumph, and any future stat pill)

```
border-radius: 999px               (full pill/capsule)
background: #1F1F26                (solid, opaque — never translucent, these sit behind live numbers)
border: 1px solid {accent}          at 13% opacity
box-shadow:
  0 0 0 1px {accent} at 20% opacity          (outer ring)
  inset 0 1px 0 {accent} at 13% opacity      (top inner highlight)
padding: 4px 10px
gap (icon-to-text): 4px
```

Where `{accent}` is the pill's own stat color (teal for Round, gold for Gold, the Life red for
Life, purple for Triumph). This exact recipe generalizes across all four pills — same shadow/border
math, only the accent color substitutes. Confirmed by extracting both the Gold and Life pills
independently and finding identical structure.

This is the single biggest gap in the current client: `scenes/main_menu/MainMenu.tscn`,
`scenes/grid_prep/GridPrepScene.gd`, and `scenes/combat_replay/CombatReplayScene.gd` all currently
render HUD stats as flat rectangular panels with a thin colored left-bar, not this glowing capsule
— see rendered screenshots from the current build for comparison (available on request, or
re-render via `SYNGRID_SCREENSHOT=...`).

### 3.2 Aurora Button (Play, Fight, Start Match, Continue, Confirm — every primary CTA)

The glow is built from two pseudo-elements layered behind the button, not a single border:

```
Button itself:
  border-radius: 999px
  background: linear-gradient(135deg, #1F1F26 0%, #2A2A33 100%)
  padding: 16px 48px
  font: Orbitron 700, 20px, letter-spacing 3px
  color: #00F5D4 (or white, depending on button — confirm per-button in Figma)

::before (the rotating gradient ring):
  position: absolute, inset: -3px
  border-radius: 999px
  background: linear-gradient(90deg, #00F5D4, #7B2FBE, #00F5D4, #7B2FBE)
  z-index: -1
  animation: 2.5s linear infinite, rotates the gradient around the rim ("aurora-orbit")

::after (the soft outer halo):
  position: absolute, inset: -8px
  border-radius: 999px
  background: linear-gradient(90deg, #00F5D4 at 50% opacity, #7B2FBE at 50% opacity)
  filter: blur(12px)
  z-index: -2
  animation: 2.5s ease-in-out infinite, pulses scale/opacity ("aurora-halo")
```

This matches the *intent* already documented for `assets/shaders/aurora_border.gdshader` (per
`memory/PRD.md`: "teal↔purple gradient orbiting the rim... plus a soft outer halo") — the shader
approach is fine for Godot (better fit than DOM pseudo-elements), but the animation timing (2.5s),
the exact color stops, and the halo's blur radius (12px equivalent) should match this recipe. If
the current shader doesn't animate the gradient rotation or lacks the separate pulsing halo layer,
that's the gap to close.

### 3.3 Item Card tier border + glow

```
border-radius: 8px
border: 2px solid {tier_color}
box-shadow:
  0 0 10px {tier_color} at 40% opacity        (outer glow)
  inset 0 0 6px #141419 at 27% opacity        (inner depth shadow)
background: linear-gradient(135deg, {category_tint} at 6.7% 0%, {category_tint2} at 6.7% 100%)
```

`{tier_color}` = one of the four tier hexes in §1. `{category_tint}` = the existing per-weapon-
category wash already described in `memory/PRD.md` ("warm crimson / forest / purple / steel per
weapon category") — this doc doesn't change that part, just confirms the border now needs a glow
(box-shadow), not just a flat-color border, which is what `ItemCard.gd` currently renders.

### 3.4 Logo / CRT chromatic-aberration headline text

```
font: Orbitron 900, 52px, letter-spacing 6.24px
text-shadow (3 layered shadows, creates the chromatic-fringe + glow look):
  {teal} ±0.7-0.9px horizontal offset, 0 blur      (red/cyan fringe copy 1)
  {purple} ∓0.7-0.9px horizontal offset, 0 blur    (fringe copy 2, opposite direction)
  {glow color} 0 0, ~15-23px blur                  (soft outer glow, color varies per word)
```

This is a CSS approximation of what `assets/shaders/crt_scanline.gdshader`'s `chromatic_shift`
parameter already targets — confirms the existing shader's *intent* is correct, this is just the
precise pixel-offset/blur reference to tune it against if the current chromatic_shift value (1.8
per `memory/PRD.md`) doesn't visually match.

---

## 4. What this doc does NOT cover

Motion/animation timing beyond what's specified above (elastic easing, stagger rhythm, tween
curves) is governed by `docs/juice_manual.md` and unchanged by this doc. Audio is unchanged.
Layout/composition (where things sit on screen, spacing between sections) should be read directly
from the Figma reference link at the top of this doc, or from screenshots taken during the design
review (available on request) — this doc is colors/type/component-recipes only, not full layout
specs.
