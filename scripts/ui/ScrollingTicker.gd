class_name ScrollingTicker
extends Panel

# Continuously-scrolling patch-notes strip (issue #79 scope item 3, Figma's
# ticker between the Daily/Codex row and the rune-field). Godot's UI toolkit
# has no marquee widget, so this hand-rolls one: a single Label holding the
# joined items duplicated once (so the loop has no visible seam) scrolls
# left every frame, wrapping after it has moved exactly one copy's width.

@export var items: Array[String] = []
@export var separator: String = "   •   "
@export var scroll_speed: float = 40.0  # px/sec

@onready var _label: Label = Label.new()

var _loop_width: float = 0.0

func _ready() -> void:
	clip_contents = true
	add_child(_label)
	_label.theme_type_variation = &"CaptionLabel"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resized.connect(_rebuild_text)
	_rebuild_text()

func set_items(new_items: Array[String]) -> void:
	items = new_items
	_rebuild_text()

func _rebuild_text() -> void:
	if items.is_empty():
		return
	var joined := separator.join(items)
	_label.text = joined + separator + joined
	await get_tree().process_frame
	_loop_width = _label.get_minimum_size().x / 2.0
	_label.position = Vector2.ZERO

func _process(delta: float) -> void:
	if _loop_width <= 0.0:
		return
	_label.position.x -= scroll_speed * delta
	if _label.position.x <= -_loop_width:
		_label.position.x += _loop_width
	_label.position.y = (size.y - _label.get_minimum_size().y) / 2.0
