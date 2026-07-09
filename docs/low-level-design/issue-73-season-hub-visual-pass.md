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

## Scope

1. Give `TimerCard` and `TriumphCard` their own `build_panel_style(..., with_glow=true)` or
   `build_capsule_style()` override (whichever fits the card's aspect ratio better - these are wider,
   shorter cards than a HUD pill, so `build_panel_style` with glow is likely the better fit, not the
   capsule variant), using `ACCENT_PURPLE` as the border/glow color to match `SeasonHub`'s existing
   purple rune-field theming (`accentColor="#7B2FBE"` per the Figma reference, and consistent with this
   screen already being visually distinct from Main Menu's teal-dominant palette).
2. Rewards-ladder placeholder (`_rewards_note`, `SeasonHub.gd:39`, text "REWARDS LADDER - COMING SOON"):
   confirm whether the Leaderboard's Season tab already has a locked-card treatment for the equivalent
   placeholder (it should, per the Figma-side consistency fix from earlier in this design pass) and match
   that treatment here for consistency between the two screens showing the same "coming soon" concept.
   Don't invent a second, different-looking placeholder style.
3. Back button - same note as #71: if #68 lands a shared CTA/button style, reuse it here rather than a
   third one-off treatment.

## Files

`scenes/season_hub/SeasonHub.tscn`, `scenes/season_hub/SeasonHub.gd` (only if adding style calls in code
rather than `.tscn` overrides - either approach is fine, `.tscn` override is simpler here since these are
static cards with no dynamic per-instance color).

## Testing

`SeasonHubPreviewHarness` screenshot showing both cards with a visible purple glow/border distinct from
the plain default panel style, and the rewards-ladder placeholder matching the Leaderboard Season tab's
treatment.
