class_name ShockLayer
extends Node2D
## Кольца-шоквейвы и партикльные бёрсты.

var rings: Array = []   # {pos, color, age, max_r}


func ring(pos: Vector2, color: Color, max_r := 120.0) -> void:
	rings.append({"pos": pos, "color": color, "age": 0.0, "max_r": max_r})


func burst(pos: Vector2, color: Color, count := 20, speed := 300.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = maxi(count, 4)
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, 480)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.texture = G.part_tex
	var c := color
	c.a = 0.85
	p.color = c
	p.material = G.mat_add
	add_child(p)
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)


func _process(delta: float) -> void:
	for r in rings:
		r.age += delta
	rings = rings.filter(func(r): return r.age < 0.4)
	if not rings.is_empty():
		queue_redraw()


func _draw() -> void:
	for r in rings:
		var t: float = r.age / 0.4
		var e := 1.0 - pow(1.0 - t, 3.0)
		var rad: float = 12.0 + r.max_r * e
		var a: float = (1.0 - t) * 0.85
		draw_arc(r.pos, rad, 0, TAU, 40, Color(r.color.r, r.color.g, r.color.b, a),
			3.0 + 3.0 * (1.0 - t), true)
		draw_arc(r.pos, rad * 0.62, 0, TAU, 32, Color(1, 1, 1, a * 0.5), 1.6, true)
