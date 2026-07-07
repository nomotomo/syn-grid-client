# Dependency Decision: Item Icons, HUD Glyphs, Panel Theme, and Audio

Status: Decided 2026-07-05.
Owner: Claude Code (Lead Architect).
Driven by: user-supplied reference mockup (neon HUD, rounded glass panels) and 4 candidate itch.io packs.
Consumers: sync-grid-client issues #7 (C8), #8 (C9), #11 (C10, new).

## Scope

Every external asset dependency needed to take GridPrepScene, CombatReplayScene, RoundEndScene, and the
future LeaderboardScene from placeholder/code-only rendering to real art and audio, plus the disposition
of the 4 itch.io packs the user linked. This does not cover item *gameplay* data - only presentation assets.

## Current gaps found in the codebase (2026-07-05 audit)

- `ItemCard.gd:74` renders every item as a flat-tinted `ColorRect`. `assets/sprites/items/` is empty except
  `.gitkeep`. The code comment already flags this: "placeholder tint... until real pixel-art sprites are"
  sourced.
- `StatsHud.tscn` has no icon nodes at all - gold/life/triumph are text-only labels ("GOLD" / "750").
  The reference mockup pairs each stat with a coin/heart/trophy glyph.
- `assets/audio/` is 100% procedurally synthesized placeholder (`tools/generate_placeholder_audio.py`),
  documented as such in `assets/audio/README.md`. Issue #8 already tracks sourcing real files with generic
  hints ("Sonniss / Freesound"); this doc replaces those hints with concrete, verified picks.
- `ThemeBuilder.gd:17` hard-codes `PANEL_CORNER_RADIUS = 0` with the comment "sharp corners - etched-circuit
  look, never rounded/glass" - a deliberate prior decision that the reference mockup's rounded glass panels
  reverse. Addressed in the C10 HLD, not this doc; noted here because it rules out importing any
  static-panel UI kit as the base theme (see below).

## Decision matrix

| Category | Decision | Source | Cost | License |
|---|---|---|---|---|
| Weapon/shield item icons | **Adopt** | Akari21 "RPG Icon Pack (200+)" | $2.01 | Personal + commercial, modify freely, no attribution required, no resale, no-AI |
| Misc/filler icons (potion, material) | **Adopt (free fallback)** | Cainos "Pixel Art Icon Pack - RPG" | Free (name-your-price) | Commercial use OK, no attribution required, no resale |
| HUD glyphs (coin, heart, trophy) | **Adopt** | Kenney "Game Icons" | Free | CC0 - no attribution ever required |
| Rank medal badges (leaderboard top-3) | **Adopt (fallback: code-drawn)** | Kenney "Game Icons" medal/star assets, or a plain `StyleBoxFlat` circle + number if no icon fits | Free | CC0 |
| Rank medal badges | **Reject** | "Racing License Rank Emblems" (user-linked) | $1.99 | N/A - not used |
| UI/electronic SFX (6 of 14 keys) | **Adopt** | Hove Audio "Free Sci-Fi UI Sound Effects Pack" | Free (name-your-price) | Royalty-free, commercial use OK, **credit requested** |
| Combat SFX (7 of 14 keys) | **Deferred - source separately** | OpenGameArt.org, filtered CC0, tag "RPG combat" | Free | CC0 (once picked) |
| BGM (2 tracks) | **Candidate, needs audition** | whitebataudio "Free Cyberpunk Loop Pack" | Free (name-your-price) | Royalty-free, commercial use OK |
| Screen-shake / hit-flash VFX plugin | **Reject** | "Godot Juice Pack" (user-linked) | $7.49 | N/A - juice_manual.md section 2-4 already specifies the exact tween/shader recipes; buying a second system would fork the effects pipeline |
| Damage number sprite pack | **Reject** | "Combat Feedback Pack" (user-linked) | $3.99 | N/A - juice_manual.md section 4 already fully specifies damage-float styling in code (color/scale/easing per damage type); a fixed external sprite set can't be recolored per-synergy the way a `Label` + tween can |
| Results-screen skin | **Reject - wrong medium** | "Neon Post-Run Results Screen Skin" (user-linked) | $2.99 | N/A - inspected the actual deliverable: it's an HTML/CSS/JS skill-tree/upgrade-shop widget, not a Godot asset, and doesn't match RoundEndScene's actual content (win/loss banner, hearts, triumph orbs) |
| Base panel/button UI kit | **Reject as base theme** | Kenney "UI Pack: Sci-Fi" / "Cyberpunk UI Asset Pack v1" | Free (CC0 / name-your-price) | Kept as emergency fallback only (see Trade-offs in the C10 HLD) - not adopted, because the codebase already has a working code-driven `StyleBoxFlat` + shader panel system (`ThemeBuilder`/`SynGridPalette`/`synergy_glow.gdshader`) that scales to arbitrary content and centralizes the palette in one file. Importing a static 9-slice PNG kit would fork the visual system into two incompatible mechanisms for no gain. |

## Why the 4 user-linked packs were rejected

All four are legitimate, reasonably priced packs, but none survive a fit check against what's already built:

1. **Juice Pack** ($7.49) - duplicates `docs/juice_manual.md` sections 2-4, which already fully spec the
   tween curves, shake formula, and shader recipes as GDScript, not a plugin. Buying it means maintaining
   two competing juice systems.
2. **Combat Feedback Pack** ($3.99) - its 12 fixed damage-number styles can't carry the server's actual
   damage taxonomy (melee/ranged/arcane/crit/shield/true) the way a tinted `Label` + elastic tween already
   does per the juice contract. Its 32 status icons are the only piece worth revisiting, and only if/when
   the server adds buff/debuff status effects (not present in `../sync-grid` today - check
   `game-rules.md` before reconsidering).
3. **Racing Rank Emblems** ($1.99) - built for 8-tier motorsport progression. Issue #7's actual requirement
   is 3 medal icons (gold/silver/bronze) for leaderboard rank 1-3. Buying an 8-tier racing-themed pack and
   discarding 5 of 8 tiers plus reskinning the racing iconography is more work than using a generic CC0
   medal icon.
4. **Neon Post-Run Results Screen Skin** ($2.99) - confirmed by direct inspection to be an HTML/CSS/JS
   skill-tree and upgrade-shop UI kit, not a Godot results screen. Wrong engine, wrong content. Do not buy.

## Licensing and credit obligations

- **CC0 sources** (Kenney Game Icons, and Cainos/Akari21's "no attribution required" grants): no ongoing
  obligation. Prefer these whenever a choice exists - lowest long-term maintenance and legal risk.
- **"Credit appreciated/requested" sources** (Hove Audio SFX, whitebataudio BGM): add every filename, source
  URL, and creator name to `assets/audio/CREDITS.md` (new file) at import time. This is a one-time
  documentation cost, not a runtime dependency.
- **Paid packs** (Akari21 icons): keep the itch.io purchase receipt and the pack's bundled license file
  under `assets/sprites/items/LICENSE-akari21.txt` (or equivalent) so provenance survives a repo transplant
  or an audit years from now.
- No pack in the adopted set requires a splash-screen credit, a specific font pairing, or a link-back at
  runtime. If a future pack does, flag it in this doc before importing.

## Still open (not blocking)

- Combat SFX (7 keys) and final BGM pick need an actual listen-through, which is a Cursor/human task, not
  something this doc can settle from text descriptions alone. Issue #8 is updated with this as an explicit
  remaining task rather than a resolved decision.
- Five new SFX keys added by issue #30 (`coin_earn`, `coin_spend`, `triumph_earn`, `defeat_stinger`,
  `victory_fanfare`) ship as procedural placeholders via `tools/generate_placeholder_audio.py`, same as the
  original 14 events. Real-asset sourcing for these follows the same deferred, non-blocking path as the
  combat-SFX/BGM picks above - no separate tracking entry; audition and replace alongside the rest.
