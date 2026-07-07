# LLD: E2 Combat Readability Telemetry Overlays

Status: Approved 2026-07-07.
Owner: Claude Code (Lead Architect).
Governs: GitHub issue #29 (E2, Client Experience Roadmap epic #42).
Source spec: `docs/game_ideas.md` §4.1, `docs/improvements.md` §1.3.
HLD: `docs/high-level-design/issue-29-combat-readability-telemetry.md` - read that first for the
data-shape decisions (why banners show absolute damage not a percentage, why icons are category-based
not physical/magical).

## Convention: new nodes are code-created, not `.tscn`-edited

Follows the existing `_hit_counter_footer` precedent (`CombatReplayScene.gd:89-103`, added in `_ready()`
specifically "to keep this feature to a single script commit"). Every new node below (damage meters,
synergy banner stack, threat pill, log ticker, HP segment dividers) is created in code, not added to
`CombatReplayScene.tscn`. Do not edit the `.tscn`.

## Shared data model

```gdscript
# CombatReplayScene.gd - new member, alongside _cards_by_item_id etc.
var _cumulative_damage_by_item_id: Dictionary = {}  # item_id -> float

# Called once per event, before any per-feature update below.
func _accumulate_damage(ev: Dictionary) -> void:
    var firing_id := String(ev.get("firing_item_id", ""))
    if firing_id == "":
        return
    var dmg := float(ev.get("actual_damage", 0.0))
    _cumulative_damage_by_item_id[firing_id] = \
        float(_cumulative_damage_by_item_id.get(firing_id, 0.0)) + dmg
```

Call `_accumulate_damage(ev)` first thing inside `_on_event_played`, before the existing FX calls. Both
the damage meter and threat pill read this same dictionary - do not add a second tally.

## 1. Per-item damage meter

New file `scripts/ui/DamageMeter.gd`:

```gdscript
class_name DamageMeter
extends Control
# Thin contribution bar attached under a mini ItemCard in combat replay.
# Fill fraction is set externally (own_damage / current_match_max) - this
# component does no computation of its own, matching HpBar's "never computes
# damage" convention.

@export var fill_tween_duration: float = 0.10
@export var bar_height: float = 6.0

var _bg: ColorRect
var _fill: ColorRect

func _ready() -> void:
    _bg = ColorRect.new()
    _bg.color = SynGridPalette.PANEL_BG_ELEVATED
    _bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_bg)
    _fill = ColorRect.new()
    _fill.color = SynGridPalette.ACCENT_TEAL
    _fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_fill)
    resized.connect(_relayout)
    _relayout()

func _relayout() -> void:
    _bg.position = Vector2.ZERO
    _bg.size = Vector2(size.x, bar_height)
    _fill.position = Vector2.ZERO
    _fill.size.y = bar_height

func set_fraction(frac: float) -> void:
    var target_w := clampf(frac, 0.0, 1.0) * size.x
    var tw := create_tween()
    tw.tween_property(_fill, "size:x", target_w, fill_tween_duration) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
```

`CombatReplayScene.gd` changes:

```gdscript
var _meters_by_item_id: Dictionary = {}  # item_id -> DamageMeter

# In _build_side, right after `card.set_item_data(item)`:
var meter := DamageMeter.new()
meter.custom_minimum_size = Vector2(mini_cell_card_size.x, 6.0)
meter.position = Vector2(0.0, mini_cell_card_size.y - 6.0)  # thin strip along the card's bottom edge
card.add_child(meter)
_meters_by_item_id[item_id] = meter
```

Update, called from `_on_event_played` right after `_accumulate_damage`:

```gdscript
func _refresh_damage_meters() -> void:
    var current_max := 0.0
    for v in _cumulative_damage_by_item_id.values():
        current_max = maxf(current_max, float(v))
    if current_max <= 0.0:
        return
    for item_id in _meters_by_item_id:
        var dmg := float(_cumulative_damage_by_item_id.get(item_id, 0.0))
        _meters_by_item_id[item_id].set_fraction(dmg / current_max)
```

## 2. Synergy activation banners

```gdscript
# CombatReplayScene.gd
var _synergy_announced_item_ids: Dictionary = {}  # item_id -> true
@onready var _synergy_stack: VBoxContainer = null  # created in _ready, see below

# In _ready(), after _hit_counter_footer setup:
_synergy_stack = VBoxContainer.new()
_synergy_stack.add_theme_constant_override("separation", 6)
_synergy_stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
_synergy_stack.position = Vector2(size.x - 180.0, 140.0)
_synergy_stack.size = Vector2(170.0, 300.0)
_synergy_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
add_child(_synergy_stack)
```

Trigger, called from `_on_event_played` after `_accumulate_damage`:

```gdscript
func _maybe_announce_synergy(ev: Dictionary) -> void:
    var firing_id := String(ev.get("firing_item_id", ""))
    var bonus := float(ev.get("synergy_bonus", 0.0))
    if bonus <= 0.0 or _synergy_announced_item_ids.has(firing_id):
        return
    _synergy_announced_item_ids[firing_id] = true
    var item: Dictionary = _items_by_id.get(firing_id, {})
    var category := String(item.get("weapon_category", ""))
    _spawn_synergy_banner(category, bonus)

func _spawn_synergy_banner(category: String, bonus: float) -> void:
    var chip := PanelContainer.new()
    chip.add_theme_stylebox_override("panel",
        ThemeBuilder.build_panel_style(SynGridPalette.tint_for_weapon_category(category),
            SynGridPalette.PANEL_BG_ELEVATED))
    var label := Label.new()
    label.text = "%s SYNERGY +%d DMG" % [category if category != "" else "ITEM", int(round(bonus))]
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", SynGridPalette.tint_for_weapon_category(category))
    chip.add_child(label)
    _synergy_stack.add_child(chip)
    chip.modulate.a = 0.0
    chip.position.x = 60.0  # slides in from further right
    var tw := chip.create_tween().set_parallel(true)
    tw.tween_property(chip, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(chip, "position:x", 0.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    var out_tw := chip.create_tween()
    out_tw.tween_interval(2.0)
    out_tw.tween_property(chip, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD)
    out_tw.tween_callback(chip.queue_free)
```

Uses `ThemeBuilder.build_panel_style` (existing helper, already opaque per `PANEL_BG_ELEVATED` - satisfies
critical rule 6, no glass behind the live damage number) rather than a hand-rolled `StyleBoxFlat`.

## 3. Damage-type icons on floats

`_spawn_damage_float` (`CombatReplayScene.gd:362-402`) gains a prefix glyph. Add a `firing_id` parameter
(the call site already has it) and prepend a small colored glyph label before the existing damage text:

```gdscript
func _spawn_damage_float(pos: Vector2, hp_loss: float, shield_absorbed: float, crit: bool,
        firing_category: String) -> void:
    # ... existing label construction unchanged, then before setting label.text:
    var prefix := ""
    if hp_loss > 0.0:
        match firing_category:
            "MELEE": prefix = "⚔ "
            "RANGED": prefix = "➵ "
            "ARCANE": prefix = "✦ "
            _: prefix = ""
    elif shield_absorbed > 0.0:
        prefix = "🛡 "
    # existing: label.text = str(int(round(hp_loss))) etc. - prepend prefix to that text.
```

Call site update (`_on_event_played`, where `_spawn_damage_float` is currently called): pass
`String(_items_by_id.get(firing_id, {}).get("weapon_category", ""))` as the new argument. Glyph color
already matches the existing label color rule (crit=DANGER, normal=TEXT_PRIMARY, blocked=ACCENT_TEAL) -
do not add a second color path for the glyph, it's part of the same `label.text` and inherits
`label`'s existing `font_color` override.

**Font coverage check required**: the glyphs above (`⚔ ➵ ✦ 🛡`) are illustrative, not mandated - the
project's active theme font may not cover these codepoints and render as tofu boxes. Verify against the
actual font in `ThemeBuilder.get_theme()` before committing to specific glyphs; fall back to simple ASCII
markers (e.g. `[M]`/`[R]`/`[A]`/`[S]`) if coverage is missing, rather than shipping an unreadable prefix.

## 4. Threat meter (enemy top-3)

```gdscript
# CombatReplayScene.gd
var _threat_pill: PanelContainer = null
var _threat_label: Label = null
var _threat_last_rendered: Array = []  # cached top-3 item_ids, to skip no-op re-renders

# In _ready(), after _opp_bar is laid out:
_threat_pill = PanelContainer.new()
_threat_pill.add_theme_stylebox_override("panel",
    ThemeBuilder.build_panel_style(SynGridPalette.DANGER, SynGridPalette.PANEL_BG_ELEVATED))
_threat_label = Label.new()
_threat_label.add_theme_font_size_override("font_size", 13)
_threat_label.add_theme_color_override("font_color", SynGridPalette.TEXT_PRIMARY)
_threat_pill.add_child(_threat_label)
_threat_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
add_child(_threat_pill)
```

Positioned in `_layout_screen()` alongside the other opponent-side rects, in the existing gap between
`_opp_bar` (ends at `116.0 + 52.0 = 168.0`) and `_opp_grid_area` (starts at `196.0`) - a 28px gap, enough
for a single-line pill:

```gdscript
_threat_pill.position = Vector2(center_x, 170.0)
_threat_pill.size = Vector2(grid_total.x, 24.0)
```

Update, called from `_on_event_played` after `_accumulate_damage`, only when the firing item is on the
opponent's side:

```gdscript
func _refresh_threat_meter(firing_id: String) -> void:
    if String(_side_by_item_id.get(firing_id, "")) != "opponent":
        return
    var ranked: Array = []
    for item_id in _cumulative_damage_by_item_id:
        if String(_side_by_item_id.get(item_id, "")) == "opponent":
            ranked.append(item_id)
    ranked.sort_custom(func(a, b):
        return _cumulative_damage_by_item_id[a] > _cumulative_damage_by_item_id[b])
    var top3: Array = ranked.slice(0, 3)
    if top3 == _threat_last_rendered:
        return
    _threat_last_rendered = top3
    var parts: Array[String] = []
    for i in top3.size():
        var item_id: String = top3[i]
        var name := String(_items_by_id.get(item_id, {}).get("name", "?"))
        parts.append("%d. %s %d" % [i + 1, name, int(_cumulative_damage_by_item_id[item_id])])
    _threat_label.text = "  ".join(parts)
```

## 5. HP bar segments

`HpBar.gd` additions:

```gdscript
@export var segment_count: int = 10  # COMBAT_MAX_HP / 100.0 at the 1000 baseline
var _segment_dividers: Array = []  # Array[ColorRect]

# In _ready(), after _hp_fill is added and before _text:
for i in segment_count - 1:
    var divider := ColorRect.new()
    divider.color = Color(SynGridPalette.PANEL_BG, 0.8)
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(divider)
    _segment_dividers.append(divider)
```

`_relayout()` gains, after the existing `_hp_fill`/`_shield_fill`/`_text` positioning:

```gdscript
var hp_height := size.y - shield_strip_height
for i in _segment_dividers.size():
    var x := size.x * float(i + 1) / float(segment_count)
    var divider: ColorRect = _segment_dividers[i]
    divider.position = Vector2(x - 1.0, 0.0)
    divider.size = Vector2(2.0, hp_height)
```

Dividers are static overlay lines - never touched by `_apply()`'s fill-width tween, so segment rendering
cannot desync from or fight the existing HP-fill animation.

## 6. Combat log ticker

```gdscript
# CombatReplayScene.gd
var _log_ticker: VBoxContainer = null
const _LOG_TICKER_MAX_LINES: int = 4

# In _ready(), in the reserved gap around _vs_label:
_log_ticker = VBoxContainer.new()
_log_ticker.add_theme_constant_override("separation", 2)
_log_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
add_child(_log_ticker)
# Positioned in _layout_screen(), replacing/alongside _vs_label's existing rect:
_log_ticker.position = Vector2(40.0, size.y * 0.465)
_log_ticker.size = Vector2(size.x - 80.0, 60.0)
```

Line format and push, called from `_on_event_played`:

```gdscript
func _push_log_line(ev: Dictionary, firing_id: String) -> void:
    var item_name := String(_items_by_id.get(firing_id, {}).get("name", "?"))
    var hp_loss := float(ev.get("hp_loss", 0.0))
    var shield_absorbed := float(ev.get("shield_absorbed", 0.0))
    var crit: bool = ev.get("crit", false)
    var text: String
    if hp_loss > 0.0:
        text = "%s %s for %d" % [item_name, "crit" if crit else "hits", int(round(hp_loss))]
    elif shield_absorbed > 0.0:
        text = "%s blocked" % item_name
    else:
        return
    var line := Label.new()
    line.text = text
    line.add_theme_font_size_override("font_size", 14)
    line.add_theme_color_override("font_color",
        SynGridPalette.DANGER if crit else SynGridPalette.TEXT_DIM)
    _log_ticker.add_child(line)
    line.modulate.a = 0.0
    var tw := line.create_tween()
    tw.tween_property(line, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    if _log_ticker.get_child_count() > _LOG_TICKER_MAX_LINES:
        var oldest: Label = _log_ticker.get_child(0)
        var out_tw := oldest.create_tween()
        out_tw.tween_property(oldest, "modulate:a", 0.0, 0.15)
        out_tw.tween_callback(oldest.queue_free)
```

Note: `_vs_label` still shows briefly at fight start via `_play_intro_banner`'s full-viewport banner: leave
`_vs_label` itself as-is (unrelated existing node) - the ticker occupies the same *vertical band*, not the
same node; confirm via harness screenshot that the two don't visually collide once the intro banner fades
(the intro banner is a separate full-viewport overlay that self-frees after ~0.85s, well before the log
ticker would have accumulated enough lines to be visually busy).

## `_on_event_played` call-site summary

All new calls, in order, added near the top of the existing function body (`CombatReplayScene.gd:236`),
before the existing FX calls so telemetry never lags a frame behind the visual read:

```gdscript
func _on_event_played(ev: Dictionary) -> void:
    # ... existing tick_label / round_timer_progress lines unchanged ...
    var firing_id := String(ev.get("firing_item_id", ""))
    _accumulate_damage(ev)
    _refresh_damage_meters()
    _maybe_announce_synergy(ev)
    _refresh_threat_meter(firing_id)
    _push_log_line(ev, firing_id)
    # ... existing lunge / SFX / bar-update / float / shake logic unchanged ...
    # existing _spawn_damage_float call site gains one new argument (see section 3)
```

## Verification (mandatory before requesting review)

1. `godot --headless --path . --import` - clean.
2. `SYNGRID_SCREENSHOT=/tmp/combat.png godot --path . --resolution 540x960 scenes/combat_replay/CombatReplayPreviewHarness.tscn` - confirm, per issue #29's acceptance criterion, that damage meters, the log ticker, and the threat pill are all visible simultaneously with no overlap.
3. Confirm the MVP item's damage meter reads visually full (fraction 1.0) at fight end, and no meter ever shrinks mid-fight (spot-check a few mid-fight frames if the harness supports frame stepping).
4. Confirm a build with at least one active synergy shows exactly one banner per synergized item, not one per hit.
5. Confirm HP segment dividers stay static (never animate) through a `set_state` HP-fill tween.
6. Confirm no glass panel sits behind any new live number (damage meter fill, synergy bonus number, threat meter numbers, log ticker damage numbers) - all must use `ThemeBuilder.build_panel_style` / `PANEL_BG_ELEVATED` opaque backings, per critical rule 6.
7. `SYNGRID_LIVE=1` run against a live `../sync-grid` server once available, to confirm real (non-fixture) `synergy_bonus`/`actual_damage` values render sensibly (no `NaN`/negative fills if a real fight has zero-damage ticks).

## Out of scope

- No new autoload, no new signal beyond what `CombatLogPlayer.event_played` already provides.
- No percentage-based synergy display and no physical/magical icon split - see the HLD's data-shape section for why, and revisit both once server G2 (#28) / G5 (#31) land.
- No change to `CombatLogPlayer.gd` itself - every addition here is scene-side, consuming the existing `event_played` signal.
- No `.tscn` edits - see the "new nodes are code-created" convention above.
