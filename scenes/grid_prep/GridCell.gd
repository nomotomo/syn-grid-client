class_name GridCell
extends PanelContainer

# One slot in the deployment grid. The anchor cell for a multi-cell item parents
# the ItemCard (sized to span its footprint); every cell in the footprint is
# marked occupied via set_occupied() so drop targeting treats the whole rect as
# full. PanelContainer single-child fill sizes the anchor card; overflow covers
# adjoining cells visually.
#
# Neon Grimoire additions:
#   * Empty cells render a faint "+" glyph at 10% opacity so the socket reads
#     as "ready to receive" even before a drag starts.
#   * highlight() accepts a `valid: bool`. Valid hover pulses teal; invalid
#     hover pulses DANGER crimson so the player never wastes a drop attempt.

@export var pulse_period: float = 0.5
@export var pulse_brightness: float = 1.45
@export var empty_glyph_alpha: float = 0.18
@export var empty_glyph_font_size: int = 40

var grid_x: int = 0
var grid_y: int = 0
var occupied: bool = false

var _pulse_tween: Tween = null
var _empty_glyph: Label = null

func _ready() -> void:
	_empty_glyph = Label.new()
	_empty_glyph.text = "+"
	_empty_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_glyph.add_theme_font_size_override("font_size", empty_glyph_font_size)
	_empty_glyph.add_theme_color_override("font_color",
		Color(SynGridPalette.ACCENT_TEAL, empty_glyph_alpha))
	_empty_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Label draws on top of the panel's background stylebox but below any
	# ItemCard added later (children added later draw on top). Do NOT set
	# show_behind_parent - that would put the label behind the panel bg and
	# hide it entirely.
	add_child(_empty_glyph)
	child_entered_tree.connect(_on_child_changed)
	child_exiting_tree.connect(_on_child_changed)
	_refresh_empty_glyph()
	highlight(false)

func setup(x: int, y: int, cell_size: Vector2) -> void:
	grid_x = x
	grid_y = y
	custom_minimum_size = cell_size

func set_occupied(on: bool) -> void:
	occupied = on
	_refresh_empty_glyph()

func is_free() -> bool:
	return not occupied

func has_card() -> bool:
	# The empty-plus glyph is a Label child, so count only ItemCard descendants.
	for c in get_children():
		if c is ItemCard:
			return true
	return false

func get_card() -> ItemCard:
	for c in get_children():
		if c is ItemCard:
			return c
	return null

# `on`    - whether this cell is the drag hover target
# `valid` - whether a drop here would be accepted. Invalid hover flashes
#           the DANGER border colour so the player never releases into a bad slot.
func highlight(on: bool, valid: bool = true) -> void:
	var border_color: Color
	if on:
		border_color = SynGridPalette.BORDER_ACTIVE if valid else SynGridPalette.DANGER
	else:
		border_color = SynGridPalette.BORDER_DIM
	add_theme_stylebox_override(
		"panel", ThemeBuilder.build_panel_style(
			border_color, SynGridPalette.PANEL_BG_ELEVATED, 0, true)
	)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if on:
		# Breathing brightness pulse on the active drop target. self_modulate
		# only touches this panel's own drawing, not a held card. Invalid
		# targets pulse faster + toward a red-tinted brightness so the
		# feedback registers as "reject".
		var bright: Color
		if valid:
			bright = Color(pulse_brightness, pulse_brightness, pulse_brightness)
		else:
			# Warm the pulse toward danger crimson for invalid targets.
			bright = Color(pulse_brightness * 1.15, pulse_brightness * 0.55,
				pulse_brightness * 0.55)
		var period := pulse_period if valid else pulse_period * 0.6
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(self, "self_modulate", bright, period / 2.0) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(self, "self_modulate", Color.WHITE, period / 2.0) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	else:
		self_modulate = Color.WHITE

func _on_child_changed(_node: Node) -> void:
	# Deferred so has_card() sees the final child list, not the mid-transition one.
	call_deferred("_refresh_empty_glyph")

func _refresh_empty_glyph() -> void:
	if _empty_glyph == null:
		return
	_empty_glyph.visible = is_free()
