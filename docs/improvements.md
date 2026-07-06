# Syn-Grid Improvements Backlog

_Living document. Anything can be picked up in isolation — items are scoped to be independently shippable._

Last updated: Jan 2026 (after Session #4 + Tier C).

---

## 0. What has already shipped (Sessions 1–4 recap)

### Session #1 — Neon Grimoire theme foundation
- 4-rung palette + `ThemeBuilder` (VOID / PANEL_BG / ELEVATED / HOVER, plus AMBER/SILVER/PARCHMENT + tier tints)
- Capsule HUD pills with left accent bars + count-up animations
- Tier-ringed `ItemCard` with category-tint radial background + stat pips (`A / D / S`)
- Rune-field shader backdrop on the main menu
- Regenerated every broken/inconsistent sprite (triumph, badges, 16 unified item icons, 4 fx particles, app icon)
- `CPUParticles2D.EMISSION_SHAPE_RING` API guard so scenes open on Godot 4.5 stable
- `tools/generate_theme_sprites.py` one-shot regen script

### Session #2 — P1 backlog
- Bottom-nav tab bar (HOME / RANKS / SEASON / PROFILE), HOME styled active
- Aurora border shader on `ENTER THE GRID` (pure UV so it runs on OpenGL 3 fallback)
- CRT scanline + chromatic aberration on the SYN-GRID wordmark
- Circular round-timer ring on Combat Replay (TEAL → AMBER < 30 % → DANGER < 10 %)
- Empty-cell `+` glyph on every empty deployment socket
- `highlight(on, valid)` — invalid-drop cells pulse DANGER crimson
- Leaderboard top-3 medallions bumped 28 → 72 px with per-tier outer glow

### Session #3 — P2 batch
- Enemy team red / player team teal arcane-circle floors on Combat Replay
- Ambient teal dust particles on the main menu
- Grid coordinate labels (A/B/C/D across top, 1/2/3/4 down left)

### Session #4 — Battle-page A + B + C + 3 follow-ups
- **Tier A**: projectile trails (RANGED/ARCANE), hitmark rings, muzzle flashes
- **Tier B**: directional camera kick, intro banner, killing-blow flash
- **Tier C**: damage-spark bursts behind floats, `N HITS · N CRITS · N KOs` footer
- Season Hub scaffold + purple-tinted backdrop + BACK button; SEASON tab now routes there
- Bigger CRT dial (scanline_intensity 0.22 → 0.42, chromatic_shift 0.8 → 1.8, jitter 0.6 → 1.2)
- HUD-pill tooltips with themed `TooltipPanel` / `TooltipLabel` styleboxes

---

## How to read this file

Each item has:
- **Difficulty**: `XS` (<15 min) · `S` (~30 min) · `M` (~1 h) · `L` (~2 h) · `XL` (>3 h)
- **Files touched**: everything that would need to be edited/created
- **Why it matters**: the player-facing win

Items are grouped by **theme** so you can pick a batch that's cheap to test together (they touch the same scene).

---

## 1. Battle Page — deeper combat feel

### 1.1 Screen-wide slow-motion on the killing blow  •  M
Slow the `_log_player`'s `event_interval` to 0.25 (from 0.10) for the ONE event immediately before playback ends, then restore. Combined with the existing killing-blow flash it turns the final shot into a moment.
_Files_: `scripts/combat/CombatLogPlayer.gd` (add `slow_next_event()`), `scenes/combat_replay/CombatReplayScene.gd` (detect penultimate event).

### 1.2 Item shake + micro-flash when it takes damage  •  S
When an item on the grid is the target of an event, briefly modulate its `ItemCard.modulate` white and shake `position:x` ±3 px for 100 ms. Currently only the HP bar reacts; the *item itself* stays still.
_Files_: `scenes/combat_replay/CombatReplayScene.gd`.

### 1.3 Combat log ticker in the middle band  •  M
Juice manual §4 promises a "one-event-per-0.1s auto-scrolling combat log" in a 10 % middle band. Currently absent. Add a `%LogTicker` `Label` that shows the last N event descriptions ("Iron Sword crit for 45") stacked, oldest sliding out to the right.
_Files_: `scenes/combat_replay/CombatReplayScene.tscn` + `.gd`, `scripts/combat/CombatLogPlayer.gd`.

### 1.4 Item shatter animation on death  •  S
Right now units keep looking healthy at 0 HP. When `target_item_id` receives a fatal hit, tween the card `scale.y → 0.4, scale.x → 1.2` then `modulate.a → 0` over 0.35 s and spawn a category-tint particle burst.
_Files_: `scenes/combat_replay/CombatReplayScene.gd`, `ItemCard.gd` (new `play_shatter()` method).

### 1.5 Combat log rewind / step-through debug  •  L
Skip button already exists. Add a `<-` / `->` scrubber in dev builds only that steps the log one tick at a time so playtesters can screenshot exact frames.
_Files_: `scenes/combat_replay/CombatReplayScene.tscn` + `.gd`.

### 1.6 Camera zoom-in on crits  •  S
Extend `ScreenEffects.hitstop` to also nudge `_camera.zoom` from 1.0 → 1.05 → 1.0 over the hit-stop window on crits only. Frames the crit without adding new nodes.
_Files_: `scripts/autoloads/ScreenEffects.gd`.

---

## 2. Grid Prep — clearer decisions

### 2.1 Synergy preview overlay  •  M
When a card is being dragged over the grid, render faint teal lines between it and any currently-placed items it would synergise with. Uses `SynergyBorder` shader logic. Removes the "guess and check" playstyle.
_Files_: `scenes/grid_prep/GridPrepScene.gd`, new `assets/shaders/synergy_preview.gdshader` (or reuse existing).

### 2.2 Best-slot hint (long-press an item)  •  M
Long-press an item in the shop or bench to briefly highlight the grid cells where placement would activate a synergy. Same shader as 2.1, driven from a `_hint_placements()` server query or client-side rule.
_Files_: `scenes/ui/ItemCard.gd`, `scenes/grid_prep/GridPrepScene.gd`.

### 2.3 Auto-arrange button  •  S
"AUTO" button next to `START MATCH` that places bench items into the grid in a naive best-synergy configuration. Great for the "I just want to play" onboarding moment.
_Files_: `scenes/grid_prep/GridPrepScene.tscn` + `.gd`.

### 2.4 Item comparison tooltip on shop cards  •  M
Long-press a shop item to overlay a small stat-diff card: "+12 ATK vs your Iron Sword". Uses the pip data already on ItemCard.
_Files_: `scenes/ui/ItemCard.gd`, new `scenes/ui/ItemCompareOverlay.tscn`.

### 2.5 Recycler danger clarification  •  XS
Recycler border already goes red-ish. Add a subtle "SELL: +Ng" preview when dragging over it, so the player knows the payout before releasing.
_Files_: `scenes/grid_prep/GridPrepScene.gd`.

### 2.6 Placed-item glow on synergy activation  •  S
When two items on the grid form a synergy, the `SynergyBorder` already lights up. Add a one-shot elastic scale pulse (1.0 → 1.08 → 1.0 over 200 ms) on both cards the moment the link forms.
_Files_: `scenes/grid_prep/GridPrepScene.gd`.

---

## 3. Main Menu / Meta

### 3.1 Codex screen from PROFILE tab  •  L
Turn the PROFILE tab into a real screen with lifetime stats (matches / wins / crits / longest streak) + a scrollable grimoire of every item the player has ever owned (grayed-out silhouette until first-owned). Retention lever.
_Files_: new `scenes/profile/ProfileHub.tscn` + `.gd`, `scenes/main_menu/MainMenu.gd` route change.

### 3.2 Rewards ladder preview in Season Hub  •  M
Currently `REWARDS LADDER - COMING SOON`. Even before server endpoints exist, render the next 3 rank thresholds with dim triumph icons + a "TRIUMPH REQUIRED: N" pill. Zero server changes — pure aspirational UI.
_Files_: `scenes/season_hub/SeasonHub.tscn` + `.gd`.

### 3.3 Season rune motif picker (cosmetic)  •  M
Let players cosmetically pick their arcane-circle-floor rune motif (Ember / Frost / Void / Storm). Just swaps shader uniforms on `arcane_circle_floor.gdshader`. Zero server changes; player prefs stored client-side.
_Files_: `scenes/season_hub/SeasonHub.gd`, `assets/shaders/arcane_circle_floor.gdshader` (new variant uniforms), `scripts/autoloads/GameState.gd` (settings section).

### 3.4 Real callsign edit popover polish  •  S
Popover exists but is bare. Add: character counter (0/16), forbidden-character warning, a "randomize" die button that pulls from a themed word list.
_Files_: `scenes/main_menu/MainMenu.gd` (`_open_name_popover`), new `scripts/util/CallsignGenerator.gd`.

### 3.5 Home tab "Continue where you left off" banner  •  S
If the player has an unfinished round in progress, show a full-width teal banner on HOME with "RESUME ROUND N" that routes straight into GridPrep. Fewer clicks between session and gameplay.
_Files_: `scenes/main_menu/MainMenu.gd`, `scripts/autoloads/GameState.gd`.

---

## 4. Leaderboard

### 4.1 Rank-change indicator  •  S
Show a `▲ 3` / `▼ 5` chip next to each row indicating movement since last check. Needs a client-side "last seen" snapshot in GameState.
_Files_: `scenes/leaderboard/LeaderboardScene.gd`, `scripts/autoloads/GameState.gd`.

### 4.2 Filter chips (SEASON / ALL-TIME / FRIENDS)  •  M
Chips at the top of the leaderboard let the player scope the list. FRIENDS requires a friends endpoint on the server (skip until then).
_Files_: `scenes/leaderboard/LeaderboardScene.tscn` + `.gd`.

### 4.3 Tap-row → profile card overlay  •  M
Tapping any row opens a floating card with that player's stats + their equipped grid at time of ranking. High replay-inspection value.
_Files_: `scenes/leaderboard/LeaderboardScene.gd`, new `scenes/leaderboard/PlayerCardOverlay.tscn`.

### 4.4 Ambient rank medallion glow on scroll  •  XS
The top-3 medallion glows are static. Have them slowly pulse (`modulate.a` 0.35 ↔ 0.55 over 1.6 s) for a "living trophy shelf" feel.
_Files_: `scenes/leaderboard/LeaderboardScene.gd`.

---

## 5. Round-End Scene

### 5.1 Victory typewriter reveal  •  S
The word "VICTORY" pops instantly. Reveal it one character at a time over 0.25 s + a soft synth chime per letter (once the SFX matrix ships).
_Files_: `scenes/round_end/RoundEndScene.gd`.

### 5.2 Triumph orb "fly-in" for newly-earned orbs  •  M
When a round grants a triumph, the new orb should fly in from off-screen with a rotating trail, snap into position, and pulse. Currently the orb just appears filled.
_Files_: `scenes/round_end/RoundEndScene.gd`.

### 5.3 Defeat scene desaturation shader  •  S
Juice manual §4 promises 60 % desaturation on defeat. Confirm currently applied; if not, add a canvas_item post-processor via `CanvasLayer + Control.material`.
_Files_: `scenes/round_end/RoundEndScene.gd`, potentially new `assets/shaders/desaturate.gdshader`.

### 5.4 Milestone celebration for streak-based ROUND thresholds  •  M
When ROUND crosses 5 / 10 / 20, add an extra 1-second confetti-particle overlay of teal + purple dots. Emotional payoff for progression.
_Files_: `scenes/round_end/RoundEndScene.gd`.

---

## 6. Audio (Phase C9 pending in `CLAUDE.md`)

### 6.1 BGM crossfade between scenes  •  M
Menu track → Combat track needs a 0.5 s cross-fade, not a hard cut. Already spec'd in juice manual §5.
_Files_: `scripts/autoloads/AudioManager.gd`.

### 6.2 Full SFX event matrix  •  L
juice manual §5 lists every event → SFX pairing. Currently: click / melee / ranged / arcane / crit / shield-absorb / hp-loss are implemented. Missing: card_lift, card_snap, coin_earn, coin_spend, triumph_earn, defeat_stinger, victory_fanfare, timer_tick_low.
_Files_: `scripts/autoloads/AudioManager.gd`, source SFX assets.

### 6.3 Combat BGM ducking on crit  •  S
On every crit event, briefly lower `bgm_bus` volume −6 dB for 200 ms so the crit stinger cuts through. Standard mobile trick.
_Files_: `scripts/autoloads/AudioManager.gd`.

### 6.4 Muted-audio Snapshot on defeat  •  S
juice manual §4 mentions LPF on BGM on defeat. Verify it's still active; if the audio system was refactored, restore.
_Files_: `scripts/autoloads/AudioManager.gd`.

---

## 7. Accessibility & UX

### 7.1 Reduced motion setting  •  M
A settings toggle that disables screen shake, camera kick, and elastic overshoot (replaces them with `TRANS_QUAD` fades). Some players need this.
_Files_: new `scripts/autoloads/PlayerSettings.gd`, `scripts/autoloads/ScreenEffects.gd`, `scripts/ui/ItemCard.gd`, `scenes/combat_replay/CombatReplayScene.gd`.

### 7.2 High-contrast palette toggle  •  M
Alternate palette with WCAG-AA contrasts (brighter parchment on darker VOID, less-saturated accents). Wired via `SynGridPalette.set_variant("high_contrast")`.
_Files_: `scripts/ui/SynGridPalette.gd`, `scripts/ui/ThemeBuilder.gd`.

### 7.3 Colour-blind safe crits  •  S
Crits use crimson today. In colour-blind mode, add a distinct **glyph** overlay (⚡) next to the damage float so the crit is identifiable without red.
_Files_: `scenes/combat_replay/CombatReplayScene.gd`.

### 7.4 Larger tap targets on tablets  •  S
Detect `DisplayServer.screen_get_size()` > 1200 px on any axis and scale up card + button min-sizes 15 %. Currently the layout is tuned for 540×960.
_Files_: `scripts/ui/ThemeBuilder.gd`, `scripts/ui/ItemCard.gd`.

### 7.5 Haptic feedback on drops / crits (Android/iOS)  •  S
`Input.vibrate_handheld(50)` on `drag_ended`, `Input.vibrate_handheld(100)` on crit. Two lines. Big feel gain on phone.
_Files_: `scripts/ui/ItemCard.gd`, `scenes/combat_replay/CombatReplayScene.gd`.

---

## 8. Performance / Tech Debt

### 8.1 Godot 4.7 → 4.5 stable pinning decision  •  M
Project claims 4.7-dev in `project.godot` (`config/features=("4.7", "Mobile")`) but 4.7 is unreleased. Choose: (a) downgrade to 4.5 stable formally (some CPUParticles2D features lose their native `EMISSION_SHAPE_RING`), or (b) stay on 4.7 nightly and pin a specific hash. Currently guarded via fallback but unclear long-term.
_Files_: `project.godot`, CI/build docs.

### 8.2 Auto-import screenshots outside project tree  •  XS
`/screenshots/` is gitignored, but Godot still auto-generates `.import` files whenever the editor scans. Move to `/tmp/syngrid_screenshots/` or `os.environ.get("SYNGRID_SCREENSHOT_DIR")`.
_Files_: `scenes/*/PreviewHarness.gd` files, harness docs.

### 8.3 Consolidate all shader parameters into `assets/shaders/params.tres`  •  M
Currently every scene inlines its `ShaderMaterial` sub_resource with hardcoded palette values. A shared `.tres` resource would keep them in sync (change teal in one place, propagate everywhere).
_Files_: 6 `.tscn` files, new `.tres`.

### 8.4 Freeing safety on scene teardown  •  S
Some tweens (aurora, dust, projectile fades) don't hold a strong reference. If a scene tears down mid-tween, the target may be freed while the tween still fires. Add `queue_free` guards where needed.
_Files_: `scripts/ui/ItemCard.gd`, `scenes/combat_replay/CombatReplayScene.gd`.

### 8.5 Sprite atlas generation  •  L
16 item icons at 64×64 = 16 draw calls today. Bundle into a single 256×256 atlas + AtlasTexture per item. Saves batching cost on low-end phones.
_Files_: `tools/generate_theme_sprites.py`, `scripts/ui/ItemCard.gd`.

---

## 9. Retention / Business Wins (zero-server-change ideas)

### 9.1 Daily login streak counter  •  M
Home tab shows "DAY 3/7 STREAK — TAP TO CLAIM" with a coin/triumph reward at each milestone. Stored client-side (in `PlayerSettings`) as MVP; migrate to server later.
_Files_: new `scripts/autoloads/PlayerSettings.gd`, `scenes/main_menu/MainMenu.gd`.

### 9.2 Onboarding tooltip tour  •  M
First-time launch triggers a 4-step overlay pointing at the HUD pills, the shop, the grid, and START MATCH. Skippable.
_Files_: new `scenes/ui/OnboardingTour.tscn` + `.gd`, `scripts/autoloads/PlayerSettings.gd`.

### 9.3 End-of-match "share your grid" screenshot  •  S
On VICTORY / DEFEAT, add a small "SHARE" button that saves a screenshot of the final grid to `user://shares/YYYYMMDD-HHMMSS.png`. Later: hook into OS share sheet.
_Files_: `scenes/round_end/RoundEndScene.gd`.

### 9.4 Daily challenge banner on HOME  •  M
Rotating challenge: "Win 3 matches using only ARCANE items today". Pure client-side rule check + cosmetic reward.
_Files_: `scenes/main_menu/MainMenu.gd`, new `scripts/util/DailyChallenges.gd`.

### 9.5 Post-match "your rank moved" toast  •  S
If leaderboard position changed after a match, show a 2-second toast in the round-end scene: "▲ MOVED TO RANK #12". Retention hook.
_Files_: `scenes/round_end/RoundEndScene.gd`, `scripts/autoloads/GameState.gd`.

---

## 10. Fresh polish ideas (any-priority)

### 10.1 Card foil animation for high-tier drops  •  M
When the shop rolls a tier ≥ 3 item, briefly play a diagonal shine-sweep shader across the card (0.6 s, one-shot). Free "premium loot" feel.
_Files_: `scenes/ui/ItemCard.gd`, new `assets/shaders/card_foil.gdshader`.

### 10.2 Combat announcer voice-over stubs  •  S
Even if you don't have voice acting, reserve `AudioManager.play_announcer("first_blood" | "wipe" | "clutch")` hooks now so it's a one-line addition later.
_Files_: `scripts/autoloads/AudioManager.gd`.

### 10.3 Item level-up flash on shop merge  •  S
When two identical items merge into a higher-tier one on the bench/grid, spawn a 1-second particle burst + tier-colored radial ring at the resulting card's position.
_Files_: `scenes/grid_prep/GridPrepScene.gd`, `scripts/ui/ItemCard.gd`.

### 10.4 Loading-screen tips (Neon Grimoire lore)  •  S
Between scenes, show a 1-line lore tip ("Iron dampens arcane conductivity"). Adds character without needing story mode.
_Files_: new `scripts/util/LoreTips.gd`, whichever screen renders a loading state.

### 10.5 A/B toggle for aurora Play button hue  •  XS
Some players will prefer amber over purple as the second aurora hue. One line change in `MainMenu.tscn`'s `AuroraMaterial` `color_b`. Ship both, let the player pick from Season Hub cosmetics later.
_Files_: `scenes/main_menu/MainMenu.tscn`, `scenes/season_hub/SeasonHub.gd`.

---

## 11. My picks — highest-impact / lowest-cost combos

If you're picking a batch, these three combos have the best ratio of "visible player-facing win" to "credit spend":

**Combo A — "Fight feels alive"**  •  ~1.5 h combined 
Items **1.2** (item shake on damage) + **1.4** (item shatter on death) + **1.6** (camera zoom on crit). Together they close the last "did that hit register?" gap in Combat Replay.

**Combo B — "Meta hooks"**  •  ~2.5 h combined 
Items **3.1** (Codex screen) + **9.1** (daily streak) + **9.5** (rank-moved toast). Turns the game into a habit loop without needing a single new server endpoint.

**Combo C — "Feels premium"**  •  ~2 h combined 
Items **2.1** (synergy preview) + **10.1** (card foil animation) + **5.2** (triumph orb fly-in). The kind of polish that gets reviewers saying "surprisingly slick for a solo indie."

Pick any single item, any combo, or the whole section — every entry is scoped to be independent.

---

## 12. Architect triage (Jul 2026) - how this doc became issues

_Added by Claude Code (Lead Architect)._
Every item above has been batched into a GitHub issue on `nomotomo/sync-grid-client` under the **"Client Experience Roadmap" epic #42** (children #28-#41), each with a `P0`-`P3` priority label and a wave order.
The authoritative cross-repo sequencing lives in the server epic `nomotomo/sync-grid` #57.

Batching (issue = the batch, doc sections = the spec):

- **Combat feel batch** (P1): §1.1, §1.2, §1.4, §1.6 - Combo A plus the slow-mo killing blow.
- **Combat readability** (P1): §1.3 log ticker + game_ideas.md §4.1 telemetry overlays.
- **Audio completion** (P1): §6.1-§6.4 - closes the Phase C9 gaps that survived issue #8.
- **Battle Report scene** (P1): game_ideas.md §4.2 + §4.5 heatmap; blocked on a small server metadata issue.
- **Grid-prep clarity** (P2): §2.1-§2.6 + §10.3 merge flash.
- **Onboarding & hints** (P2): §9.2 + game_ideas.md §5.1, §5.2, §5.5 (one suggestion engine, two triggers).
- **Meta screens** (P2): §3.1-§3.5.
- **Round-end ceremony** (P2): §5.1-§5.4 + §9.5 rank toast.
- **Accessibility** (P2): §7.1-§7.5 + one-thumb mode (game_ideas.md §10.3-I).
- **Tech debt** (P2): §8.1-§8.5.
- **Leaderboard polish** (P3): §4.1-§4.4.
- **Retention pack** (P3): §9.1, §9.3, §9.4 + game_ideas.md §3.4 mastery + §10.3-H grid scars.
- **Polish grab-bag** (P3): §10.1, §10.2, §10.4, §10.5 + game_ideas.md §6.12 reactive menu.
- **Dynamic BGM layers** (P3): game_ideas.md §10.3-G.

§1.5 (debug scrubber) folds into the Battle Report issue as the timeline scrubber MVP.
Refinement: §2.2 best-slot hint and game_ideas.md §5.5 inaction tooltips are one placement-suggestion engine - specced once inside the onboarding & hints issue.
