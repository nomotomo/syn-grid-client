class_name ApiClient
extends Node

# Configure via ProjectSettings or override in .env equivalent.
# In production this points to the grpc-gateway sidecar URL.
@export var base_url: String = "http://localhost:8080"

# Emitted signals - one pair per RPC (completed + failed).
signal authenticate_completed(data: Dictionary)
signal authenticate_failed(code: int, reason: String)

signal roll_shop_completed(data: Dictionary)
signal roll_shop_failed(code: int, reason: String)

signal purchase_item_completed(data: Dictionary)
signal purchase_item_failed(code: int, reason: String)

signal sell_item_completed(data: Dictionary)
signal sell_item_failed(code: int, reason: String)

signal validate_grid_completed(data: Dictionary)
signal validate_grid_failed(code: int, reason: String)

signal start_match_completed(data: Dictionary)
signal start_match_failed(code: int, reason: String)

signal award_round_gold_completed(data: Dictionary)
signal award_round_gold_failed(code: int, reason: String)

signal finalize_round_completed(data: Dictionary)
signal finalize_round_failed(code: int, reason: String)

signal get_leaderboard_completed(data: Dictionary)
signal get_leaderboard_failed(code: int, reason: String)

signal get_active_season_completed(data: Dictionary)
signal get_active_season_failed(code: int, reason: String)

# -- Public API --
# Callers invoke these methods. They never await return values.
# Connect to the corresponding signals to handle responses.

func authenticate(device_id: String) -> void:
	_post("/v1/authenticate", {"device_id": device_id}, false,
		authenticate_completed, authenticate_failed)

func roll_shop(round: int) -> void:
	_post("/v1/roll_shop", {"round": round}, true,
		roll_shop_completed, roll_shop_failed)

func purchase_item(template_name: String, round: int) -> void:
	_post("/v1/purchase_item", {"template_name": template_name, "round": round}, true,
		purchase_item_completed, purchase_item_failed)

func sell_item(item_id: String) -> void:
	_post("/v1/sell_item", {"item_id": item_id}, true,
		sell_item_completed, sell_item_failed)

func validate_grid(grid: Dictionary) -> void:
	_post("/v1/validate_grid", {"grid": grid}, true,
		validate_grid_completed, validate_grid_failed)

func start_match(grid: Dictionary) -> void:
	_post("/v1/start_match", {"grid": grid}, true,
		start_match_completed, start_match_failed)

func award_round_gold(round: int, won: bool) -> void:
	_post("/v1/award_round_gold", {"round": round, "won": won}, true,
		award_round_gold_completed, award_round_gold_failed)

func finalize_round(attacker_id: String, defender_id: String, winner_id: String, round: int) -> void:
	_post("/v1/finalize_round", {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"winner_id": winner_id,
		"round": round
	}, true, finalize_round_completed, finalize_round_failed)

func get_leaderboard(top_n: int = 20) -> void:
	_post("/v1/get_leaderboard", {"top_n": top_n}, true,
		get_leaderboard_completed, get_leaderboard_failed)

func get_active_season() -> void:
	_post("/v1/get_active_season", {}, true,
		get_active_season_completed, get_active_season_failed)

# -- Internal --

func _post(path: String, body: Dictionary, auth: bool,
		on_success: Signal, on_failure: Signal) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(result, code, _headers, response_body):
			_handle_response(result, code, response_body, on_success, on_failure)
			req.queue_free()
	)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth:
		headers.append("Authorization: Bearer " + GameState.token)
	var json_body := JSON.stringify(body)
	var err := req.request(base_url + path, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		on_failure.emit(err, "request setup failed")
		req.queue_free()

func _handle_response(result: int, code: int, body: PackedByteArray,
		on_success: Signal, on_failure: Signal) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		on_failure.emit(result, "network error")
		return
	var text := body.get_string_from_utf8()
	var data = JSON.parse_string(text)
	if data == null:
		on_failure.emit(code, "invalid JSON response")
		return
	# HTTP 2xx = success
	if code >= 200 and code < 300:
		on_success.emit(data)
	else:
		var reason: String = _extract_reason(data)
		on_failure.emit(code, reason)

func _extract_reason(data: Dictionary) -> String:
	# Try gRPC-gateway ErrorInfo reason field first.
	for detail in data.get("details", []):
		if detail.has("reason"):
			return detail["reason"]
	return data.get("message", "unknown error")
