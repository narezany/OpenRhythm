class_name FloatTextLayer
extends Node2D
## Floating judgement labels (PERFECT/GREAT/...) in world coordinates, and the
## captions a map puts up from its own event list.
##
## They are the same thing at different settings: a rank pops for half a second
## and floats away, while a map's caption can stand where it was put, at the
## size it asked for, for as long as it says. One layer, two sets of numbers.

var items: Array = []   # {id, pos, text, color, age, tilt}
## Every label gets a number so a mirror of this layer can tell which ones it
## has already seen. In VR the ranks are put up in the room as real 3D labels
## rather than printed on the screen hanging behind it, and that reader has no
## other way to spot a new one.
var _next_id := 0


## draw_string does not auto-translate, so the label is translated on the way
## in. The suffix is appended afterwards and left alone - it is a number.
func spawn(pos: Vector2, text: String, color: Color, suffix := "",
		size := 0, life := 0.45, rise := 34.0) -> void:
	text = tr(text) + suffix
	_next_id += 1
	items.append({
		"id": _next_id, "size": size, "life": maxf(life, 0.05), "rise": rise,
		"pos": pos, "text": text, "color": color, "age": 0.0,
		"tilt": randf_range(-0.07, 0.07) if rise > 0.0 else 0.0,
	})


func _process(delta: float) -> void:
	for i in items:
		i.age += delta
	items = items.filter(func(i): return i.age < float(i.get("life", 0.45)))
	if not items.is_empty():
		queue_redraw()


func _draw() -> void:
	for i in items:
		var life: float = float(i.get("life", 0.45))
		var t: float = i.age / life
		# a rank fades from the moment it lands; a caption that is meant to be
		# read stands at full strength and goes at the end of its time
		var a: float = (1.0 - t * t) * 0.8 if life <= 0.6 \
			else clampf(minf(i.age * 5.0, (1.0 - t) * 5.0), 0.0, 1.0) * 0.92
		var sc: float = 1.0 + 0.30 * (1.0 - clampf(i.age * 12.0, 0.0, 1.0))
		var rise: float = float(i.get("rise", 34.0))
		var p: Vector2 = i.pos
		if rise > 0.0:
			p += Vector2(0, -22.0 - rise * t)
		var sz := int(i.get("size", 0))
		if sz <= 0:
			sz = 26
			if i.text.length() > 6:
				sz = 22
		var w := G.font_bold.get_string_size(i.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_set_transform(p, i.tilt, Vector2(sc, sc))
		draw_string_outline(G.font_bold, Vector2(-w / 2.0, 0), i.text,
			HORIZONTAL_ALIGNMENT_CENTER, w, sz, 4, Color(0, 0, 0, 0.45 * a))
		draw_string(G.font_bold, Vector2(-w / 2.0, 0), i.text,
			HORIZONTAL_ALIGNMENT_CENTER, w, sz, Color(i.color.r, i.color.g, i.color.b, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
