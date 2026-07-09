# LLD: Issue #69 - Grid Prep Base Screen Neon Grimoire Visual Pass

Client issue: #69 (epic #42, Wave 7). Depends on #67 (merged, `e25e621`).
Distinct from #64 (Market split - screen organization) and #66 (grid-size hardening - 5x5/6x6/7x7
correctness). This issue is the base 4x4 visual treatment only.
Juice contract: `docs/juice_manual.md` sections 1-3 (section 3 is directly load-bearing here, see below).

## Verified against live-rendered current state

`SYNGRID_SCREENSHOT=/tmp/x.png SYNGRID_GRID_SIZE=4 godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn`,
inspected at 2x zoom.

### Already correct - do not touch

- HUD row - fixed via #67, shared component, no work needed here.
- Shop card dimming is **intentional**, not a legibility bug: `GridPrepScene.gd:34` defines
  `unaffordable_tint = Color(0.45, 0.45, 0.5, 0.65)`, applied by `_update_affordability()`
  (`GridPrepScene.gd:433-436`) - `card.modulate = Color.WHITE if price <= GameState.gold else
  unaffordable_tint`. The test fixture happened to have 1 gold against 3g/3g/2g/9g prices, so all four
  shop cards were dimmed simultaneously, which reads as "uniformly low contrast" if you don't check the
  underlying logic - it isn't. **Do not touch this.**

### Real, confirmed gap

1. **No "PREP PHASE" badge exists anywhere in the scene.** Confirmed by grep - `GridPrepScene.gd` has no
   phase-indicator text at all. The only persistent-looking label is `%StatusLabel`
   (`GridPrepScene.gd:52`), which is actually a **transient toast** reused for many unrelated messages
   ("RECYCLED +2G", "TRIPLE-MERGE - LV2 X", "placed Y at (2,1)", etc. - see the ~15 call sites across the
   file). Adding a Figma-style persistent "PREP PHASE" badge means a *new* label, not repurposing
   `_status_label` (which needs to keep doing its toast job).
2. **Synergies are already shown - but as shader glow on the grid, not as a chip list.** `SynergyBorder`
   (`scenes/ui/SynergyBorder.tscn`, spawned via `_spawn_synergy_border()`, `GridPrepScene.gd:903-926`)
   draws an animated glow shader on the shared border between synergized cells. This is not a gap to
   fill - it's the deliberate implementation of a hard rule in `docs/juice_manual.md` section 3: **"never
   draw static lines between items... trigger a fragment shader on the shared cell border."** A Figma-
   style text chip row ("Void Pact 2/3") would be a *different, additive* summary view, not a replacement
   - if added, it must coexist with the shader glow, never substitute for it. Flag this explicitly in the
   PR so a reviewer doesn't mistake a chip-row addition for satisfying section 3 on its own.

## Scope

1. Add a new small badge/label for phase state ("PREP PHASE") near the HUD row - new node, don't reuse
   `%StatusLabel`.
2. Optionally add a synergy-summary chip row (name + progress fraction, e.g. "Void Pact 2/3") as a
   *complement* to the existing shader glow, reading the same `active_synergies` data already driving
   `_spawn_synergy_border()` - do not remove or weaken the shader glow to make room for this.
3. Leave shop-card styling untouched - the affordability tint is correct as-is.

## Files

`scenes/grid_prep/GridPrepScene.tscn` + `.gd`.

## Testing

`GridPrepPreviewHarness` (4x4 only) screenshot showing the new phase badge and (if added) synergy chip
row, with the existing shader glow still visible and unchanged on synergized grid cells. Also screenshot
with `GameState.gold` set higher than all shop prices, to confirm the affordability tint correctly shows
shop cards at full brightness when affordable (regression check against accidentally "fixing" the
intentional tint while doing this work).
