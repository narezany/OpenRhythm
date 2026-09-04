class_name SongSelectScreen
extends Control
## Song select, difficulty and modifiers, with a hover preview of each track.
## Edit mode also creates new maps: a folder is made from the title and audio is
## attached with the file dialog or by dropping a file into the song folder.

var mode := "play"

var _pick_song: Dictionary = {}
var _pick_diff := 0
var _mods_layer: CanvasLayer
var _mod_checks: Dictionary = {}

var _new_layer: CanvasLayer
var _title_input: LineEdit

var _audio_dialog: FileDialog

# --- song preview ---
var _preview_song: Dictionary = {}
var _preview_wait := 0.0
var _preview_playing := ""
var _started_game := false


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	add_child(BackgroundFX.new(true))

	var title := G.label("SELECT SONG" if mode == "play" else
		("NIGHT DRIVE" if mode == "story" else "EDITOR — SELECT SONG"),
		40, G.C_TEXT, true)
	title.position = Vector2(40, 26)
	_add_sticky(title)

	var back := G.button("← Back", func():
		G.play_sfx("click")
		if mode == "story":
			G.main.goto_story()
		else:
			G.main.goto_menu())
	_add_sticky(back)
	G.anchor_corner(back, false, true, 40, 38, Vector2(190, 46))

	var hint := G.label("Esc — back", 17, Color(1, 1, 1, 0.35))
	_add_sticky(hint)
	G.anchor_corner(hint, true, true, 24, 26, Vector2(126, 24))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	G.anchor_margins(scroll, 140, 104, 140, 106)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 18)
	scroll.add_child(vb)

	var songs := RhythmMap.load_songs()
	for song in songs:
		if mode == "story" and not (str(song.get("id", "")) in ["hyper_drive", "neon_drift"]):
			continue
		if RhythmMap.is_playable(song):
			vb.add_child(_card(song))

	# Android: file access denied - say plainly what to do about it
	if RhythmMap.storage_denied_flag:
		var warn := PanelContainer.new()
		warn.add_theme_stylebox_override("panel", G.panel_style(
			Color(G.C_GOLD.r, G.C_GOLD.g, G.C_GOLD.b, 0.5)))
		var wl := G.label(
			"Storage access denied — custom songs are invisible.\nDude, I can't look at your songs: allow \"All files access\"\nfor Open Rhythm in Android Settings → Apps → Permissions.",
			16, G.C_GOLD)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_child(wl)
		vb.add_child(warn)

	if songs.is_empty():
		var empty := G.label("No songs found. Put folders or .zip song packs into:",
			22, G.C_MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(empty)
		G.anchor_top_wide(empty, 200, 40)
		var pathl := G.label(RhythmMap.user_songs_dir(), 18, G.C_PRIMARY)
		pathl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(pathl)
		G.anchor_top_wide(pathl, 244, 30)

	if mode == "edit":
		var nb := G.button("+  NEW MAP", _new_map_dialog, 24)
		add_child(nb)
		G.anchor_bottom_center(nb, 50, Vector2(260, 46))

	_build_mods_layer()


func _add_sticky(c: Control) -> void:
	add_child(c)


func _card(song: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", G.panel_style())
	panel.mouse_entered.connect(func(): _want_preview(song))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	panel.add_child(hb)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 0)
	var title := G.label(str(song.get("title", "?")), 32, G.C_TEXT)
	left.add_child(title)
	left.add_child(G.label(str(song.get("artist", "")), 19, G.C_MUTED))
	var meta_bits := "%d BPM  •  %d:%02d" % [roundi(float(song.get("bpm", 120.0))),
		int(song.get("length", 0.0)) / 60, int(song.get("length", 0.0)) % 60]
	if str(song.get("video", "")) != "":
		meta_bits += "  •  ♪ video"
	var meta := G.label(meta_bits, 17, Color(1, 1, 1, 0.45))
	left.add_child(meta)
	hb.add_child(left)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 8)
	var diffs := RhythmMap.diffs_of(song)
	for i in diffs.size():
		var dname: String = str(diffs[i].get("name", "?"))
		var b: Dictionary = G.get_best(str(song.get("id", "")), dname)
		var txt := dname
		if not b.is_empty():
			txt += "    ★ %.1f%% · %d" % [float(b.get("acc", 0.0)) * 100.0, int(b.get("score", 0))]
		var btn := G.button(txt, _difficulty_picked.bind(song, i), 22)
		btn.custom_minimum_size = Vector2(280, 0)
		right.add_child(btn)
	hb.add_child(right)
	return panel


# ---------------------------------------------------------------- preview
## Hovering a card starts its preview after a short delay, so sweeping the
## mouse down the list does not decode every track on the way.
func _want_preview(song: Dictionary) -> void:
	if str(song.get("id", "")) == _preview_playing:
		return
	_preview_song = song
	_preview_wait = 0.35


func _process(delta: float) -> void:
	if _preview_wait <= 0.0:
		return
	_preview_wait -= delta
	if _preview_wait > 0.0:
		return
	_preview_wait = 0.0
	var stream := RhythmMap.audio_stream(_preview_song)
	if stream == null:
		return
	_preview_playing = str(_preview_song.get("id", ""))
	Conductor.play_music(stream, float(_preview_song.get("preview_start", 0.0)),
		float(_preview_song.get("bpm", 120.0)), -12.0, true)


func _exit_tree() -> void:
	# leave the preview behind; the menu restarts its own music
	if _preview_playing != "" and not _started_game:
		Conductor.stop_music()


func _difficulty_picked(song: Dictionary, i: int) -> void:
	G.play_sfx("click")
	if mode == "story":
		# from the story: straight into the game, no modifier layer
		G.selected_song = song
		G.selected_diff = i
		_started_game = true
		Conductor.stop_music()
		G.main.start_game()
	elif mode == "play":
		_pick_song = song
		_pick_diff = i
		_mods_layer.visible = true
	else:
		Conductor.stop_music()
		G.main.open_editor(song, i)


# ---------------------------------------------------------------- modifiers
func _build_mods_layer() -> void:
	_mods_layer = CanvasLayer.new()
	_mods_layer.layer = 40
	_mods_layer.visible = false
	add_child(_mods_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.0, 0.72)
	_mods_layer.add_child(dim)
	G.anchor_full(dim)

	var center := CenterContainer.new()
	_mods_layer.add_child(center)
	G.anchor_full(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", G.panel_style())
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(640, 0)
	panel.add_child(vb)

	var t := G.label("MODIFIERS", 34, G.C_TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var st := G.label("Modifiers change the score multiplier. Multiplicative.", 16, G.C_MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(st)

	_mod_checks.clear()
	for md in G.MODS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var chk := CheckButton.new()
		var mid := str(md.id)
		chk.button_pressed = false
		chk.add_theme_font_override("font", G.font_bold)
		chk.add_theme_font_size_override("font_size", 22)
		chk.add_theme_color_override("font_color", G.C_EMBER)
		chk.toggled.connect(func(on): _mod_toggled(mid, on))
		_mod_checks[md.id] = chk
		row.add_child(chk)
		var lbl := G.label("%s  (%+d%%)" % [md.label,
			roundi((float(md.mult) - 1.0) * 100.0)], 22, G.C_EMBER)
		lbl.custom_minimum_size = Vector2(190, 0)
		row.add_child(lbl)
		var d := G.label(str(md.desc), 16, G.C_MUTED)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(360, 0)
		row.add_child(d)
		vb.add_child(row)

	vb.add_child(HSpacer.new(6))

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var start := G.button("START", _start_with_mods, 28)
	start.custom_minimum_size = Vector2(200, 0)
	hb.add_child(start)
	hb.add_child(G.button("Cancel", func(): _mods_layer.visible = false, 22))


## Mutually exclusive modifiers switch each other off instead of stacking.
func _mod_toggled(id: String, on: bool) -> void:
	if not on:
		return
	for pair in G.MOD_CONFLICTS:
		if id in pair:
			for other in pair:
				if other != id and _mod_checks.has(other):
					_mod_checks[other].set_pressed_no_signal(false)


func _start_with_mods() -> void:
	G.active_mods.clear()
	for id in _mod_checks:
		if _mod_checks[id].button_pressed:
			G.active_mods.append(id)
	_mods_layer.visible = false
	G.selected_song = _pick_song
	G.selected_diff = _pick_diff
	_started_game = true
	Conductor.stop_music()
	G.main.start_game()


# ---------------------------------------------------------------- new map
func _new_map_dialog() -> void:
	G.play_sfx("click")
	if _new_layer == null:
		_new_layer = CanvasLayer.new()
		_new_layer.layer = 40
		add_child(_new_layer)

		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.0, 0.0, 0.72)
		_new_layer.add_child(dim)
		G.anchor_full(dim)

		var center := CenterContainer.new()
		_new_layer.add_child(center)
		G.anchor_full(center)

		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", G.panel_style())
		center.add_child(panel)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 12)
		vb.custom_minimum_size = Vector2(560, 0)
		panel.add_child(vb)

		var t := G.label("NEW MAP", 34, G.C_TEXT, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(t)

		var il := G.label("Song title — the game creates its own folder:", 18, G.C_MUTED)
		vb.add_child(il)

		_title_input = LineEdit.new()
		_title_input.placeholder_text = "My awesome song"
		_title_input.add_theme_font_override("font", G.font_body)
		_title_input.add_theme_font_size_override("font_size", 24)
		_title_input.custom_minimum_size = Vector2(480, 0)
		vb.add_child(_title_input)

		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 16)
		vb.add_child(hb)
		var ok := G.button("CREATE", _create_new_map, 26)
		ok.custom_minimum_size = Vector2(170, 0)
		hb.add_child(ok)
		hb.add_child(G.button("Cancel", func(): _new_layer.visible = false, 22))

		var help := G.label("After creating, open the song folder and drop your audio file\n(audio.wav / .ogg / .mp3) inside — or pick it via the file dialog in the editor.",
			15, G.C_MUTED)
		help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(help)

	_new_layer.visible = true
	_title_input.grab_focus()


func _create_new_map() -> void:
	var title := _title_input.text.strip_edges()
	if title == "":
		_title_input.grab_focus()
		return
	var song := RhythmMap.create_new_song(title)
	_new_layer.visible = false
	G.play_sfx("click")
	# suggest attaching audio right away
	var songs := RhythmMap.load_songs()
	var created: Dictionary = {}
	for s in songs:
		if str(s.get("id", "")) == str(song.get("id", "")):
			created = s
			break
	if created.is_empty():
		created = song
	G.main.open_editor(created, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _mods_layer != null and _mods_layer.visible:
			_mods_layer.visible = false
			return
		if _new_layer != null and _new_layer.visible:
			_new_layer.visible = false
			return
		if mode == "story":
			G.main.goto_story()
			return
		G.main.goto_menu()


class HSpacer extends Control:
	var h := 10.0

	func _init(h_ := 10.0) -> void:
		h = h_
		custom_minimum_size = Vector2(0, h)
