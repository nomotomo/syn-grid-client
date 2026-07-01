class_name GameState
extends Node

# Session identity
var token: String = ""
var player_id: String = ""
var token_expires_at: int = 0

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

# Last combat result (used by CombatReplayScene and RoundEndScene)
var last_combat_log: Dictionary = {}
var last_fight_won: bool = false

func is_authenticated() -> bool:
	return token != "" and Time.get_unix_time_from_system() < token_expires_at - 300

func reset_for_new_round() -> void:
	# Return all equipped items to bench at round start.
	for item in equipped_items:
		item["placement_coords"] = null
		bench_items.append(item)
	equipped_items.clear()
	last_combat_log = {}

func sync_bench_from_server(server_bench: Array) -> void:
	# Server bench is authoritative, but exclude items already placed locally.
	var placed_ids: Dictionary = {}
	for it in equipped_items:
		placed_ids[it.get("item_id", "")] = true
	bench_items.clear()
	for it in server_bench:
		if not placed_ids.has(it.get("item_id", "")):
			bench_items.append(it)
