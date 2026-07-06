class_name GridCell
extends PanelContainer

# One slot in the 4x4 placement grid. Holds at most one ItemCard child -
# reparenting a card in/out is all GridPrepScene needs to "snap" it, since
# PanelContainer's single-child fill behavior sizes/positions it automatically.
# Adjoining cells' borders coincide at zero separation, giving the tech-grid
# hairline look for free with no separate drawing code.

@export var pulse_period: float = 0.5
@export var pulse_brightness: float = 1.45

var grid_x: int = 0
var grid_y: int = 0

var _pulse_tween: Tween = null

func _ready() -> void:
	highlight(false)

func setup(x: int, y: int, cell_size: Vector2) -> void:
	grid_x = x
	grid_y = y
	custom_minimum_size = cell_size

func has_card() -> bool:
	return get_child_count() > 0

func get_card() -> ItemCard:
	if has_card():
		return get_child(0) as ItemCard
	return null

func highlight(on: bool) -> void:
	var border_color := SynGridPalette.BORDER_ACTIVE if on else SynGridPalette.BORDER_DIM
	add_theme_stylebox_override(
		"panel", ThemeBuilder.build_panel_style(
			border_color, SynGridPalette.PANEL_BG_ELEVATED, 0, true)
	)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if on:
		# Breathing brightness pulse on the active drop target. self_modulate
		# only touches this panel's own drawing, not a held card.
		var bright := Color(pulse_brightness, pulse_brightness, pulse_brightness)
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(self, "self_modulate", bright, pulse_period / 2.0) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(self, "self_modulate", Color.WHITE, pulse_period / 2.0) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	else:
		self_modulate = Color.WHITE
