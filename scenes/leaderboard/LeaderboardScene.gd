class_name LeaderboardScene
extends Control

# C8: Global leaderboard + active season display. Read-only - all values from
# ApiClient signals. Juice contract section 1: staggered row entrance, teal
# self-highlight pulse, elastic rank-badge pop. No glass behind live numbers.

const MAIN_MENU_PATH: String = "res://scenes/main_menu/MainMenu.tscn"
const LEADERBOARD_TOP_N: int = 50
const PLAYER_ID_DISPLAY_LEN: int = 16
const SKELETON_ROW_COUNT: int = 8

const BADGE_TEXTURES: Dictionary = {
	1: "res://assets/sprites/ui/badge_gold.png",
	2: "res://assets/sprites/ui/badge_silver.png",
	3: "res://assets/sprites/ui/badge_bronze.png",
}

const BADGE_FALLBACK_COLORS: Dictionary = {
	1: Color(0.95, 0.78, 0.25),
	2: Color(0.75, 0.78, 0.82),
	3: Color(0.72, 0.45, 0.28),
}

@export var row_stagger: float = 0.03
@export var row_slide_distance: float = 48.0
@export var row_fade_duration: float = 0.22
@export var self_pulse_peak: float = 1.03
@export var badge_pop_delay: float = 0.08
@export var badge_pop_duration: float = 0.14

@onready var _background: ColorRect = %Background
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _leaderboard_tab: Button = %LeaderboardTab
@onready var _season_tab: Button = %SeasonTab
@onready var _leaderboard_panel: Control = %LeaderboardPanel
@onready var _season_panel: Control = %SeasonPanel
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _list_box: VBoxContainer = %ListBox
@onready var _lb_error_label: Label = %LeaderboardError
@onready var _season_name: Label = %SeasonName
@onready var _season_countdown: Label = %SeasonCountdown
@onready var _season_rank: Label = %SeasonRank
@onready var _bracket_box: VBoxContainer = %BracketBox
@onready var _season_placeholder: Label = %SeasonPlaceholder
@onready var _countdown_timer: Timer = %CountdownTimer

var _active_tab: String = "leaderboard"
var _lb_loading: bool = true
var _season_loading: bool = true
var _season_data: Dictionary = {}
var _caller_rank: int = 0

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_background.color = SynGridPalette.PANEL_BG
	_title_label.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	_season_rank.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)

	_back_button.pressed.connect(_on_back_pressed)
	_leaderboard_tab.pressed.connect(func() -> void: _switch_tab("leaderboard"))
	_season_tab.pressed.connect(func() -> void: _switch_tab("season"))
	_lb_error_label.gui_input.connect(_on_lb_error_input)

	ApiClient.get_leaderboard_completed.connect(_on_get_leaderboard_completed)
	ApiClient.get_leaderboard_failed.connect(_on_get_leaderboard_failed)
	ApiClient.get_active_season_completed.connect(_on_get_active_season_completed)
	ApiClient.get_active_season_failed.connect(_on_get_active_season_failed)
	_countdown_timer.timeout.connect(_update_season_countdown)

	_switch_tab("leaderboard")
	_show_leaderboard_skeleton()
	_fetch_data()
	AudioManager.play_prep_bgm()

func _fetch_data() -> void:
	_lb_loading = true
	_season_loading = true
	_lb_error_label.visible = false
	ApiClient.get_leaderboard(LEADERBOARD_TOP_N)
	ApiClient.get_active_season()

func _switch_tab(tab: String) -> void:
	_active_tab = tab
	var on_lb := tab == "leaderboard"
	_leaderboard_panel.visible = on_lb
	_season_panel.visible = not on_lb
	_leaderboard_tab.disabled = on_lb
	_season_tab.disabled = not on_lb
	_title_label.text = "GLOBAL LEADERBOARD" if on_lb else "ACTIVE SEASON"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

# -- Leaderboard --

func _show_leaderboard_skeleton() -> void:
	_clear_list()
	for i in SKELETON_ROW_COUNT:
		var row := _make_skeleton_row()
		row.modulate.a = 0.35 + float(i % 3) * 0.1
		_list_box.add_child(row)

func _make_skeleton_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 72.0)
	var bar := ColorRect.new()
	bar.color = SynGridPalette.PANEL_BG_ELEVATED
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)
	return panel

func _on_get_leaderboard_completed(data: Dictionary) -> void:
	_lb_loading = false
	_lb_error_label.visible = false
	_render_leaderboard(data.get("entries", []))

func _on_get_leaderboard_failed(_code: int, _reason: String) -> void:
	_lb_loading = false
	_clear_list()
	_lb_error_label.visible = true
	_lb_error_label.text = "Failed to load - tap to retry"

func _on_lb_error_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_show_leaderboard_skeleton()
		_lb_loading = true
		_lb_error_label.visible = false
		ApiClient.get_leaderboard(LEADERBOARD_TOP_N)

func _render_leaderboard(entries: Array) -> void:
	_clear_list()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "NO ENTRIES YET"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", SynGridPalette.TEXT_DIM)
		_list_box.add_child(empty)
		return
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var rank := int(str(entry.get("rank", "0")))
		var player_id := String(entry.get("player_id", ""))
		var triumph := int(str(entry.get("triumph_count", "0")))
		var display_name := String(entry.get("display_name", ""))
		var is_self := player_id == GameState.player_id
		var row := _make_leaderboard_row(rank, player_id, display_name, triumph, is_self)
		row.modulate.a = 0.0
		row.position.x = row_slide_distance
		_list_box.add_child(row)
		_animate_row_in(row, i, rank, is_self)

func _make_leaderboard_row(rank: int, player_id: String, display_name: String,
		triumph: int, is_self: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	# Top-3 get a taller row so the 72px rank medallion has breathing room.
	var row_h := 88.0 if rank >= 1 and rank <= 3 else (80.0 if is_self else 68.0)
	panel.custom_minimum_size = Vector2(0.0, row_h)
	var border := SynGridPalette.ACCENT_TEAL if is_self else SynGridPalette.BORDER_DIM
	panel.add_theme_stylebox_override("panel",
		ThemeBuilder.build_panel_style(border, SynGridPalette.PANEL_BG_ELEVATED))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(row)

	var rank_box := HBoxContainer.new()
	# Wider box for the 72px medallion + the "#N" label.
	rank_box.custom_minimum_size = Vector2(152.0 if rank <= 3 else 72.0, 0.0)
	rank_box.add_theme_constant_override("separation", 10)
	row.add_child(rank_box)

	if rank >= 1 and rank <= 3:
		var badge := _make_rank_badge(rank)
		badge.scale = Vector2.ZERO
		panel.set_meta("rank_badge", badge)
		rank_box.add_child(badge)

	var rank_label := Label.new()
	rank_label.text = "#%d" % rank
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_self:
		rank_label.add_theme_font_size_override("font_size", 22)
		rank_label.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	else:
		rank_label.theme_type_variation = &"HudValueLabel"
	rank_box.add_child(rank_label)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var shown := display_name if display_name != "" else _truncate_id(player_id)
	if is_self:
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", SynGridPalette.TEXT_PRIMARY)
	else:
		name_label.theme_type_variation = &"CaptionLabel"
	name_label.text = shown
	row.add_child(name_label)

	var triumph_box := HBoxContainer.new()
	triumph_box.add_theme_constant_override("separation", 6)
	row.add_child(triumph_box)

	var triumph_label := Label.new()
	triumph_label.text = str(triumph)
	triumph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	triumph_label.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	if is_self:
		triumph_label.add_theme_font_size_override("font_size", 24)
	else:
		triumph_label.theme_type_variation = &"HudValueLabel"
	triumph_box.add_child(triumph_label)

	var gold_glyph := Label.new()
	gold_glyph.text = "T"
	gold_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_glyph.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	gold_glyph.theme_type_variation = &"BadgeLabel"
	triumph_box.add_child(gold_glyph)

	return panel

func _make_rank_badge(rank: int) -> Control:
	var holder := Control.new()
	# Neon Grimoire: top-3 medallions ship at 72px with a per-tier outer glow
	# so they register as prestigious rather than as tiny sprite squares.
	holder.custom_minimum_size = Vector2(72.0, 72.0)
	holder.pivot_offset = Vector2(36.0, 36.0)
	var glow_color: Color = BADGE_FALLBACK_COLORS.get(rank, SynGridPalette.GOLD)
	# Soft outer glow via a same-color ColorRect with additive blend, scaled up
	# behind the medal - cheap on mobile, no shader needed.
	var glow := ColorRect.new()
	glow.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.35)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -6
	glow.offset_top = -6
	glow.offset_right = 6
	glow.offset_bottom = 6
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	var path: String = BADGE_TEXTURES.get(rank, "")
	if path != "" and ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		# Do NOT self_modulate: the regenerated badges already carry their full
		# metallic palette. Tinting would flatten the medallion bevel.
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tex)
	else:
		var dot := ColorRect.new()
		dot.color = glow_color
		dot.set_anchors_preset(Control.PRESET_FULL_RECT)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(dot)
	return holder

func _animate_row_in(row: PanelContainer, index: int, rank: int, is_self: bool) -> void:
	var delay := float(index) * row_stagger
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.parallel().tween_property(row, "modulate:a", 1.0, row_fade_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(row, "position:x", 0.0, row_fade_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if is_self:
		row.pivot_offset = row.size / 2.0
		tw.tween_interval(0.05)
		tw.tween_property(row, "scale", Vector2(self_pulse_peak, self_pulse_peak), 0.12) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tw.tween_property(row, "scale", Vector2.ONE, 0.08) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	if rank >= 1 and rank <= 3 and row.has_meta("rank_badge"):
		var badge: Control = row.get_meta("rank_badge")
		if badge != null:
			var badge_tw := create_tween()
			badge_tw.tween_interval(delay + row_fade_duration + badge_pop_delay)
			badge_tw.tween_property(badge, "scale", Vector2(1.2, 1.2), badge_pop_duration) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			badge_tw.tween_property(badge, "scale", Vector2.ONE, 0.06) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

func _truncate_id(player_id: String) -> String:
	if player_id.length() <= PLAYER_ID_DISPLAY_LEN:
		return player_id
	return player_id.substr(0, PLAYER_ID_DISPLAY_LEN) + "..."

func _clear_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()

# -- Season --

func _on_get_active_season_completed(data: Dictionary) -> void:
	_season_loading = false
	_season_data = data
	_caller_rank = int(str(data.get("caller_rank", "0")))
	GameState.season = {
		"season_id": int(data.get("season_id", 0)),
		"name": String(data.get("name", "")),
		"ends_at_unix": int(str(data.get("ends_at_unix", "0"))),
		"caller_rank": _caller_rank,
	}
	_season_placeholder.visible = false
	_season_name.visible = true
	_season_countdown.visible = true
	_season_rank.visible = true
	_bracket_box.visible = true
	_season_name.text = String(data.get("name", "")).to_upper()
	_season_rank.text = ("YOUR RANK: #%d" % _caller_rank) if _caller_rank > 0 else "UNRANKED"
	_render_brackets(data.get("reward_brackets", []))
	_update_season_countdown()
	_countdown_timer.start()

func _on_get_active_season_failed(code: int, _reason: String) -> void:
	_season_loading = false
	_season_data = {}
	_caller_rank = 0
	_countdown_timer.stop()
	_season_name.visible = false
	_season_countdown.visible = false
	_season_rank.visible = false
	_bracket_box.visible = false
	_season_placeholder.visible = true
	_season_placeholder.text = "No active season" if code == 404 else "Season unavailable"

func _update_season_countdown() -> void:
	var ends_at := int(str(_season_data.get("ends_at_unix", "0")))
	var remaining := ends_at - int(Time.get_unix_time_from_system())
	if remaining <= 0:
		_season_countdown.text = "SEASON ENDED"
		_countdown_timer.stop()
		return
	var days := remaining / 86400
	var hours := (remaining % 86400) / 3600
	var minutes := (remaining % 3600) / 60
	_season_countdown.text = "%dD %dH %dM" % [days, hours, minutes]

func _render_brackets(brackets: Array) -> void:
	for child in _bracket_box.get_children():
		child.queue_free()
	if brackets.is_empty():
		var note := Label.new()
		note.text = "Reward tiers publish with the next server release."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", SynGridPalette.TEXT_DIM)
		_bracket_box.add_child(note)
		return
	for bracket: Dictionary in brackets:
		var min_rank := int(str(bracket.get("min_rank", bracket.get("MinRank", "0"))))
		var max_rank := int(str(bracket.get("max_rank", bracket.get("MaxRank", "0"))))
		var gold := int(str(bracket.get("reward_gold", bracket.get("gold", "0"))))
		var in_bracket := _caller_rank > 0 and _caller_rank >= min_rank and _caller_rank <= max_rank
		var row := _make_bracket_row(min_rank, max_rank, gold, in_bracket)
		_bracket_box.add_child(row)

func _make_bracket_row(min_rank: int, max_rank: int, gold: int, highlighted: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var border := SynGridPalette.ACCENT_TEAL if highlighted else SynGridPalette.BORDER_DIM
	panel.add_theme_stylebox_override("panel",
		ThemeBuilder.build_panel_style(border, SynGridPalette.PANEL_BG_ELEVATED))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)
	var range_label := Label.new()
	range_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_label.text = "RANK %d - %d" % [min_rank, max_rank]
	if highlighted:
		range_label.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	hbox.add_child(range_label)
	var gold_label := Label.new()
	gold_label.text = "%dG" % gold
	gold_label.add_theme_color_override("font_color", SynGridPalette.GOLD)
	hbox.add_child(gold_label)
	return panel
