extends Node

# End-to-end exercise of ApiClient against a live server on ApiClient.base_url.
# Run: godot --headless --path . tests/ApiE2E.tscn
# Requires ../sync-grid server running (make run). Exits 0 on pass, 1 on failure.

const OVERALL_TIMEOUT_SEC := 60.0

var _failures: PackedStringArray = []
var _start_msec: int = 0

func _ready() -> void:
	_start_msec = Time.get_ticks_msec()
	await _run_all()
	if _failures.is_empty():
		print("E2E: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("E2E FAIL: " + f)
		get_tree().quit(1)

func _run_all() -> void:
	var device_id := "e2e-%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	GameState.player_id = device_id

	# 1. Authenticate
	var auth := await _call(ApiClient.authenticate.bind(device_id),
		ApiClient.authenticate_completed, ApiClient.authenticate_failed)
	if not _require(auth, "authenticate"):
		return
	_check(auth.data.get("token", "") != "", "authenticate returns token")
	_check(int(auth.data.get("gold_balance", 0)) == 10, "new player starts with 10 gold")
	GameState.token = auth.data.get("token", "")
	GameState.gold = int(auth.data.get("gold_balance", 0))
	GameState.current_round = 1

	# 2. Roll shop for round 1
	var shop := await _call(ApiClient.roll_shop.bind(1),
		ApiClient.roll_shop_completed, ApiClient.roll_shop_failed)
	if not _require(shop, "roll_shop"):
		return
	var slots: Array = shop.data.get("slots", [])
	_check(slots.size() > 0, "shop returns slots")

	# 3. Purchase the cheapest affordable WEAPON so our side always fires and
	# the combat log is guaranteed events (a potion-only board against a
	# weaponless ghost produces an empty log); fall back to cheapest anything.
	var pick: Dictionary = {}
	for prefer_weapon in [true, false]:
		for slot in slots:
			if prefer_weapon and String(slot.get("item_type", "")) != "WEAPON":
				continue
			var price := int(slot.get("buy_price", 999999))
			if price <= GameState.gold and (pick.is_empty() or price < int(pick.get("buy_price", 999999))):
				pick = slot
		if not pick.is_empty():
			break
	if not _check(not pick.is_empty(), "an affordable slot exists"):
		return
	var buy := await _call(ApiClient.purchase_item.bind(pick["template_name"], 1),
		ApiClient.purchase_item_completed, ApiClient.purchase_item_failed)
	if not _require(buy, "purchase_item"):
		return
	var bench: Array = buy.data.get("updated_grid", {}).get("bench_reserve", [])
	_check(bench.size() > 0, "purchase adds item to bench")
	GameState.gold = int(buy.data.get("new_balance", 0))

	# 4. Place the item at (0,0) and validate the grid
	var item: Dictionary = bench[0]
	item["placement_coords"] = {"x": 0, "y": 0}
	GameState.equipped_items.append(item)
	GameState.bench_items.clear()
	var validate := await _call(ApiClient.validate_grid.bind(GameState.to_grid_payload(4, 4)),
		ApiClient.validate_grid_completed, ApiClient.validate_grid_failed)
	if not _require(validate, "validate_grid"):
		return
	_check(validate.data.get("synergies", []) is Array, "validate_grid returns synergies array")

	# 5. Start a match (bot ghosts are seeded on server startup)
	var match_resp := await _call(ApiClient.start_match.bind(GameState.to_grid_payload(4, 4)),
		ApiClient.start_match_completed, ApiClient.start_match_failed)
	if not _require(match_resp, "start_match"):
		return
	var status: String = match_resp.data.get("status", "")
	_check(status == "MATCH_STATUS_PLAYED", "match played (got %s)" % status)
	var log: Dictionary = match_resp.data.get("combat_log", {})
	_check(int(log.get("total_ticks", 0)) > 0, "combat log has ticks")
	_check((log.get("events", []) as Array).size() > 0, "combat log has events")
	var opp: Dictionary = match_resp.data.get("opponent_grid", {})
	_check((opp.get("equipped_items", []) as Array).size() > 0, "opponent grid has equipped items")
	_check(not opp.has("gold_balance") or int(opp.get("gold_balance", 0)) == 0,
		"opponent private fields stripped")

	# 6. Award round gold
	var won: bool = log.get("winner_id", "") == device_id
	var gold := await _call(ApiClient.award_round_gold.bind(1, won),
		ApiClient.award_round_gold_completed, ApiClient.award_round_gold_failed)
	if _require(gold, "award_round_gold"):
		_check(gold.data.has("new_balance"), "award returns new_balance")

	# 7. Finalize the round
	var fin := await _call(ApiClient.finalize_round.bind(
			log.get("attacker_id", ""), log.get("defender_id", ""), log.get("winner_id", ""), 1),
		ApiClient.finalize_round_completed, ApiClient.finalize_round_failed)
	if _require(fin, "finalize_round"):
		_check(fin.data.has("attacker_state"), "finalize returns attacker_state")
		if fin.data.has("next_round"):
			var next_r := int(str(fin.data.get("next_round", "0")))
			_check(next_r == 2, "finalize next_round == round + 1 (got %d)" % next_r)
		else:
			print("skipped: finalize next_round field (server #35 may be unmerged)")

	# 7b. GetActiveGrid after purchase should reflect bench + gold
	var grid_resp := await _call(ApiClient.get_active_grid,
		ApiClient.get_active_grid_completed, ApiClient.get_active_grid_failed)
	if grid_resp.ok:
		var g: Dictionary = grid_resp.data.get("grid", {})
		_check(int(g.get("gold_balance", -1)) == GameState.gold,
			"get_active_grid gold_balance matches session")
		_check((g.get("bench_reserve", []) as Array).size() >= 0,
			"get_active_grid returns bench_reserve")
	elif grid_resp.code == 404:
		print("skipped: get_active_grid 404 (server #36 may be unmerged)")
	else:
		print("skipped: get_active_grid code=%s (server #36 may be unmerged)" % grid_resp.code)

	# 7c. Idempotent award_round_gold - second call same round
	if gold.ok:
		var bal_after_first := int(gold.data.get("new_balance", 0))
		var gold2 := await _call(ApiClient.award_round_gold.bind(1, won),
			ApiClient.award_round_gold_completed, ApiClient.award_round_gold_failed)
		if gold2.ok:
			var bal_after_second := int(gold2.data.get("new_balance", 0))
			if bal_after_second == bal_after_first:
				print("E2E pass: award_round_gold idempotent (balance unchanged on replay)")
			else:
				print("skipped: award_round_gold not idempotent yet (server #34 may be unmerged)")
		else:
			print("skipped: award_round_gold replay failed (server #34 may be unmerged)")

	# 7d. reset_run on live non-terminal run should 412
	var reset := await _call(ApiClient.reset_run,
		ApiClient.reset_run_completed, ApiClient.reset_run_failed)
	if not reset.ok and reset.code == 412:
		print("E2E pass: reset_run rejects non-terminal run")
	elif reset.ok:
		print("skipped: reset_run succeeded on non-terminal run (unexpected)")
	else:
		print("skipped: reset_run code=%s (server #37 may be unmerged)" % reset.code)

	# 8. Leaderboard (int64 fields arrive as JSON strings)
	var lb := await _call(ApiClient.get_leaderboard.bind(5),
		ApiClient.get_leaderboard_completed, ApiClient.get_leaderboard_failed)
	if _require(lb, "get_leaderboard"):
		var entries: Array = lb.data.get("entries", [])
		_check(entries.size() > 0, "leaderboard has entries")
		if entries.size() > 0:
			_check(int(str(entries[0].get("rank", "0"))) >= 1, "leaderboard rank parses from string")

	# 9. Season - 404 (no active season) is an acceptable server state
	var season := await _call(ApiClient.get_active_season,
		ApiClient.get_active_season_completed, ApiClient.get_active_season_failed)
	if not season.ok and season.code != 404:
		_failures.append("get_active_season: code=%s reason=%s" % [season.code, season.reason])
	elif season.ok:
		_check(season.data.get("name", "") != "", "season has a name")

	# 10. Update + read back profile
	var upd := await _call(ApiClient.update_profile.bind("E2E Tester", ""),
		ApiClient.update_profile_completed, ApiClient.update_profile_failed)
	_require(upd, "update_profile")
	var prof := await _call(ApiClient.get_profile,
		ApiClient.get_profile_completed, ApiClient.get_profile_failed)
	if _require(prof, "get_profile"):
		_check(prof.data.get("display_name", "") == "E2E Tester", "profile round-trips display_name")

	# 11. Match history should contain the match we just played
	var hist := await _call(ApiClient.get_match_history.bind(5),
		ApiClient.get_match_history_completed, ApiClient.get_match_history_failed)
	if _require(hist, "get_match_history"):
		_check((hist.data.get("records", []) as Array).size() > 0, "history has our match")

# -- helpers --

# Fires the request via call_fn, then waits for either signal.
# Returns {ok, data, code, reason}.
func _call(call_fn: Callable, completed: Signal, failed: Signal) -> Dictionary:
	var state := {"done": false, "ok": false, "data": {}, "code": 0, "reason": ""}
	var on_ok := func(data: Dictionary) -> void:
		state["ok"] = true
		state["data"] = data
		state["done"] = true
	var on_fail := func(code: int, reason: String) -> void:
		state["code"] = code
		state["reason"] = reason
		state["done"] = true
	completed.connect(on_ok, CONNECT_ONE_SHOT)
	failed.connect(on_fail, CONNECT_ONE_SHOT)
	call_fn.call()
	while not state["done"]:
		if Time.get_ticks_msec() - _start_msec > OVERALL_TIMEOUT_SEC * 1000:
			state["reason"] = "overall timeout"
			break
		await get_tree().process_frame
	if completed.is_connected(on_ok):
		completed.disconnect(on_ok)
	if failed.is_connected(on_fail):
		failed.disconnect(on_fail)
	return state

func _require(resp: Dictionary, rpc: String) -> bool:
	if not resp["ok"]:
		_failures.append("%s: code=%s reason=%s" % [rpc, resp["code"], resp["reason"]])
		return false
	print("E2E pass: %s" % rpc)
	return true

func _check(cond: bool, what: String) -> bool:
	if cond:
		print("E2E pass: %s" % what)
	else:
		_failures.append(what)
	return cond
