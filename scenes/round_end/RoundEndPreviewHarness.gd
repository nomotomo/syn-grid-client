extends Control

# Dev-only: instances RoundEndScene with injected last_round_result fixtures so
# the win/loss/eliminated/victory ceremonies can be screenshot-checked offline.
# Not one of the production screens.
#
# Modes (both save a PNG mid-ceremony then quit):
#   SYNGRID_SCREENSHOT=/path/out.png
#       SYNGRID_RESULT=win|loss|dead|victory   offline fixture selector
#   SYNGRID_SCREENSHOT=/path/out.png SYNGRID_LIVE=1
#       full loop through combat finalize into round-end (needs server #34+#35)

var _scene: RoundEndScene

# Full ceremony: orbs finish ~2.2s wall; one shared frame budget for both verify paths.
const CEREMONY_SETTLE_FRAMES: int = 150

func _ready() -> void:
	var screenshot_path := OS.get_environment("SYNGRID_SCREENSHOT")
	if screenshot_path != "" and OS.get_environment("SYNGRID_LIVE") == "1":
		_run_live_verify(screenshot_path)
		return
	_seed_offline_fixture(OS.get_environment("SYNGRID_RESULT"))
	_instance_scene()
	if screenshot_path != "":
		_run_offline_verify(screenshot_path)

func _seed_offline_fixture(mode: String) -> void:
	GameState.player_id = "preview-player"
	GameState.gold = 18
	GameState.gold_awarded_round = 0
	match mode:
		"loss":
			GameState.life_points = 3
			GameState.triumph_count = 2
			GameState.current_round = 3
			GameState.last_fight_won = false
			GameState.last_round_result = {
				"won": false,
				"round_played": 2,
				"next_round": 3,
				"my_state": {
					"player_id": "preview-player",
					"life_points": 3,
					"triumph_count": 2,
					"eliminated": false,
				},
				"gold_rewarded": 0,
			}
		"dead":
			GameState.life_points = 0
			GameState.triumph_count = 2
			GameState.current_round = 4
			GameState.last_fight_won = false
			GameState.last_round_result = {
				"won": false,
				"round_played": 3,
				"next_round": 4,
				"my_state": {
					"player_id": "preview-player",
					"life_points": 0,
					"triumph_count": 2,
					"eliminated": true,
				},
				"gold_rewarded": 0,
			}
		"victory":
			GameState.life_points = 3
			GameState.triumph_count = 10
			GameState.current_round = 11
			GameState.last_fight_won = true
			GameState.last_round_result = {
				"won": true,
				"round_played": 10,
				"next_round": 11,
				"my_state": {
					"player_id": "preview-player",
					"life_points": 3,
					"triumph_count": 10,
					"eliminated": false,
				},
				"gold_rewarded": 0,
			}
		_: # win with milestone (default)
			GameState.life_points = 5
			GameState.triumph_count = 4
			GameState.current_round = 5
			GameState.last_fight_won = true
			GameState.last_round_result = {
				"won": true,
				"round_played": 4,
				"next_round": 5,
				"my_state": {
					"player_id": "preview-player",
					"life_points": 5,
					"triumph_count": 4,
					"eliminated": false,
				},
				"gold_rewarded": 5,
			}

func _instance_scene() -> void:
	var packed: PackedScene = preload("res://scenes/round_end/RoundEndScene.tscn")
	_scene = packed.instantiate()
	add_child(_scene)
	if OS.get_environment("SYNGRID_LIVE") != "1":
		call_deferred("_mock_offline_award")

func _mock_offline_award() -> void:
	if _scene == null:
		return
	var mode := OS.get_environment("SYNGRID_RESULT")
	if mode in ["dead", "victory"]:
		return
	if ApiClient.award_round_gold_failed.is_connected(_scene._on_award_round_gold_failed):
		ApiClient.award_round_gold_failed.disconnect(_scene._on_award_round_gold_failed)
	var grant := 12 if bool(GameState.last_round_result.get("won", true)) else 10
	_scene._on_award_round_gold_completed({
		"gold_awarded": grant,
		"new_balance": GameState.gold + grant,
	})

func _run_offline_verify(screenshot_path: String) -> void:
	await _await_ceremony_settle()
	var mode := OS.get_environment("SYNGRID_RESULT")
	if mode == "":
		mode = "win"
	print("auto-verify: mode=%s banner=%s" % [mode, _scene.get_node("%Banner").text])
	print("auto-verify: status=%s continue=%s new_run=%s" % [
		_scene.get_node("%StatusLabel").text,
		_scene.get_node("%ContinueButton").visible,
		_scene.get_node("%NewRunButton").visible])
	_save_and_quit(screenshot_path)

func _run_live_verify(screenshot_path: String) -> void:
	var before_round := GameState.current_round
	GameState.current_round = 1
	var state := {"authed": false, "match": {}, "finalized": false}
	ApiClient.authenticate_completed.connect(func(data: Dictionary) -> void:
		GameState.hydrate_from_auth(data)
		state["authed"] = true, CONNECT_ONE_SHOT)
	ApiClient.authenticate(GameState.get_or_create_device_id())
	for _i in 120:
		if state["authed"]:
			break
		await get_tree().process_frame
	if not state["authed"]:
		printerr("live-verify: authenticate did not complete")
		get_tree().quit(1)
		return

	var bought := {"done": false, "bench": []}
	ApiClient.roll_shop_completed.connect(func(data: Dictionary) -> void:
		var slots: Array = data.get("slots", [])
		var cheapest: Dictionary = {}
		for slot: Dictionary in slots:
			if cheapest.is_empty() or int(slot.get("buy_price", 99)) < int(cheapest.get("buy_price", 99)):
				cheapest = slot
		ApiClient.purchase_item(String(cheapest.get("template_name", "")), 1), CONNECT_ONE_SHOT)
	ApiClient.purchase_item_completed.connect(func(data: Dictionary) -> void:
		bought["bench"] = data.get("updated_grid", {}).get("bench_reserve", [])
		bought["done"] = true, CONNECT_ONE_SHOT)
	ApiClient.roll_shop(1)
	for _i in 180:
		if bought["done"]:
			break
		await get_tree().process_frame

	GameState.equipped_items = []
	var bench: Array = bought["bench"]
	if not bench.is_empty():
		var item: Dictionary = bench[0]
		item["placement_coords"] = {"x": 1, "y": 1}
		GameState.equipped_items.append(item)

	ApiClient.start_match_completed.connect(func(data: Dictionary) -> void:
		state["match"] = data, CONNECT_ONE_SHOT)
	ApiClient.start_match(GameState.to_grid_payload())
	for _i in 240:
		if not (state["match"] as Dictionary).is_empty():
			break
		await get_tree().process_frame
	var match_data: Dictionary = state["match"]
	GameState.last_combat_log = match_data.get("combat_log", {})
	var log: Dictionary = GameState.last_combat_log
	var won := String(log.get("winner_id", "")) == GameState.player_id
	var round_played := GameState.current_round

	ApiClient.finalize_round_completed.connect(func(data: Dictionary) -> void:
		GameState.apply_round_result(data, won, round_played)
		state["finalized"] = true, CONNECT_ONE_SHOT)
	ApiClient.finalize_round(
		String(log.get("attacker_id", "")),
		String(log.get("defender_id", "")),
		String(log.get("winner_id", "")),
		round_played)
	for _i in 180:
		if state["finalized"]:
			break
		await get_tree().process_frame
	if not state["finalized"]:
		printerr("live-verify: finalize_round did not complete (server #35 may be unmerged)")
		get_tree().quit(1)
		return

	print("live-verify: round before=%d after=%d" % [before_round, GameState.current_round])
	_instance_scene()
	await _await_ceremony_settle()
	print("live-verify: banner=%s status=%s" % [
		_scene.get_node("%Banner").text,
		_scene.get_node("%StatusLabel").text])
	_save_and_quit(screenshot_path)

func _await_ceremony_settle() -> void:
	for _i in CEREMONY_SETTLE_FRAMES:
		await get_tree().process_frame

func _save_and_quit(screenshot_path: String) -> void:
	var tex := get_viewport().get_texture()
	if tex != null:
		var image := tex.get_image()
		if image != null:
			image.save_png(screenshot_path)
			print("auto-verify: screenshot saved to ", screenshot_path)
		else:
			print("auto-verify: no image buffer (headless) - skipping screenshot")
	else:
		print("auto-verify: no viewport texture (headless) - skipping screenshot")
	get_tree().quit()
