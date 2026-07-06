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

### Prioritised backlog (post-session-2)

**P2 (nice-to-have)**
- Ambient dust particles on menu screens (3-5 slow teal specks) - CPUParticles2D + the new `dot.png` fx texture
- Tooltip popovers on HUD pills (glassmorphic legal per juice §1 - tooltips are non-live)
- Grid coordinate labels `A1..D4` along top+left of the deployment grid
- Bigger tunable for the CRT title effect (currently subtle; could bump `scanline_intensity` if the user wants more retro grit)
- Wire the SEASON tab to actually route to a Season Hub screen once that scene exists
- Enemy team red arcane-circle floor + friendly team teal floor in Combat Replay (the two teams still share the same panel style)

**P3 / Future**
- Custom cursor set (arrow / grab / forbidden)
- Signal-strength bars near the LINKING status
- Per-tier item-icon rarity halo behind the sprite
- Codex screen from the PROFILE tab - a scrollable grimoire of every discovered item

## What is NOT working / not touched
- **Vulkan → OpenGL 3 fallback** on the preview pod (no GPU) triggers a benign console warning during proof render; production Android target uses Vulkan Mobile and is unaffected.
- **Live server integration** and **Android APK export** — untouched, out of scope for a theme pass.
- **BGM cross-fade & SFX matrix** (juice manual §5) — still marked pending in CLAUDE.md phase tracker (Phase C9). Sound work is a separate pass.

## Enhancement idea
Once the item roster grows to 20+, consider adding a **"Codex" screen** the player can open from the main-menu tab bar — a scroll of every discovered item with its stat block, category tint background, and a lore paragraph. Free retention lever: players love collecting, and the sprite work is already done.
