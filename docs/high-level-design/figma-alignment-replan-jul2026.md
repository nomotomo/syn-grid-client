# Figma Alignment Re-plan - Jul 2026

Re-plan of the Wave 7 Figma design pass in epic #42, triggered by two reference changes:

1. The Figma Make design source was exported locally and is now vendored at `docs/design-reference/figma-make/` (canonical for exact values and layout composition).
2. The public mirror https://surly-spout-45387130.figma.site/ was republished and now matches the export.
   The "the .figma.site mirror is stale" warning in `docs/design-tokens-neon-grimoire.md` is obsolete and has been corrected.

PR #82 (Main Menu top bar, from #79) was closed unmerged as part of this re-plan; its scope is re-absorbed below.

## What changed versus the plan of record

The previous Wave 7 plan was built by eyeballing the login-gated Figma Make preview plus computed-style extraction.
The exported source reveals the design system exactly, and it contains surfaces the plan never covered:

| Design surface (source file) | Client scene today | Covered by | Re-plan action |
|---|---|---|---|
| Bottom TabBar: HOME / RANKS / SEASON / PROFILE (`components/TabBar.tsx`) | none | nothing | **New issue E26 (#84)** - global nav shell on Main Menu + Leaderboard |
| Profile modal: avatar-triggered display-name editor (`components/ProfileModal.tsx`) | profile popover in `MainMenu.gd` | #34 (as a "Profile hub" screen) | **New issue E27 (#85)** - modal per design; #34 keeps Codex/rewards-ladder/resume-banner scope |
| Daily Rewards screen: 7-day streak + daily missions (`screens/DailyRewardsScreen.tsx`, marked CONCEPT) | none | #40 (text-only mention) | **New issue E28 (#86)** (client, blocked) + server escalation spec `docs/dependency/server-daily-rewards-escalation.md` (to be filed on sync-grid) |
| 7×7 grid concept (`App.tsx`, `screens/GridScreen.tsx`) | 4×4 only | #66 title says 5×5/6×6; its LLD already says 5x5/6x6/7x7 | Comment on #66: 7×7 confirmed in design as concept; ask server to confirm max tier |
| Leaderboard inner tabs (LEADERBOARD / SEASON) + skeleton shimmer rows (`screens/RanksScreen.tsx`) | single-view leaderboard | #72 partially | Scope addition noted on #72 |
| Battle Report 3-step flow: Breakdown → Heatmap → Timeline with turning-point marker (`screens/BattleReportScreen.tsx`) | battle_report scene from #31 | #65 (polish only) | Scope note on #65; `turning_point_tick` and per-tick log already exist in `docs/api_contract.md`, no server work |
| Round Result advice cards + per-unit breakdown + VIEW REPORT link (`screens/ResultScreen.tsx`) | round_end scene | #71 + #35 | Reference update on #71; no scope change beyond LLD refresh |
| Market screen (`screens/MarketScreen.tsx`) | buy/sell inside Grid Prep | #64 | Reference update only; design confirms #64's layout |

## Decision: palette reconciliation (new issue E25b / #83, do first)

`docs/design-tokens-neon-grimoire.md` left two colors unresolved: design amber `#FFB627` vs `SynGridPalette.gd` gold `#F2C74A`, and design crimson `#D81E3D` vs danger `#D91A1A`.
The exported `styles/tokens.css` shows the design values are deliberate primitives used across every screen (tier rings, HUD pills, glow recipes), not extraction noise.

**Decision: adopt the design values.**
Update `SynGridPalette.gd` to `#FFB627` and `#D81E3D` in one small PR before any visual-pass issue lands, so no pass ships against a forked palette.
Rationale: the design source is now the single source of truth, and it is internally consistent around these values; keeping the old constants would fork every glow recipe that references them.

## Re-planned Wave 7 ordering

Sequencing rule: palette first, structure second, per-screen visual passes last, concepts when the server catches up.

1. **E25b palette reconciliation (#83)** - P1, tiny, blocks everything visual.
2. **#66 grid-size hardening (5×5/6×6/7×7)** - P1, unchanged, server already sends tiered sizes.
3. **E26 bottom TabBar nav shell (#84)** - P1 structural; #79 and #72 both compose against it, so it lands before them.
4. **#79 Main Menu structural alignment** - P2, re-absorbs closed PR #82; its LLD delta list stays valid, but implementation now reads `screens/LandingScreen.tsx` directly instead of screenshots.
5. **#64 Market split** - P2, unchanged.
6. **#69 Grid Prep, #70 Battle, #71 Round Result visual passes** - P2, LLDs already re-verified (commit b1adfee); refresh references to vendored source paths, no re-derivation needed.
7. **E27 Profile modal (#85)** - P2, can run parallel to per-screen passes.
8. **#65 Battle Report 3-step flow, #72 Leaderboard (incl. inner tabs + skeleton), #73 Season Hub** - P3.
9. **E28 Daily Rewards (#86)** - P3, blocked on server work (streak/missions/claim endpoints, specced in `docs/dependency/server-daily-rewards-escalation.md`); client work must not start before the server contract is merged into `docs/api_contract.md`.

## Standing constraints (unchanged)

Juice contract (`docs/juice_manual.md`) is non-negotiable and is not superseded by the design export's CSS animations; where the two disagree on motion, the juice manual wins.
No client game logic; all numbers from the server.
Every new scene ships a preview harness with screenshot mode.
Implementation maps tokens through `SynGridPalette.gd` / `ThemeBuilder.gd`, never hardcoded hex from the reference.
