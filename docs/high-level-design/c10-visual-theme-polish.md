# HLD: C10 - Item/HUD Icon Sprites and Rounded Neon-Glass Theme Pass

PRD: folded into this HLD (scope is a visual asset-integration pass on already-approved C1-C7 scenes,
not new gameplay - see "Goals" below in place of a separate PRD).
Client issue: sync-grid-client #11.
Dependency decisions: `docs/dependency/ui-audio-assets.md`.
Reference target: user-supplied mockup (dark rounded stat pills, coin/heart/trophy glyphs, glowing
rounded item-slot borders), 2026-07-05.

## Problem

Two presentation gaps separate the shipped C1-C7 loop from the reference mockup:

1. Item icons are flat `ColorRect` tints (`ItemCard.gd:74`); the mockup shows real weapon/shield art.
2. HUD stat values (gold/life/triumph) are text-only; the mockup pairs each with an icon glyph in a
   rounded pill.

A third, deeper gap is architectural rather than missing-asset: `ThemeBuilder.gd:17` encodes a deliberate
prior decision - `PANEL_CORNER_RADIUS = 0`, "sharp corners - etched-circuit look, never rounded/glass" -
that is the opposite of the mockup's rounded glass-glow aesthetic. This HLD documents reversing that
decision, since it's a global, high-blast-radius change touching every shipped scene.

## Goals

1. Render real pixel-art sprites for every item, categorized by `weapon_category` (MELEE/RANGED/ARCANE)
   plus shields, with a non-crashing fallback for any item lacking a matching sprite.
2. Add coin/heart/trophy icon glyphs to `StatsHud`, matching the mockup's icon+value pill layout.
3. Move the panel theme from sharp 0-radius corners to rounded corners with a soft glow border, applied
   consistently across every existing scene (MainMenu, GridPrep, CombatReplay, RoundEnd) in one pass.
4. Do all of the above as parameter/asset changes to the existing `ThemeBuilder`/`SynGridPalette`/
   `ItemCard` code paths - no new panel-rendering system, no new autoload.

## Design

### Item icon rendering

`ItemCard.gd` gains a `TextureRect` sibling to the existing `ColorRect`. On `set_item(item)`:

- Compute a sprite path from `item.weapon_category` + a normalized `item.name` (exact convention in the
  LLD).
- If `ResourceLoader.exists(path)`, load and show the `TextureRect`, hide the `ColorRect`.
- Otherwise, keep today's behavior exactly (tinted `ColorRect`) - this makes asset delivery incremental
  and non-blocking. Cursor can wire the rendering path and ship it before every single item has art.

### HUD glyphs

`StatsHud.tscn` gains a `TextureRect` icon per stat panel (gold/life/triumph), sized to sit left of the
existing value `Label` inside the same panel, sourced from Kenney "Game Icons" (CC0). No new autoload, no
new signal - this is a scene-tree change only.

### Rounded neon-glass panel theme

`ThemeBuilder.build_panel_style()` already centralizes every panel's border/corner/background in one
function (`ThemeBuilder.gd:40`). The change is local to this function and its two constants:

- `PANEL_CORNER_RADIUS`: `0` → a rounded value (LLD specifies the exact pixel value against the
  1080x1920 viewport).
- Add a `glow` parameter path that layers a soft outer shadow in the panel's border color (already
  partially present via `style.shadow_color`, `ThemeBuilder.gd:53` - extend, don't replace).

Because every scene already calls through `ThemeBuilder.build_panel_style()` / `ThemeBuilder.get_theme()`
rather than hand-rolling `StyleBoxFlat` per scene, this single-function change propagates everywhere
without touching individual `.tscn` files' style overrides - the payoff of the existing code-driven theme
architecture.

### What does not change

- The synergy-glow shader (`synergy_glow.gdshader`) stays a shader effect, not a static asset - unaffected
  by this pass except for cosmetic color-constant tuning if needed to match the mockup's glow hue.
- Damage-float styling, tween curves, and all of `docs/juice_manual.md` sections 2 and 4 are unchanged.
- No new autoload. No new HTTP surface. No server-facing change at all - this is presentation-only.

## Trade-offs and Risks

- **Reversing a deliberate prior decision.** `PANEL_CORNER_RADIUS = 0` was chosen on purpose for an
  "etched-circuit" identity, not an oversight. Reversing it on a user-supplied mockup (not a unanimous
  re-review) is the highest-risk call in this HLD. Mitigation: the change is isolated to
  `ThemeBuilder.build_panel_style()` and two constants, so a revert is a one-function diff if the rounded
  look reads worse in-engine than in the static mockup.
- **Regression risk across 4 already-shipped scenes.** Every panel in MainMenu/GridPrep/CombatReplay/
  RoundEnd changes shape at once. Mitigation: the PR Review Protocol already mandates re-running every
  affected preview harness with `SYNGRID_SCREENSHOT` and visually inspecting the output - this is not
  optional for this PR, it's the primary regression gate since there's no automated visual-diff tool in
  this repo.
- **Rounded corners clipping content.** Text or icons positioned assuming sharp corners (e.g. a label
  anchored flush to a panel edge) can visually clip once the corner rounds. Mitigation: LLD specifies a
  conservative radius and an inset margin rule, not just a raw constant swap.
- **Partial item-icon coverage.** The 200+ icon pack won't necessarily name-match every server item
  1:1 on day one. Mitigation: the `ColorRect` tint fallback (already built, already working) means a
  missing sprite degrades to today's visual, never to a blank or broken texture - ship incrementally.
- **5x load spike / fault tolerance.** This phase touches no server call and no network path; it cannot
  affect backend load, latency, or failure modes. The only new runtime cost is texture memory (a few
  hundred small PNGs) and one additional `TextureRect` per stat/item node, negligible on target Android
  hardware.
- **Mobile performance of stacked shaders under a new glow style.** If the rounded-glass look pushes
  panel counts or shadow layers up, verify frame time on a mid-tier Android profile before merging;
  Kenney "UI Pack: Sci-Fi" (static PNG panels) remains a documented fallback in the dependency doc if
  shader/StyleBoxFlat glow proves too costly - not adopted now, held in reserve.

## Sequencing

Independent of C8 (Leaderboard) and C9 (Audio) - can proceed in parallel. The leaderboard medal-badge
task in issue #11 is presentation-only and doesn't block issue #7's data-wiring tasks.
