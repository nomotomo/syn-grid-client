class_name MainMenu
extends Control

# C3: Main Menu / Hub - bento layout, player stats card, season rank
# (juice_manual.md screens table). Boots the session: authenticate with the
# persisted device_id, hydrate GameState, then fetch profile + season.
# Section 1 governs layout (opaque panels behind live numbers; the callsign
# popover is the one permitted glassmorphic surface). Section 2 governs every
# tween. No game logic lives here - all values render straight from server
# responses.

const SHOP_SCENE_PATH: String = "res://scenes/shop/ShopScene.tscn"

# Entry cascade (contract section 2 card-pop rhythm, applied to bento panels).
@export var entry_pop_duration: float = 0.12
@export var entry_settle_duration: float = 0.06
@export var entry_stagger_interval: float = 0.04

# Button press feedback - squish then overshoot release, never linear.
@export var press_squish_scale: float = 0.94
@export var press_squish_duration: float = 0.05
@export var press_release_duration: float = 0.10

# Callsign popover pop-in/out.
@export var popover_pop_duration: float = 0.16
@export var popover_close_duration: float = 0.12

@onready var _background: ColorRect = %Background
@onready var _title_block: VBoxContainer = %TitleBlock
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _player_card: PanelContainer = %PlayerCard
@onready var _avatar_rect: ColorRect = %AvatarRect
@onready var _avatar_initial: Label = %AvatarInitial
@onready var _name_label: Label = %NameLabel
@onready var _player_id_label: Label = %PlayerIdLabel
@onready var _edit_name_button: Button = %EditNameButton
@onready var _stats_hud: StatsHud = %StatsHud
@onready var _season_card: PanelContainer = %SeasonCard
@onready var _season_name: Label = %SeasonName
@onready var _season_rank: Label = %SeasonRank
@onready var _season_countdown: Label = %SeasonCountdown
@onready var _play_button: Button = %PlayButton
@onready var _leaderboard_button: Button = %LeaderboardButton
@onready var _status_label: Label = %StatusLabel
@onready var _popover_backdrop: ColorRect = %PopoverBackdrop
@onready var _name_popover: PanelContainer = %NameEditPopover
@onready var _name_edit: LineEdit = %NameEdit
@onready var _confirm_name_button: Button = %ConfirmNameButton
@onready var _cancel_name_button: Button = %CancelNameButton
@onready var _season_timer: Timer = %SeasonTimer

var _authenticated: bool = false
var _popover_tween: Tween = null

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_background.color = SynGridPalette.PANEL_BG
	_subtitle_label.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	_season_rank.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	# Glass is permitted here: the callsign popover is an impermanent popover
	# with no live numeric values on it (contract section 1).
	_name_popover.add_theme_stylebox_override("panel", ThemeBuilder.build_panel_style(
		SynGridPalette.BORDER_ACTIVE, Color(0.12, 0.12, 0.15, 0.88)))

	ApiClient.authenticate_completed.connect(_on_authenticate_completed)
	ApiClient.authenticate_failed.connect(_on_authenticate_failed)
	ApiClient.get_profile_completed.connect(_on_get_profile_completed)
	ApiClient.get_profile_failed.connect(_on_get_profile_failed)
	ApiClient.get_active_season_completed.connect(_on_get_active_season_completed)
	ApiClient.get_active_season_failed.connect(_on_get_active_season_failed)
	ApiClient.update_profile_completed.connect(_on_update_profile_completed)
	ApiClient.update_profile_failed.connect(_on_update_profile_failed)

	_play_button.pressed.connect(_on_play_pressed)
	_edit_name_button.pressed.connect(_on_edit_name_pressed)
	_confirm_name_button.pressed.connect(_on_confirm_name_pressed)
	_cancel_name_button.pressed.connect(func() -> void: _close_name_popover())
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_confirm_name_pressed())
	_popover_backdrop.gui_input.connect(_on_backdrop_input)
	_season_timer.timeout.connect(_update_season_countdown)

	_refresh_identity()
	_stats_hud.refresh()
	await _play_entry_cascade()
	AudioManager.play_prep_bgm()
	_begin_session()

# -- Session boot / hydration --

func _begin_session() -> void:
	_set_status("LINKING TO GRID...")
	_play_button.disabled = true
	_play_button.text = "LINKING..."
	ApiClient.authenticate(GameState.get_or_create_device_id())

func _on_authenticate_completed(data: Dictionary) -> void:
	GameState.hydrate_from_auth(data)
	_authenticated = true
	_stats_hud.refresh()
	_refresh_identity()
	_set_status("LINK ESTABLISHED")
	_play_button.disabled = false
	_play_button.text = "ENTER THE GRID"
	_play_panel_pop(_play_button, 0)
	ApiClient.get_profile()
	ApiClient.get_active_season()

func _on_authenticate_failed(code: int, reason: String) -> void:
	_authenticated = false
	_set_status("LINK FAILED - %s (%s)" % [reason, str(code)])
	_play_button.disabled = false
	_play_button.text = "RETRY LINK"

# -- Profile --

func _on_get_profile_completed(data: Dictionary) -> void:
	GameState.display_name = String(data.get("display_name", ""))
	GameState.avatar_id = String(data.get("avatar_id", ""))
	_refresh_identity()

func _on_get_profile_failed(_code: int, _reason: String) -> void:
	_refresh_identity()

func _refresh_identity() -> void:
	var shown_name := GameState.display_name
	if shown_name == "":
		shown_name = "OPERATIVE-%s" % GameState.player_id.substr(0, 8).to_upper()
	if _name_label.text != shown_name:
		_name_label.text = shown_name
		_play_panel_pop(_name_label, 0)
	_player_id_label.text = GameState.player_id
	_avatar_initial.text = shown_name.substr(0, 1).to_upper()
	var tints: Array[Color] = [SynGridPalette.ACCENT_TEAL, SynGridPalette.ACCENT_PURPLE, SynGridPalette.GOLD]
	var tint: Color = tints[abs(hash(GameState.avatar_id + shown_name)) % tints.size()]
	_avatar_rect.color = Color(tint.r, tint.g, tint.b, 0.22)
	_avatar_initial.add_theme_color_override("font_color", tint)

# -- Season --

func _on_get_active_season_completed(data: Dictionary) -> void:
	GameState.season = {
		"season_id": int(data.get("season_id", 0)),
		"name": String(data.get("name", "")),
		"ends_at_unix": int(str(data.get("ends_at_unix", "0"))),
		"caller_rank": int(str(data.get("caller_rank", "0"))),
	}
	_season_name.text = String(GameState.season["name"]).to_upper()
	var rank: int = GameState.season["caller_rank"]
	_season_rank.text = ("RANK #%d" % rank) if rank > 0 else "UNRANKED"
	_play_panel_pop(_season_name, 0)
	_update_season_countdown()
	_season_timer.start()

func _on_get_active_season_failed(code: int, _reason: String) -> void:
	GameState.season = {}
	_season_name.text = "NO ACTIVE SEASON" if code == 404 else "SEASON LINK DOWN"
	_season_rank.text = "-"
	_season_countdown.text = ""
	_season_timer.stop()

func _update_season_countdown() -> void:
	var ends_at: int = int(GameState.season.get("ends_at_unix", 0))
	var remaining := ends_at - int(Time.get_unix_time_from_system())
	if remaining <= 0:
		_season_countdown.text = "SEASON ENDED"
		_season_timer.stop()
		return
	var days := remaining / 86400
	var hours := (remaining % 86400) / 3600
	var minutes := (remaining % 3600) / 60
	var seconds := remaining % 60
	if days > 0:
		_season_countdown.text = "ENDS IN %dD %02dH %02dM" % [days, hours, minutes]
	else:
		_season_countdown.text = "ENDS IN %02d:%02d:%02d" % [hours, minutes, seconds]

# -- Callsign popover (update_profile round-trip) --

func _on_edit_name_pressed() -> void:
	_pulse(_edit_name_button)
	_open_name_popover()

func _open_name_popover() -> void:
	_popover_backdrop.visible = true
	_name_popover.visible = true
	_name_edit.text = GameState.display_name
	_name_popover.pivot_offset = _name_popover.size / 2.0
	_kill_popover_tween()
	_name_popover.scale = Vector2.ZERO
	_popover_tween = create_tween()
	_popover_tween.tween_property(_name_popover, "scale", Vector2(1.05, 1.05), popover_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_popover_tween.tween_property(_name_popover, "scale", Vector2.ONE, entry_settle_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	_name_edit.grab_focus()
	_name_edit.caret_column = _name_edit.text.length()

func _close_name_popover() -> void:
	_kill_popover_tween()
	_popover_tween = create_tween()
	_popover_tween.tween_property(_name_popover, "scale", Vector2.ZERO, popover_close_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_popover_tween.tween_callback(func() -> void:
		_name_popover.visible = false
		_popover_backdrop.visible = false)

func _on_confirm_name_pressed() -> void:
	var new_name := _name_edit.text.strip_edges()
	if new_name == "" or new_name == GameState.display_name:
		_close_name_popover()
		return
	_confirm_name_button.disabled = true
	ApiClient.update_profile(new_name, "")

func _on_update_profile_completed(_data: Dictionary) -> void:
	_confirm_name_button.disabled = false
	_close_name_popover()
	# Re-read from the server rather than trusting local text - the server may
	# have rejected/normalised the name (1-24 chars, restricted charset).
	ApiClient.get_profile()

func _on_update_profile_failed(_code: int, reason: String) -> void:
	_confirm_name_button.disabled = false
	_set_status("CALLSIGN REJECTED - %s" % reason)

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_name_popover()

# -- Navigation --

func _on_play_pressed() -> void:
	if not _authenticated:
		_pulse(_play_button)
		_begin_session()
		return
	await _pulse(_play_button).finished
	get_tree().change_scene_to_file(SHOP_SCENE_PATH)

# -- Juice helpers (contract section 2) --

# Bento reveal: every panel pops in with the shop-card cascade rhythm.
func _play_entry_cascade() -> void:
	var panels: Array[Control] = [_title_block, _player_card, _stats_hud,
		_season_card, _play_button, _leaderboard_button]
	for panel in panels:
		panel.scale = Vector2.ZERO
	# One frame so container layout assigns sizes; pivots must be centred or
	# the pops look lopsided.
	await get_tree().process_frame
	for i in panels.size():
		_play_panel_pop(panels[i], i)
	await get_tree().create_timer(
		panels.size() * entry_stagger_interval + entry_pop_duration + entry_settle_duration).timeout

func _play_panel_pop(panel: Control, stagger_idx: int) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_interval(stagger_idx * entry_stagger_interval)
	tw.tween_property(panel, "scale", Vector2(1.1, 1.1), entry_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(panel, "scale", Vector2.ONE, entry_settle_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

func _pulse(control: Control) -> Tween:
	control.pivot_offset = control.size / 2.0
	var tw := create_tween()
	tw.tween_property(control, "scale", Vector2(press_squish_scale, press_squish_scale),
		press_squish_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(control, "scale", Vector2.ONE, press_release_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tw

func _set_status(text: String) -> void:
	_status_label.text = text

func _kill_popover_tween() -> void:
	if _popover_tween != null and _popover_tween.is_valid():
		_popover_tween.kill()
