# LLD: Issue #70 - Battle Screen Neon Grimoire Visual Pass

Client issue: #70 (epic #42, Wave 7). Depends on #67 (merged, `e25e621`).
Distinct from #66 (grid-size hardening - 5x5/6x6/7x7 correctness). Base visual treatment only.

## Verified against live-rendered current state

`SYNGRID_SCREENSHOT=/tmp/x.png godot --path . --resolution 540x960 scenes/combat_replay/CombatReplayPreviewHarness.tscn`,
inspected at 2-3x zoom after two prior misses in this same review (the aurora button and this screen's
timer ring both turned out to be already-working effects missed at thumbnail scale) - every claim below
was re-checked against the actual code, not just a screenshot glance.

### Already correct - do not touch (this issue's original draft got these wrong)

1. **The timer ring renders and color-transitions correctly.** `%RoundTimerRing`
   (`CombatReplayScene.gd:39`, `_update_round_timer_progress()` at line 772) is wired and, at tick 65/90
   (28% time remaining), correctly showed an amber arc - matching the documented
   teal→amber(<30%)→crimson(<10%) transition. It's small and embedded next to the tick text rather than
   a large standalone ring, which is why an earlier pass of this review missed it - it was never absent.
2. **The threat meter is already a styled panel**, not plain text. `_threat_pill`
   (`CombatReplayScene.gd:74,127-135`) is a `PanelContainer` styled via `ThemeBuilder.build_panel_style()`,
   showing a ranked "1. Iron Sword 11  2. ..." readout (`_refresh_threat_meter()`, lines 536-554).
3. **The synergy banner is already a styled, animated chip.** `_spawn_synergy_banner()`
   (lines 510-534) creates a `PanelContainer` with `build_panel_style()`, category-tinted border/text,
   fade-in/hold-2s/fade-out tween. Confirmed rendering in the test capture as "MELEE SYNERGY +5 DMG" in
   an orange-bordered chip.
4. **The losing-hint pill is already styled.** `_show_losing_hint_pill()` (lines 596-616) uses
   `build_panel_style()` with `ACCENT_AMBER`. Didn't trigger in this particular capture (condition-gated
   on HP thresholds) but the code is already correct.

### Real, confirmed gap

1. **Hit-counter footer is a bare `Label`.** `_hit_counter_footer` (`CombatReplayScene.gd:107-116`) is a
   plain `CaptionLabel`-variant `Label`, no panel/pill background - renders as raw `"13 HITS  -  2 CRITS"`
   text. This one genuinely needs the card/pill treatment the original issue draft asked for.
2. **Combat log ticker has no panel background.** `_log_ticker` (line 137) is a bare `VBoxContainer`,
   lines added via `_push_log_line()` (lines 556-581) as plain colored `Label`s directly on the scene
   background. Real gap, matches original scope.

### Open question - does Battle need a HUD row at all? (stronger evidence now, still not decided here)

The original issue draft assumed a Round/Gold/Life/Triumph HUD row exists on Battle and needs the #67
pill fix applied. **It doesn't exist on this screen at all** - confirmed, no such row in
`CombatReplayScene.gd`/`.tscn`. Battle instead shows per-side aggregate HP bars (segmented cells with a
numeric total, e.g. "848"/"956") and unit/opponent name labels.

A follow-up full top-to-bottom comparison (not just re-checking this issue's own claims) confirmed
Figma's Battle screen has the *exact same 4-pill HUD row as Grid Prep* (❤ Life, 💰 Gold, ⚠ Round,
◆ Triumph), plus the timer ring inserted as a 5th element between Gold and Round. This is stronger
evidence than before that the omission may be an actual gap rather than an intentional design choice -
but it's still a product call, not something to add unilaterally. Raise it with the stronger evidence
now available; still don't add it without sign-off.

### Additional deltas found on full re-comparison (beyond this issue's original scope)

1. **Threat display style differs from Figma, not just implementation status.** Confirmed the real
   threat meter is already styled (see above) - but Figma renders it as 3 separate icon+number pills
   side by side, while the current build renders one ranked text line ("1. Iron Sword 11  2. ..."" in a
   single panel). Both convey the same information, styled differently. Worth a product/design call on
   which presentation is preferred, not an assumed match-Figma-exactly change - the current text-line
   format may read better on a small screen than 3 separate pills would.
2. **Synergy banner positioning differs.** Figma shows the synergy-activated banner as a full-width
   element pinned to the very top of the screen (above the HUD row, pushing it down). The current build's
   `_spawn_synergy_banner()` renders as a smaller chip docked to the right side, mid-screen. Different
   layouts for the same underlying event - flag for a design call, don't assume Figma's top-banner
   placement is correct without checking whether the current side-chip placement was a deliberate choice
   (e.g. to avoid blocking the grid view, which a full-width top banner would do less of but still some).
3. **Opponent/player HP presentation differs.** Figma shows plain `"HP 53/120"` text next to the unit
   name. Current build shows a segmented visual bar (teal cells) with just the current-HP number, no
   max shown, next to the name. Also: Figma uses generated callsigns for both sides ("VEXKRIN-9" /
   "SHADOWMANCER"); current build uses "BOT-SWORDSMAN" for the opponent (fine, likely fixture data) but
   labels the player's own row simply "YOU" rather than their callsign - confirm whether that's
   intentional (arguably clearer than showing your own name back at yourself) before treating it as a gap.

## Scope

1. Wrap `_hit_counter_footer` in a `PanelContainer` with `build_panel_style()` or `build_capsule_style()`
   (whichever reads better at that screen position - it's a footer-wide element, capsule may look odd
   full-width, panel is probably right).
2. Wrap `_log_ticker` in a panel background, or give each `_push_log_line()` entry its own small chip
   (matches Figma's per-line ticker card more closely, costs more nodes per line - pick whichever the
   `docs/design-tokens-neon-grimoire.md` reference more clearly supports, that doc doesn't cover this
   specific pattern so use judgment and note the choice in the PR).
3. Do not touch the timer ring, threat meter, synergy banner, or losing hint mechanics/styling - all four
   are already correctly implemented. Layout/positioning (banner placement, HP presentation) is a
   separate question from styling correctness - see below.
4. Raise the HUD-row question, the threat-display-style question, the synergy-banner-position question,
   and the HP-presentation question in the PR description with a recommendation each; don't resolve any
   of them unilaterally. This issue's job is the two confirmed styling gaps (footer, log ticker) - the
   four open questions are surfaced for a reviewer to decide, not blocking this issue's own scope.

## Files

`scenes/combat_replay/CombatReplayScene.gd` (no `.tscn` changes expected - the footer and log ticker are
both constructed in code, not scene nodes).

## Testing

`CombatReplayPreviewHarness` screenshot, zoomed to at least 2x on the footer and log-ticker regions
specifically (not just a full-screen thumbnail - this review's own methodology failed twice on this
screen alone by not zooming in enough, don't repeat that when verifying the fix).
