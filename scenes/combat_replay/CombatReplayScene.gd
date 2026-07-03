class_name CombatReplayScene
extends Control

# C6: Combat replay - juice contract section 4 end to end. The server's
# CombatLog is the single source of truth: every HP/shield value rendered
# comes from a TickEvent's after-fields, never client math. CombatLogPlayer
# dequeues one event per 0.10s (hit-stop on crits); this scene interprets
# each event as lunge + shake + damage float + SFX.
#
# Layout note: the contract's lunge is written as "+40px on the X-axis" for
# side-by-side arenas. This portrait client stacks the arenas vertically, so
# the lunge keeps the exact magnitude, frame timing, and eases but travels
# along Y toward the enemy - the same "velocity clash" read.

const PREP_SCENE_PATH: String = "res://scenes/grid_prep/GridPrepScene.tscn"
const ROUND_END_SCENE_PATH: String = "res://scenes/round_end/RoundEndScene.tscn"
const ITEM_CARD_SCENE: PackedScene = preload("res://scenes/ui/ItemCard.tscn")
const COMBAT_MAX_HP: float = 1000.0   # game-rules.md: combat HP baseline

@export var mini_cell_card_size: Vector2 = Vector2(104, 104)
@export var grid_columns: int = 4
@export var grid_rows: int = 4
@export var intro_delay: float = 0.6
@export var lunge_distance: float = 40.0
@export var lunge_out_duration: float = 0.05    # ~3 frames at 60fps
@export var lunge_back_duration: float = 0.0833 # ~5 frames at 60fps
@export var float_rise_distance: float = 80.0
@export var float_duration: float = 0.5
@export var float_fade_start: float = 0.3
@export var crit_float_scale: float = 1.8
@export var result_delay: float = 0.4

@onready var _background: ColorRect = %Background
@onready var _shake_camera: Camera2D = %ShakeCamera
@onready var _tick_label: Label = %TickLabel
@onready var _skip_button: Button = %SkipButton
@onready var _opp_name: Label = %OppName
@onready var _opp_bar: HpBar = %OppBar
@onready var _opp_grid_area: Control = %OppGridArea
@onready var _opp_grid_container: GridContainer = %OppGridContainer
@onready var _vs_label: Label = %VsLabel
@onready var _player_name: Label = %PlayerName
@onready var _player_bar: HpBar = %PlayerBar
@onready var _player_grid_area: Control = %PlayerGridArea
@onready var _player_grid_container: GridContainer = %PlayerGridContainer
@onready var _float_layer: Control = %FloatLayer
@onready var _result_overlay: ColorRect = %ResultOverlay
@onready var _result_banner: Label = %ResultBanner
@onready var _continue_button: Button = %ContinueButton
@onready var _log_player: CombatLogPlayer = %LogPlayer

var _cards_by_item_id: Dictionary = {}   # item_id -> ItemCard
var _items_by_id: Dictionary = {}        # item_id -> item Dictionary
var _side_by_item_id: Dictionary = {}    # item_id -> "player" | "opponent"
var _bars_by_player_id: Dictionary = {}  # player_id -> HpBar
var _result_shown: bool = false
var _round_played: int = 0
var _fight_won: bool = false
var _finalize_synced: bool = false

enum ContinueAction { SYNCING, CONTINUE, RETRY_SYNC, BACK_TO_PREP }
var _continue_action: ContinueAction = ContinueAction.SYNCING

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_background.color = SynGridPalette.PANEL_BG
	_layout_screen()

	# ScreenEffects shakes by offsetting the current camera; centred at the
	# viewport midpoint the camera reproduces the identity view.
	_shake_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_shake_camera.position = Vector2.ZERO
	_shake_camera.enabled = true
	_shake_camera.make_current()
	ScreenEffects.set_camera(_shake_camera)

	var log: Dictionary = GameState.last_combat_log
	_build_side("player", GameState.equipped_items, _player_grid_container, false)
	_build_side("opponent", GameState.opponent_grid.get("equipped_items", []),
		_opp_grid_container, true)
	_player_name.text = "YOU"
	_opp_name.text = String(GameState.opponent_grid.get("player_id", "UNKNOWN")).to_upper()

	# Bars start at the 1000 HP baseline; the shield strip starts at the
	# displayed armor total and every event overwrites both with the server's
	# after-values, so any mismatch self-corrects on the first hit.
	_player_bar.setup(COMBAT_MAX_HP, _display_shield_total(GameState.equipped_items))
	_opp_bar.setup(COMBAT_MAX_HP,
		_display_shield_total(GameState.opponent_grid.get("equipped_items", [])))
	var attacker_id := String(log.get("attacker_id", GameState.player_id))
	var defender_id := String(log.get("defender_id", ""))
	_bars_by_player_id[attacker_id] = _player_bar if attacker_id == GameState.player_id else _opp_bar
	_bars_by_player_id[defender_id] = _player_bar if defender_id == GameState.player_id else _opp_bar

	_log_player.event_played.connect(_on_event_played)
	_log_player.playback_finished.connect(_on_playback_finished)
	_skip_button.pressed.connect(_skip_to_result)
	_continue_button.disabled = true
	_continue_button.text = "SYNCING..."
	_continue_button.pressed.connect(_on_continue_pressed)

	ApiClient.finalize_round_completed.connect(_on_finalize_round_completed)
	ApiClient.finalize_round_failed.connect(_on_finalize_round_failed)

	# StartMatch response received -> combat track (contract section 5).
	AudioManager.play_combat_bgm()
	_tick_label.text = "TICK 0 / %d" % int(log.get("total_ticks", 0))
	await get_tree().create_timer(intro_delay).timeout
	_log_player.load_log(log)

# -- Board construction --

func _cell_outer_size() -> Vector2:
	return mini_cell_card_size + Vector2.ONE * (ThemeBuilder.PANEL_CONTENT_MARGIN * 2.0)

func _layout_screen() -> void:
	var grid_total := _cell_outer_size() * Vector2(grid_columns, grid_rows)
	var center_x := (size.x - grid_total.x) / 2.0

	_tick_label.position = Vector2(40.0, 28.0)
	_tick_label.size = Vector2(size.x - 80.0, 36.0)

	_opp_name.position = Vector2(40.0, 76.0)
	_opp_name.size = Vector2(size.x - 80.0, 32.0)
	_opp_bar.position = Vector2(40.0, 116.0)
	_opp_bar.size = Vector2(size.x - 80.0, 52.0)
	_opp_grid_area.position = Vector2(center_x, 196.0)
	_opp_grid_area.size = grid_total

	_vs_label.position = Vector2(0.0, size.y * 0.465)
	_vs_label.size = Vector2(size.x, 60.0)

	_player_grid_area.position = Vector2(center_x, size.y * 0.52)
	_player_grid_area.size = grid_total
	_player_bar.position = Vector2(40.0, _player_grid_area.position.y + grid_total.y + 28.0)
	_player_bar.size = Vector2(size.x - 80.0, 52.0)
	_player_name.position = Vector2(40.0, _player_bar.position.y + 60.0)
	_player_name.size = Vector2(size.x - 80.0, 32.0)

	for container in [_opp_grid_container, _player_grid_container]:
		container.columns = grid_columns
		container.add_theme_constant_override("h_separation", 0)
		container.add_theme_constant_override("v_separation", 0)
		container.size = grid_total

func _build_side(side: String, items: Array, container: GridContainer, mirror_x: bool) -> void:
	var cells: Dictionary = {}
	for y in grid_rows:
		for x in grid_columns:
			var cell := GridCell.new()
			cell.setup(x, y, _cell_outer_size())
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(cell)
			cells[Vector2i(x, y)] = cell
	for item: Dictionary in items:
		var coords = item.get("placement_coords")
		if coords == null:
			continue
		var x := int(coords.get("x", 0))
		if mirror_x:
			# Mirror the opponent board so the two grids face each other the
			# same way the server's mirrored-distance targeting sees them.
			x = grid_columns - 1 - x
		var cell: GridCell = cells.get(Vector2i(x, int(coords.get("y", 0))))
		if cell == null or cell.has_card():
			continue
		var card: ItemCard = ITEM_CARD_SCENE.instantiate()
		card.card_size = mini_cell_card_size
		card.draggable = false
		cell.add_child(card)
		card.set_item_data(item)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var item_id: String = item.get("item_id", "")
		_cards_by_item_id[item_id] = card
		_items_by_id[item_id] = item
		_side_by_item_id[item_id] = side

# Display-only initial shield strip: the sum of armor on the visible ARMOR
# items. Authoritative values arrive with every event's target_shield_after.
func _display_shield_total(items: Array) -> float:
	var total := 0.0
	for item: Dictionary in items:
		if String(item.get("item_type", "")) == "ARMOR":
			total += float(item.get("base_attributes", {}).get("armor_rating", 0.0))
	return total

# -- Event interpretation (contract section 4) --

func _on_event_played(ev: Dictionary) -> void:
	_tick_label.text = "TICK %d / %d" % [int(ev.get("tick", 0)),
		int(GameState.last_combat_log.get("total_ticks", 0))]

	var firing_id := String(ev.get("firing_item_id", ""))
	var crit: bool = ev.get("crit", false)
	var hp_loss := float(ev.get("hp_loss", 0.0))
	var shield_absorbed := float(ev.get("shield_absorbed", 0.0))

	_play_lunge(firing_id)
	_play_fire_sfx(firing_id, crit)

	# Server-authoritative bar update.
	var target_bar: HpBar = _bars_by_player_id.get(String(ev.get("target_player_id", "")))
	if target_bar != null:
		target_bar.set_state(float(ev.get("target_hp_after", 0.0)),
			float(ev.get("target_shield_after", 0.0)))

	var impact_pos := _impact_position(ev, target_bar)
	if shield_absorbed > 0.0:
		AudioManager.play_shield_absorb(impact_pos)
	if hp_loss > 0.0:
		AudioManager.play_hp_loss()
	_spawn_damage_float(impact_pos, hp_loss, shield_absorbed, crit)

	# Shake scales with damage; ScreenEffects adds the crit flash + hit-stop.
	ScreenEffects.shake_from_hit(hp_loss, COMBAT_MAX_HP, crit)

func _play_lunge(firing_id: String) -> void:
	var card: ItemCard = _cards_by_item_id.get(firing_id)
	if card == null:
		return
	# Lunge toward the enemy: the player's arena is the lower one, so its
	# items strike upward; the opponent's strike downward.
	var dir := Vector2.UP if _side_by_item_id.get(firing_id, "player") == "player" else Vector2.DOWN
	var rest := card.position
	var tw := create_tween()
	tw.tween_property(card, "position", rest + dir * lunge_distance, lunge_out_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	tw.tween_property(card, "position", rest, lunge_back_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _play_fire_sfx(firing_id: String, crit: bool) -> void:
	var item: Dictionary = _items_by_id.get(firing_id, {})
	var card: ItemCard = _cards_by_item_id.get(firing_id)
	var pos := card.get_global_rect().get_center() if card != null else size / 2.0
	match String(item.get("weapon_category", "")):
		"MELEE":
			AudioManager.play_melee_strike(pos)
		"RANGED":
			AudioManager.play_ranged_strike(pos)
		"ARCANE":
			AudioManager.play_arcane_strike(pos)
	if crit:
		AudioManager.play_crit_hit(pos)

func _impact_position(ev: Dictionary, target_bar: HpBar) -> Vector2:
	var target_card: ItemCard = _cards_by_item_id.get(String(ev.get("target_item_id", "")))
	if target_card != null:
		return target_card.get_global_rect().get_center()
	if target_bar != null:
		return target_bar.get_global_rect().get_center()
	return size / 2.0

# Bouncy floating damage indicator (contract section 4).
func _spawn_damage_float(pos: Vector2, hp_loss: float, shield_absorbed: float, crit: bool) -> void:
	var label := Label.new()
	if hp_loss > 0.0:
		label.text = str(int(round(hp_loss)))
		label.add_theme_color_override("font_color",
			Color(0.85, 0.10, 0.10) if crit else SynGridPalette.TEXT_PRIMARY)
	elif shield_absorbed > 0.0:
		label.text = "BLOCKED"
		label.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	else:
		return
	label.add_theme_font_size_override("font_size", 26)
	if crit:
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0))
		label.add_theme_constant_override("outline_size", 6)
	_float_layer.add_child(label)
	label.global_position = pos
	label.pivot_offset = label.size / 2.0
	if crit:
		label.scale = Vector2(crit_float_scale, crit_float_scale)

	var angle := randf_range(-PI / 12.0, PI / 12.0)
	var dir := Vector2.UP.rotated(angle)
	var move := create_tween()
	move.tween_property(label, "global_position", pos + dir * float_rise_distance,
		float_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var fade := create_tween()
	fade.tween_interval(float_fade_start)
	fade.tween_property(label, "modulate:a", 0.0, float_duration - float_fade_start)
	fade.tween_callback(label.queue_free)

# -- Result --

func _on_playback_finished(winner_id: String, attacker_hp: float, defender_hp: float) -> void:
	var log: Dictionary = GameState.last_combat_log
	var attacker_bar: HpBar = _bars_by_player_id.get(String(log.get("attacker_id", "")))
	var defender_bar: HpBar = _bars_by_player_id.get(String(log.get("defender_id", "")))
	if attacker_bar != null:
		attacker_bar.set_state(attacker_hp, 0.0)
	if defender_bar != null:
		defender_bar.set_state(defender_hp, 0.0)
	await get_tree().create_timer(result_delay).timeout
	_show_result(winner_id)

func _skip_to_result() -> void:
	_log_player.stop()
	var log: Dictionary = GameState.last_combat_log
	var attacker_bar: HpBar = _bars_by_player_id.get(String(log.get("attacker_id", "")))
	var defender_bar: HpBar = _bars_by_player_id.get(String(log.get("defender_id", "")))
	if attacker_bar != null:
		attacker_bar.set_state(float(log.get("attacker_hp_final", 0.0)), 0.0)
	if defender_bar != null:
		defender_bar.set_state(float(log.get("defender_hp_final", 0.0)), 0.0)
	_show_result(String(log.get("winner_id", "")))

func _show_result(winner_id: String) -> void:
	if _result_shown:
		return
	_result_shown = true
	_skip_button.visible = false
	var won := winner_id == GameState.player_id
	GameState.last_fight_won = won
	if won:
		AudioManager.play_win_round()
	_result_banner.text = "VICTORY" if won else "DEFEAT"
	_result_banner.add_theme_color_override("font_color",
		SynGridPalette.ACCENT_TEAL if won else SynGridPalette.DANGER)
	_result_overlay.visible = true
	_round_played = GameState.current_round
	_fight_won = won
	_begin_finalize_round()
	for node: Control in [_result_banner, _continue_button]:
		node.pivot_offset = node.size / 2.0
		node.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_result_banner, "scale", Vector2(1.1, 1.1), 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(_result_banner, "scale", Vector2.ONE, 0.06) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_continue_button, "scale", Vector2(1.1, 1.1), 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(_continue_button, "scale", Vector2.ONE, 0.06) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

func _begin_finalize_round() -> void:
	var log: Dictionary = GameState.last_combat_log
	ApiClient.finalize_round(
		String(log.get("attacker_id", GameState.player_id)),
		String(log.get("defender_id", "")),
		String(log.get("winner_id", "")),
		_round_played)

func _on_finalize_round_completed(data: Dictionary) -> void:
	GameState.apply_round_result(data, _fight_won, _round_played)
	_finalize_synced = true
	_continue_action = ContinueAction.CONTINUE
	_continue_button.disabled = false
	_continue_button.text = "CONTINUE"

func _on_finalize_round_failed(_code: int, reason: String) -> void:
	match reason:
		"MATCH_ALREADY_RESOLVED":
			_set_finalize_status("RECOVERING STATE...")
			_continue_action = ContinueAction.BACK_TO_PREP
			ApiClient.get_active_grid_completed.connect(_on_recover_grid_completed, CONNECT_ONE_SHOT)
			ApiClient.get_active_grid_failed.connect(_on_recover_grid_failed, CONNECT_ONE_SHOT)
			ApiClient.get_active_grid()
		"MATCH_NOT_STARTED":
			_set_finalize_status("MATCH STATE LOST - REFIGHT")
			_finalize_synced = true
			_continue_action = ContinueAction.BACK_TO_PREP
			_continue_button.disabled = false
			_continue_button.text = "BACK TO PREP"
		_:
			_set_finalize_status("SYNC FAILED - %s" % reason)
			_continue_action = ContinueAction.RETRY_SYNC
			_continue_button.disabled = false
			_continue_button.text = "RETRY SYNC"

func _on_recover_grid_completed(data: Dictionary) -> void:
	GameState.hydrate_from_grid(data.get("grid", {}))
	_finalize_synced = true
	_continue_action = ContinueAction.BACK_TO_PREP
	_continue_button.disabled = false
	_continue_button.text = "BACK TO PREP"

func _on_recover_grid_failed(_code: int, reason: String) -> void:
	_set_finalize_status("RECOVERY FAILED - %s" % reason)
	_finalize_synced = true
	_continue_action = ContinueAction.BACK_TO_PREP
	_continue_button.disabled = false
	_continue_button.text = "BACK TO PREP"

func _on_continue_pressed() -> void:
	if _continue_action == ContinueAction.RETRY_SYNC:
		_continue_action = ContinueAction.SYNCING
		_continue_button.disabled = true
		_continue_button.text = "SYNCING..."
		_begin_finalize_round()
		return
	await _pulse(_continue_button).finished
	match _continue_action:
		ContinueAction.BACK_TO_PREP:
			get_tree().change_scene_to_file(PREP_SCENE_PATH)
		ContinueAction.CONTINUE:
			if _finalize_synced:
				get_tree().change_scene_to_file(ROUND_END_SCENE_PATH)

func _set_finalize_status(text: String) -> void:
	_tick_label.text = text

func _pulse(control: Control) -> Tween:
	control.pivot_offset = control.size / 2.0
	var tw := create_tween()
	tw.tween_property(control, "scale", Vector2(0.94, 0.94), 0.05) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(control, "scale", Vector2.ONE, 0.10) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tw
