# LLD: Issue #67 - Design System Foundation (HUD pill accent color, AuroraButton, ItemCard glow)

HLD: none separate - this is a targeted upgrade to the existing C10 theme pass, not a new subsystem.
Client issue: #67 (epic #42, Wave 7).
Builds on: `docs/low-level-design/c10-visual-theme-polish.md` (issue #11, CLOSED, verified shipped -
see below). This LLD does **not** redo that work.
Juice contract: `docs/juice_manual.md` sections 1-3 govern every visual decision below.

**Revision note:** this LLD was rewritten after reading the actual call sites instead of inferring
from a screenshot. The first version proposed a new `build_pill_style()` function and a
`corner_radius: 999` change - both wrong, see "What's already correct" below. Read this version, not
that reasoning.

## What's already correct (verified by reading the code, not assumed)

- `ThemeBuilder.build_capsule_style(border_color, bg_color, with_glow)` already exists
  (`scripts/ui/ThemeBuilder.gd:77-92`), already takes a border color parameter, and already applies a
  glow (`shadow_color = border_color @ 30% alpha, shadow_size = 6px`) when `with_glow = true`.
- `CAPSULE_CORNER_RADIUS = 32` (`ThemeBuilder.gd:26`). `StatsHud.tscn` gives each pill no explicit
  height, so natural height is driven by content: a 40px accent bar, a 28px icon, and a two-line
  title+value label stack, plus `CAPSULE_CONTENT_MARGIN` (10px top/bottom) - net panel height lands
  around 60-64px. Godot's `StyleBoxFlat` corner radius auto-clamps to `min(width, height) / 2`, so a
  32px radius on a ~62px-tall panel is already at or near the clamp ceiling - **this already renders as
  a full pill, not a moderately-rounded rectangle.** Do not add a "shape" fix; there isn't a shape gap.
- `StatsHud.gd:39-41` already calls `build_capsule_style(..., true)` - glow is already on.

## The actual, confirmed gap

`StatsHud.gd:39-41`:

```gdscript
for panel: PanelContainer in [_round_panel, _gold_panel, _life_panel, _triumph_panel]:
    panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
        SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED, true))
```

This loop passes the **same** `SynGridPalette.BORDER_DIM` to all four panels. `BORDER_DIM` is defined
as `Color(0.0, 0.96, 0.83, 0.25)` (`SynGridPalette.gd:31`) - literally `ACCENT_TEAL` at 25% alpha. So
every pill's border *and* glow (since glow color = border color per `build_capsule_style`) render in
the same dim teal, regardless of which stat it is. Only the small 4px accent `ColorRect` bar
(`StatsHud.gd:46-49`) actually varies per stat today. This is the one real, confirmed gap this issue
should close - not a new component, a five-line fix to an existing loop.

## Design

### Fix: per-panel accent color instead of a shared loop

Replace the loop at `StatsHud.gd:39-41` with four individual calls, reusing the exact same accent
colors already chosen for the bars at lines 46-49 (don't introduce new colors - reuse what's already
decided elsewhere in this same file):

```gdscript
_round_panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
    SynGridPalette.ACCENT_SILVER, SynGridPalette.PANEL_BG_ELEVATED, true))
_gold_panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
    SynGridPalette.GOLD, SynGridPalette.PANEL_BG_ELEVATED, true))
_life_panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
    SynGridPalette.HP_HIGH, SynGridPalette.PANEL_BG_ELEVATED, true))
_triumph_panel.add_theme_stylebox_override("panel", ThemeBuilder.build_capsule_style(
    SynGridPalette.ACCENT_PURPLE, SynGridPalette.PANEL_BG_ELEVATED, true))
```

The tooltip assignments and accent-bar colors immediately below (lines 42-49) are unaffected - leave
them as-is.

### Open design question: should the Life pill's border/glow track low-life state dynamically?

`HP_HIGH` (`SynGridPalette.gd:45`) is `Color(0.0, 0.96, 0.83)` - exactly `ACCENT_TEAL`, not red.
`refresh()` (`StatsHud.gd:54-61`) already swaps the **value label's** font color between `HP_HIGH`
(teal) and `HP_LOW` (`Color(0.85, 0.10, 0.10)`, same as `DANGER`) based on `life_low_threshold`, but
the accent bar and (after this fix) the pill border/glow are only ever set once in `_ready()` to
`HP_HIGH` - they never re-evaluate on low life. The Figma reference shows a static red/crimson Life
pill, which doesn't obviously map to either state of the current dynamic teal→red design.

Two options, pick one - this is a product/design call, not purely technical, so don't guess silently:
- **(a) Keep the dynamic teal→red behavior** (arguably a better design than Figma's static red - it
  gives players a color cue when life is actually low, not just a permanently alarming red pill) and
  extend `refresh()` to also re-apply `build_capsule_style()` with `HP_LOW` on the panel + accent bar
  when life drops to/below `life_low_threshold`, not just the value label.
- **(b) Match Figma exactly**: make the Life pill always use a red/crimson accent (`DANGER`, i.e.
  `#D91A1A` - closest existing constant to Figma's `#D81E3D`, off by a few points in the blue channel,
  close enough to not need a new color) regardless of current life value, sacrificing the
  low-life-state signal this pill currently gives.

Recommend (a) - it's already implemented for the value label, extending the same pattern to the
panel/bar is more consistent than reverting to a static color, and it preserves a real gameplay signal
Figma's static mockup didn't need to account for (Figma has no live game state to react to). Flag this
choice explicitly in the PR description either way, since it's a deviation from the Figma reference
made for a reason, not an oversight.

### Gold color: real mismatch, needs one decision

`SynGridPalette.GOLD = Color(0.95, 0.78, 0.29)` = `#F2C74A`. Figma's reference (per
`docs/design-tokens-neon-grimoire.md` §1, extracted from the live prototype) uses `#FFB627` - more
saturated/orange. Same constant is reused as `TIER_GOLD` (`SynGridPalette.gd:58`) for tier-III item
borders, so changing it has a wider blast radius than just the HUD pill. Recommend leaving `GOLD`/
`TIER_GOLD` as-is (`#F2C74A`) rather than chasing Figma's exact value here - it's a subtle hue
difference, not a structural gap, and changing a constant used by both the HUD pill and every gold-tier
item card is a bigger, riskier change than this issue's scope. Note the deviation in the PR and move
on unless a reviewer disagrees.

### Aurora button - audit existing shader before writing anything new

`assets/shaders/aurora_border.gdshader` already exists (`memory/PRD.md`: "renders a teal↔purple
gradient orbiting the rim of the button, plus a soft outer halo... 4-px negative offsets"). Before
writing new code:

1. Render `MainMenuPreviewHarness` and confirm whether the Play button's aurora border is visibly
   animating (a static screenshot can only prove the halo geometry exists, not the rotation - check in
   the editor with the scene running if possible, not just a frame capture).
2. Compare shader uniforms against `docs/design-tokens-neon-grimoire.md` §3.2: rim gradient should
   cycle `#00F5D4 → #7B2FBE → #00F5D4 → #7B2FBE` over `2.5s` linear; halo should pulse `2.5s`
   ease-in-out with a blur radius roughly equivalent to `12px` at the button's scale.
3. If the shader already matches, this scope item is a no-op - close it as verified, don't rewrite.
4. If uniforms are off, adjust the existing shader resource's parameters - do not create a second
   shader or a duplicate button component.

### ItemCard glow - confirm, don't rebuild

`ItemCard.gd:177,181` already calls `ThemeBuilder.build_panel_style(...)` for its tier border.
Check whether `with_glow = true` is already passed at those two call sites; if not, flip it on - this
should be a one-argument change, the glow mechanism itself is already built and shared with the HUD
pill fix above (same `build_panel_style`/`build_capsule_style` glow logic).

## Files

- `scripts/ui/StatsHud.gd` lines 39-41 (the fix) and lines 54-61 (`refresh()`, only if option (a) above
  is chosen for the Life pill)
- `scripts/ui/ItemCard.gd` lines 177, 181 (confirm/flip `with_glow`)
- `assets/shaders/aurora_border.gdshader` (audit only, edit uniforms if they don't match)
- No changes needed to `ThemeBuilder.gd` or `SynGridPalette.gd` - both already have what this issue
  needs; do not add a new function or a new color constant

## Testing

- `SYNGRID_SCREENSHOT=/tmp/hud.png godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn`
  - confirm all four HUD pills show visibly distinct border/glow colors (silver/gold/teal-or-red/purple),
  not the current uniform dim-teal.
- If option (a) is chosen for Life: re-run `GridPrepPreviewHarness` with a fixture/offline state where
  `GameState.life_points <= life_low_threshold` and confirm the Life pill's border and accent bar both
  switch to `HP_LOW`, not just the value label.
- `MainMenuPreviewHarness` screenshot - confirm Play button aurora border renders (geometry at minimum;
  animation can't be proven by a single frame, note that limitation in the PR rather than claiming
  verification you didn't actually do).
- `ItemCardPreviewHarness` screenshot - confirm tier borders show glow after the `with_glow` flip.
