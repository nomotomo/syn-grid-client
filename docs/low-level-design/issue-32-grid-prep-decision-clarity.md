# LLD: E5 Grid-Prep Decision Clarity

Status: Approved 2026-07-09.
Owner: Claude Code (Lead Architect).
Governs: GitHub issue #32 (E5, Client Experience Roadmap epic #42).
Source spec: `docs/improvements.md` §2.1, §2.3, §2.6, §10.3. (§2.5 deferred - see HLD.)
HLD: `docs/high-level-design/issue-32-grid-prep-decision-clarity.md` - read that first for the data-shape
decisions (why the preview is receptor-based, why the merge trigger changes source, why §2.5 is deferred).
Backend dependency filed and tracked separately: `sync-grid#77` (not required for this PR).

The snippets below are reference implementations pinning exact call sites, signatures, and data flow -
Cursor still owns final integration, naming polish, and test authorship per the standard division of
labor in this repo's `CLAUDE.md`.

## Convention: new nodes are code-created, not `.tscn`-edited

Follows the precedent already established in `docs/low-level-design/issue-29-combat-readability-telemetry.md`.
The auto-arrange button and any preview-strip container are created in `_ready()`/`_layout_screen()`, not
added to `GridPrepScene.tscn`.

## Shared primitive: `_synergy_match`

```gdscript
# GridPrepScene.gd - new static-style helper (no external state, pure function of its args).
# Returns the modifier_pct of whichever item has a receptor pointed at the other in the given
# direction, or 0.0 if neither does. Mirrors sync-grid's ComputeSynergies (internal/inventory/inventory.go):
# it checks BOTH items as a potential "src", exactly like the server evaluates every equipped item
# independently - synergy is not assumed to be mutual.
func _synergy_match(item_a: Dictionary, item_b: Dictionary, dir_a_to_b: String) -> float:
    var dir_b_to_a := _opposite_direction(dir_a_to_b)
    var a_receptor := _matching_receptor(item_a, dir_a_to_b, String(item_b.get("item_type", "")))
    var b_receptor := _matching_receptor(item_b, dir_b_to_a, String(item_a.get("item_type", "")))
    return maxf(a_receptor, b_receptor)

func _opposite_direction(dir: String) -> String:
    match dir:
        "NORTH": return "SOUTH"
        "SOUTH": return "NORTH"
        "EAST": return "WEST"
        "WEST": return "EAST"
        _: return ""

# Accounts for the item's own `rotated` flag the same way the server does
# (RotateDir: NORTH->EAST->SOUTH->WEST->NORTH, one step per 90 degrees) before comparing.
func _matching_receptor(item: Dictionary, probe_dir: String, neighbor_type: String) -> float:
    var receptors: Array = item.get("synergy_receptors", [])
    var rotated: bool = item.get("rotated", false)
    for r: Dictionary in receptors:
        var effective_dir := String(r.get("direction", ""))
        if rotated:
            effective_dir = _rotate_dir_cw(effective_dir)
        if effective_dir == probe_dir and String(r.get("accepts_type", "")) == neighbor_type:
            return float(r.get("modifier_pct", 0.0))
    return 0.0

func _rotate_dir_cw(dir: String) -> String:
    match dir:
        "NORTH": return "EAST"
        "EAST": return "SOUTH"
        "SOUTH": return "WEST"
        "WEST": return "NORTH"
        _: return dir
```

`_neighbors_of(anchor_cell: GridCell, footprint: Vector2i) -> Array[Dictionary]` is a small companion
helper both goal 1 and goal 3 call: given an anchor and a footprint, return
`[{cell: GridCell, direction: String}, ...]` for every occupied cell cardinally adjacent to that
footprint's four outer edges (reuse the existing `_footprint_rect`/edge-geometry approach
`_spawn_synergy_border` already uses, `GridPrepScene.gd:858-896`, but returning cell+direction pairs
instead of building a visual strip directly).

## 1. Synergy preview overlay

New members alongside the existing drag-hover state:

```gdscript
var _preview_borders: Array[SynergyBorder] = []  # cleared/rebuilt on hover-anchor change only
```

Hook into the existing hover-anchor change-detection block in `_process` (`GridPrepScene.gd:542-548`),
which already fires only when `anchor`/`valid` actually change frame-to-frame:

```gdscript
if anchor != _highlight_anchor or valid != _highlight_valid:
    _highlight_anchor = anchor
    _highlight_valid = valid
    if anchor == null:
        _clear_drop_highlight()
        _clear_preview_synergy()
    else:
        _set_drop_highlight(anchor, item, valid)
        if valid:
            _refresh_preview_synergy(anchor, item)
        else:
            _clear_preview_synergy()
```

```gdscript
func _refresh_preview_synergy(anchor: GridCell, item: Dictionary) -> void:
    _clear_preview_synergy()
    var footprint := GameState.item_footprint(item)
    for pair: Dictionary in _neighbors_of(anchor, footprint):
        var neighbor_card := pair.cell.get_card()
        if neighbor_card == null:
            continue
        var modifier := _synergy_match(item, neighbor_card.get("_item_data"), pair.direction)
        if modifier <= 0.0:
            continue
        var strip: SynergyBorder = SYNERGY_BORDER_SCENE.instantiate()
        _synergy_layer.add_child(strip)
        _position_strip_on_edge(strip, anchor, footprint, pair.direction)  # same geometry as _spawn_synergy_border
        strip.fade_in_to(modifier * preview_intensity_scale)  # dimmer than a confirmed link
        _preview_borders.append(strip)

func _clear_preview_synergy() -> void:
    for border in _preview_borders:
        border.fade_out_and_free()
    _preview_borders.clear()
```

`preview_intensity_scale: float = 0.5` (new `@export`) - a preview link reads as a dimmer hint, a confirmed
link (existing `_spawn_synergy_border`) stays at full intensity. Extract `_position_strip_on_edge` from the
existing inline geometry in `_spawn_synergy_border` (`GridPrepScene.gd:868-889`) so both the confirmed path
and this new preview path share one geometry function instead of two copies of the same match-statement.

Also clear preview strips whenever a real drop resolves (`_on_card_drag_ended`, top of function, alongside
the existing `_clear_drop_highlight()` call at `GridPrepScene.gd:554`) so a preview never lingers after the
card leaves drag state.

## 2. Placed-synergy pulse

`ItemCard.gd` gains one new method, matching the existing pulse idiom already used by `play_pop`/
`play_snap_bounce` (elastic overshoot, `_kill_scale_tween` guard first):

```gdscript
# ItemCard.gd
@export var synergy_pulse_duration: float = 0.20

func play_synergy_pulse() -> void:
    _kill_scale_tween()
    scale = Vector2.ONE
    _scale_tween = create_tween()
    _scale_tween.tween_property(self, "scale", Vector2(1.08, 1.08), synergy_pulse_duration / 2.0) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    _scale_tween.tween_property(self, "scale", Vector2.ONE, synergy_pulse_duration / 2.0) \
        .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
```

`GridPrepScene._on_validate_grid_completed` (`GridPrepScene.gd:820-841`) gains one line inside the existing
`fresh` loop (currently only scheduling the audio chime):

```gdscript
for i in fresh.size():
    var pitch := 1.0 + float(fresh[i].get("modifier_pct", 0.2))
    get_tree().create_timer(i * synergy_chime_stagger).timeout.connect(
        AudioManager.play_synergy_link.bind(pitch))
    _pulse_synergy_pair(fresh[i])  # new

func _pulse_synergy_pair(synergy: Dictionary) -> void:
    var source_card: ItemCard = _cards_by_item_id.get(synergy.get("source_item_id", ""))
    var target_card: ItemCard = _cards_by_item_id.get(synergy.get("target_item_id", ""))
    if source_card != null:
        source_card.play_synergy_pulse()
    if target_card != null:
        target_card.play_synergy_pulse()
```

## 3. Auto-arrange

Refactor `_place_card` (`GridPrepScene.gd:703-720`) to split off its container-agnostic tail:

```gdscript
func _place_card(card: ItemCard, cell: GridCell) -> void:
    _drag_layer.remove_child(card)
    _finish_placement(card, cell, true)

func _finish_placement(card: ItemCard, cell: GridCell, notify_server: bool) -> void:
    var item: Dictionary = card.get("_item_data")
    cell.add_child(card)
    var footprint := GameState.item_footprint(item)
    _apply_footprint_visual(card, footprint)
    _claim_footprint(cell.grid_x, cell.grid_y, item.get("item_id", ""), footprint)
    _move_item_to_equipped(item, cell.grid_x, cell.grid_y)
    _cards_by_item_id[item.get("item_id", "")] = card
    card.play_snap_bounce()
    _spawn_snap_particles(cell, footprint)
    AudioManager.play_grid_snap()
    if notify_server:
        _status_label.text = "placed %s at (%d, %d)" % [item.get("name", "?"), cell.grid_x, cell.grid_y]
        _refresh_start_button()
        ApiClient.validate_grid(GameState.to_grid_payload())
```

New button + handler:

```gdscript
@onready var _auto_arrange_button: Button = null  # created in _ready, positioned in _layout_screen

func _on_auto_arrange_pressed() -> void:
    var bench_snapshot: Array[Dictionary] = GameState.bench_items.duplicate()
    for item in bench_snapshot:
        var footprint := GameState.item_footprint(item)
        var best_cell: GridCell = null
        var best_score := -1.0
        for cell in _cells:
            if not _footprint_fits(cell.grid_x, cell.grid_y, item):
                continue
            var score := _score_cell_for_item(cell, footprint, item)
            if score > best_score:
                best_score = score
                best_cell = cell
        if best_cell == null:
            continue  # grid genuinely full; item stays on bench
        var card: ItemCard = _cards_by_item_id.get(item.get("item_id", ""))
        if card == null:
            continue
        _bench_row.remove_child(card)
        _finish_placement(card, best_cell, false)
    _render_bench()
    _refresh_start_button()
    ApiClient.validate_grid(GameState.to_grid_payload())  # one call for the whole batch

func _score_cell_for_item(anchor: GridCell, footprint: Vector2i, item: Dictionary) -> float:
    var score := 0.0
    for pair: Dictionary in _neighbors_of(anchor, footprint):
        var neighbor_card := pair.cell.get_card()
        if neighbor_card == null:
            continue
        score += _synergy_match(item, neighbor_card.get("_item_data"), pair.direction)
    return score
```

**Required companion fix**: `_cards_by_item_id` currently only gets populated for *equipped* cards
(`_render_initial_state`, `_place_card`, `_unplace_card`) - confirmed by reading `_spawn_card`
(`GridPrepScene.gd:345-351`, the shared instantiate-and-wire helper called from both `_render_bench` and
`_render_initial_state`): it wires the `drag_started`/`drag_ended` signals but never touches
`_cards_by_item_id`. Bench cards are therefore invisible to that map today. Add the registration directly
in `_spawn_card` (one line, `_cards_by_item_id[item.get("item_id", "")] = card`, right before its
`return card`) so every card - bench or grid - is always in the map from the moment it's spawned. This
also makes the existing separate registration calls in `_place_card`/`_render_initial_state` redundant but
harmless (same key, same card) - leave them as-is rather than removing them in this PR, to keep this
change a pure addition. Without this fix, `_on_auto_arrange_pressed`'s `_cards_by_item_id.get(...)` lookup
returns `null` for every bench item and the button silently does nothing.

Button creation (in `_ready()`, near the existing `_start_match_button.pressed.connect`):

```gdscript
_auto_arrange_button = Button.new()
_auto_arrange_button.text = "AUTO"
_auto_arrange_button.pressed.connect(_on_auto_arrange_pressed)
add_child(_auto_arrange_button)
```

Layout (`_layout_screen()`, replacing the single full-width `_start_match_button` rect at
`GridPrepScene.gd:182-184` with a split row - AUTO takes a fixed left column, START MATCH takes the rest):

```gdscript
var start_top := recycler_top + recycler_height + section_gap
var auto_width := 140.0
_auto_arrange_button.position = Vector2(40.0, start_top)
_auto_arrange_button.size = Vector2(auto_width, start_button_height)
_start_match_button.position = Vector2(40.0 + auto_width + 16.0, start_top)
_start_match_button.size = Vector2(size.x - 80.0 - auto_width - 16.0, start_button_height)
```

## 4. Merge flash

Replace the heuristic block in `_on_purchase_item_completed` (`GridPrepScene.gd:423-451`):

```gdscript
func _on_purchase_item_completed(data: Dictionary) -> void:
    _purchase_in_flight = false
    GameState.gold = int(data.get("new_balance", GameState.gold))
    var bench: Array = data.get("updated_grid", {}).get("bench_reserve", [])
    var merges: Array = data.get("merges", [])

    GameState.sync_bench_from_server(bench)
    GameState.sync_grid_dimensions(data.get("updated_grid", {}))
    _maybe_rebuild_grid_from_state()
    _render_bench()
    _stats_hud.refresh()
    _update_affordability()

    if not merges.is_empty():
        for i in merges.size():
            var produced: Dictionary = merges[i].get("produced_item", {})
            get_tree().create_timer(i * merge_flash_stagger).timeout.connect(
                _celebrate_merge.bind(produced))
    else:
        AudioManager.play_grid_snap()
        _status_label.text = "REQUISITIONED"
    AudioManager.play_coin_spend()

func _celebrate_merge(merged_item: Dictionary) -> void:
    AudioManager.play_triple_merge()
    _status_label.text = "TRIPLE-MERGE - LV%d %s" % [int(merged_item.get("level", 2)),
        String(merged_item.get("name", "?")).to_upper()]
    var tier_color := SynGridPalette.tint_for_tier(int(merged_item.get("level", 2)))
    for card: ItemCard in _bench_row.get_children():
        if card.get("_item_data").get("item_id", "") == merged_item.get("item_id", ""):
            var pos := card.get_global_rect().get_center()
            _spawn_merge_burst(pos, tier_color)
            _spawn_tier_ring(pos, tier_color)
            return
```

New `@export var merge_flash_stagger: float = 0.35` (matches the ~1s particle lifetime the source spec
calls for per merge, so cascaded merges read as distinct events, not one blob).

`_spawn_merge_burst` (`GridPrepScene.gd:778-786`) gains a `tint: Color` parameter, replacing its hardcoded
`SynGridPalette.ACCENT_PURPLE` with the passed-in tier color (keep `ACCENT_TEAL` as the fade-to color -
only the "from" color needs to vary by tier).

New tiny component for the ring half of "particle burst + tier ring" (§10.3's two explicitly distinct
visual elements - the particle burst alone already existed; the ring is new):

```gdscript
# scripts/ui/TierRing.gd
class_name TierRing
extends Control
# One-shot expanding ring outline, tier-colored. Self-frees on completion.

@export var start_radius: float = 20.0
@export var end_radius: float = 70.0
@export var duration: float = 0.5
@export var ring_width: float = 4.0

var _color: Color = Color.WHITE
var _radius: float

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func play(color: Color) -> void:
    _color = color
    _radius = start_radius
    var tw := create_tween().set_parallel(true)
    tw.tween_method(_set_radius, start_radius, end_radius, duration) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    tw.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(queue_free)

func _set_radius(r: float) -> void:
    _radius = r
    queue_redraw()

func _draw() -> void:
    draw_arc(Vector2.ZERO, _radius, 0, TAU, 48, _color, ring_width, true)
```

```gdscript
# GridPrepScene.gd
func _spawn_tier_ring(pos: Vector2, tint: Color) -> void:
    var ring := TierRing.new()
    _drag_layer.add_child(ring)
    ring.global_position = pos
    ring.play(tint)
```

## `_neighbors_of` (shared by sections 1 and 3)

```gdscript
func _neighbors_of(anchor: GridCell, footprint: Vector2i) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for dx in footprint.x:
        var north := _cell_at(anchor.grid_x + dx, anchor.grid_y - 1)
        if north != null:
            result.append({cell = north, direction = "NORTH"})
        var south := _cell_at(anchor.grid_x + dx, anchor.grid_y + footprint.y)
        if south != null:
            result.append({cell = south, direction = "SOUTH"})
    for dy in footprint.y:
        var west := _cell_at(anchor.grid_x - 1, anchor.grid_y + dy)
        if west != null:
            result.append({cell = west, direction = "WEST"})
        var east := _cell_at(anchor.grid_x + footprint.x, anchor.grid_y + dy)
        if east != null:
            result.append({cell = east, direction = "EAST"})
    return result
```

## Verification (mandatory before requesting review)

1. `godot --headless --path . --import` - clean.
2. `SYNGRID_SCREENSHOT=/tmp/gridprep.png godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn` -
   confirm the AUTO button renders beside START MATCH with no overlap, and (per issue #32's acceptance
   criterion) that a mid-drag frame shows preview links.
3. Update the offline harness fixture to include at least one placed item pair with matching receptors so
   a dragged third item produces a visible preview link in the screenshot, and to include a `merges` array
   (even if empty) on the fixture's purchase response, per the HLD's regression note.
4. Confirm a purchase response with an empty `merges` array shows zero flashes (fixes the old heuristic's
   false-negative/false-positive surface - this is the regression case the HLD calls out explicitly).
5. Confirm a purchase response with two `merges` entries plays two staggered flashes, each with the
   correct tier-colored ring, not simultaneous or blended.
6. Press AUTO on a bench of 4+ items with at least one synergy-eligible pair; confirm they land adjacent
   and a single `ValidateGrid` call fires (check the network log / mock call count in the harness), not one
   per item.
7. Confirm the synergy-pulse scale animation never exceeds 1.08x and always returns to exactly 1.0 (no
   residual scale drift if a card is picked up again immediately after pulsing).
8. `SYNGRID_LIVE=1` run against a live `../sync-grid` server once available, to confirm real `merges`/
   `synergy_receptors` payloads drive the same code paths correctly (not just the offline fixture).

## Out of scope

- §2.5 sell-price preview text - blocked on `sync-grid#77`, tracked as a fast-follow, not part of this PR.
- §2.2 best-slot hint and §2.4 comparison tooltip - explicitly deferred to the onboarding/hints issue (#33)
  per the epic's own "Deferred out of this issue" note on #32.
- No change to `ValidateGrid`'s call cadence outside of the auto-arrange batching described above - manual
  drag-drop placement still calls it once per drop, unchanged.
- No `.tscn` edits - see the "new nodes are code-created" convention above.
