# HLD: E4 - Battle Report Scene

PRD: folded into this HLD (scope is a client-only presentation pass over data already returned by
`match/start`, not new gameplay - see "Goals" below in place of a separate PRD, matching the precedent
set by issue #29's HLD).
Client issue: sync-grid-client #31.
Source docs: `docs/game_ideas.md` §4.2 (three-page report), §4.3 (timeline scrubber, absorbs
`improvements.md` §1.5), §4.5 (grid heatmap), §4.7 (in-fight hint).
Unblocked by: server #49 (combat log metadata + match summary), merged.

## Problem

Combat resolves in ~15 seconds of fast-forward FX and the player is dropped straight into `RoundEndScene`'s
win/loss ceremony with no way to understand *why* they won or lost, which item mattered, or what to fix
next round. The server now returns everything needed to answer that (`combat_log.summary.item_stats[]`,
`turning_point_tick`, the full `events[]` array) but nothing renders it - `CombatReplayScene` discards the
log the moment playback ends and hands off to `RoundEndScene`, which only shows life/triumph/gold deltas.

## Data-shape check (before design, not after)

Checked `docs/api_contract.md`'s `combat_log` schema (§Combat, lines 189-243, current as of #49) directly
against `game_ideas.md` §4.2's illustrative example text before designing around it - same standing rule
that caught real gaps in #28/#29/#30's LLDs.

- **No named synergy sets.** §4.2's example ("Your Iron Set synergy carried the round") assumes a set-name
  system. `ActiveSynergy`/`summary` have no name field - named sets are server G5 (`sync-grid#31`, open,
  unrelated to this client issue despite the coincidentally identical number). Confirmed with the user:
  the verdict one-liner uses **top-item MVP framing** instead - on a win, the player's highest
  `damage_dealt` item from `item_stats`; on a loss, the *opponent's* highest `damage_dealt` item (the real
  reason the fight was lost is what beat you, not what you did). Both are direct reads of `item_stats`, zero
  invented text.
- **No materialized synergy-contribution total.** §4.2 page 2 asks for "synergy contributions ranked" but
  `summary` has no such field, only a per-event `synergy_bonus` scalar on individual `events[]` entries.
  Confirmed with the user: aggregate `synergy_bonus` by the firing item's `weapon_category` (same category
  aggregation already shipped in #29's synergy banners) in a single pass over `events[]` at scene entry -
  reuses an established, already-reviewed pattern instead of inventing a new one.
- **No pie/bar chart component exists in this codebase.** §4.2 page 2 calls for a pie chart and a bar
  chart. Building a general charting component is out of scope for one issue. Substituting **ranked
  horizontal bars** (same visual language as #29's threat pill, already reviewed and shipped) for both the
  damage-by-item and damage-taken breakdowns - conveys the same "who's the MVP / who's the weak link"
  information without a new charting primitive.
- **No tick-by-tick DPS graph data.** §4.2 page 2 also asks for a "tick-by-tick DPS graph." `events[]` gives
  per-event `actual_damage`, so a DPS-over-time series is derivable, but a full graph widget is unscoped
  redundant work once the timeline scrubber (page/feature 3 of this same issue) already visualizes
  HP-over-time from the same event stream. Confirmed with the user via issue's own acceptance criteria
  (scrubber is explicitly in scope, a separate DPS graph is not listed in "Files") - dropped as
  redundant, not descoped for lack of data.
- **§4.7's exact trigger ("»60% HP down at tick 15")** is tick-count-gated, which behaves oddly on fights
  shorter or longer than 15 ticks (total_ticks ranges freely, e.g. 143 in the contract's own example).
  Confirmed with the user: replace with a continuously-evaluated HP-ratio condition (player HP < 30% of
  1000 while opponent HP > 60% of 1000) using the same per-event `target_hp_after` values `CombatReplayScene`
  already tracks per side via `_bars_by_player_id` - more robust across fight lengths, same intent ("clearly
  losing, not just took one big hit").

## Goals

1. New `BattleReportScene`, swipe-through 3-page report, inserted between `CombatReplayScene` and
   `RoundEndScene` in the navigation flow. Skippable in one tap from any page (SKIP goes straight to
   round-end).
2. Page 1 VERDICT: win/loss/overtime banner, MVP-framed one-liner, duration (`total_ticks`), total damage
   exchanged (sum of `actual_damage` across all events).
3. Page 2 BREAKDOWN: ranked bars for damage dealt by item (own side), damage taken by item (own side),
   synergy contribution by category, crit rate (`crits / shots_fired` per `item_stats` entry, aggregated).
   Every number is a direct read or a single-pass sum of server-given fields - zero client combat math.
4. Page 3 ADVICE: `scripts/util/PostMortemRules.gd`, a standalone rule-matching library (shared with the
   future adaptive-coaching feature per `improvements.md` §5.4) that turns log facts into sentences. Rules
   operate only on `item_stats` and `events[]` - never speculate.
5. Grid heatmap: overlay on the final grid (reusing `CombatReplayScene`'s `GridCell`/mirroring pattern) -
   green damage-dealt tint, blue damage-taken tint, red flash on cells whose item never fired
   (`shots_fired == 0` in `item_stats`, or absent from it entirely for items that never got a stats entry).
6. Timeline scrubber MVP: tick slider scrubbing a precomputed per-tick HP-for-both-sides series (built once
   from `events[].target_hp_after`, keyed by side via the same `attacker_id`/`defender_id`-to-local-player
   mapping `CombatReplayScene` already uses); gold marker at `turning_point_tick`.
7. In-fight hint: amber pill in `CombatReplayScene` (not the new scene - it fires *during* the fight it's
   about) when the continuously-evaluated losing-hard condition (goal above) is true, reading "TIP: Losing
   hard - check Battle Report for placement suggestions."

## Design

### Scene structure and data flow

`BattleReportScene` reads `GameState.last_combat_log` and `GameState.opponent_grid` directly at `_ready()`
(same autoload-read pattern every existing scene uses - no new plumbing, no scene-transition parameters).
One method, `_analyze_log()`, walks `combat_log.events` exactly once and produces:

- `_damage_by_item_id: Dictionary[String, float]` and `_taken_by_item_id: Dictionary[String, float]` -
  seeded directly from `summary.item_stats` (already aggregated server-side, no re-derivation needed).
- `_synergy_by_category: Dictionary[String, float]` - built by iterating `events[]`, adding `synergy_bonus`
  keyed by the firing item's `weapon_category` (looked up once into an `_items_by_id` map built from
  `GameState.equipped_items` + `GameState.opponent_grid.equipped_items`, same map shape `CombatReplayScene`
  builds).
- `_damage_by_cell: Dictionary[Vector2i, float]` and `_taken_by_cell: Dictionary[Vector2i, float]` - built
  by iterating `events[]`, adding `actual_damage` at `source_cell` and `hp_loss` at `target_cell`
  (coordinates already mirrored the same way `CombatReplayScene._build_side` mirrors the opponent side, so
  the heatmap's cell math is a direct copy of that existing mirroring logic, not a new derivation).
- `_hp_series_by_side: Dictionary[String, Array]` - one array per side, each entry `{tick, hp}`, built by
  scanning `events[]` in order and recording `target_hp_after` whenever `target_player_id` matches that
  side.

This single O(n_events) pass (n <= a few hundred) runs once at scene entry, not per-frame - negligible cost,
mirrors #29's HLD note that per-event work must stay bounded.

### Page navigation

Three `Control` pages in a root container, one visible at a time, swipe (drag) or tap-arrow to advance -
same elastic-tween page-transition idiom as any other multi-step reveal in this codebase (no linear tweens
per the juice contract). A persistent SKIP button in the corner routes to `RoundEndScene` from any page.

### Page 1 - VERDICT

Reuses the existing win/loss banner treatment from `RoundEndScene` (same palette, same juice - shatter/glow
on victory, desaturated on defeat) so the tone is continuous across the two back-to-back scenes. One-liner
built from `_damage_by_item_id` (own side, win) or the opponent's `item_stats` (loss) per the Data-shape
check above.

### Page 2 - BREAKDOWN

Four ranked-bar lists reusing the compact ranked-list visual from #29's threat pill (`ItemName` + value,
sorted descending, own-side items only for damage/taken/crit-rate, category labels for synergy).

### Page 3 - ADVICE

`PostMortemRules.gd` exposes one pure function, `generate(item_stats: Array, events: Array) -> Array[String]`,
returning 0-3 sentences. Each rule is a small, independently testable predicate over `item_stats`/`events`
(e.g. "any item with `shots_fired == 0`" -> "never fired" sentence). No rule references data that isn't in
these two arrays - enforces the acceptance criterion ("advice generated only from log facts, never
speculative") structurally, not just by convention.

### Grid heatmap

New page (or page-2 sub-panel - LLD to pin exact placement against the 540x960 canvas budget) rendering the
same `GridCell` layout `CombatReplayScene._build_side` builds, colored via `_damage_by_cell`/`_taken_by_cell`
instead of holding `ItemCard`s mid-fight. Never-fired cells (items present in `equipped_items` but with a
zero or absent `item_stats` entry) get a red flash treatment, reusing `SynGridPalette.DANGER`.

### Timeline scrubber

Horizontal `HSlider` over `_hp_series_by_side`, dragging jumps both HP bars to the nearest recorded tick
`<=` the slider value (last-known-value interpolation, no fabricated in-between values). Gold marker
(`SynGridPalette.GOLD`) fixed at `turning_point_tick`.

### In-fight hint (lives in `CombatReplayScene`, not `BattleReportScene`)

`_on_event_played` gains one check: after updating `_bars_by_player_id`, read the local player's current
fraction (`bar.current_hp / COMBAT_MAX_HP`, wherever that value already lives on `HpBar`) and the
opponent's; if player fraction < 0.3 and opponent fraction > 0.6 and the pill hasn't already been shown this
fight, show it once (guarded bool, matching the "fire once" idiom already used for #29's synergy banners).

## Trade-offs and Risks

- **Biggest risk is scope, not correctness.** Six sub-items plus a new scene plus a new standalone script is
  the largest single issue attempted in this epic wave to date. Mitigation: every sub-item above reuses an
  already-shipped, already-reviewed visual primitive (ranked lists from #29's threat pill, category
  aggregation from #29's synergy banners, `GridCell` mirroring from `CombatReplayScene`, banner treatment
  from `RoundEndScene`) - this issue is assembly of existing parts into a new scene, not six new rendering
  systems.
- **Single PR, all 6 sub-items** (confirmed with the user, matching #29's precedent) - the pages share one
  `_analyze_log()` data pass and one scene, so splitting would mean re-deriving the same event-walk twice
  for no isolation benefit. Given this issue's larger surface than #29, budget for a second review
  round-trip as the default expectation, not a surprise - flagging here so review time is planned for it.
- **Adapting illustrative spec text to real data** (MVP framing instead of named-synergy-set reasons, ranked
  bars instead of pie/bar charts, HP-ratio trigger instead of tick-15 gate) is deliberate and
  user-confirmed, documented above so a future reader comparing against `game_ideas.md` §4.2/§4.7
  understands why shipped text/behavior differs from the doc's example.
- **5x load spike / fault tolerance / network partitions**: not applicable - zero new network calls, this
  is a pure rendering pass over data already held in `GameState` from the single existing `StartMatch`
  response, same as #29. Only failure mode is a Godot-side rendering bug, caught by the mandatory
  harness-screenshot review step.
- **Future rework when G5 (named synergy sets) lands**: the MVP-framing one-liner and category-based
  synergy aggregation both upgrade additively (swap in the real set name / group by set instead of
  category) without touching `_analyze_log()`'s structure - same cheap-upgrade-path design as #29's damage
  type icons.

## Sequencing

Single PR, single branch (`feature/issue-31-battle-report-scene`), matching this repo's one-issue-one-PR
convention. Depends on server #49 only (merged) - no other open client or server issue blocks this. New
preview harness (`BattleReportPreviewHarness.tscn`) with an offline fake `combat_log`/`summary` fixture,
wired into the standard harness screenshot commands, required before merge per this repo's PR review
protocol.
