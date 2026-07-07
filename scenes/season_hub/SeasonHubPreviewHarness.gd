extends Control

# Dev-only: renders SeasonHub for scripted screenshot proof.
# Follows the same SYNGRID_SCREENSHOT pattern as the other harnesses.

func _ready() -> void:
	var hub_scene: PackedScene = preload("res://scenes/season_hub/SeasonHub.tscn")
	var hub: Control = hub_scene.instantiate()
	add_child(hub)

	var screenshot_path := OS.get_environment("SYNGRID_SCREENSHOT")
	if screenshot_path == "":
		return
	# Inject fake season/triumph state so the scaffold hydrates.
	GameState.season = {
		"season_id": 12,
		"name": "Season XII - Ember",
		"ends_at_unix": int(Time.get_unix_time_from_system()) + 3 * 86400 + 5 * 3600,
		"caller_rank": 42,
	}
	GameState.triumph_count = 128
	hub._refresh()
	for _i in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(screenshot_path)
	print("auto-verify: screenshot saved to ", screenshot_path)
	await AudioManager.release_bgm_before_quit()
	get_tree().quit()
