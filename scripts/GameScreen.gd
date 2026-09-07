class_name GameScreen
extends Node2D
## "Square" mode: white cubes fly toward the 3x3 grid inside the frame and the
## cursor must sit on the cube when it lands. A cube with a hold length keeps
## going after it lands - stay in the cell until it runs out. Modifiers change
## the score multiplier; a song video plays behind the playfield when present.

const APPROACH := 1.0        # cube flight time, sec
const GUIDE_AHEAD := 3.0     # how early the next-target outline shows
const PARALLAX := 26.0       # camera follows the cursor by up to this many px
const FADE_LEAD := 0.80      # BLACKOUT: seconds before hit when cubes vanish
## Saber play has no long notes; a hold becomes a run of ordinary cubes this
## far apart, in the same cell.
const SABER_REPEAT := 0.16

## Health, which only exists in a story.
##
## Free play cannot be lost - a bad run there is a bad score, and that is what
## practice is. A story can be, and what decides it is misses rather than
## accuracy: accuracy is a verdict on the whole run delivered at the end, while
## a health bar is something you can watch going and do something about.
##
## The hardest difficulty gives you MISS_BUDGET_HARD misses in a row before the
## bar is empty; the easiest gives you MISS_BUDGET_EASY, because the same seven
## on a chart nobody can read yet is not a challenge but a wall. Landing notes
## puts it back, a quarter of a miss at a time, so a bad patch you recover from
## is survivable and a bad patch you do not is not.
const MISS_BUDGET_HARD := 7.0
const MISS_BUDGET_EASY := 14.0
const HEAL_SHARE := 0.25

var song: Dictionary
var diff_name := ""
var notes: Array = []
var active: Array = []
var idx := 0
var ended := false
var paused := false

var score := 0
var combo := 0
var max_combo := 0
var acc_sum := 0.0
var acc_n := 0
var counts := {"PERFECT": 0, "GREAT": 0, "GOOD": 0, "BULLSHIT": 0, "MISS": 0}

## 1.0 full, 0.0 dead. Meaningless outside a story - see _story_run.
var health := 1.0
var _story_run := false
var _miss_cost := 1.0 / MISS_BUDGET_HARD
var _dead := false
var health_bar: HealthDraw = null

var trauma := 0.0
var flash := 0.0
var miss_flash := 0.0
var milestone := 0.0
var kick_env := 0.0
var alt_sign := 1.0
var last_bar := -1

var combo_scale := 1.0
var last_score := -1
var _guide_idx := 0
var _target_note: Dictionary = {}   # TARGET modifier: currently highlighted

var bg: BackgroundFX
var video: SongVideo
var cam: Camera2D
var frame_view: FrameView
var ghost_layer: GhostLayer
var shock: ShockLayer
var texts: FloatTextLayer
var notes_root: Node2D
var post_mat: ShaderMaterial

var hud_score: Label
var hud_acc: Label
var hud_combo: Label
var melly_host: CanvasLayer
var acc_fill: ColorRect
var acc_bg: ColorRect
var progress_bar: ProgressDraw
var pause_layer: CanvasLayer
var hud_versus: Label

var _last_note_t := 0.0
var _go_shown := false
var _tut_hint_i := -1
var _tut_hint_label: Label = null
var _is_tutorial := false
var _replay: Replay = null
var _play_rate := 1.0
var _elapsed := 0.0
## Set by input for exactly one frame: a click note resolves on the press, not
## on the cursor merely being in the right place.
var _click_edge := false
## How far the audio device is behind us. A sound handed to it now is heard
## this much later, so every hitsound has to be handed over that early or the
## game ends up tapping just behind its own music.
var _out_lat := 0.0
var _prev_time := 0.0
var _had_focus := false
## Centre of the playfield in canvas units. On anything that is not 16:9 the
## canvas is bigger than the design, so this is not DESIGN / 2.
var field_center := G.DESIGN / 2.0

## Map scripting: a timeline of events the song brings with it.
var script_: SongScript = null
var script_layer: Node2D
var script_image: TextureRect
var _note_skin: Texture2D = null
var _note_scale := 1.0
var _zoom_extra := 1.0

## Teaching hints come from the song's own map.json, so their timing cannot
## drift away from the chart they explain.
var _hints: Array = []


func _ready() -> void:
	# clamped: a broken driver can report an absurd figure, and a hitsound half
	# a second early is worse than one slightly late
	_out_lat = clampf(AudioServer.get_output_latency(), 0.0, 0.12)
	# A story is the only place a run can be lost, and it has to be known before
	# the HUD is built - the bar is not there at all in free play.
	_story_run = not G.story_playlist.is_empty() and not G.replay_mode \
		and G.custom_test.is_empty()
	if G.custom_test.is_empty():
		song = G.selected_song
		var diffs := RhythmMap.diffs_of(song)
		var pick := clampi(G.selected_diff, 0, diffs.size() - 1)
		var d: Dictionary = diffs[pick]
		diff_name = str(d.get("name", "?"))
		_set_miss_budget(pick, diffs.size())
		_load_notes(d.get("notes", []), G.shot_seek)
	else:
		song = G.custom_test["song"]
		diff_name = str(G.custom_test.get("name", "Custom"))
		_load_notes(G.custom_test["notes"], 0.0)
	_play_rate = G.mod_rate(G.active_mods)
	_build()
	# Anything the map sets up at or before the first instant is applied now,
	# before a single cube exists. A skin chosen at t=0 has to be on the first
	# cube, not on the first cube after the song reaches zero.
	if script_ != null and not script_.is_empty():
		_run_script(0.0)
	if not G.replay_mode and G.custom_test.is_empty():
		_replay = Replay.new()
		_replay.start(song, diff_name, G.active_mods)
	var stream := RhythmMap.audio_stream(song)
	Conductor.play_music(stream, G.shot_seek, float(song.get("bpm", 120.0)),
		0.0, false, _play_rate)
	G.shot_seek = 0.0


# ---------------------------------------------------------------- data
func _load_notes(raw: Array, seek: float) -> void:
	var mirror: bool = "mirror" in G.active_mods
	# Click notes are opt-in: a chart may carry them, but they only come alive
	# with the CLICKS modifier. Playing without it costs nothing. The tutorial
	# is the exception - it is where clicks are taught, so they are always on.
	var clicky: bool = "clicky" in G.active_mods
	var use_marked: bool = "clicks_on" in G.active_mods \
		or str(song.get("id", "")) == "tutorial"
	for nd in raw:
		var t := float(nd.get("t", 0.0))
		if t < seek + 0.2:
			continue
		var d := clampf(float(nd.get("d", 0.35)), 0.0, 1.0)
		var s := maxf(float(nd.get("s", 1.0)), 0.4)
		var cell := G.angle_to_cell(float(nd.get("a", 0.0)))
		if nd.has("cell"):
			cell = wrapi(int(nd.get("cell", 0)), 0, 9)
		if mirror:
			cell = G.mirror_cell(cell)
		var hold := maxf(float(nd.get("h", 0.0)), 0.0)
		var tex := str(nd.get("tex", ""))
		var click: bool = clicky or (use_marked and bool(nd.get("c", false)))
		var hit := G.cell_pos(cell)
		notes.append({
			"t": t, "cell": cell, "d": d, "s": s, "h": hold, "click": click,
			"tex": tex,
			"half": 52.0 * s, "base_half": 52.0 * s,
			"hit": hit,
			"spawn": hit * (0.10 + 0.22 * d),
			"color": Color.WHITE,
			"gcol": G.C_PRIMARY,
			"spin": randf_range(0.5, 1.1) * (1.0 if randf() > 0.5 else -1.0),
			"progress": 0.0, "done": false, "hover": false, "node": null,
			"holding": false, "held": 0.0, "slipped": 0.0, "broken": false,
			"base_acc": 0.0, "base_label": "",
		})
	notes.sort_custom(func(a, b): return a.t < b.t)
	_saber_chart()
	if not notes.is_empty():
		_last_note_t = notes[-1].t + float(notes[-1].h)


## Saber play has no long notes.
##
## Holding a cursor still is a mouse idea - there is nothing to hold with a
## sword, and a hold in a headset comes out as a long box you have to keep the
## blade parked inside, which is neither fun nor anything a sword does. So a
## hold becomes the thing a sword is for: a short run of ordinary cubes in the
## same cell, close enough together that clearing it means swinging hard at one
## spot. Click notes are left alone; in VR they have their own answer.
##
## This changes the chart, and so the number of notes and what a full score is
## worth. That is the point rather than a side effect - it is a different way
## of playing the same song, and it only happens in a headset holding sabers.
func _saber_chart() -> void:
	if not (G.vr_active and G.vr_style == "saber"):
		return
	var out: Array = []
	var made := 0
	for n in notes:
		var h := float(n.get("h", 0.0))
		if h <= 0.0 or bool(n.get("click", false)):
			out.append(n)
			continue
		# capped, or a ten-second hold would become a wall nobody can swing
		# through and the chart would stop being the chart
		var count := clampi(int(round(h / SABER_REPEAT)) + 1, 2, 16)
		var step := h / float(count - 1)
		for k in count:
			var c: Dictionary = n.duplicate(true)
			c["t"] = float(n.t) + step * float(k)
			c["h"] = 0.0
			out.append(c)
		made += count - 1
	if made == 0:
		return
	notes = out
	notes.sort_custom(func(a, b): return a.t < b.t)
	G.dev_log("saber chart: holds opened out into %d extra cubes" % made)


# ---------------------------------------------------------------- build
func _build() -> void:
	_is_tutorial = str(song.get("id", "")) == "tutorial"
	# A saber is taught differently from a cursor, so the tutorial has a second
	# script of its own. Falls back to the written one if a song only has that.
	_hints = song.get("hints", [])
	if G.vr_active and G.vr_style == "saber":
		var alt = song.get("hints_saber", [])
		if alt is Array and not alt.is_empty():
			_hints = alt
	bg = BackgroundFX.new()
	bg.base_hue = float(song.get("hue", 0.985))
	add_child(bg)

	script_ = SongScript.load_for(song)
	if not script_.is_empty():
		# A backdrop, in the same place the song video sits - it used to be a
		# CanvasLayer above the playfield, which put the picture over the notes,
		# the frame, the ranks and the HUD. A background that covers the game is
		# not a background.
		script_layer = Node2D.new()
		script_layer.z_index = -80        # above the video, behind everything else
		add_child(script_layer)
		script_image = TextureRect.new()
		script_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		script_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		script_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		script_image.modulate.a = 0.0
		script_layer.add_child(script_image)
		G.anchor_full(script_image)

	if not G.disable_song_video:
		video = SongVideo.new(song)
		add_child(video)

	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()

	ghost_layer = GhostLayer.new()
	add_child(ghost_layer)

	frame_view = FrameView.new()
	add_child(frame_view)

	notes_root = Node2D.new()
	add_child(notes_root)

	shock = ShockLayer.new()
	add_child(shock)

	texts = FloatTextLayer.new()
	add_child(texts)

	_center_field()
	G.view_changed.connect(_center_field)

	_build_post()
	_build_hud()
	_build_pause()


## Put the playfield in the middle of whatever canvas we actually got.
func _center_field() -> void:
	field_center = G.canvas_size() * 0.5
	for n in [ghost_layer, frame_view, notes_root, shock, texts]:
		if n != null and is_instance_valid(n):
			n.position = field_center
	if cam != null and is_instance_valid(cam):
		cam.position = field_center


func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	G.anchor_full(rect)
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post.gdshader")
	rect.material = post_mat
	layer.add_child(rect)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	hud_title_hud(hud)

	if _story_run:
		health_bar = HealthDraw.new()
		health_bar.size = Vector2(420, 26)
		health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(health_bar)

	progress_bar = ProgressDraw.new()
	progress_bar.position = Vector2(390, 16)
	progress_bar.size = Vector2(500, 8)
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(progress_bar)

	hud_score = G.label("0000000", 44, G.C_TEXT)
	hud_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(hud_score)
	G.anchor_corner(hud_score, true, false, 10, 6, Vector2(630, 54))

	hud_acc = G.label("100.00%", 24, G.C_MUTED)
	hud_acc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(hud_acc)
	G.anchor_corner(hud_acc, true, false, 10, 58, Vector2(630, 28))

	# accuracy bar - it tracks the running accuracy and never fails the run
	acc_bg = ColorRect.new()
	acc_bg.position = Vector2(1040, 94)
	acc_bg.size = Vector2(220, 7)
	acc_bg.color = Color(1, 1, 1, 0.10)
	acc_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(acc_bg)
	acc_fill = ColorRect.new()
	acc_fill.position = Vector2.ZERO
	acc_fill.size = Vector2(220, 7)
	acc_fill.color = G.C_GOLD
	acc_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	acc_bg.add_child(acc_fill)

	hud_combo = G.label("", 110, Color(1, 1, 1, 0.85), true)
	hud.add_child(hud_combo)

	if Net.in_match:
		hud_versus = G.label("", 22, G.C_EMBER)
		hud_versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(hud_versus)
		G.anchor_corner(hud_versus, true, false, 10, 88, Vector2(400, 26))

	var mods_txt := ""
	for id in G.active_mods:
		for md in G.MODS:
			if md.id == id:
				mods_txt += ("  •  " if mods_txt != "" else "") + str(md.label)
	if G.replay_mode:
		mods_txt = ("REPLAY  •  " + mods_txt) if mods_txt != "" else "REPLAY"
	if mods_txt != "":
		var ml := G.label(mods_txt, 18, G.C_EMBER)
		ml.position = Vector2(16, 64)
		hud.add_child(ml)

	var hint := G.label("ESC — pause", 17, Color(1, 1, 1, 0.35))
	hud.add_child(hint)
	G.anchor_corner(hint, false, true, 14, 12, Vector2(240, 22))

	melly_host = CanvasLayer.new()
	melly_host.layer = hud.layer + 1
	add_child(melly_host)
	var rig := MellyRig.new()
	rig.position = Vector2(10, 290)
	rig.size = Vector2(380, 430)
	melly_host.add_child(rig)
	_anchor_hud(rig)
	G.view_changed.connect(func(): _anchor_hud(rig))


## Adaptive HUD anchors: Melly bottom-left, accuracy bar top-right, progress top.
func _anchor_hud(rig: MellyRig) -> void:
	var vis := G.visible_rect_design()
	rig.position = Vector2(vis.position.x + 10.0, vis.end.y - rig.size.y)
	acc_bg.position = Vector2(vis.end.x - acc_bg.size.x - 20.0, 94.0)
	progress_bar.position = Vector2(vis.get_center().x - progress_bar.size.x / 2.0, 16.0)
	if health_bar != null and is_instance_valid(health_bar):
		health_bar.position = Vector2(
			vis.get_center().x - health_bar.size.x / 2.0, vis.end.y - 52.0)


func hud_title_hud(hud: CanvasLayer) -> void:
	var title := G.label(str(song.get("title", "?")), 26, G.C_TEXT)
	title.position = Vector2(16, 10)
	hud.add_child(title)
	var sub := G.label("%s  •  %s" % [str(song.get("artist", "")), diff_name], 18, G.C_MUTED)
	sub.position = Vector2(16, 38)
	hud.add_child(sub)
	if not _hints.is_empty():
		var tut := G.label("", 26, Color(1.0, 0.96, 0.90))
		G.anchor_top_wide(tut, 130, 120, 140)
		tut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tut.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tut.visible = false
		hud.add_child(tut)
		_tut_hint_label = tut


func _build_pause() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 30
	pause_layer.visible = false
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.0, 0.68)
	pause_layer.add_child(dim)
	G.anchor_full(dim)

	var center := CenterContainer.new()
	pause_layer.add_child(center)
	G.anchor_full(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", G.panel_style())
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(360, 0)
	panel.add_child(vb)

	var t := G.label("PAUSED", 42, G.C_TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)

	vb.add_child(G.button("Resume", _resume))
	vb.add_child(G.button("Restart", _retry))
	vb.add_child(G.button("Main menu", _to_menu))

	vb.add_child(_slider_row("Master volume", G.master_vol,
		func(v): G.set_master_volume(v); G.save_all()))
	vb.add_child(_slider_row("Music", G.music_vol,
		func(v): G.set_music_volume(v); G.save_all()))
	vb.add_child(_slider_row("Effects", G.sfx_vol,
		func(v): G.set_sfx_volume(v); G.save_all()))

	var chk := CheckButton.new()
	chk.text = "Hitsounds"
	chk.button_pressed = G.hitsound
	chk.add_theme_font_override("font", G.font_body)
	chk.add_theme_font_size_override("font_size", 20)
	chk.toggled.connect(func(on): G.hitsound = on; G.save_all())
	vb.add_child(chk)


func _slider_row(text: String, value: float, add_cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := G.label(text, 19, G.C_MUTED)
	l.custom_minimum_size = Vector2(180, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(160, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(add_cb)
	row.add_child(s)
	return row


# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if ended or paused:
		return
	var st := Conductor.play_time()
	_elapsed += delta

	if G.autoplay:
		_autoplay(delta)
		_click_edge = true          # autoplay presses whenever it is in place
	elif G.replay_mode and G.replay != null:
		UICursor.pos = G.replay.pos_at(st)
		_click_edge = G.replay.clicked_between(_prev_time, st)
	_prev_time = st

	# Events first, then the cubes they are meant to be dressing. Run the other
	# way round, a cube spawned on the same frame as the event that gives it a
	# skin flies its whole second wearing the default one - which read as the
	# custom notes not arriving until a second and a half into the song.
	_run_script(st)

	while idx < notes.size() and notes[idx].t - APPROACH <= st:
		_spawn(notes[idx])

	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var cursor_local: Vector2 = inv * UICursor.pos - field_center

	# CAGE: clamp cursor inside the frame
	if "cage" in G.active_mods:
		var lim := G.FRAME_HALF - 14.0
		var clamped := cursor_local.limit_length(lim)
		if clamped != cursor_local:
			cursor_local = clamped
			UICursor.pos = get_viewport().get_canvas_transform() * (clamped + field_center)

	if _replay != null:
		_replay.capture(st, UICursor.pos)
		if _click_edge:
			_replay.click(st)

	UICursor.hover_boost = 0.0

	for n in active:
		if n.done:
			continue
		if n.holding:
			_update_hold(n, cursor_local, delta, st)
			continue
		n.progress = clampf((st - (n.t - APPROACH)) / APPROACH, 0.0, 1.0)
		if n.node != null and is_instance_valid(n.node):
			n.node.progress = n.progress
			n.node.position = n.spawn.lerp(n.hit, n.progress)
			n.node.rotation = n.spin * (1.0 - n.progress) * 0.7
			n.node.scale = Vector2.ONE * (0.30 + 0.70 * pow(n.progress, 0.8))
			n.node.trail_emitting(n.progress < 0.995)
		var dt: float = st - n.t
		var near: bool = cursor_local.distance_to(n.hit) <= n.half * 1.75
		var is_click: bool = bool(n.get("click", false))
		n.hover = near
		if near:
			UICursor.hover_boost = 1.0
		# Hand the hitsound over one output latency before the cube lands, so
		# what comes out of the speakers lands on the beat instead of just
		# behind it. If the cursor leaves in those few milliseconds the sound
		# was already gone - a far smaller error than being late every time.
		if near and not is_click and dt >= -(_out_lat + G.hit_offset) and dt < 0.0 \
				and not bool(n.get("sounded", false)):
			n["sounded"] = true
			_play_hit_on_beat(dt)
		# The rank uses the BEST cursor position across the whole catch window,
		# not the first touch: brushing the edge early is fine as long as you
		# reach the centre by the time the cube lands.
		if dt < 0.0:
			# a click is allowed to land a little early - waiting for the exact
			# frame the cube touches down is not a timing anyone can hit
			if is_click and near and _click_edge and dt >= -Judge.CLICK_EARLY:
				_resolve(n, dt, cursor_local, Judge.pos_acc(cursor_local, n.hit, n.half))
		elif dt <= Judge.LAND_GRACE:
			if near:
				# The hitsound belongs to the music, not to the bookkeeping: it
				# fires the moment the cube lands under the cursor. Judgement
				# can still resolve up to LAND_GRACE later, and playing the
				# sound then is what made it drift off the beat.
				if not bool(n.get("sounded", false)):
					n["sounded"] = true
					_play_hit_on_beat(dt)
				var p := Judge.pos_acc(cursor_local, n.hit, n.half)
				if p > float(n.get("best_p", -1.0)):
					n["best_p"] = p
					n["best_dt"] = dt
				if is_click:
					# a click note waits for the press
					if _click_edge:
						_resolve(n, dt, cursor_local, p)
				elif p >= Judge.P_PERFECT:
					_resolve(n, dt, cursor_local, p)
		else:
			# a click note that was never pressed is a miss, however good the
			# cursor position was
			if not is_click and float(n.get("best_p", -1.0)) >= 0.0:
				_resolve_best(n)
			else:
				_resolve_miss(n)

	active = active.filter(func(n): return not n.done)
	_update_guide(st)
	ghost_layer.items = active + _guide_items

	_update_fx(delta)
	_update_hud(delta)
	_check_end()
	_click_edge = false


# future targets shown as pulsing red outlines so the player can aim early
var _guide_items: Array = []

func _update_guide(st: float) -> void:
	_guide_items.clear()
	if "target" in G.active_mods:
		for n in notes:
			if not n.done and n.t >= st - APPROACH:
				_target_note = n
				break
	var tmod_on: bool = "target" in G.active_mods
	for n in active:
		if n.done or n.node == null or not is_instance_valid(n.node):
			continue
		var m: Color = n.node.modulate
		if tmod_on and n == _target_note:
			m.r = 1.0
			m.g = 0.30
			m.b = 0.32
		else:
			m.r = 1.0
			m.g = 1.0
			m.b = 1.0
		n.node.modulate = m
	if "hidden" in G.active_mods:
		return
	_guide_idx = 0
	var i := 0
	while i < notes.size() and notes[i].t <= st + GUIDE_AHEAD:
		var n: Dictionary = notes[i]
		var show: bool = not n.done and st < n.t - APPROACH
		if tmod_on:
			show = false   # the nearest cube is already red; no outline needed
		if show:
			_guide_items.append({
				"hit": n.hit, "half": n.half * 1.3, "progress": -1.0,
				"color": Color.WHITE, "done": false, "hover": false, "node": null,
				"gcol": G.C_PRIMARY,
			})
		i += 1


func _spawn(n: Dictionary) -> void:
	idx += 1
	# a saber can take a cube before it was ever spawned; it is finished with,
	# and spawning it now would resolve it a second time
	if n.done:
		return
	# A cube whose whole window elapsed before it could spawn (a frame hitch, a
	# seek) still counts as a miss - accuracy must never silently improve.
	if Conductor.play_time() - n.t > Judge.LAND_GRACE:
		_resolve_miss(n, false)
		return
	var v := NoteView.new()
	# a script may have resized the notes since the chart was loaded
	n["half"] = float(n.get("base_half", n.half)) * _note_scale
	v.half = n.half
	v.hold_total = float(n.h)
	v.is_click = bool(n.get("click", false))
	if script_ != null:
		var tex := str(n.get("tex", ""))
		v.skin = script_.texture(tex) if tex != "" else _note_skin
	v.set_color(n.color)
	v.position = n.spawn
	v.scale = Vector2.ONE * 0.30
	v.modulate.a = 0.0
	notes_root.add_child(v)
	# newer cubes go behind older ones so they emerge from under them
	notes_root.move_child(v, 0)
	var tw := v.create_tween()
	tw.tween_property(v, "modulate:a", 1.0, 0.22)
	n.node = v
	active.append(n)


func _resolve(n: Dictionary, dt: float, cursor_local: Vector2, p_acc_in := -1.0) -> void:
	n["hit_dt"] = dt
	# an early click resolves before the cube lands, so the sound is scheduled
	# for the landing rather than played now - it belongs to the music
	if not bool(n.get("sounded", false)):
		n["sounded"] = true
		_play_hit_on_beat(dt)
	var p_acc := p_acc_in if p_acc_in >= 0.0 else Judge.pos_acc(cursor_local, n.hit, n.half)
	var acc := Judge.acc_for(dt, p_acc)
	var lbl := Judge.label_for(dt, p_acc)
	acc = maxf(acc, Judge.ACC_FLOOR[lbl])
	if float(n.h) > 0.0:
		# a hold has landed: keep it alive and grade it when it runs out
		n.holding = true
		n.held = 0.0
		n.base_acc = acc
		n.base_label = lbl
		if n.node != null and is_instance_valid(n.node):
			n.node.hold_started = true
		frame_view.hit_glow = minf(1.0, frame_view.hit_glow + 0.3)
		return
	n.done = true
	_award(n, acc, lbl)


## A saber cut this cube. VR only.
##
## Two things separate this from every other way a note resolves. It grades on
## timing rather than on where in the cell the cursor was, because a sword
## meets the cube in the air and there is no cell to be off-centre in. And it
## settles the note now, instead of leaving it to land under a cursor that has
## already swung on to the next cube - which is why cutting used to read as a
## miss unless you left the blade parked in the cube until it touched down.
func cut_note(n: Dictionary) -> void:
	if ended or paused or bool(n.get("done", false)):
		return
	var dt: float = Conductor.play_time() - float(n.t)
	n["hit_dt"] = dt
	n["cut"] = true
	if not bool(n.get("sounded", false)):
		n["sounded"] = true
		_play_hit_on_beat(dt)
	var p := Judge.time_acc(dt)
	var lbl := Judge.label_for(dt, p)
	var acc := maxf(Judge.acc_for(dt, p), Judge.ACC_FLOOR[lbl])
	n.done = true
	_award(n, acc, lbl)


## Hold in progress: bank the time the cursor stays inside the cell, and give
## up on it once the cursor has been away for longer than the grace. Brushing a
## long cube and moving on must not score.
func _update_hold(n: Dictionary, cursor_local: Vector2, delta: float, st: float) -> void:
	var inside: bool = Judge.holding(cursor_local, n.hit, n.half) and not n.broken
	if inside:
		n.held += delta
		UICursor.hover_boost = 1.0
	elif not n.broken:
		n.slipped += delta
		if n.slipped > Judge.HOLD_GRACE:
			n.broken = true
	var total := maxf(float(n.h), 0.001)
	var left := clampf(1.0 - (st - float(n.t)) / total, 0.0, 1.0)
	if n.node != null and is_instance_valid(n.node):
		n.node.position = n.hit
		n.node.hold_left = left
		n.node.hold_active = inside
		n.node.scale = Vector2.ONE * (1.0 + (0.06 if inside else 0.0))
	if inside and randf() < delta * 14.0:
		shock.burst(n.hit, G.C_EMBER, 2, 120.0)
	if n.broken or st >= float(n.t) + total:
		n.done = true
		var frac: float = clampf(float(n.held) / total, 0.0, 1.0)
		if frac < Judge.HOLD_MIN:
			_resolve_miss(n)
			return
		var acc: float = Judge.hold_acc(float(n.base_acc), frac)
		var lbl: String = Judge.degrade(str(n.base_label), frac)
		acc = maxf(acc, Judge.ACC_FLOOR[lbl])
		_award(n, acc, lbl)


## Score, combo, counters and feedback for one resolved note.
func _award(n: Dictionary, acc: float, lbl: String) -> void:
	var gain := int(round(300.0 * acc * G.mod_mult(G.active_mods)))
	if float(n.h) > 0.0:
		gain = int(round(float(gain) * (1.0 + minf(float(n.h), 2.0) * 0.5)))
	score += gain
	combo += 1
	max_combo = maxi(max_combo, combo)
	acc_sum += acc
	acc_n += 1
	counts[lbl] += 1
	G.note_hit_stat(combo)
	_heal()

	var col: Color = G.JUDGE_COLORS[lbl]
	var ncol: Color = n.color
	shock.ring(n.hit, ncol, 60.0 + 45.0 * (1.0 - acc))
	var to_center: Vector2 = (Vector2.ZERO - (n.hit as Vector2)).normalized()
	# a click note also reports how far off the press was, in milliseconds -
	# that is the only note type where timing is something you can practise
	var suffix := ""
	if bool(n.get("click", false)) or bool(n.get("cut", false)):
		suffix = "  %+d" % roundi(float(n.get("hit_dt", 0.0)) * 1000.0)
	texts.spawn(n.hit + to_center * 46.0, lbl, col, suffix)
	trauma += (0.10 if lbl == "PERFECT" else 0.06) * G.motion()
	flash += (0.10 if lbl == "PERFECT" else 0.05) * G.flashes()
	frame_view.hit_glow = minf(1.0, frame_view.hit_glow + 0.4)
	combo_scale = 1.30
	if n.node != null and is_instance_valid(n.node):
		n.node.die()
	if combo > 0 and combo % 50 == 0:
		milestone = 1.0 * G.motion()
		bg.flash = maxf(bg.flash, 0.4 * G.flashes())
		shock.ring(Vector2.ZERO, G.C_PRIMARY, 380.0)
	if G.melly != null:
		G.melly.react_hit(combo)


## Resolve from the best moment banked inside the zone.
func _resolve_best(n: Dictionary) -> void:
	_resolve(n, float(n.get("best_dt", 0.0)), n.hit, float(n.get("best_p", 0.0)))


## How many misses in a row the bar can take, from where this difficulty sits
## among the song's own. Read from the position rather than from the name: maps
## bring whatever names they like, and a song with two difficulties means
## something different by "hard" than one with five.
func _set_miss_budget(pick: int, count: int) -> void:
	var hardness := 0.0 if count < 2 else float(pick) / float(count - 1)
	var budget := lerpf(MISS_BUDGET_EASY, MISS_BUDGET_HARD, hardness)
	_miss_cost = 1.0 / maxf(budget, 1.0)


## A miss takes a bite out of the bar, and the bar running out ends the run
## where it stands. Outside a story none of this happens at all.
func _hurt() -> void:
	if not _story_run or _dead or ended:
		return
	health = maxf(0.0, health - _miss_cost)
	if health_bar != null and is_instance_valid(health_bar):
		health_bar.hit = 1.0
	if health <= 0.0:
		_die()


## Landing a note puts a little of it back. A quarter of a miss, so a bad patch
## you pull out of is survivable and one you do not is not.
func _heal() -> void:
	if not _story_run or _dead:
		return
	health = minf(1.0, health + _miss_cost * HEAL_SHARE)


## The bar emptied. The run stops here rather than playing itself out to a
## results screen that would have to pretend it went fine.
func _die() -> void:
	if _dead or ended:
		return
	_dead = true
	trauma = maxf(trauma, 0.9 * G.motion())
	miss_flash = 1.0 * G.flashes()
	G.play_sfx("miss", 0.75, -2.0)
	_finish()


func _resolve_miss(n: Dictionary, has_node := true) -> void:
	n.done = true
	counts["MISS"] += 1
	combo = 0
	acc_n += 1
	var to_center: Vector2 = (Vector2.ZERO - (n.hit as Vector2)).normalized()
	texts.spawn(n.hit + to_center * 46.0, "MISS", G.JUDGE_COLORS["MISS"])
	trauma += 0.26 * G.motion()
	miss_flash = 1.0 * G.flashes()
	if G.hitsound:
		G.play_sfx("miss", 1.0, -8.0)
	if G.melly != null:
		G.melly.react_miss()
	_hurt()
	if has_node and n.node != null and is_instance_valid(n.node):
		n.node.fade_out(0.35)


## Hitsound exactly on the beat: delay the sample so its peak lands on the note.
func _play_hit_on_beat(dt: float) -> void:
	if not G.hitsound:
		return
	# -dt is how long until the cube lands; the device eats _out_lat of that,
	# and G.hit_offset is whatever the player had to add on top by ear
	var delay := (-dt - _out_lat - G.hit_offset) / maxf(_play_rate, 0.1)
	var vol := -8.0
	if delay <= 0.005:
		G.play_sfx("hit", 1.0, vol)
	else:
		var t := get_tree().create_timer(delay, true)
		t.timeout.connect(func(): G.play_sfx("hit", 1.0, vol))


func _autoplay(delta: float) -> void:
	var target := field_center
	var best_dt := INF
	for n in active:
		if n.done:
			continue
		# a hold owns the cursor until it releases, exactly as a player must
		if n.holding:
			target = n.hit + field_center
			best_dt = -1.0
			break
		var dt := absf(Conductor.play_time() - n.t)
		if dt < best_dt:
			best_dt = dt
			target = n.hit + field_center
	var xform := get_viewport().get_canvas_transform()
	var tpos: Vector2 = xform * target
	var k := clampf(delta * 24.0, 0.0, 1.0)
	UICursor.pos = UICursor.pos.lerp(tpos, k)
	if UICursor.pos.distance_to(tpos) < 8.0:
		UICursor.pos = tpos
	var tms := Time.get_ticks_msec() / 1000.0
	UICursor.pos += Vector2(sin(tms * 2.1), cos(tms * 1.7)) * 2.5


## Apply whatever the song's event timeline has queued up by now.
func _run_script(t: float) -> void:
	if script_ == null or script_.is_empty():
		return
	for e in script_.advance(t):
		match str(e.get("do", "")):
			"bg_color":
				var hue := float(e.get("hue", bg.base_hue))
				var fade := float(e.get("fade", 0.0))
				if fade <= 0.0:
					bg.base_hue = hue
				else:
					create_tween().tween_property(bg, "base_hue", hue, fade)
			"bg_image":
				if script_image == null:
					continue
				var tex := script_.texture(str(e.get("file", "")))
				script_image.texture = tex
				var dim: float = clampf(1.0 - float(e.get("dim", 0.6)), 0.0, 1.0)
				var target: float = 0.0 if tex == null else dim
				var f := float(e.get("fade", 0.5))
				if f <= 0.0:
					script_image.modulate.a = target
				else:
					create_tween().tween_property(script_image, "modulate:a", target, f)
			"note_skin":
				_note_skin = script_.texture(str(e.get("file", "")))
			"note_scale":
				_note_scale = clampf(float(e.get("value", 1.0)), 0.2, 6.0)
			"flash":
				flash = maxf(flash, clampf(float(e.get("value", 0.5)), 0.0, 1.0) * G.flashes())
			"shake":
				trauma = maxf(trauma, clampf(float(e.get("value", 0.5)), 0.0, 1.0) * G.motion())
			"zoom":
				var z := clampf(float(e.get("value", 1.0)), 0.6, 2.0)
				var zf := float(e.get("fade", 0.0))
				if zf <= 0.0:
					_zoom_extra = z
				else:
					create_tween().tween_property(self, "_zoom_extra", z, zf)
			"text":
				# where, how big, what colour and for how long - all optional,
				# and all defaulting to what the command used to do on its own
				var at := Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0)))
				var col: Color = G.C_PRIMARY
				var raw_col = e.get("color", null)
				if raw_col != null and Color.html_is_valid(str(raw_col)):
					col = Color.html(str(raw_col))
				texts.spawn(at, str(e.get("value", "")), col, "",
					int(e.get("size", 0)),
					maxf(float(e.get("hold", 0.45)), 0.05),
					0.0 if e.has("hold") or e.has("x") or e.has("y") else 34.0)


# ---------------------------------------------------------------- fx/hud
func _update_fx(delta: float) -> void:
	trauma = maxf(0.0, trauma - 2.4 * delta)
	flash = maxf(0.0, flash - delta * 3.2)
	miss_flash = maxf(0.0, miss_flash - delta * 2.2)
	milestone = maxf(0.0, milestone - delta * 2.6)

	var bp := Conductor.phase()
	var barp := Conductor.bar_phase()
	kick_env = (pow(1.0 - bp, 3.0) * 0.5 + pow(1.0 - barp, 3.0) * 0.85) * G.motion()

	var bar := int(Conductor.beat() / 4.0)
	if bar != last_bar:
		last_bar = bar
		alt_sign = -alt_sign

	var tr := trauma * trauma
	var mo := G.motion()
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var cur_local: Vector2 = inv * UICursor.pos - field_center
	var parallax := cur_local * (PARALLAX / (G.FRAME_HALF * 2.2)) * mo
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 12.0 * tr + parallax
	cam.rotation = (randf_range(-1, 1) * 0.035 * tr \
		+ sin(Conductor.play_time() * 0.6) * 0.006 \
		+ kick_env * 0.005 * alt_sign) * mo
	cam.zoom = Vector2.ONE * _zoom_extra * (1.0 + (kick_env * 0.010 + milestone * 0.045) * mo)

	frame_view.pulse = kick_env
	frame_view.accent = G.C_PRIMARY
	frame_view.scale = Vector2.ONE * (1.0 + (kick_env * 0.014 + milestone * 0.04) * mo)

	bg.beat_env = kick_env
	bg.flash = maxf(bg.flash * 0.92, flash)

	post_mat.set_shader_parameter("shake", trauma)
	post_mat.set_shader_parameter("flash", flash)
	post_mat.set_shader_parameter("miss_flash", miss_flash)
	post_mat.set_shader_parameter("beat", kick_env)

	if not _go_shown and Conductor.play_time() >= 0.05:
		_go_shown = true
		if not _is_tutorial:
			texts.spawn(Vector2(0, 0), "GO!", G.C_PRIMARY)

	if _tut_hint_label != null and not _hints.is_empty():
		var st_t := Conductor.play_time()
		var hint_shown := false
		for i in range(_hints.size() - 1, -1, -1):
			if st_t >= float(_hints[i].t) and st_t < float(_hints[i].t) + 5.0:
				if _tut_hint_i != i:
					_tut_hint_i = i
					_tut_hint_label.text = str(_hints[i].text)
				_tut_hint_label.visible = true
				var fade_in: float = clampf((st_t - float(_hints[i].t)) * 3.0, 0.0, 1.0)
				var fade_out: float = clampf((float(_hints[i].t) + 4.6 - st_t) * 2.5, 0.0, 1.0)
				_tut_hint_label.modulate.a = minf(fade_in, fade_out)
				hint_shown = true
				break
		if not hint_shown:
			_tut_hint_label.visible = false
			_tut_hint_i = -1

	# BLACKOUT: cubes vanish shortly before their hit moment
	if "fade" in G.active_mods:
		for n in active:
			if n.done or n.node == null or not is_instance_valid(n.node):
				continue
			if Conductor.play_time() >= n.t - FADE_LEAD and not n.get("faded", false):
				n["faded"] = true
				var tw: Tween = n.node.create_tween()
				tw.tween_property(n.node, "modulate:a", 0.0, 0.30)


func _update_hud(delta: float) -> void:
	if score != last_score:
		last_score = score
		hud_score.text = "%07d" % score
		hud_score.pivot_offset = Vector2(hud_score.size.x, hud_score.size.y / 2.0)
		hud_score.scale = Vector2(1.12, 1.12)
	hud_score.scale = hud_score.scale.lerp(Vector2.ONE, clampf(delta * 10.0, 0.0, 1.0))

	var acc: float = (acc_sum / acc_n) if acc_n > 0 else 1.0
	hud_acc.text = "%.2f%%" % (acc * 100.0)
	var acc_color := G.C_GOLD if acc > 0.85 else (G.C_AMBER if acc > 0.70 else G.C_PRIMARY)
	hud_acc.add_theme_color_override("font_color", acc_color)

	# the bar mirrors the running accuracy; it is information, not a life meter
	acc_fill.size.x = 220.0 * acc
	acc_fill.color = acc_color

	combo_scale = lerpf(combo_scale, 1.0, clampf(delta * 9.0, 0.0, 1.0))
	if combo >= 4:
		var txt := str(combo)
		if hud_combo.text != txt:
			hud_combo.text = txt
		var heat := clampf(float(mini(combo, 200)) * 0.005, 0.0, 1.0)
		var ccol := Color(1.0, 1.0 - heat * 0.45, 1.0 - heat * 0.55, 0.30 + heat * 0.10)
		hud_combo.add_theme_color_override("font_color", ccol)
	else:
		hud_combo.text = ""
	hud_combo.custom_minimum_size = Vector2(300, 0)
	hud_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_combo.pivot_offset = Vector2(150.0, hud_combo.size.y / 2.0)
	hud_combo.scale = Vector2.ONE * combo_scale
	var cvc: Vector2 = G.visible_rect_design().get_center()
	hud_combo.position = (cvc - Vector2(150.0, hud_combo.size.y / 2.0)).round()

	progress_bar.frac = Conductor.song_time / maxf(Conductor.length, 0.001)
	if health_bar != null and is_instance_valid(health_bar):
		health_bar.frac = health

	# versus: keep the other player posted and show where they are
	if Net.in_match:
		Net.send_progress(_elapsed, score, max_combo, acc)
		if hud_versus != null:
			var them := int(Net.opponent.get("score", 0))
			var lead := score - them
			hud_versus.text = "VS  %s   (%s%s)" % [G.fmt_score(them),
				"+" if lead >= 0 else "", G.fmt_score(lead)]
			hud_versus.add_theme_color_override("font_color",
				G.C_GOLD if lead >= 0 else G.C_PRIMARY)


# ---------------------------------------------------------------- end/pause
func _check_end() -> void:
	var all_spawned := idx >= notes.size()
	var all_done := all_spawned
	if all_done:
		for n in active:
			if not n.done:
				all_done = false
	var time_over: bool = Conductor.playing and Conductor.length > 0.0 \
		and Conductor.song_time >= Conductor.length - 0.08
	if time_over or (all_done and Conductor.play_time() > _last_note_t + 1.2):
		_finish()


func _finish() -> void:
	if ended:
		return
	ended = true
	Conductor.stop_music()
	var acc: float = (acc_sum / acc_n) if acc_n > 0 else 1.0
	# Losing is a story mode idea, and it is the health bar that says so. Free
	# play cannot be failed at all: a bad run there is a bad score, which is
	# what practice looks like.
	var failed := _dead
	var rank: String = Judge.DEAD if failed else Judge.rank_for(acc)
	if G.melly != null:
		if failed:
			G.melly.react_miss()
		else:
			G.melly.react_win()
	var is_best := false
	var earned := 0
	if not failed:
		is_best = G.save_best(str(song.get("id", "")), diff_name, score, acc, max_combo)
		G.add_total_score(score)
		# Coins are for the game's own songs. A chart you wrote yourself and
		# cleared on easy is not a thing a currency can survive being minted by.
		if G.custom_test.is_empty() and not G.replay_mode:
			var diffs := RhythmMap.diffs_of(song)
			earned = G.earn_coins(not RhythmMap.is_user_song(song),
				str(song.get("id", "")), diff_name, rank,
				clampi(G.selected_diff, 0, maxi(diffs.size() - 1, 0)), diffs.size())
	# played is played, however badly
	G.stat_plays += 1
	G.stat_playtime += _elapsed
	G.results = {
		"title": str(song.get("title", "?")),
		"artist": str(song.get("artist", "")),
		"diff": diff_name,
		"score": score, "acc": acc, "max_combo": max_combo,
		"counts": counts.duplicate(), "rank": rank, "new_best": is_best,
		"failed": failed, "coins": earned,
		"on_mobile": G.is_mobile(),
		"mods": G.active_mods.duplicate(),
		"total_score": G.total_score,
		"song_id": str(song.get("id", "")),
	}
	if Net.in_match:
		Net.send_result(G.results)
		G.results["versus"] = true
	if _replay != null:
		_replay.finish(G.results)
		G.replay = _replay
		G.results["has_replay"] = true
	# nothing is earned by a run that was lost
	G.results["unlocked"] = [] if failed else Achievements.check_results(G.results)
	if OS.get_environment("OR_DEBUG") != "":
		print("[DBG] result ", G.results)
	# Story mode: find where this song sits in the playlist rather than trusting
	# a counter, so a retry does not lose the thread. The playlist is kept until
	# the story ends or the player leaves it - clearing it here used to kill the
	# "continue" button after the second song.
	if not G.story_playlist.is_empty() and not failed:
		var pos: int = G.story_playlist.find(str(song.get("id", "")))
		if pos >= 0:
			G.story_idx = pos
			if pos + 1 < G.story_playlist.size():
				G.results["story_next_id"] = str(G.story_playlist[pos + 1])
				G.results["story_diff"] = G.story_diff
			else:
				G.results["story_complete"] = true
				G.coins += Coins.STORY_BONUS
				G.results["coins"] = int(G.results.get("coins", 0)) + Coins.STORY_BONUS
				G.save_all()
				G.story_playlist = []
				G.story_idx = 0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	await tw.finished
	G.main.show_results(G.results)


## Losing focus mid-song would cost the player the run, so pause instead.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_had_focus = true
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			# only pause if the window actually had focus and then lost it - a
			# window manager that never focuses us on launch would otherwise
			# drop the player into a paused song before they touched anything
			if _had_focus and not ended and not paused and is_inside_tree() \
					and pause_layer != null:
				_toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
	if ended:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(Binds.PAUSE):
		go_back()
		return
	if event.is_action_pressed(Binds.RESTART) and not paused:
		_retry()
		return
	if paused or G.autoplay or G.replay_mode:
		return
	# any press counts as a click: mouse, finger or gamepad
	if event is InputEventMouseButton and event.pressed:
		_click_edge = true
	elif event is InputEventScreenTouch and event.pressed:
		_click_edge = true
	elif event.is_action_pressed(Binds.HIT):
		_click_edge = true


func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	pause_layer.visible = paused
	Conductor.set_paused(paused)
	if video != null and is_instance_valid(video):
		video.set_paused(paused)


func _resume() -> void:
	_toggle_pause()


func _retry() -> void:
	get_tree().paused = false
	Conductor.set_paused(false)
	G.custom_test = {}
	G.main.start_game()


func _to_menu() -> void:
	get_tree().paused = false
	Conductor.set_paused(false)
	G.custom_test = {}
	G.replay_mode = false
	Conductor.stop_music()
	G.main.goto_menu()


## The health bar, along the bottom of a story run.
##
## Deliberately not a thin line like the song progress above it: this is the
## thing that ends the run, and it has to be readable out of the corner of an
## eye that is busy watching cubes. It goes from the game's own red to a
## warning amber as it empties, and flinches when it is bitten.
class HealthDraw extends Control:
	var frac := 1.0
	var hit := 0.0            # 1 on the frame a miss lands, fading out
	var _shown := 1.0

	func _process(delta: float) -> void:
		hit = maxf(0.0, hit - delta * 3.2)
		# the drawn value chases the real one, so a miss reads as a lurch
		_shown = move_toward(_shown, frac, delta * 1.6)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var h := size.y * 0.42
		var y := (size.y - h) * 0.5
		G.draw_rounded_rect(self, Rect2(0, y, size.x, h), h * 0.5,
			Color(0.06, 0.012, 0.02, 0.72))
		var f := clampf(_shown, 0.0, 1.0)
		if f > 0.001:
			var col := Color(1.0, 0.62, 0.18).lerp(G.C_PRIMARY, clampf(f * 1.6, 0.0, 1.0))
			if hit > 0.0:
				col = col.lerp(Color.WHITE, hit * 0.55)
			var w: float = maxf(h, size.x * f)
			G.draw_rounded_rect(self, Rect2(0, y, w, h), h * 0.5, col)
		G.draw_rounded_outline(self, Rect2(0, y, size.x, h), h * 0.5,
			Color(1.0, 0.86, 0.84, 0.35 + hit * 0.5), 2.0)
		# a low bar says so rather than leaving it to be noticed
		if f <= 0.34:
			var pulse: float = 0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
			G.draw_rounded_outline(self, r.grow(-1.0), size.y * 0.5,
				Color(1.0, 0.16, 0.2, pulse * (1.0 - f / 0.34)), 2.0)


class ProgressDraw extends Control:
	var frac := 0.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		draw_rect(Rect2(0, y - 1.5, w, 3), Color(1, 1, 1, 0.10))
		var fw := w * clampf(frac, 0.0, 1.0)
		draw_rect(Rect2(0, y - 1.5, fw, 3),
			Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.85))
		draw_circle(Vector2(fw, y), 5.0, Color(1.0, 0.75, 0.70, 0.95))



## Esc, and the Android back button: pause, or unpause. Once the song is over
## the results screen is on its way in and back does nothing.
func go_back() -> void:
	if ended:
		return
	_toggle_pause()
