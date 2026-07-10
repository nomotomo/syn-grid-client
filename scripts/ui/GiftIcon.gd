class_name GiftIcon
extends Control

# Daily-reward tile glyph (issue #79 follow-up: Figma shows a 🎁 emoji, the
# pixel font this project uses has no emoji glyphs, so this hand-draws a
# simple gift-box silhouette per the NavIcon.gd convention).

@export var glyph_color: Color = Color.WHITE

func set_glyph_color(color: Color) -> void:
	glyph_color = color
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var box_top := size.y * 0.42
	var lid_top := size.y * 0.28
	# Box body.
	draw_rect(Rect2(Vector2(size.x * 0.08, box_top), Vector2(size.x * 0.84, size.y * 0.58)), glyph_color, false, 2.0)
	# Lid, slightly wider than the body.
	draw_rect(Rect2(Vector2(size.x * 0.02, lid_top), Vector2(size.x * 0.96, size.y * 0.14)), glyph_color, false, 2.0)
	# Vertical ribbon.
	draw_line(Vector2(size.x * 0.5, lid_top), Vector2(size.x * 0.5, size.y), glyph_color, 2.0, true)
	# Bow (two small triangles above the lid).
	var mid := size.x * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid, lid_top), Vector2(size.x * 0.28, 0.0), Vector2(size.x * 0.42, lid_top),
	]), glyph_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid, lid_top), Vector2(size.x * 0.72, 0.0), Vector2(size.x * 0.58, lid_top),
	]), glyph_color)
