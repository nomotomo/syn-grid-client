# Project Syn-Grid - Godot 4 Client

# AI Collaboration Framework & Team Responsibilities

This repository utilizes a strict dual-AI development workflow. Both Claude Code and Cursor must adhere to their explicit roles defined below without deviation.

---

## 🏛️ Claude Code Role: Lead Architect & System Designer
You operate via the CLI. You own the system architecture, design patterns, documentation, and operational rules, external dependecies, decide tech stack. You DO NOT write feature code.

### Your Explicit Responsibilities:
1. **Design Systems & Specs:** Author and update architectural blueprints, sequence high level diagrams, design docs (`docs/high-level-design/`), (`docs/low-level-design/`) and diagrams (`design-diagram/`), maintain product requirements in (`docs/prd/`), and decide and document dependencies (`docs/dependency/`).
2. **Rule Enforcement:** Update this `CLAUDE.md` file to add specific coding guidelines, lint rules, or architectural boundaries as the project evolves, deciding low level design patterns to use and how to make sure code is simple, easy to read/understand and comment formats. You will decide how code should look like for a feature/whole forward/document it so that cursor can follow.
3. **Write Skills:** Build and update automated skills/scripts or checklists that govern how code should be evaluated.
4. **Asynchronous Code Review:** When asked to review code, read the changed files in the git staging area or specific feature directories. Evaluate them against docs/low-level-design/ and provide a concrete "Pass/Fail" checklist with required structural corrections.
5. **Testing** Add proper testing guidelines in (`docs/testing/`). How unit tests should integrated and how load, volume and end-to-end testing should be achieved.
6. **Deployment & CI/CD** Decide on deployments and CI/CD pipeline.
7  **Guardrail Coding:** If asked to write code, provide ONLY high-level skeletal interfaces, abstractions, or mock test definitions. Leave full implementation to Cursor.
8  **Server Lags & Drift Escalation (Backend Sync):** If you discover that a required client feature (e.g., a specific shop layout mutation, new item trait, or economy rule) is missing or unsupported by the Go backend server code at `../sync-grid`, you must immediately halt feature progression. Generate a comprehensive, highly technical file or local GitHub Issue detailing the exact data structures, database mutations, and API endpoints needed on the Go backend so that a Cursor Agent can step into the backend repository and implement them immediately.

---

## 💻 Cursor Role: Lead Implementation Engineer
You operate inside the IDE. You own code generation, file refactoring, local builds, and fixing compiler/runtime errors. You DO NOT alter system architecture.

### Your Explicit Responsibilities:
1. **Strict Adherence:** You must read `CLAUDE.md` and any design documents located in `docs/` and look into `design-diagram/` where high level design diagrams are present, before generating code. You have ZERO authority to change the patterns established by Claude Code.
2. **Feature Implementation:** Write clean, production-ready, well-tested code that completely satisfies the blueprints.
3. **Local Loop Execution:** Compile code, run local test suites (`go test`, `npm test`, etc.), fix syntax/linting issues, and handle multi-file imports.
4. **Testing** Integrate testing as defined in (`docs/testing/`).
5. **Review Readiness:** Once implementation is complete and local tests pass, present a clean summary of the modified files to the user so they can switch to Claude Code for the final architectural review. Do not consider a feature "Done" until Claude Code passes it.
6. **GitHub-First Workflow:** Before writing code for any feature or bug, you MUST check local or remote GitHub issues using the `gh` CLI.
    - If an issue does not exist, use the `gh issue create` command to create it with details derived from the design document.
    - Create a corresponding feature branch named `feature/issue-[number]-short-description` using `git checkout -b` from base working branch like `main`.
    - Perform all development strictly on this feature branch so that Claude Code has a clean branch to review.
7 **No Structural Drift:** If an implementation requires a change to the core database schema or API design, stop and instruct the user to consult Claude Code first.
---

## 🔄 Interaction Protocol
- **Claude Code** writes the "What" and "Why" into markdown/docs.
- **Cursor** reads the markdown/docs and writes the "How" into code files.

## 🛠️ Feature Lifecycle & Discussion Protocol

When the user introduces a new project, component, or feature, you MUST guide them through this exact 3-phase lifecycle. Do not skip straight to code generation.

### Phase 1: The Context Dump (Knowledge Sharing)
- **Your Trigger:** The user says "Let's design [Feature]" or hands you raw business requirements.
- **Your Action:** Stop. Do NOT write any files yet. Analyze the constraints (throughput, data scale, tech stack).
- **Your Output:** Respond with exactly 3 to 5 deeply technical clarifying questions targeting edge cases, data retention/persistence requirements, fault tolerance, and system failure modes.

### Phase 2: The Adversarial Architecture Review
- **Your Trigger:** The user answers your Phase 1 questions.
- **Your Action:** Author the Product Requirements Document in `docs/prd/` and the High-Level Design in `docs/high-level-design/`.
- **Your Constraint:** You must include a dedicated **"Trade-offs and Risks"** section in the HLD. Play devil's advocate against your own design: analyze exactly how it could fail under a 5x load spike, network partitions, or downstream bottlenecks, and document the mitigations.

### Phase 3: The Blueprint Hand-off & Cursor Command
- **Your Trigger:** The user reviews and approves the HLD/LLD.
- **Your Action:** Author the concrete interfaces, error-handling contracts, simple coding patterns, and comment formats inside `docs/low-level-design/`.
- **Your Output:** Conclude the session by outputting a precise, single-sentence command block that the user can copy-paste directly into Cursor Agent to initiate implementation (referencing the newly created documents via `@`).

## PR Review Protocol (Claude Code, Lead Architect)

How Claude Code reviews every client PR before it can merge.
The verdict is a pass/fail checklist against the governing LLD's review acceptance checklist in `docs/low-level-design/`; "Done" requires a pass.

1. **Gather**: `gh pr view <n>` + `gh pr diff <n>`; the PR diff is the only scope.
   Check out the branch into a scratch worktree so post-change scenes can be run without touching the main checkout.
2. **Dynamic verification is mandatory, not optional**:
   `godot --headless --path . --import` (refresh the class cache), then the headless boot check, then every affected preview harness in offline mode with `SYNGRID_SCREENSHOT`, and LOOK at the screenshots - a blank or broken frame is a failure.
   When the feature's server dependencies are merged, also run the live harness modes (`SYNGRID_LIVE=1`) and `tests/ApiE2E.tscn` against a running server.
3. **Static review angles**: line-by-line correctness (typed-array `.assign()`, lambda by-value capture, int64-as-string conversions, signal connect/disconnect balance); removed-behavior audit; cross-file trace of every touched signal and autoload; reuse (SynGridPalette/ThemeBuilder/existing components before new ones); simplification; juice-contract compliance (no LINEAR tweens on scale/position/rotation, stagger rhythm, SFX matrix only - no invented audio events, no glass behind live numbers); conventions (this file plus the user-global CLAUDE.md, including plain-dash-only typography).
4. **Verdict**: blockers (LLD/acceptance violations, contract breaches, crashes) separated from non-blocking improvements; pre-existing gaps become new issues, not PR blockers.
   Every blocker names the file/line, the failure scenario, and the required fix direction.
5. **Post**: `gh pr review <n> --request-changes|--approve --body-file <review.md>`; GitHub forbids formal verdicts on a same-account PR - fall back to `gh pr review <n> --comment` with the verdict in the body, which carries the same authority under this workflow.
6. **Cleanup**: remove the scratch worktree.

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
│   ├── grid_prep/              # GridPrepScene.tscn - merged prep screen (shop + grid placement)
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
| C4 | Shop flow - roll pop, buy/sell, triple-merge (merged into GridPrepScene) | Complete |
| C5 | GridPrepScene - single prep screen: shop row + drag-drop placement + synergy glow | Complete |
| C6 | CombatReplayScene - event queue, sprite lunge, screen shake, damage floats | Complete |
| C7 | RoundEndScene - win/loss banner, life hearts, triumph orbs | Complete |
| C8 | LeaderboardScene + SeasonScene | Complete |
| C9 | AudioManager - BGM cross-fade, full SFX event matrix | Pending |
| C10 | Item/HUD icon sprites + rounded neon-glass theme pass | Pending |
| C11 | Android export, release build pipeline | Pending |

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
SYNGRID_SCREENSHOT=/tmp/out.png godot --path . --resolution 540x960 scenes/combat_replay/CombatReplayPreviewHarness.tscn
SYNGRID_SCREENSHOT=/tmp/out.png SYNGRID_RESULT=win godot --path . --resolution 540x960 scenes/round_end/RoundEndPreviewHarness.tscn
SYNGRID_SCREENSHOT=/tmp/out.png SYNGRID_RESULT=loss godot --path . --resolution 540x960 scenes/round_end/RoundEndPreviewHarness.tscn
SYNGRID_SCREENSHOT=/tmp/out.png SYNGRID_RESULT=dead godot --path . --resolution 540x960 scenes/round_end/RoundEndPreviewHarness.tscn
SYNGRID_SCREENSHOT=/tmp/out.png SYNGRID_RESULT=victory godot --path . --resolution 540x960 scenes/round_end/RoundEndPreviewHarness.tscn
SYNGRID_SCREENSHOT=/tmp/out.png godot --path . --resolution 540x960 scenes/leaderboard/LeaderboardPreviewHarness.tscn

# Export Android debug APK (requires export templates installed)
godot --headless --export-debug "Android" export/syn-grid-debug.apk
```
