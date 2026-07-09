# LLD: Recycler Sell-Price Preview (E5 Fast-Follow, §2.5)

Status: Approved 2026-07-09.
Owner: Claude Code (Lead Architect).
Governs: GitHub issue #59.
Depends on: `nomotomo/syn-grid#77` (shipped in PR #78 - `Item.sell_price` now present on every
server response that carries an `Item`), `docs/api_contract.md` (updated alongside this doc),
`docs/juice_manual.md` (no new violations introduced by this change - this is a label-text swap,
not a new tween/shader).

## Why this doc exists

§2.5 of `docs/improvements.md` asked for a "SELL: +Ng" gold-amount preview while dragging a bench
item over the recycler. Issue #32 shipped everything else in that section but descoped this one
piece because the wire `Item` object had no `sell_price` field - see the HLD's "Data-shape check"
(`docs/high-level-design/issue-32-grid-prep-decision-clarity.md`). `sync-grid#77` closed that gap.
This doc wires the now-available field into the existing recycler-hover UI - no new component,
no new server call.

## Grounding in current code

`GridPrepScene.gd`:
- `_ready()` (`:84-88`) builds `_recycler_rest_style` / `_recycler_hot_style` and applies the rest
  style to `_recycler_panel`.
- `_process()` (`:539-572`) already computes hover-over-recycler every frame while a card drags:
  `:570-572` toggles `_recycler_panel`'s stylebox between hot/rest based on
  `_recycler_panel.get_global_rect().has_point(center)`. This is the one true hover check - reuse
  it, do not add a second `has_point` call.
- `_dragging_origin` (`:64`) is already set to `_bench_row` when a bench card starts dragging, and
  is exactly the check `_on_card_drag_ended` (`:585-592`) uses to decide sellability. Reuse the same
  check for the preview so the text never promises a sale that `_on_card_drag_ended` would then
  refuse (equipped-item drags over the recycler get bounced back with "ONLY BENCH ITEMS CAN BE
  RECYCLED" - they must keep showing the plain hover text, not a false "SELL: +Ng").
- `_on_card_drag_ended()` (`:574-579`) already resets the panel style back to rest on drop; the
  label needs the same reset in the same place.

`GridPrepScene.tscn` (`:78-83`): `RecyclerLabel` is a plain `Label` child of `RecyclerPanel`, not
currently exposed via `unique_name_in_owner`, text authored directly in the scene:
`"RECYCLER - DRAG A BENCH ITEM HERE TO SELL"`.

Existing gold-text convention: `GridPrepScene.gd:388` already does
`_status_label.text = "ROUND GRANT +%dG" % int(...)` - uppercase `G`, no space before the sign.
Match this exact convention here instead of the issue's placeholder `"SELL: +Ng"` wording, so the
two gold-gain strings in this scene read consistently: **`"SELL: +%dG" % sell_price`**.

`scripts/ui/SynGridPalette.gd:44`: `GOLD = Color(0.95, 0.78, 0.29)` - already the palette's gold
constant, used elsewhere for gold values (`StatsHud.gd:47,50`). Use it for the sell-preview text
color so it reads as a gain, distinct from the panel's red danger tint.

## Required change 1: expose the label

In `GridPrepScene.tscn`, add `unique_name_in_owner = true` to the `RecyclerLabel` node (matching
every other `%Name`-accessed node in this scene). Then in `GridPrepScene.gd`, add next to the other
`@onready` recycler reference:

```gdscript
@onready var _recycler_label: Label = %RecyclerLabel
```

## Required change 2: cache the default text (do not duplicate the literal)

In `_ready()`, after the existing recycler style setup (`:88`), cache whatever the scene authored
rather than hardcoding the string a second time in the script:

```gdscript
var _recycler_default_text: String = ""
...
func _ready() -> void:
    ...
    _recycler_label.add_theme_color_override("font_color", SynGridPalette.TEXT_PRIMARY)
    _recycler_default_text = _recycler_label.text
```

(`_recycler_default_text` is a new member var alongside `_recycler_rest_style`/`_recycler_hot_style`
at `:77-78`.)

## Required change 3: drive the label from the existing hover check

`_process()` (`:570-572`) currently reads:

```gdscript
_recycler_panel.add_theme_stylebox_override("panel",
    _recycler_hot_style if _recycler_panel.get_global_rect().has_point(center)
    else _recycler_rest_style)
```

Extract the hover bool once and use it for both the style and the label:

```gdscript
var is_over_recycler := _recycler_panel.get_global_rect().has_point(center)
_recycler_panel.add_theme_stylebox_override("panel",
    _recycler_hot_style if is_over_recycler else _recycler_rest_style)

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

Add the small reset helper (used here and in change 4) rather than repeating both lines inline:

```gdscript
func _reset_recycler_label() -> void:
    _recycler_label.text = _recycler_default_text
    _recycler_label.add_theme_color_override("font_color", SynGridPalette.TEXT_PRIMARY)
```

`item` is already in scope in `_process()` (`:545`, `_dragging_card.get("_item_data")`) - no new
lookup needed. The `sell_price <= 0` fallback covers a stale cached item from before the server
change, per the issue's explicit acceptance criterion: never show `+0G` or invent a number, fall
back to the plain hover text.

## Required change 4: reset on drag end

`_on_card_drag_ended()` (`:574-579`) already resets the panel stylebox to rest on every drop path
(sell, place, return, bounce). Add the label reset in the same spot so no frame renders a stale
"SELL: +Ng" after the drag ends and before the next `_process()` tick:

```gdscript
_recycler_panel.add_theme_stylebox_override("panel", _recycler_rest_style)
_reset_recycler_label()
```

## Required change 5: harness and fixture coverage

`SAMPLE_BENCH_ITEMS` in `GridPrepPreviewHarness.gd:20-27` needs a `sell_price` key on at least one
entry (e.g. `preview-1`, since it's already used for the mid-drag synergy screenshot at `:112`) so
the new label path is exercised. Use a value distinguishable from any other on-screen number, e.g.
`2` (bench-hover uses `preview-1`/Shortsword, `buy_price` is `3` in `SAMPLE_SHOP_SLOTS:30` - keep
`sell_price` different from `buy_price` so a reviewer can tell which number is on screen).

Add one more entry with `sell_price` deliberately omitted (or `0`) to exercise the fallback path in
the same run - reuse an existing bench item that isn't otherwise load-bearing for the merge/synergy
assertions, e.g. `preview-5` (Healing Draught, currently unused by any assertion in
`_run_offline_verify`).

Add a new screenshot step in `_run_offline_verify()`, after the existing mid-drag synergy block
(`:107-137`) and its drag-end (`:129-130`), following the exact same start/end pattern documented in
the comment at `:108-111` (direct `_on_card_drag_started`/`_on_card_drag_ended` calls - do not mix
with simulated mouse-up, per the bug already fixed in PR #58):

```gdscript
# Recycler sell-price preview: hover a bench item over the recycler panel.
var sell_drag_card := _bench_card_for_id("preview-1")
if sell_drag_card != null:
    _simulate_mouse_button(MOUSE_BUTTON_LEFT, true)
    _grid._on_card_drag_started(sell_drag_card)
    var recycler_center := _grid.get_node("%RecyclerPanel").get_global_rect().get_center()
    sell_drag_card.global_position = recycler_center - sell_drag_card.size / 2.0
    for _i in 15:
        await get_tree().process_frame
    var label_text: String = _grid.get_node("%RecyclerLabel").text
    print("auto-verify: recycler label mid-hover = '%s'" % label_text)
    if not label_text.begins_with("SELL: +"):
        push_error("auto-verify: expected recycler label to show a sell-price preview, got '%s'" % label_text)
    _save_png(_sell_preview_path_for(screenshot_path))
    _grid._on_card_drag_ended(sell_drag_card, recycler_center)
    _simulate_mouse_button(MOUSE_BUTTON_LEFT, false)
    for _i in 10:
        await get_tree().process_frame
    var reset_text: String = _grid.get_node("%RecyclerLabel").text
    if reset_text.begins_with("SELL: +"):
        push_error("auto-verify: recycler label must reset after drag end, still showing '%s'" % reset_text)
```

Add `_sell_preview_path_for()` mirroring the existing `_confirmed_path_for()` (`:158-161`) rather
than a bespoke string op.

## Non-goals / do-not-touch

- No change to `ApiClient.sell_item` or any payout logic - this is a read of a value the server
  already sends, purely presentational.
- No client-side computation of `sell_price` anywhere - grep the diff for any arithmetic on
  `base_dmg`/`level`/template lookups near this code; there should be none. The number comes from
  the server response verbatim.
- Do not touch the equipped-item bounce path (`"ONLY BENCH ITEMS CAN BE RECYCLED"`) - it already
  behaves correctly and is explicitly excluded from the preview by the `_dragging_origin ==
  _bench_row` check above.
- No new node, no new scene - `RecyclerLabel` already exists and is the only text on the panel.

## Verification (mandatory before requesting review)

1. `godot --headless --path . --import` - clean.
2. `SYNGRID_SCREENSHOT=/tmp/grid_prep.png godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn`
   - console must show `recycler label mid-hover = 'SELL: +2G'` (or whatever value is fixtured) and
     no `push_error`.
   - open the new `_sell_preview` screenshot and visually confirm gold-colored "SELL: +2G" text on
     the reddened recycler panel while the card hovers over it.
3. Grep the diff: no arithmetic deriving a sell price client-side; the only new read is
   `item.get("sell_price", 0)`.
4. Confirm `docs/api_contract.md`'s `Item` reference block documents `sell_price` (added alongside
   this LLD - see that file's `## Grid Object Reference` section).

## Out of scope

- No other §2.5 visual changes - the red-hover danger cue is unchanged.
- `docs/api_contract.md` documentation of `sell_price` is a doc change owned by Claude Code, not
  part of this PR's diff (already done as a prerequisite to unblocking this issue).
