class_name FrameView
extends Node2D
## The big square frame that bounds play. Pulses on the beat and lights the 3x3 grid.

var accent := Color("ff2b3a")
var pulse := 0.0
var hit_glow := 0.0
var grid_alpha := 0.05


func _process(delta: float) -> void:
	pulse = maxf(0.0, pulse - delta * 5.0)
	hit_glow = maxf(0.0, hit_glow - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var R := G.FRAME_HALF
	draw_rect(Rect2(-R, -R, R * 2.0, R * 2.0), Color(0.030, 0.006, 0.010, 0.60))
	# 3x3 grid: cell outlines
	if grid_alpha > 0.0:
		for gy in 3:
			for gx in 3:
				var c := Vector2((gx - 1) * G.CELL, (gy - 1) * G.CELL)
				var gp := G.rounded_points(Rect2(c - Vector2(70, 70), Vector2(140, 140)), 10.0)
				gp.append(gp[0])
				draw_polyline(gp, Color(1.0, 0.55, 0.5, grid_alpha), 1.4, true)
	var pts := G.rounded_points(Rect2(-R, -R, R * 2.0, R * 2.0), 26.0)
	var closed := pts.duplicate()
	closed.append(pts[0])
	var ac := accent
	if hit_glow > 0.0:
		ac = ac.lerp(Color.WHITE, hit_glow * 0.7)
	for cfg in [[18.0, 0.05], [10.0, 0.11], [4.0, 0.34]]:
		draw_polyline(closed, Color(ac.r, ac.g, ac.b, cfg[1] + hit_glow * 0.12), cfg[0], true)
	draw_polyline(closed, Color(1.0, 0.92, 0.90, 0.85), 1.8, true)
