class_name BookIcon
extends Control

# Codex tile glyph (issue #79 follow-up: Figma shows a 📖 emoji, no emoji
# glyphs available in this project's pixel font - hand-drawn open-book
# silhouette per the NavIcon.gd convention).

@export var glyph_color: Color = Color.WHITE

func set_glyph_color(color: Color) -> void:
	glyph_color = color
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var mid := size.x * 0.5
	var top := size.y * 0.15
	var bottom := size.y * 0.85
	# Left and right pages, outlined only (open-book silhouette).
	draw_polyline(PackedVector2Array([
		Vector2(size.x * 0.05, top + size.y * 0.05), Vector2(mid, top),
		Vector2(size.x * 0.95, top + size.y * 0.05),
	]), glyph_color, 2.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(size.x * 0.05, bottom - size.y * 0.05), Vector2(mid, bottom),
		Vector2(size.x * 0.95, bottom - size.y * 0.05),
	]), glyph_color, 2.0, true)
	draw_line(Vector2(size.x * 0.05, top + size.y * 0.05), Vector2(size.x * 0.05, bottom - size.y * 0.05), glyph_color, 2.0, true)
	draw_line(Vector2(size.x * 0.95, top + size.y * 0.05), Vector2(size.x * 0.95, bottom - size.y * 0.05), glyph_color, 2.0, true)
	draw_line(Vector2(mid, top), Vector2(mid, bottom), glyph_color, 2.0, true)
