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


func _ready() -> void:
	if _enter_vr():
		add_child(VR_STAGE.new())
	else:
		add_child(load("res://scenes/Main.tscn").instantiate())


## True once a headset has actually taken over the viewport.
func _enter_vr() -> bool:
	if G.vr_start == "off" or G.shot_mode != "":
		return false
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return false
	var xr := XRServer.find_interface("OpenXR")
	if xr == null:
		return false
	# Not being initialised is the ordinary case on a desktop with no headset
	# plugged in, so it is not an error and nothing is said about it.
	if not xr.is_initialized() and not xr.initialize():
		return false
	get_viewport().use_xr = true
	# the runtime paces frames now; leaving vsync on fights it for the wait
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	UICursor.cursor_visible = false
	G.vr_active = true
	print("Open Rhythm: %s runtime found, starting in VR" % xr.get_name())
	return true
