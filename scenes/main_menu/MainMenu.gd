class_name MainMenu
extends Control

# C3: Main Menu / Hub - bento layout, player stats card, season rank
# (juice_manual.md screens table). Boots the session: authenticate with the
# persisted device_id, hydrate GameState, then fetch profile + season.
# Section 1 governs layout (opaque panels behind live numbers; the callsign
# popover is the one permitted glassmorphic surface). Section 2 governs every
# tween. No game logic lives here - all values render straight from server
# responses.

const PREP_SCENE_PATH: String = "res://scenes/grid_prep/GridPrepScene.tscn"
const LEADERBOARD_SCENE_PATH: String = "res://scenes/leaderboard/LeaderboardScene.tscn"

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
@onready var _top_bar: HBoxContainer = %TopBar
@onready var _online_label: Label = %OnlineLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _topbar_avatar_rect: Panel = %TopAvatarRect
@onready var _topbar_avatar_initial: Label = %TopAvatarInitial
@onready var _settings_button: Button = %SettingsButton
@onready var _settings_icon: GearIcon = %SettingsIcon
@onready var _title_block: VBoxContainer = %TitleBlock
@onready var _top_badge: PanelContainer = %TopBadge
@onready var _top_badge_label: Label = %TopBadgeLabel
@onready var _wordmark_top: Label = %WordmarkTop
@onready var _wordmark_bottom: Label = %WordmarkBottom
@onready var _bracket_label: Label = %BracketLabel
@onready var _divider_line_left: ColorRect = %LineLeft
@onready var _divider_line_right: ColorRect = %LineRight
@onready var _divider_hex: NavIcon = %DividerHex
@onready var _player_card: PanelContainer = %PlayerCard
@onready var _avatar_rect: Panel = %AvatarRect
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
@onready var _aurora_overlay: ColorRect = %PlayButton.get_node("AuroraOverlay")
@onready var _play_bolt_icon: BoltIcon = %PlayBoltIcon
@onready var _play_label: Label = %PlayLabel
@onready var _quick_actions_row: HBoxContainer = %QuickActionsRow
@onready var _daily_tile: Button = %DailyTile
@onready var _daily_icon: GiftIcon = %DailyIcon
@onready var _daily_badge: Panel = %DailyBadge
@onready var _codex_tile: Button = %CodexTile
@onready var _codex_icon: BookIcon = %CodexIcon
@onready var _patch_ticker: ScrollingTicker = %PatchTicker
@onready var _leaderboard_button: Button = %LeaderboardButton
@onready var _status_label: Label = %StatusLabel
@onready var _home_tab: Button = %HomeTab
@onready var _leaderboard_tab: Button = %LeaderboardTab
@onready var _season_tab: Button = %SeasonTab
@onready var _profile_tab: Button = %ProfileTab
@onready var _popover_backdrop: ColorRect = %PopoverBackdrop
@onready var _name_popover: PanelContainer = %NameEditPopover
@onready var _name_edit: LineEdit = %NameEdit
@onready var _confirm_name_button: Button = %ConfirmNameButton
@onready var _cancel_name_button: Button = %CancelNameButton
@onready var _season_timer: Timer = %SeasonTimer
@onready var _clock_timer: Timer = %ClockTimer

var _authenticated: bool = false
var _popover_tween: Tween = null

func _ready() -> void:
        theme = ThemeBuilder.get_theme()
        _background.color = SynGridPalette.PANEL_BG
        # Hero wordmark: NEON teal, GRIMOIRE white (design LandingScreen).
        _wordmark_top.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
        _wordmark_bottom.add_theme_color_override("font_color", Color.WHITE)
        _season_rank.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)

        # Issue #79: top status bar + logo badge/bracket + patch ticker + Play
        # button icon. Purely additive presentation - no new data sources
        # beyond what GameState/ApiClient already provide (identity, which
        # _refresh_identity() now also mirrors onto the smaller top-bar avatar).
        _online_label.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
        _settings_icon.set_glyph_color(SynGridPalette.TEXT_DIM)
        _settings_button.add_theme_stylebox_override("normal",
                ThemeBuilder.build_button_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED))
        _settings_button.add_theme_stylebox_override("hover",
                ThemeBuilder.build_button_style(SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_HOVER, 0, true))
        _settings_button.pressed.connect(_on_settings_pressed)

        _top_badge.add_theme_stylebox_override("panel",
                ThemeBuilder.build_capsule_style(SynGridPalette.ACCENT_PURPLE, SynGridPalette.PANEL_BG_ELEVATED, false))
        _top_badge_label.add_theme_color_override("font_color", SynGridPalette.ACCENT_PURPLE)
        _bracket_label.add_theme_color_override("font_color", SynGridPalette.ACCENT_PURPLE)
        _divider_line_left.color = SynGridPalette.BORDER_DIM
        _divider_line_right.color = SynGridPalette.BORDER_DIM
        _divider_hex.set_glyph_color(SynGridPalette.ACCENT_TEAL)
        _daily_icon.set_glyph_color(SynGridPalette.ACCENT_AMBER)
        _codex_icon.set_glyph_color(SynGridPalette.TEXT_DIM)

        # Static flavor lines only - no reference to GameState.season here, since
        # season data hasn't arrived yet at _ready() time (ApiClient.get_active_
        # season() fires later, from _on_authenticate_completed) and this ticker
        # is never re-populated afterward. A dynamic season-name line would show
        # a stale fallback on every load; keep this chrome-only like Figma's own
        # ticker (generic announcements, not live player-specific state).
        _patch_ticker.add_theme_stylebox_override("panel",
                ThemeBuilder.build_panel_style(SynGridPalette.BORDER_DIM, Color(SynGridPalette.ACCENT_TEAL, 0.08)))
        _patch_ticker.set_items([
                "CHECK DAILY REWARDS",
                "NEW SYNERGIES DISCOVERED EACH RUN",
                "SEASON REWARDS COMING SOON",
        ])

        _play_bolt_icon.set_glyph_color(SynGridPalette.ACCENT_TEAL)

        _update_clock()
        # Glass is permitted here: the callsign popover is an impermanent popover
        # with no live numeric values on it (contract section 1).
        _name_popover.add_theme_stylebox_override("panel", ThemeBuilder.build_panel_style(
                SynGridPalette.BORDER_ACTIVE, Color(0.12, 0.12, 0.15, 0.88)))

        # Issue #68: PlayButton needs its own full-pill style - the global Button
        # theme's 12px radius (ThemeBuilder.build_button_style) barely rounds a
        # 150px-tall button. build_cta_style over-specifies the radius so Godot
        # clamps it to a true pill regardless of height.
        _play_button.add_theme_stylebox_override("normal",
                ThemeBuilder.build_cta_style(SynGridPalette.BORDER_DIM, SynGridPalette.PANEL_BG_ELEVATED))
        _play_button.add_theme_stylebox_override("hover",
                ThemeBuilder.build_cta_style(SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_HOVER))
        _play_button.add_theme_stylebox_override("pressed",
                ThemeBuilder.build_cta_style(SynGridPalette.ACCENT_PURPLE, SynGridPalette.PANEL_BG_ELEVATED))
        _play_button.add_theme_stylebox_override("focus",
                ThemeBuilder.build_cta_style(SynGridPalette.BORDER_ACTIVE, SynGridPalette.PANEL_BG_HOVER))
        _play_button.add_theme_stylebox_override("disabled",
                ThemeBuilder.build_cta_style(Color(0.30, 0.32, 0.35, 0.4), SynGridPalette.PANEL_BG, false))
        # The aurora shader needs the overlay's actual pixel size to trace a
        # rounded-rect rim matching the pill fill above - a canvas_item
        # shader on a texture-less ColorRect has no built-in way to read its
        # own rect size. Without this, the rim ignores corner_radius_px and
        # renders a hard square corner over the now-rounded button.
        _aurora_overlay.resized.connect(_update_aurora_rect_size)
        _update_aurora_rect_size()

        # Daily unclaimed-reward dot: issue #40 (daily streak/challenge state)
        # hasn't landed yet, so this stays permanently hidden until that issue
        # wires a real "has unclaimed reward" signal/field to flip it on.
        var badge_style := StyleBoxFlat.new()
        badge_style.bg_color = SynGridPalette.DANGER
        badge_style.set_corner_radius_all(999)
        _daily_badge.add_theme_stylebox_override("panel", badge_style)
        _daily_badge.visible = false

        ApiClient.authenticate_completed.connect(_on_authenticate_completed)
        ApiClient.authenticate_failed.connect(_on_authenticate_failed)
        ApiClient.get_active_grid_completed.connect(_on_get_active_grid_completed)
        ApiClient.get_active_grid_failed.connect(_on_get_active_grid_failed)
        ApiClient.get_profile_completed.connect(_on_get_profile_completed)
        ApiClient.get_profile_failed.connect(_on_get_profile_failed)
        ApiClient.get_active_season_completed.connect(_on_get_active_season_completed)
        ApiClient.get_active_season_failed.connect(_on_get_active_season_failed)
        ApiClient.update_profile_completed.connect(_on_update_profile_completed)
        ApiClient.update_profile_failed.connect(_on_update_profile_failed)

        _play_button.pressed.connect(_on_play_pressed)
        _daily_tile.pressed.connect(_on_daily_tile_pressed)
        _codex_tile.pressed.connect(_on_codex_tile_pressed)
        _leaderboard_button.pressed.connect(_on_leaderboard_pressed)
        _home_tab.pressed.connect(_on_home_tab_pressed)
        _leaderboard_tab.pressed.connect(_on_leaderboard_pressed)
        _season_tab.pressed.connect(_on_season_tab_pressed)
        _profile_tab.pressed.connect(_on_profile_tab_pressed)
        _style_active_tab(_home_tab)
        _edit_name_button.pressed.connect(_on_edit_name_pressed)
        _confirm_name_button.pressed.connect(_on_confirm_name_pressed)
        _cancel_name_button.pressed.connect(func() -> void: _close_name_popover())
        _name_edit.text_submitted.connect(func(_text: String) -> void: _on_confirm_name_pressed())
        _popover_backdrop.gui_input.connect(_on_backdrop_input)
        _season_timer.timeout.connect(_update_season_countdown)
        # Deliberately NOT piggybacked on _season_timer: that timer only starts
        # once season data loads and self-stops on "SEASON ENDED"/fetch failure
        # (see _update_season_countdown), which would silently kill clock
        # updates too in exactly those cases. The clock needs its own
        # lifecycle, independent of season-fetch success or failure.
        _clock_timer.timeout.connect(_update_clock)
        _clock_timer.start()

        _refresh_identity()
        _stats_hud.refresh()
        await _play_entry_cascade()
        AudioManager.play_prep_bgm()
        _begin_session()

# -- Session boot / hydration --

func _begin_session() -> void:
        _set_status("LINKING TO GRID...")
        _play_button.disabled = true
        _play_label.text = "LINKING..."
        ApiClient.authenticate(GameState.get_or_create_device_id())

func _on_authenticate_completed(data: Dictionary) -> void:
        GameState.hydrate_from_auth(data)
        _authenticated = true
        _stats_hud.refresh()
        _refresh_identity()
        _set_status("SYNCING RUN STATE...")
        _play_button.disabled = true
        _play_label.text = "SYNCING..."
        ApiClient.get_active_grid()
        ApiClient.get_profile()
        ApiClient.get_active_season()

func _on_get_active_grid_completed(data: Dictionary) -> void:
        GameState.hydrate_from_grid(data.get("grid", {}))
        _stats_hud.refresh()
        _refresh_identity()
        if GameState.current_round > 1:
                _set_status("RUN RESUMED - ROUND %d" % GameState.current_round)
        else:
                _set_status("LINK ESTABLISHED")
        _enable_play()

func _on_get_active_grid_failed(code: int, _reason: String) -> void:
        if code == 404:
                _set_status("LINK ESTABLISHED")
        else:
                _set_status("STATE SYNC OFFLINE")
        _enable_play()

func _enable_play() -> void:
        _play_button.disabled = false
        _play_label.text = "ENTER THE GRID"
        _leaderboard_button.disabled = false
        _play_panel_pop(_play_button, 0)
        _play_panel_pop(_leaderboard_button, 1)

func _on_authenticate_failed(code: int, reason: String) -> void:
        _authenticated = false
        _set_status("LINK FAILED - %s (%s)" % [reason, str(code)])
        _play_button.disabled = false
        _play_label.text = "RETRY LINK"

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
        var initial := shown_name.substr(0, 1).to_upper()
        var tints: Array[Color] = [SynGridPalette.ACCENT_TEAL, SynGridPalette.ACCENT_PURPLE, SynGridPalette.GOLD]
        var tint: Color = tints[abs(hash(GameState.avatar_id + shown_name)) % tints.size()]
        _avatar_initial.text = initial
        _set_avatar_tint(_avatar_rect, tint)
        _avatar_initial.add_theme_color_override("font_color", tint)
        # Issue #79: same initial/tint mirrored onto the smaller top-bar avatar -
        # PlayerCard stays the source of truth, this is presentation-only.
        _topbar_avatar_initial.text = initial
        _set_avatar_tint(_topbar_avatar_rect, tint)
        _topbar_avatar_initial.add_theme_color_override("font_color", tint)

# Circular avatar fill (issue #79 fix: these were plain ColorRects, which have
# no corner radius and rendered as squares - Figma's avatars are circles).
# A fresh StyleBoxFlat per call is fine here; this only runs on identity
# refresh, not per-frame.
func _set_avatar_tint(panel: Panel, tint: Color) -> void:
        var style := StyleBoxFlat.new()
        style.bg_color = Color(tint.r, tint.g, tint.b, 0.22)
        style.set_corner_radius_all(999)
        panel.add_theme_stylebox_override("panel", style)

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

# Issue #79 top-bar clock - plain wall-clock time-of-day display, not a
# countdown, so juice_manual.md's "no live decision clock" rule (which
# targets urgency-implying countdowns, not informational chrome like a phone
# status bar's clock) doesn't apply here.
func _update_clock() -> void:
        var t := Time.get_time_dict_from_system()
        _clock_label.text = "%02d:%02d" % [t.hour, t.minute]

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
        get_tree().change_scene_to_file(PREP_SCENE_PATH)

func _on_leaderboard_pressed() -> void:
        if not _authenticated:
                _pulse(_leaderboard_button)
                _begin_session()
                return
        await _pulse(_leaderboard_button).finished
        get_tree().change_scene_to_file(LEADERBOARD_SCENE_PATH)

# Entry points only (issue #68 scope item 4) - Daily ties to #40 (retention
# pack) and Codex ties to #34 (Profile hub), neither of which is built yet.
func _on_daily_tile_pressed() -> void:
        _pulse(_daily_tile)
        _set_status("DAILY REWARDS COMING SOON")

func _on_codex_tile_pressed() -> void:
        _pulse(_codex_tile)
        _set_status("CODEX COMING SOON")

# Entry point only, same as Daily/Codex above - no settings screen exists yet
# and building one is out of issue #79's scope (top-bar layout only).
func _on_settings_pressed() -> void:
        _pulse(_settings_button)
        _set_status("SETTINGS COMING SOON")

# -- Juice helpers (contract section 2) --

# Bento reveal: every panel pops in with the shop-card cascade rhythm.
func _play_entry_cascade() -> void:
        # _player_card and _stats_hud are hidden on this screen (issue #79) -
        # left out of the cascade since animating a scale tween on an invisible
        # node is pointless, even though harmless.
        var panels: Array[Control] = [_top_bar, _title_block,
                _season_card, _play_button, _quick_actions_row, _patch_ticker, _leaderboard_button]
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

func _update_aurora_rect_size() -> void:
        var mat: ShaderMaterial = _aurora_overlay.material
        if mat != null:
                mat.set_shader_parameter("rect_size", _aurora_overlay.size)

func _pulse(control: Control) -> Tween:
        control.pivot_offset = control.size / 2.0
        var tw := create_tween()
        tw.tween_property(control, "scale", Vector2(press_squish_scale, press_squish_scale),
                press_squish_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
        tw.tween_property(control, "scale", Vector2.ONE, press_release_duration) \
                .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
        return tw

# -- Bottom nav tab handlers (Neon Grimoire mobile-first navigation) --

func _on_home_tab_pressed() -> void:
        # Already home - just play a tap pulse for feedback and re-highlight.
        _pulse(_home_tab)
        _style_active_tab(_home_tab)

func _on_season_tab_pressed() -> void:
        _pulse(_season_tab)
        get_tree().change_scene_to_file("res://scenes/season_hub/SeasonHub.tscn")

func _on_profile_tab_pressed() -> void:
        _pulse(_profile_tab)
        _open_name_popover()

# Highlight the active tab with a teal border + tinted text; dim the rest.
# Called on scene enter and whenever the player taps back to Home. Tab labels
# render via a TabContent/Label child (not the Button's own text - that's
# left empty so the icon glyph above it has room), so both the label and the
# NavIcon glyph get tinted here alongside the button's own colors.
func _style_active_tab(active: Button) -> void:
        for tab: Button in [_home_tab, _leaderboard_tab, _season_tab, _profile_tab]:
                var is_active := tab == active
                var border := SynGridPalette.ACCENT_TEAL if is_active else SynGridPalette.BORDER_DIM
                var bg := SynGridPalette.PANEL_BG_HOVER if is_active else SynGridPalette.PANEL_BG_ELEVATED
                tab.add_theme_stylebox_override("normal",
                        ThemeBuilder.build_button_style(border, bg, 0, is_active))
                var text_color := SynGridPalette.ACCENT_TEAL if is_active else SynGridPalette.TEXT_DIM
                tab.add_theme_color_override("font_color", text_color)
                tab.add_theme_color_override("font_hover_color", text_color)
                var tab_content: VBoxContainer = tab.get_node("TabContent")
                var label: Label = tab_content.get_node("Label")
                label.add_theme_color_override("font_color", text_color)
                var icon: NavIcon = tab_content.get_child(0)
                icon.set_glyph_color(text_color)

func _set_status(text: String) -> void:
        _status_label.text = text

func _kill_popover_tween() -> void:
        if _popover_tween != null and _popover_tween.is_valid():
                _popover_tween.kill()
