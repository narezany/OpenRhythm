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
##   OR_BG_LOGO   "1" to put the game's wordmark in the middle of it
##   OR_BG_LOGO_W how much of the width the wordmark takes (default 0.78)
##   OR_BG_ALPHA  "1" for a transparent picture with no background in it
##   OR_BG_MARK   "1" for the playfield in miniature - frame, grid, one cube

const SETTLE := 3.0


func _ready() -> void:
	var size := _size()
	var out := OS.get_environment("OR_BG_OUT")
	if out == "":
		out = "user://shots/bg.png"

	var bare := OS.get_environment("OR_BG_ALPHA") == "1"
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = bare
	add_child(vp)

	if not bare:
		var bg := BackgroundFX.new(OS.get_environment("OR_BG_DUST") != "0")
		var hue := OS.get_environment("OR_BG_HUE")
		if hue != "":
			bg.base_hue = clampf(float(hue), 0.0, 1.0)
		vp.add_child(bg)
		_fit(bg, Vector2(size))
	if OS.get_environment("OR_BG_MARK") == "1":
		vp.add_child(_mark(Vector2(size)))
	if OS.get_environment("OR_BG_LOGO") == "1":
		vp.add_child(_logo(Vector2(size), bare))

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


## The wordmark from the main menu, in the middle of the picture.
##
## The same label the menu builds - Orbitron at weight 850, the same near-white
## - and not a picture of it, so a cover cannot end up showing a logo the game
## stopped using. Only the size is worked out here: the menu sets 64 against a
## canvas 1280 across, and a cover is a different shape, so the type is scaled
## to take a fixed share of the width instead.
## The playfield in miniature: the frame the game plays inside, its grid, and
## one cube sitting in the middle cell. For an icon that has to survive being
## drawn at sixteen pixels, this is the game's own shape - a square with
## something in it - rather than a wordmark nobody could read at that size.
func _mark(size: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = size * 0.5
	var k: float = size.x * 0.86 / (G.FRAME_HALF * 2.0)
	root.scale = Vector2(k, k)

	var frame := FrameView.new()
	frame.grid_alpha = 0.16      # brighter than in play: nothing else is lit
	root.add_child(frame)

	var cube := NoteView.new()
	# a cube at playing size disappears at icon sizes, so this one is the size
	# the shape needs to be rather than the size the game gives it
	cube.half = 112.0
	cube.progress = 1.0
	root.add_child(cube)
	cube.set_color(Color.WHITE)
	return root


func _logo(size: Vector2, outlined := false) -> Label:
	var want := 0.78
	if OS.get_environment("OR_BG_LOGO_W") != "":
		want = clampf(float(OS.get_environment("OR_BG_LOGO_W")), 0.2, 1.0)
	var text := "Open Rhythm"
	var at64 := G.font_logo.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	var fs := 64
	if at64 > 1.0:
		fs = maxi(8, int(round(64.0 * size.x * want / at64)))
	var lab := G.label(text, fs, Color(1, 1, 1, 0.97), true)
	if outlined:
		# a white wordmark on a transparent background disappears the moment
		# somebody puts it on a white page, and itch says it has to survive
		# that. A dark edge costs nothing on black and saves it on white.
		lab.add_theme_constant_override("outline_size", maxi(2, int(fs * 0.07)))
		lab.add_theme_color_override("font_outline_color", Color(0.05, 0.012, 0.02, 0.9))
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size = size
	lab.position = Vector2.ZERO
	return lab


func _size() -> Vector2i:
	var spec := OS.get_environment("OR_BG_SIZE")
	if spec.contains("x"):
		var parts := spec.split("x")
		if parts.size() == 2:
			return Vector2i(maxi(int(parts[0]), 16), maxi(int(parts[1]), 16))
	return Vector2i(1920, 1080)
