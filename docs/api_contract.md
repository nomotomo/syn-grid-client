# Syn-Grid REST API Contract (Client Reference)

This document describes the HTTP/JSON API that the Godot client calls.
The Go server exposes these endpoints via grpc-gateway, which translates HTTP/JSON to gRPC.
The source of truth is `../sync-grid/proto/sync_grid.proto`.
If this document and the proto disagree, the proto wins and this file must be updated.

All requests require `Authorization: Bearer <token>` except `POST /v1/auth`.

Server base URL (local dev): `http://localhost:8080`
Server base URL (production): configured via `ApiClient.gd` `base_url` export var.

## grpc-gateway JSON conventions

These follow from protojson serialization and apply to every endpoint.

- `int64` fields are serialized as JSON **strings**, not numbers (e.g. `"rank": "1"`).
  Affected fields: `expires_at_unix`, `rank`, `triumph_count` (leaderboard), `ends_at_unix`, `caller_rank`, `played_at_unix`.
  Convert with `int(value)` in GDScript before storing.
- `bytes` fields are serialized as base64 strings (e.g. `combat_log.seed`).
- Fields at their zero value may be omitted from the response entirely.
  Always read with `data.get("field", default)`.
- GET endpoints take parameters as URL query strings, not JSON bodies.

---

## Authentication

### POST /v1/auth

No auth header required.

Request:
```json
{ "device_id": "stable-uuid-string" }
```

Response:
```json
{
  "token": "hmac-signed-session-token",
  "expires_at_unix": "1234567890",
  "gold_balance": 10
}
```

`device_id` becomes the player's permanent identity.
Use a stable client-generated UUID persisted in `user://`.
New players are credited 10 starting gold on first authenticate.
Store the token in `GameState.token` and hydrate `GameState.gold` from `gold_balance`.
Re-authenticate when the token is within 5 minutes of expiry or any request returns `401`.

---

## Shop

### GET /v1/shop?round=N

Rolls the shop offering for the given round.

Response:
```json
{
  "slots": [
    {
      "template_name": "Shortsword",
      "item_type": "WEAPON",
      "weapon_category": "MELEE",
      "buy_price": 3,
      "base_attributes": {
        "base_dmg": 12.0,
        "act_cooldown": 1.5,
        "stamina_per_use": 10.0
      }
    }
  ]
}
```

The roll is deterministic per player + round, so calling this twice returns the same slots.
Cache the response in `GameState.current_shop_slots` for the duration of the round.

### POST /v1/shop/purchase

Request:
```json
{
  "template_name": "Shortsword",
  "round": 3
}
```

Response:
```json
{
  "updated_grid": { ...Grid object... },
  "new_balance": 19
}
```

The server re-derives the round's shop to confirm the template is available.
Triple-merge is evaluated after the item is added.
`updated_grid.bench_reserve` contains all items the server knows about.
Update `GameState.gold = new_balance` and sync the bench from `updated_grid`.

### POST /v1/shop/sell

Request:
```json
{ "item_id": "uuid-of-item-to-sell" }
```

Response:
```json
{
  "updated_grid": { ...Grid object... },
  "new_balance": 21
}
```

---

## Grid

### POST /v1/grid/validate

Request: the full current Grid object including `equipped_items` with `placement_coords`.

```json
{
  "grid": {
    "player_id": "device-uuid",
    "current_round": 3,
    "life_points": 4,
    "triumph_count": 2,
    "gold_balance": 14,
    "grid_dimensions": { "columns": 4, "rows": 4 },
    "equipped_items": [
      {
        "item_id": "uuid",
        "name": "Shortsword",
        "level": 1,
        "dimensions": { "width": 1, "height": 1 },
        "placement_coords": { "x": 0, "y": 0 },
        "item_type": "WEAPON",
        "weapon_category": "MELEE",
        "base_attributes": { "base_dmg": 12.0, "act_cooldown": 1.5 },
        "rotated": false
      }
    ],
    "bench_reserve": []
  }
}
```

Response:
```json
{
  "synergies": [
    {
      "source_item_id": "uuid-a",
      "target_item_id": "uuid-b",
      "direction": "EAST",
      "modifier_pct": 0.20
    }
  ]
}
```

Returns `400 INVALID_ARGUMENT` if the grid fails validation.
Call this after every item placement/removal to get live synergy feedback.
Trigger the synergy glow shader for each returned synergy pair (see `juice_manual.md` section 3).

---

## Combat

### POST /v1/match/start

Request: the full current Grid (same shape as grid/validate).

The server saves the player's ghost, fetches an opponent ghost, and runs a full deterministic combat simulation.
The combat log is embedded in the response so the client can replay every tick exactly.

Response:
```json
{
  "status": "MATCH_STATUS_PLAYED",
  "combat_log": {
    "seed": "base64-encoded-32-bytes",
    "attacker_id": "player-device-uuid",
    "defender_id": "ghost-player-uuid",
    "winner_id": "player-device-uuid",
    "total_ticks": 143,
    "events": [
      {
        "tick": 15,
        "firing_item_id": "uuid-of-shortsword",
        "target_player_id": "ghost-player-uuid",
        "target_item_id": "uuid-of-target-armor",
        "synergy_bonus": 0.0,
        "crit_chance": 0.05,
        "crit": false,
        "actual_damage": 12.0,
        "shield_absorbed": 0.0,
        "hp_loss": 12.0,
        "target_hp_after": 988.0,
        "target_shield_after": 0.0
      }
    ],
    "attacker_hp_final": 725.0,
    "defender_hp_final": 0.0
  },
  "opponent_grid": {
    "player_id": "ghost-player-uuid",
    "grid_dimensions": { "columns": 4, "rows": 4 },
    "equipped_items": [ ...Item objects with placement_coords... ]
  }
}
```

`status` values: `MATCH_STATUS_PLAYED`, `MATCH_STATUS_NO_OPPONENT`.
`combat_log` and `opponent_grid` are populated only when status is `MATCH_STATUS_PLAYED`.
`opponent_grid` is the ghost's public board (identity, dimensions, equipped items only).
Bench, gold, and life values are stripped server-side - they are private to the ghost.
Store it in `GameState.opponent_grid` so `CombatReplayScene` can render the enemy board.
Players start combat at 1000 HP.
Store the `combat_log` in `GameState.last_combat_log`.
Navigate to `CombatReplayScene` and pass the log for playback.

**Playback rule:** queue all events, play one per 0.10s.
2-frame hit-stop + 1-frame white flash on `crit=true` events.

### POST /v1/economy/gold/award

Request:
```json
{ "round": 3, "won": true }
```

Response:
```json
{ "gold_awarded": 13, "new_balance": 27 }
```

The server computes the award from round tier, win/loss outcome, and interest on the existing balance.
The client never supplies the amount.
Call at the START of each round (round 1 with `won: false` for the initial grant).

### POST /v1/round/finalize

Request:
```json
{
  "attacker_id": "player-uuid",
  "defender_id": "ghost-uuid",
  "winner_id": "player-uuid",
  "round": 3
}
```

Response:
```json
{
  "attacker_state": {
    "player_id": "player-uuid",
    "life_points": 4,
    "triumph_count": 3,
    "eliminated": false
  },
  "defender_state": { ... },
  "gold_rewarded": 0
}
```

`winner_id` must equal `attacker_id` or `defender_id`.
The `round` field is used for match deduplication; finalizing the same round twice is rejected.
`gold_rewarded` is non-zero when a triumph milestone was crossed (e.g. 5th triumph).
`attacker_state.eliminated = true` means life points reached 0 - trigger the game-over screen.
`attacker_state.triumph_count >= 10` means victory - trigger the victory screen.

---

## Leaderboard & Season

### GET /v1/leaderboard?top_n=N

`top_n <= 0` (or omitted) defaults to 20.

Response:
```json
{
  "entries": [
    {
      "rank": "1",
      "player_id": "uuid",
      "triumph_count": "9",
      "display_name": "PlayerName"
    }
  ]
}
```

`rank` and `triumph_count` are int64 and arrive as JSON strings.
`display_name` is an empty string when the player has not set one; fall back to a truncated `player_id`.

### GET /v1/season

Response:
```json
{
  "season_id": 1,
  "name": "Season 1",
  "ends_at_unix": "1234567890",
  "caller_rank": "5"
}
```

`caller_rank` is 0 when the caller is unranked.
Returns `404` when no active season exists (between seasons).
Returns `412 Precondition Failed` when DATABASE_URL is not set on the server.

---

## Profile & History

### PUT /v1/me/profile

Sets the calling player's display name and/or avatar.
An empty string leaves that field unchanged.

Request:
```json
{ "display_name": "NewName", "avatar_id": "avatar_03" }
```

Response: `{}`

`display_name`: 1-24 chars, alphanumeric + spaces + underscores only.
`avatar_id`: must be one of the server-approved avatar IDs.

### GET /v1/profile and GET /v1/profile/{player_id}

`GET /v1/profile` returns the calling player's own profile.
`GET /v1/profile/{player_id}` returns the public profile for any player.

Response:
```json
{
  "player_id": "uuid",
  "display_name": "PlayerName",
  "avatar_id": "avatar_03"
}
```

### GET /v1/me/history?top_n=N

Returns the calling player's most recent matches, newest first.
`top_n <= 0` (or omitted) defaults to 20.
Requires a database on the server (`412` otherwise).

Response:
```json
{
  "records": [
    {
      "attacker_id": "uuid",
      "defender_id": "uuid",
      "winner_id": "uuid",
      "round": 3,
      "played_at_unix": "1234567890"
    }
  ]
}
```

---

## Error Handling

All errors follow gRPC-gateway's error format:

```json
{
  "code": 7,
  "message": "store not configured; set DATABASE_URL",
  "details": [
    {
      "@type": "type.googleapis.com/google.rpc.ErrorInfo",
      "reason": "STORE_NOT_CONFIGURED",
      "domain": "syngrid"
    }
  ]
}
```

HTTP status codes map to gRPC codes:
- `400` = INVALID_ARGUMENT
- `401` = UNAUTHENTICATED
- `403` = PERMISSION_DENIED
- `404` = NOT_FOUND
- `409` = ALREADY_EXISTS
- `412` = FAILED_PRECONDITION
- `429` = RESOURCE_EXHAUSTED (rate limit)
- `500` = INTERNAL

In `ApiClient.gd`, check `response.get("details", [])` for the `reason` field to show user-friendly messages without parsing error strings.

---

## Grid Object Reference

```
Grid {
  player_id:       string
  current_round:   int
  life_points:     int      (max 5)
  triumph_count:   int      (max 10, triggers victory)
  gold_balance:    int
  grid_dimensions: { columns: 4, rows: 4 }
  equipped_items:  Item[]
  bench_reserve:   Item[]
}

Item {
  item_id:          string   (UUID, server-assigned)
  name:             string
  level:            int      (0 or 1 = base item; 2 = Level-2 merged)
  dimensions:       { width: int, height: int }   (canonical unrotated dims; multi-cell weapons exist)
  placement_coords: { x: int, y: int }             (anchor cell; omit when on bench)
  item_type:        "WEAPON" | "ARMOR" | "AUXILIARY" | "POTION"
  weapon_category:  "MELEE" | "RANGED" | "ARCANE" | ""  (weapons only)
  rotated:          bool     (client signals 90-degree rotation; server derives effective dims)
  base_attributes: {
    base_dmg:        float
    act_cooldown:    float   (seconds between attacks)
    stamina_per_use: float
    mana_cost:       float
    armor_rating:    float
  }
  synergy_receptors: SynergyReceptor[]  (server-defined; client reads, never edits)
}

SynergyReceptor {
  direction:    "NORTH" | "SOUTH" | "EAST" | "WEST"
  accepts_type: "WEAPON" | "ARMOR" | "POTION" | "AUXILIARY"
  modifier_pct: float
}
```
