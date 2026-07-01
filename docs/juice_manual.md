# PROJECT SYN-GRID: JUICE & PRESENTATION CONTRACT

This document is the authoritative client-side design contract.
Every Godot scene, shader, tween, and audio node you generate must comply with every rule here.
Do not invent alternatives. Do not soften requirements. Implement them exactly.

---

## 1. UI Layout Paradigm

- All menu layers default to a **Dark-First, high-contrast bento-grid** structure.
- Use grey elevation shifts (`Color(0.08, 0.08, 0.10)` vs `Color(0.12, 0.12, 0.15)`) for panel separation - never harsh solid lines or bright borders.
- **Glassmorphic panels** (BackdropFilter-style translucency) are permitted ONLY for impermanent popovers, settings overlays, and stats cards.
- Never render glassmorphic layers behind active gold numbers, HP values, or combat log text fields. Those must sit on fully opaque dark backgrounds for legibility under any lighting condition.

---

## 2. Elastic Easing & Tweens

**Banned:** All `LINEAR` transition types on any `scale`, `position`, or `rotation` property mutation.

Every component scale and position change must pass through an asymptotic or overshoot elastic easing curve.

### Shop Card Roll Pop

When the user invokes Reroll:
1. Scale each item card from `Vector2(0, 0)` to `Vector2(1.1, 1.1)` over `0.12s` using `Tween.EASE_OUT` + `Tween.TRANS_ELASTIC`.
2. Immediately chain a second tween settling from `Vector2(1.1, 1.1)` to `Vector2(1.0, 1.0)` over `0.06s` using `Tween.EASE_IN_OUT` + `Tween.TRANS_BACK`.
3. Stagger each card by `0.04s` from the previous so they cascade left-to-right, not all at once.

GDScript signature for the card pop:
```gdscript
func play_card_pop(card: Control, stagger_idx: int) -> void:
    var tw := create_tween().set_parallel(false)
    card.scale = Vector2.ZERO
    tw.tween_interval(stagger_idx * 0.04)
    tw.tween_property(card, "scale", Vector2(1.1, 1.1), 0.12)\
      .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
    tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.06)\
      .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
```

### Drag-and-Drop Tilt

While an item card is held:
- Read `InputEventMouseMotion.relative.x` each frame.
- Apply `card.rotation = clamp(velocity_x * 0.04, -0.35, 0.35)` radians.
- Apply a trailing lag: `card.global_position = lerp(card.global_position, target_pos, 0.65)` each physics frame.
- On drop: tween `rotation` back to `0.0` over `0.15s` with `TRANS_SPRING`.

### Grid Snap Bounce

On a valid server-confirmed placement (`ValidateGrid` returns success):
1. Y-axis squish: tween card `scale.y` from `1.0` to `0.75` over `0.06s`.
2. Bounce back: tween `scale.y` from `0.75` to `1.05` over `0.08s`, then to `1.0` over `0.04s`.
3. Spawn a `CPUParticles2D` radial ring at the cell centre: `emission_shape = RING`, lifetime `0.3s`, alpha fade out, colour `Color(0.0, 0.9, 0.8, 0.6)` (neon teal).

---

## 3. Shader Synergy Glows

When the server returns `active_synergies` from `ValidateGrid`, **never draw static lines between items.**

Trigger a fragment shader on the shared cell border:
- Cycle a neon plasma gradient along the boundary UV coordinate.
- Gradient colours: `#00F5D4` (teal) → `#7B2FBE` (purple) → `#00F5D4`, cycling at `2.0 Hz`.
- Shader uniform `glow_intensity` = `synergy.modifier_pct` (e.g. 0.20 for 20% bonus).
- Use `TIME` in the shader for the animation; the host node passes `modifier_pct` as a uniform.

Shader skeleton:
```glsl
shader_type canvas_item;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    float pulse = sin(TIME * 6.28 * 2.0) * 0.5 + 0.5;
    vec3 color_a = vec3(0.0, 0.96, 0.83);
    vec3 color_b = vec3(0.48, 0.18, 0.75);
    vec3 glow = mix(color_a, color_b, pulse) * glow_intensity;
    COLOR = vec4(glow, pulse * glow_intensity);
}
```

---

## 4. Auto-Combat Log Visual Interpretation Layer

The client receives a `CombatLog` with ordered `TickEvent` entries.
It must NOT render all events instantly. It queues them and plays one at a time at a fixed rate.

**Playback rate:** 1 tick event per `0.10s` real time (10 events/second for normal, 5 events/second during crits to let hit-stop register).

### Sprite Velocity Clashes

When a `TickEvent.firing_item_id` fires:
1. Move the attacker sprite `+40px` on the X-axis over `3 frames` (approx. `0.05s` at 60fps).
2. Return it to origin over `5 frames`.
Use a `Tween` with `TRANS_CIRC` ease out for the lunge, `TRANS_QUAD` ease in for the return.

### Screen Shake Severity

```gdscript
const BASE_SCALAR := 12.0

func shake_camera(damage_dealt: float, max_target_hp: float, is_crit: bool) -> void:
    var intensity := (damage_dealt / max_target_hp) * BASE_SCALAR
    if is_crit:
        intensity *= 2.5
        await get_tree().process_frame          # 1-frame white flash
        $ScreenFlash.modulate = Color(1, 1, 1, 1)
        await get_tree().process_frame
        $ScreenFlash.modulate = Color(1, 1, 1, 0)
    $Camera2D.apply_shake(intensity)            # implement as offset noise decay
```

Critical hits additionally freeze ALL animations for exactly `2 frames`, then resume (hit-stop).

### Bouncy Floating Damage Indicators

On every `TickEvent`:
1. Instantiate a `Label` at the target sprite position.
2. Randomise direction vector: `angle = randf_range(-PI/12, PI/12)` from straight up.
3. Tween position `+80px` in the randomised direction over `0.5s` with `TRANS_QUAD EASE_OUT`.
4. Simultaneously fade alpha from `1.0` to `0.0` starting at `0.3s`.
5. **Crit formatting:** font scale `1.8x`, text colour `Color(0.85, 0.10, 0.10)`, add a `StyleBoxFlat` outline in `Color(0.1, 0.0, 0.0)`.

---

## 5. Soundscapes & Acoustic Architecture

Audio is 50% of perceived game weight. All audio events are triggered by server response fields, not by UI interactions alone.

### BGM Tracks

Two looping tracks. Each must loop seamlessly at a `30` to `45` second interval to minimise runtime memory.

| Phase | Style | Trigger |
|---|---|---|
| Prep / Shop | Dark synthwave, slow BPM, low-key | Screen enters ShopScene or PrepScene |
| Combat Replay | Percussive chiptune / synthwave | `StartMatch` response received |

Swap between tracks with a `0.8s` cross-fade using two `AudioStreamPlayer` nodes with volume tweens.

### SFX Event Matrix

| Trigger | Sound Design Requirement | Source Hint |
|---|---|---|
| Shop Reroll | High-freq wooden dice clatter + mechanical metallic notch | Sonniss GDC: "UI clicks", "dice roll" |
| Synergy edge link activated | Rising synth chime, ascending pitch per modifier_pct level | Sonniss: "Magic Shimmer Elements" |
| Item placed on grid (valid) | Satisfying grid-snap click, short transient | OpenGameArt: "Pixel UI" CC0 packs |
| Item drag pickup | Soft card-lift whoosh | itch.io: "Dark Fantasy UI Assets" |
| Melee weapon fires (MELEE) | Explosive metallic slice, immediate decay | Sonniss: "Medieval Combat" |
| Ranged weapon fires (RANGED) | Bow twang / crossbow snap | Sonniss: "Medieval Combat" |
| Arcane weapon fires (ARCANE) | Staff hum / spell whoosh | Sonniss: "Magic Shimmer Elements" |
| Critical hit (`crit=true`) | Same as weapon fire + heavy layered impact overtone | Pitch-shifted version of base strike |
| Shield absorb (`shield_absorbed > 0`) | Dense low-freq iron chime, distinct ring-out trail | Sonniss: "Medieval Combat" |
| HP loss - normal | Soft thud | Pitched down version of melee strike |
| Fatal HP loss (life_points decreases) | Low-pass filter sweep on BGM + sub-bass drop | DSP filter on running AudioStreamPlayer |
| Triple-merge | Rising chime + particle impact | Sonniss: "Magic Shimmer" |
| Win round | Ascending 3-note victory chime | Custom or itch.io |
| Triumph milestone | Short fanfare sting | Custom or itch.io |

### Audio Implementation Rules

- Use `AudioStreamPlayer2D` for all positional in-grid SFX (weapon fires map to item position on grid).
- Use global `AudioStreamPlayer` for BGM, screen-level SFX (reroll, fatal loss), and UI clicks.
- Fatal core HP loss applies a `AudioEffectLowPassFilter` programmatically to the BGM bus, then removes it after `2.0s`. Do not permanently alter the bus chain.
- Never preload all SFX at startup. Load on first use via `ResourceLoader.load_threaded_request` and cache in an autoload singleton.

---

## 6. Asset Sourcing

| Channel | What to Search | License |
|---|---|---|
| itch.io | "Pixel Art RPG Interface Kit", "16-bit Spell Icon Pack", "Dark Fantasy UI Assets" - creators CraftPix, Adamatlas | Varies - check per asset |
| OpenGameArt.org | "Pixel UI borders", sound collections tagged CC0 | CC0 Public Domain |
| Sonniss GDC Archive | "UI clicks", "Medieval Combat", "Magic Shimmer Elements" | Free commercial use |
| Scribble Audio / Epidemic Sound | "Chiptune Dark Synth Dungeon" loops | Paid licence, low cost |

Budget: start entirely free (CC0 + Sonniss), then selectively license from itch.io bundles within ₹15,000-30,000 total.

---

## 7. Implementation Checklist

Before marking any Godot scene complete, verify:

- [ ] No `LINEAR` tween on any visible property
- [ ] Shop roll uses staggered elastic pop (`play_card_pop`)
- [ ] Drag tilt applied via velocity vector, not fixed rotation
- [ ] Grid snap triggers Y-axis squish + teal particle ring
- [ ] Synergy borders use fragment shader, not `Line2D` or `StyleBoxFlat`
- [ ] Combat log plays events sequentially at 0.10s intervals, not instantly
- [ ] Crit hit triggers 2-frame hit-stop + 1-frame white flash
- [ ] Damage floats randomise direction arc -15 to +15 degrees
- [ ] Crit damage floats are 1.8x scale + crimson outline
- [ ] BGM cross-fades (0.8s) between prep and combat tracks
- [ ] Fatal HP loss applies LPF filter to BGM bus then removes it
- [ ] All SFX loaded on-demand via threaded resource loader, not preloaded at startup
- [ ] Glassmorphic panels absent from any scene with live numeric values
