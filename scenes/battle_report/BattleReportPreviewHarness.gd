extends Control

# Dev-only: instances BattleReportScene with a fabricated combat_log that
# includes summary.item_stats + turning_point_tick (issue #31 / #49 schema).
# Not a production screen.
#
# Modes:
#   SYNGRID_SCREENSHOT=/path/out.png
#       SYNGRID_PAGE=0|1|2|3|4   which report page to show (default 0=VERDICT)
#   SYNGRID_SCREENSHOT=/path/out.png SYNGRID_RESULT=loss
#       loss fixture (defeat verdict + advice rules that fire)

var _report: BattleReportScene

func _ready() -> void:
	var screenshot_path := OS.get_environment("SYNGRID_SCREENSHOT")
	var result_mode := OS.get_environment("SYNGRID_RESULT")
	_seed_offline_state(result_mode)
	_instance_report()
	if screenshot_path != "":
		_run_offline_verify(screenshot_path)

func _seed_offline_state(result_mode: String) -> void:
	GameState.player_id = "preview-player"
	GameState.current_round = 3
	GameState.last_fight_won = result_mode != "loss"
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
		{"item_id": "me-dead", "name": "Dusty Relic", "item_type": "WEAPON",
			"weapon_category": "ARCANE", "level": 1,
			"placement_coords": {"x": 3, "y": 3},
			"base_attributes": {"base_dmg": 8.0}},
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
	GameState.last_combat_log = _fabricate_log(result_mode == "loss")
	GameState.last_round_result = {
		"won": result_mode != "loss",
		"round_played": 2,
		"next_round": 3,
		"my_state": {
			"player_id": "preview-player",
			"life_points": 4 if result_mode != "loss" else 3,
			"triumph_count": 2,
			"eliminated": false,
		},
		"gold_rewarded": 0,
	}

func _fabricate_log(as_loss: bool) -> Dictionary:
	var events: Array = []
	var opp_hp := 1000.0
	var my_hp := 1000.0
	var opp_shield := 25.0
	for i in 16:
		if i % 3 == 2:
			my_hp -= 11.0
			events.append({
				"tick": (i + 1) * 5,
				"firing_item_id": "opp-sword",
				"target_player_id": "preview-player",
				"target_item_id": "me-armor",
				"source_cell": {"x": 2, "y": 2},
				"target_cell": {"x": 1, "y": 2},
				"crit": false,
				"actual_damage": 11.0,
				"synergy_bonus": 0.0,
				"shield_absorbed": 0.0,
				"hp_loss": 11.0,
				"target_hp_after": my_hp,
				"target_shield_after": 0.0,
				"killing_blow": false,
			})
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
			events.append({
				"tick": (i + 1) * 5,
				"firing_item_id": firing,
				"target_player_id": "bot-swordsman",
				"target_item_id": "opp-sword",
				"source_cell": {"x": 1 if firing == "me-sword" else 2, "y": 1},
				"target_cell": {"x": 2, "y": 2},
				"crit": crit,
				"actual_damage": dmg,
				"synergy_bonus": synergy,
				"shield_absorbed": absorbed,
				"hp_loss": loss,
				"target_hp_after": opp_hp,
				"target_shield_after": opp_shield,
				"killing_blow": false,
			})

	# Killing blow against own relic early for advice rule 2.
	events.insert(3, {
		"tick": 12,
		"firing_item_id": "opp-sword",
		"target_player_id": "preview-player",
		"target_item_id": "me-dead",
		"source_cell": {"x": 2, "y": 2},
		"target_cell": {"x": 3, "y": 3},
		"crit": false,
		"actual_damage": 40.0,
		"synergy_bonus": 0.0,
		"shield_absorbed": 0.0,
		"hp_loss": 0.0,
		"target_hp_after": my_hp,
		"target_shield_after": 0.0,
		"killing_blow": true,
	})

	var winner := "bot-swordsman" if as_loss else "preview-player"
	if as_loss:
		# Drain player and leave opponent healthy for a clean defeat.
		my_hp = 0.0
		opp_hp = 620.0
		events.append({
			"tick": 95,
			"firing_item_id": "opp-sword",
			"target_player_id": "preview-player",
			"target_item_id": "me-armor",
			"source_cell": {"x": 2, "y": 2},
			"target_cell": {"x": 1, "y": 2},
			"crit": true,
			"actual_damage": 200.0,
			"synergy_bonus": 0.0,
			"shield_absorbed": 0.0,
			"hp_loss": 200.0,
			"target_hp_after": 0.0,
			"target_shield_after": 0.0,
			"killing_blow": false,
		})
		# Retroactively clamp player HP after earlier hits for series continuity.
		var running := 1000.0
		for ev: Dictionary in events:
			if String(ev.get("target_player_id", "")) != "preview-player":
				continue
			if bool(ev.get("killing_blow", false)) and float(ev.get("hp_loss", 0.0)) == 0.0:
				continue
			running = maxf(0.0, running - float(ev.get("hp_loss", 0.0)))
			ev["target_hp_after"] = running
		my_hp = 0.0
		opp_hp = 620.0
	else:
		for j in range(events.size() - 1, -1, -1):
			var e: Dictionary = events[j]
			if String(e.get("target_player_id", "")) != "bot-swordsman":
				continue
			if bool(e.get("killing_blow", false)):
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
		"winner_id": winner,
		"total_ticks": 100,
		"events": events,
		"attacker_hp_final": my_hp,
		"defender_hp_final": opp_hp,
		"summary": {
			"item_stats": [
				{"item_id": "me-sword", "damage_dealt": 180.0, "damage_taken": 0.0,
					"shots_fired": 8, "crits": 2, "kills": 0},
				{"item_id": "me-bow", "damage_dealt": 140.0, "damage_taken": 0.0,
					"shots_fired": 7, "crits": 1, "kills": 1},
				{"item_id": "me-armor", "damage_dealt": 0.0, "damage_taken": 55.0,
					"shots_fired": 0, "crits": 0, "kills": 0},
				{"item_id": "me-dead", "damage_dealt": 0.0, "damage_taken": 40.0,
					"shots_fired": 0, "crits": 0, "kills": 0},
				{"item_id": "opp-sword", "damage_dealt": 95.0 if not as_loss else 280.0,
					"damage_taken": 220.0, "shots_fired": 6, "crits": 1, "kills": 1},
				{"item_id": "opp-armor", "damage_dealt": 0.0, "damage_taken": 100.0,
					"shots_fired": 0, "crits": 0, "kills": 0},
			],
			"turning_point_tick": 45,
		},
	}

func _instance_report() -> void:
	var scene: PackedScene = preload("res://scenes/battle_report/BattleReportScene.tscn")
	_report = scene.instantiate()
	add_child(_report)

func _run_offline_verify(screenshot_path: String) -> void:
	var page := int(OS.get_environment("SYNGRID_PAGE")) if OS.get_environment("SYNGRID_PAGE") != "" else 0
	# Settle layout + banner pop (BattleReportScene awaits one frame in _ready).
	await get_tree().create_timer(0.4).timeout
	if page > 0 and _report != null:
		_report._show_page(page, false)
		await get_tree().create_timer(0.2).timeout
	print("auto-verify: battle-report page=%d" % page)
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
	AudioManager.release_bgm_streams()
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		get_tree().quit())
