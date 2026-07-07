# LLD: Small Fixes Batch (Issues #12, #13, #25, #44)

Status: Approved 2026-07-07.
Owner: Claude Code (Lead Architect).
Governs: GitHub issues #12, #13, #25, #44 - four small, independent, contained bugs bundled into one doc since none needs its own architectural discussion. Each still ships on its own branch/PR per this repo's one-issue-one-branch convention; they touch different files and can be implemented and reviewed in parallel.

## #12 - RoundEndScene: hearts row has no caption label

`RoundEndScene.tscn` has `RoundCaption`, `TriumphCaption` (text `"TRIUMPH"`), and `PayoutCaption` (text `"NEXT ROUND GRANT"`) but no caption above `HeartsRow` - confirmed no such node exists in the scene or `RoundEndScene.gd`.

**Fix**: add a new `Label` node `LifeCaption` in `RoundEndScene.tscn`, copying `TriumphCaption`'s node config exactly (`theme_type_variation = &"CaptionLabel"`, `theme_override_font_sizes/font_size = 16`, `horizontal_alignment = 1`, `unique_name_in_owner = true`), with `text = "LIFE"`. Place it as a sibling immediately before `HeartsRow` in the node tree (matching how `TriumphCaption` precedes `OrbsRow`).

Add the onready var and wire it into `_layout_screen()` (`RoundEndScene.gd:85-97`):

```gdscript
@onready var _life_caption: Label = %LifeCaption
```

`_layout_screen()` positions every row by an absolute `size.y * fraction` - inserting a new row means every fraction from `_hearts_row` downward shifts. Current fractions: hearts `0.34`, triumph caption `0.44`, orbs `0.48`, payout caption `0.60`, payout value `0.64`, buttons `0.76`. Insert the life caption at `0.30` (matching the ~0.10 gap pattern already used between round caption `0.22` and hearts `0.34`) and shift hearts down to `0.34` unchanged... actually hearts must move down to make room for the new caption above it. Use:

```gdscript
_life_caption.position = Vector2(40.0, size.y * 0.30)
_life_caption.size = Vector2(size.x - 80.0, 32.0)
_hearts_row.position = Vector2(40.0, size.y * 0.36)
_hearts_row.size = Vector2(size.x - 80.0, heart_size)
_triumph_caption.position = Vector2(40.0, size.y * 0.46)
_triumph_caption.size = Vector2(size.x - 80.0, 32.0)
_orbs_row.position = Vector2(40.0, size.y * 0.50)
_orbs_row.size = Vector2(size.x - 80.0, orb_size)
_payout_caption.position = Vector2(40.0, size.y * 0.62)
_payout_caption.size = Vector2(size.x - 80.0, 32.0)
_payout_value.position = Vector2(40.0, size.y * 0.66)
_payout_value.size = Vector2(size.x - 80.0, 48.0)
_continue_button.position = Vector2(40.0, size.y * 0.78)
_new_run_button.position = Vector2(40.0, size.y * 0.78)
```

(Each fraction shifted +0.02 from its original value, preserving the original relative gaps; button size/width lines are unchanged.) Re-check on a 1080x1920 viewport that `0.78 + (140.0/1920.0) ≈ 0.85` still clears the bottom edge - it does, same margin the original `0.76` had.

**Verification**: `SYNGRID_RESULT=win|loss|dead|victory` offline harness screenshots (all four, per the Commands section of `CLAUDE.md`) - confirm "LIFE" renders above the hearts row, nothing overlaps, and the whole ceremony still fits on a 540x960 capture. Also run the live variant once a server is available.

## #13 - RoundEndPreviewHarness: live screenshot fires before orbs settle

`_run_live_verify()` (`RoundEndPreviewHarness.gd`, wait at line ~207) uses a 90-frame wait; `_run_offline_verify()` (line 122) uses 150 frames and its own comment documents the full ceremony takes ~2.2s wall (hearts + orbs). The 90-frame live wait fires before the orb ceremony completes, so `SYNGRID_LIVE=1` screenshots can't catch a real regression in that portion - already caused this repo's mandatory dynamic-verification step to be weaker than intended on a past PR.

**Correction (2026-07-07, after PR #50 review)**: the fix below is wrong and must not be implemented as originally written. It assumed `_continue_button.visible or _new_run_button.visible` only becomes true after `_run_ceremony()` finishes. That's false: `RoundEndScene.gd:_ready()` sets one of the two buttons' `.visible` to `true` **immediately**, before `_run_ceremony()` is even called - the actual reveal is a `scale` tween (`_pop_continue()`/`_pop_terminal_button()`, run at the very end of the ceremony) that this poll condition never looks at. Confirmed dynamically: this poll exits at frame 0 and produces a completely blank screenshot, which is worse than the original bug (fires even before the intro banner pops in). `scale.x >= 0.99` has the identical flaw (`Control.scale` defaults to `Vector2.ONE` before `_pop_continue()` ever touches it).

**Actual fix**: revert to a hardcoded frame count in `_run_live_verify()`, raised to match (or slightly exceed) `_run_offline_verify()`'s own documented 150 frames. This is the issue's own first-listed, simpler option - take it. A true event-driven completion signal (`ceremony_finished`, emitted after awaiting the reveal tween in `_pop_continue()`/`_pop_terminal_button()`) would be the more correct long-term fix, but it changes `RoundEndScene`'s production contract and isn't warranted just to unblock this small harness-timing bug - only worth doing if event-driven sync is wanted for its own sake.

~~Fix: per the issue's own preferred direction, poll on ceremony completion rather than a hardcoded frame count, so the two verify paths can never drift again:~~

```gdscript
var frames := 0
while not (_replay_scene_continue_visible() or frames >= 400):
    await get_tree().process_frame
    frames += 1
```

~~where `_replay_scene_continue_visible()` checks the instantiated `RoundEndScene`'s `_continue_button.visible or _new_run_button.visible` (both flip `true` only after `_run_ceremony()` finishes, per `RoundEndScene.gd:_ready()`).~~ (Struck through - see correction above. Do not implement this.)

**Verification**: run both `SYNGRID_LIVE=1` and offline `SYNGRID_RESULT=win` against the same scenario and confirm both screenshots show the orbs fully popped in, not just the offline one.

## #25 - arcane_rune_field.gdshader: hash-coupled variant/presence

`assets/shaders/arcane_rune_field.gdshader:44-46`:

```glsl
float h = hash21(cell);
int variant = int(floor(h * 4.0));
float presence = step(0.55, h);
```

`presence` is only `1.0` when `h >= 0.55`; `variant` only equals `0` or `1` when `h < 0.5`. Since both read the same `h`, variants 0 (circle) and 1 (diamond) can never be visible - only 2 (cross) and 3 (square) ever render whenever `presence` is true. Confirmed: this is the exact bug behind "only pluses and small squares ever appear."

**Fix**: derive `variant` and `presence` from independent hashes, salting the second input so it doesn't correlate with the first:

```glsl
float h = hash21(cell);
int variant = int(floor(h * 4.0));
float presence = step(0.55, hash21(cell + vec2(17.0, 31.0)));
```

**Scope decision on item 2 (masking/density)**: the shader already has a radial vignette (`vign` in `fragment()`, `smoothstep(1.3, 0.5, length(UV - 0.5) * 1.5)`) that dims density away from screen center - this is an existing, if imperfect, mitigation for "competes with foreground UI." Do not add a content-column exclusion mask speculatively; land the hash fix first, then re-screenshot `MainMenuPreviewHarness`/`SeasonHubPreviewHarness` and judge whether the existing vignette is sufficient now that all four variants (a visually calmer mix than the current circle/diamond-starved one) are in play. If it still reads as clutter, that's a follow-up, not part of this fix - issue #25 itself says to flag rather than presume.

**Verification**: run both harnesses' offline screenshots, and additionally capture 2-3 frames a few seconds apart (the shader is time-driven and cells drift) to confirm circles and diamonds are now visibly present, not just crosses/squares.

## #44 - Expanded-grid: numeric header fallback, doubled headers, bench clipping

Three independent root causes in `scenes/grid_prep/GridPrepScene.gd`, all inside `_build_coord_labels()` (`:214-240`) and `_layout_screen()` (`:135-183`):

### 1. Column letters hardcoded to A-D

`:216`: `var col_letters := ["A", "B", "C", "D"]`, with `:225`: `col_label.text = col_letters[x] if x < col_letters.size() else str(x)` - any column past D falls back to a raw index. Fix: generate the letter programmatically, no array, no size limit:

```gdscript
col_label.text = char(65 + x)   # 'A' + x; supports any column count without a lookup table
```

### 2. Headers duplicate across relayouts

`_build_cells()` (`:200-208`) calls `_clear_grid_cells()` (`:242-247`) first, which only clears `_cells` (the `GridCell` nodes in `_grid_container`) - it never touches the column/row `Label` nodes `_build_coord_labels()` adds directly to `_grid_area` (`:228`, `:240`). When `_maybe_rebuild_grid_from_state()` triggers a second `_build_cells()` call (e.g. live mode fetching real grid dimensions after the offline default), the old label nodes are still there and new ones stack on top - this is the "AA, B B, C C" duplication.

Fix: track the labels and free them before rebuilding, mirroring `_cells`' own clear pattern:

```gdscript
var _coord_labels: Array[Label] = []   # new state, alongside _cells

func _build_coord_labels() -> void:
    for label in _coord_labels:
        label.queue_free()
    _coord_labels.clear()
    var outer := _cell_outer_size()
    # No col_letters array - char(65 + x) replaces it entirely (fix 1).
    for x in grid_columns:
        var col_label := Label.new()
        ...
        col_label.text = char(65 + x)
        col_label.position = Vector2(x * outer.x, -22.0)
        col_label.size = Vector2(outer.x, 20.0)
        _grid_area.add_child(col_label)
        _coord_labels.append(col_label)
    for y in grid_rows:
        var row_label := Label.new()
        ...
        _grid_area.add_child(row_label)
        _coord_labels.append(row_label)
```

### 3. Bench cards clipped behind the recycler bar on tall grids

Root cause is a units mismatch, not a missing reservation. `_compute_layout_cell_size()` (`:122-133`) already reserves bottom-section height using the **nominal** export `cell_size.y` (`:124`: `_bottom_section_height(cell_size.y)`) - correct, since bench cards render at their own fixed `ItemCard.card_size` (`:288`: `_reset_footprint_visual` sets `card.custom_minimum_size = card.card_size`, independent of the grid's cell size). But `_layout_screen()` then positions the bench row, bench panel, and recycler using `_layout_cell_size.y` (the **shrunk-to-fit-the-grid** cell size) instead of the nominal `cell_size.y` it was actually reserved against (`:166`, `:171`, `:177`). For grids where `_layout_cell_size.y` shrinks below `card_size.y` (rows > ~4 on a 1080x1920 viewport), the bench row's HBoxContainer bounding box ends up shorter than its children's actual rendered height, and since `HBoxContainer` doesn't clip by default, the bench cards visually overflow downward into the recycler panel positioned right below.

Fix: use the nominal `cell_size.y` (matching what was actually reserved) at all three sites:

```gdscript
_bench_row.offset_bottom = bench_top + cell_size.y
...
_bench_panel.size = Vector2(size.x - 48.0, cell_size.y + caption_gap + 36.0)
...
var recycler_top := bench_top + cell_size.y + section_gap
```

Note `ItemCard`'s own default `card_size` is `Vector2(140, 168)` while `GridPrepScene.cell_size` defaults to `Vector2(150, 150)` - the reservation is based on `cell_size.y` (150), which is still 18px short of the actual rendered card height (168). This gap is independent of grid row count (it exists even at 4 rows) and evidently hasn't caused a reported clipping problem there, likely absorbed by the bench panel's extra `+ 36.0` padding - but re-check the 6x6 screenshot in verification below; if clipping persists even after the `_layout_cell_size.y` -> `cell_size.y` fix, the remaining fix is bumping that padding constant, not re-deriving the whole layout.

**Verification** (mandatory before requesting review, all four sub-fixes together since they're all in the same two functions):
1. `godot --headless --path . --import` - clean.
2. `SYNGRID_SCREENSHOT=... godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn` (default/offline, likely 4x4 or 5-column per the issue) - confirm single, alphabetic headers (A, B, C, D, E, ...), no duplication, no numeric fallback.
3. `SYNGRID_SCREENSHOT=... SYNGRID_LIVE=1 godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn` against a running server with a 6-column grid - confirm headers are NOT doubled (this is the case that specifically exercises the relayout path via `_maybe_rebuild_grid_from_state`).
4. With a 5-6 row grid (live or a temporarily-patched offline fixture), confirm bench cards render fully, including their name label, with no visible overlap into the recycler bar.

## Out of scope
- #15 (AudioManager WAV leak), #19 (real sprite pack staging) - both deferred; #15 needs runtime resource-lifecycle investigation and #19 is an asset-sourcing task, neither is a small contained code fix like the four above.
