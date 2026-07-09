# LLD: Issue #73 - Season Hub Neon Grimoire Visual Pass

Client issue: #73 (epic #42, Wave 7). Depends on #67 (merged). Distinct from #34 (E7 Meta screens -
rewards ladder *content*, not yet built) and the already-fixed rewards-ladder consistency work (issue
#26, closed - `docs/design-tokens-neon-grimoire.md` PR's earlier "Update Season Rewards Consistency"
pass on the Figma side, mirrored here by whatever the Leaderboard Season tab already does).

## Verified against code read

`TimerCard` and `TriumphCard` (`SeasonHub.tscn:54,71`) are `PanelContainer`s with **no per-instance
style override** - no `theme_override_styles/panel` in the `.tscn`, and no `build_panel_style()`/
`build_capsule_style()` call anywhere in `SeasonHub.gd` (confirmed by grep - zero matches). They fall
back to the global theme default: `ThemeBuilder._build_theme()` sets `PanelContainer`'s default style to
`build_panel_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED)` - plain 16px-round
panel, dim border, **no glow** (`with_glow` defaults false).

So these cards aren't literally flat/unstyled (they do get the standard rounded-panel treatment every
generic panel gets), but they don't have any distinguishing accent - no glow, no per-card border color -
which is why they read as generic/flat next to Figma's more deliberately-styled timer/triumph cards.

### Substantially bigger gap found on full top-to-bottom re-comparison

The original scope above (add glow to two cards) badly under-counted the actual delta. This screen has
the same under-scoping problem #68 (Main Menu) had - checked only the specific claim from the original
issue draft instead of diffing the whole screen. Full list:

1. **Triumph card has no orb tracker at all - it's a bare number.** Confirmed by grep:
   `SeasonHub.gd:15` - `@onready var _triumph_value: Label = %TriumphValueLabel` is the *only*
   triumph-related node in the whole script. No `ProgressBar`, no orb loop, nothing. Figma shows a
   10-slot orb tracker (filled/empty circles) plus the numeric `"3/10"` plus a caption sentence ("7 more
   triumphs to complete Season 4"). **This codebase already has a working, tested orb-tracker
   implementation** - `RoundEndScene.gd`'s `_animate_orbs()`/`_make_orb_holder()` (10-slot, filled/empty,
   pop-in animation). Reuse that pattern here instead of building a new one from scratch.
2. **Season Timer card has no progress bar.** Figma shows a purple-to-amber gradient bar with
   "SEASON START / 72% ELAPSED / SEASON END" labels under the countdown text. Confirmed by grep - no
   `ProgressBar` or equivalent anywhere in `SeasonHub.gd`. Current card is countdown text only.
3. **No top utility bar.** Figma has a small "← BACK" button top-left and "SEASON 4" text top-right,
   separate from the bottom "← BACK TO MAIN MENU" CTA. The current build only has the bottom button - no
   top-positioned back control or season-number readout.
4. **No decorative divider between the title and the cards.** Figma has a thin horizontal rule with a
   small warning-triangle icon centered on it, between the "ARCANE RIFT" subtitle and the Season Timer
   card. Not present in the current build.
5. **Bottom back button is a plain rectangle, not the aurora CTA pill**, and reads "BACK" not "BACK TO
   MAIN MENU". #68 landed `ThemeBuilder.build_cta_style()` (merged) - reuse it here for both the shape and
   to decide on the fuller label text.

Given the size of this list, treat items 1 and 2 (missing orb tracker, missing progress bar) as the
priority - they're functional/informational gaps, not just polish, since a player currently has no visual
sense of "how close to the next triumph milestone" or "how much of the season is elapsed" beyond raw
numbers. Items 3-5 are lower-priority polish.

## Scope

**Priority (functional gaps, not just polish):**
1. Add a 10-slot orb tracker to `TriumphCard`, reusing `RoundEndScene.gd`'s `_make_orb_holder()` pattern
   rather than reimplementing - extract it to a shared helper if it isn't already reusable across scenes,
   don't copy-paste the function body.
2. Add a progress bar to `TimerCard` showing season elapsed-time, matching the countdown text already
   there.

**Polish:**
3. Give `TimerCard` and `TriumphCard` their own `build_panel_style(..., with_glow=true)` override, using
   `ACCENT_PURPLE` as the border/glow color to match `SeasonHub`'s existing purple rune-field theming.
4. Rewards-ladder placeholder (`_rewards_note`, `SeasonHub.gd:39`): match whatever locked-card treatment
   the Leaderboard's Season tab already uses for the same "coming soon" concept - don't invent a second
   style.
5. Bottom back button: reuse #68's `ThemeBuilder.build_cta_style()` (merged) for the pill shape; decide
   on "BACK" vs "BACK TO MAIN MENU" label length.
6. Lower priority, raise as a question rather than build: top utility bar (small back button + season
   number) and the decorative divider/icon between title and cards. Both are minor enough that a reviewer
   may decide they're not worth the added complexity - don't treat as mandatory.

## Files

`scenes/season_hub/SeasonHub.tscn`, `scenes/season_hub/SeasonHub.gd`, `scenes/round_end/RoundEndScene.gd`
(if extracting the orb-holder pattern to a shared location).

## Testing

`SeasonHubPreviewHarness` screenshot showing: a working orb tracker on the Triumph card, a progress bar
on the Timer card, both cards with visible purple glow, and the CTA-pill back button.
