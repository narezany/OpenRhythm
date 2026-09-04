class_name BackgroundFX
extends Node2D
## Animated shader background plus drifting dust, used on every screen.
## The palette is heavy black and blood red: the hue stays near zero.

var mat: ShaderMaterial
var hue := 0.985
var flash := 0.0
var beat_env := 0.0
var rect: ColorRect


func _init(with_particles := false) -> void:
	z_index = -100
	rect = ColorRect.new()
	rect.size = G.DESIGN * 1.25
	rect.position = -G.DESIGN * 0.125
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/bg.gdshader")
	rect.material = mat
	add_child(rect)
	mat.set_shader_parameter("res", rect.size)
	if with_particles:
		var p := CPUParticles2D.new()
		p.position = Vector2(G.DESIGN.x * 0.5, G.DESIGN.y + 20.0)
		p.amount = 40
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(G.DESIGN.x * 0.62, 10.0)
		p.direction = Vector2(0, -1)
		p.spread = 12.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 30.0
		p.initial_velocity_max = 90.0
		p.scale_amount_min = 1.5
		p.scale_amount_max = 4.0
		p.color = Color(1.0, 0.30, 0.22, 0.25)
		p.texture = G.part_tex
		add_child(p)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	hue = fposmod(0.985 + 0.03 * sin(t * 0.07), 1.0)
	flash = maxf(0.0, flash - delta * 2.6)
	beat_env = maxf(0.0, beat_env - delta * 4.5)
	mat.set_shader_parameter("i_time", Conductor.song_time if Conductor.playing else t)
	mat.set_shader_parameter("beat", beat_env)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("hue", hue)
