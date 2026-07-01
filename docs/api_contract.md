# Syn-Grid REST API Contract (Client Reference)

This document describes the HTTP/JSON API that the Godot client calls.
The Go server exposes these endpoints via a `grpc-gateway` sidecar that translates HTTP/JSON to gRPC.
All requests require `Authorization: Bearer <token>` except `POST /v1/authenticate`.

Server base URL (local dev): `http://localhost:8080`
Server base URL (production): configured via `ApiClient.gd` `BASE_URL` export var.

---

## Authentication

### POST /v1/authenticate

No auth header required.

Request:
```json
{ "device_id": "stable-uuid-string" }
```

Response:
```json
{
  "token": "hmac-signed-session-token",
  "expires_at_unix": 1234567890
}
```

Store the token in `GameState.token`.
Re-authenticate when the token is within 5 minutes of expiry or any request returns `401`.

---

## Shop

### POST /v1/roll_shop

Request:
```json
{ "round": 3 }
```

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

Roll is deterministic per player+round. Calling this twice returns the same slots.
Cache the response in `GameState.current_shop_slots` for the duration of the round.

### POST /v1/purchase_item

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

`updated_grid.bench_reserve` contains all items the server knows about.
Update `GameState.gold = new_balance`.
Add new bench items to the local item state.

### POST /v1/sell_item

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

### POST /v1/validate_grid

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
        "base_attributes": { "base_dmg": 12.0, "act_cooldown": 1.5 }
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

Call this after every item placement/removal to get live synergy feedback.
Trigger the synergy glow shader for each returned synergy pair (see `juice_manual.md` section 3).

---

## Combat

### POST /v1/start_match

Request: the full current Grid (same shape as ValidateGrid).

Response:
```json
{
  "status": "MATCH_STATUS_PLAYED",
  "combat_log": {
    "attacker_id": "player-device-uuid",
    "defender_id": "ghost-player-uuid",
    "winner_id": "player-device-uuid",
    "total_ticks": 143,
    "events": [
      {
        "tick": 15,
        "firing_item_id": "uuid-of-shortsword",
        "target_player_id": "ghost-player-uuid",
        "synergy_bonus": 0.0,
        "crit_chance": 0.05,
        "crit": false,
        "shield_absorbed": 0.0,
        "hp_loss": 12.0,
        "target_hp_after": 88.0
      }
    ],
    "attacker_hp_final": 72.5,
    "defender_hp_final": 0.0
  }
}
```

`status` values: `MATCH_STATUS_PLAYED`, `MATCH_STATUS_NO_OPPONENT`.
Store the `combat_log` in `GameState.last_combat_log`.
Navigate to `CombatReplayScene` and pass the log for playback.

**Playback rule:** queue all events, play one per 0.10s.
2-frame hit-stop + 1-frame white flash on `crit=true` events.

### POST /v1/award_round_gold

Request:
```json
{ "round": 3, "won": true }
```

Response:
```json
{ "gold_awarded": 13, "new_balance": 27 }
```

Call at the START of each round (round 1 with `won: false` for the initial grant).

### POST /v1/finalize_round

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

`gold_rewarded` is non-zero when a triumph milestone crossed (e.g. 5th triumph).
`attacker_state.eliminated = true` means `life_points` reached 0 - trigger game-over screen.
`attacker_state.triumph_count >= 10` means victory - trigger victory screen.

---

## Leaderboard & Season

### POST /v1/get_leaderboard

Request:
```json
{ "top_n": 20 }
```

Response:
```json
{
  "entries": [
    { "rank": 1, "player_id": "uuid", "triumph_count": 9 }
  ]
}
```

### POST /v1/get_active_season

Request: `{}`

Response:
```json
{
  "season_id": 1,
  "name": "Season 1",
  "ends_at_unix": 1234567890,
  "caller_rank": 5
}
```

Returns `404` when no active season exists.
Returns `412 Precondition Failed` when DATABASE_URL is not set on the server.

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
  level:            int      (1-3, upgrades via triple-merge)
  dimensions:       { width: 1, height: 1 }   (always 1x1 currently)
  placement_coords: { x: 0-3, y: 0-3 }        (null when on bench)
  item_type:        "WEAPON" | "ARMOR" | "AUXILIARY" | "POTION"
  weapon_category:  "MELEE" | "RANGED" | "ARCANE" | ""
  base_attributes: {
    base_dmg:        float
    act_cooldown:    float   (seconds between attacks)
    stamina_per_use: float
    mana_cost:       float
    armor_rating:    float
  }
  synergy_receptors: []      (server-validated, client reads from ValidateGrid response)
}
```
