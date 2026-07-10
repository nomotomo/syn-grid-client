class_name GearIcon
extends Control

# Top-bar Settings-button glyph (issue #79 scope item 1: "gear icon").
# Hand-drawn per the same no-icon-asset-pipeline convention as NavIcon.gd -
# a circle with radial teeth reads as "gear" at small sizes without a
# sourced icon font/texture.

@export var glyph_color: Color = Color.WHITE
@export var line_width: float = 2.0
@export var tooth_count: int = 8

func set_glyph_color(color: Color) -> void:
	glyph_color = color
	queue_redraw()

func _draw() -> void:
	var outer: float = min(size.x, size.y) * 0.5
	if outer <= 0.0:
		return
	var inner: float = outer * 0.58
	var tooth_outer: float = outer * 0.95
	var tooth_half_width: float = (TAU / float(tooth_count)) * 0.28
	var center: Vector2 = size * 0.5
	# Filled trapezoidal teeth read as a solid cog rather than thin radial
	# spikes (which looked more like a sun/starburst than a gear at 20px).
	for i in tooth_count:
		var mid: float = i * TAU / float(tooth_count)
		var a0: float = mid - tooth_half_width
		var a1: float = mid + tooth_half_width
		var pts := PackedVector2Array([
			center + Vector2(cos(a0), sin(a0)) * inner,
			center + Vector2(cos(a0), sin(a0)) * tooth_outer,
			center + Vector2(cos(a1), sin(a1)) * tooth_outer,
			center + Vector2(cos(a1), sin(a1)) * inner,
		])
		draw_colored_polygon(pts, glyph_color)
	draw_circle(center, inner, glyph_color)
	# Punch the center hole by drawing the background back over it - Godot's
	# 2D draw API has no boolean subtract, so an inner circle in the panel's
	# own background color fakes the cog's hollow center. Caller must ensure
	# whatever sits behind this icon matches PANEL_BG_ELEVATED (the button's
	# own fill), which SettingsButton already does.
	draw_circle(center, inner * 0.4, SynGridPalette.PANEL_BG_ELEVATED)
