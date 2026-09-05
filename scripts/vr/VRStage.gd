extends Node3D
class_name VRStage
## The game inside a headset.
##
## Nothing about the game is rewritten for VR. The flat game runs unchanged in
## a viewport that hangs in front of the player as a screen - menus, video,
## background, HUD, the editor, all of it - and only the cubes are lifted out
## of that screen into real space in front of it. Judging, scoring, holds and
## charts stay exactly where they were, so a map plays the same on a monitor
## and in a headset, and there is one implementation to keep honest.
##
## Aiming feeds the same two things the mouse feeds: a cursor position and a
## click edge. A laser pointer intersects the grid plane; a saber uses the tip
## of the blade and counts a cut when it sweeps through a cube, from any
## direction - how you swing is your business.

const PANEL_W := 5.4              # the backdrop screen, metres across
const PANEL_Y := 1.62
const PANEL_Z := -3.6
## The grid sits in two different places depending on how you play. A saber has
## to reach it, so it is at arm's length and no wider than a swing. A pointer
## does not, and a target that close means throwing your whole arm around to
## cross it - so it moves back and grows, and ends up covering about the same
## part of your view.
const FIELD_W_SABER := 1.25
const FIELD_Y_SABER := 1.38
const FIELD_Z_SABER := -0.72
const FIELD_W_POINT := 1.95
const FIELD_Y_POINT := 1.50
const FIELD_Z_POINT := -2.20
const FLIGHT := 7.0               # how far back a cube starts its run
const CUT_SPEED := 2.0            # m/s the saber tip has to be moving to cut
const CUT_SLAB := 0.16            # how close to the grid plane a cut counts
const BLADE_LEN := 0.85

## design pixels -> metres, on the grid and on the backdrop
var field_w := FIELD_W_POINT
var field_mpp := FIELD_W_POINT / (G.FRAME_HALF * 2.0)
var panel_mpp := PANEL_W / G.DESIGN.x
var _laid_out := ""

var origin: XROrigin3D
var camera: XRCamera3D
var hands: Array[XRController3D] = []
var blades: Array[MeshInstance3D] = []
var vp: SubViewport
var panel: MeshInstance3D
var field: Node3D
var reticle: MeshInstance3D
var laser: MeshInstance3D
var main: Node

var _pool: Array[MeshInstance3D] = []
var _live: Array[MeshInstance3D] = []
var _gs = null                    # the GameScreen currently playing, if any
var _tip_prev := [Vector3.ZERO, Vector3.ZERO]
var _tip_have := [false, false]
var _cut_cool := [0.0, 0.0]
var _trigger_was := false
var _btn_cool := 0.0
var _cursor_design := G.DESIGN * 0.5


func _ready() -> void:
	name = "VRStage"
	_build_world()
	_build_rig()
	_build_screen()
	_build_field()
	_build_pointer()


# ---------------------------------------------------------------- the room
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = G.C_BLOOD.darkened(0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# a floor grid, so the room has a sense of scale and the player can tell
	# which way they have drifted
	var floor_ := MeshInstance3D.new()
	floor_.mesh = _grid_mesh(6.0, 12, Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, 0.22))
	floor_.rotation_degrees = Vector3(-90, 0, 0)
	floor_.material_override = _line_material()
	add_child(floor_)


func _build_rig() -> void:
	origin = XROrigin3D.new()
	add_child(origin)
	camera = XRCamera3D.new()
	camera.near = 0.05
	camera.far = 60.0
	origin.add_child(camera)
	for i in 2:
		var c := XRController3D.new()
		c.tracker = "left_hand" if i == 0 else "right_hand"
		origin.add_child(c)
		hands.append(c)
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.035, BLADE_LEN)
		blade.mesh = bm
		blade.position = Vector3(0, 0, -BLADE_LEN * 0.5)
		blade.material_override = _flat_material(
			G.C_EMBER if i == 1 else Color(0.55, 0.75, 1.0))
		c.add_child(blade)
		blades.append(blade)


## The flat game, rendered to a screen hanging in front of the player.
func _build_screen() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(int(G.DESIGN.x), int(G.DESIGN.y))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = true
	vp.transparent_bg = false
	add_child(vp)
	main = load("res://scenes/Main.tscn").instantiate()
	vp.add_child(main)

	panel = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(PANEL_W, PANEL_W * G.DESIGN.y / G.DESIGN.x)
	panel.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	panel.material_override = m
	panel.position = Vector3(0, PANEL_Y, PANEL_Z)
	add_child(panel)


## The 3x3 grid the cubes land on.
func _build_field() -> void:
	field = Node3D.new()
	add_child(field)
	_layout_field()


## Put the grid where the current way of playing wants it, and only when that
## has actually changed - the mesh is rebuilt with it.
func _layout_field() -> void:
	var style: String = G.vr_style
	if style == _laid_out:
		return
	_laid_out = style
	var saber := style == "saber"
	field_w = FIELD_W_SABER if saber else FIELD_W_POINT
	field_mpp = field_w / (G.FRAME_HALF * 2.0)
	field.position = Vector3(0,
		FIELD_Y_SABER if saber else FIELD_Y_POINT,
		FIELD_Z_SABER if saber else FIELD_Z_POINT)
	for c in field.get_children():
		if c is MeshInstance3D and c.get("owner_note") == null and not _live.has(c):
			c.queue_free()
	var frame := MeshInstance3D.new()
	frame.mesh = _field_mesh()
	frame.material_override = _line_material()
	field.add_child(frame)
	field.move_child(frame, 0)


func _build_pointer() -> void:
	reticle = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.018
	s.height = 0.036
	reticle.mesh = s
	reticle.material_override = _flat_material(Color(1, 0.96, 0.94))
	add_child(reticle)

	laser = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.004
	cyl.height = 1.0
	laser.mesh = cyl
	laser.material_override = _flat_material(
		Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, 0.7))
	add_child(laser)


# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	_layout_field()
	_track_screen()
	var saber := G.vr_style == "saber" and _gs != null
	if saber:
		_aim_saber(delta)
	else:
		_aim_pointer()
	laser.visible = not saber
	for i in 2:
		blades[i].visible = saber
		_cut_cool[i] = maxf(0.0, _cut_cool[i] - delta)
	_sync_notes()
	_buttons(delta)


## The controller buttons that are not the trigger: one steps back the way Esc
## does on a keyboard, the other puts the room back in front of you when you
## have drifted or sat down.
func _buttons(delta: float) -> void:
	_btn_cool = maxf(0.0, _btn_cool - delta)
	if _btn_cool > 0.0:
		return
	var back := false
	var recentre := false
	for c in hands:
		if not c.get_has_tracking_data():
			continue
		if c.is_button_pressed("menu_button") or c.is_button_pressed("by_button"):
			back = true
		if c.get_float("grip") > 0.8 and c.is_button_pressed("by_button"):
			recentre = true
	if recentre:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
		_btn_cool = 0.6
		return
	if back and main != null:
		main.go_back()
		_btn_cool = 0.4


## Follow what the flat game is doing, and get its 2D playfield out of the way
## while a song is running - in VR the cubes are real objects instead.
func _track_screen() -> void:
	var cur = main.current if main != null else null
	var playing = cur if cur is GameScreen else null
	if playing != null and (playing.paused or playing.ended):
		playing = null
	if playing == _gs:
		return
	if _gs != null and is_instance_valid(_gs):
		_release_all()
	_gs = playing
	if _gs != null:
		for n in [_gs.notes_root, _gs.frame_view, _gs.ghost_layer]:
			if n != null and is_instance_valid(n):
				n.visible = false


# ---------------------------------------------------------------- aiming
## Where the player is pointing, as a ray in world space. A tracked controller
## wins; with none the head does the pointing, so the game is still playable
## with a gamepad or nothing at all.
func _ray() -> Array:
	for i in [1, 0]:
		var c := hands[i]
		if c.get_has_tracking_data():
			var t := c.global_transform
			return [t.origin, -t.basis.z]
	var ct := camera.global_transform
	return [ct.origin, -ct.basis.z]


func _aim_pointer() -> void:
	var r := _ray()
	var from: Vector3 = r[0]
	var dir: Vector3 = r[1]
	var target: Node3D = field if _gs != null else panel
	var hit = _plane_hit(target, from, dir)
	if hit == null:
		laser.visible = false
		return
	var world: Vector3 = hit
	reticle.global_position = world
	_lay_laser(from, world)
	_set_cursor(target, world)
	_click(_trigger_down())


## The saber: whichever tip is nearest the grid drives the cursor, and a cut is
## registered when a tip sweeps through the plane quickly. Direction is not
## checked on purpose - people swing the way that feels natural, and telling
## them they swung wrong is not what this game is about.
func _aim_saber(delta: float) -> void:
	var best := -1
	var best_d := 1e9
	var tips: Array[Vector3] = []
	for i in 2:
		var tip: Vector3 = blades[i].global_transform * Vector3(0, 0, -BLADE_LEN * 0.5)
		tips.append(tip)
		if not hands[i].get_has_tracking_data():
			_tip_have[i] = false
			continue
		var d: float = absf(field.to_local(tip).z)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	_set_cursor(field, tips[best])
	var cut := false
	for i in 2:
		if not hands[i].get_has_tracking_data():
			continue
		var local: Vector3 = field.to_local(tips[i])
		if _tip_have[i] and delta > 0.0:
			var speed: float = (tips[i] - _tip_prev[i]).length() / delta
			var crossed: bool = signf(local.z) != signf(field.to_local(_tip_prev[i]).z)
			if _cut_cool[i] <= 0.0 and speed >= CUT_SPEED \
					and (crossed or absf(local.z) < CUT_SLAB):
				cut = true
				_cut_cool[i] = 0.08
				_haptic(i)
		_tip_prev[i] = tips[i]
		_tip_have[i] = true
	if cut and _gs != null:
		_gs._click_edge = true


## Turn a point on a surface into the cursor the flat game reads. The game asks
## the viewport for its canvas transform when it converts that back into
## playfield coordinates, so the same transform is applied here - camera shake
## and zoom stay in step instead of pulling the aim off the cubes.
func _set_cursor(target: Node3D, world: Vector3) -> void:
	var local: Vector3 = target.to_local(world)
	var design: Vector2
	if target == field:
		design = G.DESIGN * 0.5 + Vector2(local.x, -local.y) / field_mpp
	else:
		design = G.DESIGN * 0.5 + Vector2(local.x, -local.y) / panel_mpp
	_cursor_design = design
	if G.autoplay or G.replay_mode:
		return                      # a recording is doing the aiming
	if _gs != null:
		var ct: Transform2D = _gs.get_viewport().get_canvas_transform()
		UICursor.pos = ct * (design - G.DESIGN * 0.5 + _gs.field_center)
	else:
		UICursor.pos = design
		vp.push_input(_mouse_motion(design), true)


## The trigger is a click. In menus it is also a real mouse click, pushed into
## the screen's own viewport so buttons behave exactly as they do flat.
func _click(down: bool) -> void:
	if down == _trigger_was:
		return
	_trigger_was = down
	if _gs != null:
		if down:
			_gs._click_edge = true
			_haptic(1)
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.pressed = down
	ev.position = _cursor_design
	ev.global_position = _cursor_design
	vp.push_input(ev, true)


func _trigger_down() -> bool:
	for c in hands:
		if not c.get_has_tracking_data():
			continue
		if c.get_float("trigger") > 0.6 or c.is_button_pressed("trigger_click") \
				or c.is_button_pressed("ax_button"):
			return true
	return false


func _haptic(hand: int) -> void:
	if hand >= 0 and hand < hands.size():
		hands[hand].trigger_haptic_pulse("haptic", 0.0, 0.35, 0.06, 0.0)


# ---------------------------------------------------------------- the cubes
## Mirror whatever the flat game currently has in the air. The note dictionary
## stays the single source of truth: this only reads position and progress.
func _sync_notes() -> void:
	if _gs == null:
		_release_all()
		return
	var used := {}
	for n in _gs.active:
		if bool(n.get("done", false)):
			continue
		var node: MeshInstance3D = _claim(n)
		used[node] = true
		var hit: Vector2 = n.hit
		var half := float(n.get("half", 60.0)) * field_mpp
		var prog := float(n.get("progress", 0.0))
		var hold := float(n.get("h", 0.0))
		node.position = Vector3(hit.x * field_mpp, -hit.y * field_mpp,
			-FLIGHT * (1.0 - prog))
		var depth: float = maxf(half * 2.0, hold * (FLIGHT / GameScreen.APPROACH))
		node.scale = Vector3(half * 2.0, half * 2.0, depth)
		# a hold reaches back behind its head, so its length is the time you
		# have to keep the cursor on it
		node.position.z -= depth * 0.5 - half
		var col: Color = n.color
		if bool(n.get("holding", false)):
			col = col.lightened(0.35)
		var mat: StandardMaterial3D = node.material_override
		mat.albedo_color = col
		if node.get_child_count() > 0:
			(node.get_child(0) as Node3D).visible = bool(n.get("click", false))
	for node in _live.duplicate():
		if not used.has(node):
			_release(node)


func _claim(n: Dictionary) -> MeshInstance3D:
	var have = n.get("vr_node")
	if have != null and is_instance_valid(have) and _live.has(have):
		return have as MeshInstance3D
	var node: MeshInstance3D
	if _pool.is_empty():
		node = MeshInstance3D.new()
		node.mesh = BoxMesh.new()
		(node.mesh as BoxMesh).size = Vector3.ONE
		node.material_override = _flat_material(Color.WHITE)
		var core := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.34, 0.34, 1.04)
		core.mesh = cm
		core.material_override = _flat_material(Color(1, 0.97, 0.95))
		node.add_child(core)
	else:
		node = _pool.pop_back()
	node.visible = true
	field.add_child(node)
	_live.append(node)
	n["vr_node"] = node
	return node


func _release(node: MeshInstance3D) -> void:
	_live.erase(node)
	node.visible = false
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_pool.append(node)


func _release_all() -> void:
	for node in _live.duplicate():
		_release(node)


# ---------------------------------------------------------------- helpers
func _plane_hit(target: Node3D, from: Vector3, dir: Vector3):
	var t := target.global_transform
	var plane := Plane(t.basis.z.normalized(), t.origin)
	return plane.intersects_ray(from, dir)


func _lay_laser(from: Vector3, to: Vector3) -> void:
	var d := to - from
	var len_ := d.length()
	if len_ < 0.01:
		laser.visible = false
		return
	laser.visible = true
	laser.global_position = from + d * 0.5
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	laser.look_at(to, up)
	# look_at points -Z at the target; the cylinder runs along its own +Y, so
	# tip it a quarter turn the way that lands +Y on -Z
	laser.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	laser.scale = Vector3(1, len_, 1)


func _mouse_motion(at: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	return ev


func _flat_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _line_material() -> StandardMaterial3D:
	var m := _flat_material(Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, 0.5))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	return m


## The 3x3 grid, drawn as lines so it reads as a target without hiding cubes.
func _field_mesh() -> ArrayMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var half := field_w * 0.5
	var step := field_w / 3.0
	im.surface_set_color(Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, 0.55))
	for i in 4:
		var o := -half + step * i
		im.surface_add_vertex(Vector3(o, -half, 0))
		im.surface_add_vertex(Vector3(o, half, 0))
		im.surface_add_vertex(Vector3(-half, o, 0))
		im.surface_add_vertex(Vector3(half, o, 0))
	im.surface_end()
	var mesh := ArrayMesh.new()
	for s in im.get_surface_count():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,
			im.surface_get_arrays(s))
	return mesh


func _grid_mesh(size: float, cells: int, col: Color) -> ArrayMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(col)
	var half := size * 0.5
	var step := size / float(cells)
	for i in cells + 1:
		var o := -half + step * i
		im.surface_add_vertex(Vector3(o, -half, 0))
		im.surface_add_vertex(Vector3(o, half, 0))
		im.surface_add_vertex(Vector3(-half, o, 0))
		im.surface_add_vertex(Vector3(half, o, 0))
	im.surface_end()
	var mesh := ArrayMesh.new()
	for s in im.get_surface_count():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,
			im.surface_get_arrays(s))
	return mesh
