# LLD: Main Menu - Full Structural Alignment with Figma

Follow-up to #68 (merged, `e277719`), which fixed one specific styling gap (Play button shape) per a
deliberately narrow LLD. This issue exists because that narrow scoping missed most of the actual
delta - a full top-to-bottom comparison against the Figma reference (not just re-checking #68's
original claims) found 10 real differences, most of them structural, not just stylistic.

Token/color reference: `docs/design-tokens-neon-grimoire.md`. Figma reference link is in that doc's
header (login-gated - the published `.figma.site` mirror is confirmed stale, do not use it).

## Full delta list (verified by comparing rendered screenshots side by side, top to bottom)

1. **Top status bar missing.** Figma: `SYN-GRID v2.4.1 | ● ONLINE 23:41 | avatar | gear icon` at the
   very top of the frame. Current build: none of this renders - the screen starts directly at the logo.
2. **HUD row (Round/Gold/Life/Triumph) exists in the current build but not in Figma's Main Menu at
   all.** This is the opposite of what #68's LLD assumed. Don't treat this as "needs #67's pill fix
   applied here too" - first confirm with product whether the HUD row belongs on Main Menu at all. If it
   does (there may be a good reason - players want to see their stats without entering a match), leave it
   and note the deliberate deviation from Figma. If not, this needs a decision from whoever owns product
   intent, not a unilateral removal.
3. **Identity card (avatar/name/ID/Edit) occupies the position Figma's season card uses**, pushing the
   real season card further down the layout rather than the two coexisting side by side as separate
   concerns. #68's LLD flagged this card's *existence* as a question; this issue adds that its *position*
   actively displaces other content, which is a layout problem even if the card itself turns out to be
   wanted.
4. **"Dark-Fantasy · Auto-Battler" badge missing entirely** - no equivalent element anywhere in the
   current layout.
5. **"[ SYN-GRID ]" purple subtitle line missing entirely** - same, no equivalent.
6. **Play button text is wrong, not just its shape.** Figma: "⚡ PLAY" with a lightning-bolt icon.
   Current (post-#68): "ENTER THE GRID", no icon. #68 fixed the shape without touching the label - worth
   deciding whether "ENTER THE GRID" is an intentional flavor choice (it reads more thematically
   on-brand than a generic "PLAY") before reflexively renaming it to match Figma exactly.
7. **Scrolling patch-notes ticker bar missing entirely.** Figma shows a teal ticker strip cycling
   several status lines ("Patch 2.4 live...", "Daily reward available", etc.) between the Daily/Codex
   row and the decorative rune-field. No equivalent renders in the current build.
8. **Logo wordmark mismatch** (partially known before, confirmed at high zoom): Figma renders a glowing
   "NEON GRIMOIRE" wordmark; the current build renders plain "SYN-GRID" text with no glow effect and
   different copy entirely.
9. **Season card content differs**, not just styling: Figma shows season name + a 3-item patch teaser
   ("New units · New synergies · New dread") + days-remaining. Current build shows season name + player's
   numeric rank + a full countdown timer. These may both be intentional (Figma's is more of a marketing
   teaser, current build's is more functionally useful to the player) - flag for a product decision on
   which fields actually belong here rather than blindly copying Figma's fields.
10. **Daily/Codex tiles have no icons** (already known from #68 - the Figma reference link was
    inaccessible to Cursor when #68 was implemented, so these shipped as text-only stand-ins).

## What this issue is NOT asking for

Do not treat this as "make the current build a pixel-perfect clone of Figma, delete anything Figma
doesn't have." Several of the items above (HUD row, identity card, season-card fields, "ENTER THE GRID"
label) may be deliberate, better-than-Figma choices already made by this codebase for reasons Figma's
static mockup never had to account for (Figma has no real game state to reflect). The correct process
per item:

- **Missing elements Figma has and the build doesn't** (top bar, badge, subtitle, ticker, PLAY icon) -
  these are close to unambiguous gaps, implement them.
- **Elements the build has that Figma doesn't, or that differ in content** (HUD row, identity card,
  season card fields, "ENTER THE GRID" label) - raise each as an explicit question in the PR description
  with a recommendation, do not silently delete or silently keep. Whoever reviews the PR makes the call.

## Scope

1. Add the top status bar (version, online status, avatar, settings gear).
2. Add the "Dark-Fantasy · Auto-Battler" badge and "[ SYN-GRID ]" subtitle around the existing logo.
3. Add the scrolling patch-notes ticker.
4. Add the lightning-bolt icon to the Play button; raise (don't resolve) whether "ENTER THE GRID" stays
   or becomes "PLAY".
5. Raise (don't resolve) the HUD-row-on-Main-Menu question, the identity-card-position question, and the
   season-card-fields question - each gets a paragraph in the PR description with a clear recommendation,
   not a silent decision.
6. Logo wordmark glow treatment - likely large enough to warrant checking whether this should be its own
   issue (touches font/shader work, not just layout) rather than folding into this one. Use judgment;
   note the choice.

## Files

`scenes/main_menu/MainMenu.tscn`, `scenes/main_menu/MainMenu.gd`, `scripts/ui/ThemeBuilder.gd` (badge/
ticker styling), possibly `assets/shaders/` if the wordmark glow is tackled here rather than split out.

## Testing

`MainMenuPreviewHarness` screenshot, full-screen (not just the previously-checked regions), diffed
top-to-bottom against a fresh Figma capture the same way this LLD was produced - not just re-verifying
this issue's own claims, since that's exactly the methodology gap that caused #68 to under-deliver.
