class_name ModeIcon
extends BaseButton
## One round mode button, drawn rather than drawn on.
##
## Everything here is strokes - arcs and polylines with antialiasing asked for
## explicitly - because a filled polygon in Godot's 2D renderer has hard edges
## and a diagonal one comes out as a staircase. A ring is an arc; a filled dot
## is an arc as wide as its own radius. It costs a little more thought at the
## drawing end and it means the icons are smooth at any size, on any screen,
## with no image to export at three resolutions.

var kind := "all"        # all | laser | saber
var chosen := false

var _glow := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	# hover comes up quickly and falls away slowly, the way the buttons do
	var want: float = 1.0 if (is_hovered() and not disabled) else 0.0
	var was := _glow
	_glow = move_toward(_glow, want, delta * (6.0 if want > 0.0 else 3.0))
	if not is_equal_approx(was, _glow):
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 2.0
	var col := G.C_PRIMARY
	if disabled:
		col = Color(0.42, 0.40, 0.43)
	elif chosen:
		col = G.C_GOLD
	col = col.lerp(Color.WHITE, _glow * 0.35)

	# plate: a filled disc drawn as an arc so its edge is smooth
	draw_arc(c, r * 0.5, 0.0, TAU, 48,
		Color(0.07, 0.015, 0.03, 0.92 if not disabled else 0.55), r, true)
	draw_arc(c, r, 0.0, TAU, 64,
		Color(col.r, col.g, col.b, 0.9 if chosen else 0.45 + _glow * 0.3),
		2.6 if chosen else 1.8, true)
	if chosen:
		draw_arc(c, r + 2.5, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.22), 5.0, true)

	var s := r * 0.62
	match kind:
		"all":
			_all(c, s, col)
		"laser":
			_laser(c, s, col)
		"saber":
			_saber(c, s, col)


## Every mode at once: three cubes, which is what the game is made of.
func _all(c: Vector2, s: float, col: Color) -> void:
	var d := s * 0.52
	for at in [Vector2(0.0, -0.62), Vector2(-0.62, 0.42), Vector2(0.62, 0.42)]:
		var p: Vector2 = c + at * s
		_square(p, d * 0.62, col, 2.0)


## A pointer with a beam coming out of it and a dot where it lands.
func _laser(c: Vector2, s: float, col: Color) -> void:
	var back: Vector2 = c + Vector2(-0.78, 0.66) * s
	var nose: Vector2 = c + Vector2(-0.12, 0.10) * s
	var tip: Vector2 = c + Vector2(0.74, -0.62) * s
	# the body: a short thick stroke with round ends
	draw_line(back, nose, col, s * 0.34, true)
	# the beam, thinner and brighter
	draw_line(nose, tip, Color(col.r, col.g, col.b, 0.85), s * 0.13, true)
	# and the dot it puts on the wall
	draw_arc(tip, s * 0.11, 0.0, TAU, 20, col, s * 0.22, true)


## A blade with a guard and a pommel, stood up steeper than the pointer so the
## two do not read as the same diagonal stroke at the size these are drawn.
func _saber(c: Vector2, s: float, col: Color) -> void:
	var hilt: Vector2 = c + Vector2(-0.42, 0.92) * s
	var guard: Vector2 = c + Vector2(-0.22, 0.44) * s
	var tip: Vector2 = c + Vector2(0.42, -0.92) * s
	# grip and pommel
	draw_line(hilt, guard, Color(col.r, col.g, col.b, 0.7), s * 0.24, true)
	draw_arc(hilt, s * 0.09, 0.0, TAU, 16, col, s * 0.18, true)
	# crossguard, wide enough to be seen
	var across := (tip - guard).normalized().orthogonal() * s * 0.46
	draw_line(guard - across, guard + across, col, s * 0.15, true)
	# the blade, tapering to a point in three strokes - a filled triangle would
	# come out of the renderer with a staircase down its edge
	var steps := 3
	for i in steps:
		var a: float = float(i) / float(steps)
		var b: float = float(i + 1) / float(steps)
		draw_line(guard.lerp(tip, a), guard.lerp(tip, b), col,
			s * lerpf(0.26, 0.08, (a + b) * 0.5), true)


func _square(at: Vector2, half: float, col: Color, w: float) -> void:
	var p := PackedVector2Array([
		at + Vector2(-half, -half), at + Vector2(half, -half),
		at + Vector2(half, half), at + Vector2(-half, half),
		at + Vector2(-half, -half)])
	draw_polyline(p, col, w, true)
