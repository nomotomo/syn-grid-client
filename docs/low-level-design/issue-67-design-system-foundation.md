# LLD: Issue #67 - Design System Foundation (HUDPill, AuroraButton, ItemCard glow)

HLD: none separate - this is a targeted upgrade to the existing C10 theme pass, not a new subsystem.
Client issue: #67 (epic #42, Wave 7).
Builds on: `docs/low-level-design/c10-visual-theme-polish.md` (issue #11, CLOSED) - that work already
shipped rounded panels, HUD icons, and a `with_glow` flag on `ThemeBuilder.build_panel_style()`. This
LLD does **not** redo that work. It closes the gap between what #11 shipped and the exact Figma
recipe now documented in `docs/design-tokens-neon-grimoire.md`.
Juice contract: `docs/juice_manual.md` sections 1-3 govern every visual decision below.

## What #11 already shipped (verified against current `main`, not assumed)

- `ThemeBuilder.PANEL_CORNER_RADIUS = 16` (`scripts/ui/ThemeBuilder.gd:21`)
- `build_panel_style(border_color, bg_color, shadow_size, with_glow)` exists and is called by 9 sites
- `StatsHud.tscn` has `RoundIcon`/`GoldIcon`/`LifeIcon`/`TriumphIcon` `TextureRect` nodes wired to real
  Kenney icon sprites (`icon_gold.png`, `icon_life.png`, `icon_triumph.png`, `icon_round.png`)
- `assets/sprites/items/` has real per-category icon PNGs, `ItemCard.gd` renders them with a tint fallback

Rendered proof: `SYNGRID_SCREENSHOT=/tmp/x.png godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn` shows all four HUD panels with real icons, rounded corners, and a colored
left-accent bar - #11's acceptance criteria were genuinely met. **Do not re-scope icon sourcing or
corner-radius-from-zero work; that's done.**

## The actual gap

Comparing the same render against `docs/design-tokens-neon-grimoire.md` §3.1, three things remain:

1. **Shape**: current panels use `PANEL_CORNER_RADIUS = 16` (a moderately rounded rectangle). The
   Figma reference is a full capsule (`border-radius: 999px` - i.e. `corner_radius = min(width, height) / 2`).
2. **Border color**: all four HUD panels currently render with a uniform teal-ish border regardless of
   stat (confirmed visually - Round/Gold/Life/Triumph panels all show the same border hue, only the
   left-accent bar varies per stat). The Figma reference borders each pill in *that stat's own* accent
   color at ~13% opacity, not one shared color.
3. **Glow**: `with_glow` currently drives a single outer soft shadow (Godot `StyleBoxFlat.shadow_size`/
   `shadow_color`, one shadow only). The Figma recipe has two distinct layers - an outer ring at ~20%
   opacity and an inner top-highlight at ~13% opacity. `StyleBoxFlat` has no native inset-shadow
   equivalent to CSS's `inset` box-shadow, so layer 2 needs a decision (see Open Question below).

## Design

### 1. HUD pill shape - new constant, not a `PANEL_CORNER_RADIUS` change

Do not change `PANEL_CORNER_RADIUS` globally (it's used by 9 call sites, most of which are *not* pills
and should stay at 16 - card panels, popovers, etc). Add a pill-specific path:

```gdscript
# ThemeBuilder.gd
static func build_pill_style(accent_color: Color, bg_color: Color = Color(0.122, 0.122, 0.149)) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg_color                                   # #1F1F26, opaque - juice law: no glass behind live numbers
    style.border_color = Color(accent_color, 0.13)
    style.set_border_width_all(1)
    style.corner_radius_top_left = 999
    style.corner_radius_top_right = 999
    style.corner_radius_bottom_left = 999
    style.corner_radius_bottom_right = 999                      # Godot clamps to min(w,h)/2 automatically, safe to over-specify
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    style.shadow_color = Color(accent_color, 0.20)               # outer ring approximation
    style.shadow_size = 1
    return style
```

Corner radius values above 999 are automatically clamped to `min(width, height) / 2` by Godot's
`StyleBoxFlat` - safe to hardcode 999 rather than compute per-instance, this is the same trick the
Figma CSS reference uses (`border-radius: 999px`).

### 2. Per-accent border - StatsHud call-site fix

`StatsHud.gd` (or `.tscn` theme overrides, wherever the 4 panels currently get their style) must pass
each panel's *own* accent color, not a shared one:

| Panel | Accent color source |
|---|---|
| Round | `SynGridPalette.ACCENT_TEAL` |
| Gold | reconcile per `docs/design-tokens-neon-grimoire.md` §1 (Figma `#FFB627` vs. existing `TIER_GOLD`/`GOLD` `#F2C74A` - resolve before this lands, don't ship two golds) |
| Life | reconcile per §1 (Figma `#D81E3D` vs. existing `DANGER` `#D91A1A` - same decision needed) |
| Triumph | `SynGridPalette.ACCENT_PURPLE` |

Both reconciliations are a single decision each (pick the existing `SynGridPalette` value or update
it) - flag whichever is chosen in `SynGridPalette.gd`'s header comment so the next person doesn't
reintroduce drift.

### 3. Glow inset highlight - Open Question, pick one before implementing

`StyleBoxFlat` supports exactly one shadow (outer, soft, single color) - there's no built-in inset
shadow for the top-highlight layer. Two options, pick one and note the choice in the PR:

- **(a) Skip the inset highlight.** The outer ring + opaque background likely reads as "glowing pill"
  without it at this size (4px-10px padding, small pills) - cheapest, matches the juice contract's
  general bias toward simple opaque panels. Recommended default unless it visibly looks flat.
- **(b) Add a second overlay node**: a 1px-tall `ColorRect` pinned to the top inner edge at
  `accent_color @ 13% opacity`, manually positioned - more faithful, more nodes per pill (4 pills ×
  1 extra node = negligible cost, but more scene complexity for a subtle effect).

Try (a) first, screenshot it, only escalate to (b) if the reviewer (Claude Code, PR review protocol)
flags it as too flat.

### 4. Aurora button - audit existing shader before writing anything new

`assets/shaders/aurora_border.gdshader` already exists (`memory/PRD.md`: "renders a teal↔purple
gradient orbiting the rim of the button, plus a soft outer halo... 4-px negative offsets"). Before
writing new code:

1. Render `MainMenuPreviewHarness` and confirm whether the Play button's aurora border is visibly
   animating (a static screenshot can only prove the halo geometry exists, not the rotation - if
   possible check in-editor with the scene running, not just a frame capture).
2. Compare shader uniforms against `docs/design-tokens-neon-grimoire.md` §3.2: rim gradient should
   cycle `#00F5D4 → #7B2FBE → #00F5D4 → #7B2FBE` over `2.5s` linear, halo should pulse `2.5s`
   ease-in-out with a blur radius equivalent to `~12px` at the button's scale.
3. If the shader already matches, this scope item is a no-op - close it as verified, don't rewrite.
4. If uniforms are off, adjust them in the existing shader resource - do not create a second shader.

## Files

- `scripts/ui/ThemeBuilder.gd` - add `build_pill_style()`
- `scenes/ui/StatsHud.tscn` / `StatsHud.gd` (wherever panel styles are currently assigned) - switch to
  `build_pill_style()`, pass real per-stat accent colors
- `scripts/ui/SynGridPalette.gd` - resolve the two color reconciliations, document the decision in a
  header comment
- `assets/shaders/aurora_border.gdshader` - audit, adjust uniforms only if they don't already match
- `scripts/ui/ItemCard.gd` - confirm tier border already uses `with_glow = true` (per #11); if not,
  flip it on - this should be a one-line change, #11 already built the mechanism

## Testing

- `MainMenuPreviewHarness`, `GridPrepPreviewHarness` (4x4 only - other sizes are #66's scope),
  `CombatReplayPreviewHarness`, all 4 `RoundEndPreviewHarness` `SYNGRID_RESULT` modes - screenshot
  every one under `SYNGRID_SCREENSHOT`, confirm HUD pills show per-accent borders and pill shape.
- Visual regression check: corner radius change must not clip the icon or number text inside any pill
  at any of the 4 stat widths (Round's label is longer than Gold's - verify the pill still fits content
  without truncation now that padding/radius changed).
