extends Control

# Dev-only: offline leaderboard + season fixtures for screenshot verification.
# SYNGRID_SCREENSHOT=/path/out.png godot --path . --resolution 540x960 \
#   scenes/leaderboard/LeaderboardPreviewHarness.tscn

const LEADERBOARD_SCENE: PackedScene = preload("res://scenes/leaderboard/LeaderboardScene.tscn")

var _scene: Control

func _ready() -> void:
	GameState.player_id = "preview-player-self"
	GameState.display_name = "Preview Operative"
	_scene = LEADERBOARD_SCENE.instantiate()
	add_child(_scene)
	call_deferred("_inject_fixtures")
	var screenshot_path := OS.get_environment("SYNGRID_SCREENSHOT")
	if screenshot_path != "":
		_run_verify(screenshot_path)
	else:
		# Headless CI: auto-quit after fixtures render.
		_run_verify("")

func _inject_fixtures() -> void:
	if ApiClient.get_leaderboard_completed.is_connected(_scene._on_get_leaderboard_completed):
		ApiClient.get_leaderboard_completed.disconnect(_scene._on_get_leaderboard_completed)
	if ApiClient.get_active_season_completed.is_connected(_scene._on_get_active_season_completed):
		ApiClient.get_active_season_completed.disconnect(_scene._on_get_active_season_completed)
	if ApiClient.get_leaderboard_failed.is_connected(_scene._on_get_leaderboard_failed):
		ApiClient.get_leaderboard_failed.disconnect(_scene._on_get_leaderboard_failed)
	if ApiClient.get_active_season_failed.is_connected(_scene._on_get_active_season_failed):
		ApiClient.get_active_season_failed.disconnect(_scene._on_get_active_season_failed)

	var ends_at := int(Time.get_unix_time_from_system()) + 3 * 86400 + 5 * 3600 + 42 * 60
	_scene._on_get_active_season_completed({
		"season_id": 1,
		"name": "Season 1",
		"ends_at_unix": str(ends_at),
		"caller_rank": "5",
		"reward_brackets": [
			{"min_rank": "1", "max_rank": "3", "reward_gold": "500"},
			{"min_rank": "4", "max_rank": "10", "reward_gold": "200"},
			{"min_rank": "11", "max_rank": "25", "reward_gold": "50"},
		],
	})
	_scene._on_get_leaderboard_completed({
		"entries": [
			{"rank": "1", "player_id": "aaa-top-player-001", "triumph_count": "10", "display_name": "GridLord"},
			{"rank": "2", "player_id": "bbb-runner-up-002", "triumph_count": "9", "display_name": "NeonFox"},
			{"rank": "3", "player_id": "ccc-third-003", "triumph_count": "8", "display_name": "Shard"},
			{"rank": "4", "player_id": "ddd-fourth-004", "triumph_count": "7", "display_name": ""},
			{"rank": "5", "player_id": "preview-player-self", "triumph_count": "6", "display_name": "Preview Operative"},
			{"rank": "6", "player_id": "eee-sixth-006", "triumph_count": "5", "display_name": "Ghost"},
		],
	})

func _run_verify(screenshot_path: String) -> void:
	for _i in 90:
		await get_tree().process_frame
	print("auto-verify: list_rows=%d season=%s" % [
		_scene.get_node("%ListBox").get_child_count(),
		_scene.get_node("%SeasonName").text])
	if screenshot_path != "":
		_save_and_quit(screenshot_path)
	else:
		get_tree().quit()

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
