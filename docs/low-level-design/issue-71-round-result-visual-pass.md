# LLD: Issue #71 - Round Result Neon Grimoire Visual Pass

Client issue: #71 (epic #42, Wave 7). Depends on #67 (merged). **Real overlap with #35 (E8 Round-end
ceremony, open, P2)** - both touch `RoundEndScene.gd`'s banner. Coordinate before starting; don't let
both issues touch `_configure_banner()` independently.

## Verified against live-rendered current state + code read

`SYNGRID_RESULT=win|loss SYNGRID_SCREENSHOT=/tmp/x.png godot --path . --resolution 540x960 scenes/round_end/RoundEndPreviewHarness.tscn`,
cross-checked against `RoundEndScene.gd`/`.tscn` directly (not just screenshots, per this review's
established pattern after missing real effects twice on other screens by not checking code).

### Already correct / out of scope for this issue

- Hearts and Triumph orbs (`_animate_hearts()`, `_animate_orbs()`) already have real pop/shatter/particle
  animations - visually close to the Figma reference, no work needed.
- **This screen has no stats grid, narrative summary card, or per-unit breakdown - by design, not by
  gap.** That content lives entirely in `BattleReportScene` (issue #31, shipped), reached after this
  screen. The Figma mockup's single "Round Result" screen conflates what the real app splits into two
  screens. Do not pull Breakdown-style content into `RoundEndScene` - that would duplicate #65's scope
  and fight the existing screen split.

### Real, confirmed gap

**Banner headline has zero glow/shadow treatment.** `RoundEndScene.tscn:17-24` - `%Banner` is a plain
`Label` (`TitleLabel` variant, 56px), and `_configure_banner()` (`RoundEndScene.gd:126-138`) only sets
`font_color` (`ACCENT_TEAL` for win, `DANGER` for loss/terminated). No shader, no text-shadow, no glow
of any kind - confirmed by reading both the `.tscn` node definition and every line that touches
`_banner`. Figma's reference shows a pulsing glow on "VICTORY" and desaturated-but-still-styled "DEFEAT"
text; the current banner is flat colored text only.

**Overlaps with #35's scope**: #35 already plans a "defeat desaturation audit" (`docs/improvements.md`
§5.3 - verify/restore a 60%-desaturation effect promised by the juice manual) on this same banner. A
glow/pulse treatment and a desaturation filter are different effects but touch the same node and the
same function. Whoever picks up #71 should read #35 first and either do both together or clearly
sequence who touches `_configure_banner()` first, so they don't produce conflicting PRs on the same
5 lines.

### Architectural finding from a full top-to-bottom comparison (not just re-checking this issue's claims)

**The real navigation order is the opposite of what Figma's mockup assumes, and this is not a styling
question - it's confirmed by reading the actual scene-transition code.** `CombatReplayScene.gd:753`
navigates to `BATTLE_REPORT_SCENE_PATH` after combat; `BattleReportScene.gd:70,223,227-228` navigates to
`ROUND_END_SCENE_PATH` only after the report is skipped or all 5 pages are viewed. So the real flow is:

```
CombatReplay -> BattleReport (mandatory, 5 pages) -> RoundEnd (final screen)
```

Figma's mental model, reflected in the "VIEW REPORT" link added to its Round Result mockup during an
earlier pass of this design review, treats Round Result as the primary landing screen with an *optional*
deep-dive into the report. That's backwards from the real app, where the report is the mandatory middle
step and Round End is the actual final screen. **Do not add a "VIEW REPORT" link from `RoundEndScene` to
`BattleReportScene`** - by the time a player reaches `RoundEndScene`, they've already been through the
report (or explicitly skipped it via the report's own Skip button, `BattleReportScene.gd:70`). Adding a
link backward into a screen they already passed through (or chose to skip) doesn't match the real
navigation graph. This is worth a note in the PR so nobody "fixes" this screen by copying that Figma
element in.

### Content/layout differences beyond the banner (found on full re-comparison)

1. **LIFE and TRIUMPH are stacked vertically**, each with their own centered row. Figma shows them side
   by side in a single top row (LIFE left-aligned, TRIUMPH right-aligned, same line). Confirm whether
   this is worth changing - the current vertical stack may read more clearly on a narrow mobile frame
   than Figma's side-by-side layout does, this is a layout call not an obvious bug.
2. **Gold-earned is a separate "NEXT ROUND GRANT" block** near the bottom of the screen, not folded into
   the headline subtitle. Figma shows `"ROUND 4 COMPLETE · +3 GOLD EARNED"` as one line right under the
   headline. The current build shows `"ROUND 4 COMPLETE"` under the headline, then a separate labeled
   `"NEXT ROUND GRANT / 12G"` block much further down. Different information architecture, not just
   styling - flag for a call on which reads better, don't assume Figma's inline version is correct by
   default.
3. **A "MILESTONE +5G" line appears at the very bottom** of the current build with no Figma equivalent
   visible in the reference screenshot - likely a separate bonus-trigger indicator. Confirm what triggers
   it before touching it; may be working as intended and simply not something Figma's static mockup had
   sample data for.

## Scope

1. Add a glow treatment to `%Banner` - a pulsing outer glow for the win state (teal), consistent with
   the Main Menu logo's existing CRT/chromatic approach if that's already a proven pattern, or a simpler
   shader/shadow-based glow if not. Coordinate with #35 on whether the defeat state's desaturation
   (their scope) and this issue's glow (this scope) are compatible effects applied together, or mutually
   exclusive design choices - don't assume, ask.
2. Style the payout line ("NEXT ROUND GRANT: 12G" or similar, from `_animate_payout()`/
   `_set_payout_display()`) as a small stat readout rather than plain text, if it isn't already - check
   `RoundEndScene.tscn` for its current node type before assuming it needs work.
3. Continue/New Run buttons - confirm whether they already use `build_button_style()`/a themed style, or
   need the same CTA-pill treatment discussed in #68 for the Main Menu Play button. #68 landed
   `ThemeBuilder.build_cta_style()` (merged) - reuse it here rather than inventing a second CTA treatment.
4. Do NOT add a "VIEW REPORT" link to `BattleReportScene` - the real navigation order already routes
   through the report before reaching this screen (see above). This is the one item from the original
   Figma-derived scope that should be actively rejected, not just left as an open question.
5. Raise the LIFE/TRIUMPH layout, gold-earned placement, and MILESTONE-line questions in the PR
   description with a recommendation each - same pattern as the banner glow/desaturation question.

## Files

`scenes/round_end/RoundEndScene.gd`, `scenes/round_end/RoundEndScene.tscn`.

## Testing

All 4 `RoundEndPreviewHarness` `SYNGRID_RESULT` modes (`win`/`loss`/`dead`/`victory`) screenshotted at
2x zoom minimum on the banner region specifically.
