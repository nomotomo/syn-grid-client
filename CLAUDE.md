# Project Syn-Grid - Godot 4 Client

## What This Is

The mobile game client for Syn-Grid, an asymmetric asynchronous inventory management auto-battler.
This is a pure presentation layer - no game logic lives here.
All inventory, grid, combat, economy, and season logic runs on the Go server at `../sync-grid`.

The client's only jobs:
1. Call the REST API (via grpc-gateway bridge at the server).
2. Interpolate server responses into animated, juicy visual sequences.
3. Let the player arrange items on a grid and submit to the server.

A compromised client can only change cosmetics. The server rejects any invalid state.

## Juice & Presentation Contract

**This is the most important document in this repo.**
The full design spec lives in `docs/juice_manual.md`.
Load it (or invoke `/game-ui`) before writing any scene, shader, tween, or audio node.

Key laws:
- No LINEAR tweens on any visible property.
- All items animate with elastic overshoot.
- Synergy borders use a fragment shader - never a static Line2D.
- Combat log events play one per 0.10s from a queue - never all at once.
- Audio is 50% of perceived weight. Follow the SFX event matrix exactly.

## Server API Contract

All server communication is documented in `docs/api_contract.md`.
The server speaks HTTP/JSON (grpc-gateway bridge).
The `ApiClient` autoload singleton handles all network calls.
No scene or script calls HTTPRequest directly - everything goes through `ApiClient`.

## Architecture

```
[Godot Client]
    |
    |--(HTTP/JSON via grpc-gateway)--> [Go Server ../sync-grid :8080]
                                              |
                                           [PostgreSQL + Redis]
```

## Stack

| Layer | Technology |
|---|---|
| Engine | Godot 4.3 |
| Language | GDScript (not C#) |
| Transport | HTTP/JSON via `HTTPRequest` node through `ApiClient` autoload |
| Target | Android (primary), iOS (secondary) |
| Orientation | Portrait (1080x1920 viewport) |

## Directory Structure

```
sync-grid-client/
├── docs/
│   ├── juice_manual.md         # Master design contract (load before any UI work)
│   ├── api_contract.md         # REST API shapes and error codes
│   └── Project_Syn_Grid_Juice_Aesthetic_Spec.pdf
├── scenes/
│   ├── main_menu/              # MainMenu.tscn + MainMenu.gd
│   ├── shop/                   # ShopScene.tscn + ShopScene.gd
│   ├── grid_prep/              # GridPrepScene.tscn + GridPrepScene.gd
│   ├── combat_replay/          # CombatReplayScene.tscn + CombatReplayScene.gd
│   ├── round_end/              # RoundEndScene.tscn + RoundEndScene.gd
│   └── leaderboard/            # LeaderboardScene.tscn + LeaderboardScene.gd
├── scripts/
│   ├── autoloads/
│   │   ├── ApiClient.gd        # All HTTP calls; emits signals on response
│   │   ├── AudioManager.gd     # BGM cross-fade, SFX on-demand loader/cache
│   │   ├── ScreenEffects.gd    # Camera shake, white flash, LPF bus filter
│   │   └── GameState.gd        # Current round, gold, life, triumph, token
│   ├── ui/                     # Reusable UI components (ItemCard.gd, etc.)
│   ├── combat/                 # CombatLogPlayer.gd - event queue + timer
│   └── network/                # ApiRequest.gd - base request wrapper
├── assets/
│   ├── audio/
│   │   ├── bgm/                # Prep track, combat track (30-45s looping)
│   │   └── sfx/                # SFX files (loaded on demand, not preloaded)
│   ├── sprites/
│   │   ├── items/              # Item icons (16-bit pixel art)
│   │   ├── ui/                 # Buttons, panels, borders
│   │   └── effects/            # Particles, flash textures
│   └── shaders/
│       ├── synergy_glow.gdshader
│       └── screen_flash.gdshader
├── addons/                     # Third-party Godot plugins
├── project.godot
├── .gitignore
└── CLAUDE.md
```

## Autoload Dependency Map

```
GameState       - no deps (pure data store for current session)
ApiClient       - imports GameState (reads token)
AudioManager    - no deps (pure audio)
ScreenEffects   - no deps (pure visual effects)

Scenes          - import ApiClient (via signal), GameState, AudioManager, ScreenEffects
```

Scenes never call `ApiClient` methods directly via return values.
`ApiClient` emits typed signals; scenes connect to them.
Example: `ApiClient.shop_rolled.connect(_on_shop_rolled)` not `var resp = await ApiClient.roll_shop()`.

## Critical Rules

1. **No game logic in the client** - The client never computes gold, synergies, damage, or triumph. It only displays what the server returns.
2. **Signal-based decoupling** - Scenes never call parent/sibling nodes. Emit signals upward.
3. **No global singletons except the four autoloads** - Do not create additional autoloads.
4. **Juice contract is non-negotiable** - Every tween, shader, and audio node must match `docs/juice_manual.md` exactly.
5. **No preloading SFX at startup** - Use `ResourceLoader.load_threaded_request` in `AudioManager.gd`.
6. **Glassmorphic panels banned on live numbers** - Never put a translucent panel behind HP, gold, or triumph values.
7. **No hardcoded server URL** - Always read from `ApiClient.BASE_URL` export var or `ProjectSettings`.
8. **No C#** - GDScript only. If a plugin requires C#, find an alternative.

## Skills

### /game-ui
Load whenever implementing any scene, shader, tween, or audio node.
This skill loads `docs/juice_manual.md` and applies all design laws to the code it generates.

### Game Rules
The server-side game rules live in `../sync-grid/.claude/skills/game-rules.md`.
Load them when implementing anything that presents game state to the player (damage numbers, synergy descriptions, item stats).
The client must present the same semantics the server computes.

## Phase Tracker

| Phase | Description | Status |
|---|---|---|
| C1 | Repo setup, project.godot, autoload skeletons, ApiClient base | Complete |
| C2 | ApiClient - all 13 RPCs wired to real gateway routes, E2E tested | Complete |
| C3 | MainMenu + GameState hydration | Complete |
| C4 | ShopScene - card roll pop, drag tilt, buy/sell flow | Pending |
| C5 | GridPrepScene - drag-drop placement, synergy glow shader, ValidateGrid call | Complete |
| C6 | CombatReplayScene - event queue, sprite lunge, screen shake, damage floats | Pending |
| C7 | RoundEndScene - win/loss banner, life hearts, triumph orbs | Pending |
| C8 | LeaderboardScene + SeasonScene | Pending |
| C9 | AudioManager - BGM cross-fade, full SFX event matrix | Pending |
| C10 | Android export, release build pipeline | Pending |

## Commands

```bash
# Open in Godot editor (macOS)
open -a "Godot 4" .

# Headless test run (CI)
godot --headless --quit

# API E2E test (requires live server: `make run` in ../sync-grid with DATABASE_URL set)
godot --headless --path . tests/ApiE2E.tscn

# Screenshot harnesses (offline injects fake responses; SYNGRID_LIVE=1 uses the real server)
SYNGRID_SCREENSHOT=/tmp/out.png godot --path . --resolution 540x960 scenes/main_menu/MainMenuPreviewHarness.tscn
SYNGRID_SCREENSHOT=/tmp/out.png godot --path . --resolution 540x960 scenes/grid_prep/GridPrepPreviewHarness.tscn

# Export Android debug APK (requires export templates installed)
godot --headless --export-debug "Android" export/syn-grid-debug.apk
```
