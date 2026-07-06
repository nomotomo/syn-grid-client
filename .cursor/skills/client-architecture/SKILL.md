---
name: client-architecture
description: Godot 4 client architecture constraints for Syn-Grid. Load whenever making structural decisions, adding scripts, or designing how scenes and autoloads interact.
---

# Client Architecture Constraints

These are hard rules. Every file you generate must comply.

---

## 1. Autoload Hierarchy

Four and only four autoloads exist. No new autoloads may be added without explicit user approval.

```
GameState       - session data (token, round, gold, life, triumph, item lists)
ApiClient       - all HTTP/JSON server calls; emits typed signals per RPC
AudioManager    - BGM cross-fade, SFX load-on-demand cache, bus filter control
ScreenEffects   - camera shake, white flash, screen overlay effects
```

Dependency direction: `ApiClient` reads `GameState.token`. Nothing else crosses autoload boundaries.

---

## 2. Scene Structure

Each of the six game screens is a self-contained scene:

```
scenes/main_menu/     MainMenu.tscn    + MainMenu.gd
scenes/shop/          ShopScene.tscn   + ShopScene.gd
scenes/grid_prep/     GridPrepScene.tscn + GridPrepScene.gd
scenes/combat_replay/ CombatReplayScene.tscn + CombatReplayScene.gd
scenes/round_end/     RoundEndScene.tscn + RoundEndScene.gd
scenes/leaderboard/   LeaderboardScene.tscn + LeaderboardScene.gd
```

A scene transitions to the next by calling `get_tree().change_scene_to_file(path)`.
Scenes never hold references to other scenes.
Scene-to-scene data is passed via `GameState` (write before transition, read after load).

---

## 3. Network Layer - Signal Contract

`ApiClient` is the only node that creates `HTTPRequest` nodes or calls HTTP.
All other scripts connect to `ApiClient` signals to receive responses.

Signal naming convention: `<rpc_name>_completed(data: Dictionary)` and `<rpc_name>_failed(code: int, reason: String)`.

Example:
```gdscript
# In ShopScene.gd _ready():
ApiClient.roll_shop_completed.connect(_on_roll_shop_completed)
ApiClient.roll_shop_failed.connect(_on_roll_shop_failed)
ApiClient.roll_shop(GameState.current_round)

func _on_roll_shop_completed(data: Dictionary) -> void:
    GameState.current_shop_slots = data.get("slots", [])
    _render_shop()
```

`ApiClient` never returns values. It always signals.

---

## 4. Item State Ownership

The client maintains the local item arrangement (equipped positions) per round.
The server is authoritative on bench contents (returned after PurchaseItem / SellItem).

Rules:
- After any server call returning `updated_grid`, sync bench from `updated_grid.bench_reserve`, excluding items the player has locally placed in `GameState.equipped_items`.
- `equipped_items` is reset to `[]` at the start of each round (returned to bench).
- Item placement coordinates (`{ x, y }`) are client-owned until `StartMatch` - only then does the server see and validate them.

---

## 5. Combat Log Playback

`CombatLogPlayer.gd` (in `scripts/combat/`) is the only place that processes `TickEvent` entries.
It owns a `Timer` node (`wait_time = 0.10`) and a queue (`Array[Dictionary]`).
No scene processes combat events in `_process`. Use the queue + timer pattern.

```gdscript
class_name CombatLogPlayer
extends Node

signal event_played(event: Dictionary)
signal playback_finished(winner_id: String)

@export var tick_interval: float = 0.10
@export var hitstop_frames: int = 2

var _queue: Array[Dictionary] = []
var _timer: Timer

func load_log(combat_log: Dictionary) -> void:
    _queue = combat_log.get("events", []).duplicate()
    _timer.start()

func _on_timer_timeout() -> void:
    if _queue.is_empty():
        _timer.stop()
        playback_finished.emit(...)
        return
    var ev: Dictionary = _queue.pop_front()
    event_played.emit(ev)
    if ev.get("crit", false):
        _timer.stop()
        await get_tree().process_frame   # frame 1 of hit-stop
        await get_tree().process_frame   # frame 2
        _timer.start()
```

---

## 6. Shader Files

All shaders live in `assets/shaders/`.
Shader uniforms that map to server data must be named to match the JSON field:
- `glow_intensity` <- `modifier_pct` from `synergy` object
- `shake_intensity` <- computed from `hp_loss / max_hp * BASE_SCALAR`

No hardcoded magic numbers in shader files. Expose every constant as a uniform.

---

## 7. Audio Files

- BGM files: `assets/audio/bgm/` - two tracks, 30-45s seamless loops.
- SFX files: `assets/audio/sfx/` - one file per SFX event, named to match the event matrix in `docs/juice_manual.md` (e.g. `sfx_shop_reroll.ogg`, `sfx_melee_strike.ogg`).
- `AudioManager.gd` exposes one method per SFX event: `play_shop_reroll()`, `play_melee_strike(position: Vector2)`, etc.
- Never call `AudioStreamPlayer.play()` from a scene directly.

---

## 8. Export Variables on Every Constant

Any value a designer might want to adjust must be `@export`:

```gdscript
@export var card_pop_duration: float = 0.12
@export var card_settle_duration: float = 0.06
@export var card_stagger_interval: float = 0.04
@export var drag_tilt_scale: float = 0.04
@export var shake_base_scalar: float = 12.0
```

No magic numbers buried in tween calls.
