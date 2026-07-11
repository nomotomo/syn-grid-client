# Server escalation: Daily Rewards backend (unblocks client E28 / #86)

Escalation from the syn-grid-client architect per CLAUDE.md rule 8 (backend sync).
Filed as nomotomo/sync-grid#81 (Jul 2026); this file is the spec of record on the client side.
Client-side twin: syn-grid-client #86 (E28 Daily Rewards screen), which is blocked on this work.
Design reference: `docs/design-reference/figma-make/screens/DailyRewardsScreen.tsx`, rendered at https://surly-spout-45387130.figma.site/ (⑦ DAILY REWARDS CONCEPT).

## Why

The Jul 2026 Figma design adds a Daily Rewards surface: a 7-day login streak with claimable day rewards (day 7 = grand reward) and daily missions with progress counters paying out gold or triumph.
All economy numbers must come from the server (the client renders only), so this is entirely new backend surface.

## Needed data structures (sketch - server owns the final shape)

```
DailyStreak {
  current_day   int      // 1..7, resets after day-7 claim or on a missed day
  claimable     bool     // has today's reward been claimed yet
  claimed_days  []int    // for rendering check overlays
  day_rewards   []Reward // what each of the 7 days pays, so the client never invents values
}

DailyMission {
  id        string
  label     string // display text is server-authored
  progress  int
  target    int
  reward    Reward
  completed bool
  claimed   bool
}

Reward { kind: "gold" | "triumph", amount int }
```

## Needed endpoints

1. `GET /players/{id}/daily` returning `{ streak: DailyStreak, missions: []DailyMission }`.
   Also expose a cheap unclaimed flag (or fold it into an existing player summary call) so the Main Menu tile can show its notification dot without fetching the whole payload.
2. `POST /players/{id}/daily/claim` - claims the current streak day.
   Idempotent: a second call the same day returns the already-claimed state, not an error.
   Pays into the existing gold/triumph economy server-side.
3. `POST /players/{id}/daily/missions/{mission_id}/claim` - same idempotency and payout rules.

## Persistence and rules the server must decide and document

- Day-boundary definition (UTC vs player-local) and what a missed day does to the streak.
- Mission generation cadence and pool (daily rotation), and how progress events hook into existing match/round completion flows.
- Anti-replay: claims must be transactional with the economy update.

## Definition of done

Contract merged into the client repo's `docs/api_contract.md` (the client's source of truth).
Endpoints live behind the existing auth.
Client issue syn-grid-client #86 unblocked.
