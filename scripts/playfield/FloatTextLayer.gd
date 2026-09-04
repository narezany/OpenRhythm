class_name FloatTextLayer
extends Node2D
## Floating judgement labels (PERFECT/GREAT/...) in world coordinates.

var items: Array = []   # {pos, text, color, age, tilt}


func spawn(pos: Vector2, text: String, color: Color) -> void:
	items.append({
		"pos": pos, "text": text, "color": color, "age": 0.0,
		"tilt": randf_range(-0.07, 0.07),
	})


func _process(delta: float) -> void:
	for i in items:
		i.age += delta
	items = items.filter(func(i): return i.age < 0.45)
	if not items.is_empty():
		queue_redraw()


func _draw() -> void:
	for i in items:
		var t: float = i.age / 0.45
		var a: float = (1.0 - t * t) * 0.8
		var sc: float = 1.0 + 0.30 * (1.0 - clampf(i.age * 12.0, 0.0, 1.0))
		var p: Vector2 = i.pos + Vector2(0, -22.0 - 34.0 * t)
		var sz := 26
		if i.text.length() > 6:
			sz = 22
		var w := G.font_bold.get_string_size(i.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_set_transform(p, i.tilt, Vector2(sc, sc))
		draw_string_outline(G.font_bold, Vector2(-w / 2.0, 0), i.text,
			HORIZONTAL_ALIGNMENT_CENTER, w, sz, 4, Color(0, 0, 0, 0.45 * a))
		draw_string(G.font_bold, Vector2(-w / 2.0, 0), i.text,
			HORIZONTAL_ALIGNMENT_CENTER, w, sz, Color(i.color.r, i.color.g, i.color.b, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
