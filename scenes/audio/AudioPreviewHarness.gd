extends Node

# Offline verification harness for C9 audio import (docs/low-level-design/c9-audio-asset-integration.md).
# Exercises threaded SFX load + pending-play flush, BGM cross-fade, and fatal LPF sweep.
#
# godot --headless --path . scenes/audio/AudioPreviewHarness.tscn

const SFX_METHODS: Array[String] = [
	"play_shop_reroll",
	"play_synergy_link",
	"play_grid_snap",
	"play_item_drag",
	"play_melee_strike",
	"play_ranged_strike",
	"play_arcane_strike",
	"play_crit_hit",
	"play_shield_absorb",
	"play_hp_loss",
	"play_fatal_hp_loss",
	"play_triple_merge",
	"play_win_round",
	"play_triumph_milestone",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var bus_idx := AudioServer.get_bus_index("BGM")
	var effects_before := AudioServer.get_bus_effect_count(bus_idx)
	print("auto-verify: bgm_effects_before=", effects_before)

	# First pass: prime threaded loads (may queue pending plays).
	for method_name in SFX_METHODS:
		_call_sfx(method_name)
	for _i in 60:
		await get_tree().process_frame

	# Second pass: cached streams should play immediately.
	for method_name in SFX_METHODS:
		_call_sfx(method_name)

	AudioManager.play_prep_bgm()
	for _i in 30:
		await get_tree().process_frame
	AudioManager.play_combat_bgm()
	for _i in 30:
		await get_tree().process_frame
	AudioManager.play_prep_bgm()
	for _i in 30:
		await get_tree().process_frame

	await AudioManager.play_fatal_hp_loss()
	for _i in 120:
		await get_tree().process_frame
	var effects_after := AudioServer.get_bus_effect_count(bus_idx)
	print("auto-verify: bgm_effects_after=", effects_after)
	print("auto-verify: lpf_cleared=", effects_after == effects_before)
	print("auto-verify: sfx_cache_size=", AudioManager._sfx_cache.size())
	get_tree().quit(0 if effects_after == effects_before else 1)

func _call_sfx(method_name: String) -> void:
	match method_name:
		"play_synergy_link":
			AudioManager.play_synergy_link(1.1)
		"play_melee_strike", "play_ranged_strike", "play_arcane_strike", "play_crit_hit", "play_shield_absorb":
			AudioManager.call(method_name, Vector2(540, 960))
		_:
			AudioManager.call(method_name)
