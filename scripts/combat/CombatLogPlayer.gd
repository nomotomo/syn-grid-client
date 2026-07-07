class_name CombatLogPlayer
extends Node
# Juice contract section 4: queues CombatLog events, emits one per tick_interval.
# 2-frame hit-stop on crit events. Used by CombatReplayScene.

signal event_played(event: Dictionary)
signal playback_finished(winner_id: String, attacker_hp: float, defender_hp: float)

@export var tick_interval: float = 0.10
@export var hitstop_frames: int = 2
# Contract section 4: 10 events/s normally, 5 events/s during crits so the
# hit-stop registers. The gap after a crit event is tick_interval * this.
@export var crit_tick_multiplier: float = 2.0
@export var slow_event_interval: float = 0.25

var _queue: Array[Dictionary] = []
var _combat_log: Dictionary = {}
var _timer: Timer
var _paused: bool = false
var _slow_next_pending: bool = false

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = tick_interval
	_timer.one_shot = false
	_timer.timeout.connect(_dequeue_next)
	add_child(_timer)

func load_log(combat_log: Dictionary) -> void:
	_combat_log = combat_log
	# JSON gives an untyped Array; assign() copies it into the typed queue
	# (direct assignment to Array[Dictionary] raises at runtime).
	_queue.assign((combat_log.get("events", []) as Array).duplicate(true))
	_paused = false
	_timer.start()

func stop() -> void:
	_timer.stop()
	_queue.clear()

func remaining_count() -> int:
	return _queue.size()

func slow_next_event() -> void:
	_slow_next_pending = true

func _dequeue_next() -> void:
	if _queue.is_empty():
		_timer.stop()
		playback_finished.emit(
			_combat_log.get("winner_id", ""),
			_combat_log.get("attacker_hp_final", 0.0),
			_combat_log.get("defender_hp_final", 0.0)
		)
		return
	var ev: Dictionary = _queue.pop_front()
	event_played.emit(ev)
	if ev.get("crit", false):
		# Hit-stop: pause queue for hitstop_frames frames (juice contract),
		# then leave a double-length gap before the next event.
		_timer.stop()
		for _i in hitstop_frames:
			await get_tree().process_frame
		_timer.start(tick_interval * crit_tick_multiplier)
	elif not is_equal_approx(_timer.wait_time, tick_interval):
		# Restore the normal cadence after a crit-stretched gap.
		_timer.start(tick_interval)
	if _slow_next_pending:
		_timer.start(slow_event_interval)
		_slow_next_pending = false
