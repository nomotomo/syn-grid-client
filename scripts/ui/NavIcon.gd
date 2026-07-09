class_name NavIcon
extends Control

# Bottom-nav tab glyph (issue #68 scope item 3: "hexagon/diamond/triangle/
# circle motif per Figma"). Hand-drawn as a polygon outline rather than a
# texture/icon-font asset - no icon sourcing pipeline exists yet in this repo
# (docs/design-tokens-neon-grimoire.md explicitly punts icon style to the
# Figma reference, which is login-gated and wasn't accessible to derive exact
# pixel geometry from). The shape/color match the motif named in the issue;
# swap for real icon art if/when one is sourced.

enum Shape { HEXAGON, DIAMOND, TRIANGLE, CIRCLE }

@export var shape: Shape = Shape.CIRCLE
@export var glyph_color: Color = Color.WHITE
@export var line_width: float = 2.0

const _SIDES_FOR_SHAPE: Dictionary = {
        Shape.HEXAGON: 6,
        Shape.DIAMOND: 4,
        Shape.TRIANGLE: 3,
        Shape.CIRCLE: 24,
}

func set_glyph_color(color: Color) -> void:
        glyph_color = color
        queue_redraw()

func _draw() -> void:
        var radius: float = min(size.x, size.y) * 0.5 - line_width
        if radius <= 0.0:
                return
        var center: Vector2 = size * 0.5
        var sides: int = _SIDES_FOR_SHAPE.get(shape, 24)
        # Point-up orientation for the triangle/diamond/hexagon; circle's
        # start angle is irrelevant at 24 sides.
        var start_angle: float = -PI / 2.0
        var points := PackedVector2Array()
        for i in sides:
                var angle: float = start_angle + i * TAU / sides
                points.append(center + Vector2(cos(angle), sin(angle)) * radius)
        points.append(points[0])
        draw_polyline(points, glyph_color, line_width, true)
