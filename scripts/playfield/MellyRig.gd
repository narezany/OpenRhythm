class_name MellyRig
extends SubViewportContainer
## Melly - the GLB model (a skinned blocky figure, res://models/melly.glb)
## rendered in a SubViewport. Every animation is procedural: damped springs and
## sine breathing, with joint limits so body parts never intersect. Colouring is
## done on the CPU, per bone.

const PARTS := ["torso", "head", "arm_l", "arm_r", "leg_l", "leg_r"]
const PART_NAMES := {
	"torso": "TORSO", "head": "HEAD", "arm_l": "LEFT ARM", "arm_r": "RIGHT ARM",
	"leg_l": "LEFT LEG", "leg_r": "RIGHT LEG",
}
const BONE_PART := ["torso", "head", "arm_l", "arm_r", "leg_l", "leg_r"]

# joint limits in radians, so limbs never pass through the body
const ARM_UP_MAX := 2.85       # arm nearly straight up, no further
const ARM_DOWN_MAX := 0.55     # slightly behind the back
const LEG_FWD_MAX := 0.9
const LEG_BACK_MAX := 0.45
const HEAD_TILT_MAX := 0.38
const TORSO_LEAN_MAX := 0.22

var mood := "idle"             # idle | happy | very | sad
var _mood_until_ms := 0
var _t := 0.0

var _vp: SubViewport
var _model: Node3D
var _skel: Skeleton3D
var _rest: Array[Transform3D] = []
var _mi: MeshInstance3D
var _face_mat: StandardMaterial3D
var _base := []
var _faces := {}               # mood -> Texture2D

# --- spring state (value / velocity) ---
var body_y := 0.0
var body_yv := 0.0
var lean := 0.0
var lean_v := 0.0
var sway := 0.0
var head_pitch := 0.0
var head_roll := 0.0
var arm_l := 0.12
var arm_r := 0.12
var arm_lv := 0.0
var arm_rv := 0.0
var leg_l := 0.0
var leg_r := 0.0
var leg_lv := 0.0
var leg_rv := 0.0

var _kick_cd := 0.0            # stops the spring being re-kicked every frame


func _init() -> void:
	stretch = true
	stretch_shrink = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_8X
	add_child(_vp)
	_build_world()
	_load_model()


func _ready() -> void:
	G.melly = self
	tree_exiting.connect(func():
		if G.melly == self:
			G.melly = null)


func _process(delta: float) -> void:
	_t += delta
	if _mood_until_ms != 0 and Time.get_ticks_msec() > _mood_until_ms:
		mood = "idle"
		_mood_until_ms = 0
	_kick_cd = maxf(0.0, _kick_cd - delta)
	_sim(delta)
	_apply_pose()


## ---------------------------------------------------------------- world
func _build_world() -> void:
	var cam := Camera3D.new()
	_vp.add_child(cam)
	cam.current = true
	cam.fov = 44.0
	# pull the camera back so raised arms and a jump always stay in frame
	cam.look_at_from_position(Vector3(0.3, 2.7, 10.4), Vector3(0.0, 2.55, 0.0))

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = false
	_vp.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, -150.0, 0.0)
	fill.light_energy = 0.5
	fill.light_color = Color(1.0, 0.85, 0.8)
	_vp.add_child(fill)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.3, 0.3)
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	_model = Node3D.new()
	_vp.add_child(_model)


## ---------------------------------------------------------------- model
func _load_model() -> void:
	var ps: PackedScene = load("res://models/melly.glb")
	if ps == null:
		return
	var inst := ps.instantiate()
	_model.add_child(inst)

	# skinned mesh: rebuild the surfaces with per-bone vertex colours
	var mis := inst.find_children("*", "MeshInstance3D", true, false)
	if not mis.is_empty():
		_mi = mis[0] as MeshInstance3D
		var mesh: Mesh = _mi.mesh
		if mesh is ArrayMesh and (mesh as ArrayMesh).get_surface_count() > 0:
			var am := mesh as ArrayMesh
			_base = [am.surface_get_arrays(0),
				am.surface_get_arrays(1) if am.get_surface_count() > 1 else null]
			_face_mat = am.surface_get_material(1) if am.get_surface_count() > 1 else null
			apply_colors()
		# bones come from Skeleton3D; the GLB import makes it a sibling
		var skels := inst.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			_skel = skels[0] as Skeleton3D
		if _skel != null:
			for i in _skel.get_bone_count():
				_rest.append(_skel.get_bone_rest(i))

	# the model's own animations are never played - everything is procedural
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		ap.playback_active = false

	# kaomoji faces: swap the face material's texture to match the mood
	_faces = {
		"idle": load("res://models/face_idle.png"),
		"happy": load("res://models/face_happy.png"),
		"very": load("res://models/face_very.png"),
		"sad": load("res://models/face_sad.png"),
	}
	if _face_mat != null:
		_face_mat = _face_mat.duplicate() as StandardMaterial3D
		_face_mat.albedo_texture = _faces["idle"]
		# open-mouth faces have a transparent cut-out; the head colour has to
		# show through it or the cut-out renders black
		_face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_face_mat.alpha_scissor_threshold = 0.5
		_face_mat.cull_mode = BaseMaterial3D.CULL_BACK
		if _mi != null:
			_mi.set_surface_override_material(1, _face_mat)


## Rebuild the mesh: the body surface is tinted by its dominant bone, the face is left alone.
func apply_colors() -> void:
	if _mi == null or _base.is_empty() or _base[0] == null:
		return
	var body: Array = _base[0].duplicate()
	var verts: PackedVector3Array = body[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = body[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = body[Mesh.ARRAY_WEIGHTS]
	if verts.size() == 0 or bones.size() == 0:
		return
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for v in verts.size():
		var bi := 0
		var bw := -1.0
		for k in 4:
			var w: float = weights[v * 4 + k]
			if w > bw:
				bw = w
				bi = bones[v * 4 + k]
		var part: String = BONE_PART[clampi(bi, 0, 5)]
		cols[v] = G.melly_colors.get(part, Color("f2e8e4"))
	body[Mesh.ARRAY_COLOR] = cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body)
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.roughness = 0.55
	bm.metallic_specular = 0.4
	am.surface_set_material(0, bm)
	if _base.size() > 1 and _base[1] != null:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _base[1].duplicate())
		am.surface_set_material(1, _face_mat)
	_mi.mesh = am


## ---------------------------------------------------------------- moods
func set_mood(m: String, hold_sec := 0.0) -> void:
	mood = m
	if hold_sec > 0.0:
		_mood_until_ms = Time.get_ticks_msec() + int(hold_sec * 1000.0)
	else:
		_mood_until_ms = 0
	if _face_mat != null and _faces.has(m):
		_face_mat.albedo_texture = _faces[m]
	if _kick_cd <= 0.0:
		_kick(m)
		_kick_cd = 0.18


func react_hit(combo: int) -> void:
	if combo >= 25:
		set_mood("very", 2.0)
	elif combo >= 8:
		set_mood("happy", 1.4)
	else:
		set_mood("happy", 0.7)


func react_miss() -> void:
	set_mood("sad", 1.6)


func react_win() -> void:
	set_mood("very", 0.0)   # held until they leave the screen


## Kick the springs when the mood changes - a reaction, not a clip switch.
func _kick(m: String) -> void:
	match m:
		"happy":
			body_yv += 1.1
			arm_lv += -3.2
			arm_rv += -2.4
			head_roll_v_add(-0.8)
		"very":
			body_yv += 2.2
			arm_lv += -6.5
			arm_rv += -6.2
			leg_lv += -2.4
			leg_rv += -1.6
			head_pitch_v_add(1.2)
		"sad":
			lean_v += 0.55
			head_pitch_v_add(-0.9)
			arm_lv += 0.9
			arm_rv += 0.7


func head_pitch_v_add(v: float) -> void:
	head_pitch_move(v)
func head_pitch_move(v: float) -> void:
	head_pv += v
func head_roll_v_add(v: float) -> void:
	head_rv += v

var head_pv := 0.0
var head_rv := 0.0


## ---------------------------------------------------------------- physics
func _spring(v: float, vel: float, target: float, stiff: float, damp: float, dt: float) -> Array:
	vel += (target - v) * stiff * dt
	vel *= 1.0 - minf(damp * dt, 0.9)
	v += vel * dt
	return [v, vel]


func _sim(dt: float) -> void:
	var ft := _t
	# targets per mood
	var t_lean := 0.0
	var t_arms := 0.12
	var t_headp := 0.0
	var bounce := 0.0
	var wave := 0.0
	match mood:
		"happy":
			bounce = 0.10
			wave = 0.45
			t_arms = 0.95
		"very":
			bounce = 0.22
			wave = 0.85
			t_arms = 2.6
			t_headp = -0.12
		"sad":
			t_lean = 0.18
			t_arms = -0.14
			t_headp = 0.30
		_:
			bounce = 0.018
			t_arms = 0.12

	# breathing and sway - they are never completely still
	var breath := sin(ft * 2.1) * 0.5 + 0.5
	var hop := absf(sin(ft * (3.4 + bounce * 9.0))) * bounce

	# torso spring: target is the bounce plus the breathing
	var by := _spring(body_y, body_yv, hop + breath * 0.012, 90.0, 7.0, dt)
	body_y = by[0]; body_yv = by[1]
	var ln := _spring(lean, lean_v, t_lean, 42.0, 6.0, dt)
	lean = clampf(ln[0], -TORSO_LEAN_MAX, TORSO_LEAN_MAX); lean_v = ln[1]

	# arms: base pose plus swing; happy and very alternate into a wave
	var arm_phase := sin(ft * (5.0 + wave * 7.0))
	var arm_phase2 := sin(ft * (5.0 + wave * 7.0) + PI * 0.8)
	var tl := t_arms + arm_phase * wave * 0.5 + sin(ft * 1.3) * 0.03
	var tr := t_arms + arm_phase2 * wave * 0.5 + cos(ft * 1.7) * 0.03
	tl = clampf(tl, -ARM_DOWN_MAX, ARM_UP_MAX)
	tr = clampf(tr, -ARM_DOWN_MAX, ARM_UP_MAX)
	var al := _spring(arm_l, arm_lv, tl, 55.0, 6.5, dt)
	arm_l = al[0]; arm_lv = al[1]
	var ar := _spring(arm_r, arm_rv, tr, 55.0, 6.5, dt)
	arm_r = ar[0]; arm_rv = ar[1]

	# legs: tucked in a jump, small steps otherwise
	var lp := sin(ft * (3.4 + bounce * 9.0)) * (bounce * 2.2 + 0.0)
	var rp := sin(ft * (3.4 + bounce * 9.0) + PI) * (bounce * 2.2 + 0.0)
	var tl2 := clampf(lp - hop * 0.8, -LEG_BACK_MAX, LEG_FWD_MAX)
	var tr2 := clampf(rp - hop * 0.8, -LEG_BACK_MAX, LEG_FWD_MAX)
	var ll := _spring(leg_l, leg_lv, tl2, 70.0, 7.5, dt)
	leg_l = ll[0]; leg_lv = ll[1]
	var lr := _spring(leg_r, leg_rv, tr2, 70.0, 7.5, dt)
	leg_r = lr[0]; leg_rv = lr[1]

	# head: droops when sad, always nodding and rolling a little
	var tp := t_headp + breath * 0.02 + sin(ft * 0.9) * 0.02
	var hp := _spring(head_pitch, head_pv, clampf(tp, -HEAD_TILT_MAX, HEAD_TILT_MAX), 40.0, 6.0, dt)
	head_pitch = hp[0]; head_pv = hp[1]
	var t_roll := sin(ft * 0.7) * 0.04 + (sin(ft * 11.0) * 0.05 if mood == "very" else 0.0)
	var hr := _spring(head_roll, head_rv, clampf(t_roll, -HEAD_TILT_MAX, HEAD_TILT_MAX), 40.0, 6.0, dt)
	head_roll = hr[0]; head_rv = hr[1]

	# a gentle left-right torso rotation to keep them alive
	sway = sin(ft * 0.6) * 0.10 + (sin(ft * 9.0) * 0.04 if mood == "very" else 0.0)


func _apply_pose() -> void:
	if _skel == null or _rest.size() < 6:
		return
	# bone 0 = Torso (root): position, tilt and rotation
	var t := Transform3D(Basis.from_euler(Vector3(lean, sway, 0.0)), _rest[0].origin + Vector3(0, body_y, 0))
	_skel.set_bone_pose(0, t)
	# 1 = Head
	_skel.set_bone_pose(1, Transform3D(Basis.from_euler(Vector3(head_pitch, 0.0, head_roll)), _rest[1].origin))
	# 2/3 = ArmL/ArmR: rotate around Z, up and down in the body plane
	_skel.set_bone_pose(2, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, arm_l)), _rest[2].origin))
	_skel.set_bone_pose(3, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -arm_r)), _rest[3].origin))
	# 4/5 = LegL/LegR: rotate around X, forwards and backwards
	_skel.set_bone_pose(4, Transform3D(Basis.from_euler(Vector3(leg_l, 0.0, 0.0)), _rest[4].origin))
	_skel.set_bone_pose(5, Transform3D(Basis.from_euler(Vector3(leg_r, 0.0, 0.0)), _rest[5].origin))
