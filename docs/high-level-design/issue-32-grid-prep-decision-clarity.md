# HLD: E5 - Grid-Prep Decision Clarity

PRD: folded into this HLD (client-only presentation pass over data the client already receives or can
locally derive from server-authored receptor tables; no new gameplay rule - see "Goals" below).
Client issue: sync-grid-client#32 (Client Experience Roadmap epic #42, Wave 3).
Source docs: `docs/improvements.md` §2.1, §2.3, §2.5, §2.6, §10.3.

## Problem

`GridPrepScene` is the screen every round starts on, and today it only tells the player what happened
*after* they commit to an action:

1. No feedback on whether a card mid-drag would form a synergy until it is actually dropped and
   `ValidateGrid` returns - "guess and check" placement.
2. A confirmed synergy link lights up the border shader but the two item cards themselves show no reaction
   - the moment a link *forms* has no card-level acknowledgment, only the strip.
3. Building a full board from a fresh bench is entirely manual placement, one drag at a time - no
   fast-path for a player who wants to get straight to fighting.
4. Selling from the bench flashes the recycler red but never previews the payout before release.
5. A triple-merge on purchase plays a fixed-color particle burst regardless of what tier it produced, and
   - separately from the visual gap - the detection powering it is a client-side guess, not the server's
     own signal.

## Data-shape check (before design, not after)

Checked directly against `sync-grid/internal/models/models.go`, `internal/inventory/inventory.go`, and
`docs/api_contract.md` before designing around them, per the standing rule from prior LLDs in this repo:

- **Synergy adjacency data already exists client-side.** Every `Item` the server sends (bench and
  equipped) carries `synergy_receptors: SynergyReceptor[]` (`{direction, accepts_type, modifier_pct}`) -
  the exact same data `internal/inventory/inventory.go:118` (`ComputeSynergies`) reads server-side. A
  client-side preview that reads these receptor fields and does a cardinal-adjacency check is **reading
  server data, not duplicating server rules** - it satisfies issue #32's own acceptance criterion
  ("synergy adjacency read from server data only, no client rule duplication"). Confirmed direction
  semantics from `ComputeSynergies`: a receptor's `direction` is probed *from* the item that owns it, and
  rotation (`item.rotated`) rotates that direction 90° clockwise per step
  (`inventory.go:129-131`, `RotateDir`) before probing.
- **`merges[]` already exists on the purchase response and is already unused.** `docs/api_contract.md`
  line 98 documents `POST /v1/shop/purchase` returning
  `"merges": [{"consumed_item_ids": [...], "produced_item": {...Item...}}]`, explicitly stating "the
  client never computes merges." `GridPrepScene._on_purchase_item_completed` (current code,
  `GridPrepScene.gd:423-451`) does not read this field at all - it re-derives "did a merge happen" by
  scanning the post-purchase bench for any item with `level >= 2` not seen in `_known_bench_ids` before.
  This is exactly the kind of client rule duplication the contract forbids, and it is also fragile: it
  cannot distinguish two independent merges in the same purchase (a double-merge cascade, 9 copies -> one
  Level-3, already covered by server-side `sync-grid#47` tests) and can misfire if a Level 2+ item already
  existed in the account from a previous round's merge and simply gets reordered on re-render. Fixing this
  is in scope for this issue's merge-flash work (confirmed with the user, see the client issue #32 comment
  log) - it is the correct, minimal-risk source for the flash trigger, not an unrelated cleanup.
- **`sell_price` is not on the wire `Item` object.** Confirmed by reading `internal/models/models.go:88-100`
  - only the server's internal shop-template table (`internal/shop/shop.go`) knows each template's
    `SellPrice`. §2.5's "SELL: +Ng" preview text cannot be shown without either a server change or the
    client guessing a gold amount, which the client must never do (critical rule 1). **Decision (confirmed
    with the user): escalate and descope.** Filed `sync-grid#77` requesting the field. This pass ships the
    other four sub-items; the gold-amount text in §2.5 becomes a small fast-follow once `sync-grid#77`
    lands. The recycler's existing red-hover danger cue (already shipped, `_recycler_hot_style` in
    `GridPrepScene.gd:81-83,549-551`) is untouched and already satisfies most of §2.5's intent on its own.

## Goals

1. **Synergy preview overlay** (§2.1): while a card is mid-drag, render faint `SynergyBorder` strips
   between the drag-target anchor and every already-placed neighbor it would link with, using only
   receptor data both items already carry.
2. **Placed-synergy pulse** (§2.6): the moment `ValidateGrid` reports a synergy link that wasn't active a
   moment ago, both cards play a one-shot elastic scale pulse (1.0 -> 1.08 -> 1.0, 200ms) - independent of,
   and in addition to, the existing border-strip fade-in.
3. **Auto-arrange** (§2.3): one button places every bench item into the grid in a naive greedy
   best-synergy configuration (confirmed algorithm: process bench items in bench order, for each pick the
   empty cell maximizing receptor-match count against already-placed neighbors, ties broken by reading
   order A1..D4).
4. **Merge flash** (§10.3, folded into this issue per the epic): particle burst + tier-colored radial ring
   at the produced item's card, driven by the purchase response's `merges[]` array instead of the current
   bench-scan heuristic.
5. **Sell preview** (§2.5): descoped to a follow-up pending `sync-grid#77` (see above). Not built this pass.

## Design

### Shared primitive: `_synergy_match(item_a, item_b, dir_a_to_b) -> float`

Every goal except the merge flash reduces to the same question - "if item A sits at cell X and item B
sits one step away from X in direction D, do they synergize, and by how much?" One pure function answers
it by reading only `synergy_receptors`, checked in both directions (A's receptors pointed at B, and B's
receptors pointed back at A - `ComputeSynergies` evaluates every equipped item as a `src` independently, so
either side can be the one carrying the active receptor):

```gdscript
# Returns the larger of (A's receptor toward B) and (B's receptor toward A), or 0.0 if neither matches.
# dir_a_to_b: "NORTH"|"SOUTH"|"EAST"|"WEST" - the cardinal step from A's cell to B's cell.
static func _synergy_match(item_a: Dictionary, item_b: Dictionary, dir_a_to_b: String) -> float
```

The synergy preview overlay (goal 1) and the auto-arrange scorer (goal 3) both call this instead of each
re-deriving receptor logic - one implementation, two call sites, matching the "shared data model" pattern
used in prior HLDs in this repo (e.g. issue-29's `_cumulative_damage_by_item_id`).

### 1. Synergy preview overlay

Extends the existing per-frame drag-hover logic in `_process` (`GridPrepScene.gd:523-552`), which already
computes `valid_anchor` every frame at zero extra network cost (no `ValidateGrid` call happens during
drag today - that call only fires after an actual drop, in `_place_card`/`_unplace_card`). The preview
reuses that same cadence: for the current hover anchor, walk its 4 cardinal neighbor cells, call
`_synergy_match` against each occupied one, and show a faint (lower fade-in alpha than a confirmed link)
`SynergyBorder` strip on any edge that matches - the exact same strip component and shader already used
for confirmed synergies (`scenes/ui/SynergyBorder.tscn`), so a preview link and a confirmed link read as
the same visual language, just dimmer. Strips are rebuilt every frame the hover anchor changes (same
change-detection guard the existing highlight logic already has at `GridPrepScene.gd:542`), not every
frame unconditionally.

### 2. Placed-synergy pulse

`_on_validate_grid_completed` (`GridPrepScene.gd:820-841`) already computes `fresh` - the list of synergy
entries whose key wasn't in `_known_synergy_keys` last call. Today `fresh` only drives the staggered audio
chime. Add one more consumer of the same array: for each fresh entry, look up its `source_item_id` and
`target_item_id` in the existing `_cards_by_item_id` map and call a new `ItemCard.play_synergy_pulse()` on
both. No new state, no new signal - purely a second use of data already being iterated.

### 3. Auto-arrange

New button, code-created (not a `.tscn` edit, matching the "new nodes are code-created" convention from
prior LLDs in this repo) beside `%StartMatchButton`. On press: snapshot `GameState.bench_items` (a fixed
list, since the loop mutates the live bench as it goes), and for each item in that snapshot order, find
the empty cell (from `_cells`, already in reading order) that maximizes the sum of `_synergy_match` against
every already-occupied neighbor, ties broken by first-in-`_cells`-order (already = reading order). Place
greedily, one at a time, so each placement's neighbor set includes every item placed earlier in the same
run - later bench items can synergize with items the button itself just placed. Items with no
synergy-positive cell available fall back to the first empty cell that fits their footprint (never leaves
a placeable item stranded on the bench).

Reuses the exact placement machinery `_place_card` already implements (footprint claim, `GameState`
mutation, snap bounce, particle burst) via one small refactor: `_place_card`'s tail (everything after the
card is already parented into the target cell) becomes a shared `_finish_placement` helper that both the
manual-drag path and the auto-arrange path call - the only difference between the two call sites is which
container the card is removed from beforehand (`_drag_layer` for a drag-drop, `_bench_row` for
auto-arrange). One `ValidateGrid` call fires after the whole batch completes, not once per item, to avoid
spamming the network for what the player experiences as a single action.

### 4. Merge flash

`_on_purchase_item_completed` (`GridPrepScene.gd:423-451`) swaps its bench-scan heuristic for a direct read
of `data.get("merges", [])`. For each entry, `produced_item.level` drives the ring/particle tint via the
palette's existing `tint_for_tier` lookup (already used by `ItemCard._apply_rest_style`) instead of the
current fixed purple, so a Level-2 merge and a Level-3 merge read as visually distinct tiers, matching
§10.3's "tier-colored radial ring." Multiple entries (a double-merge cascade) stagger the same way
newly-formed synergy chimes already do (`synergy_chime_stagger`, `GridPrepScene.gd:835-838`) - one flash
each, not simultaneous.

## Trade-offs and Risks

- **The preview is a best-effort approximation, not a second source of truth.** `_synergy_match` checks
  single-cell cardinal adjacency; the server's real `ComputeSynergies`/`probeCells` walks the full edge of
  a multi-cell item's footprint. For the single-cell items that make up the overwhelming majority of the
  current shop catalog this is exact; for multi-cell weapons it can occasionally miss or over-show a link
  on an edge cell the simplified check doesn't probe. This is an acceptable and *safe* simplification
  specifically because the preview never gates or replaces the real `ValidateGrid` call after drop - it is
  advisory only, so a preview/reality mismatch is a cosmetic near-miss, never a state desync or an exploit.
  If multi-cell item variety grows enough that mismatches become noticeable in practice, tighten
  `_synergy_match`'s neighbor-cell walk to match `probeCells` exactly - flagged here so a future reader
  knows this is a deliberate scope line, not an oversight.
- **5x load / fault tolerance / network partitions**: not applicable to goals 1, 2, and 4 - all three are
  pure rendering passes over data already in memory (receptors on items already fetched, or fields already
  on the purchase response), zero new network calls. Goal 3 (auto-arrange) makes exactly the same one
  `ValidateGrid` call a manual multi-item placement session would already make, batched instead of
  per-item - if anything it is a *reduction* in request volume relative to a human placing the same items
  one at a time.
- **Auto-arrange determinism**: the greedy algorithm is a client-side *visual arrangement choice*, not a
  game-rule computation - the server still authoritatively validates the resulting grid via the same
  `ValidateGrid` call any manual placement triggers, and still rejects anything invalid. A buggy client
  arrangement can only produce a suboptimal-looking board, never an invalid or unfair one.
- **Merge-flash refactor touches a purchase-response code path already covered by production traffic.**
  Swapping the trigger source (heuristic -> `merges[]`) changes behavior on every purchase, not just
  merge-adjacent ones, so it needs explicit regression coverage: a purchase with zero merges must show zero
  flashes (the old heuristic's false-negative surface), and a purchase whose response omits `merges`
  entirely (older cached fixture, or a purchase that legitimately had none) must not error on a missing key
  - `data.get("merges", [])` already defaults safely, but the harness fixture used for
    `GridPrepPreviewHarness` needs a `merges` array added to stay representative of the real contract shape.

## Sequencing

Single PR, single branch (`feature/issue-32-grid-prep-decision-clarity`), matching this repo's
one-issue-one-PR convention - all four in-scope sub-items touch the same file
(`scenes/grid_prep/GridPrepScene.gd`) and share the `_synergy_match` primitive, so splitting them would
mean re-deriving the same receptor-reading logic multiple times for no isolation benefit. No dependency on
any other open client issue. No server dependency for goals 1-4 (server-side M1/`merges[]` already shipped
in `sync-grid#47`/#74-#76); goal 5 (sell preview) is explicitly deferred behind `sync-grid#77`.
