# LLD: Issue #72 - Leaderboard Neon Grimoire Visual Pass

Client issue: #72 (epic #42, Wave 7). Depends on #67 (merged). Distinct from #39 (E12 Leaderboard
polish - league chips, blocked on sync-grid #51).

## Verified against live-rendered current state + code read

`SYNGRID_SCREENSHOT=/tmp/x.png godot --path . --resolution 540x960 scenes/leaderboard/LeaderboardPreviewHarness.tscn`,
zoomed to 1.8x on the top-3 rows specifically (not thumbnail scale - see this review's other LLDs for
why that matters here).

### Already correct - do not touch (original scope got this wrong)

**Medallion glow already exists.** `_make_rank_badge()` (`LeaderboardScene.gd:228-263`) renders each
top-3 medal at 72px with a per-tier soft outer glow (`Color(glow_color, 0.35)` `ColorRect`, 6px offset,
additive-feel blend, explicitly commented as "Neon Grimoire" work). Confirmed visible at 1.8x zoom -
gold/silver/bronze tinted glow behind each medal. **Not a gap.** One real nuance worth a one-line note in
the PR, not a rewrite: the glow is a rectangular `ColorRect`, not a radial gradient, so it reads as a
soft box behind a circular medal rather than a circular halo - fine to leave as-is unless a reviewer
specifically wants a radial shape, since the difference is subtle and the existing approach is
explicitly documented as a deliberate cheap-on-mobile choice ("no shader needed").

**Self-row (`is_self`) emphasis already exists.** `LeaderboardScene.gd:148-161` - self row gets
`ACCENT_TEAL` border (vs `BORDER_DIM` for others) and taller row height (80px vs 68px for non-top-3
rows). Confirmed working in the original screenshot review (row #5 "Preview Operative" had a visibly
brighter border).

### Real, confirmed gap

**No podium arrangement.** `_list_box` (`LeaderboardScene.gd:40`) is a single `VBoxContainer`; every row
including ranks 1-3 is added sequentially via `_list_box.add_child(row)` (lines 103, 152). Ranks 1-3 get
a taller row (88px, line 159) and a medallion, but they're still plain sequential list rows, not the
raised/staggered 2nd-1st-3rd podium layout the Figma reference shows.

### Two more real gaps found on full re-comparison (beyond this issue's original scope)

1. **Triumph is shown as a bare number, inconsistent with every other screen in the app.**
   `LeaderboardScene.gd:210` - `triumph_label.text = str(triumph)`, no suffix. Figma shows `"T 9/10"`
   (value/max). More importantly: this is inconsistent with the rest of the *real* app, not just Figma -
   the HUD pill (post-#67) and Round Result both show Triumph as `"N/10"` against the real
   `MAX_TRIUMPH = 10` constant (`RoundEndScene.gd`). Leaderboard is the odd one out today. This is worth
   fixing regardless of the Figma comparison, since it's an internal consistency gap, not just a
   stylistic mismatch.
2. **No "YOU" text badge on the self row.** Confirmed by grep - no `"YOU"` string or equivalent anywhere
   in `LeaderboardScene.gd`. The self row is only distinguished by the border color/row-height treatment
   already noted above. Figma adds an explicit "YOU" label next to the player's own name. Minor, real,
   cheap to add.

## Scope

1. Restructure the top-3 rendering so ranks 1-3 render in a podium arrangement (rank 1 center and
   visually raised, 2 and 3 flanking at a lower position) instead of continuing the plain vertical list
   for those three rows specifically. Ranks 4+ keep the existing `_list_box` vertical list unchanged.
   This likely means splitting row-building into two paths: a new `HBoxContainer`-based podium row for
   ranks 1-3 (built once, not through the per-row loop), and the existing loop starting at rank 4.
2. Leave `_make_rank_badge()`'s glow and the self-row emphasis untouched - both are already correct.
3. Change `triumph_label.text` to `"%d/%d" % [triumph, MAX_TRIUMPH]` (or reference wherever `MAX_TRIUMPH`
   should live if it's not already a shared constant accessible here - check `RoundEndScene.gd` for the
   existing constant before adding a duplicate).
4. Add a small "YOU" label next to the display name on the self row only (`is_self == true`).

## Files

`scenes/leaderboard/LeaderboardScene.gd`.

## Testing

`LeaderboardPreviewHarness` screenshot at 1.5-2x zoom on the top-3 region, confirming a podium layout
(not three sequential rows) while ranks 4+ still render as a normal list below it.
