# Syn-Grid Client — PRD

## Original problem statement
> "Can you look into repository and check if you can improve the visuals icons theme UI/UX of this game app… I want to improve the UI/UX and theme for gameplay… lay out a better theme for game and user experiences."

## Product context
Syn-Grid is a portrait-mobile (1080×1920) Godot 4 auto-battler client for an asymmetric asynchronous inventory-management game. All game logic lives on a Go server; the client's only jobs are (1) render server responses as juicy visual sequences, (2) let the player arrange items on a grid and submit, (3) call the REST API through a single autoload. Design contract is `docs/juice_manual.md` — non-negotiable rules on tweens, glassmorphism, particle rings, combat log cadence, SFX matrix, etc.

## User persona
Mobile strategy-game player, one-thumb portrait, expects modern juice (elastic pops, glow shaders, staggered reveals) plus a dark-fantasy / cyber aesthetic that reads instantly and is legible under any lighting.

## Static core requirements
- **Portrait mobile Godot 4 client** (1080×1920 viewport, GDScript only, no C#).
- All colors flow from `scripts/ui/SynGridPalette.gd`; all theme resource construction flows from `scripts/ui/ThemeBuilder.gd`. **No hardcoded hex** in scenes or scripts.
- **No LINEAR tweens** on any visible property (juice manual §2).
- **No glassmorphic layers** behind live numeric values (juice manual §1).
- **No new autoloads**, no C#, no server-URL hardcoding.
- Reuse the existing `SynergyBorder` fragment shader for synergy glow; never draw static Line2Ds.

## Session #1 — "Neon Grimoire" theme pass  (Jan 2026)

### What was implemented
- **Extended palette** (`scripts/ui/SynGridPalette.gd`): added VOID (L0 wells), PANEL_BG_HOVER (L3 interactive), ACCENT_AMBER, ACCENT_SILVER, PARCHMENT text primary, BORDER_HIGHLIGHT, plus 4 tier colors (`tint_for_tier(level)`). Old constants preserved so no existing call-site breaks.
- **Rebuilt ThemeBuilder** with a 4-rung elevation ladder (VOID → PANEL_BG → ELEVATED → HOVER), richer button state matrix (normal / hover / pressed / focus / disabled — each with correct border colour, glow, and text colour), a new capsule pill stylebox (`build_capsule_style`) for the HUD, a new button stylebox (`build_button_style`) with 12 px radius, and a new `StatPipLabel` variation.
- **Redesigned HUD (`StatsHud`)**: four capsule pills, each with a coloured accent bar (silver ROUND / gold GOLD / teal LIFE / purple TRIUMPH), a 28 px pixel icon on the left, and a monospaced number on the right. Kept the existing count-up scale-pop on value changes.
- **Redesigned ItemCard**: tier-coloured panel border (bronze/silver/gold/epic — driven by server-supplied `level`), category-tint radial background wash (warm crimson / forest / purple / steel per weapon category), tier chip (top-right, roman numeral), cost chip (top-left, shop only), stat-pip row (`A 45   D 12   S 8` — attack / defense / speed pulled from server `base_attributes`). All existing signals, drag/tilt, snap-bounce, and pop juice preserved.
- **Main-menu backdrop shader** (`assets/shaders/arcane_rune_field.gdshader`): drifting field of dim teal rune glyphs (four variants) with rare purple ping cells. Vignetted so the CTAs above stay dominant. Materialised on `MainMenu`'s Background ColorRect.
- **Regenerated every broken/inconsistent sprite** via `tools/generate_theme_sprites.py`:
  - HUD icons — gold coin, crystal-heart LIFE, laurel-ring triumph orb (**was blank**), new compass ROUND icon.
  - Rank badges — bronze / silver / gold circular medals with laurel ring + roman numeral core (**all three were blank**).
  - App icon (128×128 SVG) redrawn with the grid + rune identity.
  - Item roster expanded from 8 → 16 (added dagger, war_hammer, greatsword, crossbow, frost_orb, tome, tower_shield, chain_mail); all 16 standardised to 64×64 3-tone pixel art with a subtle category tint.
  - Effects — ring / spark / dot / hitmark particle textures added to previously-empty `assets/sprites/effects/`.
- **Round-end hearts and triumph orbs** now use the new pixel-art sprites instead of raw ColorRect diamonds — hearts read as hearts, orbs read as prestige laurels, empty states are dimmed silhouettes.
- **Pre-existing Godot 4.7-only API guard**: `CPUParticles2D.EMISSION_SHAPE_RING` in `GridPrepScene.gd` + `RoundEndScene.gd` gated behind a runtime `"emission_ring_radius" in particles` check with a `SPHERE_SURFACE` fallback so the scenes open on Godot 4.5 stable (unblocks headless preview rendering).

### Proof
Rendered via headless Godot 4.5 + Xvfb using the existing `SYNGRID_SCREENSHOT` preview harnesses. Six side-by-side comparisons in `/screenshots/compare/`:
- `compare_main_menu.png` — capsule HUD + arcane rune-field backdrop
- `compare_grid_prep.png` — category-tint item cards, tier chips, socket grid
- `compare_combat_replay.png` — tinted cards visible on the combat pane
- `compare_round_end_win.png` — real hearts + laurel orbs replace red diamonds
- `compare_round_end_loss.png` — same, loss variant
- `compare_leaderboard.png` — real rank medals in the top-3 plinths

### Files changed
- `scripts/ui/SynGridPalette.gd` (extended)
- `scripts/ui/ThemeBuilder.gd` (rewritten with capsule + button variants)
- `scripts/ui/ItemCard.gd`, `scenes/ui/ItemCard.tscn` (tier ring + tint bg + pips)
- `scripts/ui/StatsHud.gd`, `scenes/ui/StatsHud.tscn` (capsule pills)
- `scenes/main_menu/MainMenu.tscn` (rune-field ShaderMaterial on background)
- `scenes/round_end/RoundEndScene.gd` (pixel-art hearts + orbs, particle ring fallback)
- `scenes/grid_prep/GridPrepScene.gd` (particle ring fallback)
- `assets/shaders/arcane_rune_field.gdshader` (new)
- `assets/sprites/ui/*.png` (icons + badges regenerated)
- `assets/sprites/ui/icon.svg` (app icon)
- `assets/sprites/items/*.png` (16-item roster, all 64×64)
- `assets/sprites/effects/*.png` (new: ring/spark/dot/hitmark)
- `tools/generate_theme_sprites.py` (new: reproducible sprite regeneration)
- `.gitignore` (adds `/screenshots/`)

## Session #2 — P1 backlog cleared  (Jan 2026)

### What was implemented (all 5 from the last "Next Action Items" list)

1. **Bottom-nav tab bar on the main menu** — `HOME | RANKS | SEASON | PROFILE`, thumb-reachable at the bottom, HOME styled active (teal border + glow + teal text). RANKS opens the leaderboard, PROFILE opens the callsign popover, SEASON currently sets a "COMING SOON" status until Phase C9 sound + Phase C11 export land. The old standalone `LeaderboardButton` is hidden (kept in the tree to avoid script rewrites but `visible = false`).
2. **Circular round-timer ring on Combat Replay** — new `assets/shaders/round_timer_ring.gdshader`, 64×64 ColorRect at the top-centre of `CombatReplayScene.tscn`. Colour smoothly transitions `ACCENT_TEAL → ACCENT_AMBER (< 30%) → DANGER (< 10%)` and pulses at 2 Hz below the danger threshold. `_update_round_timer_progress(current_tick, total_ticks)` is called on every `_on_event_played` so the ring stays in lock-step with the log playback.
3. **Empty-cell "+" glyph + danger-crimson invalid-drop pulse** — `GridCell.gd` now spawns a `+` Label child at 18% alpha on empty cells (auto-hidden the moment an ItemCard is added, via `child_entered_tree`/`child_exiting_tree`). `highlight()` gained a `valid: bool` parameter; when the drag hovers an occupied cell, the border pulses `DANGER` crimson at a faster period (0.3 s vs 0.5 s) so the player never wastes a drop release. `GridPrepScene.gd` wires `hover.highlight(true, not hover.has_card())`.
4. **Leaderboard top-3 badges enlarged with per-tier glow** — `_make_rank_badge()` bumped from 28×28 to **72×72**, added a same-color outer glow ColorRect at 35% alpha, and dropped the `tex.self_modulate` that was tinting the medallion pixels (the regenerated badges already carry their full metallic palette). Row height for ranks 1-3 grew from 68 to 88 px so the medal has breathing room; the rank-label box widened to 152 px.
5. **Aurora border on the main-menu Play button + CRT scanline on the SYN-GRID wordmark** —
   - `assets/shaders/aurora_border.gdshader` renders a teal↔purple gradient orbiting the rim of the button, plus a soft outer halo. Rewritten to be pure-UV (independent of `TEXTURE_PIXEL_SIZE`) so it works on ColorRect overlays with no source texture and on the OpenGL 3 mobile fallback path. Instanced as `AuroraOverlay` inside `PlayButton`, with 4-px negative offsets so the halo bleeds past the button's outer edge.
   - `assets/shaders/crt_scanline.gdshader` applies a subtle scanline + chromatic aberration + soft time-jitter to the `TitleLabel`. Alpha is preserved (the shader is an overlay, not a fill).

### Proof (rendered again through the SYNGRID_SCREENSHOT harnesses)
Four side-by-side compares in `/screenshots/compare2/`:
- `compare2_main_menu.png` — bottom nav + aurora rim + CRT title
- `compare2_grid_prep.png` — empty-cell "+" glyphs on every socket
- `compare2_leaderboard.png` — 72-px medallions with per-tier glow on top-3 rows
- `compare2_combat_replay.png` — circular timer ring visible next to the TICK label

### Files changed / added in this session
- `scenes/main_menu/MainMenu.tscn` (aurora sub_resource, CRT sub_resource, `AuroraOverlay` child on `PlayButton`, hidden legacy `LeaderboardButton`, new `BottomNav` panel with 4 tabs, `Margin.margin_bottom` grew from 48 to 140 to reserve nav space)
- `scenes/main_menu/MainMenu.gd` (`_home_tab / _leaderboard_tab / _season_tab / _profile_tab` @onreadys, wired tab pressed signals, `_style_active_tab()`, `_on_home_tab_pressed`, `_on_season_tab_pressed`, `_on_profile_tab_pressed`)
- `scenes/grid_prep/GridCell.gd` (empty "+" Label child, `highlight(on, valid)` signature, danger pulse for invalid targets)
- `scenes/grid_prep/GridPrepScene.gd` (hover.highlight call passes validity)
- `scenes/combat_replay/CombatReplayScene.tscn` (timer ring sub_resource + `%RoundTimerRing` ColorRect at top)
- `scenes/combat_replay/CombatReplayScene.gd` (`_update_round_timer_progress()` + calls from `load_and_start_replay` and `_on_event_played`)
- `scenes/leaderboard/LeaderboardScene.gd` (rank badge 28→72 px, glow overlay, removed self_modulate tint, taller top-3 rows)
- `assets/shaders/aurora_border.gdshader` (new)
- `assets/shaders/crt_scanline.gdshader` (new)
- `assets/shaders/round_timer_ring.gdshader` (new)
- `memory/PRD.md` (this section)

## Session #3 — P2 batch  (Jan 2026)

### What was implemented

1. **Enemy team red arcane-circle floor + friendly team teal floor** on Combat Replay — new `assets/shaders/arcane_circle_floor.gdshader` renders a dashed outer ring + six slowly-rotating rune glyphs + soft radial pool tint. Two `ColorRect` nodes (`%OppFloor` red, `%PlayerFloor` teal) added under each grid area with `show_behind_parent = true` so they render UNDER the grid cells. `_layout_screen()` sizes them 18% larger than the grid so the disc extends past the corners.
2. **Ambient dust particles on the main menu** — new `%AmbientDust` `CPUParticles2D` node using the `assets/sprites/effects/dot.png` texture from the theme sprite regenerator. 5 particles, 14-second lifetime, slow upward-diagonal drift with soft rotation and 28% alpha teal tint. `preprocess = 8.0` means the particles are pre-simulated so they're already scattered when the scene opens (never a "cold start" pop-in).
3. **Grid coordinate labels A/B/C/D + 1/2/3/4** on the deployment grid — new `_build_coord_labels()` in `GridPrepScene.gd`. Column letters drawn 22 px above the top row of cells, row numbers 24 px left of the leftmost column. `CaptionLabel` type variation, teal @ 55% alpha, centered per cell.

### Proof

Rendered through the SYNGRID_SCREENSHOT harnesses:
- `/screenshots/compare3/compare3_combat_replay.png` — visible red dashed circle around opponent grid, teal dashed circle around player grid
- `/screenshots/compare3/compare3_grid_prep.png` — A/B/C/D across top, 1/2/3/4 down left
- `/screenshots/compare3/compare3_main_menu.png` — subtle teal dust specks drifting across the field

### Files changed / added in this session
- `assets/shaders/arcane_circle_floor.gdshader` (new)
- `scenes/combat_replay/CombatReplayScene.tscn` (opp/player floor sub_resources + ColorRect children of grid areas)
- `scenes/combat_replay/CombatReplayScene.gd` (`_opp_floor` / `_player_floor` @onready refs + sizing loop in `_layout_screen()`)
- `scenes/main_menu/MainMenu.tscn` (dust texture ext_resource + `%AmbientDust` CPUParticles2D)
- `scenes/grid_prep/GridPrepScene.gd` (`_build_coord_labels()` called from `_build_cells()`)
- `memory/PRD.md` (this section)

## Session #4 — Battle-page A+B + 3 P2 follow-ups  (Jan 2026)

### Battle-page upgrades (Tier A + Tier B)

**A1. Projectile trails** (`CombatReplayScene._spawn_projectile`)
Line2D streaks fly from the firer's card centre to the impact point over one tick (0.09 s), tapered by animating tail-position 0.06 s behind the head. Category-tinted: RANGED = forest green, ARCANE = purple, MELEE = no projectile (lunge handles it). Crit shots are `lightened(0.35)` and use `width = 5.0` instead of `3.5`.

**A2. Hitmark rings on impact** (`CombatReplayScene._spawn_hitmark`)
Reuses the existing `assets/sprites/effects/hitmark.png` (4-corner brackets). Spawns at 40 % scale, pops to 135 % with `TRANS_ELASTIC`, rotates 12 % of TAU, then fades over 0.22 s. Colour matches hit type: crit = DANGER crimson, pure-shield-absorb = ACCENT_SILVER, normal HP damage = ACCENT_TEAL.

**A3. Muzzle flash at firer** (`CombatReplayScene._spawn_muzzle_flash`)
Reuses `spark.png` at the firer's card centre with a random rotation, category-tinted, scale pop `0.4 → 1.3` with `TRANS_BACK`, fade over 0.16 s.

**B1. Directional camera kick** (`CombatReplayScene._apply_directional_kick`)
Player attacks bounce the screen -8 px on Y over 0.05 s then settle over 0.14 s; opponent attacks bounce +8 px. Uses `_shake_camera.position:y` — ScreenEffects's shake uses `.offset`, so the two channels never fight.

**B2. Battle intro banner** (`CombatReplayScene._play_intro_banner`)
"CALLSIGN\nvs\nOPPONENT" 3-line label pops in at 0.60× scale to 1.00× with `TRANS_ELASTIC`, holds 0.45 s, fades over 0.20 s. Purple outline at 80 % alpha for a "hero card" look. Called from `load_and_start_replay` right before `intro_delay`.

**B3. Killing-blow flash** (`CombatReplayScene._play_killing_blow_effect`)
When `hp_loss > 0` and `target_hp_after <= 0`, spawns a full-viewport `DANGER` crimson wash at 45 % alpha that fades to zero over 0.35 s. Non-blocking, self-frees.

All new helpers live at the bottom of `CombatReplayScene.gd`. A `_projectile_layer: Node2D` (z_index 8) is spun up in `_ready()` as the reparent target for every effect node so scene teardown auto-cleans them.

### 3 P2 follow-ups shipped in the same session

1. **SEASON tab → Season Hub scaffold** — new `scenes/season_hub/SeasonHub.tscn` + `.gd` with a purple-tinted arcane rune-field backdrop, big pixel SEASON HUB title, two capsule cards (SEASON WINDOW countdown, YOUR TRIUMPH value), a "REWARDS LADDER - COMING SOON" placeholder, and a full-width BACK button. `MainMenu._on_season_tab_pressed()` now calls `get_tree().change_scene_to_file()` instead of showing a status. New `SeasonHubPreviewHarness.tscn` for scripted screenshot proof.
2. **Bigger CRT dial** — bumped `scanline_intensity` 0.22 → 0.42, `scanline_frequency` 220 → 260, `chromatic_shift` 0.8 → 1.8, `jitter_rate` 0.35 → 0.55, `jitter_amount` 0.6 → 1.2 on the `CrtMaterial` sub_resource. Result: strong teal/purple colour fringing on every SYN-GRID glyph.
3. **HUD pill tooltips** — added `tooltip_text` on all four `StatsHud` pills (ROUND / GOLD / LIFE / TRIUMPH). Added `TooltipPanel` StyleBox and `TooltipLabel` font-size/colour to `ThemeBuilder` so tooltips render with the same rounded neon-glass look as the pills instead of Godot's default flat popup.

### Files changed / added in this session
- `scenes/combat_replay/CombatReplayScene.gd` (6 new helpers + `_projectile_layer` + intro banner call + directional kick + killing-blow flash)
- `scenes/season_hub/SeasonHub.tscn` (new)
- `scenes/season_hub/SeasonHub.gd` (new)
- `scenes/season_hub/SeasonHubPreviewHarness.tscn` + `.gd` (new — for scripted proof rendering)
- `scenes/main_menu/MainMenu.tscn` (`CrtMaterial` sub_resource tuned)
- `scenes/main_menu/MainMenu.gd` (`_on_season_tab_pressed` routes to SeasonHub)
- `scripts/ui/StatsHud.gd` (tooltip_text on each of the 4 pills)
- `scripts/ui/ThemeBuilder.gd` (TooltipPanel StyleBox + TooltipLabel font styling)
- `memory/PRD.md` (this section)

### Proof
Rendered clean (zero SCRIPT ERRORs on project import):
- `/screenshots/after4_main_menu.png` — visible strong CRT chromatic fringing on SYN-GRID
- `/screenshots/after4_season_hub.png` — new Season Hub scaffold
- `/screenshots/after4_combat_replay.png` — combat scene compiles + arcane floors + timer ring (projectile/hitmark/muzzle effects are transient and only render mid-playback — verified via clean parse but not in a still)

## Session #5 — Tier C battle upgrades + improvements.md  (Jan 2026)

### Tier C battle upgrades shipped

1. **Damage-spark bursts behind floats** — `_spawn_damage_sparks(pos, color, count)` fires 3 dots on normal hits, 5 on crits from the damage-float position outward on random angles at 22–48 px, scaling `1.0 → 0.3` and fading over 0.40 s with `TRANS_QUART` ease-out. Uses the existing `assets/sprites/effects/dot.png`. Colour matches the float: crimson on crit, parchment on normal HP, teal on shield block.
2. **Live hit-counter footer** — new `_hit_counter_footer: Label` created in `_ready()`, anchored `PRESET_BOTTOM_WIDE` with a −34 px offset from the bottom. Displays `N HITS · N CRITS · N KOs` (pieces only appear when the count is >0). Colour ramps by severity: `TEXT_DIM` at baseline, `ACCENT_AMBER` after first crit, `DANGER` after first KO. Every increment triggers a `1.18 → 1.0` elastic scale-pop so peripheral vision picks up the change.

Counters (`_hit_count`, `_crit_count`, `_ko_count`) live as scene-local state, incremented in `_on_event_played()` alongside the existing effect calls. HIT = any event with `hp_loss > 0 OR shield_absorbed > 0`; CRIT stacks on top when `crit == true`; KO stacks when `hp_loss > 0 AND target_hp_after <= 0`.

### `docs/improvements.md` — living backlog document

New 11-section markdown at `/app/docs/improvements.md` covering:

- **Recap** of everything Sessions 1–5 shipped
- **Difficulty legend** (XS / S / M / L / XL)
- **1. Battle Page** — 6 upgrades (slow-motion killing blow, item shake on damage, combat log ticker, item shatter, rewind scrubber, crit zoom-in)
- **2. Grid Prep** — 6 upgrades (synergy preview, best-slot hint, auto-arrange, item compare tooltip, recycler sell preview, synergy activation pulse)
- **3. Main Menu / Meta** — 5 upgrades (Codex screen, rewards ladder preview, rune motif picker, callsign polish, resume-round banner)
- **4. Leaderboard** — 4 upgrades (rank-change indicator, filter chips, tap-row profile card, medallion pulse)
- **5. Round-End** — 4 upgrades (victory typewriter, triumph orb fly-in, defeat desaturation shader, milestone celebration)
- **6. Audio** — 4 upgrades (BGM crossfade, full SFX matrix, crit ducking, defeat LPF)
- **7. Accessibility & UX** — 5 upgrades (reduced motion, high-contrast palette, colour-blind crits, tablet tap targets, haptics)
- **8. Performance / Tech Debt** — 5 items (Godot 4.7→4.5 pin decision, screenshot import cleanup, shader param consolidation, tween safety, sprite atlas)
- **9. Retention / Business Wins** — 5 zero-server ideas (daily login streak, onboarding tour, share-your-grid screenshot, daily challenge, rank-moved toast)
- **10. Fresh polish ideas** — 5 items (card foil animation for high-tier drops, announcer voice-over stubs, level-up flash, loading-screen lore tips, aurora hue A/B)
- **11. My picks** — three curated combos (**"Fight feels alive"**, **"Meta hooks"**, **"Feels premium"**) with per-combo cost + rationale

Each item lists difficulty, files touched, and the player-facing win. Pick single items, combos, or whole sections.

### Files changed / added
- `scenes/combat_replay/CombatReplayScene.gd` (`_PROJECTILE_DOT_TEXTURE` const, counter state, footer label, `_spawn_damage_sparks`, `_refresh_hit_counter`, event-handler counter increments, `_spawn_damage_float` calls sparks)
- `docs/improvements.md` (new)
- `memory/PRD.md` (this section)

### Proof
- `/screenshots/after5_combat_replay.png` — hit counter footer visible at bottom: `"16 HITS  -  2 CRITS"` in amber, confirming counters increment + colour ramps activate.
- Zero SCRIPT ERRORs on project import.

### Prioritised backlog (post-session-5)

**All active P2 items are cleared.** Future work now lives in `/app/docs/improvements.md`, organised by scene + business impact so any single item or curated combo can be picked up as a standalone commit.

## What is NOT working / not touched
- **Vulkan → OpenGL 3 fallback** on the preview pod (no GPU) triggers a benign console warning during proof render; production Android target uses Vulkan Mobile and is unaffected.
- **Live server integration** and **Android APK export** — untouched, out of scope for a theme pass.
- **BGM cross-fade & SFX matrix** (juice manual §5) — still marked pending in CLAUDE.md phase tracker (Phase C9). Sound work is a separate pass.

## Enhancement idea
Once the item roster grows to 20+, consider adding a **"Codex" screen** the player can open from the main-menu tab bar — a scroll of every discovered item with its stat block, category tint background, and a lore paragraph. Free retention lever: players love collecting, and the sprite work is already done.
