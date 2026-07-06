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
@onready var _round_timer_ring: ColorRect = %RoundTimerRing
@onready var _skip_button: Button = %SkipButton
@onready var _opp_name: Label = %OppName
@onready var _opp_bar: HpBar = %OppBar
@onready var _opp_grid_area: Control = %OppGridArea
@onready var _opp_grid_container: GridContainer = %OppGridContainer
@onready var _opp_floor: ColorRect = %OppFloor
@onready var _vs_label: Label = %VsLabel
@onready var _player_name: Label = %PlayerName
@onready var _player_bar: HpBar = %PlayerBar
@onready var _player_grid_area: Control = %PlayerGridArea
@onready var _player_grid_container: GridContainer = %PlayerGridContainer
@onready var _player_floor: ColorRect = %PlayerFloor

# Neon Grimoire session #4: projectile/hitmark/muzzle-flash reparent target.
# Created in _ready() so the scene's script can be tested standalone without
# extra .tscn wiring.
var _projectile_layer: Node2D = null
@onready var _float_layer: Control = %FloatLayer
@onready var _result_overlay: ColorRect = %ResultOverlay
@onready var _result_banner: Label = %ResultBanner
@onready var _continue_button: Button = %ContinueButton
@onready var _status_label: Label = %StatusLabel
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

        # Projectile layer sits above the item grids but below any overlay
        # banner/flash. All battle-page FX (projectiles, hitmarks, muzzle
        # flashes) reparent to this node so they self-clean when the scene
        # exits.
        _projectile_layer = Node2D.new()
        _projectile_layer.name = "ProjectileLayer"
        _projectile_layer.z_index = 8
        add_child(_projectile_layer)

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
        _update_round_timer_progress(0, int(log.get("total_ticks", 0)))
        _play_intro_banner(_opp_name.text)
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

        # Arcane-circle floors sit under each team's grid, sized larger than the
        # grid so the disc extends past the corners. Enemy = red danger tint,
        # player = teal ACCENT tint. Shaders animate on their own via TIME.
        for pair in [[_opp_floor, _opp_grid_area], [_player_floor, _player_grid_area]]:
                var floor_rect: ColorRect = pair[0]
                var expand := grid_total.x * 0.18
                floor_rect.position = Vector2(-expand, -expand)
                floor_rect.size = grid_total + Vector2(expand * 2.0, expand * 2.0)

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
        _update_round_timer_progress(int(ev.get("tick", 0)),
                int(GameState.last_combat_log.get("total_ticks", 0)))

        var firing_id := String(ev.get("firing_item_id", ""))
        var crit: bool = ev.get("crit", false)
        var hp_loss := float(ev.get("hp_loss", 0.0))
        var shield_absorbed := float(ev.get("shield_absorbed", 0.0))
        var target_hp_after := float(ev.get("target_hp_after", 0.0))

        _play_lunge(firing_id)
        _play_fire_sfx(firing_id, crit)

        # Neon Grimoire battle-page upgrades (Session #4 A/B):
        # muzzle flash at firer, projectile streak to target (RANGED/ARCANE),
        # hitmark ring at impact, directional camera kick.
        var firing_card: ItemCard = _cards_by_item_id.get(firing_id)
        var firing_item: Dictionary = _items_by_id.get(firing_id, {})
        var category := String(firing_item.get("weapon_category", ""))
        var attacker_side := String(_side_by_item_id.get(firing_id, "player"))

        # Server-authoritative bar update.
        var target_bar: HpBar = _bars_by_player_id.get(String(ev.get("target_player_id", "")))
        if target_bar != null:
                target_bar.set_state(target_hp_after,
                        float(ev.get("target_shield_after", 0.0)))

        var impact_pos := _impact_position(ev, target_bar)
        if firing_card != null:
                _spawn_muzzle_flash(firing_card.get_global_rect().get_center(), category)
                _spawn_projectile(firing_card.get_global_rect().get_center(),
                        impact_pos, category, crit)
        _spawn_hitmark(impact_pos, crit, shield_absorbed, hp_loss)
        _apply_directional_kick(attacker_side)

        if shield_absorbed > 0.0:
                AudioManager.play_shield_absorb(impact_pos)
        if hp_loss > 0.0:
                AudioManager.play_hp_loss()
        _spawn_damage_float(impact_pos, hp_loss, shield_absorbed, crit)

        # Shake scales with damage; ScreenEffects adds the crit flash + hit-stop.
        ScreenEffects.shake_from_hit(hp_loss, COMBAT_MAX_HP, crit)

        # Killing-blow accent: on the shot that ends a life bar, paint a soft
        # DANGER wash over the whole viewport that fades out over 0.35s.
        if hp_loss > 0.0 and target_hp_after <= 0.0:
                _play_killing_blow_effect()

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
        await _pulse(_continue_button).finished
        if _continue_action == ContinueAction.RETRY_SYNC:
                _continue_action = ContinueAction.SYNCING
                _continue_button.disabled = true
                _continue_button.text = "SYNCING..."
                _status_label.text = ""
                _begin_finalize_round()
                return
        match _continue_action:
                ContinueAction.BACK_TO_PREP:
                        get_tree().change_scene_to_file(PREP_SCENE_PATH)
                ContinueAction.CONTINUE:
                        if _finalize_synced:
                                get_tree().change_scene_to_file(ROUND_END_SCENE_PATH)

func _set_finalize_status(text: String) -> void:
        _status_label.text = text

func _pulse(control: Control) -> Tween:
        control.pivot_offset = control.size / 2.0
        var tw := create_tween()
        tw.tween_property(control, "scale", Vector2(0.94, 0.94), 0.05) \
                .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
        tw.tween_property(control, "scale", Vector2.ONE, 0.10) \
                .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
        return tw


# Neon Grimoire circular round-timer ring. Progress is 1.0 (fresh) -> 0.0
# (expired). Colour smoothly transitions ACCENT_TEAL -> ACCENT_AMBER -> DANGER
# and pulses when below the danger threshold. The material lives on
# %RoundTimerRing (ColorRect + round_timer_ring.gdshader).
func _update_round_timer_progress(current_tick: int, total_ticks: int) -> void:
        if _round_timer_ring == null or _round_timer_ring.material == null:
                return
        if total_ticks <= 0:
                _round_timer_ring.material.set_shader_parameter("progress", 1.0)
                return
        var remaining := clampf(1.0 - float(current_tick) / float(total_ticks), 0.0, 1.0)
        _round_timer_ring.material.set_shader_parameter("progress", remaining)

# -- Neon Grimoire battle-page upgrades (session #4, tiers A + B) --
#
# All helpers below are pure presentation: they spawn short-lived visual
# nodes (Line2D streaks, TextureRect hitmarks/flashes, full-screen wash) and
# tween them, then self-free. They never touch GameState, ApiClient, or the
# CombatLogPlayer's timing - juice_manual.md section 4 timing rules (0.10s
# tick cadence, hit-stop 2 frames, no LINEAR tweens) are all preserved.

const _PROJECTILE_SPARK_TEXTURE: Texture2D = preload("res://assets/sprites/effects/spark.png")
const _PROJECTILE_HITMARK_TEXTURE: Texture2D = preload("res://assets/sprites/effects/hitmark.png")

func _projectile_color(category: String) -> Color:
        # Warm/cool tints so the eye reads category at a glance without needing
        # to look at the source card.
        match category:
                "RANGED":
                        return Color(0.35, 0.85, 0.35)
                "ARCANE":
                        return SynGridPalette.ACCENT_PURPLE
                "MELEE":
                        return Color(0.95, 0.35, 0.30)
                _:
                        return SynGridPalette.ACCENT_TEAL

# RANGED / ARCANE fires spawn a tapered Line2D that flies from the firer's
# card centre to the impact point over one tick (0.10s), then fades. MELEE
# uses its lunge instead - no projectile.
func _spawn_projectile(from_pos: Vector2, target_pos: Vector2,
                category: String, crit: bool) -> void:
        if category == "MELEE" or category == "":
                return
        var line := Line2D.new()
        var color := _projectile_color(category)
        if crit:
                color = color.lightened(0.35)
        line.default_color = color
        line.width = 5.0 if crit else 3.5
        line.z_index = 10
        line.add_point(from_pos)
        line.add_point(from_pos)
        _projectile_layer.add_child(line)
        var travel := 0.09
        # Head races to target; tail follows with a slight lag to give the
        # streak a tapered "trail" look.
        var tw := line.create_tween().set_parallel(true)
        tw.tween_method(func(v: Vector2) -> void:
                line.set_point_position(1, v),
                from_pos, target_pos, travel) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw.tween_method(func(v: Vector2) -> void:
                line.set_point_position(0, v),
                from_pos, target_pos, travel + 0.06).set_delay(0.02)
        tw.tween_property(line, "modulate:a", 0.0, 0.14).set_delay(travel + 0.02)
        line.create_tween().tween_callback(line.queue_free).set_delay(travel + 0.22)

# Bracket-style hitmark ring that pops (elastic overshoot) at the impact
# point, spins slightly, then fades. Crimson = crit, silver = pure shield
# block, teal = normal HP damage.
func _spawn_hitmark(pos: Vector2, crit: bool, shield_absorbed: float, hp_loss: float) -> void:
        var tex := TextureRect.new()
        tex.texture = _PROJECTILE_HITMARK_TEXTURE
        tex.size = Vector2(56.0, 56.0)
        tex.pivot_offset = Vector2(28.0, 28.0)
        tex.position = pos - Vector2(28.0, 28.0)
        var color: Color
        if crit:
                color = SynGridPalette.DANGER
        elif hp_loss <= 0.0 and shield_absorbed > 0.0:
                color = SynGridPalette.ACCENT_SILVER
        else:
                color = SynGridPalette.ACCENT_TEAL
        tex.modulate = Color(color.r, color.g, color.b, 0.9)
        tex.scale = Vector2(0.4, 0.4)
        tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tex.z_index = 12
        _projectile_layer.add_child(tex)
        var tw := tex.create_tween().set_parallel(true)
        tw.tween_property(tex, "scale", Vector2(1.35, 1.35), 0.12) \
                .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
        tw.tween_property(tex, "rotation", TAU * 0.12, 0.34) \
                .set_trans(Tween.TRANS_QUAD)
        tw.tween_property(tex, "modulate:a", 0.0, 0.22).set_delay(0.13) \
                .set_trans(Tween.TRANS_QUAD)
        tex.create_tween().tween_callback(tex.queue_free).set_delay(0.36)

# Small sparkle at the firer's card centre - "energy released" feel. Same
# category tint as the projectile so the whole strike reads as one motion.
func _spawn_muzzle_flash(pos: Vector2, category: String) -> void:
        var tex := TextureRect.new()
        tex.texture = _PROJECTILE_SPARK_TEXTURE
        tex.size = Vector2(36.0, 36.0)
        tex.pivot_offset = Vector2(18.0, 18.0)
        tex.position = pos - Vector2(18.0, 18.0)
        var color := _projectile_color(category)
        tex.modulate = Color(color.r, color.g, color.b, 0.95)
        tex.scale = Vector2(0.4, 0.4)
        tex.rotation = randf() * TAU
        tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tex.z_index = 11
        _projectile_layer.add_child(tex)
        var tw := tex.create_tween().set_parallel(true)
        tw.tween_property(tex, "scale", Vector2(1.3, 1.3), 0.08) \
                .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tw.tween_property(tex, "modulate:a", 0.0, 0.16) \
                .set_trans(Tween.TRANS_QUAD)
        tex.create_tween().tween_callback(tex.queue_free).set_delay(0.18)

# Directional camera kick: player attacks bounce the screen UP, opponent
# attacks bounce it DOWN. Uses _shake_camera.position:y - ScreenEffects
# animates _shake_camera.offset, so the two channels never fight.
func _apply_directional_kick(attacker_side: String) -> void:
        if _shake_camera == null:
                return
        var kick_y := -8.0 if attacker_side == "player" else 8.0
        var tw := _shake_camera.create_tween()
        tw.tween_property(_shake_camera, "position:y", kick_y, 0.05) \
                .set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
        tw.tween_property(_shake_camera, "position:y", 0.0, 0.14) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# 0.6s battle-open banner: "YOU vs OPPONENT" pops in with elastic scale,
# holds, then fades. Non-blocking - the log playback still starts on
# intro_delay so the banner overlaps the first tick briefly.
func _play_intro_banner(opp_name: String) -> void:
        var banner := Label.new()
        var my_name := String(GameState.display_name).to_upper()
        if my_name == "":
                my_name = "YOU"
        banner.text = "%s\nvs\n%s" % [my_name, opp_name]
        banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        banner.add_theme_font_size_override("font_size", 44)
        banner.add_theme_color_override("font_color", SynGridPalette.ACCENT_TEAL)
        banner.add_theme_color_override("font_outline_color",
                Color(SynGridPalette.ACCENT_PURPLE, 0.8))
        banner.add_theme_constant_override("outline_size", 6)
        banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
        banner.z_index = 50
        banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        add_child(banner)
        banner.pivot_offset = size / 2.0
        banner.modulate.a = 0.0
        banner.scale = Vector2(0.6, 0.6)
        var tw := banner.create_tween().set_parallel(true)
        tw.tween_property(banner, "modulate:a", 1.0, 0.20) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw.tween_property(banner, "scale", Vector2.ONE, 0.35) \
                .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
        # Chain a hold + fade on a fresh tween so it runs after the pop.
        var out_tw := banner.create_tween()
        out_tw.tween_interval(0.45)
        out_tw.tween_property(banner, "modulate:a", 0.0, 0.20) \
                .set_trans(Tween.TRANS_QUAD)
        out_tw.tween_callback(banner.queue_free)

# Fatal-blow: full-viewport crimson wash on the shot that drops a life bar
# to zero. Fades over 0.35s and self-frees. Doesn't block input; z_index
# keeps it above cards but below the outro banner.
func _play_killing_blow_effect() -> void:
        var flash := ColorRect.new()
        flash.color = Color(SynGridPalette.DANGER.r, SynGridPalette.DANGER.g,
                SynGridPalette.DANGER.b, 0.45)
        flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
        flash.z_index = 45
        flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        add_child(flash)
        var tw := flash.create_tween()
        tw.tween_property(flash, "modulate:a", 0.0, 0.35) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw.tween_callback(flash.queue_free)