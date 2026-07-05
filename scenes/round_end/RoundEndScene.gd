class_name RoundEndScene
extends Control

# C7: Round-end ceremony - juice contract sections 1, 2, and 5. All life,
# triumph, gold, and round values are server-authoritative via
# GameState.last_round_result (written by apply_round_result). This scene
# never increments current_round locally; it only displays and claims
# AwardRoundGold for next_round when the run is not terminal.

const PREP_SCENE_PATH: String = "res://scenes/grid_prep/GridPrepScene.tscn"
const MAX_LIFE: int = 5
const MAX_TRIUMPH: int = 10

@export var banner_pop_duration: float = 0.12
@export var banner_settle_duration: float = 0.06
@export var hearts_delay: float = 0.4
@export var orbs_delay: float = 0.9
@export var continue_delay: float = 1.6
@export var heart_size: float = 72.0
@export var orb_size: float = 56.0
@export var heart_stagger: float = 0.04
@export var orb_stagger: float = 0.04
@export var heart_shatter_up_duration: float = 0.08
@export var heart_shatter_down_duration: float = 0.12
@export var payout_count_duration: float = 0.6
@export var particle_lifetime: float = 0.35
@export var press_squish_scale: float = 0.94
@export var press_squish_duration: float = 0.05
@export var press_release_duration: float = 0.10

@onready var _background: ColorRect = %Background
@onready var _banner: Label = %Banner
@onready var _round_caption: Label = %RoundCaption
@onready var _hearts_row: HBoxContainer = %HeartsRow
@onready var _triumph_caption: Label = %TriumphCaption
@onready var _orbs_row: HBoxContainer = %OrbsRow
@onready var _payout_caption: Label = %PayoutCaption
@onready var _payout_value: Label = %PayoutValue
@onready var _continue_button: Button = %ContinueButton
@onready var _new_run_button: Button = %NewRunButton
@onready var _status_label: Label = %StatusLabel
@onready var _fx_layer: Control = %FxLayer

var _result: Dictionary = {}
var _won: bool = false
var _round_played: int = 1
var _next_round: int = 1
var _gold_rewarded: int = 0
var _is_eliminated: bool = false
var _is_victory: bool = false
var _heart_holders: Array[Control] = []
var _orb_holders: Array[Control] = []
var _award_pending: bool = false

func _ready() -> void:
	theme = ThemeBuilder.get_theme()
	_background.color = SynGridPalette.PANEL_BG
	_payout_value.add_theme_color_override("font_color", SynGridPalette.GOLD)
	_layout_screen()
	_result = GameState.last_round_result
	_won = bool(_result.get("won", GameState.last_fight_won))
	_round_played = int(_result.get("round_played", maxi(1, GameState.current_round - 1)))
	_next_round = int(_result.get("next_round", GameState.current_round))
	_gold_rewarded = int(_result.get("gold_rewarded", 0))
	var my_state: Dictionary = _result.get("my_state", {})
	_is_eliminated = bool(my_state.get("eliminated", false))
	_is_victory = int(my_state.get("triumph_count", GameState.triumph_count)) >= MAX_TRIUMPH

	ApiClient.award_round_gold_completed.connect(_on_award_round_gold_completed)
	ApiClient.award_round_gold_failed.connect(_on_award_round_gold_failed)
	ApiClient.reset_run_completed.connect(_on_reset_run_completed)
	ApiClient.reset_run_failed.connect(_on_reset_run_failed)

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_run_button.pressed.connect(_on_new_run_pressed)
	_continue_button.visible = not (_is_eliminated or _is_victory)
	_new_run_button.visible = _is_eliminated or _is_victory

	AudioManager.play_prep_bgm()
	_run_ceremony()

	if not _is_eliminated and not _is_victory:
		_request_payout_grant()

func _layout_screen() -> void:
	_banner.position = Vector2(40.0, size.y * 0.14)
	_banner.size = Vector2(size.x - 80.0, 120.0)
	_round_caption.position = Vector2(40.0, size.y * 0.22)
	_round_caption.size = Vector2(size.x - 80.0, 32.0)
	_hearts_row.position = Vector2(40.0, size.y * 0.34)
	_hearts_row.size = Vector2(size.x - 80.0, heart_size)
	_triumph_caption.position = Vector2(40.0, size.y * 0.44)
	_triumph_caption.size = Vector2(size.x - 80.0, 32.0)
	_orbs_row.position = Vector2(40.0, size.y * 0.48)
	_orbs_row.size = Vector2(size.x - 80.0, orb_size)
	_payout_caption.position = Vector2(40.0, size.y * 0.60)
	_payout_caption.size = Vector2(size.x - 80.0, 32.0)
	_payout_value.position = Vector2(40.0, size.y * 0.64)
	_payout_value.size = Vector2(size.x - 80.0, 48.0)
	var button_w := size.x - 80.0
	_continue_button.position = Vector2(40.0, size.y * 0.76)
	_continue_button.size = Vector2(button_w, 140.0)
	_new_run_button.position = Vector2(40.0, size.y * 0.76)
	_new_run_button.size = Vector2(button_w, 140.0)

func _run_ceremony() -> void:
	_round_caption.text = "ROUND %d COMPLETE" % _round_played
	_configure_banner()
	_pop_banner()
	await get_tree().create_timer(hearts_delay).timeout
	await _animate_hearts()
	await get_tree().create_timer(orbs_delay - hearts_delay).timeout
	await _animate_orbs()
	if _is_eliminated or _is_victory:
		_payout_caption.visible = false
		_payout_value.visible = false
		await get_tree().create_timer(continue_delay - orbs_delay).timeout
		_pop_terminal_button()
	else:
		await get_tree().create_timer(continue_delay - orbs_delay).timeout
		_pop_continue()

func _configure_banner() -> void:
	if _is_eliminated:
		_banner.text = "RUN TERMINATED"
		_banner.add_theme_color_override("font_color", SynGridPalette.DANGER)
	elif _is_victory:
		_banner.text = "GRID DOMINATED"
		_banner.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	elif _won:
		_banner.text = "ROUND %d WON" % _round_played
		_banner.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
	else:
		_banner.text = "ROUND %d LOST" % _round_played
		_banner.add_theme_color_override("font_color", SynGridPalette.DANGER)

func _pop_banner() -> void:
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2(1.1, 1.1), banner_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(_banner, "scale", Vector2.ONE, banner_settle_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

func _animate_hearts() -> void:
	_clear_row(_hearts_row, _heart_holders)
	var display_life := _display_life_before_round()
	if _is_eliminated:
		display_life = MAX_LIFE
	for i in MAX_LIFE:
		var holder := _make_heart_holder(i < display_life)
		_hearts_row.add_child(holder)
		_heart_holders.append(holder)
	if _is_eliminated:
		AudioManager.play_fatal_hp_loss()
		for i in _heart_holders.size():
			await get_tree().create_timer(heart_stagger).timeout
			_shatter_heart(_heart_holders[i])
		return
	if not _won:
		for i in _heart_holders.size():
			if i < display_life:
				_pop_holder(_heart_holders[i], i * heart_stagger)
		await get_tree().create_timer(display_life * heart_stagger + 0.12).timeout
		var lost_idx := display_life - 1
		if lost_idx >= 0 and lost_idx < _heart_holders.size():
			_shatter_heart(_heart_holders[lost_idx])
			AudioManager.play_fatal_hp_loss()
		return
	for i in _heart_holders.size():
		_pop_holder(_heart_holders[i], i * heart_stagger)

func _animate_orbs() -> void:
	_clear_row(_orbs_row, _orb_holders)
	var triumph := int(_result.get("my_state", {}).get("triumph_count", GameState.triumph_count))
	if _is_victory:
		triumph = MAX_TRIUMPH
	for i in MAX_TRIUMPH:
		var filled := i < triumph
		var holder := _make_orb_holder(filled)
		_orbs_row.add_child(holder)
		_orb_holders.append(holder)
	if _is_victory:
		AudioManager.play_triumph_milestone()
		for i in _orb_holders.size():
			await get_tree().create_timer(orb_stagger).timeout
			_pop_holder(_orb_holders[i], 0.0)
		return
	for i in triumph:
		var is_newest := _won and i == triumph - 1
		if is_newest:
			_pop_holder(_orb_holders[i], 0.0, true)
			_spawn_burst(_orb_holders[i].global_position + Vector2(orb_size, orb_size) * 0.5,
				SynGridPalette.ACCENT_TEAL)
		else:
			_pop_holder(_orb_holders[i], i * orb_stagger)
	if _gold_rewarded > 0:
		AudioManager.play_triumph_milestone()
		_status_label.text = "MILESTONE +%dG" % _gold_rewarded

func _display_life_before_round() -> int:
	if _won:
		return GameState.life_points
	return mini(MAX_LIFE, GameState.life_points + 1)

func _make_heart_holder(full: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(heart_size, heart_size)
	holder.pivot_offset = Vector2(heart_size, heart_size) * 0.5
	var rect := ColorRect.new()
	rect.size = Vector2(heart_size * 0.7, heart_size * 0.7)
	rect.position = Vector2(heart_size * 0.15, heart_size * 0.15)
	rect.rotation = PI / 4.0
	rect.pivot_offset = rect.size / 2.0
	rect.color = SynGridPalette.HP_LOW if full else SynGridPalette.TEXT_DIM
	rect.color.a = 0.9 if full else 0.25
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rect)
	holder.scale = Vector2.ZERO
	return holder

func _make_orb_holder(filled: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(orb_size, orb_size)
	holder.pivot_offset = Vector2(orb_size, orb_size) * 0.5
	var rect := ColorRect.new()
	rect.size = Vector2(orb_size, orb_size)
	rect.color = SynGridPalette.ACCENT_TEAL if filled else SynGridPalette.TEXT_DIM
	rect.color.a = 0.9 if filled else 0.25
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rect)
	holder.scale = Vector2.ZERO
	return holder

func _pop_holder(holder: Control, stagger: float, elastic: bool = false) -> void:
	var tw := create_tween()
	if stagger > 0.0:
		tw.tween_interval(stagger)
	var peak := Vector2(1.15, 1.15) if elastic else Vector2(1.1, 1.1)
	tw.tween_property(holder, "scale", peak, banner_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(holder, "scale", Vector2.ONE, banner_settle_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

func _shatter_heart(holder: Control) -> void:
	var tw := create_tween()
	tw.tween_property(holder, "scale", Vector2(1.3, 1.3), heart_shatter_up_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(holder, "scale", Vector2.ZERO, heart_shatter_down_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_spawn_burst(holder.global_position + Vector2(heart_size, heart_size) * 0.5,
		SynGridPalette.DANGER)

func _spawn_burst(pos: Vector2, color: Color) -> void:
	var particles := _build_ring_particles(heart_size * 0.45, heart_size * 0.25, 24,
		particle_lifetime, 80.0, 160.0, 4.0, color, Color(color.r, color.g, color.b, 0.0))
	_fx_layer.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	get_tree().create_timer(particle_lifetime + 0.1).timeout.connect(particles.queue_free)

func _build_ring_particles(ring_radius: float, inner_radius: float, amount: int,
		lifetime: float, vel_min: float, vel_max: float, scale_max: float,
		from_color: Color, to_color: Color) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	particles.emission_ring_radius = ring_radius
	particles.emission_ring_inner_radius = inner_radius
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = vel_min
	particles.initial_velocity_max = vel_max
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = scale_max
	var grad := Gradient.new()
	grad.set_color(0, from_color)
	grad.set_color(1, to_color)
	particles.color_ramp = grad
	return particles

func _request_payout_grant() -> void:
	if _award_pending:
		return
	_award_pending = true
	ApiClient.award_round_gold(_next_round, _won)

func _on_award_round_gold_completed(data: Dictionary) -> void:
	if _is_eliminated or _is_victory:
		return
	_award_pending = false
	var awarded := int(data.get("gold_awarded", 0))
	GameState.gold = int(data.get("new_balance", GameState.gold))
	GameState.gold_awarded_round = _next_round
	_animate_payout(awarded)

func _on_award_round_gold_failed(_code: int, reason: String) -> void:
	_award_pending = false
	_status_label.text = "GRANT PENDING - %s" % reason

func _animate_payout(target: int) -> void:
	var tw := create_tween()
	tw.tween_method(_set_payout_display, 0.0, float(target), payout_count_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_pop_payout_value)

func _set_payout_display(value: float) -> void:
	_payout_value.text = "%dG" % int(round(value))

func _pop_payout_value() -> void:
	_payout_value.pivot_offset = _payout_value.size / 2.0
	_payout_value.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(_payout_value, "scale", Vector2.ONE, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _pop_continue() -> void:
	_continue_button.pivot_offset = _continue_button.size / 2.0
	_continue_button.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_continue_button, "scale", Vector2(1.1, 1.1), banner_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(_continue_button, "scale", Vector2.ONE, banner_settle_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

func _pop_terminal_button() -> void:
	_new_run_button.pivot_offset = _new_run_button.size / 2.0
	_new_run_button.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_new_run_button, "scale", Vector2(1.1, 1.1), banner_pop_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(_new_run_button, "scale", Vector2.ONE, banner_settle_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

func _on_continue_pressed() -> void:
	await _pulse(_continue_button).finished
	get_tree().change_scene_to_file(PREP_SCENE_PATH)

func _on_new_run_pressed() -> void:
	_new_run_button.disabled = true
	_new_run_button.text = "RESETTING..."
	ApiClient.reset_run()

func _on_reset_run_completed(data: Dictionary) -> void:
	GameState.hydrate_from_grid(data.get("grid", {}))
	GameState.gold = int(data.get("new_balance", GameState.gold))
	GameState.gold_awarded_round = 0
	GameState.last_round_result = {}
	get_tree().change_scene_to_file(PREP_SCENE_PATH)

func _on_reset_run_failed(_code: int, reason: String) -> void:
	_new_run_button.disabled = false
	_new_run_button.text = "RETRY NEW RUN"
	_status_label.text = "RESET FAILED - %s" % reason
	if reason == "RUN_NOT_TERMINAL":
		ApiClient.get_active_grid_completed.connect(_on_reset_recover_grid_completed, CONNECT_ONE_SHOT)
		ApiClient.get_active_grid_failed.connect(_on_reset_recover_grid_failed, CONNECT_ONE_SHOT)
		ApiClient.get_active_grid()

func _on_reset_recover_grid_completed(data: Dictionary) -> void:
	GameState.hydrate_from_grid(data.get("grid", {}))

func _on_reset_recover_grid_failed(_code: int, reason: String) -> void:
	_status_label.text = "RESET FAILED - %s" % reason

func _pulse(control: Control) -> Tween:
	control.pivot_offset = control.size / 2.0
	var tw := create_tween()
	tw.tween_property(control, "scale", Vector2(press_squish_scale, press_squish_scale),
		press_squish_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(control, "scale", Vector2.ONE, press_release_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tw

func _clear_row(row: HBoxContainer, holders: Array) -> void:
	for child in row.get_children():
		child.queue_free()
	holders.clear()
