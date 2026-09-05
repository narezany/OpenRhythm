extends Node
## Boot - decides whether the game opens flat or in a headset, and does it
## without asking.
##
## One desktop build covers both. If an OpenXR runtime is up when the game
## starts - SteamVR running, a headset awake - it opens in VR; if there is no
## runtime, or the headset is off, or the player turned VR off in the settings,
## it opens as an ordinary window. On a standalone headset there is always a
## runtime, so those builds simply always land in VR.

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

var _waiting := false
var _waited := 0.0


func _ready() -> void:
	var xr := _interface()
	if xr == null:
		_go_flat("no OpenXR in this build")
		return
	if _enter_vr(xr):
		return
	if OS.has_feature("android"):
		print("[OR] OpenXR is there but not started; waiting up to %.0fs"
			% XR_RETRY_SECONDS)
		_waiting = true
		return
	_go_flat("no runtime running")


func _process(delta: float) -> void:
	if not _waiting:
		return
	_waited += delta
	var xr := _interface()
	if xr != null and _enter_vr(xr):
		_waiting = false
		return
	if _waited >= XR_RETRY_SECONDS:
		_waiting = false
		_go_flat("OpenXR never started, gave up after %.0fs" % _waited)


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
	get_viewport().use_xr = true
	# the runtime paces frames now; leaving vsync on fights it for the wait
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	UICursor.cursor_visible = false
	G.vr_active = true
	print("[OR] %s runtime up after %.1fs, starting in VR" % [xr.get_name(), _waited])
	add_child(VR_STAGE.new())
	return true


func _go_flat(why: String) -> void:
	print("[OR] starting flat: %s" % why)
	add_child(load("res://scenes/Main.tscn").instantiate())
