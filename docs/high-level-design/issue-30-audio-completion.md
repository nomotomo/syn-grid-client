# HLD: E3 - Audio Completion

PRD: folded into this HLD (scope is closing gaps in an already-shipped system against its own governing
spec, not new gameplay - see "Goals" below in place of a separate PRD).
Client issue: sync-grid-client #30. Also closes #15 (BGM `AudioStreamWAV` leak at exit).
Source docs: `docs/juice_manual.md` §5 (Soundscapes & Acoustic Architecture - the authoritative SFX/BGM
spec), `docs/improvements.md` §6.1-§6.4.
Dependency precedent: `docs/dependency/ui-audio-assets.md` (audio is currently 100% procedurally
synthesized placeholder via `tools/generate_placeholder_audio.py`; real-asset sourcing for the existing
14 events is already tracked there as "still open, not blocking" - this issue follows the same convention
for any new events rather than opening a second asset-sourcing track).

## Audit finding: the issue's own scope list is stale - verified against the actual code before designing

Per the standing rule from prior LLDs in this repo (verify a spec claim against real code/data before
building around it - this is the third time this has mattered on this project, after #28's per-item-HP
assumption and #29's named-synergy-set assumption): `improvements.md` §6.2 claims only 7 SFX events are
implemented and lists 8 as "missing." Reading `scripts/autoloads/AudioManager.gd`'s `SFX_PATHS` directly
shows **all 14 events in `juice_manual.md` §5's official matrix are already implemented**, including
`triple_merge`, `win_round`, and `triumph_milestone` - none of which the improvements.md bullet
acknowledges. Two of its "missing" names are simple renames of existing code, confirmed via grep of actual
call sites:

- `card_lift` = existing `item_drag` (wired at `GridPrepScene.gd:517`, on drag pickup).
- `card_snap` = existing `grid_snap` (wired at `GridPrepScene.gd:446`/`:710`, on valid placement).

Also: `improvements.md` §6.1 states the crossfade must be "0.5s," but `juice_manual.md` §5 (the actual
source of truth per this repo's own rule - "if this document and the proto disagree, the proto wins," and
by the same logic here, the manual wins over a backlog bullet) specifies `0.8s`, and
`AudioManager._crossfade_bgm` already implements `0.8s` correctly. Not a bug - `improvements.md`'s text is
simply wrong. The defeat LPF (§6.4) is also already implemented exactly to spec
(`play_fatal_hp_loss()` - `AudioEffectLowPassFilter`, `800.0` Hz cutoff, removed after `2.0s`).

**Decision (confirmed with the user)**: rather than build the stale "8 missing events" list verbatim, add
the subset that closes a real, currently-unaddressed feedback gap - gold gain/spend, a per-round triumph
tick, a distinct defeat stinger, and a distinct victory fanfare - to `juice_manual.md` §5 as new official
matrix rows (required before implementation, since this repo's PR review protocol forbids invented audio
events not in the matrix), then implement them. `timer_tick_low` is dropped: this game has no real-time
player-facing countdown to warn about (the "round timer ring" visualizes deterministic combat-tick
progress during an already-resolved replay, not a live decision clock), so there is no honest trigger
point for it - the same "don't build around a spec gap, name it" principle from the #29 HLD applies here.

## Goals

1. Correct the crit-ducking gap: on every crit event, dip the `BGM` bus -6dB for 200ms so the crit stinger
   cuts through - the one item from the issue's scope that is genuinely and entirely missing today.
2. Fix issue #15 (BGM `AudioStreamWAV` leak at process exit) in the same file, same standard, per that
   issue's own suggested ownership.
3. Add four new SFX events to the official matrix and implement them: `coin_earn`, `coin_spend`,
   `triumph_earn`, `defeat_stinger`, `victory_fanfare` (five events - `victory_fanfare` and
   `defeat_stinger` are the two ends of "run completion," `triumph_earn` is the per-round tick,
   `coin_earn`/`coin_spend` are the economy pair).
4. Document (not re-fix) that BGM crossfade duration and defeat LPF already match the manual exactly -
   close the corresponding backlog bullets without touching working code.
5. Every new event follows the existing placeholder-generation convention
   (`tools/generate_placeholder_audio.py`, `SFX_BUILDERS`) - no manual asset sourcing in this pass, matching
   the precedent already set for all 14 existing events and documented as a deliberate, separate follow-up
   in `docs/dependency/ui-audio-assets.md`.

## Design

### Crit ducking

`AudioManager` gains a `_duck_bgm()` helper that dips the `BGM` bus volume by `-6.0` dB for `0.2s` then
restores it, called from wherever crit SFX already fires (`play_crit_hit`). Bus-volume manipulation, not a
new effect resource - simpler and cheaper than the LPF path (which needs an effect instance because
`AudioEffectLowPassFilter` has no bus-level volume equivalent), and self-contained: no other code path
touches `BGM` bus volume directly today, so a plain "save current, dip, restore" pattern cannot race
against anything else.

### BGM stream leak (issue #15)

`AudioManager` connects to `get_tree().tree_exiting` once in `_ready()` and stops + nils both `_bgm_a`/
`_bgm_b` streams there. This targets the exact leak in #15's repro (a playing `AudioStreamPlayer.stream`
holds a live reference past `get_tree().quit()`) without touching the crossfade logic itself - the fix is
purely "let go of the resource before the tree tears down," not a change to how BGM plays or fades.

### New SFX events

Each new event is a `juice_manual.md` §5 matrix row (sound-design requirement column, matching the
existing table's own voice) plus a `SFX_PATHS` entry plus a placeholder generator function, exactly
mirroring how all 14 existing events are structured - no new architecture, no new autoload method shape.

| Event | Trigger | Sound design |
|---|---|---|
| `coin_earn` | Gold increases from a round-start grant or an item sell (`GridPrepScene._on_award_round_gold_completed`, `_on_sell_item_completed`) | Bright single coin-clink, very short |
| `coin_spend` | Gold decreases from a shop purchase (`GridPrepScene._on_purchase_item_completed`) | Duller, lower-pitched coin drop - spend should read as the "opposite" of earn, not a variation of the same sound |
| `triumph_earn` | The newest triumph orb pops on a round win (`RoundEndScene._animate_orbs`, the `is_newest` branch) - **not** the milestone-gold branch, which keeps the existing louder `triumph_milestone` cue so the two never compete in the same moment | Soft single tick/ping, subordinate to `triumph_milestone` in loudness and complexity |
| `defeat_stinger` | The run ends in elimination (`RoundEndScene._animate_hearts`, the `_is_eliminated` branch), layered alongside the existing `fatal_hp_loss` LPF sweep, not replacing it | Short low-register stinger - the "this run is over" punctuation, distinct from the per-round `fatal_hp_loss` sweep that already plays on every life lost, milestone or not |
| `victory_fanfare` | The run is won outright (`RoundEndScene._animate_orbs`, the `_is_victory` branch), replacing the current reuse of `triumph_milestone` for that moment | Bigger, longer fanfare than `triumph_milestone` - this is the single biggest moment in a run and should not sound identical to an ordinary mid-run bonus-gold ping |

## Trade-offs and Risks

- **Expanding the official SFX matrix is a judgment call, not a mechanical "fill the gap" task** - confirmed
  with the user rather than decided unilaterally, since it adds asset-generation surface and two new
  trigger points inside `RoundEndScene`'s existing staggered-reveal choreography (`_animate_hearts`/
  `_animate_orbs`), which already has carefully tuned timing. Mitigation: new SFX calls are placed at
  existing branch points already gated by `_is_eliminated`/`_is_victory`/`is_newest`, not new conditionals -
  no change to the stagger/await timing itself.
- **`victory_fanfare` replaces `triumph_milestone`'s role at the `_is_victory` branch** (`RoundEndScene.gd:188`)
  rather than adding a second sound on top of it - playing both back to back at the biggest moment in the
  game would be noise, not clarity. `triumph_milestone` keeps its other call site (`:202`, ordinary
  mid-run milestone gold) unchanged.
- **5x load spike / fault tolerance / network partitions**: not applicable - zero network calls, zero
  server-facing change. The only new runtime cost is five more short placeholder WAVs (a few KB each,
  loaded on demand via the existing threaded-load cache, never preloaded) and one bus-volume tween that
  already has an established, working precedent in the LPF add/remove-after-timeout pattern.
- **Placeholder audio stays placeholder**: deliberately not sourcing "real" licensed audio for the five new
  events in this pass - doing so would be inconsistent with the fact that the *existing* 14 events are
  still 100% placeholder too (per `docs/dependency/ui-audio-assets.md`'s own "still open" list). Add the
  five new keys to that doc's open list rather than treating them specially.

## Sequencing

Single PR, single branch (`feature/issue-30-audio-completion`), matching this repo's one-issue-one-PR
convention and closing #15 in the same PR per that issue's own suggested ownership ("fix as part of that
phase's implementation"). No dependency on any other open issue; no server-side change of any kind.
