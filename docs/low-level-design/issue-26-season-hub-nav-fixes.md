# LLD: SeasonHub Field Wiring + Nav Tab Labeling

Status: Approved 2026-07-07.
Owner: Claude Code (Lead Architect).
Governs: GitHub issue #26.
Depends on: `scenes/main_menu/MainMenu.gd` (`GameState.season` producer), `scripts/autoloads/GameState.gd`.

## Why this doc exists

`SeasonHub.gd` shipped straight to `main` outside the normal PR review flow with no PRD/HLD/LLD behind it.
It reads `GameState.current_season_name` / `GameState.season_end_ts`, neither of which exists - the real data already lives in `GameState.season` (a `Dictionary`), populated by `MainMenu._on_get_active_season_completed`.
Because `"current_season_name" in GameState` always evaluates false, the scene is permanently stuck on its fallback literals regardless of server state.
This doc is the minimal fix to wire the existing data through, plus a decision on the two secondary problems the issue raised, so Cursor has one authoritative spec instead of picking between the issue's listed options itself.

## Scope decision (architect call)

Issue #26 lists four required items. Given this is a wiring bug, not a new feature, keep the fix contained:

1. **Point `SeasonHub` at `GameState.season`.** Required, in scope.
2. **`PROFILE` tab mislabeling.** Decision: rename the tab, do not build a profile scene. A real profile scene needs its own PRD/HLD per the feature lifecycle in `CLAUDE.md` - out of scope for a bug-fix pass. Rename is a one-line label/tooltip change that closes the honesty gap today.
3. **`RANKS` tab auth-gating.** Decision: no change needed. `_leaderboard_tab.pressed` is already wired to `_on_leaderboard_pressed` (`MainMenu.gd:84`, handler at `:277-283`), which already gates on `_authenticated` and falls into the retry-session branch - functionally equivalent to the old `LeaderboardButton` disable. This is a non-issue; verify only, no code change required.
4. **Whether `SeasonHub` should ship at all right now.** Decision: ship it, fixed. The "REWARDS LADDER - COMING SOON" note stays (it's an honest label for genuinely unbuilt content), unlike the season name/countdown which were silently wrong.

## Required fix 1: `SeasonHub.gd` reads `GameState.season`

`GameState.season` shape (set at `MainMenu.gd:178-183`):

```gdscript
{
    "season_id": int,
    "name": String,
    "ends_at_unix": int,
    "caller_rank": int,
}
```

Empty `{}` when no active season (initial state, and set on `_on_get_active_season_failed`, `MainMenu.gd:192`).

Replace `SeasonHub.gd:32-38`:

```gdscript
func _refresh() -> void:
    var season_name := String(GameState.get("current_season_name")) if "current_season_name" in GameState else "SEASON"
    if season_name == "":
        season_name = "SEASON"
    _season_name.text = season_name.to_upper()
    _triumph_value.text = str(GameState.triumph_count)
    _season_timer.text = _format_countdown()
    _rewards_note.text = "REWARDS LADDER - COMING SOON"
```

with:

```gdscript
func _refresh() -> void:
    if GameState.season.is_empty():
        _season_name.text = "NO ACTIVE SEASON"
        _season_timer.text = ""
    else:
        _season_name.text = String(GameState.season.get("name", "")).to_upper()
        _season_timer.text = _format_countdown()
    _triumph_value.text = str(GameState.triumph_count)
    _rewards_note.text = "REWARDS LADDER - COMING SOON"
```

And `_format_countdown` (`SeasonHub.gd:41-52`), replace the `"season_end_ts" in GameState` guard with the dict lookup:

```gdscript
func _format_countdown() -> String:
    var end_ts: int = int(GameState.season.get("ends_at_unix", 0))
    if end_ts == 0:
        return "SEASON END - TBA"
    var now_ts := int(Time.get_unix_time_from_system())
    var remaining: int = max(0, end_ts - now_ts)
    if remaining <= 0:
        return "SEASON ENDED"
    var d: int = remaining / 86400
    var h: int = (remaining % 86400) / 3600
    var m: int = (remaining % 3600) / 60
    return "ENDS IN %dD %02dH %02dM" % [d, h, m]
```

Also update the header doc-comment at `SeasonHub.gd:9-11` ("Contract: reads GameState.current_season_name...") to name `GameState.season` instead - it's actively wrong and will mislead the next reader.

Do not add a `caller_rank` display here - `MainMenu`'s season card already shows rank; duplicating it in `SeasonHub` is not in the issue's acceptance criteria and would be scope creep.

## Required fix 2: rename the `PROFILE` tab

`_on_profile_tab_pressed` (`MainMenu.gd:331-333`) only opens the existing callsign popover. Rename the tab's visible text (the `%ProfileTab` button in `MainMenu.tscn`) from `PROFILE` to `EDIT NAME`, matching the actual behavior. No handler or signal changes - `_on_profile_tab_pressed` stays exactly as-is. If the button also has a tooltip, update it to match.

## Verification (mandatory before requesting review)

1. `godot --headless --path . --import` - clean.
2. `SYNGRID_SCREENSHOT=/tmp/season_hub.png godot --path . --resolution 540x960 scenes/season_hub/SeasonHubPreviewHarness.tscn` (or equivalent if no dedicated harness exists yet - inject a realistic `GameState.season` dict before showing the scene) - confirm season name and countdown render real values, not fallback literals, and confirm the empty-season path (`GameState.season = {}`) renders "NO ACTIVE SEASON" cleanly, not a crash or blank label.
3. `SYNGRID_SCREENSHOT=/tmp/main_menu.png godot --path . --resolution 540x960 scenes/main_menu/MainMenuPreviewHarness.tscn` - confirm the bottom nav tab reads "EDIT NAME", not "PROFILE".
4. Manually confirm tapping `RANKS` pre-auth still falls into the retry-session branch without crashing (no code change expected here - this is a regression check on existing behavior, not new behavior).

## Out of scope

- No new profile scene.
- No change to `RANKS` tab gating logic.
- No change to `_on_get_active_season_completed`/`_on_get_active_season_failed` in `MainMenu.gd` - both are already correct producers of `GameState.season`.
