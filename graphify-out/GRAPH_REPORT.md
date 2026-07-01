# Graph Report - /Users/saurabhmishra/Desktop/projects/game-development/sync-grid-client  (2026-07-01)

## Corpus Check
- Corpus is ~4,190 words - fits in a single context window. You may not need a graph.

## Summary
- 41 nodes · 58 edges · 9 communities
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.93)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Server API & Data Contracts|Server API & Data Contracts]]
- [[_COMMUNITY_Grid Interaction & Tweening|Grid Interaction & Tweening]]
- [[_COMMUNITY_Combat Replay System|Combat Replay System]]
- [[_COMMUNITY_Project Foundation & Audio Autoload|Project Foundation & Audio Autoload]]
- [[_COMMUNITY_Session Auth & Shop Flow|Session Auth & Shop Flow]]
- [[_COMMUNITY_Juice Design Contract & Checklist|Juice Design Contract & Checklist]]
- [[_COMMUNITY_Network Architecture & Autoloads|Network Architecture & Autoloads]]
- [[_COMMUNITY_Audio Soundscape System|Audio Soundscape System]]
- [[_COMMUNITY_Godot Scene Conventions|Godot Scene Conventions]]

## God Nodes (most connected - your core abstractions)
1. `Syn-Grid REST API Contract (client reference, HTTP/JSON via grpc-gateway)` - 10 edges
2. `Juice & Presentation Contract (authoritative client-side design spec, juice_manual.md)` - 10 edges
3. `Client Architecture Skill (Godot 4 hard rules)` - 7 edges
4. `GameState autoload (session data: token, round, gold, life, triumph, item lists)` - 6 edges
5. `Project Syn-Grid Godot 4 Client (pure presentation layer, CLAUDE.md)` - 6 edges
6. `Autoload Hierarchy (four fixed autoloads: GameState, ApiClient, AudioManager, ScreenEffects)` - 5 edges
7. `ApiClient autoload (all HTTP calls, emits typed signals per RPC)` - 5 edges
8. `Game UI Skill (juice & presentation contract pointer)` - 4 edges
9. `Elastic Easing & Tweens (no LINEAR; TRANS_ELASTIC overshoot on all scale/position/rotation)` - 4 edges
10. `Combat Log Visual Interpretation Layer (queue + 0.10s timer, sprite lunge, hit-stop, screen shake)` - 4 edges

## Surprising Connections (you probably didn't know these)
- `Project Syn-Grid Juice Aesthetic Spec (PDF design reference)` --semantically_similar_to--> `Juice & Presentation Contract (authoritative client-side design spec, juice_manual.md)`  [INFERRED] [semantically similar]
  docs/Project_Syn_Grid_Juice_Aesthetic_Spec.pdf → docs/juice_manual.md
- `AudioManager autoload (BGM cross-fade, SFX load-on-demand cache, bus filter control)` --semantically_similar_to--> `Soundscapes & Acoustic Architecture (audio = 50% perceived weight, events triggered by server fields)`  [INFERRED] [semantically similar]
  .claude/skills/client-architecture.md → docs/juice_manual.md
- `CombatLogPlayer (queue + timer pattern, 0.10s tick interval, 2-frame hit-stop on crit)` --semantically_similar_to--> `Combat Log Visual Interpretation Layer (queue + 0.10s timer, sprite lunge, hit-stop, screen shake)`  [INFERRED] [semantically similar]
  .claude/skills/client-architecture.md → docs/juice_manual.md
- `Synergy Glow Shader (synergy_glow.gdshader, glow_intensity uniform from modifier_pct)` --semantically_similar_to--> `Shader Synergy Glows (fragment shader neon plasma gradient, glow_intensity from modifier_pct, 2Hz cycle)`  [INFERRED] [semantically similar]
  .claude/skills/client-architecture.md → docs/juice_manual.md
- `Project Syn-Grid Godot 4 Client (pure presentation layer, CLAUDE.md)` --references--> `Project Syn-Grid Juice Aesthetic Spec (PDF design reference)`  [EXTRACTED]
  CLAUDE.md → docs/Project_Syn_Grid_Juice_Aesthetic_Spec.pdf

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Client Communication Pattern (autoload hierarchy + signal contract + scene structure form the decoupled Godot communication architecture)** — skills_client_architecture_autoload_hierarchy, skills_client_architecture_signal_contract, skills_client_architecture_scene_structure [EXTRACTED 1.00]
- **Combat Replay Presentation (CombatLogPlayer + screen shake + damage floats together implement the full combat replay visual layer)** — skills_client_architecture_combat_log_player, docs_juice_manual_screen_shake, docs_juice_manual_damage_floats [INFERRED 0.95]
- **Juice Contract Pillars (elastic tweening + synergy shader + soundscapes are the three non-negotiable pillars of the presentation contract)** — docs_juice_manual_elastic_tweening, docs_juice_manual_synergy_shader, docs_juice_manual_soundscapes [INFERRED 0.85]

## Communities (9 total, 0 thin omitted)

### Community 0 - "Server API & Data Contracts"
Cohesion: 0.33
Nodes (7): Go Server (../sync-grid, server-authoritative game logic, PostgreSQL + Redis), grpc-gateway bridge (HTTP/JSON translation layer on Go server port 8080), Error Handling (gRPC-gateway ErrorInfo with SCREAMING_SNAKE_CASE reason field), Grid Object (player_id, current_round, life_points, triumph_count, gold_balance, equipped_items, bench_reserve), Item Object (item_id, name, level, dimensions, placement_coords, item_type, weapon_category, base_attributes), Leaderboard & Season RPCs (get_leaderboard, get_active_season), Syn-Grid REST API Contract (client reference, HTTP/JSON via grpc-gateway)

### Community 1 - "Grid Interaction & Tweening"
Cohesion: 0.29
Nodes (7): ValidateGrid RPC (POST /v1/validate_grid, returns active synergies with modifier_pct), Drag-and-Drop Tilt (velocity-based rotation clamp, 0.65 lerp lag, TRANS_SPRING on drop), Elastic Easing & Tweens (no LINEAR; TRANS_ELASTIC overshoot on all scale/position/rotation), Grid Snap Bounce (Y-squish 1.0->0.75->1.05->1.0, teal CPUParticles2D ring on valid placement), Shop Card Roll Pop (0->1.1->1.0 scale, TRANS_ELASTIC, 0.04s stagger per card), Shader Synergy Glows (fragment shader neon plasma gradient, glow_intensity from modifier_pct, 2Hz cycle), Synergy Glow Shader (synergy_glow.gdshader, glow_intensity uniform from modifier_pct)

### Community 2 - "Combat Replay System"
Cohesion: 0.40
Nodes (5): Combat RPCs (start_match returns CombatLog; award_round_gold; finalize_round), Combat Log Visual Interpretation Layer (queue + 0.10s timer, sprite lunge, hit-stop, screen shake), Floating Damage Indicators (-15 to +15 degree arc, 1.8x crit scale, crimson outline on crit), Screen Shake Severity (damage/max_hp * BASE_SCALAR 12.0, 2.5x on crit, 1-frame white flash), CombatLogPlayer (queue + timer pattern, 0.10s tick interval, 2-frame hit-stop on crit)

### Community 3 - "Project Foundation & Audio Autoload"
Cohesion: 0.50
Nodes (4): Project Syn-Grid Godot 4 Client (pure presentation layer, CLAUDE.md), Project Syn-Grid Juice Aesthetic Spec (PDF design reference), AudioManager autoload (BGM cross-fade, SFX load-on-demand cache, bus filter control), Game UI Skill (juice & presentation contract pointer)

### Community 4 - "Session Auth & Shop Flow"
Cohesion: 0.50
Nodes (4): Authentication RPC (POST /v1/authenticate, device_id -> HMAC token, stored in GameState.token), Shop RPCs (roll_shop, purchase_item, sell_item; deterministic roll per player+round), GameState autoload (session data: token, round, gold, life, triumph, item lists), Item State Ownership (client owns placement coords; server authoritative on bench contents)

### Community 5 - "Juice Design Contract & Checklist"
Cohesion: 0.50
Nodes (4): Asset Sourcing Guide (Sonniss GDC free, OpenGameArt CC0, itch.io bundles, budget Rs 15k-30k), Juice & Presentation Contract (authoritative client-side design spec, juice_manual.md), Implementation Checklist (14-item verification gate before marking any scene complete), UI Layout Paradigm (dark-first bento-grid, glassmorphic panels banned on live numbers)

### Community 6 - "Network Architecture & Autoloads"
Cohesion: 0.50
Nodes (4): ApiClient autoload (all HTTP calls, emits typed signals per RPC), Autoload Hierarchy (four fixed autoloads: GameState, ApiClient, AudioManager, ScreenEffects), ScreenEffects autoload (camera shake, white flash, screen overlay effects), Network Layer Signal Contract (ApiClient signals, rpc_name_completed/failed naming)

### Community 7 - "Audio Soundscape System"
Cohesion: 0.67
Nodes (3): BGM Tracks (two 30-45s loops; prep/shop dark synthwave, combat percussive chiptune; 0.8s cross-fade), SFX Event Matrix (14 events: shop reroll, synergy link, grid snap, drag pickup, melee/ranged/arcane fire, crit, shield absorb, hp loss, fatal hp, triple-merge, win, triumph), Soundscapes & Acoustic Architecture (audio = 50% perceived weight, events triggered by server fields)

### Community 8 - "Godot Scene Conventions"
Cohesion: 0.67
Nodes (3): Export Variables Pattern (every designer-tunable constant must be @export), Scene Structure (six self-contained game screens), Client Architecture Skill (Godot 4 hard rules)

## Knowledge Gaps
- **13 isolated node(s):** `ScreenEffects autoload (camera shake, white flash, screen overlay effects)`, `Scene Structure (six self-contained game screens)`, `Leaderboard & Season RPCs (get_leaderboard, get_active_season)`, `Error Handling (gRPC-gateway ErrorInfo with SCREAMING_SNAKE_CASE reason field)`, `UI Layout Paradigm (dark-first bento-grid, glassmorphic panels banned on live numbers)` (+8 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Juice & Presentation Contract (authoritative client-side design spec, juice_manual.md)` connect `Juice Design Contract & Checklist` to `Grid Interaction & Tweening`, `Combat Replay System`, `Project Foundation & Audio Autoload`, `Audio Soundscape System`?**
  _High betweenness centrality (0.413) - this node is a cross-community bridge._
- **Why does `Syn-Grid REST API Contract (client reference, HTTP/JSON via grpc-gateway)` connect `Server API & Data Contracts` to `Grid Interaction & Tweening`, `Combat Replay System`, `Project Foundation & Audio Autoload`, `Session Auth & Shop Flow`?**
  _High betweenness centrality (0.306) - this node is a cross-community bridge._
- **Why does `Project Syn-Grid Godot 4 Client (pure presentation layer, CLAUDE.md)` connect `Project Foundation & Audio Autoload` to `Server API & Data Contracts`, `Juice Design Contract & Checklist`, `Network Architecture & Autoloads`?**
  _High betweenness centrality (0.236) - this node is a cross-community bridge._
- **What connects `ScreenEffects autoload (camera shake, white flash, screen overlay effects)`, `Scene Structure (six self-contained game screens)`, `Export Variables Pattern (every designer-tunable constant must be @export)` to the rest of the system?**
  _14 weakly-connected nodes found - possible documentation gaps or missing edges._