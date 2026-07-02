extends Node

# Stable device identity file - written once on first launch, reused forever.
# The server treats device_id as the player's permanent identity (api_contract.md).
const DEVICE_ID_PATH: String = "user://device_id.txt"

# Session identity
var token: String = ""
var player_id: String = ""
var token_expires_at: int = 0

# Profile (server-authoritative via GetProfile)
var display_name: String = ""
var avatar_id: String = ""

# Active season snapshot (empty when no active season / no database)
var season: Dictionary = {}

# Round state (authoritative after each server response)
var current_round: int = 1
var gold: int = 0
var life_points: int = 5
var triumph_count: int = 0

# Item state
var equipped_items: Array[Dictionary] = []
var bench_items: Array[Dictionary] = []

# Shop state (cached per round)
var current_shop_slots: Array[Dictionary] = []
var shop_round: int = 0

# Highest round whose start-of-round gold grant has been claimed. AwardRoundGold
# credits on every call, so the client claims it exactly once per round.
var gold_awarded_round: int = 0

# Last combat result (used by CombatReplayScene and RoundEndScene)
var last_combat_log: Dictionary = {}
var last_fight_won: bool = false

# Written by CombatReplayScene when FinalizeRound completes; read by RoundEndScene.
# Shape: { won, round_played, next_round, my_state, gold_rewarded }
var last_round_result: Dictionary = {}

# Opponent ghost's public board from StartMatchResponse (equipped items only)
var opponent_grid: Dictionary = {}

func is_authenticated() -> bool:
	return token != "" and Time.get_unix_time_from_system() < token_expires_at - 300

# Returns the persisted device UUID, creating and saving one on first launch.
func get_or_create_device_id() -> String:
	if player_id != "":
		return player_id
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var file := FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		if file != null:
			var saved := file.get_as_text().strip_edges()
			if saved != "":
				player_id = saved
				return player_id
	player_id = _generate_uuid_v4()
	var out := FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
	if out != null:
		out.store_string(player_id)
	return player_id

# Applies an AuthenticateResponse. int64 fields arrive as JSON strings from
# grpc-gateway (api_contract.md), so convert via str() -> int().
func hydrate_from_auth(data: Dictionary) -> void:
	token = String(data.get("token", ""))
	token_expires_at = int(str(data.get("expires_at_unix", "0")))
	gold = int(data.get("gold_balance", 0))

func _generate_uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4),
		hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func reset_for_new_round() -> void:
	# Return all equipped items to bench at round start.
	for item in equipped_items:
		item["placement_coords"] = null
		bench_items.append(item)
	equipped_items.clear()
	last_combat_log = {}

# Full session rehydration from GetActiveGridResponse.grid or ResetRunResponse.grid.
# current_round is assigned only here (and in apply_round_result) - never += 1 elsewhere.
func hydrate_from_grid(grid: Dictionary) -> void:
	var new_round := int(grid.get("current_round", current_round))
	life_points = int(grid.get("life_points", life_points))
	triumph_count = int(grid.get("triumph_count", triumph_count))
	gold = int(grid.get("gold_balance", gold))
	current_round = new_round
	var equipped: Array = grid.get("equipped_items", [])
	var bench: Array = grid.get("bench_reserve", [])
	equipped_items.assign(equipped)
	bench_items.assign(bench)
	if shop_round != new_round:
		current_shop_slots.clear()
		shop_round = 0

func apply_round_result(finalize_response: Dictionary, won: bool, round_played: int) -> void:
	var my_state := _my_player_state(finalize_response)
	life_points = int(my_state.get("life_points", life_points))
	triumph_count = int(my_state.get("triumph_count", triumph_count))
	var next_round := int(str(finalize_response.get("next_round", str(round_played + 1))))
	current_round = next_round
	last_round_result = {
		"won": won,
		"round_played": round_played,
		"next_round": next_round,
		"my_state": my_state,
		"gold_rewarded": int(finalize_response.get("gold_rewarded", 0)),
	}

func _my_player_state(finalize_response: Dictionary) -> Dictionary:
	var attacker: Dictionary = finalize_response.get("attacker_state", {})
	var defender: Dictionary = finalize_response.get("defender_state", {})
	if String(attacker.get("player_id", "")) == player_id:
		return attacker
	if String(defender.get("player_id", "")) == player_id:
		return defender
	return attacker if not attacker.is_empty() else defender

func sync_bench_from_server(server_bench: Array) -> void:
	# Server bench is authoritative, but exclude items already placed locally.
	var placed_ids: Dictionary = {}
	for it in equipped_items:
		placed_ids[it.get("item_id", "")] = true
	bench_items.clear()
	for it in server_bench:
		if not placed_ids.has(it.get("item_id", "")):
			bench_items.append(it)

# Packages current session state into the Grid JSON shape docs/api_contract.md
# expects for validate_grid / start_match. Pure data-shaping, no game logic.
func to_grid_payload(columns: int, rows: int) -> Dictionary:
	return {
		"player_id": player_id,
		"current_round": current_round,
		"life_points": life_points,
		"triumph_count": triumph_count,
		"gold_balance": gold,
		"grid_dimensions": {"columns": columns, "rows": rows},
		"equipped_items": equipped_items,
		"bench_reserve": bench_items,
	}
