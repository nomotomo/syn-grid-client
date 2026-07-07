# LLD: E3 Audio Completion

Status: Approved 2026-07-07.
Owner: Claude Code (Lead Architect).
Governs: GitHub issue #30 (E3, Client Experience Roadmap epic #42), and #15 (BGM `AudioStreamWAV` leak).
Source spec: `docs/juice_manual.md` §5 (as amended 2026-07-07 with the five new matrix rows this issue adds).
HLD: `docs/high-level-design/issue-30-audio-completion.md` - read that first for the audit findings (why
most of the issue's original scope is already done, why `timer_tick_low` is dropped).

## 1. Crit BGM ducking (-6dB / 200ms)

`AudioManager.gd` additions:

```gdscript
@export var crit_duck_db: float = -6.0
@export var crit_duck_duration: float = 0.2

var _duck_tween: Tween = null

func _duck_bgm() -> void:
    var bus_idx := AudioServer.get_bus_index("BGM")
    var base_db := AudioServer.get_bus_volume_db(bus_idx)
    if _duck_tween != null and _duck_tween.is_valid():
        _duck_tween.kill()
    else:
        _bgm_base_db = base_db  # only capture on a fresh duck, not mid-duck
    AudioServer.set_bus_volume_db(bus_idx, _bgm_base_db + crit_duck_db)
    _duck_tween = create_tween()
    _duck_tween.tween_interval(crit_duck_duration)
    _duck_tween.tween_callback(func() -> void:
        AudioServer.set_bus_volume_db(bus_idx, _bgm_base_db))

var _bgm_base_db: float = 0.0
```

Call site, in `play_crit_hit`:

```gdscript
func play_crit_hit(pos: Vector2) -> void:
    _play_sfx_2d("crit_hit", pos)
    _duck_bgm()
```

The `_bgm_base_db` capture-only-on-fresh-duck guard matters: if two crits land within `crit_duck_duration`
of each other (possible - combat can tick at 5 events/s during crits per the juice contract's own crit
cadence), the second call must not capture the already-ducked volume as the new "base" - it would then
restore to the ducked level instead of the true pre-duck level, permanently lowering BGM for the rest of
the fight. Killing the in-flight tween and re-ducking from the same `_bgm_base_db` avoids that.

## 2. Fix issue #15 - BGM stream leak at exit

`AudioManager.gd`, in `_ready()`:

```gdscript
func _ready() -> void:
    _ensure_bus("BGM")
    _ensure_bus("SFX")
    _bgm_a = AudioStreamPlayer.new()
    _bgm_b = AudioStreamPlayer.new()
    _bgm_a.bus = "BGM"
    _bgm_b.bus = "BGM"
    add_child(_bgm_a)
    add_child(_bgm_b)
    _active_bgm = _bgm_a
    set_process(false)
    get_tree().tree_exiting.connect(_release_bgm_streams)

func _release_bgm_streams() -> void:
    _kill_bgm_tween()
    _bgm_a.stop()
    _bgm_a.stream = null
    _bgm_b.stop()
    _bgm_b.stream = null
```

This targets exactly what issue #15 reproduces: a playing `AudioStreamPlayer.stream` (`bgm_prep.wav`,
`AudioStreamWAV`) holds a live reference past `get_tree().quit()`. Stopping playback and nulling `.stream`
on both players before the tree tears down releases that reference. Verify with the exact repro from #15
(`godot --path . --resolution 540x960 --verbose scenes/main_menu/MainMenuPreviewHarness.tscn`) - the
"Leaked instance"/"Resource still in use" warnings must be gone from the exit log.

## 3. New SFX events

### `AudioManager.gd` additions

```gdscript
const SFX_PATHS: Dictionary = {
    # ... existing 14 entries unchanged ...
    "coin_earn":        "res://assets/audio/sfx/sfx_coin_earn.wav",
    "coin_spend":        "res://assets/audio/sfx/sfx_coin_spend.wav",
    "triumph_earn":      "res://assets/audio/sfx/sfx_triumph_earn.wav",
    "defeat_stinger":    "res://assets/audio/sfx/sfx_defeat_stinger.wav",
    "victory_fanfare":   "res://assets/audio/sfx/sfx_victory_fanfare.wav",
}

func play_coin_earn() -> void:       _play_sfx("coin_earn")
func play_coin_spend() -> void:      _play_sfx("coin_spend")
func play_triumph_earn() -> void:    _play_sfx("triumph_earn")
func play_defeat_stinger() -> void:  _play_sfx("defeat_stinger")
func play_victory_fanfare() -> void: _play_sfx("victory_fanfare")
```

One method per event, matching the existing "one method per juice_manual.md event" convention exactly -
do not add a generic `play_by_key(String)` shortcut, it would break the pattern every other call site in
this file already follows.

### Call sites

`scenes/grid_prep/GridPrepScene.gd`:

```gdscript
# _on_award_round_gold_completed (:363-368), after the existing GameState.gold assignment:
func _on_award_round_gold_completed(data: Dictionary) -> void:
    GameState.gold_awarded_round = GameState.current_round
    GameState.gold = int(data.get("new_balance", GameState.gold))
    AudioManager.play_coin_earn()
    _stats_hud.refresh()
    _update_affordability()
    _status_label.text = "ROUND GRANT +%dG" % int(data.get("gold_awarded", 0))
```

```gdscript
# _on_purchase_item_completed (:422-447), alongside the existing grid_snap/triple_merge branch:
if not merged_item.is_empty():
    AudioManager.play_triple_merge()
    _celebrate_merge(merged_item)
else:
    AudioManager.play_grid_snap()
    _status_label.text = "REQUISITIONED"
AudioManager.play_coin_spend()
```

(`play_coin_spend()` fires unconditionally after the existing merge/no-merge branch, since gold is spent
either way - do not put it inside either branch.)

```gdscript
# _on_sell_item_completed (:604-612), using the already-computed `credited` delta:
func _on_sell_item_completed(data: Dictionary) -> void:
    var credited := int(data.get("new_balance", GameState.gold)) - GameState.gold
    GameState.gold = int(data.get("new_balance", GameState.gold))
    if credited > 0:
        AudioManager.play_coin_earn()
    # ... rest unchanged ...
```

(Guard on `credited > 0` even though a sell should always credit something - defensive against a
zero-value edge case, not because a negative/zero sell is expected.)

`scenes/round_end/RoundEndScene.gd`, inside `_animate_orbs` (:177-203):

```gdscript
func _animate_orbs() -> void:
    # ... existing setup unchanged ...
    if _is_victory:
        AudioManager.play_victory_fanfare()   # replaces the old play_triumph_milestone() call here
        for i in _orb_holders.size():
            await get_tree().create_timer(orb_stagger).timeout
            _pop_holder(_orb_holders[i], 0.0)
        return
    for i in triumph:
        var is_newest := _won and i == triumph - 1
        if is_newest:
            AudioManager.play_triumph_earn()
            _pop_holder(_orb_holders[i], 0.0, true)
            _spawn_burst(_orb_holders[i].global_position + Vector2(orb_size, orb_size) * 0.5,
                SynGridPalette.ACCENT_TEAL)
        else:
            _pop_holder(_orb_holders[i], i * orb_stagger)
    if _gold_rewarded > 0:
        AudioManager.play_triumph_milestone()   # unchanged - stays the mid-run bonus-gold cue
        _status_label.text = "MILESTONE +%dG" % _gold_rewarded
```

`_is_victory`'s branch **replaces** `play_triumph_milestone()` with `play_victory_fanfare()` - do not play
both; see the HLD's trade-off note on why. The `is_newest` branch is new (`play_triumph_earn()`), and the
existing mid-run `_gold_rewarded > 0` branch keeps `play_triumph_milestone()` exactly as-is.

Inside `_animate_hearts` (:149-163), the `_is_eliminated` branch:

```gdscript
if _is_eliminated:
    AudioManager.play_fatal_hp_loss()
    AudioManager.play_defeat_stinger()
    for i in _heart_holders.size():
        await get_tree().create_timer(heart_stagger).timeout
        _shatter_heart(_heart_holders[i])
    return
```

`play_defeat_stinger()` is additive, right after the existing `play_fatal_hp_loss()` call - the ordinary
mid-run life-loss branch (the `elif not _won` path a few lines down, :164-173) is untouched and keeps only
`play_fatal_hp_loss()`, since a regular round loss with lives remaining is not "the run is over."

### Placeholder generator (`tools/generate_placeholder_audio.py`)

Five new functions following the existing style exactly (short numpy synthesis, `decay_env`/`osc`/`sweep`
helpers already defined in the file), added to `SFX_BUILDERS` alongside the existing 14:

```python
def sfx_coin_earn() -> np.ndarray:
    """Bright single coin-clink, very short."""
    out = np.zeros(samples(0.25))
    tone = (osc(1800.0, 0.12) + 0.4 * osc(3200.0, 0.08)) * decay_env(0.12, k=8, attack=0.002)
    place(out, tone, 0.0, gain=0.6)
    return out


def sfx_coin_spend() -> np.ndarray:
    """Duller, lower-pitched coin drop - the inverse of coin_earn."""
    out = np.zeros(samples(0.3))
    tone = (osc(600.0, 0.18) + 0.3 * osc(900.0, 0.1)) * decay_env(0.18, k=6, attack=0.004)
    place(out, tone, 0.0, gain=0.55)
    return out


def sfx_triumph_earn() -> np.ndarray:
    """Soft single tick/ping, subordinate to triumph_milestone."""
    out = np.zeros(samples(0.3))
    tone = osc(1046.5, 0.15) * decay_env(0.15, k=7, attack=0.003)
    place(out, tone, 0.0, gain=0.4)
    return out


def sfx_defeat_stinger() -> np.ndarray:
    """Short low-register stinger - layered with fatal_hp_loss, not a replacement."""
    out = np.zeros(samples(0.6))
    for f in [196.0, 146.83]:
        tone = osc(f, 0.4, "saw") * decay_env(0.4, k=3, attack=0.01)
        place(out, lowpass(tone, 1200), 0.0, gain=0.5)
    return out


def sfx_victory_fanfare() -> np.ndarray:
    """Bigger, longer fanfare than triumph_milestone."""
    out = np.zeros(samples(1.8))
    notes = [(392.0, 0.0, 0.3), (523.25, 0.22, 0.3), (659.25, 0.44, 0.3), (783.99, 0.66, 1.0)]
    for f, at, d in notes:
        tone = (osc(f, d) + 0.5 * osc(f * 2, d) + 0.3 * osc(f * 1.5, d))
        place(out, tone * decay_env(d, k=3.5, attack=0.006), at, gain=0.75)
    return out


SFX_BUILDERS = {
    # ... existing 14 entries unchanged ...
    "sfx_coin_earn": sfx_coin_earn,
    "sfx_coin_spend": sfx_coin_spend,
    "sfx_triumph_earn": sfx_triumph_earn,
    "sfx_defeat_stinger": sfx_defeat_stinger,
    "sfx_victory_fanfare": sfx_victory_fanfare,
}
```

Exact synthesis constants (frequencies/durations/gains) above are a starting point, not a locked spec -
Cursor should listen and adjust within the sound-design intent (bright/short vs. dull/lower for the
coin pair; "subordinate" loudness for `triumph_earn`; "bigger, longer" for `victory_fanfare`), same
latitude already implicit in every existing `sfx_*` function's docstring-only spec. Run the generator
(`python3 tools/generate_placeholder_audio.py` - check the existing `main()` for the exact invocation) to
produce the five new WAVs at 16-bit mono (matching the existing loop-math constraint from this project's
memory, though these are one-shot SFX, not looping BGM, so the mono requirement is about consistency with
the rest of `assets/audio/sfx/`, not loop-seam math specifically).

### `docs/dependency/ui-audio-assets.md` update

Add the five new keys to the existing "Still open (not blocking)" section's combat-SFX/real-asset-sourcing
list, so they're tracked as placeholder-pending-real-audio alongside the other 14 - do not open a second,
separate tracking entry for them.

## Verification (mandatory before requesting review)

1. `godot --headless --path . --import` - clean.
2. Run the placeholder generator and confirm five new WAV files exist at
   `assets/audio/sfx/sfx_coin_earn.wav` etc.
3. `SYNGRID_SCREENSHOT=/tmp/gridprep.png godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn` - purchase and sell an item, confirm no crash and (if the harness supports audio assertions) that `coin_spend`/`coin_earn` fire.
4. `godot --path . --resolution 540x960 --verbose scenes/main_menu/MainMenuPreviewHarness.tscn` - confirm issue #15's exact leak warnings ("Leaked instance: AudioStreamWAV", "Resource still in use... bgm_prep.wav") are gone from the exit log.
5. `scenes/audio/AudioPreviewHarness.gd` already lists every `play_*` method for manual audition (per the existing `AudioPreviewHarness.gd:9-22` array) - add the five new method names to that list so they're audition-able the same way as the existing 14.
6. Confirm `_is_victory` plays `victory_fanfare` and never `triumph_milestone` in the same run-completion moment (log or breakpoint check - both are silent WAV placeholders so this can't be confirmed by ear alone yet).
7. Trigger two crits in quick succession (within 0.2s) in a live or fixture combat log and confirm BGM volume returns to true baseline after the second duck, not a permanently-lowered level - this is the specific race the `_bgm_base_db` capture-guard in section 1 exists to prevent.

## Out of scope

- No real (non-placeholder) audio sourcing for the five new events - see the HLD's trade-offs section.
- No `timer_tick_low` - see the HLD's audit finding for why there is no honest trigger point today.
- No change to `_crossfade_bgm`'s duration or `play_fatal_hp_loss`'s LPF parameters - both already match `juice_manual.md` §5 exactly; this issue documents that fact, it does not re-implement either.
