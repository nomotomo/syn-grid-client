extends Node
# Juice contract section 5: BGM cross-fade + on-demand SFX loading.
# Never preload all SFX at startup. Never call AudioStreamPlayer directly from scenes.

@export var bgm_fade_duration: float = 0.8
@export var sfx_cache_size: int = 32    # max concurrent cached SFX resources

const SFX_PATHS: Dictionary = {
	"shop_reroll":      "res://assets/audio/sfx/sfx_shop_reroll.wav",
	"synergy_link":     "res://assets/audio/sfx/sfx_synergy_link.wav",
	"grid_snap":        "res://assets/audio/sfx/sfx_grid_snap.wav",
	"item_drag":        "res://assets/audio/sfx/sfx_item_drag.wav",
	"melee_strike":     "res://assets/audio/sfx/sfx_melee_strike.wav",
	"ranged_strike":    "res://assets/audio/sfx/sfx_ranged_strike.wav",
	"arcane_strike":    "res://assets/audio/sfx/sfx_arcane_strike.wav",
	"crit_hit":         "res://assets/audio/sfx/sfx_crit_hit.wav",
	"shield_absorb":    "res://assets/audio/sfx/sfx_shield_absorb.wav",
	"hp_loss":          "res://assets/audio/sfx/sfx_hp_loss.wav",
	"fatal_hp_loss":    "res://assets/audio/sfx/sfx_fatal_hp_loss.wav",
	"triple_merge":     "res://assets/audio/sfx/sfx_triple_merge.wav",
	"win_round":        "res://assets/audio/sfx/sfx_win_round.wav",
	"triumph_milestone":"res://assets/audio/sfx/sfx_triumph_milestone.wav",
}

const BGM_PREP:   String = "res://assets/audio/bgm/bgm_prep.wav"
const BGM_COMBAT: String = "res://assets/audio/bgm/bgm_combat.wav"

var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _active_bgm: AudioStreamPlayer
var _bgm_tween: Tween = null
var _current_bgm_path: String = ""
var _sfx_cache: Dictionary = {}
var _pending_loads: Dictionary = {}   # key -> path currently in threaded load
var _pending_plays: Array[Dictionary] = []  # plays requested before load finished

func _ready() -> void:
	# The project ships no default_bus_layout.tres (same no-hand-authored-
	# resources philosophy as ThemeBuilder), so create the buses here.
	_ensure_bus("BGM")
	_ensure_bus("SFX")
	_bgm_a = AudioStreamPlayer.new()
	_bgm_b = AudioStreamPlayer.new()
	_bgm_a.bus = "BGM"
	_bgm_b.bus = "BGM"
	add_child(_bgm_a)
	add_child(_bgm_b)
	_active_bgm = _bgm_a
	set_process(false)   # only polls while a threaded SFX load is pending

func play_prep_bgm() -> void:
	_crossfade_bgm(BGM_PREP)

func play_combat_bgm() -> void:
	_crossfade_bgm(BGM_COMBAT)

func stop_bgm() -> void:
	_current_bgm_path = ""
	_kill_bgm_tween()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_active_bgm, "volume_db", -80.0, bgm_fade_duration)
	await _bgm_tween.finished
	_active_bgm.stop()

# -- SFX public interface (one method per juice_manual.md event) --
# play_synergy_link takes a pitch scale so the chime can ascend per
# modifier_pct level (juice contract section 5 SFX matrix).

func play_shop_reroll() -> void:             _play_sfx("shop_reroll")
func play_synergy_link(pitch: float = 1.0) -> void: _play_sfx("synergy_link", pitch)
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

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _crossfade_bgm(path: String) -> void:
	if path == _current_bgm_path and _active_bgm.playing:
		return
	var stream := _load_bgm_stream(path)
	if stream == null:
		return
	_current_bgm_path = path
	var inactive := _bgm_b if _active_bgm == _bgm_a else _bgm_a
	var outgoing := _active_bgm
	_active_bgm = inactive
	inactive.stream = stream
	inactive.volume_db = -80.0
	inactive.play()
	_kill_bgm_tween()
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(outgoing, "volume_db", -80.0, bgm_fade_duration)
	_bgm_tween.tween_property(inactive, "volume_db", 0.0, bgm_fade_duration)
	_bgm_tween.chain().tween_callback(outgoing.stop)

func _kill_bgm_tween() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()

func _load_bgm_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	# Loop flags live in per-file import metadata; force them at runtime so
	# BGM loops seamlessly regardless of how the asset was imported.
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2   # 16-bit mono frames
	elif stream is AudioStreamMP3:
		stream.loop = true
	return stream

func _play_sfx(key: String, pitch: float = 1.0) -> void:
	var stream: AudioStream = _get_cached(key)
	if stream == null:
		# Threaded load in flight - remember the request and play on arrival
		# instead of silently dropping the first trigger of every sound.
		_pending_plays.append({"key": key, "pitch": pitch})
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _play_sfx_2d(key: String, pos: Vector2, pitch: float = 1.0) -> void:
	var stream: AudioStream = _get_cached(key)
	if stream == null:
		_pending_plays.append({"key": key, "pos": pos, "pitch": pitch})
		return
	var player := AudioStreamPlayer2D.new()
	player.bus = "SFX"
	player.stream = stream
	player.global_position = pos
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _get_cached(key: String) -> AudioStream:
	if _sfx_cache.has(key):
		return _sfx_cache[key]
	_load_sfx_async(key)
	return null

func _load_sfx_async(key: String) -> void:
	if _pending_loads.has(key) or not SFX_PATHS.has(key):
		return
	var path: String = SFX_PATHS[key]
	if ResourceLoader.load_threaded_request(path) != OK:
		return
	_pending_loads[key] = path
	set_process(true)

func _process(_delta: float) -> void:
	for key: String in _pending_loads.keys():
		var path: String = _pending_loads[key]
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_LOADED:
				_sfx_cache[key] = ResourceLoader.load_threaded_get(path)
				_pending_loads.erase(key)
				_flush_pending_plays(key)
				# Evict oldest entry if cache is full.
				if _sfx_cache.size() > sfx_cache_size:
					_sfx_cache.erase(_sfx_cache.keys()[0])
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_pending_loads.erase(key)
				_drop_pending_plays(key)
	if _pending_loads.is_empty():
		set_process(false)

func _flush_pending_plays(key: String) -> void:
	var due := _pending_plays.filter(func(p: Dictionary) -> bool: return p["key"] == key)
	_drop_pending_plays(key)
	for request: Dictionary in due:
		if request.has("pos"):
			_play_sfx_2d(key, request["pos"], request["pitch"])
		else:
			_play_sfx(key, request["pitch"])

func _drop_pending_plays(key: String) -> void:
	_pending_plays = _pending_plays.filter(func(p: Dictionary) -> bool: return p["key"] != key)
