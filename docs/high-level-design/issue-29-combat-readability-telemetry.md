# HLD: E2 - Combat Readability Telemetry Overlays

PRD: folded into this HLD (scope is a client-only presentation pass over data already in the combat log,
not new gameplay - see "Goals" below in place of a separate PRD).
Client issue: sync-grid-client #29.
Source docs: `docs/game_ideas.md` §4.1 (telemetry overlays A-E), `docs/improvements.md` §1.3 (log ticker).

## Problem

`CombatReplayScene` plays the combat log as a sequence of FX (lunge, shake, damage float, SFX) but throws
away the *meaning* of the fight as it plays: the player cannot tell which item is carrying the round,
whether their synergies are actually firing, which enemy item to plan around next round, or scan back
over what just happened. Six gaps, all readable from data the scene already receives on `_on_event_played`
but never surfaces:

1. No per-item damage attribution (which card is the MVP).
2. No synergy-activation feedback (is the build actually working).
3. No damage-type distinction on floats (every hit reads the same).
4. No opponent threat ranking (nothing to plan around).
5. HP bars are a smooth fill - a single big hit and death by a thousand cuts look the same.
6. No scrollback - a missed read of one damage float is gone forever.

## Data-shape check (before design, not after)

Two sub-items in the source spec assume server concepts that don't exist yet - checked directly against
`sync-grid/proto/sync_grid.proto` and `.claude/skills/game-rules.md` before designing around them, per the
standing rule from prior LLDs in this repo (verify assumptions about server data shape before handoff):

- **Synergy banners**: the spec's example text is `"SYNERGY: Iron Set (2)"`, implying a named synergy-set
  system. `ActiveSynergy` server-side is `{SourceItemID, TargetItemID, Direction, ModifierPct}` - no name,
  no set concept. Named sets are already tracked as future work under server **G5** (`sync-grid#31`,
  "synergy evolution... set bonuses"), not built yet.
- **Damage-type icons**: the spec lists physical/magical/fire-DoT/shield/crit glyphs. `TickEvent` has no
  `damage_type` field at all (confirmed: `tick, firing_item_id, target_player_id, target_item_id,
  synergy_bonus, crit_chance, crit, actual_damage, shield_absorbed, hp_loss, target_hp_after,
  target_shield_after` - proto lines 79-92). Elemental typing is explicitly gated on server **G2**
  (`sync-grid#28`), not built yet. The issue text itself already flags this ("elemental icons activate
  when server G2 lands").
- **Decision (confirmed with the user)**: ship generic, data-accurate versions of both now rather than
  descoping. Synergy banners use `weapon_category` (already on every item, zero new plumbing) as the type
  label plus the event's own `synergy_bonus` - which is a **flat absolute damage bonus, not a percentage**
  (`internal/combat/combat.go:177`: `actualDamage := (w.BaseAttributes.BaseDmg + synergyBonus) * critMod`).
  Showing a fabricated `"+15%"` would require threading the pre-fight `ValidateGrid` synergy list through
  `GameState` into this scene - new plumbing outside this issue's file list, and not truthful to what a
  single hit's bonus actually was anyway (percentages sum across all active pairs; the flat number is
  already the correct total for that hit). Damage-type icons use `weapon_category` (MELEE/RANGED/ARCANE)
  instead of a fabricated physical/magical binary - real, available, already used for FX tinting
  elsewhere in this file (`_projectile_color`). Both upgrade automatically once G2/G5 land and add real
  typed data - no rework needed, just richer inputs to the same rendering path.

## Goals

1. Per-item damage-contribution meter under every mini card (both sides), normalized against the current
   match-wide max so the MVP's bar always reads full.
2. Synergy activation banner, fired once per item on its first synergized hit this fight, stacking on the
   right edge.
3. Category-tinted prefix glyph on damage floats (MELEE/RANGED/ARCANE/shield-block), reusing the palette's
   existing category tint so floats, projectiles, and glyphs agree visually.
4. Threat pill over the enemy grid ranking their top-3 damage dealers, live-updating.
5. Segmented HP bars (chunk dividers) on the existing `HpBar` component.
6. Auto-scrolling combat log ticker in the middle band, one line per event, matching the juice manual's
   "one event per 0.10s" cadence exactly (driven by the same signal the rest of the scene already uses).
7. Zero client-side combat math anywhere in this feature: every number rendered is a direct read or a pure
   running sum of server-given event fields (`actual_damage`, `hp_loss`, `synergy_bonus`) - no derived
   percentages, no recomputed crit chance, no invented stats.

## Design

### Shared data model

One new dictionary in `CombatReplayScene`: `_cumulative_damage_by_item_id: Dictionary[String, float]`,
incremented by `ev.actual_damage` on every event keyed by `firing_item_id`. This single running tally
feeds both the per-item meter (goal 1) and the threat pill (goal 4) - no duplicate bookkeeping.

### 1. Per-item damage meter

A new small component (`scripts/ui/DamageMeter.gd`, plain `Control`, sibling pattern to `HpBar`) attached
under every mini `ItemCard` in both `_player_grid_container` and `_opp_grid_container` at build time
(`_build_side`). Updated on every event: recompute the running max across `_cumulative_damage_by_item_id`,
then set each visible meter's fill fraction to `own_damage / current_max`. Because the max can only grow
during a fight, no meter ever visually shrinks - a fill-only tween (`TRANS_QUAD EASE_OUT`, matching every
other bar-fill tween in this file) is sufficient, no elastic overshoot needed for a value that only climbs.
Freezes naturally at fight end since no more events arrive.

### 2. Synergy activation banners

New `_synergy_announced_item_ids: Dictionary[String, bool]` guard set. On each event, if
`ev.synergy_bonus > 0.0` and `firing_item_id` is not yet in the set: mark it, then spawn one banner chip
reading `"<WEAPON_CATEGORY> SYNERGY +<round(synergy_bonus)> DMG"` (category from
`_items_by_id[firing_id].weapon_category`, already resolved elsewhere in this file). Chips join a
top-down stacked `VBoxContainer` on the right edge, slide in from the right (`TRANS_BACK EASE_OUT`,
matching the existing pop-in idiom), hold, then fade after a few seconds - same three-tween shape as
`_play_intro_banner`. Bounded stack size: at most one entry per item that ever fires with an active
synergy this fight (small grids, single digits), not one per tick.

### 3. Damage-type icons on floats

`_spawn_damage_float` gains a one-glyph prefix, resolved by the firing item's `weapon_category` via the
same tint lookup `_projectile_color` already uses (`SynGridPalette.tint_for_weapon_category`), so a
MELEE hit's icon is colored identically to its lunge/projectile/hitmark. Shield-block floats (already
textually distinct - `"BLOCKED"`) get their own fixed glyph instead of a category glyph, since a block
isn't attributable to the defender's weapon category. Crit floats keep their existing scale/outline
treatment - no separate crit glyph needed, it already reads unambiguously.

### 4. Threat meter (enemy top-3)

A pill `Control` positioned above `_opp_grid_area` (between `_opp_bar` and the grid, an already-reserved
vertical gap in `_layout_screen`). Recomputed on every event where the firing item's side is `"opponent"`:
take the top 3 of `_cumulative_damage_by_item_id` restricted to opponent item IDs, render as a compact
ranked list (`item.name` + running total). Re-renders only when the ranked set or order actually changes,
not on every single event, to avoid constant micro-layout thrash on the pill.

### 5. HP bar segments

`HpBar.gd` gains a `segment_count: int` export (default derived from `COMBAT_MAX_HP / 100.0` = 10 at the
1000 baseline) and a set of thin divider `ColorRect`s positioned at even fractions of `_hp_fill`'s track,
added once in `_ready()` and repositioned in the existing `_relayout()` alongside the fill/text rects
already handled there. Purely a visual overlay above `_hp_fill`/below `_text` in child order - `_apply()`'s
fill-width math is completely unchanged, so segment count is independent of and never fights the existing
tween.

### 6. Combat log ticker

A new `%LogTicker` `VBoxContainer` occupying the existing "middle band" gap around `_vs_label`
(`size.y * 0.465`, ~60px tall - already reserved, unused space between the two grids). One line per event,
built from data already resolved in `_on_event_played` (`_items_by_id[firing_id].name`, `hp_loss`, `crit`,
`shield_absorbed`): `"<ItemName> crit for <N>"` / `"<ItemName> hits for <N>"` / `"<ItemName> blocked"`,
matching `improvements.md`'s own example format exactly. Shows the last ~4 lines, oldest fading/sliding out
to the right as new ones arrive - driven by the same `event_played` signal the rest of the scene already
consumes, so it never drifts out of sync with the FX layer (both read the identical event at the identical
tick).

## Trade-offs and Risks

- **Portrait canvas is already tight (540x960, ~840 lines of scene script today).** Six new visual elements
  competing for space is the single biggest risk in this HLD, not a code-correctness risk. Mitigation:
  three of the six reuse already-reserved dead space (log ticker in the `_vs_label` gap, threat pill in the
  gap between `_opp_bar` and `_opp_grid_area`, damage meters as a thin strip under existing mini-cards
  rather than new standalone panels) instead of claiming new vertical real estate. The acceptance criterion
  ("meter, ticker, and threat pill simultaneously without overlap at 540x960") is the actual regression
  gate - the LLD pins exact pixel offsets and this must be verified with a harness screenshot before merge,
  not just eyeballed in the editor.
- **Adapting the source spec's illustrative examples to real data** (flat-damage synergy banners instead
  of a percentage; category glyphs instead of physical/magical) is a deliberate, confirmed decision (see
  "Data-shape check" above), not an oversight - flagged here so a future reader comparing this HLD against
  `game_ideas.md` §4.1 understands why the shipped text differs from the doc's example text.
- **Per-event work must stay O(1) or O(k) for small k.** The threat pill's top-3 recompute and the damage
  meter's running-max recompute both run on a signal that can fire up to ~150 times per fight at 10/s (5/s
  during crits). Both are bounded by grid size (max ~16 items per side), so this is negligible on target
  Android hardware - noted only because "recompute every event" is the kind of pattern that silently
  becomes expensive if a future change makes it scan something unbounded.
- **5x load spike / fault tolerance / network partitions**: not applicable - this feature makes zero new
  network calls and touches no server state. It is a pure rendering pass over data the scene already holds
  in memory from the single existing `StartMatch` response. The only failure mode is a Godot-side rendering
  bug, caught by the mandatory harness-screenshot review step, not a backend concern.
- **Future rework when G2/G5 land**: intentionally deferred to those issues, not this one. When elemental
  damage types exist, the damage-type icon lookup gains real typed data instead of falling back to
  `weapon_category`; when named synergy sets exist, the banner text swaps from `"<CATEGORY> SYNERGY"` to
  the real set name. Both are additive swaps inside the same rendering functions, not architectural
  changes - the LLD's function boundaries are chosen specifically so this upgrade path stays cheap.

## Sequencing

Single PR, single branch (`feature/issue-29-combat-readability-telemetry`), matching this repo's
one-issue-one-PR convention - the six sub-items share one data model (`_cumulative_damage_by_item_id`,
the existing `event_played` signal) and splitting them would mean re-deriving the same wiring twice for
no isolation benefit. No dependency on any other open issue; no server-side change of any kind.
