# Syn-Grid Client

> **Presentation-only Godot 4 client** for [Syn-Grid](https://github.com/nomotomo/sync-grid) — an asymmetric, asynchronous inventory-management auto-battler. All game logic runs on the Go server; this repo animates server truth into a juicy mobile experience.

[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/Language-GDScript-7B4DFF)](https://docs.godotengine.org/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84)](docs/build.md)
[![Orientation](https://img.shields.io/badge/Viewport-1080×1920%20Portrait-222)](project.godot)

---

## Table of Contents

- [What Is Syn-Grid?](#what-is-syn-grid)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Scene Flow](#scene-flow)
- [Project Structure](#project-structure)
- [Autoloads](#autoloads)
- [Networking & API](#networking--api)
- [Juice & Presentation Contract](#juice--presentation-contract)
- [Development Workflow](#development-workflow)
- [Testing & Screenshot Harnesses](#testing--screenshot-harnesses)
- [Android Build](#android-build)
- [Documentation Index](#documentation-index)
- [Phase Tracker](#phase-tracker)
- [Contributing](#contributing)
- [Related Repositories](#related-repositories)

---

## What Is Syn-Grid?

Syn-Grid is a mobile auto-battler where players:

1. **Shop** for items during a prep phase
2. **Arrange** them on a grid to trigger synergies
3. **Fight** asynchronously — combat is replayed from a server-generated event log
4. **Progress** through rounds, life points, triumph orbs, and seasonal leaderboards

**Security model:** A compromised client can only change cosmetics. The server rejects every invalid placement, purchase, or state mutation. The client never computes gold, damage, synergies, or triumph — it only displays and animates what the API returns.

**Target:** Portrait mobile (1080×1920), Android primary, iOS secondary.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Godot 4 Client (this repo)              │
│  Scenes · Tweens · Shaders · Audio · Drag-and-drop UI       │
│                                                             │
│  GameState │ ApiClient │ AudioManager │ ScreenEffects        │
│            (4 autoloads only — no additional singletons)    │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP/JSON (grpc-gateway bridge)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Go Server  ../sync-grid  :8080                 │
│  Inventory · Grid · Combat · Economy · Seasons · Matchmaking│
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
                    PostgreSQL + Redis
```

| Layer | Responsibility |
|-------|----------------|
| **Client** | REST calls, signal-driven UI, combat log interpolation, juice (tweens, SFX, shaders) |
| **Server** | All authoritative game rules, persistence, matchmaking, combat simulation |
| **Transport** | JSON over HTTP via `HTTPRequest` through the `ApiClient` autoload |

Scenes **never** call `ApiClient` methods and await return values. `ApiClient` emits typed signals; scenes connect to them.

```gdscript
# Correct
ApiClient.roll_shop_completed.connect(_on_shop_rolled)
ApiClient.roll_shop(round_num)

# Wrong — do not await ApiClient directly from scenes
var resp = await ApiClient.roll_shop(round_num)
```

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Engine | [Godot 4.7](https://godotengine.org/) |
| Language | **GDScript only** (no C#) |
| Transport | `HTTPRequest` → `ApiClient` autoload |
| Audio | On-demand SFX load via `ResourceLoader.load_threaded_request` |
| Shaders | Synergy glow (`assets/shaders/synergy_glow.gdshader`), screen flash |
| Server | Go + grpc-gateway at `../sync-grid` |

---

## Prerequisites

| Tool | Version / Notes |
|------|-----------------|
| **Godot 4.7** | Match `config/features` in `project.godot` |
| **Go server** | Clone [sync-grid](https://github.com/nomotomo/sync-grid) sibling to this repo |
| **PostgreSQL** | Required for live API / E2E tests |
| **Android SDK + JDK 17** | Only for APK export — see [docs/build.md](docs/build.md) |
| **gh CLI** | GitHub issues / PR workflow (optional but expected for contributors) |

Default API base URL: `http://localhost:8080` (`ApiClient.base_url`).

---

## Quick Start

### 1. Clone and open

```bash
git clone https://github.com/nomotomo/sync-grid-client.git
cd sync-grid-client
open -a "Godot 4" .    # macOS — or open project.godot from Godot launcher
```

### 2. Start the server (sibling repo)

```bash
cd ../sync-grid
# Follow sync-grid README — typically:
export DATABASE_URL="postgres://..."
make run    # listens on :8080
```

### 3. Run the client

Press **F5** in the editor, or headless smoke check:

```bash
make check
# equivalent: godot --headless --path . --import && godot --headless --path . --quit-after 60
```

### 4. Play offline (preview harnesses)

Every major scene has a harness that injects fake API responses — no server required. See [Testing & Screenshot Harnesses](#testing--screenshot-harnesses).

---

## Scene Flow

```
MainMenu
    ├── GridPrepScene          (shop + bench + grid placement + synergies)
    │       └── CombatReplayScene   (event-queue combat replay)
    │               └── BattleReportScene   (post-mortem: verdict, heatmap, timeline)
    │                       └── RoundEndScene   (win/loss/dead/victory)
    │                               └── GridPrepScene  (next round)
    ├── LeaderboardScene
    └── SeasonHub
```

| Scene | Path | Purpose |
|-------|------|---------|
| Main Menu | `scenes/main_menu/MainMenu.tscn` | Login, season pick, navigation |
| Grid Prep | `scenes/grid_prep/GridPrepScene.tscn` | Shop row, drag-drop grid, synergy glow |
| Combat Replay | `scenes/combat_replay/CombatReplayScene.tscn` | Server combat log playback |
| Battle Report | `scenes/battle_report/BattleReportScene.tscn` | 5-page post-mortem (verdict → timeline) |
| Round End | `scenes/round_end/RoundEndScene.tscn` | Life hearts, triumph orbs, continue |
| Leaderboard | `scenes/leaderboard/LeaderboardScene.tscn` | Season standings |
| Season Hub | `scenes/season_hub/SeasonHub.tscn` | Season metadata & navigation |

---

## Project Structure

```
sync-grid-client/
├── scenes/                    # One folder per screen + PreviewHarness per scene
│   ├── main_menu/
│   ├── grid_prep/             # GridCell, ItemCard, shop UI
│   ├── combat_replay/         # CombatLogPlayer integration
│   ├── battle_report/         # PostMortemRules-driven advice pages
│   ├── round_end/
│   ├── leaderboard/
│   └── season_hub/
├── scripts/
│   ├── autoloads/             # GameState, ApiClient, AudioManager, ScreenEffects
│   ├── ui/                    # Reusable components (ItemCard, SynGridPalette, ThemeBuilder)
│   ├── combat/                # CombatLogPlayer — 0.10s event queue
│   ├── network/               # ApiRequest base wrapper
│   └── util/                  # PostMortemRules, shared helpers
├── assets/
│   ├── audio/bgm/             # Looping prep & combat tracks
│   ├── audio/sfx/             # Loaded on demand (not preloaded at boot)
│   ├── sprites/items/         # 16-bit pixel item icons
│   ├── sprites/ui/
│   └── shaders/               # synergy_glow, screen_flash
├── tests/
│   ├── ApiE2E.tscn            # Live server integration test
│   └── PostMortemRulesVerify.tscn
├── docs/
│   ├── juice_manual.md        # ★ Master presentation contract
│   ├── api_contract.md        # REST shapes & error codes
│   ├── build.md               # Android export pipeline
│   ├── prd/                   # Product requirements
│   ├── high-level-design/     # HLD per feature
│   └── low-level-design/      # LLD + review checklists
├── addons/                    # Third-party Godot plugins
├── export/                    # APK output (gitignored binaries)
├── Makefile                   # check, apk-debug, clean
├── project.godot
└── CLAUDE.md                  # AI collaboration & coding laws
```

---

## Autoloads

Only **four** global singletons exist. Do not add more.

| Autoload | File | Role |
|----------|------|------|
| `GameState` | `scripts/autoloads/GameState.gd` | Session token, round/gold/life/triumph, grid items, shop cache |
| `ApiClient` | `scripts/autoloads/ApiClient.gd` | All HTTP RPCs; emits typed success/error signals |
| `AudioManager` | `scripts/autoloads/AudioManager.gd` | BGM cross-fade, threaded SFX cache |
| `ScreenEffects` | `scripts/autoloads/ScreenEffects.gd` | Camera shake, white flash, LPF bus filter |

**Dependency rule:** `GameState` has no deps. `ApiClient` reads `GameState.token`. Scenes connect to `ApiClient` signals and read `GameState` for display.

---

## Networking & API

Full contract: **[docs/api_contract.md](docs/api_contract.md)**

### ApiClient RPCs (signal-driven)

| Method | Signals | Purpose |
|--------|---------|---------|
| `authenticate` | `authenticate_completed` / `authenticate_failed` | Device ID → JWT session |
| `get_profile` | `get_profile_completed` / `get_profile_failed` | Display name, avatar |
| `update_profile` | `update_profile_completed` / `update_profile_failed` | Set display name / avatar |
| `get_active_season` | `get_active_season_completed` / `get_active_season_failed` | Current season snapshot |
| `get_active_grid` | `get_active_grid_completed` / `get_active_grid_failed` | Hydrate equipped grid from server |
| `award_round_gold` | `award_round_gold_completed` / `award_round_gold_failed` | Claim start-of-round gold (once per round) |
| `roll_shop` | `roll_shop_completed` / `roll_shop_failed` | Refresh shop slots |
| `purchase_item` | `purchase_item_completed` / `purchase_item_failed` | Buy item to bench |
| `sell_item` | `sell_item_completed` / `sell_item_failed` | Sell from grid or bench |
| `validate_grid` | `validate_grid_completed` / `validate_grid_failed` | Server-side placement check |
| `start_match` | `start_match_completed` / `start_match_failed` | Lock grid → queue combat |
| `finalize_round` | `finalize_round_completed` / `finalize_round_failed` | Round outcome, HP, triumph delta |
| `get_leaderboard` | `get_leaderboard_completed` / `get_leaderboard_failed` | Season rankings |
| `get_match_history` | `get_match_history_completed` / `get_match_history_failed` | Past match list |
| `reset_run` | `reset_run_completed` / `reset_run_failed` | Abandon current run |

Configure server URL via `ApiClient.base_url` export or project settings — **never hardcode** URLs in scenes.

### Device identity

`GameState` persists a stable `device_id` at `user://device_id.txt` on first launch. The server treats this as permanent player identity.

---

## Juice & Presentation Contract

**This is the most important doc for any UI work:** [docs/juice_manual.md](docs/juice_manual.md)

Load the `/game-ui` skill (`.cursor/skills/game-ui/` or `.claude/skills/game-ui/`) before implementing scenes, shaders, tweens, or audio.

### Non-negotiable laws

| Rule | Detail |
|------|--------|
| **No LINEAR tweens** | Visible motion uses elastic/back/quint easing — never `Tween.TRANS_LINEAR` on scale, position, or rotation |
| **Elastic overshoot** | Items pop in with overshoot; synergy borders use a **fragment shader**, not `Line2D` |
| **Combat log queue** | One event per **0.10s** from `CombatLogPlayer` — never dump all events at once |
| **Audio matrix** | Use only documented SFX events — do not invent new sound names |
| **No glass on live numbers** | Never put translucent panels behind HP, gold, or triumph values |
| **Screen shake** | `ScreenEffects` formula — combat crits and fatal hits trigger prescribed intensities |

---

## Development Workflow

This repo uses a **dual-AI workflow** documented in [CLAUDE.md](CLAUDE.md):

| Role | Tool | Owns |
|------|------|------|
| **Lead Architect** | Claude Code (CLI) | HLD/LLD, `docs/`, architecture, review verdicts |
| **Lead Engineer** | Cursor (IDE) | Implementation, tests, local Godot loop |

### GitHub-first (implementers)

Before writing feature code:

1. `gh issue list` — find or create an issue
2. `git checkout -b feature/issue-[N]-short-description`
3. Read the governing LLD in `docs/low-level-design/`
4. Implement, run harnesses / tests
5. Open PR — Claude Code reviews against LLD acceptance checklist

**Do not** change architecture, add autoloads, or alter API contracts without an architect-approved design doc.

---

## Testing & Screenshot Harnesses

### Makefile targets

```bash
make check          # Headless import + 60s boot smoke test
make setup-android  # Install Godot Android build template
make apk-debug      # Android debug APK → export/syn-grid-debug.apk
make apk-release    # Signed release APK (requires .env keystore vars)
make clean          # Remove export/ artifacts
```

### Headless verification

```bash
godot --headless --path . --import
godot --headless --path . tests/PostMortemRulesVerify.tscn
```

### Live API E2E (requires running server)

```bash
cd ../sync-grid && make run   # in another terminal
godot --headless --path . tests/ApiE2E.tscn
```

### Screenshot harnesses (offline by default)

Set `SYNGRID_SCREENSHOT=/path/to/out.png` and optional env vars:

| Harness | Env extras | Notes |
|---------|------------|-------|
| `MainMenuPreviewHarness.tscn` | — | Login / menu state |
| `GridPrepPreviewHarness.tscn` | — | Shop + grid |
| `CombatReplayPreviewHarness.tscn` | `SYNGRID_HINT=losing` | Amber "losing hard" hint pill |
| `BattleReportPreviewHarness.tscn` | `SYNGRID_PAGE=0..4` | Pages: verdict, breakdown, advice, heatmap, timeline |
| `RoundEndPreviewHarness.tscn` | `SYNGRID_RESULT=win\|loss\|dead\|victory` | |
| `LeaderboardPreviewHarness.tscn` | — | |

```bash
# Example — capture battle report heatmap page at 540×960
SYNGRID_SCREENSHOT=/tmp/heatmap.png SYNGRID_PAGE=3 \
  godot --path . --resolution 540x960 \
  scenes/battle_report/BattleReportPreviewHarness.tscn
```

Live server mode for harnesses: `SYNGRID_LIVE=1`.

---

## Android Build

See **[docs/build.md](docs/build.md)** for full export template setup, keystore, and CI notes.

```bash
# After Godot Android export templates are installed
make apk-debug
# → export/syn-grid-debug.apk
```

Requirements: Android SDK, platform tools, JDK 17, Godot Android export templates matching 4.7.

---

## Documentation Index

| Document | Purpose |
|----------|---------|
| [CLAUDE.md](CLAUDE.md) | Project laws, phase tracker, commands |
| [docs/juice_manual.md](docs/juice_manual.md) | Animation, audio, shader, UX contract |
| [docs/api_contract.md](docs/api_contract.md) | REST endpoints & JSON shapes |
| [docs/build.md](docs/build.md) | Android export pipeline |
| [docs/game_ideas.md](docs/game_ideas.md) | Design brainstorming (non-authoritative) |
| `docs/prd/` | Product requirements per feature |
| `docs/high-level-design/` | Architecture & trade-offs |
| `docs/low-level-design/` | Implementation blueprints + review checklists |
| `design-diagram/` | Mermaid / sequence diagrams |

Server-side game rules: `../sync-grid/.claude/skills/game-rules.md`

---

## Phase Tracker

| Phase | Description | Status |
|-------|-------------|--------|
| C1 | Repo setup, autoload skeletons, ApiClient base | ✅ |
| C2 | All RPCs wired to gateway routes, E2E tested | ✅ |
| C3 | MainMenu + GameState hydration | ✅ |
| C4 | Shop flow — roll, buy/sell, triple-merge | ✅ |
| C5 | GridPrepScene — shop + drag-drop + synergy glow | ✅ |
| C6 | CombatReplayScene — event queue, shake, damage floats | ✅ |
| C7 | RoundEndScene — banners, life, triumph | ✅ |
| C8 | LeaderboardScene + SeasonHub | ✅ |
| C9 | AudioManager — BGM cross-fade, full SFX matrix | 🔲 |
| C10 | Item/HUD sprites + rounded neon-glass theme | 🔲 |
| C11 | Android export, release build pipeline | 🔲 |

---

## Contributing

1. Read [CLAUDE.md](CLAUDE.md) and the relevant LLD before coding.
2. File or claim a GitHub issue.
3. Branch: `feature/issue-[N]-description`.
4. Match existing GDScript style (tabs, signal naming, `SynGridPalette` / `ThemeBuilder` reuse).
5. Run `make check` and affected preview harnesses with `SYNGRID_SCREENSHOT`.
6. Open a PR — implementation is **not done** until architect review passes.

### Critical don'ts

- No game logic on the client (gold, damage, synergies, triumph)
- No additional autoloads
- No C#
- No `HTTPRequest` in scenes — use `ApiClient`
- No architectural changes without HLD/LLD approval

---

## Related Repositories

| Repo | Role |
|------|------|
| [nomotomo/sync-grid](https://github.com/nomotomo/sync-grid) | Go game server (authoritative logic) |
| **sync-grid-client** (this repo) | Godot presentation layer |

Expected layout:

```
game-development/
├── sync-grid/          # Go server
└── sync-grid-client/   # Godot client (you are here)
```

---

## Credits & License

- Item sprite attributions: [docs/CREDITS.md](docs/CREDITS.md)
- Third-party licenses: [docs/LICENSE-akari21.txt](docs/LICENSE-akari21.txt)

---

<p align="center">
  <strong>Syn-Grid</strong> — arrange items. trigger synergies. watch the replay.<br>
  <sub>Server computes. Client animates. Players feel everything.</sub>
</p>
