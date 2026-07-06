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

## Prioritised backlog

### P1 (next session, from the original theme plan)
- **Main menu:** aurora border animation on the Play button (masked gradient orbits every 4 s); CRT scanline shader overlay on the SYN-GRID wordmark; bottom-nav tab bar (Play / Leaderboard / Season / Profile) or keep stacked buttons per user choice.
- **Grid cells:** empty-cell `+` glyph at 10 % opacity; danger-crimson pulse on invalid drop hovers (currently only teal-active on valid hover).
- **Round timer ring** on Combat Replay: circular teal progress → amber < 30 % → danger < 10 %.
- **Leaderboard top-3 plinths**: enlarge the badge sprites to 64+ px, add a subtle glow to each rank.
- **Enemy team red arcane-circle floor + friendly team teal floor** in Combat Replay (currently both teams share the same panel).

### P2
- Ambient dust particles on menu screens (3–5 slow teal specks) — CPUParticles2D with the new `dot.png` texture.
- Tooltip popovers on HUD pills (glassmorphic legal per juice §1 — tooltips are non-live).
- Coordinate labels `A1..D4` along top/left of the grid.

### P3 / Future
- Item icon rarity glow (per-tier soft outer glow around the icon square).
- Custom cursor set (arrow / grab / forbidden).
- Signal-strength bars near the LINKING status.

## What is NOT working / not touched
- **Vulkan → OpenGL 3 fallback** on the preview pod (no GPU) triggers a benign console warning during proof render; production Android target uses Vulkan Mobile and is unaffected.
- **Live server integration** and **Android APK export** — untouched, out of scope for a theme pass.
- **BGM cross-fade & SFX matrix** (juice manual §5) — still marked pending in CLAUDE.md phase tracker (Phase C9). Sound work is a separate pass.

## Enhancement idea
Once the item roster grows to 20+, consider adding a **"Codex" screen** the player can open from the main-menu tab bar — a scroll of every discovered item with its stat block, category tint background, and a lore paragraph. Free retention lever: players love collecting, and the sprite work is already done.
