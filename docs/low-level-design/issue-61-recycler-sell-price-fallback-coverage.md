# LLD: recycler sell-price fallback regression coverage

Tracks: [nomotomo/syn-grid-client#61](https://github.com/nomotomo/syn-grid-client/issues/61).

## Problem

PR #60 (issue #59) added the recycler sell-price preview to `GridPrepScene.gd`'s `_process()`
(`scenes/grid_prep/GridPrepScene.gd:578-586`):

```gdscript
if is_over_recycler and _dragging_origin == _bench_row:
    var sell_price := int(item.get("sell_price", 0))
    if sell_price > 0:
        _recycler_label.text = "SELL: +%dG" % sell_price
        _recycler_label.add_theme_color_override("font_color", SynGridPalette.GOLD)
    else:
        _reset_recycler_label()
else:
    _reset_recycler_label()
```

The `else` branch (no/zero `sell_price` - "never invent a number") is production-correct but has
zero automated coverage. `GridPrepPreviewHarness.gd`'s only recycler-hover assertion
(`_run_offline_verify()`, currently around `:141-162`) drags `preview-4`, which always carries
`"sell_price": 2` in `SAMPLE_BENCH_ITEMS` (`:24`) - so the fallback branch only gets a one-off
manual check (done during PR #60's review, then discarded) instead of a standing regression test.

This is harness-only. No production code changes.

## Design

### Fixture

`preview-5` (Healing Draught, `GridPrepPreviewHarness.gd:25`) already omits `sell_price` entirely -
no fixture edit needed. It's otherwise unused by any assertion in `_run_offline_verify()` per the
issue and the original design note in `docs/low-level-design/issue-59-sell-price-preview.md`
("Required change 5"), so using it here doesn't collide with the merge/synergy/auto-arrange blocks
earlier in the same run. Confirm this stays true after implementation - if a future change starts
consuming `preview-5` for a different assertion, this block needs a different fixture, not a second
`sell_price`-less entry.

### New assertion block

Add immediately after the existing preview-4 recycler-hover block in `_run_offline_verify()`
(right after the `else: push_error("auto-verify: no bench card for preview-4 ...")` at the current
`:161-162`, before the `_on_validate_grid_completed(...)` call at `:164`). Mirrors the existing
block's start/end pattern exactly (direct `_on_card_drag_started`/`_on_card_drag_ended` calls, not
simulated mouse-up - same reasoning as the documented `:108-111` comment on the mid-drag block: a
simulated release without the matching direct call leaves `ItemCard._dragging` in the wrong state).

```gdscript
# Recycler sell-price fallback: hovering a bench item with no sell_price must
# never show "SELL: +0G" - the label stays on its default text (§2.5 follow-up, issue #61).
var no_price_drag_card := _bench_card_for_id("preview-5")
if no_price_drag_card != null:
    _simulate_mouse_button(MOUSE_BUTTON_LEFT, true)
    _grid._on_card_drag_started(no_price_drag_card)
    var recycler_center_2: Vector2 = _grid.get_node("%RecyclerPanel").get_global_rect().get_center()
    no_price_drag_card.global_position = recycler_center_2 - no_price_drag_card.size / 2.0
    for _i in 15:
        await get_tree().process_frame
    var fallback_text: String = _grid.get_node("%RecyclerLabel").text
    print("auto-verify: recycler label mid-hover (no sell_price) = '%s'" % fallback_text)
    if fallback_text.begins_with("SELL: +") or fallback_text != _grid._recycler_default_text:
        push_error("auto-verify: recycler label must not invent a sell price when sell_price is absent, got '%s'" % fallback_text)
    else:
        print("auto-verify: recycler label correctly stayed on default text for no-sell_price item")
    _grid._on_card_drag_ended(no_price_drag_card, recycler_center_2)
    _simulate_mouse_button(MOUSE_BUTTON_LEFT, false)
    for _i in 10:
        await get_tree().process_frame
else:
    push_error("auto-verify: no bench card for preview-5 (sell-price fallback)")
```

Notes for the implementer:

- `_grid._recycler_default_text` is directly reachable the same way the harness already reaches
  `_grid._preview_borders`, `_grid._highlight_anchor`, etc. - this file already treats `GridPrepScene`
  internals as harness-visible by convention, so no new accessor is needed.
- Assert both `begins_with("SELL: +")` is false *and* exact equality against
  `_grid._recycler_default_text`, not just the `begins_with` negation alone - the issue's acceptance
  criterion is "shows the cached default text", and a bare negation would silently pass even if the
  label showed some other wrong (but non-`"SELL: +"`-prefixed) string.
- Reuse `recycler_center_2` as the local variable name (not `recycler_center`) since the preview-4
  block above it already declares `recycler_center` in the same function scope - GDScript will not
  let you redeclare it in the same block.
- Do not touch `GridPrepScene.gd` - production logic is already correct per the issue.

## Acceptance

- New block runs as part of the existing `_run_offline_verify()` sequence (no new env var or mode).
- Harness `push_error`s if a bench item with no/zero `sell_price` ever shows a `"SELL: +"` label
  while hovering the recycler, or shows anything other than the cached default text.
- Regression proof required before opening the PR: temporarily strip the guard (e.g. force the
  `if sell_price > 0` branch to always take the `SELL:` path, or comment out the new fixture's
  omitted-`sell_price` condition) and confirm the new assertion fails loud, then revert - this
  proves the check is sensitive, not vacuous (same bar as the regression test added for #60 on the
  server side).
- `godot --headless --path . --import`, then run the harness in offline mode with
  `SYNGRID_SCREENSHOT=/tmp/grid_prep.png` and confirm: (a) no new `push_error` output, (b) the
  existing preview-4 (`SELL: +2G`) assertion still passes, (c) the new preview-5 assertion passes,
  (d) `_sell_preview.png` and `_confirmed.png` screenshots still render correctly (visually spot-check
  - a blank/broken frame is a failure per this repo's PR Review Protocol).
