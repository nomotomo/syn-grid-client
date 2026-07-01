class_name AudioManager
extends Node
# Juice contract section 5: BGM cross-fade + on-demand SFX loading.
# Never preload all SFX at startup. Never call AudioStreamPlayer directly from scenes.

@export var bgm_fade_duration: float = 0.8
@export var sfx_cache_size: int = 32    # max concurrent cached SFX resources

const SFX_PATHS: Dictionary = {
	"shop_reroll":      "res://assets/audio/sfx/sfx_shop_reroll.ogg",
	"synergy_link":     "res://assets/audio/sfx/sfx_synergy_link.ogg",
	"grid_snap":        "res://assets/audio/sfx/sfx_grid_snap.ogg",
	"item_drag":        "res://assets/audio/sfx/sfx_item_drag.ogg",
	"melee_strike":     "res://assets/audio/sfx/sfx_melee_strike.ogg",
	"ranged_strike":    "res://assets/audio/sfx/sfx_ranged_strike.ogg",
	"arcane_strike":    "res://assets/audio/sfx/sfx_arcane_strike.ogg",
	"crit_hit":         "res://assets/audio/sfx/sfx_crit_hit.ogg",
	"shield_absorb":    "res://assets/audio/sfx/sfx_shield_absorb.ogg",
	"hp_loss":          "res://assets/audio/sfx/sfx_hp_loss.ogg",
	"fatal_hp_loss":    "res://assets/audio/sfx/sfx_fatal_hp_loss.ogg",
	"triple_merge":     "res://assets/audio/sfx/sfx_triple_merge.ogg",
	"win_round":        "res://assets/audio/sfx/sfx_win_round.ogg",
	"triumph_milestone":"res://assets/audio/sfx/sfx_triumph_milestone.ogg",
}

const BGM_PREP:   String = "res://assets/audio/bgm/bgm_prep.ogg"
const BGM_COMBAT: String = "res://assets/audio/bgm/bgm_combat.ogg"

var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _active_bgm: AudioStreamPlayer
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	_bgm_a = AudioStreamPlayer.new()
	_bgm_b = AudioStreamPlayer.new()
	_bgm_a.bus = "BGM"
	_bgm_b.bus = "BGM"
	add_child(_bgm_a)
	add_child(_bgm_b)
	_active_bgm = _bgm_a

func play_prep_bgm() -> void:
	_crossfade_bgm(BGM_PREP)

func play_combat_bgm() -> void:
	_crossfade_bgm(BGM_COMBAT)

func stop_bgm() -> void:
	var tw := create_tween()
	tw.tween_property(_active_bgm, "volume_db", -80.0, bgm_fade_duration)
	await tw.finished
	_active_bgm.stop()

# -- SFX public interface (one method per juice_manual.md event) --

func play_shop_reroll() -> void:             _play_sfx("shop_reroll")
func play_synergy_link() -> void:            _play_sfx("synergy_link")
func play_grid_snap() -> void:               _play_sfx("grid_snap")
func play_item_drag() -> void:               _play_sfx("item_drag")
func play_melee_strike(pos: Vector2) -> void: _play_sfx_2d("melee_strike", pos)
func play_ranged_strike(pos: Vector2) -> void:_play_sfx_2d("ranged_strike", pos)
func play_arcane_strike(pos: Vector2) -> void:_play_sfx_2d("arcane_strike", pos)
func play_crit_hit(pos: Vector2) -> void:    _play_sfx_2d("crit_hit", pos)
func play_shield_absorb(pos: Vector2) -> void:_play_sfx_2d("shield_absorb", pos)
func play_hp_loss() -> void:                 _play_sfx("hp_loss")
func play_triple_merge() -> void:            _play_sfx("triple_merge")
func play_win_round() -> void:               _play_sfx("win_round")
func play_triumph_milestone() -> void:       _play_sfx("triumph_milestone")

func play_fatal_hp_loss() -> void:
	_play_sfx("fatal_hp_loss")
	# Apply LPF filter to BGM bus for 2s (juice contract section 5).
	var bus_idx := AudioServer.get_bus_index("BGM")
	var lpf := AudioEffectLowPassFilter.new()
	lpf.cutoff_hz = 800.0
	AudioServer.add_bus_effect(bus_idx, lpf)
	await get_tree().create_timer(2.0).timeout
	var effect_count := AudioServer.get_bus_effect_count(bus_idx)
	for i in range(effect_count - 1, -1, -1):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectLowPassFilter:
			AudioServer.remove_bus_effect(bus_idx, i)
			break

# -- Internal --

func _crossfade_bgm(path: String) -> void:
	var inactive := _bgm_b if _active_bgm == _bgm_a else _bgm_a
	var stream = _load_sfx_resource(path)
	if stream == null:
		return
	inactive.stream = stream
	inactive.volume_db = -80.0
	inactive.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_active_bgm, "volume_db", -80.0, bgm_fade_duration)
	tw.tween_property(inactive, "volume_db", 0.0, bgm_fade_duration)
	await tw.finished
	_active_bgm.stop()
	_active_bgm = inactive

func _play_sfx(key: String) -> void:
	var stream = _get_cached(key)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _play_sfx_2d(key: String, pos: Vector2) -> void:
	var stream = _get_cached(key)
	if stream == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.bus = "SFX"
	player.stream = stream
	player.global_position = pos
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _get_cached(key: String):
	if _sfx_cache.has(key):
		return _sfx_cache[key]
	_load_sfx_async(key)
	return null   # plays on next call once loaded

func _load_sfx_async(key: String) -> void:
	if not SFX_PATHS.has(key):
		return
	var path: String = SFX_PATHS[key]
	ResourceLoader.load_threaded_request(path)
	# Poll until loaded - check in _process or use a timer.
	_pending_loads[key] = path

var _pending_loads: Dictionary = {}

func _process(_delta: float) -> void:
	for key in _pending_loads.keys():
		var path: String = _pending_loads[key]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_sfx_cache[key] = ResourceLoader.load_threaded_get(path)
			_pending_loads.erase(key)
			# Evict oldest entry if cache is full.
			if _sfx_cache.size() > sfx_cache_size:
				_sfx_cache.erase(_sfx_cache.keys()[0])

func _load_sfx_resource(path: String):
	if ResourceLoader.exists(path):
		return load(path)
	return null
