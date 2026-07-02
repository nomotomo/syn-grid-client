# HLD: C7 - Round End and Server State Authority

PRD: `docs/prd/c7-round-end.md`.
Server issues: sync-grid #34 (award dedup), #35 (next_round), #36 (GetActiveGrid), #37 (ResetRun).

## Round loop sequence (target state)

```
Boot:
  Authenticate ──> GetActiveGrid ──> hydrate GameState ──> MainMenu ──> Prep

Round N:
  Prep (buy/place) ──> StartMatch ──> CombatReplay plays log
    replay finished or skipped
      ──> FinalizeRound(attacker, defender, winner, N)
            server: loser -1 life, winner +1 triumph, caller round -> N+1
            returns: attacker_state, defender_state, gold_rewarded, next_round
      ──> RoundEndScene
            banner + hearts/orbs + triumph milestone sting
            AwardRoundGold(N+1, won)   [idempotent server-side]
            gold payout counter juice
      ──> terminal? ──> GameOver / Victory screen ──> ResetRun ──> Prep (round 1)
      ──> else CONTINUE ──> Prep (round N+1, round from next_round)
```

## Server changes (sync-grid)

### 1. Idempotent AwardRoundGold (issue #34)

A `gold_awards` ledger table keyed `(player_id, round)` records each grant inside the same transaction as the credit.
A replayed call finds the existing row and returns the recorded amount plus the current balance without crediting.
The Redis-only deployment (no DATABASE_URL) uses a `SETNX`-guarded key with the same semantics.
The proto response shape is unchanged.

### 2. FinalizeRound returns next_round (issue #35)

`FinalizeRoundResponse` gains `int32 next_round = 4`.
The server persists `CurrentRound = round + 1` on the calling participant's grid record in the same save that applies life and triumph changes.
Only the caller's round advances; the ghost's own run is untouched by being fought.

### 3. GetActiveGrid (issue #36)

`GET /v1/me/grid` returns the caller's persisted grid record (the server already saves it on purchase and finalize).
`NOT_FOUND` means a brand-new player; the client starts a fresh round 1 locally.
The response includes gold balance read from the economy ledger so the client hydrates one source of truth.

### 4. ResetRun (issue #37)

`POST /v1/run/reset` requires the caller's record to be terminal: `life_points <= 0` or `triumph_count >= 10`.
Non-terminal callers get `FAILED_PRECONDITION`, which blocks mid-run reset abuse (dodging a bad economy or a lost fight).
Reset restores: life 5, triumph 0, round 1, empty board and bench, gold set to the starting credit, gold_awards rows cleared, leaderboard triumph entry zeroed.
Identity, token, profile, match history, and season history persist.

## Client changes (sync-grid-client)

- `ApiClient`: two new signal pairs (`get_active_grid_*`, `reset_run_*`); `finalize_round_completed` already exists.
- `GameState`: `hydrate_from_grid(data)` sets round, board, bench, life, triumph, gold; `current_round` writes happen only in hydrate paths.
- `CombatReplayScene`: on playback finished or skip, calls `FinalizeRound`, then routes to RoundEndScene with the response.
- `RoundEndScene` (new): banner, heart shatter or orb fill, milestone sting when `gold_rewarded > 0`, then claims `AwardRoundGold(next_round, won)` and plays the payout.
- `MainMenu`: after authenticate, calls `GetActiveGrid` before enabling ENTER THE GRID.
- Terminal screens: game-over and victory variants of RoundEndScene with NEW RUN wired to `ResetRun`.
- Detailed node trees, tween specs, and error contracts land in `docs/low-level-design/` after this HLD is approved.

## Data model impact

- New Postgres table `gold_awards(player_id TEXT, round INT, amount INT, created_at TIMESTAMPTZ, PRIMARY KEY(player_id, round))` via the standard migration mechanism.
- No changes to the existing `players` or leaderboard schemas beyond values written.

## Trade-offs and Risks

- **Two-call round transition.** FinalizeRound and AwardRoundGold remain separate RPCs (option 3a) instead of one fused call (option 3b considered).
  A client crash between them leaves the award unclaimed, not double-paid; the next round-end or a re-entry claims it because the server dedup makes claims idempotent.
  Mitigation: the client re-requests the award for the current round whenever RoundEndScene or Prep loads and the grant is unclaimed; replays are free.
- **5x load spike.** Every new RPC is a single-row read or a two-row transaction; GetActiveGrid adds one read per app boot, not per round.
  The heavy path stays StartMatch (combat simulation), which is unchanged.
  Rate limiting (60 rpm per player) already bounds all four new endpoints.
- **Network partition between gRPC server and Postgres.** FinalizeRound's round-advance shares a transaction with life/triumph persistence, so partial writes cannot desync round from life.
  If the ledger credit succeeds but the gold_awards insert cannot (same transaction), both roll back; the client retries safely.
- **Redis matchstate loss.** If Redis loses matchstate, FinalizeRound rejects with match-not-started while the round was already fought.
  Mitigation documented in issue #35: on `matchNotStartedError` the client offers re-fight (StartMatch is deterministic per seed only within a run, so the outcome may differ; acceptable for ghosts).
- **Ghost record contention.** FinalizeRound writes both participants' records; two players fighting the same ghost concurrently can interleave life decrements.
  Existing behavior, unchanged by this design; acceptable for the asymmetric-async model and noted for a future optimistic-locking pass.
- **ResetRun griefing surface.** Terminal-state precondition means an attacker cannot reset an opponent (auth token scopes to self) nor reset mid-run to dodge losses.
  Leaderboard zeroing on reset means a completed 10-triumph run must be recorded by C8 season snapshots before reset; until C8 lands, victory resets forfeit the leaderboard slot, which is acceptable pre-season.
