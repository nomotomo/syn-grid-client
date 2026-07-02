# Graph Report - .  (2026-07-02)

## Corpus Check
- 24 files · ~8,043 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 99 nodes · 233 edges · 20 communities (15 shown, 5 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 8 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Audio Synthesis Primitives|Audio Synthesis Primitives]]
- [[_COMMUNITY_Client Architecture Skill|Client Architecture Skill]]
- [[_COMMUNITY_SFX Generators & Envelopes|SFX Generators & Envelopes]]
- [[_COMMUNITY_Juice Design Contract|Juice Design Contract]]
- [[_COMMUNITY_Audio Soundscape System|Audio Soundscape System]]
- [[_COMMUNITY_Shop & Triumph SFX|Shop & Triumph SFX]]
- [[_COMMUNITY_Combat BGM & Shield SFX|Combat BGM & Shield SFX]]
- [[_COMMUNITY_Ranged Strike & Karplus|Ranged Strike & Karplus]]
- [[_COMMUNITY_Combat Log Visual Layer|Combat Log Visual Layer]]
- [[_COMMUNITY_Elastic Tweening & Grid UX|Elastic Tweening & Grid UX]]
- [[_COMMUNITY_Placeholder Audio Pipeline|Placeholder Audio Pipeline]]
- [[_COMMUNITY_REST API & ApiClient|REST API & ApiClient]]
- [[_COMMUNITY_Pixel Font & Licensing|Pixel Font & Licensing]]
- [[_COMMUNITY_WAV Output Pipeline|WAV Output Pipeline]]
- [[_COMMUNITY_App Icon & Branding|App Icon & Branding]]
- [[_COMMUNITY_Juice Manual Cross-Ref|Juice Manual Cross-Ref]]
- [[_COMMUNITY_Auth & GameState|Auth & GameState]]
- [[_COMMUNITY_Grid Snap SFX|Grid Snap SFX]]
- [[_COMMUNITY_Combat Replay Scene|Combat Replay Scene]]
- [[_COMMUNITY_Repository Root|Repository Root]]

## God Nodes (most connected - your core abstractions)
1. `samples()` - 21 edges
2. `osc()` - 19 edges
3. `decay_env()` - 17 edges
4. `place()` - 16 edges
5. `noise()` - 14 edges
6. `lowpass()` - 13 edges
7. `bgm_combat()` - 13 edges
8. `sweep()` - 12 edges
9. `sfx_melee_strike()` - 11 edges
10. `bgm_prep()` - 11 edges

## Surprising Connections (you probably didn't know these)
- `Project Syn-Grid Juice Aesthetic Spec (PDF design reference)` --semantically_similar_to--> `Juice & Presentation Contract (authoritative client-side design spec, juice_manual.md)`  [INFERRED] [semantically similar]
  docs/Project_Syn_Grid_Juice_Aesthetic_Spec.pdf → docs/juice_manual.md
- `AudioManager autoload (BGM cross-fade, SFX load-on-demand cache, bus filter control)` --semantically_similar_to--> `Soundscapes & Acoustic Architecture (audio = 50% perceived weight, events triggered by server fields)`  [INFERRED] [semantically similar]
  .claude/skills/client-architecture.md → docs/juice_manual.md
- `CombatLogPlayer (queue + timer pattern, 0.10s tick interval, 2-frame hit-stop on crit)` --semantically_similar_to--> `Combat Log Visual Interpretation Layer (queue + 0.10s timer, sprite lunge, hit-stop, screen shake)`  [INFERRED] [semantically similar]
  .claude/skills/client-architecture.md → docs/juice_manual.md
- `Synergy Glow Shader (synergy_glow.gdshader, glow_intensity uniform from modifier_pct)` --semantically_similar_to--> `Shader Synergy Glows (fragment shader neon plasma gradient, glow_intensity from modifier_pct, 2Hz cycle)`  [INFERRED] [semantically similar]
  .claude/skills/client-architecture.md → docs/juice_manual.md
- `2x2 Grid Visual Motif` --conceptually_related_to--> `Project Syn-Grid Godot 4 Client`  [INFERRED]
  assets/sprites/ui/icon.svg → CLAUDE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Syn-Grid Client Autoloads** — root_claude_apiclient_autoload, root_claude_gamestate_autoload, root_claude_audiomanager_autoload [EXTRACTED 1.00]

## Communities (20 total, 5 thin omitted)

### Community 0 - "Audio Synthesis Primitives"
Cohesion: 0.18
Nodes (24): ndarray, bgm_prep(), kick(), lowpass(), osc(), Soft card-lift whoosh., Explosive metallic slice, immediate decay., Staff hum / spell whoosh. (+16 more)

### Community 1 - "Client Architecture Skill"
Cohesion: 0.31
Nodes (9): ApiClient autoload (all HTTP calls, emits typed signals per RPC), Autoload Hierarchy (four fixed autoloads: GameState, ApiClient, AudioManager, ScreenEffects), Export Variables Pattern (every designer-tunable constant must be @export), GameState autoload (session data: token, round, gold, life, triumph, item lists), Item State Ownership (client owns placement coords; server authoritative on bench contents), Scene Structure (six self-contained game screens), ScreenEffects autoload (camera shake, white flash, screen overlay effects), Network Layer Signal Contract (ApiClient signals, rpc_name_completed/failed naming) (+1 more)

### Community 2 - "SFX Generators & Envelopes"
Cohesion: 0.32
Nodes (8): decay_env(), place(), Rising synth chime; pitch_scale ascends further per modifier_pct., Rising chime + particle-impact sparkle., Ascending 3-note victory chime., sfx_synergy_link(), sfx_triple_merge(), sfx_win_round()

### Community 3 - "Juice Design Contract"
Cohesion: 0.29
Nodes (7): Project Syn-Grid Juice Aesthetic Spec (PDF design reference), Asset Sourcing Guide (Sonniss GDC free, OpenGameArt CC0, itch.io bundles, budget Rs 15k-30k), Juice & Presentation Contract (authoritative client-side design spec, juice_manual.md), Implementation Checklist (14-item verification gate before marking any scene complete), Shader Synergy Glows (fragment shader neon plasma gradient, glow_intensity from modifier_pct, 2Hz cycle), UI Layout Paradigm (dark-first bento-grid, glassmorphic panels banned on live numbers), Synergy Glow Shader (synergy_glow.gdshader, glow_intensity uniform from modifier_pct)

### Community 4 - "Audio Soundscape System"
Cohesion: 0.40
Nodes (5): BGM Tracks (two 30-45s loops; prep/shop dark synthwave, combat percussive chiptune; 0.8s cross-fade), SFX Event Matrix (14 events: shop reroll, synergy link, grid snap, drag pickup, melee/ranged/arcane fire, crit, shield absorb, hp loss, fatal hp, triple-merge, win, triumph), Soundscapes & Acoustic Architecture (audio = 50% perceived weight, events triggered by server fields), AudioManager autoload (BGM cross-fade, SFX load-on-demand cache, bus filter control), Game UI Skill (juice & presentation contract pointer)

### Community 5 - "Shop & Triumph SFX"
Cohesion: 0.60
Nodes (4): highpass(), High-freq wooden dice clatter + mechanical metallic notch., sfx_shop_reroll(), sfx_triumph_milestone()

### Community 6 - "Combat BGM & Shield SFX"
Cohesion: 0.40
Nodes (5): bgm_combat(), noise(), Dense low-freq iron chime with a distinct ring-out trail., Percussive chiptune / synthwave, 128 BPM, 16 bars = 30s seamless loop., sfx_shield_absorb()

### Community 7 - "Ranged Strike & Karplus"
Cohesion: 0.50
Nodes (5): karplus(), Bow twang / crossbow snap., Karplus-Strong plucked string - the bow twang., samples(), sfx_ranged_strike()

### Community 8 - "Combat Log Visual Layer"
Cohesion: 0.50
Nodes (4): Combat Log Visual Interpretation Layer (queue + 0.10s timer, sprite lunge, hit-stop, screen shake), Floating Damage Indicators (-15 to +15 degree arc, 1.8x crit scale, crimson outline on crit), Screen Shake Severity (damage/max_hp * BASE_SCALAR 12.0, 2.5x on crit, 1-frame white flash), CombatLogPlayer (queue + timer pattern, 0.10s tick interval, 2-frame hit-stop on crit)

### Community 9 - "Elastic Tweening & Grid UX"
Cohesion: 0.50
Nodes (4): Drag-and-Drop Tilt (velocity-based rotation clamp, 0.65 lerp lag, TRANS_SPRING on drop), Elastic Easing & Tweens (no LINEAR; TRANS_ELASTIC overshoot on all scale/position/rotation), Grid Snap Bounce (Y-squish 1.0->0.75->1.05->1.0, teal CPUParticles2D ring on valid placement), Shop Card Roll Pop (0->1.1->1.0 scale, TRANS_ELASTIC, 0.04s stagger per card)

### Community 10 - "Placeholder Audio Pipeline"
Cohesion: 0.67
Nodes (3): generate_placeholder_audio.py, Placeholder Audio Assets, AudioManager Autoload

### Community 11 - "REST API & ApiClient"
Cohesion: 0.67
Nodes (3): grpc-gateway JSON Bridge, Syn-Grid REST API Contract, ApiClient Autoload Singleton

### Community 12 - "Pixel Font & Licensing"
Cohesion: 0.67
Nodes (3): SIL Open Font License 1.1, Press Start 2P Pixel Font, ThemeBuilder.PIXEL_FONT_PATH

### Community 13 - "WAV Output Pipeline"
Cohesion: 0.67
Nodes (3): Path, main(), write_wav()

### Community 14 - "App Icon & Branding"
Cohesion: 0.67
Nodes (3): Project Syn-Grid Godot 4 Client, 2x2 Grid Visual Motif, Syn-Grid App Icon

## Knowledge Gaps
- **27 isolated node(s):** `ScreenEffects autoload (camera shake, white flash, screen overlay effects)`, `Scene Structure (six self-contained game screens)`, `UI Layout Paradigm (dark-first bento-grid, glassmorphic panels banned on live numbers)`, `Shop Card Roll Pop (0->1.1->1.0 scale, TRANS_ELASTIC, 0.04s stagger per card)`, `Drag-and-Drop Tilt (velocity-based rotation clamp, 0.65 lerp lag, TRANS_SPRING on drop)` (+22 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Juice & Presentation Contract (authoritative client-side design spec, juice_manual.md)` connect `Juice Design Contract` to `Combat Log Visual Layer`, `Elastic Tweening & Grid UX`, `Audio Soundscape System`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._
- **Why does `osc()` connect `Audio Synthesis Primitives` to `SFX Generators & Envelopes`, `Shop & Triumph SFX`, `Combat BGM & Shield SFX`, `Ranged Strike & Karplus`, `Grid Snap SFX`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Why does `Client Architecture Skill (Godot 4 hard rules)` connect `Client Architecture Skill` to `Combat Log Visual Layer`, `Juice Design Contract`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **What connects `ScreenEffects autoload (camera shake, white flash, screen overlay effects)`, `Scene Structure (six self-contained game screens)`, `Export Variables Pattern (every designer-tunable constant must be @export)` to the rest of the system?**
  _47 weakly-connected nodes found - possible documentation gaps or missing edges._