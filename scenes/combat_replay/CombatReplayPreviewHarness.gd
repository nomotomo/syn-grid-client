extends Control

# Dev-only: instances CombatReplayScene with a combat log so playback juice
# (lunges, shake, floats, hit-stop) can be checked with F6. Not a production
# screen.
#
# Modes (both save a PNG mid-replay then quit):
#   SYNGRID_SCREENSHOT=/path/out.png                  - offline: fabricated
#       log with crits and shield absorbs, no Go server.
#   SYNGRID_SCREENSHOT=/path/out.png SYNGRID_LIVE=1   - live: authenticates,
#       buys + places a real item, runs a real match against a bot ghost,
#       and replays the server's actual combat log.

var _replay: CombatReplayScene

func _ready() -> void:
	if OS.get_environment("SYNGRID_SCREENSHOT") != "" and OS.get_environment("SYNGRID_LIVE") == "1":
		_run_live_verify(OS.get_environment("SYNGRID_SCREENSHOT"))
		return
	_seed_offline_state()
	_instance_replay()
	if OS.get_environment("SYNGRID_SCREENSHOT") != "":
		_run_offline_verify(OS.get_environment("SYNGRID_SCREENSHOT"))

func _seed_offline_state() -> void:
	GameState.player_id = "preview-player"
	GameState.equipped_items = [
		{"item_id": "me-sword", "name": "Shortsword", "item_type": "WEAPON",
			"weapon_category": "MELEE", "level": 1,
			"placement_coords": {"x": 1, "y": 1},
			"base_attributes": {"base_dmg": 12.0}},
		{"item_id": "me-bow", "name": "Longbow", "item_type": "WEAPON",
			"weapon_category": "RANGED", "level": 2,
			"placement_coords": {"x": 2, "y": 1},
			"base_attributes": {"base_dmg": 16.0}},
		{"item_id": "me-armor", "name": "Iron Buckler", "item_type": "ARMOR",
			"weapon_category": "", "level": 1,
			"placement_coords": {"x": 1, "y": 2},
			"base_attributes": {"armor_rating": 30.0}},
	]
	GameState.opponent_grid = {
		"player_id": "bot-swordsman",
		"grid_dimensions": {"columns": 4, "rows": 4},
		"equipped_items": [
			{"item_id": "opp-sword", "name": "Iron Sword", "item_type": "WEAPON",
				"weapon_category": "MELEE", "level": 1,
				"placement_coords": {"x": 2, "y": 2},
				"base_attributes": {"base_dmg": 14.0}},
			{"item_id": "opp-armor", "name": "Leather Armor", "item_type": "ARMOR",
				"weapon_category": "", "level": 1,
				"placement_coords": {"x": 1, "y": 1},
				"base_attributes": {"armor_rating": 25.0}},
		],
	}
	GameState.last_combat_log = _fabricate_log()

func _fabricate_log() -> Dictionary:
	var events: Array = []
	var opp_hp := 1000.0
	var my_hp := 1000.0
	var opp_shield := 25.0
	for i in 16:
		if i % 3 == 2:
			# Opponent strikes back at our armor item.
			my_hp -= 11.0
			events.append({"tick": (i + 1) * 5, "firing_item_id": "opp-sword",
				"target_player_id": "preview-player", "target_item_id": "me-armor",
				"crit": false, "actual_damage": 11.0, "shield_absorbed": 0.0,
				"hp_loss": 11.0, "target_hp_after": my_hp, "target_shield_after": 0.0})
		else:
			var firing := "me-sword" if i % 2 == 0 else "me-bow"
			var crit := i == 6 or i == 12
			var dmg := 36.0 if crit else 15.0
			var synergy := 8.0 if firing == "me-sword" and i == 0 else 0.0
			var absorbed := 0.0
			if opp_shield > 0.0:
				absorbed = minf(opp_shield, dmg)
				opp_shield -= absorbed
			var loss := dmg - absorbed
			opp_hp -= loss
			events.append({"tick": (i + 1) * 5, "firing_item_id": firing,
				"target_player_id": "bot-swordsman", "target_item_id": "opp-sword",
				"crit": crit, "actual_damage": dmg, "synergy_bonus": synergy,
				"shield_absorbed": absorbed,
				"hp_loss": loss, "target_hp_after": opp_hp,
				"target_shield_after": opp_shield})
	# Last player strike must actually end the match so offline harness exercises
	# shatter + killing-blow juice (simulated opp_hp was not reaching zero).
	for j in range(events.size() - 1, -1, -1):
		var e: Dictionary = events[j]
		if String(e.get("target_player_id", "")) != "bot-swordsman":
			continue
		var pre_hit_hp := float(e.get("target_hp_after", 0.0)) + float(e.get("hp_loss", 0.0))
		e["hp_loss"] = pre_hit_hp
		e["actual_damage"] = pre_hit_hp + float(e.get("shield_absorbed", 0.0))
		e["target_hp_after"] = 0.0
		opp_hp = 0.0
		break
	return {
		"attacker_id": "preview-player",
		"defender_id": "bot-swordsman",
		"winner_id": "preview-player",
		"total_ticks": 90,
		"events": events,
		"attacker_hp_final": my_hp,
		"defender_hp_final": opp_hp,
	}

func _instance_replay() -> void:
	var scene: PackedScene = preload("res://scenes/combat_replay/CombatReplayScene.tscn")
	_replay = scene.instantiate()
	add_child(_replay)

func _run_offline_verify(screenshot_path: String) -> void:
	# Intro delay + ~9 events in: floats, lunges, and bar drain are on screen.
	for _i in 100:
		await get_tree().process_frame
	print("auto-verify: tick=%s" % _replay.get_node("%TickLabel").text)
	_save_and_quit(screenshot_path)

func _run_live_verify(screenshot_path: String) -> void:
	GameState.current_round = 1
	var state := {"authed": false, "match": {}}
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

	# Buy the cheapest slot and place it so the grid has at least one item.
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
	if bench.is_empty():
		print("live-verify: no purchasable item; fighting with an empty grid")
	else:
		var item: Dictionary = bench[0]
		item["placement_coords"] = {"x": 1, "y": 1}
		GameState.equipped_items.append(item)
	GameState.bench_items = []

	ApiClient.start_match_completed.connect(func(data: Dictionary) -> void:
		state["match"] = data, CONNECT_ONE_SHOT)
	ApiClient.start_match(GameState.to_grid_payload())
	for _i in 240:
		if not (state["match"] as Dictionary).is_empty():
			break
		await get_tree().process_frame
	var match_data: Dictionary = state["match"]
	if String(match_data.get("status", "")) != "MATCH_STATUS_PLAYED":
		printerr("live-verify: match not played: %s" % str(match_data))
		get_tree().quit(1)
		return

	GameState.last_combat_log = match_data.get("combat_log", {})
	GameState.opponent_grid = match_data.get("opponent_grid", {})
	print("live-verify: opponent=%s events=%d winner=%s" % [
		GameState.opponent_grid.get("player_id", "?"),
		(GameState.last_combat_log.get("events", []) as Array).size(),
		GameState.last_combat_log.get("winner_id", "?")])

	_instance_replay()
	for _i in 110:
		await get_tree().process_frame
	print("live-verify: tick=%s" % _replay.get_node("%TickLabel").text)
	_save_and_quit(screenshot_path)

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
