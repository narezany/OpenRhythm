class_name NoteView
extends Node2D
## A flying white cube: pseudo-3D growth, a floor shadow, a soft halo.
## A hold note is drawn as the same cube with a receding body behind it that
## shrinks as the hold runs out, so a long cube reads as long.

var half := 55.0
var color := Color.WHITE
var progress := 0.0
var dead := false

# --- hold notes ---
var hold_total := 0.0        # length in seconds, 0 for a normal note
var hold_left := 1.0         # 1 at the start of the hold, 0 when it runs out
var hold_active := false     # cursor is inside the cell right now
var hold_started := false

## A click note has to be pressed, not just covered, so it is drawn as an
## ember cube ringed by a target.
var is_click := false

## Optional cube art from the song folder. Drawn in place of the cube face, so
## a map can bring its own look without touching the game.
var skin: Texture2D = null

var _halo: Node2D
var _t := 0.0


func _ready() -> void:
	_halo = HaloNode.new()
	_halo.note = self
	add_child(_halo)


func set_color(c: Color) -> void:
	color = c


func trail_emitting(v: bool) -> void:
	pass   # trail removed - it got in the way of reading the playfield


func _process(delta: float) -> void:
	if hold_total > 0.0 or is_click:
		_t += delta
		queue_redraw()


func die() -> void:
	if dead:
		return
	dead = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", scale * 1.35, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(queue_free)


func fade_out(dur := 0.3) -> void:
	if dead:
		return
	dead = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, dur)
	tw.tween_callback(queue_free)


func _draw() -> void:
	if hold_total > 0.0:
		_draw_hold_body()
	# floor shadow - a hint of depth
	if progress < 0.92:
		draw_set_transform(Vector2(0, half * 1.1 + 14.0), 0.0, Vector2(1.0, 0.30))
		draw_circle(Vector2.ZERO, half * 0.92, Color(0, 0, 0, 0.30 * (1.0 - progress)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var r := half
	var rect := Rect2(-r, -r, r * 2.0, r * 2.0)
	if skin != null:
		var tint := Color(1, 1, 1, 1)
		if hold_started:
			tint = Color(1.0, 0.86, 0.70) if hold_active else Color(0.70, 0.66, 0.68)
		draw_texture_rect(skin, rect, false, tint)
		if is_click:
			_draw_click_ring()
		if hold_started:
			_draw_hold_ring()
		return
	var face := Color(0.92, 0.90, 0.89, 1.0)
	var inner_col := Color(1.0, 0.99, 0.98, 1.0)
	if is_click:
		face = Color(1.0, 0.55, 0.28)
		inner_col = Color(1.0, 0.76, 0.52)
	if hold_started:
		# warm while held, cold while dropped, so the state is obvious
		face = Color(1.0, 0.86, 0.70) if hold_active else Color(0.70, 0.66, 0.68)
		inner_col = Color(1.0, 0.95, 0.86) if hold_active else Color(0.82, 0.78, 0.80)
	G.draw_rounded_rect(self, rect, r * 0.24, face)
	var inner := rect.grow(-r * 0.18)
	G.draw_rounded_rect(self, inner, r * 0.18, inner_col)
	G.draw_rounded_outline(self, rect, r * 0.24, Color(0.45, 0.18, 0.18, 0.9), 2.2)
	# red diamond glint in the middle - the theme accent
	var q := r * 0.30
	draw_polyline(PackedVector2Array([
		Vector2(0, -q), Vector2(q, 0), Vector2(0, q), Vector2(-q, 0), Vector2(0, -q)
	]), Color(0.88, 0.14, 0.16, 0.75), 2.2, true)
	if is_click:
		_draw_click_ring()
	if hold_started:
		_draw_hold_ring()


## The tail: nested squares receding behind the face. Their count follows the
## remaining hold length, so the cube visibly shortens as it is held.
func _draw_hold_body() -> void:
	var span := clampf(hold_left, 0.0, 1.0)
	if hold_started and span <= 0.001:
		return
	var depth := 1.0 + minf(hold_total, 3.0) * 0.9
	var layers := maxi(2, int(round(6.0 * span * depth / 3.0)) + 2)
	for i in range(layers, 0, -1):
		var k := float(i) / float(layers)
		var s := half * (1.0 + 0.20 * k * depth * span)
		var a := 0.28 * (1.0 - k * 0.75)
		if hold_started and not hold_active:
			a *= 0.45
		var rect := Rect2(-s, -s, s * 2.0, s * 2.0)
		G.draw_rounded_rect(self, rect, s * 0.24, Color(0.86, 0.84, 0.86, a))
		G.draw_rounded_outline(self, rect, s * 0.24, Color(1.0, 0.55, 0.45, a * 0.8), 1.6)


## Target ring that marks a cube you have to press.
func _draw_click_ring() -> void:
	var r := half * 1.28
	var pulse := 0.5 + 0.5 * sin(_t * 7.0)
	draw_arc(Vector2.ZERO, r, 0, TAU, 36,
		Color(1.0, 0.45, 0.22, 0.55 + 0.35 * pulse), 3.0, true)
	for i in 4:
		var a := PI * 0.25 + PI * 0.5 * float(i)
		var d := Vector2(cos(a), sin(a))
		draw_line(d * (r * 0.78), d * (r * 1.18),
			Color(1.0, 0.62, 0.35, 0.9), 2.4)


## Radial timer around a hold that is currently being held.
func _draw_hold_ring() -> void:
	var r := half * 1.5
	var frac := clampf(hold_left, 0.0, 1.0)
	var col := Color(1.0, 0.62, 0.30, 0.9) if hold_active else Color(0.7, 0.7, 0.75, 0.5)
	draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, col, 3.0, true)
	if hold_active:
		var pulse := 0.5 + 0.5 * sin(_t * 12.0)
		draw_arc(Vector2.ZERO, r + 4.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 32,
			Color(1.0, 0.8, 0.5, 0.25 * pulse), 2.0, true)


class HaloNode extends Node2D:
	var note: NoteView

	func _ready() -> void:
		material = G.mat_add

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if note == null or note.dead:
			return
		var s: float = note.half * 1.9
		var c: Color = note.color
		var warm := Color(1.0, minf(c.g + 0.35, 1.0), minf(c.b + 0.35, 1.0))
		var a := 0.12
		if note.hold_started and note.hold_active:
			a = 0.24
		draw_texture_rect(G.halo_tex, Rect2(-s, -s, s * 2.0, s * 2.0), false,
			Color(warm.r, warm.g, warm.b, a))
