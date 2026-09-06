extends Node
## Render the game's own background on its own, at any size, for store art.
##
## Not a drawing of the background - the background. The same shader and the
## same drifting dust the game runs on every screen, with nothing in front of
## it, so the page and the game cannot drift apart the way a hand-made picture
## would the first time the palette changes.
##
##   OR_BG_SIZE=1920x480 OR_BG_OUT=build/itch/banner.png \
##     godot --path . tools/BgShot.tscn
##
## Drawn into a viewport of its own rather than into the window: a window
## manager is free to ignore a size request - a tiling one always does - and
## the picture would come out whatever shape it felt like. A viewport is the
## size it is told.
##
## Needs a real display all the same: rendering is what this does, and
## --headless has no renderer to do it with. A small window opens and closes.
##
##   OR_BG_SIZE   pixels, "WIDTHxHEIGHT" (default 1920x1080)
##   OR_BG_OUT    where to write the PNG, relative to the project
##   OR_BG_WAIT   seconds to let the shader and the dust settle (default 3.0)
##   OR_BG_HUE    base hue, 0..1 (default 0.985, the game's blood red)
##   OR_BG_DUST   "0" to leave the drifting particles out

const SETTLE := 3.0


func _ready() -> void:
	var size := _size()
	var out := OS.get_environment("OR_BG_OUT")
	if out == "":
		out = "user://shots/bg.png"

	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)

	var bg := BackgroundFX.new(OS.get_environment("OR_BG_DUST") != "0")
	var hue := OS.get_environment("OR_BG_HUE")
	if hue != "":
		bg.base_hue = clampf(float(hue), 0.0, 1.0)
	vp.add_child(bg)
	_fit(bg, Vector2(size))

	var wait := SETTLE
	if OS.get_environment("OR_BG_WAIT") != "":
		wait = float(OS.get_environment("OR_BG_WAIT"))
	await get_tree().create_timer(wait, true).timeout
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	if img == null:
		printerr("nothing rendered - is there a display?")
		get_tree().quit(1)
		return
	var path := out if out.begins_with("user://") or out.begins_with("res://") \
		else "res://" + out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		printerr("could not write %s (%d)" % [path, err])
		get_tree().quit(1)
		return
	print("BG_SAVED %s  %dx%d" % [ProjectSettings.globalize_path(path),
		img.get_width(), img.get_height()])
	get_tree().quit()


## The background sizes itself to the game's canvas when it is built, and in
## here there is no game canvas - only the viewport it was handed. Same sums,
## against the size that actually matters.
func _fit(bg: BackgroundFX, size: Vector2) -> void:
	bg.rect.size = size * 1.25
	bg.rect.position = -size * 0.125
	bg.mat.set_shader_parameter("res", bg.rect.size)
	for c in bg.get_children():
		if c is CPUParticles2D:
			var p := c as CPUParticles2D
			p.position = Vector2(size.x * 0.5, size.y + 20.0)
			p.emission_rect_extents = Vector2(size.x * 0.62, 10.0)
			# the dust is tuned for a 1280-wide canvas; a banner four times as
			# wide with the same forty specks in it reads as empty
			p.amount = clampi(int(40.0 * size.x / 1280.0), 40, 400)
			p.restart()


func _size() -> Vector2i:
	var spec := OS.get_environment("OR_BG_SIZE")
	if spec.contains("x"):
		var parts := spec.split("x")
		if parts.size() == 2:
			return Vector2i(maxi(int(parts[0]), 16), maxi(int(parts[1]), 16))
	return Vector2i(1920, 1080)
