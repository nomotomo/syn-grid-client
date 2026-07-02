# PRD: C7 - Round End, Run Lifecycle, and Session State Authority

Status: Approved direction (user selections 1a, 2a, 3a, 4a on 2026-07-02).
Owner: Claude Code (Lead Architect).
Implementers: Cursor (server issues in `sync-grid`, client LLD to follow).

## Problem

The game loop currently dead-ends after combat.
`FinalizeRound` is never called by the client, so life, triumph, and elimination never change.
The round counter is client-owned, in-memory, and trusted by the server, so it resets to 1 on every app launch and can be spoofed for better shop tiers.
`AwardRoundGold` credits on every call, so a modified client can farm gold.
There is no way to recover session state after an app restart, and no way to start a new run after elimination or victory.

## Goals

1. Close the round loop: combat result -> round end ceremony -> next round prep, with life hearts, triumph orbs, and the gold payout presented per the juice contract.
2. Make the server the authority for round number, round gold, and run lifecycle.
3. Survive app restarts: a relaunched client resumes the same run at the correct round with the correct board.
4. Allow a finished run (eliminated or 10 triumphs) to start fresh without losing identity, profile, or history.

## User stories

- As a player, after the combat replay I see a round-end screen that shows the life I lost or the triumph I gained, my gold payout for the next round, and a button to continue.
- As a player, when I lose my last life I see a game-over screen and can immediately start a new run.
- As a player, when I reach 10 triumphs I see a victory screen, my run is recorded, and I can start a new run.
- As a player, if I kill the app and relaunch, I am back on the prep screen at the same round with my board intact.
- As an operator, I can trust that gold balances and round numbers in the database were computed only by the server.

## Functional requirements

### Server (sync-grid)

- FR-S1: `AwardRoundGold` is idempotent per `(player_id, round)`; replays return the originally awarded amount and current balance without crediting again.
- FR-S2: `FinalizeRound` persists `current_round = round + 1` on the calling participant's grid record and returns `next_round`.
- FR-S3: A new `GetActiveGrid` RPC (`GET /v1/me/grid`) returns the caller's persisted grid, including current round, equipped items, bench, life, triumph, and gold.
- FR-S4: A new `ResetRun` RPC (`POST /v1/run/reset`) resets a terminal run (life <= 0 or triumph >= 10) to a fresh state, preserving identity, profile, match history, and season history.

### Client (sync-grid-client)

- FR-C1: RoundEndScene plays the win/loss banner, life-heart shatter (loss) or triumph-orb fill (win), then the gold payout, per `docs/juice_manual.md`.
- FR-C2: The client calls `FinalizeRound` when the combat replay ends (or is skipped), then `AwardRoundGold` for the next round from the round-end screen.
- FR-C3: `GameState.current_round` is only ever set from server responses (`next_round`, `GetActiveGrid`), never incremented locally.
- FR-C4: On boot after authenticate, the client calls `GetActiveGrid` and rehydrates round, board, bench, life, triumph, and gold.
- FR-C5: Terminal states route to game-over or victory screens with a NEW RUN button wired to `ResetRun`.
- FR-C6: The fatal-HP-loss audio treatment (low-pass sweep on the BGM bus) triggers when the round-end screen shows a life-point loss.

## Non-goals

- Season rewards, rank-up ceremonies, and leaderboards UI (C8).
- Real audio assets (C9).
- Detecting and resuming a match that crashed between StartMatch and FinalizeRound mid-replay; the recovered client simply re-fights the round (StartMatch is idempotent while a match is IN_PROGRESS).
- Grid expansion beyond 4x4 by round tier.

## Success criteria

- A full run can be played to elimination or victory and then restarted, entirely through the UI.
- Killing the app at any point and relaunching resumes the same run at the same round.
- Calling `AwardRoundGold` twice for the same round changes the balance exactly once (verified by server test and client E2E).
- The API E2E harness passes with the new endpoints included.
