extends Control

# Dev-only: instances MainMenu for F6 preview and scripted screenshot checks
# (same pattern as GridPrepPreviewHarness). Not one of the six production screens.
#
# Modes (both save a PNG then quit):
#   SYNGRID_SCREENSHOT=/path/out.png                  - offline: injects fake
#       auth/profile/season responses so the full hydrated layout renders
#       with no Go server.
#   SYNGRID_SCREENSHOT=/path/out.png SYNGRID_LIVE=1   - live: real server on
#       ApiClient.base_url hydrates the menu end-to-end.

var _menu: MainMenu

func _ready() -> void:
	var menu_scene: PackedScene = preload("res://scenes/main_menu/MainMenu.tscn")
	_menu = menu_scene.instantiate()
	add_child(_menu)

	var screenshot_path := OS.get_environment("SYNGRID_SCREENSHOT")
	if screenshot_path == "":
		return
	if OS.get_environment("SYNGRID_LIVE") == "1":
		_run_live_verify(screenshot_path)
	else:
		_run_offline_verify(screenshot_path)

func _run_offline_verify(screenshot_path: String) -> void:
	# The menu's _ready fired a real authenticate at a server that isn't
	# there - unhook the failure handlers so the injected happy-path state
	# isn't overwritten when those requests come back dead.
	ApiClient.authenticate_failed.disconnect(_menu._on_authenticate_failed)
	ApiClient.get_profile_failed.disconnect(_menu._on_get_profile_failed)
	ApiClient.get_active_season_failed.disconnect(_menu._on_get_active_season_failed)
	# Let the entry cascade settle.
	for _i in 50:
		await get_tree().process_frame
	_menu._on_authenticate_completed({
		"token": "preview-token",
		"expires_at_unix": "9999999999",
		"gold_balance": 14,
	})
	_menu._on_get_profile_completed({
		"player_id": GameState.player_id,
		"display_name": "NightOwl",
		"avatar_id": "avatar_02",
	})
	_menu._on_get_active_season_completed({
		"season_id": 1,
		"name": "Season of Embers",
		"ends_at_unix": str(int(Time.get_unix_time_from_system()) + 3 * 86400 + 4 * 3600),
		"caller_rank": "5",
	})
	for _i in 40:
		await get_tree().process_frame
	_save_and_quit(screenshot_path)

func _run_live_verify(screenshot_path: String) -> void:
	# Three real round-trips (auth, then profile + season) at ~2s worth of frames.
	for _i in 120:
		await get_tree().process_frame
	print("live-verify: player_id=", GameState.player_id)
	print("live-verify: token_len=", GameState.token.length(),
		" gold=", GameState.gold,
		" display_name=", GameState.display_name)
	print("live-verify: status=", _menu.get_node("%StatusLabel").text)
	_save_and_quit(screenshot_path)

func _save_and_quit(screenshot_path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(screenshot_path)
	print("auto-verify: screenshot saved to ", screenshot_path)
	get_tree().quit()
