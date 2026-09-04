class_name AchievementIcon
extends Control
## Badge art for achievements. The shapes are drawn in code - no image assets,
## so a badge scales cleanly and recolours itself for the locked state.

var kind := "star"
var tint := Color(1, 1, 1)
var locked := false


func _init(kind_ := "star", size_ := 44.0) -> void:
	kind = kind_
	custom_minimum_size = Vector2(size_, size_)
	size = Vector2(size_, size_)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var col: Color = tint if not locked else Color(0.45, 0.42, 0.44)
	var dim := Color(col.r, col.g, col.b, 0.16)
	# badge plate
	draw_circle(c, r * 0.96, Color(0.08, 0.02, 0.035, 0.9 if not locked else 0.5))
	draw_arc(c, r * 0.92, 0, TAU, 40, Color(col.r, col.g, col.b, 0.55), 2.0, true)
	draw_circle(c, r * 0.80, dim)
	_shape(kind, c, r * 0.56, col)


func _shape(k: String, c: Vector2, s: float, col: Color) -> void:
	match k:
		"star":
			_star(c, s, 5, 0.45, col)
		"crown":
			var pts := PackedVector2Array([
				c + Vector2(-s, s * 0.55), c + Vector2(-s, -s * 0.5),
				c + Vector2(-s * 0.45, s * 0.02), c + Vector2(0, -s * 0.75),
				c + Vector2(s * 0.45, s * 0.02), c + Vector2(s, -s * 0.5),
				c + Vector2(s, s * 0.55)])
			draw_colored_polygon(pts, col)
		"note":
			draw_circle(c + Vector2(-s * 0.35, s * 0.55), s * 0.34, col)
			draw_rect(Rect2(c.x + -s * 0.05, c.y - s * 0.8, s * 0.16, s * 1.4), col)
			draw_rect(Rect2(c.x + -s * 0.05, c.y - s * 0.8, s * 0.85, s * 0.22), col)
		"bolt":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(s * 0.15, -s), c + Vector2(-s * 0.55, s * 0.12),
				c + Vector2(-s * 0.05, s * 0.12), c + Vector2(-s * 0.2, s),
				c + Vector2(s * 0.55, -s * 0.16), c + Vector2(s * 0.02, -s * 0.16)]), col)
		"heart":
			draw_circle(c + Vector2(-s * 0.36, -s * 0.22), s * 0.44, col)
			draw_circle(c + Vector2(s * 0.36, -s * 0.22), s * 0.44, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.78, -s * 0.06), c + Vector2(s * 0.78, -s * 0.06),
				c + Vector2(0, s * 0.9)]), col)
		"cube":
			var q := s * 0.72
			G.draw_rounded_rect(self, Rect2(c.x - q, c.y - q, q * 2, q * 2), q * 0.28, col)
			G.draw_rounded_outline(self, Rect2(c.x - q, c.y - q, q * 2, q * 2),
				q * 0.28, Color(0, 0, 0, 0.45), 2.0)
		"skull":
			draw_circle(c + Vector2(0, -s * 0.15), s * 0.75, col)
			draw_rect(Rect2(c.x - s * 0.34, c.y + s * 0.35, s * 0.68, s * 0.46), col)
			draw_circle(c + Vector2(-s * 0.3, -s * 0.2), s * 0.2, Color(0.05, 0.01, 0.02))
			draw_circle(c + Vector2(s * 0.3, -s * 0.2), s * 0.2, Color(0.05, 0.01, 0.02))
		"eye":
			draw_arc(c, s * 0.85, PI * 0.15, PI * 0.85, 24, col, 2.6, true)
			draw_arc(c, s * 0.85, PI * 1.15, PI * 1.85, 24, col, 2.6, true)
			draw_circle(c, s * 0.3, col)
		"flame":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s * 0.62, -s * 0.05),
				c + Vector2(s * 0.4, s * 0.85), c + Vector2(-s * 0.4, s * 0.85),
				c + Vector2(-s * 0.62, -s * 0.05)]), col)
			draw_circle(c + Vector2(0, s * 0.3), s * 0.34, Color(1, 1, 1, 0.55))
		"clock":
			draw_arc(c, s * 0.82, 0, TAU, 32, col, 2.6, true)
			draw_line(c, c + Vector2(0, -s * 0.55), col, 2.4)
			draw_line(c, c + Vector2(s * 0.42, 0), col, 2.4)
		"palette":
			draw_circle(c, s * 0.85, col)
			draw_circle(c + Vector2(s * 0.3, s * 0.28), s * 0.26, Color(0.05, 0.01, 0.02))
			for i in 4:
				var a := PI * (0.85 + i * 0.28)
				draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.5, s * 0.15,
					Color.from_hsv(fposmod(0.02 + i * 0.16, 1.0), 0.75, 1.0))
		"grid":
			for i in 3:
				for j in 3:
					var p := c + Vector2(float(i - 1), float(j - 1)) * s * 0.62
					draw_rect(Rect2(p.x - s * 0.2, p.y - s * 0.2, s * 0.4, s * 0.4),
						col if (i + j) % 2 == 0 else Color(col.r, col.g, col.b, 0.4))
		"box":
			draw_rect(Rect2(c.x - s * 0.8, c.y - s * 0.45, s * 1.6, s * 1.1), col)
			draw_rect(Rect2(c.x - s * 0.8, c.y - s * 0.8, s * 1.6, s * 0.4),
				Color(col.r, col.g, col.b, 0.62))
			draw_rect(Rect2(c.x - s * 0.12, c.y - s * 0.8, s * 0.24, s * 1.5),
				Color(0.05, 0.01, 0.02, 0.8))
		"disc":
			draw_circle(c, s * 0.9, col)
			draw_circle(c, s * 0.3, Color(0.05, 0.01, 0.02))
			draw_arc(c, s * 0.62, 0.4, 2.4, 20, Color(1, 1, 1, 0.45), 2.0, true)
		"moon":
			draw_circle(c, s * 0.85, col)
			draw_circle(c + Vector2(s * 0.4, -s * 0.24), s * 0.72, Color(0.06, 0.015, 0.03))
		"mirror":
			draw_line(c + Vector2(0, -s), c + Vector2(0, s), Color(1, 1, 1, 0.6), 2.0)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.15, -s * 0.6), c + Vector2(-s * 0.85, 0),
				c + Vector2(-s * 0.15, s * 0.6)]), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(s * 0.15, -s * 0.6), c + Vector2(s * 0.85, 0),
				c + Vector2(s * 0.15, s * 0.6)]), Color(col.r, col.g, col.b, 0.45))
		"turtle":
			draw_circle(c, s * 0.72, col)
			draw_circle(c + Vector2(s * 0.78, -s * 0.3), s * 0.26, col)
			for i in 3:
				draw_arc(c, s * 0.3 + i * s * 0.2, 0, TAU, 20,
					Color(0.05, 0.01, 0.02, 0.5), 1.6, true)
		"globe":
			draw_arc(c, s * 0.85, 0, TAU, 32, col, 2.4, true)
			draw_arc(c, s * 0.85, 0, TAU, 32, Color(col.r, col.g, col.b, 0.5), 2.4, true)
			draw_line(c + Vector2(-s * 0.85, 0), c + Vector2(s * 0.85, 0), col, 2.0)
			for ring: float in [0.45, 0.85]:
				draw_arc(c, s * ring, -PI * 0.5, PI * 0.5, 16,
					Color(col.r, col.g, col.b, 0.7), 1.6, true)
				draw_arc(c, s * ring, PI * 0.5, PI * 1.5, 16,
					Color(col.r, col.g, col.b, 0.7), 1.6, true)
		"book":
			draw_rect(Rect2(c.x - s * 0.85, c.y - s * 0.7, s * 0.8, s * 1.4), col)
			draw_rect(Rect2(c.x + s * 0.05, c.y - s * 0.7, s * 0.8, s * 1.4),
				Color(col.r, col.g, col.b, 0.6))
			draw_line(c + Vector2(0, -s * 0.75), c + Vector2(0, s * 0.75),
				Color(0.05, 0.01, 0.02), 2.2)
		"ghost":
			draw_circle(c + Vector2(0, -s * 0.2), s * 0.75, col)
			draw_rect(Rect2(c.x - s * 0.75, c.y - s * 0.2, s * 1.5, s * 0.8), col)
			draw_circle(c + Vector2(-s * 0.28, -s * 0.3), s * 0.16, Color(0.05, 0.01, 0.02))
			draw_circle(c + Vector2(s * 0.28, -s * 0.3), s * 0.16, Color(0.05, 0.01, 0.02))
		_:
			_star(c, s, 5, 0.45, col)


func _star(c: Vector2, s: float, points: int, inner: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := -PI * 0.5 + PI * float(i) / float(points)
		var rr: float = s if i % 2 == 0 else s * inner
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
