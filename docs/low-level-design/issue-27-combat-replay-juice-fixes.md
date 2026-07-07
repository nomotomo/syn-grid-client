# LLD: CombatReplayScene Juice-Contract and Reuse Fixes

Status: Approved 2026-07-07.
Owner: Claude Code (Lead Architect).
Governs: GitHub issue #27.
Depends on: `docs/juice_manual.md` section 2 (no linear tweens on visible properties), `scripts/ui/SynGridPalette.gd`.

## Why this doc exists

The `CombatReplayScene.gd` rewrite landed direct-to-`main` with two new juice-contract violations, a reuse violation (hardcoded colors that already exist in `SynGridPalette` and don't even match it), and a pre-existing damage-float positioning bug that is the likely cause of the "9&9"-style HP overlap seen in testing. All four fixes are mechanical - no new architecture, just wiring existing patterns already used elsewhere in the same file.

## Required fix 1: two LINEAR tweens

`CombatReplayScene.gd:718` (Tier-C damage-spark burst, inside a `set_parallel(true)` tween group alongside `position` at `:714` and `modulate:a` at `:716`, both of which already have easing):

```gdscript
tw.tween_property(dot, "scale", Vector2(0.3, 0.3), 0.40)
```

Add matching easing - match the sibling `modulate:a` tween's curve (`TRANS_QUAD`, default ease):

```gdscript
tw.tween_property(dot, "scale", Vector2(0.3, 0.3), 0.40).set_trans(Tween.TRANS_QUAD)
```

`CombatReplayScene.gd:575-577` (projectile trail tail point):

```gdscript
tw.tween_method(func(v: Vector2) -> void:
        line.set_point_position(0, v),
    from_pos, target_pos, travel + 0.06).set_delay(0.02)
```

Add the same curve as the head tween two lines above (`:572-574`, `TRANS_QUAD`/`EASE_OUT`):

```gdscript
tw.tween_method(func(v: Vector2) -> void:
        line.set_point_position(0, v),
    from_pos, target_pos, travel + 0.06).set_delay(0.02) \
    .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
```

## Required fix 2: replace hardcoded colors with `SynGridPalette`

`_projectile_color()` at `CombatReplayScene.gd:537-548` hardcodes `Color(0.95, 0.35, 0.30)` (MELEE) / `Color(0.35, 0.85, 0.35)` (RANGED) - neither matches `SynGridPalette.ITEM_TYPE_TINT` (`scripts/ui/SynGridPalette.gd:59-63`: MELEE `Color(0.75, 0.30, 0.25)`, RANGED `Color(0.35, 0.65, 0.35)`). Replace the whole function body with a direct call:

```gdscript
func _projectile_color(category: String) -> Color:
    return SynGridPalette.tint_for_weapon_category(category)
```

Keep the function itself (both call sites at `:558` and `:619` stay unchanged) - only the body changes, so this is a one-line diff at each of the two color literals plus the signature line, not a call-site rewrite.

`CombatReplayScene.gd:337` (crit damage-float color) hardcodes `Color(0.85, 0.10, 0.10)`. Replace with the existing constant:

```gdscript
Color(0.85, 0.10, 0.10) if crit else SynGridPalette.TEXT_PRIMARY
```
becomes
```gdscript
SynGridPalette.DANGER if crit else SynGridPalette.TEXT_PRIMARY
```

Confirm `SynGridPalette.DANGER` numerically matches `Color(0.85, 0.10, 0.10)` before committing (the file already uses `SynGridPalette.DANGER` correctly elsewhere, e.g. `:368`, `:592`, `:686-687`, `:738` - this one spot was just missed).

`scenes/ui/StatsHud.tscn`'s `AccentBar` nodes hardcode raw `Color(...)` literals that happen to match `SynGridPalette` today. Set them from code instead, in `StatsHud.gd:_ready()`, mirroring how the same function already does this correctly for `add_theme_color_override` a few lines below it - find that existing pattern in `_ready()` and apply the same style to the `AccentBar` nodes rather than leaving them as `.tscn`-authored literals.

## Required fix 3: center damage floats on the impact point

`_spawn_damage_float` (`CombatReplayScene.gd:347-349`):

```gdscript
_float_layer.add_child(label)
label.global_position = pos
label.pivot_offset = label.size / 2.0
```

`label.size` is `(0, 0)` immediately after `add_child()` - no layout pass has run yet - so both the position offset and the pivot are computed from a zero size. Every other FX spawner in this file centers explicitly (`_spawn_hitmark:589` uses `pos - Vector2(28, 28)`, `_spawn_muzzle_flash:618` uses `pos - Vector2(18, 18)`). Fix:

```gdscript
_float_layer.add_child(label)
label.reset_size()
label.global_position = pos - label.size / 2.0
label.pivot_offset = label.size / 2.0
```

`reset_size()` forces the layout pass immediately so `label.size` is real before it's used. This is the most likely cause of the "9&9"-style overlap onto the HP bar seen in testing - `HpBar.gd` renders a single integer with no separator, so a mispositioned floating damage number landing on top of the HP bar's own number is the plausible read, though this hasn't been pixel-confirmed against a live frame yet. Confirm during verification below.

## Verification (mandatory before requesting review)

1. `godot --headless --path . --import` - clean.
2. `SYNGRID_SCREENSHOT=/tmp/combat.png godot --path . --resolution 540x960 scenes/combat_replay/CombatReplayPreviewHarness.tscn` - visually confirm:
   - Damage-spark burst and projectile trail read as eased motion (ease-out settle), not constant-velocity.
   - A MELEE weapon's projectile color visually matches its item card's tint; same for RANGED.
   - Damage numbers and "BLOCKED" labels are centered on the impact point, not offset down-and-right, and do not overlap the HP bar's own digit.
3. Grep the diff for any remaining bare `Color(` literal inside `CombatReplayScene.gd` that duplicates a `SynGridPalette` constant - none should remain outside the two fixed above (a few `Color(r, g, b, a)` constructions that only add alpha to an existing `SynGridPalette` color, e.g. `:686-687`, are fine - those already reference the palette, they're not new literals).
4. Note (not required to fix here, but do not regress it further): the harness leaked more `ObjectDB` instances at exit than baseline (13 vs. the pre-existing 2 tracked in issue #15) during the audit that found this issue. If instance count is easy to check in passing, note the number in the PR description; do not spend time root-causing it as part of this fix.

## Out of scope

- No change to `HpBar.gd`'s rendering (single integer, no ratio/separator) - the fix is the damage float's own position, not the HP bar.
- No new shared "FX centering" helper - three call sites (`_spawn_hitmark`, `_spawn_muzzle_flash`, `_spawn_damage_float`) with slightly different offset semantics (fixed pixel offset vs. computed half-size) is not yet enough duplication to justify an abstraction.
- Issue #15 (AudioStreamWAV leak) and any ObjectDB leak investigation - separate, already-tracked issue.
