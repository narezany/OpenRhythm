extends Node
## G — global constants, theme helpers, save data, sfx pool.

const DESIGN := Vector2(1280, 720)
const FRAME_HALF := 250.0
const CELL := 166.0            # spacing of the 3x3 note grid
const SAVE_PATH := "user://save.json"
## Semantic version, matched against the tag of a GitHub release by the
## updater. Bump it in the same commit as the tag.
const VERSION := "0.3.1"
const REPO := "narezany/OpenRhythm"

# --- heavy black & blood-red palette ---
const C_PRIMARY := Color("ff2b3a")   # blood red — main accent
const C_EMBER := Color("ff7a45")     # ember orange-red — secondary accent
const C_BLOOD := Color("9c1022")     # deep blood red — shadows / rare accent
const C_GOLD := Color("ffb547")      # warm gold — good state
const C_AMBER := Color("ff8c2e")     # deep amber — mid state
const C_TEXT := Color("f2e8e4")      # warm off-white
const C_MUTED := Color("a3908c")     # warm gray

const JUDGE_COLORS := {
	"PERFECT": Color("fff1e8"),
	"GREAT": Color("ff4653"),
	"GOOD": Color("ffb547"),
	"BULLSHIT": Color("7a6f5a"),
	"MISS": Color("8d96a0"),
}

var font_body: Font
var font_bold: Font
var font_logo: Font

var main: Node = null
var results: Dictionary = {}
var selected_song: Dictionary = {}
var selected_diff := 0
var custom_test := {}       # {"song": Dictionary, "notes": Array, "name": String}
var return_screen := ""     # "editor": go back to the editor after a run
var editor_song: Dictionary = {}
# story mode: songs played back to back
var story_playlist: Array = []
var story_idx := 0
var story_diff := 0
var editor_diff := 0

var autoplay := false
var shot_mode := ""
var shot_seek := 0.0

## Replay of the last run, or the one being watched when replay_mode is on.
var replay = null
var replay_mode := false

var master_vol := 0.9
var music_vol := 0.85
var sfx_vol := 0.9
var hitsound := true
## Judgement offset in seconds. Positive means the player hears the audio late,
## so note times are shifted later to match. Set by the calibration screen.
var audio_offset := 0.0

# --- video ---
var fullscreen := false
var vsync := true
var max_fps := 0                 # 0 = unlimited

# --- accessibility ---
var reduce_motion := false       # damps camera shake, zoom, parallax, rotation
var reduce_flashes := false      # damps full-screen flashes and strobing
var disable_song_video := false
var cursor_scale := 1.0

# --- input ---
var gamepad_speed := 950.0       # cursor px/sec at full stick deflection
var key_binds := {}              # action name -> [physical keycode, ...]

# --- misc ---
var locale := ""
var disclaimer_seen := false
var check_updates := true

# --- lifetime stats ---
var stat_plays := 0
var stat_notes := 0
var stat_best_combo := 0
var stat_playtime := 0.0
var unlocked := []               # achievement ids

# --- active modifier ids for this run, see MODS ---
var active_mods: Array = []

# --- settings: cursor sensitivity (touch), disabled song ids ---
var mouse_sens := 1.0
var relative_touch := false      # Android: the finger moves the cursor relatively
var touch_zone := false          # true while in the game or the editor
var disabled_songs: Array = []

# --- VR: the same build runs flat or in a headset, whichever is there ---
## Extra delay on the hitsound, seconds. The game already hands the sound over
## one audio-device latency early, but a phone's driver often under-reports how
## far behind it really is, and no measurement here can see that. Positive
## values fire the hitsound earlier.
var hit_offset := 0.0
var vr_start := "auto"           # "auto" enters VR when a runtime is up, "off" never
var vr_style := "pointer"        # "pointer" aims a laser, "saber" cuts with a blade
var vr_active := false           # true once a headset has actually taken over

# --- Melly: per-body-part colours, chosen from presets in the settings ---
var melly_colors := {
	"torso": Color("8a3fd1"),
	"head": Color("f2e8e4"),
	"arm_l": Color("f2e8e4"),
	"arm_r": Color("f2e8e4"),
	"leg_l": Color("1a1a1d"),
	"leg_r": Color("1a1a1d"),
}
var melly = null   # the MellyRig currently on screen, if any


# ---------------------------------------------------------------- adaptive layout
## Layout mode for the window's real aspect ratio - the design is never
## squashed. "wide" is 16:9 as designed, "narrow" is taller than 16:9 so side
## panels move inwards, "ultrawide" has spare room at the sides.
var view_w := 1280.0
var view_h := 720.0

signal view_changed


func aspect_ratio() -> float:
	return view_w / maxf(view_h, 1.0)


func layout_mode() -> String:
	var a := aspect_ratio()
	if a < 1.45:
		return "narrow"
	if a <= 1.85:
		return "wide"
	return "ultrawide"


## Stick a control to the right edge of the visible area (fill can crop it).
func stick_right(c: Control, margin := 0.0) -> void:
	var vis := visible_rect_design()
	c.position.x = vis.end.x - c.size.x - margin


## Stick a control to the bottom of the visible area.
func stick_bottom(c: Control, margin := 0.0) -> void:
	var vis := visible_rect_design()
	c.position.y = vis.end.y - c.size.y - margin


## Visible canvas in design units. With stretch aspect "expand" the scale is
## min(w/1280, h/720) and the canvas simply grows past the design size on the
## long axis - nothing is cropped and nothing is squashed. So the origin is
## always (0,0) and the size is at least DESIGN, larger on one axis.
func visible_rect_design() -> Rect2:
	var sc := minf(view_w / DESIGN.x, view_h / DESIGN.y)
	if sc <= 0.0001:
		return Rect2(Vector2.ZERO, DESIGN)
	return Rect2(0.0, 0.0, view_w / sc, view_h / sc)


## Canvas size in design units. Anything meant to cover the screen must use
## this, never DESIGN, or it leaves a gap on a phone.
func canvas_size() -> Vector2:
	return visible_rect_design().size


# ---------------------------------------------------------------- anchoring
## Anchor helpers. A control anchored this way follows the canvas on its own,
## with no per-frame relayout, which is what keeps things from jumping around
## when the window changes size.

## Full-bleed: dims, background rects, post-process overlays.
func anchor_full(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


## Full canvas width at a fixed distance from the top - centred text stays
## centred at any window size.
func anchor_top_wide(c: Control, top: float, height: float, margin := 0.0) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = margin
	c.offset_right = -margin
	c.offset_top = top
	c.offset_bottom = top + height


## Full canvas width at a fixed distance from the bottom.
func anchor_bottom_wide(c: Control, up: float, height: float, margin := 0.0) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = margin
	c.offset_right = -margin
	c.offset_top = -up - height
	c.offset_bottom = -up


## A fixed-size control centred horizontally and pinned to the bottom.
func anchor_bottom_center(c: Control, up: float, size: Vector2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = -size.x * 0.5
	c.offset_right = size.x * 0.5
	c.offset_top = -up - size.y
	c.offset_bottom = -up


## A fixed-size control offset from the horizontal centre of the canvas.
func anchor_center_x(c: Control, dx: float, top: float, size: Vector2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = dx
	c.offset_right = dx + size.x
	c.offset_top = top
	c.offset_bottom = top + size.y


## A control that follows the canvas with fixed margins on every side.
func anchor_margins(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = l
	c.offset_top = t
	c.offset_right = -r
	c.offset_bottom = -b


## Pin a fixed-size control to a corner or edge of the canvas.
func anchor_corner(c: Control, right: bool, bottom: bool, mx: float, my: float,
		size: Vector2) -> void:
	c.anchor_left = 1.0 if right else 0.0
	c.anchor_right = c.anchor_left
	c.anchor_top = 1.0 if bottom else 0.0
	c.anchor_bottom = c.anchor_top
	c.offset_left = (-size.x - mx) if right else mx
	c.offset_right = c.offset_left + size.x
	c.offset_top = (-size.y - my) if bottom else my
	c.offset_bottom = c.offset_top + size.y


func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("mobile") \
		or OS.has_feature("web_android") or OS.has_feature("ios")


## 1234567 -> "1 234 567"
func fmt_score(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

# --- lifetime score: every play adds up, replay freely ---
var total_score := 0

var best := {}

var halo_tex: Texture2D
var part_tex: Texture2D
var mat_add := CanvasItemMaterial.new()

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_fonts()
	_make_textures()
	_setup_buses()
	_load_sfx()
	_load_save()
	Binds.apply(key_binds)
	apply_video()
	shot_mode = OS.get_environment("OR_SHOT")
	autoplay = OS.get_environment("OR_AUTOPLAY") != "" or shot_mode == "game"
	shot_seek = float(OS.get_environment("OR_SEEK")) if OS.get_environment("OR_SEEK") != "" else 0.0
	if shot_mode != "":
		_schedule_shot()


# ---------------------------------------------------------------- fonts
func _load_fonts() -> void:
	font_body = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	font_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	var orb: Font = load("res://assets/fonts/Orbitron-Variable.ttf")
	if orb != null:
		var fv := FontVariation.new()
		fv.base_font = orb
		fv.variation_opentype = {"wght": 850}
		font_logo = fv
	else:
		font_logo = font_bold
	if font_body == null:
		font_body = ThemeDB.fallback_font
	if font_bold == null:
		font_bold = ThemeDB.fallback_font
	if font_logo == null:
		font_logo = font_bold


func _make_textures() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.55))
	g.set_color(1, Color(1, 1, 1, 0.0))
	halo_tex = GradientTexture2D.new()
	(halo_tex as GradientTexture2D).gradient = g
	(halo_tex as GradientTexture2D).fill = GradientTexture2D.FILL_RADIAL
	(halo_tex as GradientTexture2D).fill_from = Vector2(0.5, 0.5)
	(halo_tex as GradientTexture2D).fill_to = Vector2(0.5, 0.0)
	(halo_tex as GradientTexture2D).width = 256
	(halo_tex as GradientTexture2D).height = 256
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for x in 12:
		for y in 12:
			var d := float(mini(mini(x, y), mini(11 - x, 11 - y)) + 1)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(d / 3.0, 0.0, 1.0)))
	part_tex = ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- audio
func _setup_buses() -> void:
	while AudioServer.get_bus_count() < 3:
		AudioServer.add_bus()
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_name(2, "SFX")
	set_master_volume(master_vol)
	set_music_volume(music_vol)
	set_sfx_volume(sfx_vol)


func set_master_volume(v: float) -> void:
	master_vol = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_vol, 0.0001)))
	AudioServer.set_bus_mute(0, master_vol <= 0.001)


func set_music_volume(v: float) -> void:
	music_vol = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(1, linear_to_db(maxf(music_vol, 0.0001)))
	AudioServer.set_bus_mute(1, music_vol <= 0.001)


func set_sfx_volume(v: float) -> void:
	sfx_vol = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(2, linear_to_db(maxf(sfx_vol, 0.0001)))
	AudioServer.set_bus_mute(2, sfx_vol <= 0.001)


func _load_sfx() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	for n in ["hit", "miss", "click"]:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)


func play_sfx(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not _sfx.has(name):
		return
	var player: AudioStreamPlayer = null
	for p in _sfx_pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _sfx_pool[0]
	player.stream = _sfx[name]
	player.pitch_scale = pitch
	player.volume_db = vol_db
	player.play()


# ---------------------------------------------------------------- save data
func _load_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				best = data.get("best", {})
				total_score = int(data.get("total_score", 0))
				mouse_sens = float(data.get("mouse_sens", 1.0))
				relative_touch = bool(data.get("relative_touch", false))
				disabled_songs = data.get("disabled_songs", [])
				hit_offset = float(data.get("hit_offset", 0.0))
				vr_start = str(data.get("vr_start", "auto"))
				vr_style = str(data.get("vr_style", "pointer"))
				master_vol = float(data.get("master_vol", master_vol))
				music_vol = float(data.get("music_vol", music_vol))
				sfx_vol = float(data.get("sfx_vol", sfx_vol))
				hitsound = bool(data.get("hitsound", hitsound))
				audio_offset = float(data.get("audio_offset", 0.0))
				fullscreen = bool(data.get("fullscreen", false))
				vsync = bool(data.get("vsync", true))
				max_fps = int(data.get("max_fps", 0))
				reduce_motion = bool(data.get("reduce_motion", false))
				reduce_flashes = bool(data.get("reduce_flashes", false))
				disable_song_video = bool(data.get("disable_song_video", false))
				cursor_scale = float(data.get("cursor_scale", 1.0))
				gamepad_speed = float(data.get("gamepad_speed", 950.0))
				locale = str(data.get("locale", ""))
				disclaimer_seen = bool(data.get("disclaimer_seen", false))
				check_updates = bool(data.get("check_updates", true))
				stat_plays = int(data.get("stat_plays", 0))
				stat_notes = int(data.get("stat_notes", 0))
				stat_best_combo = int(data.get("stat_best_combo", 0))
				stat_playtime = float(data.get("stat_playtime", 0.0))
				unlocked = data.get("unlocked", [])
				var kb: Dictionary = data.get("key_binds", {})
				for act in kb:
					var arr: Array = []
					for kc in kb[act]:
						arr.append(int(kc))
					key_binds[act] = arr
				var mc: Dictionary = data.get("melly_colors", {})
				for part in MellyRig.PARTS:
					if mc.has(part):
						melly_colors[part] = Color(str(mc[part]))
		# volumes come from the save, so the buses need re-applying
		set_master_volume(master_vol)
		set_music_volume(music_vol)
		set_sfx_volume(sfx_vol)


func save_all() -> void:
	var mc := {}
	for part in MellyRig.PARTS:
		mc[part] = melly_colors[part].to_html(false)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"best": best, "total_score": total_score,
			"mouse_sens": mouse_sens, "relative_touch": relative_touch,
			"disabled_songs": disabled_songs,
			"hit_offset": hit_offset,
			"vr_start": vr_start, "vr_style": vr_style,
			"melly_colors": mc,
			"master_vol": master_vol, "music_vol": music_vol, "sfx_vol": sfx_vol,
			"hitsound": hitsound, "audio_offset": audio_offset,
			"fullscreen": fullscreen, "vsync": vsync, "max_fps": max_fps,
			"reduce_motion": reduce_motion, "reduce_flashes": reduce_flashes,
			"disable_song_video": disable_song_video, "cursor_scale": cursor_scale,
			"gamepad_speed": gamepad_speed, "key_binds": key_binds,
			"locale": locale, "disclaimer_seen": disclaimer_seen,
			"check_updates": check_updates,
			"stat_plays": stat_plays, "stat_notes": stat_notes,
			"stat_best_combo": stat_best_combo, "stat_playtime": stat_playtime,
			"unlocked": unlocked,
		}, "\t"))


func add_total_score(v: int) -> void:
	total_score += v
	save_all()


# ---------------------------------------------------------------- video / a11y
func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not is_mobile():
		# borderless fullscreen, not exclusive: an exclusive window owns the
		# display, so a screenshot editor or a file manager opened on top of the
		# game could not be reached
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN \
			if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync \
		else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = maxi(max_fps, 0)


## Multiplier for camera shake, zoom punch, rotation and parallax.
func motion() -> float:
	return 0.2 if reduce_motion else 1.0


## Multiplier for full-screen flashes and strobing background pulses.
func flashes() -> float:
	return 0.12 if reduce_flashes else 1.0


func set_locale(code: String) -> void:
	var changed := code != locale
	locale = code
	Loc.apply(code)
	save_all()
	if changed:
		Achievements.unlock("polyglot")


func note_hit_stat(combo: int) -> void:
	stat_notes += 1
	stat_best_combo = maxi(stat_best_combo, combo)


func get_best(song_id: String, diff: String) -> Dictionary:
	if best.has(song_id) and best[song_id] is Dictionary and best[song_id].has(diff):
		return best[song_id][diff]
	return {}


func save_best(song_id: String, diff: String, score: int, acc: float, combo: int) -> bool:
	if not best.has(song_id) or not (best[song_id] is Dictionary):
		best[song_id] = {}
	var cur: Dictionary = get_best(song_id, diff)
	if not cur.is_empty() and float(cur.get("score", 0)) >= score:
		return false
	best[song_id][diff] = {"score": score, "acc": acc, "combo": combo}
	save_all()
	return true


## Modifiers: id, label, score multiplier (applied on earn), description.
const MODS := [
	{"id": "target", "label": "TARGET", "mult": 0.80,
		"desc": "Highlights the nearest upcoming note and switches the highlight to it after each hit. -20% score."},
	{"id": "fade", "label": "BLACKOUT", "mult": 1.25,
		"desc": "Cubes turn invisible shortly before reaching you — memorize them. +25% score."},
	{"id": "cage", "label": "CAGE", "mult": 0.90,
		"desc": "Your cursor is locked inside the frame for the whole song. -10% score."},
	{"id": "speed", "label": "SPEED UP", "mult": 1.30, "rate": 1.4,
		"desc": "The whole song plays 1.4x faster. +30% score."},
	{"id": "slow", "label": "SLOW DOWN", "mult": 0.70, "rate": 0.75,
		"desc": "The whole song plays at 0.75x. Good for learning a chart. -30% score."},
	{"id": "mirror", "label": "MIRROR", "mult": 1.0,
		"desc": "The grid is mirrored left to right. Same score."},
	{"id": "hidden", "label": "HIDDEN", "mult": 1.20,
		"desc": "No outline guides for upcoming notes. +20% score."},
	{"id": "clicks_on", "label": "CLICKS", "mult": 1.15, "needs_clicks": true,
		"desc": "Play the click notes the mapper put in this chart. +15% score."},
	{"id": "clicky", "label": "CLICKY", "mult": 1.40,
		"desc": "Every cube has to be clicked, not just covered. +40% score."},
]

## SPEED UP and SLOW DOWN are mutually exclusive.
const MOD_CONFLICTS := [["speed", "slow"]]


static func mod_mult(mods: Array) -> float:
	var m := 1.0
	for id in mods:
		for md in MODS:
			if md.id == id:
				m *= float(md.mult)
	return m


## Playback rate implied by the active modifiers.
static func mod_rate(mods: Array) -> float:
	for id in mods:
		for md in MODS:
			if md.id == id and md.has("rate"):
				return float(md.rate)
	return 1.0


## Mirror a grid cell index horizontally (0..8).
static func mirror_cell(idx: int) -> int:
	var col := idx % 3
	var row := int(idx / 3.0)
	return row * 3 + (2 - col)


# ---------------------------------------------------------------- 3x3 note grid
static func cell_pos(idx: int) -> Vector2:
	var col := idx % 3 - 1
	var row := int(idx / 3.0) - 1
	return Vector2(col * CELL, row * CELL)


static func cell_index(local: Vector2) -> int:
	var cx := clampi(roundi(local.x / CELL), -1, 1)
	var cy := clampi(roundi(local.y / CELL), -1, 1)
	return (cy + 1) * 3 + (cx + 1)


## Legacy maps store a direction angle; snap it to the nearest grid cell.
static func angle_to_cell(a_deg: float) -> int:
	var rad := deg_to_rad(a_deg)
	var dir := Vector2(sin(rad), -cos(rad))
	var cx := clampi(roundi(dir.x * 1.5), -1, 1)
	var cy := clampi(roundi(dir.y * 1.5), -1, 1)
	return (cy + 1) * 3 + (cx + 1)


# ---------------------------------------------------------------- screenshots (dev)
func _schedule_shot() -> void:
	var wait := 2.2
	# OR_SHOT_WAIT holds the window open longer, which is what makes it
	# possible to size it from outside before the frame is grabbed
	var forced := OS.get_environment("OR_SHOT_WAIT")
	match shot_mode:
		"select": wait = 2.6
		"game": wait = 5.5 + shot_seek * 0.0
		"results": wait = 2.6
		"editor": wait = 2.6
	if forced != "":
		wait = float(forced)
	await get_tree().create_timer(wait, true).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		DirAccess.make_dir_recursive_absolute("user://shots")
		var path := "user://shots/or_%s.png" % shot_mode
		img.save_png(path)
		print("SHOT_SAVED ", ProjectSettings.globalize_path(path))
	# dev: a burst of frames for checking Melly's animation
	if shot_mode == "game" and OS.get_environment("OR_MELLY_SEQ") != "":
		for i in 4:
			await get_tree().create_timer(0.5, true).timeout
			await RenderingServer.frame_post_draw
			var im2 := get_viewport().get_texture().get_image()
			if im2 != null:
				im2.save_png("user://shots/melly_seq_%d.png" % i)
				print("SEQ_SAVED ", i)
	get_tree().quit()


# ---------------------------------------------------------------- UI helpers
func label(text: String, size: int, color: Color = C_TEXT, logo := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_logo if logo else font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func button(text: String, cb: Callable, font_size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color("ff8d8d"))
	b.add_theme_color_override("font_pressed_color", C_EMBER)
	b.add_theme_color_override("font_focus_color", C_TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.058, 0.012, 0.022, 0.90)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.35)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.10, 0.022, 0.038, 0.95)
	sb_hover.border_color = Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.95)
	var sb_pressed := sb.duplicate()
	sb_pressed.bg_color = Color(0.035, 0.007, 0.014, 0.95)
	sb_pressed.border_color = Color(C_EMBER.r, C_EMBER.g, C_EMBER.b, 0.85)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.add_theme_stylebox_override("pressed", sb_pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b


func panel_style(border := Color(0.0, 0.0, 0.0, 0.0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.042, 0.008, 0.016, 0.86)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = border if border.a > 0.0 \
		else Color(C_PRIMARY.r, C_PRIMARY.g, C_PRIMARY.b, 0.28)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	return sb


# ---------------------------------------------------------------- drawing
func rounded_points(rect: Rect2, r: float, seg := 5) -> PackedVector2Array:
	r = minf(r, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5, 0.0],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0, PI * 0.5],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5, PI],
		[Vector2(rect.position.x + r, rect.position.y + r), PI, PI * 1.5],
	]
	for c in corners:
		for i in seg + 1:
			var a: float = c[1] + (c[2] - c[1]) * float(i) / float(seg)
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


func draw_rounded_rect(cv: CanvasItem, rect: Rect2, r: float, color: Color) -> void:
	cv.draw_colored_polygon(rounded_points(rect, r), color)


func draw_rounded_outline(cv: CanvasItem, rect: Rect2, r: float, color: Color, width := 2.0) -> void:
	var pts := rounded_points(rect, r)
	pts.append(pts[0])
	cv.draw_polyline(pts, color, width, true)
