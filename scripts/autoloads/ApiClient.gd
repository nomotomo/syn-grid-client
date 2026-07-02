extends Node

# Configure via ProjectSettings or override in .env equivalent.
# In production this points to the grpc-gateway bridge URL.
@export var base_url: String = "http://localhost:8080"

const REQUEST_TIMEOUT_SEC := 10.0

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

signal update_profile_completed(data: Dictionary)
signal update_profile_failed(code: int, reason: String)

signal get_profile_completed(data: Dictionary)
signal get_profile_failed(code: int, reason: String)

signal get_match_history_completed(data: Dictionary)
signal get_match_history_failed(code: int, reason: String)

signal get_active_grid_completed(data: Dictionary)
signal get_active_grid_failed(code: int, reason: String)

signal reset_run_completed(data: Dictionary)
signal reset_run_failed(code: int, reason: String)

# -- Public API --
# Callers invoke these methods. They never await return values.
# Connect to the corresponding signals to handle responses.
# Paths and verbs mirror proto/sync_grid.proto google.api.http bindings exactly.

func authenticate(device_id: String) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/auth", {"device_id": device_id}, {}, false,
		authenticate_completed, authenticate_failed)

func roll_shop(round_num: int) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/shop", {}, {"round": round_num}, true,
		roll_shop_completed, roll_shop_failed)

func purchase_item(template_name: String, round_num: int) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/shop/purchase",
		{"template_name": template_name, "round": round_num}, {}, true,
		purchase_item_completed, purchase_item_failed)

func sell_item(item_id: String) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/shop/sell", {"item_id": item_id}, {}, true,
		sell_item_completed, sell_item_failed)

func validate_grid(grid: Dictionary) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/grid/validate", {"grid": grid}, {}, true,
		validate_grid_completed, validate_grid_failed)

func start_match(grid: Dictionary) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/match/start", {"grid": grid}, {}, true,
		start_match_completed, start_match_failed)

func award_round_gold(round_num: int, won: bool) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/economy/gold/award",
		{"round": round_num, "won": won}, {}, true,
		award_round_gold_completed, award_round_gold_failed)

func finalize_round(attacker_id: String, defender_id: String, winner_id: String, round_num: int) -> void:
	_request(HTTPClient.METHOD_POST, "/v1/round/finalize", {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"winner_id": winner_id,
		"round": round_num
	}, {}, true, finalize_round_completed, finalize_round_failed)

func get_leaderboard(top_n: int = 20) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/leaderboard", {}, {"top_n": top_n}, true,
		get_leaderboard_completed, get_leaderboard_failed)

func get_active_season() -> void:
	_request(HTTPClient.METHOD_GET, "/v1/season", {}, {}, true,
		get_active_season_completed, get_active_season_failed)

# Empty string leaves that field unchanged on the server.
func update_profile(display_name: String = "", avatar_id: String = "") -> void:
	_request(HTTPClient.METHOD_PUT, "/v1/me/profile",
		{"display_name": display_name, "avatar_id": avatar_id}, {}, true,
		update_profile_completed, update_profile_failed)

# Empty player_id returns the calling player's own profile.
func get_profile(player_id: String = "") -> void:
	var path := "/v1/profile"
	if player_id != "":
		path += "/" + player_id.uri_encode()
	_request(HTTPClient.METHOD_GET, path, {}, {}, true,
		get_profile_completed, get_profile_failed)

func get_match_history(top_n: int = 20) -> void:
	_request(HTTPClient.METHOD_GET, "/v1/me/history", {}, {"top_n": top_n}, true,
		get_match_history_completed, get_match_history_failed)

func get_active_grid() -> void:
	_request(HTTPClient.METHOD_GET, "/v1/me/grid", {}, {}, true,
		get_active_grid_completed, get_active_grid_failed)

func reset_run() -> void:
	_request(HTTPClient.METHOD_POST, "/v1/run/reset", {}, {}, true,
		reset_run_completed, reset_run_failed)

# -- Internal --

func _request(method: int, path: String, body: Dictionary, query: Dictionary, auth: bool,
		on_success: Signal, on_failure: Signal) -> void:
	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT_SEC
	add_child(req)
	req.request_completed.connect(
		func(result, code, _headers, response_body):
			_handle_response(result, code, response_body, on_success, on_failure)
			req.queue_free()
	)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth:
		headers.append("Authorization: Bearer " + GameState.token)
	var url := base_url + path + _encode_query(query)
	var json_body := ""
	if method != HTTPClient.METHOD_GET:
		json_body = JSON.stringify(body)
	var err := req.request(url, headers, method, json_body)
	if err != OK:
		on_failure.emit(err, "request setup failed")
		req.queue_free()

func _encode_query(query: Dictionary) -> String:
	if query.is_empty():
		return ""
	var parts: PackedStringArray = []
	for key in query:
		parts.append(str(key).uri_encode() + "=" + str(query[key]).uri_encode())
	return "?" + "&".join(parts)

func _handle_response(result: int, code: int, body: PackedByteArray,
		on_success: Signal, on_failure: Signal) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		on_failure.emit(result, "network error")
		return
	var text := body.get_string_from_utf8()
	var data = JSON.parse_string(text)
	if data == null or not (data is Dictionary):
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
		if detail is Dictionary and detail.has("reason"):
			return detail["reason"]
	return data.get("message", "unknown error")
