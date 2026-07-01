class_name CombatLogPlayer
extends Node
# Juice contract section 4: queues CombatLog events, emits one per tick_interval.
# 2-frame hit-stop on crit events. Used by CombatReplayScene.

signal event_played(event: Dictionary)
signal playback_finished(winner_id: String, attacker_hp: float, defender_hp: float)

@export var tick_interval: float = 0.10
@export var hitstop_frames: int = 2

var _queue: Array[Dictionary] = []
var _combat_log: Dictionary = {}
var _timer: Timer
var _paused: bool = false

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = tick_interval
	_timer.one_shot = false
	_timer.timeout.connect(_dequeue_next)
	add_child(_timer)

func load_log(combat_log: Dictionary) -> void:
	_combat_log = combat_log
	_queue = combat_log.get("events", []).duplicate(true)
	_paused = false
	_timer.start()

func stop() -> void:
	_timer.stop()
	_queue.clear()

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
		# Hit-stop: pause queue for hitstop_frames frames (juice contract).
		_timer.stop()
		for _i in hitstop_frames:
			await get_tree().process_frame
		_timer.start()
