extends Node
## Boot - decides whether the game opens flat or in a headset, and does it
## without asking.
##
## One desktop build covers both. If an OpenXR runtime is up when the game
## starts - SteamVR running, a headset awake - it opens in VR; if there is no
## runtime, or the headset is off, or the player turned VR off in the settings,
## it opens as an ordinary window. On a standalone headset there is always a
## runtime, so those builds simply always land in VR.
##
## Getting into VR is done in steps, and which step a build got to is written
## down before it is attempted. A headset with no usable cable cannot hand over
## a crash log, and a crash takes the game down before it can write one itself -
## but the note saying what it was about to try survives, so the next launch
## knows what killed the last one, says so, and stops one step short of it. Four
## restarts and the game says where the trouble is instead of dying silently.

## Preloaded rather than referenced by class name: an exported build may be
## packed before the editor has rescanned the class cache, and a main scene
## that fails to parse is not a failure worth risking.
const VR_STAGE := preload("res://scripts/vr/VRStage.gd")

## How long a headset package keeps asking for a runtime before giving up.
##
## A desktop answers on the spot: a runtime is either running or it is not. A
## standalone can take a moment - the session becomes available once the
## activity is properly resumed, and asking once on the first frame can be too
## early. Getting that wrong is invisible from inside the headset: the game
## runs and plays its music while the compositor waits for pictures that are
## never coming, which looks like the app hanging on its loading screen.
const XR_RETRY_SECONDS := 5.0

## The steps, in the order they are tried. Each does everything the one before
## it does and one thing more, so the first one that crashes names the thing.
enum {
	STEP_FLAT = 0,      ## no XR at all - the game as it runs on a phone
	STEP_INIT = 1,      ## bring the OpenXR session up, keep rendering flat
	STEP_XR = 2,        ## hand the viewport over, with a bare 3D scene in it
	STEP_STAGE = 3,     ## the real thing
}
const STEP_NAMES := ["flat", "openxr session", "viewport handover", "vr stage"]
const PROBE_FILE := "user://vr_steps.cfg"
## A step counts as survived once the game has been running this long on it.
const PROBE_SETTLE := 8.0

var _waiting := false
var _waited := 0.0
var _step := STEP_STAGE
var _survived := STEP_STAGE
## Lowest step ever seen to take the game down on this device.
var _ceiling := 99
var _xr: XRInterface = null


func _ready() -> void:
	_pick_step()
	if _step <= STEP_FLAT:
		_go_flat("stepping back after a crash" if _survived < STEP_STAGE
			else "no VR wanted here")
		return
	_xr = _interface()
	if _xr == null:
		_go_flat("no OpenXR in this build")
		return
	if _enter_vr(_xr):
		return
	if OS.has_feature("android"):
		G.dev_log("OpenXR is there but not started; waiting up to %.0fs" % XR_RETRY_SECONDS)
		_waiting = true
		return
	_go_flat("no runtime running")


func _process(delta: float) -> void:
	if _waiting:
		_waited += delta
		var xr := _interface()
		if xr != null and _enter_vr(xr):
			_waiting = false
		elif _waited >= XR_RETRY_SECONDS:
			_waiting = false
			_go_flat("OpenXR never started, gave up after %.0fs" % _waited)
	if _survived < _step:
		_waited += delta
		if _waited >= PROBE_SETTLE:
			_survived = _step
			_write_probe(_step, _survived)
			G.dev_log("step %d (%s) held for %.0fs" % [_step, STEP_NAMES[_step], PROBE_SETTLE])


# ---------------------------------------------------------------- the steps
## Work out which step to try, from what the last launch was in the middle of.
##
## Three numbers are kept: the step last attempted, the highest step that ran
## long enough to count as working, and the lowest step ever seen to crash. A
## launch that never got to say it was working is taken as a crash, which
## lowers the ceiling; the next launch then aims for the highest step below it.
## Without that ceiling the game would alternate forever between the step that
## crashes and the one below it.
func _pick_step() -> void:
	if G.vr_start == "off" or G.shot_mode != "" or OS.has_feature("web") \
			or DisplayServer.get_name() == "headless":
		_step = STEP_FLAT
		_survived = STEP_STAGE      # not a crash, just not wanted
		return
	var cfg := ConfigFile.new()
	var tried := -1
	var held := -1
	var ceiling := 99
	if cfg.load(PROBE_FILE) == OK and str(cfg.get_value("vr", "version", "")) == G.VERSION:
		tried = int(cfg.get_value("vr", "tried", -1))
		held = int(cfg.get_value("vr", "survived", -1))
		ceiling = int(cfg.get_value("vr", "crashed_at", 99))
	if tried > held:
		ceiling = mini(ceiling, tried)
		G.dev_log("last launch died at step %d (%s)" % [tried, STEP_NAMES[tried]])
	_step = clampi(mini(STEP_STAGE, ceiling - 1), STEP_FLAT, STEP_STAGE)
	_survived = held
	_ceiling = ceiling
	_write_probe(_step, _survived)
	if _step < STEP_STAGE:
		G.dev_log("VR is limited to step %d (%s) on this device"
			% [_step, STEP_NAMES[_step]])
	G.dev_log("trying step %d (%s)" % [_step, STEP_NAMES[_step]])


func _write_probe(tried: int, survived: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("vr", "version", G.VERSION)
	cfg.set_value("vr", "tried", tried)
	cfg.set_value("vr", "survived", survived)
	cfg.set_value("vr", "crashed_at", _ceiling)
	cfg.save(PROBE_FILE)


## The OpenXR interface, or null when this build has none at all - a phone
## package is exported with XR off and never sees one.
func _interface() -> XRInterface:
	if G.vr_start == "off" or G.shot_mode != "":
		return null
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return null
	return XRServer.find_interface("OpenXR")


## Try to hand the viewport to the headset. True once it has taken over.
func _enter_vr(xr: XRInterface) -> bool:
	if not xr.is_initialized() and not xr.initialize():
		return false
	G.dev_log("%s session up after %.1fs" % [xr.get_name(), _waited])
	_waited = 0.0
	if _step <= STEP_INIT:
		# the session is up and that is all this step does: the game carries on
		# rendering flat, which proves whether starting OpenXR is what crashes
		add_child(load("res://scenes/Main.tscn").instantiate())
		return true

	var vp := get_viewport()
	vp.use_xr = true
	# Multisampling through the XR path is the first thing to drop when a
	# headset shows nothing: it costs a little edge quality and rules out a
	# whole class of driver trouble.
	vp.msaa_3d = Viewport.MSAA_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	UICursor.cursor_visible = false
	G.vr_active = true
	G.dev_log("viewport handed over: size=%v" % vp.get_visible_rect().size)

	if _step <= STEP_XR:
		add_child(_bare_scene())
		return true
	add_child(VR_STAGE.new())
	_keep_engine_log()
	return true


## A clean shutdown is not a crash either. This does not run when the process
## is killed, which is exactly what makes it a usable signal.
func _exit_tree() -> void:
	_clear_attempt()


## Say that nothing is pending, so the next launch reads no crash.
func _clear_attempt() -> void:
	if _survived < _step:
		_survived = _step
	_write_probe(_survived, _survived)


## The smallest thing that can be looked at: a camera and something in front of
## it. If this draws and the real stage does not, the trouble is ours.
func _bare_scene() -> Node3D:
	var root := Node3D.new()
	var origin := XROrigin3D.new()
	origin.current = true
	root.add_child(origin)
	var cam := XRCamera3D.new()
	cam.current = true
	origin.add_child(cam)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	(box.mesh as BoxMesh).size = Vector3(0.4, 0.4, 0.4)
	box.position = Vector3(0, 1.5, -1.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = G.C_PRIMARY
	box.material_override = mat
	root.add_child(box)
	return root


func _go_flat(why: String) -> void:
	# Deciding not to go into VR is not the same as dying on the way there, and
	# the note has to say so or the next launch will lower the ceiling over a
	# headset that simply was not switched on.
	_clear_attempt()
	G.dev_log("starting flat: %s" % why)
	add_child(load("res://scenes/Main.tscn").instantiate())
	_keep_engine_log()


## The engine writes its startup errors before any of this runs, so the copy is
## taken once things have settled and again a few seconds later, by which point
## anything with something to say has said it.
func _keep_engine_log() -> void:
	G.copy_engine_log()
	G.dump_logcat()
	await get_tree().create_timer(6.0).timeout
	G.copy_engine_log()
	G.dump_logcat()
