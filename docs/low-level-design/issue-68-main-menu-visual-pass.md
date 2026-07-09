# LLD: Issue #68 - Main Menu Neon Grimoire Visual Pass

Client issue: #68 (epic #42, Wave 7). Depends on #67 (merged, `e25e621`).
Juice contract: `docs/juice_manual.md` sections 1-3. Token reference: `docs/design-tokens-neon-grimoire.md`.

## Verified against live-rendered current state

`SYNGRID_SCREENSHOT=/tmp/x.png godot --path . --resolution 540x960 scenes/main_menu/MainMenuPreviewHarness.tscn`,
inspected at 3x zoom, not eyeballed at thumbnail size.

### Already correct - do not touch

- HUD row (Round/Gold/Life/Triumph) now shows correct per-stat pill colors - #67 fixed this and it's
  shared via `StatsHud`, Main Menu gets it for free.
- The aurora shader on `PlayButton` **is** rendering - confirmed visually, a teal→purple gradient rim is
  visible on the button's left/right edges at 3x zoom. It was not a missing effect, just subtle enough
  to miss at thumbnail scale in an earlier pass of this review - don't re-report it as absent.

### The real, confirmed gap

1. **Play button shape**: `PlayButton` (`MainMenu.tscn:180-185`) has no per-instance style override, so
   it inherits the global `Button` theme style - `ThemeBuilder.build_button_style()`
   (`ThemeBuilder.gd:96-114`) with `BUTTON_CORNER_RADIUS = 12`. The button is `custom_minimum_size =
   Vector2(0, 150)` - a 12px radius on a 150px-tall button reads as barely-rounded, not the full pill
   Figma's reference shows. This is a real, confirmed shape gap (unlike the false one from the first
   draft of #67's LLD - this one's been visually verified at high zoom, not inferred).
2. **Aurora animation unverified**: the shader renders correctly in a single frame, but a static
   screenshot cannot prove the `aurora_speed` rotation is actually animating at runtime. Don't claim to
   have verified this either way without checking in the running editor or a multi-frame capture.
3. **Identity card placement**: the current build shows a player identity card (avatar circle, name,
   long ID string, Edit button) directly below the logo, above the HUD row. This isn't in the Figma
   reference at all - Figma's Main Menu goes straight from logo to season banner to HUD to Play button,
   with identity handled via a separate Profile modal (already covered by `MainMenu.gd`'s existing
   `_confirm_name_button` flow, unrelated to this card). Confirm with whoever owns product intent
   whether this card should move into the Profile modal or stay - **do not delete it without checking
   first**, it may be intentional and simply not something the Figma pass covered.
4. **No Daily/Codex quick-icon row**: confirmed absent. Figma reference shows two tiles below Play.
   Codex ties to issue #34 (Profile hub, not yet built) - only add the tile/entry point here, don't
   build Codex content. Daily ties to issue #40 (retention pack, not yet built) - same, entry point only.
5. **Bottom nav has no icons**: current nav reads `HOME / RANKS / SEASON / EDIT NAME` as plain text
   labels. Figma shows a small glyph per tab (hexagon/diamond/triangle/circle motif). Note also the
   current label is `EDIT NAME`, not `PROFILE` - confirm whether this is intentional (this tab opens the
   name-edit popover directly, per `MainMenu.gd`'s `_confirm_name_button` wiring) before renaming it to
   match Figma's "PROFILE" label, since the current label may more accurately describe what it does.

## Scope

1. Give `PlayButton` its own style override (either a new `ThemeBuilder.build_cta_style()` following the
   same pattern as `build_capsule_style()`/`build_button_style()`, or a per-instance
   `theme_override_styles/normal` in the .tscn) with a full pill radius appropriate to its 150px height.
   Reuse `build_capsule_style`'s corner-radius-clamping approach (over-specify the radius, let Godot
   clamp) rather than computing an exact pixel value.
2. Add the Daily/Codex tile row below the Play button (see `docs/design-tokens-neon-grimoire.md` for
   card styling patterns). Daily gets a red-dot unclaimed-reward badge - wire it to whatever state #40
   eventually exposes; if #40 hasn't landed yet, stub the badge as always-hidden rather than block on it.
3. Add bottom-nav icon glyphs. Confirm exact icon style from the Figma reference link in
   `docs/design-tokens-neon-grimoire.md` (this LLD doesn't cover icon sourcing/style).
4. Raise the identity-card and `EDIT NAME`-label questions in the PR description rather than resolving
   them unilaterally - both are product calls, not styling calls.

## Files

`scenes/main_menu/MainMenu.tscn`, `scenes/main_menu/MainMenu.gd`, `scripts/ui/ThemeBuilder.gd` (if adding
a new CTA style helper).

## Testing

`MainMenuPreviewHarness` screenshot at 2-3x zoom (not just thumbnail - this review's own first pass
missed a real effect by not zooming in, don't repeat that mistake) showing the pill-shaped Play button,
Daily/Codex row, and nav icons.
