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
	if "current_season_name" in GameState:
		GameState.set("current_season_name", "SEASON XII - EMBER")
	if "season_end_ts" in GameState:
		GameState.set("season_end_ts", int(Time.get_unix_time_from_system()) + 3 * 86400 + 5 * 3600)
	GameState.triumph_count = 128
	hub._refresh()
	for _i in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(screenshot_path)
	print("auto-verify: screenshot saved to ", screenshot_path)
	get_tree().quit()
