# LLD: Synergy `modifier_pct` Boundary Normalization

Status: Approved 2026-07-07.
Owner: Claude Code (Lead Architect).
Governs: GitHub issue #43.
Depends on: `docs/api_contract.md` (`ValidateGrid` synergies shape, corrected 2026-07-07), `docs/juice_manual.md` sections 3 and 5.

## Why this doc exists

`docs/api_contract.md` was corrected to state the server sends `modifier_pct` as whole
percent points (`12.0`, `15.0`, `20.0`), not a `0-1` fraction. The client code was never
updated to match - it still treats every `modifier_pct` value as if it were already a
fraction. This was verified dynamically, not just read off the diff: driving
`GridPrepScene._on_validate_grid_completed` with a realistic server payload
(`modifier_pct: 15.0`) and inspecting the actual values shows the shader uniform receives
raw `15.0` (Godot does not clamp `set_shader_parameter` calls to a uniform's
`hint_range`), which the fragment shader then clamps to `1.0` - so every real synergy
(`12`/`15`/`20`) renders at identical max brightness with the 0.35s fade-in bloom
collapsing to a near-instant pop. The chime pitch fares worse: `1.0 + modifier_pct` with a
live value of `15.0` sets `AudioStreamPlayer.pitch_scale = 16.0`, a garbled high-speed
squeal instead of the intended subtle lift.

The offline `GridPrepPreviewHarness` never catches this because it injects
`modifier_pct: 0.25` directly into `_on_validate_grid_completed`, bypassing `ApiClient`
entirely - offline and live diverge by construction. This doc closes both gaps: normalize
once at the network boundary, and make the harness go through the same normalization path
so it can never again drift from what the live server sends.

## Root cause (two call sites, one shared root)

- `scenes/grid_prep/GridPrepScene.gd:825` - `var pitch := 1.0 + float(fresh[i].get("modifier_pct", 0.2))`
- `scenes/grid_prep/GridPrepScene.gd:883` - `strip.fade_in_to(float(synergy.get("modifier_pct", 0.2)))` (consumed by `scripts/ui/SynergyBorder.gd:20` as a `0-1` shader intensity)

Both assume `modifier_pct` is already a fraction (the `0.2` fallback defaults agree with
that assumption). Patching both sites individually is fragile - any future consumer of
`validate_grid_completed` (e.g. a Battle Report screen reading synergy strength) would
reintroduce the same bug. Normalize once, at ingestion, instead.

## Required fix: normalize in `ApiClient`, not at each call site

`ApiClient._handle_response` (`scripts/autoloads/ApiClient.gd:164-179`) is generic across
all 15 RPCs and must stay that way - it has no knowledge of any endpoint's response shape.
Do not add `validate_grid`-specific branching there. Instead, insert one endpoint-specific
normalization step between the raw HTTP response and the public signal, for this endpoint
only:

```gdscript
# New private signal - the real target passed to _request(); never exposed outside ApiClient.
signal _validate_grid_raw_completed(data: Dictionary)

func _ready() -> void:
    _validate_grid_raw_completed.connect(_on_validate_grid_raw_completed)

func validate_grid(grid: Dictionary) -> void:
    _request(HTTPClient.METHOD_POST, "/v1/grid/validate", {"grid": grid}, {}, true,
        _validate_grid_raw_completed, validate_grid_failed)

func _on_validate_grid_raw_completed(data: Dictionary) -> void:
    validate_grid_completed.emit(normalize_validate_grid_response(data))

# Public (no leading underscore - the offline preview harness calls this directly, see
# below) and pure: does not mutate a dict the caller still holds elsewhere by reference
# if that ever matters. api_contract.md: synergies[].modifier_pct is whole percent points
# server-side (15.0 == +15%); every downstream consumer keeps assuming a 0-1 fraction.
func normalize_validate_grid_response(data: Dictionary) -> Dictionary:
    for synergy: Dictionary in data.get("synergies", []):
        if synergy.has("modifier_pct"):
            synergy["modifier_pct"] = float(synergy["modifier_pct"]) / 100.0
    return data
```

`validate_grid_completed`'s public signature and every existing consumer
(`GridPrepScene._on_validate_grid_completed`) stay unchanged - they already assume a
fraction, which is now true by the time the signal fires. **Do not touch
`GridPrepScene.gd:825` or `:883`** - once the boundary is fixed those call sites are
already correct.

## Required fix: offline harness must go through the same path

`GridPrepPreviewHarness.gd:84-87` currently calls:

```gdscript
_grid._on_validate_grid_completed({"synergies": [
    {"source_item_id": "preview-1", "target_item_id": "preview-2",
        "direction": "EAST", "modifier_pct": 0.25},
]})
```

Change the injected value to a realistic whole-percent-point number and route it through
the real normalizer, so the offline screenshot can never again render a different result
class than live:

```gdscript
_grid._on_validate_grid_completed(ApiClient.normalize_validate_grid_response({"synergies": [
    {"source_item_id": "preview-1", "target_item_id": "preview-2",
        "direction": "EAST", "modifier_pct": 15.0},
]}))
```

## Verification (mandatory before requesting review)

1. `godot --headless --path . --import` - clean.
2. `SYNGRID_SCREENSHOT=/tmp/out.png godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn` - synergy border must render as a soft bloom (fade-in visible mid-ramp, not instant-max), matching the pre-existing offline screenshot's visual class.
3. `SYNGRID_SCREENSHOT=/tmp/out_live.png SYNGRID_LIVE=1 godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn` against a running `../sync-grid` server - confirm the live screenshot's glow intensity is in the same visual class as the offline one (this is the issue's acceptance criterion; it was impossible to satisfy before this fix by construction).
4. Add a temporary print in `_on_validate_grid_completed` (or step through in the debugger) confirming `synergy.modifier_pct` is a value like `0.12`-`0.20` by the time it reaches `GridPrepScene`, both offline and live. Remove the print before commit.
5. Confirm chime pitch: with a live `modifier_pct` of `15.0`, `pitch_scale` at `AudioManager.play_synergy_link` must land at `1.15`, not `16.0` - listen for a subtle lift, not a chipmunk squeal.

## Out of scope

- No change to `docs/api_contract.md` - already corrected.
- No change to the shader (`assets/shaders/synergy_glow.gdshader`) or `SynergyBorder.gd` - both are correct once fed a real `0-1` fraction.
- No retroactive clamp/sanitization of `modifier_pct` in the shader or `AudioManager` as a defense-in-depth measure - the normalization boundary is the single source of truth; adding a second silent-clamp layer would hide a future contract regression instead of surfacing it.
