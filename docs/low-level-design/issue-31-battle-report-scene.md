# LLD: E4 - Battle Report Scene

HLD: `docs/high-level-design/issue-31-battle-report-scene.md`. Read that first for the "why" and the
data-shape decisions - this document is the "how."
Tracks: sync-grid-client#31. Single branch `feature/issue-31-battle-report-scene`, single PR.

## Files

New:
- `scenes/battle_report/BattleReportScene.tscn` + `.gd`
- `scenes/battle_report/BattleReportPreviewHarness.tscn` + `.gd`
- `scripts/util/PostMortemRules.gd`

Modified:
- `scenes/combat_replay/CombatReplayScene.gd` - route to `BattleReportScene` instead of `RoundEndScene`;
  add the in-fight losing-hard hint.
- `scenes/grid_prep/GridCell.gd` - add `set_heat_tint()` (shared component, used by the new heatmap page).

## `CombatReplayScene.gd` changes

1. Add `const BATTLE_REPORT_SCENE_PATH: String = "res://scenes/battle_report/BattleReportScene.tscn"`
   next to the existing `ROUND_END_SCENE_PATH` const (line 16).
2. In `_on_continue_pressed()`, the `ContinueAction.CONTINUE` branch (line 698-700) currently does:
   ```gdscript
   ContinueAction.CONTINUE:
           if _finalize_synced:
                   get_tree().change_scene_to_file(ROUND_END_SCENE_PATH)
   ```
   Change the target to `BATTLE_REPORT_SCENE_PATH`. `BattleReportScene` becomes the one that eventually
   calls `change_scene_to_file(ROUND_END_SCENE_PATH)`, either from its own SKIP button or after the last
   page. No other `ContinueAction` branch changes - `BACK_TO_PREP` and the sync-retry paths are unrelated
   to this issue.
3. In-fight hint. Add near the top of `_on_event_played` (after the `_bars_by_player_id` update path that
   already runs each event, around line 588-601):
   - New guard var at class scope: `var _losing_hint_shown: bool = false`.
   - New var at class scope: `var _losing_hint_pill: Control = null` (built lazily, same lazy-build idiom
     `DamageMeter`/synergy banners use elsewhere in this file).
   - After the event's HP values are applied to both bars, compute the local player's HP fraction and the
     opponent's HP fraction. Do **not** reach into `HpBar`'s private `_hp` var from outside the class -
     instead compute the fraction locally from the event you already have in hand: track
     `_current_hp_by_player_id: Dictionary[String, float]`, updated every event via
     `_current_hp_by_player_id[ev.target_player_id] = ev.target_hp_after` (a one-line addition next to the
     existing `_bars_by_player_id` update). Player fraction is
     `_current_hp_by_player_id.get(GameState.player_id, COMBAT_MAX_HP) / COMBAT_MAX_HP`; opponent fraction
     is the same lookup keyed by whichever of `attacker_id`/`defender_id` isn't `GameState.player_id`
     (already computed once in `_ready()`-time setup around line 159-162 - reuse that, don't recompute the
     id lookup per event).
   - If `not _losing_hint_shown and player_fraction < 0.3 and opponent_fraction > 0.6`: set
     `_losing_hint_shown = true`, build the pill (amber background `SynGridPalette.ACCENT_AMBER`, text "TIP:
     Losing hard - check Battle Report for placement suggestions"), slide/fade it in with the same
     `TRANS_BACK EASE_OUT` idiom as #29's synergy banner chips, anchor it in the same reserved middle-band
     gap #29 already established (`_vs_label` area) stacked below the log ticker so the two never overlap -
     verify this in the harness screenshot, it's the actual regression gate per the HLD's risk note. Pill
     persists until the fight ends (no auto-fade - unlike synergy banners this is meant to stay visible as a
     standing warning).

## `GridCell.gd` change

Add one method, placed after `highlight()`:

```gdscript
var _heat_overlay: ColorRect = null

func set_heat_tint(color: Color) -> void:
        if _heat_overlay == null:
                _heat_overlay = ColorRect.new()
                _heat_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
                _heat_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
                # Added before any ItemCard is parented in the heatmap's build path, so it draws
                # beneath the card per the same "children added later draw on top" rule _empty_glyph
                # relies on above - do not call this after add_child(item_card) on the same cell.
                add_child(_heat_overlay)
        _heat_overlay.color = color
```

Not wired into `highlight()` or the drag-hover path at all - `GridPrepScene` and `CombatReplayScene` never
call `set_heat_tint()`, so this is strictly additive and zero-risk to existing callers. Only
`BattleReportScene`'s heatmap page calls it, once per cell, immediately after `cell.setup()` and before
adding the (non-interactive, `draggable = false`) `ItemCard`.

## `BattleReportScene.gd`

### State

```gdscript
var _log: Dictionary                    # GameState.last_combat_log
var _own_items_by_id: Dictionary         # item_id -> item dict (GameState.equipped_items)
var _opp_items_by_id: Dictionary         # item_id -> item dict (GameState.opponent_grid.equipped_items)
var _damage_by_item_id: Dictionary       # from summary.item_stats, keyed damage_dealt
var _taken_by_item_id: Dictionary        # from summary.item_stats, keyed damage_taken
var _crit_rate_by_item_id: Dictionary    # crits / shots_fired per item_stats entry (0.0 if shots_fired == 0)
var _synergy_by_category: Dictionary     # weapon_category -> summed synergy_bonus, from events[]
var _damage_by_cell: Dictionary          # Vector2i -> summed actual_damage at source_cell
var _taken_by_cell: Dictionary           # Vector2i -> summed hp_loss at target_cell
var _hp_series_by_side: Dictionary       # "player"/"opponent" -> Array[{tick:int, hp:float}]
var _current_page: int = 0
```

### `_ready()`

1. `_log = GameState.last_combat_log`; build `_own_items_by_id`/`_opp_items_by_id` from
   `GameState.equipped_items` / `GameState.opponent_grid.get("equipped_items", [])` (same pattern
   `CombatReplayScene._build_side` already uses to build its own id maps).
2. Seed `_damage_by_item_id`, `_taken_by_item_id`, `_crit_rate_by_item_id` directly from
   `_log.summary.item_stats` - one pass, no recomputation of anything `summary` already gives.
3. Call `_analyze_events()` once - single pass over `_log.events` populating `_synergy_by_category`,
   `_damage_by_cell`, `_taken_by_cell`, `_hp_series_by_side`. Mirroring for the opponent's `source_cell`/
   `target_cell` x-coordinate uses the identical `grid_columns - 1 - x` transform
   `CombatReplayScene._build_side` uses for `mirror_x` - copy that expression exactly so the heatmap lines
   up with how the opponent grid is drawn everywhere else in this codebase.
4. Build page 1, defer pages 2/3 and the heatmap/scrubber panels to build lazily on first navigation to
   them (keeps `_ready()` cheap and matches this codebase's general lazy-build convention for combat FX
   nodes).

### Page 1 - VERDICT

- Banner: reuse `RoundEndScene`'s win/loss banner construction (extract the shared piece into a call if
  `RoundEndScene.gd` already exposes it as a function; otherwise duplicate the exact same three-tween
  shatter/glow-vs-desaturate treatment so the two scenes read as one continuous ceremony - do **not**
  invent a new banner treatment).
- One-liner: if `_log.winner_id == GameState.player_id`, take `max(_damage_by_item_id)` -> own item name
  -> `"<Name> carried the round with <round(dmg)> dmg dealt."`. Else take the max of the *opponent's*
  per-item `damage_dealt` from `item_stats` (same array, just don't filter to own-side ids) -> `"<Name>
  dealt <round(dmg)> dmg - you had no answer."`.
- Duration: `"%d ticks" % _log.total_ticks`. Total damage exchanged: `_log.attacker_hp_final` and
  `_log.defender_hp_final` are final pools, not exchanged totals - use
  `sum(item_stats[i].damage_dealt for all i)` (both sides combined) instead, which is the real "total damage
  exchanged" figure and needs no new field.

### Page 2 - BREAKDOWN

Four ranked lists, own-side only, ItemCard-name + value, descending, reusing #29's threat-pill ranked-list
visual (compact `VBoxContainer` rows, not a new list component):
1. Damage dealt (`_damage_by_item_id`, own ids only).
2. Damage taken (`_taken_by_item_id`, own ids only).
3. Synergy by category (`_synergy_by_category`, all categories present, no own/opp split needed - synergy
   is inherently about the firing item, already own-side-only since only your items receive your synergy
   bonuses in the underlying `internal/combat` model per `docs/api_contract.md`).
4. Crit rate (`_crit_rate_by_item_id`, own ids only, formatted as a percentage).

### Page 3 - ADVICE

Call `PostMortemRules.generate(item_stats, events, own_item_ids)` once, render each returned string as a
line. Empty array renders nothing (no placeholder text - an uneventful fight with no fireable advice is a
valid empty state, not an error).

### Grid heatmap panel

Build two `GridContainer` + `GridCell` layouts exactly like `CombatReplayScene._build_side` (own + opponent,
same mirroring), but:
- Pass `mirror_x = true` for opponent, `false` for player - identical call shape.
- Instead of parenting an `ItemCard` sized/tinted for gameplay, call `cell.set_heat_tint(color)` where
  `color` blends green (`SynGridPalette.HP_HIGH`, reused - it's already a green-leaning teal) at alpha
  proportional to `_damage_by_cell[coord] / max(_damage_by_cell.values())`, layered with a blue tint
  (`Color(0.2, 0.4, 0.9)`, new - no existing blue in the palette, add it as
  `SynGridPalette.HEAT_TAKEN` alongside the other named accents) proportional to `_taken_by_cell`. Cells
  with an occupant whose `item_stats` entry has `shots_fired == 0` (or no entry at all) get
  `SynGridPalette.DANGER` at a flat 0.35 alpha instead, overriding the damage tint - "never fired" is a
  stronger signal than "fired but low."
- Still parent a non-interactive `ItemCard` (`draggable = false`, same as `CombatReplayScene`'s final-state
  cards) on top of the tint so the player can see *which* item occupies the hot/cold/dead cell.

### Timeline scrubber panel

`HSlider` with `min_value = 0`, `max_value = _log.total_ticks`. On `value_changed`, for each side look up
the last entry in `_hp_series_by_side[side]` whose `tick <= value` and set that side's HP bar/label to that
entry's `hp` (reuse `HpBar` - instantiate two, one per side, same component the combat scene uses, not a
new bar widget). A `Label` positioned at `turning_point_tick / total_ticks` fraction along the slider track,
colored `SynGridPalette.GOLD`, reads "TURNING POINT."

## `PostMortemRules.gd`

```gdscript
class_name PostMortemRules
extends RefCounted
# Pure log-fact rule engine, no gameplay computation. Shared with the future
# adaptive-coaching feature (improvements.md §5.4) - every rule here must be a
# straight read of item_stats/events, never a speculative "what if" claim.

static func generate(item_stats: Array, events: Array, own_item_ids: Array) -> Array[String]:
        var lines: Array[String] = []
        var stats_by_id: Dictionary = {}
        for s: Dictionary in item_stats:
                stats_by_id[String(s.get("item_id", ""))] = s

        # Rule 1: never fired.
        for id in own_item_ids:
                var s: Dictionary = stats_by_id.get(id, {})
                if int(s.get("shots_fired", 0)) == 0:
                        lines.append("%s never fired this fight - check its placement." % _name_for(id, stats_by_id))
                        break  # one example is enough, don't spam every dead card

        # Rule 2: destroyed early (killing_blow landed against one of your own items).
        for ev: Dictionary in events:
                if bool(ev.get("killing_blow", false)) and String(ev.get("target_item_id", "")) in own_item_ids:
                        lines.append("You lost %s at tick %d." % [
                                _name_for(String(ev.get("target_item_id", "")), stats_by_id), int(ev.get("tick", 0))])
                        break

        # Rule 3: never synergized.
        var synergized_ids: Dictionary = {}
        for ev: Dictionary in events:
                if float(ev.get("synergy_bonus", 0.0)) > 0.0:
                        synergized_ids[String(ev.get("firing_item_id", ""))] = true
        for id in own_item_ids:
                var s: Dictionary = stats_by_id.get(id, {})
                if int(s.get("shots_fired", 0)) > 0 and not synergized_ids.has(id):
                        lines.append("%s never synergized with a neighbor." % _name_for(id, stats_by_id))
                        break

        return lines

static func _name_for(item_id: String, stats_by_id: Dictionary) -> String:
        # item_stats has no name field - caller-supplied item dicts do. Resolved by
        # BattleReportScene passing names through, not hardcoded here (keeps this
        # file a pure function of log data with no GameState coupling).
        return item_id  # placeholder signature note - see below
```

Note for Cursor: `item_stats` entries carry `item_id` but not `name` (confirmed against
`docs/api_contract.md`'s schema, lines 224-232). `generate()`'s real signature must also take an
`id_to_name: Dictionary` (built by `BattleReportScene` from its own `_own_items_by_id`) so `_name_for` can
resolve real names - the sketch above omits it for brevity, the actual implementation must thread it
through. This keeps `PostMortemRules` a pure function with no `GameState`/autoload dependency (testable in
isolation, matching the "shared with adaptive coaching" goal), at the cost of one extra parameter.

## Preview harness

`BattleReportPreviewHarness.gd` follows the exact pattern of `CombatReplayPreviewHarness.gd`: offline mode
injects a fixed fake `combat_log` (reuse or lightly extend the fixture the combat harness already uses, so
`item_stats`/`turning_point_tick` are present) directly into `GameState` before instantiating the scene, no
live server needed. Wire into the standard harness screenshot commands list in this repo's `CLAUDE.md`.

## Acceptance checklist (per this repo's PR review protocol)

- [ ] `godot --headless --path . --import` clean.
- [ ] `SYNGRID_SCREENSHOT=... BattleReportPreviewHarness.tscn` for all 3 pages + heatmap + scrubber, at
      540x960, no overlap/clipping (this is the actual regression gate, not a nice-to-have).
- [ ] In-fight hint pill screenshot-verified on a fixture where the player is losing hard, and verified
      absent on a normal/winning fixture.
- [ ] SKIP button reachable and functional from every page.
- [ ] `PostMortemRules.generate()` covered by a standalone GUT test (or this repo's existing test harness
      convention) with fixtures for each of the 3 rules plus an empty-result case - it's the piece most
      likely to be reused by future adaptive coaching, worth locking down independently of the scene.
- [ ] `CombatReplayScene` now routes to `BattleReportScene`, which routes to `RoundEndScene` - full chain
      screenshot-walked once end to end.
