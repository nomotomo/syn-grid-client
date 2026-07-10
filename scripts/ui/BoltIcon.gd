class_name BoltIcon
extends Control

# Lightning-bolt glyph for the Play button (issue #79 scope item 4: "⚡ PLAY"
# per Figma). Hand-drawn filled polygon per the no-icon-asset-pipeline
# convention established by NavIcon.gd - a bolt's zigzag silhouette doesn't
# fit that script's regular-N-sided-polygon pattern, so it gets its own tiny
# script rather than overloading NavIcon's Shape enum with an irregular case.

@export var glyph_color: Color = Color.WHITE

func set_glyph_color(color: Color) -> void:
	glyph_color = color
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Normalized zigzag bolt silhouette (unit square), scaled to the rect.
	var pts := PackedVector2Array([
		Vector2(0.55, 0.0), Vector2(0.15, 0.55), Vector2(0.42, 0.55),
		Vector2(0.30, 1.0), Vector2(0.85, 0.40), Vector2(0.55, 0.40),
	])
	var scaled := PackedVector2Array()
	for p in pts:
		scaled.append(p * size)
	draw_colored_polygon(scaled, glyph_color)
