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
const PANEL_Z := -3.6
## Everything in the room is placed below the player's own eyes rather than at
## a height in metres, and the eyes are measured from the headset once tracking
## settles. A room laid out for someone standing is over the ceiling for
## someone sitting down, and the only thing that knows which is happening is
## the headset on their head.
const EYE_ASSUMED := 1.6          # until a tracked frame says otherwise
const PANEL_DROP := 0.30
const FIELD_DROP_SABER := 0.22
const FIELD_DROP_POINT := 0.10
## The grid sits in two different places depending on how you play. A saber has
## to reach it, so it is at arm's length and no wider than a swing. A pointer
## does not, and a target that close means throwing your whole arm around to
## cross it - so it moves back and grows, and ends up covering about the same
## part of your view.
const FIELD_W_SABER := 1.25
const FIELD_Z_SABER := -0.72
const FIELD_W_POINT := 1.95
const FIELD_Z_POINT := -2.20

## How far back a cube starts, and how long it takes to arrive.
##
## The flat game gives a cube one second, which is plenty on a monitor: it
## grows from a third of its size on the way in, and that growth is the depth
## cue. In a headset the depth is real, the growth is not needed - and a cube
## crossing seven metres in that same second is doing 7 m/s. It spends most of
## its run as a speck and then arrives all at once, which reads as cubes
## appearing on top of you rather than flying at you. So VR looks further ahead
## than the flat game does.
##
## Nothing about judging moves with it. The chart, the hit window and the score
## still belong to GameScreen and still run on its one second; this decides
## only how early a cube becomes something you can see coming.
const FLIGHT := 7.0
const VR_APPROACH := 2.0
## The first slice of that run, spent growing into place - the headset's
## version of the fade and the pop a cube gets on a flat screen.
const BIRTH := 0.09
## How round the corners are, as a fraction of a cube. The flat game rounds its
## cards by 0.12 of their width; this is the same number.
const CUBE_ROUND := 0.12
const CUT_SPEED := 2.0            # m/s the saber tip has to be moving to cut
const BLADE_LEN := 0.85
## A saber cuts the cube itself, wherever the cube happens to be - there is no
## target to line up with, which is why saber play has no grid drawn at all.
## What it does still have is the chart's timing: a cube is cuttable once it is
## this close to landing, which is when it is in front of you anyway. Cutting a
## cube that is still four metres out would split it on screen and then have
## the song count it as missed, and that would be a lie.
## How early a cube may be taken. A little wider than the window the cut is
## graded in, so an early swing still connects - and scores like an early
## swing, rather than silently doing nothing.
const CUT_WINDOW := 0.22
## A cut is any part of the blade going through the cube, not the tip of it.
## The blade is sampled along its length and each sample carries its own trail
## from last frame, so what is really tested is the whole sheet the blade swept
## - which is what a swing looks like to the person doing it.
const BLADE_SAMPLES := 6
const CUT_MARGIN := 0.035         # metres of slack around the cube
const SHARD_LIFE := 0.9
const SHARD_SPEED := 1.9
const BURN_LIFE := 0.55
## Hold the trigger and the blade goes live. A live blade passes straight
## through ordinary cubes and burns the ones with a ring on them - so a chart
## that mixes the two is asking you to know which is coming and have the
## trigger in the right state when it gets there.
const C_LIVE := Color(0.55, 0.86, 1.0)
const C_BURN := Color(1.0, 0.74, 0.32)
## Melly stands in the room rather than on the screen. Small, off to one side,
## and turned towards whoever is looking.
const MELLY_HEIGHT := 0.54
const MELLY_SPOT := Vector3(-1.1, 0.0, -1.85)
## Reach a hand up to their head and move it about and they get patted. Both
## conditions matter: a hand parked near their head is somebody resting, not
## somebody being kind.
const PAT_REACH := 0.26
const PAT_SPEED := 0.25           # m/s the hand has to be moving
const HEART_LIFE := 1.5
## Take hold of them with the grip and they go limp in your hand. Let go and
## they fall - there is no putting them down in mid-air, because there is
## nothing up there to put them on.
const GRAB_REACH := 0.34
const DROP_GRAV := 6.5
## How long a rank hangs in the air. Longer than the flat game gives it: on a
## monitor it is printed right where you are looking, and out here it is a
## couple of metres away.
const TEXT_LIFE := 0.7

## The colours the flat game paints its cards with, so a cube means the same
## thing on a monitor and in a headset.
const C_FACE := Color(0.92, 0.90, 0.89)
const C_CORE := Color(1.0, 0.99, 0.98)
const C_CLICK_FACE := Color(1.0, 0.55, 0.28)
const C_CLICK_CORE := Color(1.0, 0.76, 0.52)
const C_HOLD_ON := Color(1.0, 0.86, 0.70)
const C_HOLD_ON_CORE := Color(1.0, 0.95, 0.86)
const C_HOLD_OFF := Color(0.70, 0.66, 0.68)
const C_HOLD_OFF_CORE := Color(0.82, 0.78, 0.80)
## The cartoon trick: a second copy of the cube, grown a little, painted black
## and drawn inside out, so what you see of it is a rim around the cube. A
## white cube on a white background has no silhouette without it.
const OUTLINE := 0.014            # metres, the same all the way in
const C_OUTLINE := Color(0.03, 0.012, 0.02)
const C_BEAM := Color(0.98, 0.13, 0.15)

## Standing where you want to stand: the left stick walks, the right one turns.
## Both move the player and not the room, so the screen and the grid stay put
## while you find the spot you like.
const MOVE_SPEED := 1.5           # metres per second
const TURN_SPEED := 75.0          # degrees per second
const STICK_DEAD := 0.2
const ROOM_REACH := 2.6           # how far from the middle you can wander

## design pixels -> metres, on the grid and on the backdrop
var field_w := FIELD_W_POINT
var field_mpp := FIELD_W_POINT / (G.FRAME_HALF * 2.0)
var panel_mpp := PANEL_W / G.DESIGN.x
var _laid_out := ""

## Preview mode: the same room on an ordinary screen, with the mouse doing the
## pointing. No headset, no OpenXR - which is the point. It is the only way to
## see whether the room itself is right when the trouble is somewhere in the
## engine's XR startup, and it is a far quicker way to work on the room than
## putting a headset on for every change.
var preview := false

var origin: Node3D
var camera: Camera3D
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
var _sweep_prev := [PackedVector3Array(), PackedVector3Array()]
var _tip_have := [false, false]
var _cut_cool := [0.0, 0.0]
var _trigger_was := false
var _btn_cool := 0.0
var _frames := 0
var _cursor_design := G.DESIGN * 0.5
var _time := 0.0
var _vr_i := 0                    # first cube in the chart still worth drawing
var _eye_y := 0.0                 # measured eye height, 0 until tracking says
var _eye_pending := true
var _laid_eye := -1.0
var _cube_mesh: ArrayMesh = null
var _core_mesh: ArrayMesh = null
var _ring_mesh: TorusMesh = null
var wands: Array[Node3D] = []     # the pointer models, one per hand
## The pieces a cut cube comes apart into. One entry each, holding the node
## and how it is flying, because a half cube needs its birth shape kept whole:
## adding to a scaled node's rotation every frame slowly shears it.
var shards: Array = []
var melly_root: Node3D = null
var _melly_rig = null             # the MellyRig whose model we are borrowing
var _melly_model: Node3D = null
var _melly_home: Node = null
var _own_rig = null                # our own Melly, for the screens with none
var _pat_prev := [Vector3.ZERO, Vector3.ZERO]
var _pat_cool := 0.0
var _heart_mesh: ArrayMesh = null
var _labels: Array = []           # the ranks currently hanging in the room
var _last_text := 0
var _melly_state := "stand"       # stand | held | fall
var _melly_pos := MELLY_SPOT
var _melly_yaw := 0.0
var _melly_tilt := Vector3.ZERO
var _melly_vel := Vector3.ZERO
var _melly_hand := -1
var _melly_scale := 1.0
var _melly_foot := 0.0
var _grab_prev := Vector3.ZERO


func _ready() -> void:
	name = "VRStage"
	# The pause menu pauses the whole tree, and a paused stage stops reading
	# the controllers - which leaves the player looking at a menu they cannot
	# press anything on and no way out of it but the desktop.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Each stage says it finished. A log that stops halfway says exactly which
	# piece of building the room is the one that fell over, which is otherwise
	# unknowable from inside a headset showing nothing.
	G.dev_log("stage: building")
	_build_world()
	G.dev_log("stage: world")
	_build_rig()
	G.dev_log("stage: rig")
	_build_screen()
	G.dev_log("stage: screen")
	_build_field()
	G.dev_log("stage: field")
	_build_pointer()
	_build_melly()
	# One line in the device log saying the room was built and by whom. A
	# headset that shows nothing gives no other clue as to how far this got.
	G.dev_log("stage up: camera=%s origin=%s hands=%d interface=%s" % [
		camera.current, origin.current, hands.size(),
		XRServer.primary_interface.get_name() if XRServer.primary_interface else "none"])


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

	# Everything the room draws itself is unshaded, so these two light exactly
	# one thing: Melly, once they are standing in here rather than on the screen.
	# They are aimed the way Melly's own little world aims them, so they look
	# in VR the way they look flat.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = false
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, -150.0, 0.0)
	fill.light_energy = 0.5
	fill.light_color = Color(1.0, 0.85, 0.8)
	add_child(fill)
	melly_root = Node3D.new()
	add_child(melly_root)

	# a floor grid, so the room has a sense of scale and the player can tell
	# which way they have drifted
	var floor_ := MeshInstance3D.new()
	floor_.mesh = _grid_mesh(6.0, 12, Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, 0.22))
	floor_.rotation_degrees = Vector3(-90, 0, 0)
	floor_.material_override = _line_material()
	add_child(floor_)


func _build_rig() -> void:
	if preview:
		_build_preview_rig()
		return
	origin = XROrigin3D.new()
	# Both have to say they are the ones in use. With no current camera the
	# viewport has no 3D view to render, so nothing is handed to the headset's
	# compositor at all - which a headset shows as a loading spinner that never
	# ends, while the game carries on running and playing its music behind it.
	origin.current = true
	add_child(origin)
	camera = XRCamera3D.new()
	camera.near = 0.05
	camera.far = 60.0
	camera.current = true
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
		var wand := _build_wand()
		c.add_child(wand)
		wands.append(wand)


## Which hand does the work. Everything that has to pick one hand asks here,
## so a left-handed player gets the whole game the other way round rather than
## a laser that comes out of the wrong hand.
func _dom() -> int:
	return 0 if G.vr_hand == "left" else 1


## The thing in your hand in pointer play: the little rounded metal tube you
## chase a cat around the room with. A body, a rubber band around the button
## end, and the emitter at the front. Both hands hold one - a hand with nothing
## in it reads as tracking having dropped, which is a worse thing to be told
## than "this one does not work".
func _build_wand() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.0105
	cap.height = 0.104
	cap.radial_segments = 20
	cap.rings = 6
	body.mesh = cap
	# the capsule stands on its own +Y; a quarter turn lays it along -Z, which
	# is the way a controller points
	body.rotation_degrees = Vector3(-90, 0, 0)
	body.position = Vector3(0, 0, -0.03)
	body.material_override = _flat_material(Color(0.66, 0.67, 0.70))
	body.name = "body"
	root.add_child(body)
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.0112
	bm.bottom_radius = 0.0112
	bm.height = 0.016
	bm.radial_segments = 20
	band.mesh = bm
	band.rotation_degrees = Vector3(-90, 0, 0)
	band.position = Vector3(0, 0, 0.002)
	band.material_override = _flat_material(Color(0.17, 0.16, 0.18))
	root.add_child(band)
	var lens := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.0072
	sm.height = 0.0144
	lens.mesh = sm
	lens.position = Vector3(0, 0, -0.081)
	lens.material_override = _flat_material(C_BEAM)
	lens.name = "lens"
	root.add_child(lens)
	return root


## Show the right thing in each hand, and make the dead pointer look dead: a
## darker barrel and a lens that has stopped, apart from the odd twitch of a
## light that is not quite gone.
func _paint_hands(saber: bool) -> void:
	if preview or wands.size() < 2:
		return
	var dom := _dom()
	for i in 2:
		wands[i].visible = not saber
		blades[i].visible = saber
		if saber:
			# a live blade is unmistakable, because holding the trigger at the
			# wrong moment is the difference between a cube burnt and a cube
			# missed
			var live: bool = _trigger_held(i)
			var base: Color = G.C_EMBER if i == 1 else Color(0.55, 0.75, 1.0)
			blades[i].material_override.albedo_color = (
				C_LIVE.lerp(Color.WHITE, 0.35 + 0.35 * sin(_time * 26.0))
				if live else base)
			continue
		var lens: MeshInstance3D = wands[i].get_node_or_null("lens")
		var barrel: MeshInstance3D = wands[i].get_node_or_null("body")
		if lens == null or barrel == null:
			continue
		if i == dom:
			lens.material_override.albedo_color = C_BEAM
			barrel.material_override.albedo_color = Color(0.66, 0.67, 0.70)
		else:
			var twitch: bool = sin(_time * 11.0 + 1.7) > 0.965
			lens.material_override.albedo_color = (Color(0.55, 0.14, 0.13)
				if twitch else Color(0.19, 0.05, 0.06))
			barrel.material_override.albedo_color = Color(0.34, 0.34, 0.36)


## The same rig without a headset: a plain camera where the head would be, and
## no controllers - the mouse points instead.
func _build_preview_rig() -> void:
	origin = Node3D.new()
	add_child(origin)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 60.0
	camera.position = Vector3(0, 1.6, 0)
	camera.current = true
	origin.add_child(camera)


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
	panel.position = Vector3(0, _eye() - PANEL_DROP, PANEL_Z)
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
	if style == _laid_out and is_equal_approx(_laid_eye, _eye()):
		return
	_laid_out = style
	_laid_eye = _eye()
	var saber := style == "saber"
	field_w = FIELD_W_SABER if saber else FIELD_W_POINT
	field_mpp = field_w / (G.FRAME_HALF * 2.0)
	field.position = Vector3(0,
		_eye() - (FIELD_DROP_SABER if saber else FIELD_DROP_POINT),
		FIELD_Z_SABER if saber else FIELD_Z_POINT)
	for c in field.get_children():
		if c is MeshInstance3D and c.get("owner_note") == null and not _live.has(c):
			c.queue_free()
	# Saber play draws no grid at all. There is nothing to line up with: the
	# cube is the target and you cut it where it is, so a 3x3 frame hanging in
	# the air would only be telling you about the flat game's rules.
	if saber:
		return
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
	reticle.material_override = _flat_material(Color(1.0, 0.42, 0.38))
	add_child(reticle)

	laser = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.004
	cyl.height = 1.0
	laser.mesh = cyl
	laser.material_override = _flat_material(
		Color(C_BEAM.r, C_BEAM.g, C_BEAM.b, 0.72))
	add_child(laser)


# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	if _frames < 121:
		# Two lines in the device log: one when the room is up, one once frames
		# are actually going out. A headset that shows only its own loading
		# screen gives no other way to tell which of the two never happened.
		_frames += 1
		if _frames == 120:
			G.dev_log("rendering: 120 frames out, head at %v" % camera.global_position)
	_time += delta
	_settle_height()
	_layout_field()
	_track_screen()
	var saber := G.vr_style == "saber" and _gs != null and not preview
	if saber:
		_aim_saber(delta)
	else:
		_aim_pointer()
	if saber:
		laser.visible = false
	_paint_hands(saber)
	for i in _cut_cool.size():
		_cut_cool[i] = maxf(0.0, _cut_cool[i] - delta)
	_sync_notes()
	_sync_texts()
	_texts(delta)
	_shards(delta)
	_melly(delta)
	_locomotion(delta)
	_buttons(delta)


## The controller buttons that are not the trigger: one steps back the way Esc
## does on a keyboard, the other puts the room back in front of you when you
## have drifted or sat down.
func _buttons(delta: float) -> void:
	if preview:
		return
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
		# not while they are in that hand - grip is how you are holding them
		if c.get_float("grip") > 0.8 and c.is_button_pressed("by_button") \
				and _melly_state != "held":
			recentre = true
	if recentre:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
		origin.transform = Transform3D.IDENTITY
		_eye_pending = true         # sitting down counts as a new room
		_btn_cool = 0.6
		return
	if back and main != null:
		main.go_back()
		_btn_cool = 0.4


## The eye height the room is built around: measured if the headset has said,
## assumed otherwise.
func _eye() -> float:
	return _eye_y if _eye_y > 0.0 else EYE_ASSUMED


## Take the player's height from the headset, once.
##
## Sampled when tracking first gives a believable number, and again after a
## recentre. Deliberately not followed frame by frame: a screen that drifts up
## and down with your head is the quickest way to make someone ill, and ducking
## should not move the room.
func _settle_height() -> void:
	if preview or not _eye_pending or camera == null:
		return
	var y: float = camera.position.y
	if y < 0.6 or y > 2.4:
		return                      # tracking has not settled yet
	_eye_pending = false
	_eye_y = y
	panel.position.y = y - PANEL_DROP
	G.dev_log("room set to an eye height of %.2f m" % y)


## The thumbsticks. Left walks, right turns.
##
## This moves the player, never the room: the screen and the grid are where the
## song is, and a game that slid them around underfoot would be aiming at a
## moving target. Turning happens about the player's own head rather than about
## the middle of the room, because turning about a point you are not standing
## on throws you sideways instead.
func _locomotion(delta: float) -> void:
	if preview or hands.size() < 2 or origin == null:
		return
	var walk := _stick(0)
	if walk != Vector2.ZERO:
		var b := camera.global_transform.basis
		var fwd := Vector3(-b.z.x, 0.0, -b.z.z)
		var right := Vector3(b.x.x, 0.0, b.x.z)
		if fwd.length_squared() > 0.0001 and right.length_squared() > 0.0001:
			origin.global_position += (right.normalized() * walk.x
				+ fwd.normalized() * walk.y) * MOVE_SPEED * delta
			origin.position = Vector3(
				clampf(origin.position.x, -ROOM_REACH, ROOM_REACH),
				origin.position.y,
				clampf(origin.position.z, -ROOM_REACH, ROOM_REACH))
	var turn := _stick(1)
	if turn.x != 0.0:
		var angle := -turn.x * deg_to_rad(TURN_SPEED) * delta
		var pivot: Vector3 = origin.transform * Vector3(
			camera.position.x, 0.0, camera.position.z)
		var rot := Basis(Vector3.UP, angle)
		origin.transform = Transform3D(rot, pivot - rot * pivot) * origin.transform


## One thumbstick, with its dead zone taken out and the rest stretched back
## over the full range - so a stick that rests at 0.15 does not creep the
## player across the room, and small pushes still give small movements.
func _stick(hand: int) -> Vector2:
	var c := hands[hand]
	if not c.get_has_tracking_data():
		return Vector2.ZERO
	var v: Vector2 = c.get_vector2("primary")
	var m := v.length()
	if m < STICK_DEAD:
		return Vector2.ZERO
	return v / m * minf((m - STICK_DEAD) / (1.0 - STICK_DEAD), 1.0)


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
	_vr_i = 0
	_last_text = 0
	for e in _labels:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	_labels.clear()
	_gs = playing
	if _gs != null:
		for n in [_gs.notes_root, _gs.frame_view, _gs.ghost_layer, _gs.texts]:
			if n != null and is_instance_valid(n):
				n.visible = false


# ---------------------------------------------------------------- aiming
## Where the player is pointing, as a ray in world space. A tracked controller
## wins; with none the head does the pointing, so the game is still playable
## with a gamepad or nothing at all.
func _ray() -> Array:
	if preview:
		# the mouse is the hand: aim through the pointer, from the eye
		var vp := get_viewport()
		var m := vp.get_mouse_position()
		return [camera.project_ray_origin(m), camera.project_ray_normal(m)]
	for i in [_dom(), 1 - _dom()]:
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
	# from the lens rather than from the wrist, or the beam starts inside the
	# model of the thing it is supposed to be coming out of
	_lay_laser(from + dir.normalized() * 0.21, world)
	_set_cursor(target, world)
	_click(_trigger_down())


## The saber. There is no grid to aim at: a cut is a blade passing through the
## cube itself, from any direction, and the cube comes apart where it was.
##
## What a cut cannot do is arrive early. The chart still decides when a note
## lands, so a cube is only cuttable once it is close enough to be in front of
## you - which is where you would swing at it anyway. Splitting one four metres
## out and then having the song count it as missed would be a lie told with
## particles.
func _aim_saber(delta: float) -> void:
	var sweep: Array = [_blade_points(0), _blade_points(1)]
	# the cursor follows whichever blade is deepest into the field, so a cube
	# that is swept resolves under the cursor rather than by luck
	var best := -1
	var best_d := 1e9
	for i in 2:
		if not hands[i].get_has_tracking_data():
			_tip_have[i] = false
			continue
		var tip: Vector3 = sweep[i][BLADE_SAMPLES - 1]
		var d: float = absf(field.to_local(tip).z)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_set_cursor(field, sweep[best][BLADE_SAMPLES - 1])
	for i in 2:
		if not hands[i].get_has_tracking_data():
			continue
		var now: PackedVector3Array = sweep[i]
		if _tip_have[i] and delta > 0.0 and _cut_cool[i] <= 0.0 \
				and _sweep_prev[i].size() == now.size():
			# any part of the blade moving fast enough arms the swing - a hilt
			# barely turns while the point is flying, so asking the whole blade
			# to be quick would mean only the last few inches ever cut
			var fast := false
			for k in BLADE_SAMPLES:
				if (now[k] - _sweep_prev[i][k]).length() / delta >= CUT_SPEED:
					fast = true
					break
			if fast:
				_try_cut(i, _sweep_prev[i], now)
		_sweep_prev[i] = now
		_tip_have[i] = true


## The blade, as a handful of points from hilt to tip. Cutting is tested along
## all of them, because a sword is a length of steel and not a dot on the end.
func _blade_points(i: int) -> PackedVector3Array:
	var t := blades[i].global_transform
	var out := PackedVector3Array()
	for k in BLADE_SAMPLES:
		var f: float = float(k) / float(BLADE_SAMPLES - 1)
		out.append(t * Vector3(0.0, 0.0, BLADE_LEN * (0.5 - f)))
	return out


## Did this sweep go through a cube? The path the tip travelled is taken into
## each live cube's own space, where the cube is the unit box however it has
## been scaled or turned, and the whole thing becomes a segment against a box.
func _try_cut(hand: int, prev: PackedVector3Array, now: PackedVector3Array) -> void:
	if _gs == null:
		return
	var at: float = Conductor.play_time()
	var live := _trigger_held(hand)
	for node: MeshInstance3D in _live.duplicate():
		var n = node.get_meta("note", null)
		if not (n is Dictionary) or bool(n.get("vr_cut", false)) \
				or bool(n.get("done", false)):
			continue
		if float(n.t) - at > CUT_WINDOW:
			continue
		# a live blade is for the ringed cubes and nothing else, and a dead one
		# cannot touch them - which is the whole of the trigger's job in here
		if bool(n.get("click", false)) != live:
			continue
		var inv := node.global_transform.affine_inverse()
		# the slack is in metres out here and has to arrive in the cube's own
		# space, where the cube is the unit box however it has been stretched
		var sc := node.scale
		var slack := Vector3(
			CUT_MARGIN / maxf(sc.x, 0.001),
			CUT_MARGIN / maxf(sc.y, 0.001),
			CUT_MARGIN / maxf(sc.z, 0.001))
		var through := false
		for k in BLADE_SAMPLES:
			if _seg_box(inv * prev[k], inv * now[k], slack):
				through = true
				break
		# and the blade where it is standing right now, so a cube the steel is
		# lying across counts even if it slipped between two frames
		if not through and _seg_box(inv * now[0],
				inv * now[BLADE_SAMPLES - 1], slack):
			through = true
		if not through:
			continue
		_cut_cool[hand] = 0.08
		_haptic(hand)
		n["vr_cut"] = true
		# settled here and now, on timing. Leaving it to land would mean
		# judging it by where the cursor happens to be a moment later, and by
		# then the blade is somewhere else entirely.
		# the rank belongs where the cube was, so it is taken now rather than
		# left for the sweep at the end of the frame to put on the plane
		var where := node.position + Vector3(0.0, 0.0, 0.07)
		_gs.cut_note(n)
		_sync_texts(where)
		if live:
			_burn(node)
		else:
			_shatter(node, now[BLADE_SAMPLES - 1] - prev[BLADE_SAMPLES - 1])
		_release(node)
		return


## Is this hand holding its trigger? Sabers only - the pointer's trigger is
## still a click and nothing about flat play changes.
func _trigger_held(hand: int) -> bool:
	var c := hands[hand]
	if not c.get_has_tracking_data():
		return false
	return c.get_float("trigger") > 0.55 or c.is_button_pressed("trigger_click")


## A ringed cube taken by a live blade does not come apart - it goes up. One
## piece, flaring and shrinking to nothing, because burning is the thing that
## makes the trigger worth holding rather than another way of cutting.
func _burn(node: MeshInstance3D) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = _cube_mesh
	var m := _flat_material(Color(1.0, 0.95, 0.72))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	piece.material_override = m
	piece.transform = node.transform
	field.add_child(piece)
	shards.append({
		"node": piece, "life": BURN_LIFE, "total": BURN_LIFE, "burn": true,
		"vel": Vector3(0.0, 0.55, 0.25), "grav": 0.0,
		"axis": Vector3.UP, "spin": 2.4, "base": node.transform.basis, "ang": 0.0,
	})


## A segment against the unit box, by slabs. Both ends are in the box's own
## space, so there is no orientation left to worry about.
func _seg_box(a: Vector3, b: Vector3, slack := Vector3.ZERO) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for k in 3:
		var o: float = a[k]
		var dd: float = d[k]
		var h: float = 0.5 + slack[k]
		if absf(dd) < 0.000001:
			if o < -h or o > h:
				return false
			continue
		var ta := (-h - o) / dd
		var tb := (h - o) / dd
		if ta > tb:
			var swap := ta
			ta = tb
			tb = swap
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true


## Take the cube apart. Which way the blade went decides where the cut runs:
## the split follows the swing, so a flat swing takes the top off and an
## upward one halves it down the middle.
func _shatter(node: MeshInstance3D, swing: Vector3) -> void:
	var local: Vector3 = field.global_transform.basis.inverse() * swing
	var upright: bool = absf(local.y) > absf(local.x)
	var body: StandardMaterial3D = node.material_override
	var t := node.transform
	for side in [-1.0, 1.0]:
		var piece := MeshInstance3D.new()
		piece.mesh = _cube_mesh
		var m := _flat_material(body.albedo_color)
		# a half cube is an open shell - the cut face has no lid on it, so its
		# far side has to keep drawing or you look straight through the piece
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		piece.material_override = m
		var cut := Vector3(0.5, 1.0, 1.0) if upright else Vector3(1.0, 0.5, 1.0)
		var off := Vector3(0.25 * side, 0.0, 0.0) if upright \
			else Vector3(0.0, 0.25 * side, 0.0)
		var basis := t.basis * Basis.IDENTITY.scaled(cut)
		piece.transform = Transform3D(basis, t.origin + t.basis * off)
		field.add_child(piece)
		shards.append({
			"node": piece,
			"life": SHARD_LIFE,
			"total": SHARD_LIFE,
			"burn": false,
			"grav": 2.6,
			# apart along the cut, and a little towards the player
			"vel": off.normalized() * SHARD_SPEED + Vector3(0.0, 0.0, 0.7),
			"axis": local.normalized() if local.length() > 0.001 else Vector3.UP,
			"spin": randf_range(4.0, 9.0) * side,
			"base": basis,
			"ang": 0.0,
		})


## The pieces, falling and fading. Their turn is applied to the shape they were
## born with rather than accumulated on the node: a half cube is scaled on one
## axis, and adding to its rotation every frame would slowly shear it.
func _shards(delta: float) -> void:
	var i := shards.size()
	while i > 0:
		i -= 1
		var sh: Dictionary = shards[i]
		var piece = sh["node"]
		sh["life"] = float(sh["life"]) - delta
		if float(sh["life"]) <= 0.0 or not is_instance_valid(piece):
			if is_instance_valid(piece):
				piece.queue_free()
			shards.remove_at(i)
			continue
		sh["vel"] = (sh["vel"] as Vector3) + Vector3.DOWN * float(sh["grav"]) * delta
		sh["ang"] = float(sh["ang"]) + float(sh["spin"]) * delta
		var pos: Vector3 = piece.position + (sh["vel"] as Vector3) * delta
		var k := clampf(float(sh["life"]) / maxf(float(sh["total"]), 0.001), 0.0, 1.0)
		var shape: Basis = sh["base"] as Basis
		var m: StandardMaterial3D = piece.material_override
		if bool(sh["burn"]):
			# white hot, then ember, then gone - and smaller all the way
			shape = shape.scaled(Vector3.ONE * (0.25 + 0.75 * k))
			m.albedo_color = Color(1.0, 0.95, 0.72).lerp(C_BURN, 1.0 - k)
			m.albedo_color.a = k
		else:
			m.albedo_color.a = k * k
		piece.transform = Transform3D(
			Basis(sh["axis"] as Vector3, float(sh["ang"])) * shape, pos)


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
			_haptic(_dom())
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.pressed = down
	ev.position = _cursor_design
	ev.global_position = _cursor_design
	vp.push_input(ev, true)


func _trigger_down() -> bool:
	if preview:
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
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
## Mirror what the flat game has in the air, and what it is about to.
##
## The note dictionaries stay the single source of truth - this reads their
## time, cell and size and never writes anything a rule depends on. Where it
## parts company with the flat game is how far ahead it looks: a cube becomes
## visible VR_APPROACH seconds before it lands rather than the one second the
## flat game spawns it in, because the flat game's second is a distance of a
## few hundred pixels and here it is seven metres.
func _sync_notes() -> void:
	if _gs == null:
		_release_all()
		_vr_i = 0
		return
	var st: float = Conductor.play_time()
	var all: Array = _gs.notes
	# Walk a window, not the chart: a long map is thousands of notes and this
	# runs every frame. Everything before _vr_i is finished with for good.
	while _vr_i < all.size() and bool(all[_vr_i].get("done", false)):
		_vr_i += 1
	var note_scale := float(_gs.get("_note_scale"))
	if note_scale <= 0.0:
		note_scale = 1.0
	var used := {}
	var i := _vr_i
	while i < all.size():
		var n: Dictionary = all[i]
		i += 1
		var lead: float = float(n.t) - st
		if lead > VR_APPROACH:
			break                   # sorted by time: nothing later is closer
		if bool(n.get("done", false)) or bool(n.get("vr_cut", false)):
			continue
		var prog := clampf(1.0 - lead / VR_APPROACH, 0.0, 1.0)
		var node: MeshInstance3D = _claim(n)
		used[node] = true
		var hit: Vector2 = n.hit
		var w: float = float(n.get("base_half", n.get("half", 52.0))) \
			* note_scale * field_mpp * 2.0
		var hold := float(n.get("h", 0.0))
		var depth: float = maxf(w, hold * (FLIGHT / VR_APPROACH))
		# The cube grows into place over the first slice of its run and spins
		# down to square as it arrives - the same two things the flat game does
		# with scale and rotation, which is what makes a cube read as thrown
		# rather than as switched on.
		var grow := _grow(prog)
		node.position = Vector3(hit.x * field_mpp, -hit.y * field_mpp,
			-FLIGHT * (1.0 - prog))
		# a hold reaches back behind its head, so its length is the time you
		# have to keep the cursor on it
		node.position.z -= depth * 0.5 - w * 0.5
		node.scale = Vector3(w * grow, w * grow, depth)
		node.rotation = Vector3(0.0, 0.0,
			float(n.get("spin", 0.0)) * (1.0 - prog) * 0.7)
		# The three looks the flat game paints, so a cube says the same thing on
		# a monitor and in a headset: a plain card, an ember card ringed for one
		# you have to press, and a hold that goes warm while you are on it and
		# cold the moment you come off.
		var click := bool(n.get("click", false))
		var face: Color = C_CLICK_FACE if click else C_FACE
		var core_col: Color = C_CLICK_CORE if click else C_CORE
		if bool(n.get("holding", false)):
			face = C_HOLD_ON
			core_col = C_HOLD_ON_CORE
		elif bool(n.get("broken", false)):
			face = C_HOLD_OFF
			core_col = C_HOLD_OFF_CORE
		var tint: Color = n.color
		node.material_override.albedo_color = face * tint
		var core: MeshInstance3D = node.get_node_or_null("core")
		if core != null:
			core.material_override.albedo_color = core_col * tint
			# the inner square of the flat card, kept at the head of the cube
			# instead of stretched down the whole length of a hold
			var zl: float = minf(1.04, w * 1.04 / maxf(depth, 0.001))
			core.scale = Vector3(0.34, 0.34, zl)
			core.position = Vector3(0.0, 0.0, 0.5 - zl * 0.5 + 0.02)
		var sw: float = maxf(w * grow, 0.001)
		var outline: MeshInstance3D = node.get_node_or_null("outline")
		if outline != null:
			# a rim of the same thickness however the cube has been stretched
			outline.scale = Vector3(
				(sw + OUTLINE * 2.0) / sw, (sw + OUTLINE * 2.0) / sw,
				(depth + OUTLINE * 2.0) / maxf(depth, 0.001))
		var ring: MeshInstance3D = node.get_node_or_null("ring")
		if ring != null:
			ring.visible = click
			if click:
				var dz: float = maxf(depth, 0.001)
				ring.scale = Vector3(1.0, 1.0, sw / dz)
				ring.position = Vector3(0.0, 0.0, 0.5 + 0.05 / dz)
	for node in _live.duplicate():
		if not used.has(node):
			_release(node)


## How big a cube is as a fraction of itself, this far into its run: it grows
## into place over the first slice and is full size for all the rest. The flat
## game does the same with a scale tween and a fade, and without it a cube in a
## headset does not fly in - it is simply there.
func _grow(prog: float) -> float:
	var birth := clampf(prog / BIRTH, 0.0, 1.0)
	return 0.25 + 0.75 * (1.0 - pow(1.0 - birth, 3.0))


func _claim(n: Dictionary) -> MeshInstance3D:
	var have = n.get("vr_node")
	if have != null and is_instance_valid(have) and _live.has(have):
		return have as MeshInstance3D
	var node: MeshInstance3D
	if _pool.is_empty():
		if _cube_mesh == null:
			_cube_mesh = _rounded_box(CUBE_ROUND, 5)
			_core_mesh = _rounded_box(CUBE_ROUND * 1.6, 3)
			_ring_mesh = TorusMesh.new()
			_ring_mesh.inner_radius = 0.58
			_ring_mesh.outer_radius = 0.68
			_ring_mesh.rings = 28
			_ring_mesh.ring_segments = 8
		node = MeshInstance3D.new()
		node.mesh = _cube_mesh
		node.material_override = _flat_material(Color.WHITE)
		# The cartoon trick: the same cube again, a little bigger, painted
		# black and drawn inside out. Only its far side survives the depth
		# test, so what you see of it is a rim - which is the difference
		# between a white cube on a white background and no cube at all.
		var outline := MeshInstance3D.new()
		outline.name = "outline"
		outline.mesh = _cube_mesh
		var om := _flat_material(C_OUTLINE)
		om.cull_mode = BaseMaterial3D.CULL_FRONT
		outline.material_override = om
		node.add_child(outline)
		var core := MeshInstance3D.new()
		core.name = "core"
		core.mesh = _core_mesh
		core.material_override = _flat_material(C_CORE)
		node.add_child(core)
		var ring := MeshInstance3D.new()
		ring.name = "ring"
		ring.mesh = _ring_mesh
		# the torus lies flat by default; stand it up to face the player
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.material_override = _flat_material(Color(1.0, 0.45, 0.22))
		node.add_child(ring)
	else:
		node = _pool.pop_back()
	node.set_meta("note", n)
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


# ---------------------------------------------------------------- the ranks
## PERFECT, GREAT and the rest, put up in the room where the cube was.
##
## The flat game prints them on the playfield, and in a headset the playfield
## is a screen several metres behind everything you are looking at - which is
## the last place to tell somebody how they did. So the 2D layer is hidden and
## its labels are mirrored out here instead, at the cell the cube landed in.
## `at3` is where the cube actually was when it was taken - a saber meets it
## out in the air, and putting the rank on the grid plane instead leaves it
## floating on a surface the cube never touched. Anything the flat game settles
## on its own has no such place, and those go on the plane as before.
func _sync_texts(at3 = null) -> void:
	if _gs == null or _gs.texts == null or not is_instance_valid(_gs.texts):
		return
	for it in _gs.texts.items:
		var id := int(it.get("id", 0))
		if id <= _last_text:
			continue
		_last_text = id
		_put_rank(it, at3)


func _put_rank(it: Dictionary, at3 = null) -> void:
	var lab := Label3D.new()
	lab.text = str(it.get("text", ""))
	lab.font = G.font_bold
	lab.font_size = 64
	lab.outline_size = 16
	lab.outline_modulate = Color(0, 0, 0, 0.6)
	lab.modulate = it.get("color", Color.WHITE)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# over the cubes rather than lost among them: a rank you have to look for
	# is not telling you anything
	lab.no_depth_test = true
	# a couple of metres away, so it wants to be a fraction of the size the
	# same words are on a monitor an arm's length from your face
	lab.pixel_size = 0.00075
	if at3 != null:
		lab.position = at3
	else:
		var at: Vector2 = it.get("pos", Vector2.ZERO)
		lab.position = Vector3(at.x * field_mpp, -at.y * field_mpp, 0.12)
	field.add_child(lab)
	_labels.append({"node": lab, "life": TEXT_LIFE})


func _texts(delta: float) -> void:
	var i := _labels.size()
	while i > 0:
		i -= 1
		var e: Dictionary = _labels[i]
		var lab = e["node"]
		e["life"] = float(e["life"]) - delta
		if float(e["life"]) <= 0.0 or not is_instance_valid(lab):
			if is_instance_valid(lab):
				lab.queue_free()
			_labels.remove_at(i)
			continue
		var k: float = 1.0 - clampf(float(e["life"]) / TEXT_LIFE, 0.0, 1.0)
		lab.position.y += 0.34 * delta
		lab.modulate.a = 1.0 - k * k
		var pop: float = 1.0 + 0.25 * (1.0 - clampf(k * 6.0, 0.0, 1.0))
		lab.scale = Vector3(pop, pop, pop)


# ---------------------------------------------------------------- melly
## Melly, standing in the room instead of printed on the screen.
##
## Nothing here rebuilds them. The rig already makes Melly a real 3D model in a
## viewport of its own, so the model is simply lifted out of that viewport into
## the room and handed back when the screen that owns it goes. The animation
## keeps running wherever they are parented: it drives the skeleton, not the
## scene they happen to be in.
func _melly(delta: float) -> void:
	var rig = G.melly
	if rig == null or not is_instance_valid(rig):
		rig = _own_rig
	if rig != _melly_rig:
		_return_melly()
		_borrow_melly(rig)
	# ours goes back to being pleased with themselves once a reaction has run its
	# course - the rig drops the pose back to idle but leaves the face where it
	# was, and idle is the blank one
	if _own_rig != null and rig == _own_rig and _own_rig.mood == "idle":
		_own_rig.set_mood("happy", 0.0)
	_melly_carry(delta)
	if _melly_state == "stand":
		_face_melly(delta)
		_pat(delta)


## Our own Melly, for every screen that does not bring one.
##
## The menu, the song list, the results - none of them put Melly on screen, and
## in a headset that leaves the room with nobody in it. So the stage keeps one
## of its own, standing in the corner breathing and pleased with itself. When a
## screen does bring its own, that one is used instead, so a miss still makes
## the right Melly flinch.
func _build_melly() -> void:
	_own_rig = MellyRig.new()
	# it is a Control living under a 3D node and is never drawn as one; the
	# size is only here so its viewport is not built at nothing by nothing
	_own_rig.size = Vector2(256, 256)
	add_child(_own_rig)
	# set_mood rather than assigning mood: the face is a texture the rig swaps
	# there, so setting the field alone leaves them standing about with the
	# blank idle face on.
	_own_rig.set_mood("happy", 0.0)
	var own_vp = _own_rig.get("_vp")
	if own_vp is SubViewport:
		# the model gets lifted straight out into the room, so the little
		# viewport they were built inside has nothing left to draw
		(own_vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED


func _borrow_melly(rig) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	var model = rig.get("_model")
	if not (model is Node3D) or not is_instance_valid(model):
		return
	_melly_rig = rig
	_melly_model = model
	_melly_home = model.get_parent()
	if _melly_home != null:
		_melly_home.remove_child(model)
	melly_root.add_child(model)
	# Melly is modelled several units tall. Measured rather than guessed - a new
	# export would otherwise arrive the size of a house - and stood on the
	# floor off to one side, small enough to share the room rather than own it.
	var box := _model_aabb(model)
	_melly_scale = MELLY_HEIGHT / maxf(box.size.y, 0.001)
	_melly_foot = box.position.y
	_place_melly()
	G.dev_log("melly is in the room (%.2f units tall, scaled %.2f)"
		% [box.size.y, _melly_scale])


## Where they are, which way up, and which way round. Everything that moves them
## standing, carried, falling - sets the three numbers and calls this, so there
## is one place that knows how a position becomes a transform.
func _place_melly() -> void:
	if _melly_model == null or not is_instance_valid(_melly_model):
		return
	var b := Basis(Vector3.UP, _melly_yaw)
	var tilt := _melly_tilt.length()
	if tilt > 0.0001:
		# tip them the way they are being dragged, about the axis across it
		var axis := Vector3(_melly_tilt.z, 0.0, -_melly_tilt.x).normalized()
		b = Basis(axis, tilt) * b
	_melly_model.transform = Transform3D(
		b * Basis.IDENTITY.scaled(Vector3.ONE * _melly_scale),
		_melly_pos + Vector3(0.0, -_melly_foot * _melly_scale, 0.0))


## Picking them up, carrying them about and putting them down.
##
## There is no ragdoll in the model - it has a skeleton and no physics bones -
## so the doll is made where the doll already lives: the rig animates every
## joint on a spring, and going limp is that same spring set slack with nothing
## driving it. Swinging them about throws the hand's speed into those springs,
## which is where the flopping comes from. The body itself is carried and
## dropped here.
func _melly_carry(delta: float) -> void:
	if preview or hands.size() < 2 or _melly_model == null \
			or not is_instance_valid(_melly_model):
		return
	match _melly_state:
		"held":
			_carry(delta)
		"fall":
			_fall(delta)
		_:
			_try_grab()


func _gripped(i: int, hard := true) -> bool:
	var c := hands[i]
	if not c.get_has_tracking_data():
		return false
	return c.get_float("grip") > (0.7 if hard else 0.45) \
		or c.is_button_pressed("grip_click")


func _try_grab() -> void:
	var body: Vector3 = _melly_model.global_position \
		+ Vector3.UP * (MELLY_HEIGHT * 0.62)
	for i in 2:
		if not _gripped(i):
			continue
		if hands[i].global_position.distance_to(body) > GRAB_REACH:
			continue
		_melly_state = "held"
		_melly_hand = i
		_grab_prev = hands[i].global_position
		_set_limp(true)
		_haptic(i)
		G.dev_log("melly picked up")
		return


func _carry(delta: float) -> void:
	if _melly_hand < 0 or not _gripped(_melly_hand, false):
		_melly_state = "fall"
		_melly_hand = -1
		G.dev_log("melly let go of")
		return
	var at: Vector3 = hands[_melly_hand].global_position
	var moved := at - _grab_prev
	_grab_prev = at
	_melly_vel = moved / maxf(delta, 0.0001)
	# held by the scruff: the hand is up at their neck and the rest of them is
	# below it
	_melly_pos = at - Vector3.UP * (MELLY_HEIGHT * 0.82)
	# and they trail behind the hand, the way anything limp does
	var lag := Vector3(-_melly_vel.x, 0.0, -_melly_vel.z) * 0.09
	_melly_tilt = _melly_tilt.lerp(lag.limit_length(0.55), minf(1.0, delta * 9.0))
	_place_melly()
	var speed := _melly_vel.length()
	if speed > 0.55 and _melly_rig != null and is_instance_valid(_melly_rig):
		_melly_rig.shake(minf(speed - 0.55, 4.0) * 0.3)


func _fall(delta: float) -> void:
	_melly_vel.y -= DROP_GRAV * delta
	_melly_pos += _melly_vel * delta
	_melly_pos.x = clampf(_melly_pos.x, -ROOM_REACH, ROOM_REACH)
	_melly_pos.z = clampf(_melly_pos.z, -ROOM_REACH, ROOM_REACH)
	_melly_tilt = _melly_tilt.lerp(Vector3.ZERO, minf(1.0, delta * 5.0))
	if _melly_pos.y <= 0.0:
		# the floor is the only place they can end up - there is nothing to
		# stand them on in mid-air, so letting go anywhere means letting go here
		_melly_pos.y = 0.0
		_melly_vel = Vector3.ZERO
		_melly_tilt = Vector3.ZERO
		_melly_state = "stand"
		_set_limp(false)
		if _melly_rig != null and is_instance_valid(_melly_rig):
			_melly_rig.set_mood("very", 1.2)
		G.dev_log("melly landed at %v" % _melly_pos)
	_place_melly()


func _set_limp(on: bool) -> void:
	if _melly_rig != null and is_instance_valid(_melly_rig):
		_melly_rig.limp = on


## A hand up at their head, and moving: that is a pat. Both halves are needed -
## a hand parked near their head is somebody resting it there.
func _pat(delta: float) -> void:
	_pat_cool = maxf(0.0, _pat_cool - delta)
	if preview or hands.size() < 2 or _melly_model == null \
			or not is_instance_valid(_melly_model):
		return
	var head: Vector3 = _melly_model.global_position \
		+ Vector3.UP * (MELLY_HEIGHT * 0.86)
	for i in 2:
		if not hands[i].get_has_tracking_data():
			continue
		var at: Vector3 = hands[i].global_position
		var moved: float = (at - _pat_prev[i]).length() / maxf(delta, 0.0001)
		_pat_prev[i] = at
		if _pat_cool > 0.0 or moved < PAT_SPEED or at.distance_to(head) > PAT_REACH:
			continue
		_pat_cool = 0.16
		_heart(head)
		if _melly_rig != null and is_instance_valid(_melly_rig):
			_melly_rig.set_mood("very", 1.6)
		_haptic(i)


## One heart, drifting up off their head and fading.
func _heart(at: Vector3) -> void:
	if _heart_mesh == null:
		_heart_mesh = _make_heart()
	var piece := MeshInstance3D.new()
	piece.mesh = _heart_mesh
	var m := _flat_material(Color(1.0, 0.36, 0.46))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	piece.material_override = m
	var k := randf_range(0.055, 0.085)
	var shape := Basis.IDENTITY.scaled(Vector3(k, k, k))
	piece.transform = Transform3D(shape, at + Vector3(
		randf_range(-0.09, 0.09), randf_range(0.0, 0.06), randf_range(-0.09, 0.09)))
	melly_root.add_child(piece)
	shards.append({
		"node": piece, "life": HEART_LIFE, "total": HEART_LIFE, "burn": false,
		"vel": Vector3(randf_range(-0.12, 0.12), randf_range(0.34, 0.52),
			randf_range(-0.12, 0.12)),
		"grav": 0.0, "axis": Vector3.UP, "spin": 0.0, "base": shape, "ang": 0.0,
	})


## A heart, from the curve everyone draws one with, as a fan of triangles.
func _make_heart() -> ArrayMesh:
	var n := 48
	var curve: Array = []
	for i in n:
		var t := TAU * float(i) / float(n)
		curve.append(Vector3(
			16.0 * pow(sin(t), 3.0),
			13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t),
			0.0) / 32.0)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for i in n:
		verts.append(Vector3.ZERO)
		verts.append(curve[i])
		verts.append(curve[(i + 1) % n])
		for _k in 3:
			norms.append(Vector3.BACK)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Turn them towards whoever is looking, and only about the upright axis - a
## Melly that tips over to follow your head is a puppet rather than a person.
## Eased rather than snapped, so walking past does not make them flick.
func _face_melly(delta: float) -> void:
	if _melly_model == null or not is_instance_valid(_melly_model) or camera == null:
		return
	var to := camera.global_position - _melly_model.global_position
	to.y = 0.0
	if to.length_squared() < 0.0004:
		return
	_melly_yaw = lerp_angle(_melly_yaw, atan2(to.x, to.z), minf(1.0, delta * 6.0))
	_place_melly()


func _return_melly() -> void:
	_set_limp(false)
	_melly_state = "stand"
	_melly_hand = -1
	_melly_tilt = Vector3.ZERO
	_melly_vel = Vector3.ZERO
	var model := _melly_model
	var home := _melly_home
	var rig = _melly_rig
	_melly_model = null
	_melly_home = null
	_melly_rig = null
	if model == null or not is_instance_valid(model):
		return
	if model.get_parent() != null:
		model.get_parent().remove_child(model)
	if home != null and is_instance_valid(home) and rig != null and is_instance_valid(rig):
		model.transform = Transform3D.IDENTITY
		home.add_child(model)
	else:
		# the screen that owned them has gone, and they are ours to let go of
		model.queue_free()


## How big a model is, whatever it is made of, in its own space. Measured so
## that standing them at human height is not a number that quietly stops being
## right the next time the model is exported.
func _model_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var got := false
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var xf: Transform3D = it[1]
		if node is VisualInstance3D:
			var b: AABB = xf * (node as VisualInstance3D).get_aabb()
			box = b if not got else box.merge(b)
			got = true
		for c in node.get_children():
			if c is Node3D:
				stack.append([c, xf * (c as Node3D).transform])
	return box


## Whatever else happens, Melly goes back where they came from - the screen
## that owns them will free them, and a model left parented here would be freed
## or not at all.
func _exit_tree() -> void:
	_return_melly()


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


## A cube with its edges taken off, to match the rounded cards the flat game
## draws. Built once and shared by every cube in the room.
##
## Made by pushing the vertices of a subdivided cube outward from an inner box
## inset by the radius: a point in the middle of a face does not move, a point
## along an edge bulges into a quarter cylinder, a point at a corner into an
## eighth of a sphere. The normal falls out of the same subtraction.
##
## It is a unit cube and every note is scaled to its own size, so a hold - which
## is stretched along Z and nothing else - still has round corners on the one
## face you actually look at.
##
## Wound the way the engine winds its own BoxMesh, which CoreTest checks by
## comparing the volume the two enclose. That is not fussiness: the black
## outline is this same cube drawn again, bigger and inside out, and "inside
## out" only means anything if the faces face the way the renderer expects.
func _rounded_box(radius: float, seg: int) -> ArrayMesh:
	var r := clampf(radius, 0.0, 0.49)
	var inner := 0.5 - r
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for face: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN,
			Vector3.BACK, Vector3.FORWARD]:
		# two axes across the face, picked so that u cross v points out of it
		var u := Vector3(face.y, face.z, face.x)
		var v := face.cross(u)
		for a in seg:
			for b in seg:
				var quad := []
				for c in [Vector2(a, b), Vector2(a + 1, b),
						Vector2(a + 1, b + 1), Vector2(a, b + 1)]:
					var p: Vector3 = face * 0.5 \
						+ u * (c.x / float(seg) - 0.5) \
						+ v * (c.y / float(seg) - 0.5)
					var core := Vector3(
						clampf(p.x, -inner, inner),
						clampf(p.y, -inner, inner),
						clampf(p.z, -inner, inner))
					var out := p - core
					var nn: Vector3 = out.normalized() if out.length() > 0.0001 else face
					quad.append([core + nn * r, nn])
				for k in [0, 2, 1, 0, 3, 2]:
					verts.append(quad[k][0])
					norms.append(quad[k][1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


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
