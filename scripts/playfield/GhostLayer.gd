class_name GhostLayer
extends Node2D
## Red targets on the grid showing where a note will land and where to aim.
## progress < 0 marks a guide: a future target highlighted early.

var items: Array = []   # dict: hit, half, progress, color, done, hover, node


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var tms := Time.get_ticks_msec() / 1000.0
	for n in items:
		if n.done:
			continue
		var a: float
		var pr: float = n.progress
		if pr < 0.0:
			# a future target is a faint pulsing outline
			a = 0.09 + 0.07 * (0.5 + 0.5 * sin(tms * 5.0))
		else:
			a = clampf(pr * 1.8, 0.0, 1.0)
			a = 0.12 + 0.32 * a + (0.30 if n.hover else 0.0)
		var half: float = n.half * 1.02
		var col: Color = n.get("gcol", n.get("color", Color.WHITE))
		draw_set_transform_matrix(Transform2D(0.0, n.hit))
		var pts := G.rounded_points(Rect2(-half, -half, half * 2.0, half * 2.0), 8.0)
		pts.append(pts[0])
		draw_polyline(pts, Color(col.r, col.g, col.b, a), 2.0, true)
		if pr >= 0.0 and n.hover:
			draw_colored_polygon(G.rounded_points(Rect2(-half, -half, half * 2, half * 2), 8.0),
				Color(col.r, col.g, col.b, 0.10))
		draw_set_transform_matrix(Transform2D())
		# line from the note to its target
		if pr > 0.0 and pr < 1.0:
			var from: Vector2 = n.hit
			var nn = n.get("node")
			if nn != null and is_instance_valid(nn):
				from = nn.position
			draw_line(from, n.hit, Color(col.r, col.g, col.b, 0.14), 1.5, true)
