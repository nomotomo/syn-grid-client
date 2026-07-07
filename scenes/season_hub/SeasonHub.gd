extends Control
class_name SeasonHubScene

# Neon Grimoire Season Hub scaffold. Renders the current-season summary
# (name + countdown + player triumph + rank), and reserves layout for a
# rewards ladder that Phase C9+ will populate. Non-interactive for now
# beyond the BACK button - safe to ship as a "COMING SOON" preview.
#
# Contract: reads GameState.season, GameState.triumph_count. Never mutates state; the real Season Hub
# gameplay will land with the server's season endpoints in a later phase.

@onready var _back_btn: Button = %BackButton
@onready var _season_name: Label = %SeasonNameLabel
@onready var _season_timer: Label = %SeasonTimerLabel
@onready var _triumph_value: Label = %TriumphValueLabel
@onready var _rewards_note: Label = %RewardsNoteLabel

var _tick_timer: Timer = null

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_back_btn.pressed.connect(_on_back_pressed)
	_refresh()
	# Countdown ticker at 1 Hz. Cheap; the Season Hub is a passive screen.
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_refresh)
	add_child(_tick_timer)

func _refresh() -> void:
	if GameState.season.is_empty():
		_season_name.text = "NO ACTIVE SEASON"
		_season_timer.text = ""
	else:
		_season_name.text = String(GameState.season.get("name", "")).to_upper()
		_season_timer.text = _format_countdown()
	_triumph_value.text = str(GameState.triumph_count)
	_rewards_note.text = "REWARDS LADDER - COMING SOON"

func _format_countdown() -> String:
	var end_ts: int = int(GameState.season.get("ends_at_unix", 0))
	if end_ts == 0:
		return "SEASON END - TBA"
	var now_ts := int(Time.get_unix_time_from_system())
	var remaining: int = max(0, end_ts - now_ts)
	if remaining <= 0:
		return "SEASON ENDED"
	var d: int = remaining / 86400
	var h: int = (remaining % 86400) / 3600
	var m: int = (remaining % 3600) / 60
	return "ENDS IN %dD %02dH %02dM" % [d, h, m]

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
