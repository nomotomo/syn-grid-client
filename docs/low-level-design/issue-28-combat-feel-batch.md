# LLD: Combat Feel Batch (Item Shake, Death Shatter, Crit Zoom, Slow-Mo Killing Blow)

Status: Approved 2026-07-07.
Owner: Claude Code (Lead Architect).
Governs: GitHub issue #28 (E1, Client Experience Roadmap epic #42).
Source spec: `docs/improvements.md` §1.1, §1.2, §1.4, §1.6.
Depends on: `docs/juice_manual.md` sections 2 and 4, `docs/api_contract.md` (`combat_log.events[]` shape).

## Why this doc exists

Issue #28 bundles four independent juice additions to combat replay. Each is small on its own, but two of them (shatter-on-death, crit zoom) have a technical detail the source issue/`improvements.md` gets subtly wrong or leaves ambiguous. This doc pins down the exact mechanism for all four so Cursor implements one specific thing per item rather than re-deriving intent from prose.

## Scope decision (architect call): shatter applies to the match-ending blow only

`docs/improvements.md` §1.4 says "when `target_item_id` receives a fatal hit, tween the card...". This assumes individual items on the grid have their own HP that can independently hit zero mid-combat. **That does not exist.** Per `docs/api_contract.md`'s `TickEvent` shape (`tick`, `firing_item_id`, `target_item_id`, `hp_loss`, `target_hp_after`, ...), `target_hp_after` is the **team-wide combat HP pool** (`COMBAT_MAX_HP = 1000.0`, `CombatReplayScene.gd:18`), not a per-item value - there is no field anywhere in the contract for an individual item's remaining HP. The existing `hp_loss > 0.0 and target_hp_after <= 0.0` check (`CombatReplayScene.gd:277`, `:292`) already means "this event ended the whole match," not "this specific item died" - it's the same condition that currently drives `_play_killing_blow_effect()` (the viewport-wide wash).

Decision: **shatter the card belonging to `target_item_id` on that same match-ending event**, synced with the existing killing-blow wash. This is an honest interpretation - the last item hit "shatters" as part of the finishing blow - without inventing client-side item-HP tracking (which would be client-computed game state, forbidden by this repo's "no game logic in the client" rule). No individual item can shatter mid-fight before the match ends, because the server does not expose the data needed to know that happened. If true per-item HP/death is wanted later, that requires a server change (new `TickEvent` field) - flag it to the user as a follow-up, don't build a client-side approximation now.

## Required fix 1: item hit shake + micro-flash (§1.2)

Per the issue's own file scope (`scenes/combat_replay/CombatReplayScene.gd` only - no `ItemCard.gd` change), this is scene-owned, matching the existing `_play_lunge` precedent (`CombatReplayScene.gd:295-307`) where the scene directly tweens a card's `position`, not the card itself. `ItemCard.gd`'s tween-ownership doc-comment ("the card owns every tween that animates itself") governs `scale`/`rotation` reactions the card exposes as methods (`play_pop`, `play_snap_bounce`) - it does not cover `position`, which `_play_lunge` already treats as scene-owned. Follow that same split here; do not add a new `ItemCard` method for this one.

Add a new private method, called from `_on_event_played` right after `_impact_position` resolves the target card:

```gdscript
@export var hit_shake_amplitude: float = 3.0
@export var hit_shake_duration: float = 0.05   # per direction; ~0.10s round trip

func _play_hit_reaction(target_card: ItemCard) -> void:
    if target_card == null:
        return
    var rest_x := target_card.position.x
    var shake := create_tween()
    shake.tween_property(target_card, "position:x", rest_x - hit_shake_amplitude, hit_shake_duration) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    shake.tween_property(target_card, "position:x", rest_x + hit_shake_amplitude, hit_shake_duration) \
        .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
    shake.tween_property(target_card, "position:x", rest_x, hit_shake_duration) \
        .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    var flash := create_tween()
    flash.tween_property(target_card, "modulate", Color(1.6, 1.6, 1.6, 1.0), hit_shake_duration * 0.4) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    flash.tween_property(target_card, "modulate", Color.WHITE, hit_shake_duration * 1.2) \
        .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
```

`Color(1.6, 1.6, 1.6, 1.0)` over-brightens past white (Godot 4 does not clamp `modulate`/`CanvasItem` color components to 1.0 at render time) - this is the "micro-flash," not a literal white cap. `ItemCard.gd` never touches its own `modulate` today (grep confirms), so there is no ownership conflict with `_apply_rest_style`/`_apply_drag_style`, which only touch the panel stylebox and `_tint_bg.color`.

Call site, in `_on_event_played` (`CombatReplayScene.gd:234-293`), right after `_impact_position` is computed:

```gdscript
var target_card: ItemCard = _cards_by_item_id.get(String(ev.get("target_item_id", "")))
_play_hit_reaction(target_card)
```

(`_impact_position` already does this same lookup internally at `:324` - do not duplicate the dictionary lookup logic, just resolve `target_card` once in `_on_event_played` and pass it to both `_impact_position` if refactored, or accept the one extra `_cards_by_item_id.get` call site as a pragmatic duplicate since `_impact_position` takes `ev` not a resolved card. Do not refactor `_impact_position`'s signature as part of this fix - out of scope.)

## Required fix 2: item shatter on death (§1.4, scoped per the decision above)

New `ItemCard.gd` method (matches the existing `play_pop`/`play_snap_bounce` ownership pattern - `scale`/`modulate.a` are already exclusively card-owned):

```gdscript
@export var shatter_duration: float = 0.35

func play_shatter() -> void:
    _kill_scale_tween()
    var tw := create_tween().set_parallel(true)
    tw.tween_property(self, "scale", Vector2(1.2, 0.4), shatter_duration) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    tw.tween_property(self, "modulate:a", 0.0, shatter_duration) \
        .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
```

`_kill_scale_tween()` prevents fighting with any in-flight hover/drag/pop tween on the same card - reuse the existing guard rather than adding a new one.

Particle burst: reuse the existing category-tint pattern already established by `_spawn_damage_sparks`/`_projectile_color` in `CombatReplayScene.gd` (post-#27, both now source color from `SynGridPalette.tint_for_weapon_category()`) - do not hardcode a new color here. Spawn the burst at `target_card.get_global_rect().get_center()` using the same `_spawn_damage_sparks`-style Control-based dot burst already in the file (do not add a second particle system implementation for this one case).

Call site in `_on_event_played`, in the existing match-ending branch (`CombatReplayScene.gd:292-293`):

```gdscript
if hp_loss > 0.0 and target_hp_after <= 0.0:
    var dying_card: ItemCard = _cards_by_item_id.get(String(ev.get("target_item_id", "")))
    if dying_card != null:
        dying_card.play_shatter()
    _play_killing_blow_effect()
```

## Required fix 3: camera zoom on crits (§1.6) - direction correction

`docs/improvements.md` §1.6 and issue #28 both say "nudge `_camera.zoom` from 1.0 -> 1.05 -> 1.0". **This is backwards.** In Godot 4, `Camera2D.zoom` is inverse to visual magnification - a zoom value of `(1.05, 1.05)` shows *more* of the scene at smaller scale (zooms **out**), while a value below 1.0 (e.g. `(0.95, 0.95)`) magnifies (zooms **in**). The intent ("frames the crit," a punch-in emphasis) requires zooming **in**, so the correct target value is `0.95`, not `1.05`. Do not implement the literal number from the issue - implement the correct visual effect it describes.

Add to `ScreenEffects.gd`, alongside the existing `_apply_crit_flash()` (`:63-67`), following the same frame-stepped pattern (a `Tween` would not animate during `hitstop()`'s `Engine.time_scale = 0.0` window, since `Tween` timing is scaled by `Engine.time_scale` same as everything else - `_apply_crit_flash` avoids this by using `await get_tree().process_frame`, which fires every rendered frame regardless of time scale):

```gdscript
@export var crit_zoom_scale: float = 0.95
@export var crit_zoom_return_duration: float = 0.12

func _apply_crit_zoom() -> void:
    if _camera == null:
        return
    _camera.zoom = Vector2(crit_zoom_scale, crit_zoom_scale)
    for _i in hitstop_frames:
        await get_tree().process_frame
    var tw := create_tween()
    tw.tween_property(_camera, "zoom", Vector2.ONE, crit_zoom_return_duration) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
```

Call it from `shake_from_hit()` (`ScreenEffects.gd:41-47`) alongside the existing crit branch:

```gdscript
if is_crit:
    intensity *= 2.5
    _apply_crit_flash()
    _apply_crit_zoom()
    hitstop()
```

The zoom-out tween (return to `Vector2.ONE`) runs after `hitstop_frames` real frames have passed, which lines up with (but does not need to strictly synchronize against) `hitstop()`'s own frame count - both use the same `hitstop_frames` export, so they resolve together. This is deliberately two independent frame-counted waits, not one shared await, because `hitstop()` also has to restore `Engine.time_scale` - keep them as separate functions, do not merge them into one to "avoid duplication"; they have different responsibilities (time-scale vs. camera zoom) that happen to share a duration constant.

## Required fix 4: slow-mo killing blow (§1.1)

`CombatLogPlayer.gd` needs two additions:

```gdscript
@export var slow_event_interval: float = 0.25

var _slow_next_pending: bool = false

func remaining_count() -> int:
    return _queue.size()

func slow_next_event() -> void:
    _slow_next_pending = true
```

And at the end of `_dequeue_next()` (`CombatLogPlayer.gd:39-59`), after the existing crit/elif cadence logic, add the override:

```gdscript
func _dequeue_next() -> void:
    if _queue.is_empty():
        _timer.stop()
        playback_finished.emit(
            _combat_log.get("winner_id", ""),
            _combat_log.get("attacker_hp_final", 0.0),
            _combat_log.get("defender_hp_final", 0.0)
        )
        return
    var ev: Dictionary = _queue.pop_front()
    event_played.emit(ev)
    if ev.get("crit", false):
        _timer.stop()
        for _i in hitstop_frames:
            await get_tree().process_frame
        _timer.start(tick_interval * crit_tick_multiplier)
    elif not is_equal_approx(_timer.wait_time, tick_interval):
        _timer.start(tick_interval)
    if _slow_next_pending:
        _timer.start(slow_event_interval)
        _slow_next_pending = false
```

The `_slow_next_pending` check runs last and unconditionally restarts the timer at `slow_event_interval` (0.25s), overriding whatever the crit/elif branch just set - this is intentional, not a bug: the final blow's pause should win over an ordinary crit gap (0.25s > the crit branch's 0.20s anyway), and it's fine if the very last event also happens to be a crit - the two effects (zoom, flash, hitstop) all still fire independently from `shake_from_hit`, only the *pre-fire pause* is governed by this override.

Call site in `CombatReplayScene.gd`'s `_on_event_played` (`:234-236`, before any other logic, so it fires the same frame the penultimate event dequeues):

```gdscript
func _on_event_played(ev: Dictionary) -> void:
    if _log_player.remaining_count() == 1:
        _log_player.slow_next_event()
    _tick_label.text = ...
```

Because `_dequeue_next()` does `_queue.pop_front()` *before* `event_played.emit(ev)`, `remaining_count() == 1` inside the signal handler correctly means "exactly one event is left after this one" - i.e., the event about to be played next is the last one. Since GDScript signals fire synchronously, calling `slow_next_event()` here sets `_slow_next_pending` before `_dequeue_next()` reaches its own tail check, so the override applies to the very next tick as intended.

## Verification (mandatory before requesting review)

1. `godot --headless --path . --import` - clean.
2. `SYNGRID_SCREENSHOT=/tmp/combat.png godot --path . --resolution 540x960 scenes/combat_replay/CombatReplayPreviewHarness.tscn` - confirm:
   - A hit target card visibly shakes and brightens without permanently altering its rest position/color afterward.
   - The match-ending event's `target_item_id` card visibly shrinks/flattens and fades - not every fatal-looking hit, only the actual final one.
   - Crits show a visible push-in (objects appear larger/closer), not a pull-back - if it looks like the camera pulled away on a crit, the zoom direction fix in fix 3 was not applied correctly.
3. Manually verify timing: log the tick interval actually used for the final event (temporary print, removed before commit) and confirm it is `0.25`, not `0.10`, and that this is true regardless of whether the final event is also a crit.
4. Confirm no regression in the non-crit, non-final steady-state cadence - `_timer.wait_time` should be exactly `tick_interval` for every ordinary event.
5. `SYNGRID_LIVE=1` run against a live `../sync-grid` server once available, to confirm the fix works against a real, non-fixture combat log (varying event counts, varying which event is actually last).

## Out of scope

- No per-item HP tracking or death detection mid-combat - the server does not expose per-item HP; do not approximate it client-side. If genuine per-item death is wanted, that is a server-schema change - flag it, do not build around the gap.
- No change to `_play_killing_blow_effect()` itself - the shatter call is additive, placed alongside it, not inside it.
- No merge of `ScreenEffects.hitstop()` and `_apply_crit_zoom()` into one function - see fix 3's note.
- §1.3 (combat log ticker) and §1.5 (rewind/step-through debug) are separate `improvements.md` items not included in issue #28 - do not implement them here.
