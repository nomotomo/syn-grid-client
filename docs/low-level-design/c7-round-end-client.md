# LLD: C7 Round End - Client Implementation Blueprint

PRD: `docs/prd/c7-round-end.md`.
HLD: `docs/high-level-design/c7-round-end-and-state-authority.md` (approved 2026-07-02).
Client issue: sync-grid-client #6.
Server dependencies: sync-grid #34 (award dedup), #35 (next_round), #36 (GetActiveGrid), #37 (ResetRun).
Juice contract: `docs/juice_manual.md` sections 1, 2, and 5 govern every visual and audio decision below.

## Sequencing note

All scenes and harness work can be implemented and offline-verified immediately.
Live E2E verification of the full loop requires #34 and #35 merged; the NEW RUN path requires #37; boot rehydration requires #36.
Until a server issue lands, its client path must degrade to a status-label message, never a crash or a hang.

## File inventory

New:
- `scenes/round_end/RoundEndScene.gd` + `.tscn`
- `scenes/round_end/RoundEndPreviewHarness.gd` + `.tscn`

Modified:
- `scripts/autoloads/ApiClient.gd` - two methods, four signals (exact shapes below)
- `scripts/autoloads/GameState.gd` - `hydrate_from_grid`, `last_round_result`, round-authority rule
- `scenes/combat_replay/CombatReplayScene.gd` - finalize on result, route to RoundEndScene
- `scenes/main_menu/MainMenu.gd` - GetActiveGrid in the boot chain
- `tests/e2e_api_client.gd` - new endpoint checks (see Testing)
- `CLAUDE.md` - phase tracker row C7 and harness command list, in the final PR

## ApiClient contract

Follow the existing `_request` helper exactly; no new HTTP machinery.

```gdscript
signal get_active_grid_completed(data: Dictionary)
signal get_active_grid_failed(code: int, reason: String)
signal reset_run_completed(data: Dictionary)
signal reset_run_failed(code: int, reason: String)

func get_active_grid() -> void:
    _request(HTTPClient.METHOD_GET, "/v1/me/grid", {}, {}, true,
        get_active_grid_completed, get_active_grid_failed)

func reset_run() -> void:
    _request(HTTPClient.METHOD_POST, "/v1/run/reset", {}, {}, true,
        reset_run_completed, reset_run_failed)
```

## GameState contract

```gdscript
# Round authority rule (enforced in review): current_round is assigned ONLY
# inside hydrate_from_grid() and apply_round_result(); `current_round += 1`
# must not appear anywhere in the codebase.

# Full session rehydration from GetActiveGridResponse.grid or ResetRunResponse.grid.
func hydrate_from_grid(grid: Dictionary) -> void
    # Sets: current_round, life_points, triumph_count, gold (from grid.gold_balance),
    # equipped_items and bench_items via .assign() (typed-array rule),
    # and clears current_shop_slots/shop_round when the round changed.

# Stored by CombatReplayScene when FinalizeRound completes; read by RoundEndScene.
# Shape: { "won": bool, "round_played": int, "next_round": int,
#          "my_state": Dictionary (PlayerState), "gold_rewarded": int }
var last_round_result: Dictionary = {}

func apply_round_result(finalize_response: Dictionary, won: bool, round_played: int) -> void
    # Picks the caller's PlayerState (player_id match on attacker_state/defender_state),
    # writes life_points/triumph_count from it, sets current_round from next_round
    # (int64-as-string: int(str(...))), and fills last_round_result.
```

Terminal routing reads `last_round_result.my_state.eliminated` (server-computed) and
`triumph_count >= 10`; the 10 is display/routing only - the server enforces terminality
in ResetRun, so a spoofed client gains nothing.

## CombatReplayScene changes

- When the result overlay appears (`_show_result`, both finished and skip paths),
  immediately call `ApiClient.finalize_round(attacker_id, defender_id, winner_id, round)`
  using ids from `GameState.last_combat_log` and `GameState.current_round`.
- CONTINUE starts disabled with text `SYNCING...`; on `finalize_round_completed` it
  enables with text `CONTINUE` and its press routes to
  `res://scenes/round_end/RoundEndScene.tscn` after the standard `_pulse`.
- On `finalize_round_completed`: `GameState.apply_round_result(data, won, round_played)`.
- Error contract (`finalize_round_failed`):

| code | reason | behavior |
|---|---|---|
| 409/412 | match already resolved | Round was finalized earlier (crash replay). Call `get_active_grid`, rehydrate, route to prep. |
| 412 | match not started | Redis matchstate lost. Status `MATCH STATE LOST - REFIGHT`, CONTINUE becomes `BACK TO PREP`, route to prep (HLD risk section). |
| any other | - | Status `SYNC FAILED - <reason>`, CONTINUE becomes `RETRY SYNC` and re-invokes finalize. |

## RoundEndScene specification

### Node tree (`RoundEndScene.tscn`)

```
RoundEndScene (Control, full rect)            script, class_name RoundEndScene
├── Background        %  ColorRect PANEL_BG, full rect, mouse_filter ignore
├── Banner            %  Label, TitleLabel variation, centered, y ~18%
├── RoundCaption      %  Label, CaptionLabel, centered under banner
├── HeartsRow         %  HBoxContainer, centered, y ~34%, 5 children built in code
├── TriumphCaption    %  Label CaptionLabel "TRIUMPH", centered, y ~46%
├── OrbsRow           %  HBoxContainer, centered, y ~50%, 10 children built in code
├── PayoutCaption     %  Label CaptionLabel "NEXT ROUND GRANT", centered, y ~62%
├── PayoutValue       %  Label, HudValueLabel, gold color override, centered
├── ContinueButton    %  Button, min height 140, font 32, y ~78%
├── NewRunButton      %  Button, min height 140, font 32, y ~78%, hidden by default
├── StatusLabel       %  Label CaptionLabel, anchored 0.92-0.98, centered
└── FxLayer           %  Control full rect, mouse_filter ignore (particles)
```

Hearts and orbs are code-built placeholders (no sprite assets yet):
a heart is a `ColorRect` 72x72 rotated 45 degrees tinted `HP_LOW` at 0.9 alpha when full and `TEXT_DIM` at 0.25 when empty;
an orb is a `ColorRect` 56x56 tinted `ACCENT_TEAL` when filled and `TEXT_DIM` at 0.25 when empty.
Wrap each in a `Control` holder so pivot-centered scale pops do not fight the HBox.

### Choreography timeline (all tweens obey contract section 2 - never LINEAR)

Input: `GameState.last_round_result` (set by CombatReplayScene).

1. `t=0` banner pop: scale 0 -> 1.1 over 0.12s `TRANS_ELASTIC/EASE_OUT`, settle to 1.0 over 0.06s `TRANS_BACK/EASE_IN_OUT`.
   Text `ROUND %d WON` teal / `ROUND %d LOST` crimson (`DANGER`).
2. `t=0.4` hearts render at the PREVIOUS life count, then on a loss the lost heart shatters:
   scale to 1.3 `TRANS_BACK/EASE_OUT` 0.08s, then to 0 `TRANS_BACK/EASE_IN` 0.12s,
   plus a crimson `CPUParticles2D` ring burst on `FxLayer` (reuse the ring-builder pattern from GridPrepScene),
   plus `AudioManager.play_fatal_hp_loss()` (this is the SFX matrix "Fatal HP loss" trigger - the LPF sweep).
   On a win, hearts simply pop in staggered at index * 0.04s.
3. `t=0.9` orbs fill to the NEW triumph count; the newest orb (win only) pops elastic with a teal burst.
   When `gold_rewarded > 0` (milestone crossed), `AudioManager.play_triumph_milestone()` and StatusLabel shows `MILESTONE +%dG`.
4. `t=1.2` payout: call `ApiClient.award_round_gold(next_round, won)` on scene enter (not at t=1.2; fire in `_ready`).
   When `award_round_gold_completed` arrives, count `PayoutValue` from 0 to `gold_awarded` over 0.6s using `tween_method` with `TRANS_QUAD/EASE_OUT` (numeric text, not a scale/position property), then a single elastic value-pop (StatsHud `_set_value` pattern).
   `GameState.gold = new_balance`; `GameState.gold_awarded_round = next_round`.
   On `award_round_gold_failed`: StatusLabel `GRANT PENDING - %s`; prep's existing once-per-round claim is the retry path (idempotent after #34), so do not block CONTINUE.
5. `t=1.6` CONTINUE pops in (elastic, same pattern as MainMenu buttons); press -> `_pulse` -> `change_scene_to_file` prep.
   `current_round` is already `next_round` via `apply_round_result`; the scene must not touch it.

### Terminal variants (same scene, no extra scene files)

- Eliminated (`my_state.eliminated == true`): banner `RUN TERMINATED` in `DANGER`; all hearts shatter in a 0.04s-staggered cascade; skip the payout block entirely (no award call); ContinueButton hidden, NewRunButton shown.
- Victory (`triumph_count >= 10`): banner `GRID DOMINATED` in teal; all 10 orbs fill in a 0.04s-staggered cascade; `play_triumph_milestone()`; skip payout; NewRunButton shown.
- NewRunButton press: disable + text `RESETTING...`, call `ApiClient.reset_run()`.
  On `reset_run_completed`: `GameState.hydrate_from_grid(data.grid)`, `GameState.gold = int(data.new_balance)`, `GameState.gold_awarded_round = 0`, `GameState.last_round_result = {}`, route to prep.
  On `reset_run_failed`: re-enable with text `RETRY NEW RUN`, StatusLabel `RESET FAILED - <reason>` (412 `RUN_NOT_TERMINAL` means desynced state: also call `get_active_grid` and rehydrate).

### Audio summary for this scene (contract section 5 - no invented events)

- Life lost: `play_fatal_hp_loss()` (LPF sweep + sub drop).
- Triumph milestone (`gold_rewarded > 0` or victory): `play_triumph_milestone()`.
- No sound on payout count-up or button presses beyond existing button feel.

## MainMenu boot chain change

After `authenticate_completed` hydrates the token, call `ApiClient.get_active_grid()` before enabling play.
- `get_active_grid_completed`: `GameState.hydrate_from_grid(data.grid)`, StatsHud refresh, status `RUN RESUMED - ROUND %d` when round > 1.
- `get_active_grid_failed` with 404: fresh player, keep defaults, status unchanged.
- `get_active_grid_failed` with 412 or network: status `STATE SYNC OFFLINE`, still enable play with local defaults (never block the player on this call).
- Profile and season fetches remain parallel as today.

## Coding patterns (binding for this feature; review checks these)

1. `class_name` on every new script; after adding one, run `godot --headless --path . --import` before any CLI scene run (stale global class cache otherwise).
2. Signals only for ApiClient results; no awaited returns.
3. Typed arrays are filled with `.assign()`, never direct `=` from JSON arrays.
4. GDScript lambdas capture locals by value: use a shared Dictionary holder for flags set inside signal lambdas (see existing harnesses).
5. Every tunable duration/scale/color offset is an `@export`; colors come from `SynGridPalette`, styles from `ThemeBuilder`.
6. All int64 JSON fields go through `int(str(...))`.
7. Header comment on each new file: one paragraph stating which contract section governs it and the data-authority rule it obeys; inline comments only for non-obvious constraints.
8. No `current_round` arithmetic outside `GameState` hydrate/apply functions.

## Testing requirements

1. `RoundEndPreviewHarness` follows the established harness pattern (offline + `SYNGRID_LIVE=1`), plus a `SYNGRID_RESULT=win|loss|dead|victory` env switch selecting the injected `last_round_result` fixture in offline mode; it screenshots mid-ceremony and prints the StatusLabel and button states.
2. Offline fixtures must cover: win with milestone (`gold_rewarded > 0`), plain loss (heart shatter + LPF), eliminated, victory.
3. Live mode (requires #34+#35 merged): full loop - auth, buy, place, real match, finalize, round-end with real `next_round`, screenshot; print `GameState.current_round` before and after to prove server-owned advancement.
4. `tests/e2e_api_client.gd` additions (guard each behind server availability by checking the failure code and reporting `skipped:` rather than failing while #34-#37 are unmerged):
   - `get_active_grid` after purchase returns the bench item and matching `gold_balance`.
   - `finalize_round` response includes `next_round == round + 1`.
   - `award_round_gold` called twice for the same round changes the balance exactly once.
   - `reset_run` on a live (non-terminal) run returns 412 with reason `RUN_NOT_TERMINAL`.
5. Headless boot check and both existing harnesses must stay green (no regressions in prep/replay).

## Review acceptance checklist (Claude Code pass/fail gate)

- [ ] No LINEAR tween on any scale/position/rotation property anywhere in the diff.
- [ ] Heart shatter, orb fill, banner, payout, and button pops match the timeline above within exported-tunable tolerances.
- [ ] `play_fatal_hp_loss` fires exactly when a life is lost on screen; `play_triumph_milestone` only on milestone or victory.
- [ ] `current_round` writes exist only in `GameState.hydrate_from_grid` / `apply_round_result`.
- [ ] Every failure path lands in a StatusLabel message with a retry affordance; no dead-ends, no crashes offline.
- [ ] All four offline harness fixtures screenshot correctly; live loop verified once server #34/#35 are merged.
- [ ] No glass panels behind live numeric values; palette/theme sourced from `SynGridPalette`/`ThemeBuilder`.
- [ ] `docs/api_contract.md` updated with `/v1/me/grid` and `/v1/run/reset` shapes as implemented.
