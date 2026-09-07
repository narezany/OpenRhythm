class_name StoryScreen
extends Control
## Story mode.
## Phase 1: a scrollable list of stories.
## Phase 2: a visual-novel dialog - Melly centred, a name box, text typed out
## with a soft beep per couple of characters, click to advance.
##
## Each story is a playlist played back to back. A story unlocks when the one
## before it has been cleared.

const STORIES := [
	{
		"key": "first_steps",
		"title": "1 • FIRST STEPS",
		"sub": "Learn the basics with Melly.\nJust the tutorial.",
		"songs": ["tutorial"],
		"pick_diff": false,
		"needs": "",
		"dialog": [
			"Hey! You want to learn how to play Open Rhythm?",
			"Then watch closely — I'll show you everything myself!",
		],
	},
	{
		"key": "night_drive",
		"title": "2 • NIGHT DRIVE",
		"sub": "Hyper Drive, Neon Drift, Midnight Pulse.\nChoose your difficulty.",
		"songs": ["hyper_drive", "neon_drift", "midnight_pulse"],
		"pick_diff": true,
		"needs": "tutorial",
		"dialog": [
			"Well, how's your first impression of the game?",
			"Yeah, you can't really enjoy a tutorial... let's do it for real!",
			"Three tracks, no stopping. The last one is my favourite.",
		],
	},
	{
		"key": "overdrive",
		"title": "3 • OVERDRIVE",
		"sub": "Bass Rush, Crimson Step, Afterburner.\nThe heavy set.",
		"songs": ["bass_rush", "crimson_step", "afterburner"],
		"pick_diff": true,
		"needs": "midnight_pulse",
		"dialog": ["Shall we continue?"],
	},
]

var story := 0            # index into STORIES, -1 while nothing is picked
var _rig = null
var _novel_layer: Control = null
var _name_lbl: Label
var _text_lbl: Label
var _hint_lbl: Label
var _lines: Array = []
var _li := 0
var _shown := 0.0         # how many characters have been typed out
var _typing := false
var _list_root: Control = null


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	# clicks advance the dialog from _unhandled_input, so the root must let
	# them through; the buttons and cards keep their own input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(BackgroundFX.new(true))
	_build_list()
	Conductor.ensure_menu_music()


# ------------------------------------------------------------- phase 1: list
func _build_list() -> void:
	_list_root = Control.new()
	G.anchor_full(_list_root)
	_list_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list_root)

	var title := G.label("STORY MODE", 42, G.C_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list_root.add_child(title)
	G.anchor_top_wide(title, 28, 54)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_root.add_child(scroll)
	G.anchor_margins(scroll, 290, 100, 290, 100)
	DragScroll.attach(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 18)
	scroll.add_child(vb)

	for i in STORIES.size():
		var idx := i
		var st: Dictionary = STORIES[i]
		var locked := not _unlocked(st)
		vb.add_child(_story_card(str(st.title), str(st.sub),
			func(): _open_story(idx), locked))

	var back := G.button("← Back", func():
		G.play_sfx("click")
		G.main.goto_menu(), 22)
	_list_root.add_child(back)
	G.anchor_corner(back, false, true, 24, 32, Vector2(180, 46))


## A story opens once the song its predecessor ends on has been cleared.
func _unlocked(st: Dictionary) -> bool:
	var needs := str(st.get("needs", ""))
	return needs == "" or _song_cleared(needs)


func _song_cleared(song_id: String) -> bool:
	if not G.best.has(song_id):
		return false
	var entry = G.best[song_id]
	return entry is Dictionary and not entry.is_empty()


func _story_card(title: String, sub: String, on_open: Callable, locked: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.22 if locked else 0.75)))
	p.custom_minimum_size = Vector2(660, 160)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	p.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	hb.add_child(vb)
	var t := G.label(title, 30, G.C_GOLD if not locked else G.C_MUTED, true)
	vb.add_child(t)
	var s := G.label(sub, 17, G.C_TEXT if not locked else G.C_MUTED)
	vb.add_child(s)
	var b := G.button("PLAY" if not locked else "LOCKED", func():
		if locked:
			G.play_sfx("miss", 1.0, -6.0)
			return
		G.play_sfx("click")
		on_open.call())
	b.custom_minimum_size = Vector2(150, 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(b)
	return p


# --------------------------------------------- phase 2: novel dialog
func _open_story(which: int) -> void:
	story = which
	_lines = STORIES[which].dialog
	_li = 0
	_build_novel()
	_start_line()


func _build_novel() -> void:
	if _list_root != null:
		_list_root.visible = false
	_novel_layer = Control.new()
	G.anchor_full(_novel_layer)
	_novel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_novel_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.004, 0.01, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novel_layer.add_child(dim)
	G.anchor_full(dim)

	# Melly in the middle of the screen
	_rig = MellyRig.new()
	_rig.position = Vector2(G.canvas_size().x / 2.0 - 230.0, 60)
	_rig.size = Vector2(460, 470)
	if _rig is Control:
		(_rig as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novel_layer.add_child(_rig)

	# a visual-novel style dialog box
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.85)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novel_layer.add_child(box)
	G.anchor_bottom_wide(box, 20, 140, 90)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vb)
	_name_lbl = G.label("MELLY", 17, G.C_GOLD, true)
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_name_lbl)
	_text_lbl = G.label("", 22, G.C_TEXT)
	# the label is filled character by character, and half a sentence is not a
	# translation key - so the line is translated up front and typed out from
	# the translated text instead
	_text_lbl.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.custom_minimum_size = Vector2(0, 74)
	_text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_text_lbl)
	_hint_lbl = G.label("▼", 18, G.C_PRIMARY)
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novel_layer.add_child(_hint_lbl)
	G.anchor_corner(_hint_lbl, true, true, 130, 44, Vector2(40, 24))


func _start_line() -> void:
	_shown = 0.0
	_typing = true
	_text_lbl.text = ""


func _process(delta: float) -> void:
	if _novel_layer == null or not _typing:
		return
	var full := _line_text()
	if _shown < full.length():
		var prev := int(_shown)
		_shown = minf(_shown + delta * 38.0, float(full.length()))
		var cur := int(_shown)
		_text_lbl.text = full.substr(0, cur)
		# a quiet high beep every two new characters
		if cur - prev >= 2 and cur % 2 == 0:
			G.play_sfx("click", 2.4, -21.0)
	else:
		_typing = false
		_text_lbl.text = full


## The current line, already translated.
func _line_text() -> String:
	return tr(str(_lines[_li])) if _li < _lines.size() else ""


func _advance() -> void:
	if _novel_layer == null:
		return
	var full := _line_text()
	if _typing:
		_shown = float(full.length())   # finish the line instantly
		_text_lbl.text = full
		_typing = false
		return
	_li += 1
	if _li < _lines.size():
		G.play_sfx("click", 1.4, -10.0)
		_start_line()
	else:
		_finish_dialog()


func _finish_dialog() -> void:
	var st: Dictionary = STORIES[story]
	if not st.get("pick_diff", false):
		G.story_playlist = (st.songs as Array).duplicate()
		G.story_idx = 0
		G.story_diff = 0
		_start_playlist_song()
		return
	_hint_lbl.visible = false
	var pick := G.label("Choose your difficulty:", 22, G.C_GOLD)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_novel_layer.add_child(pick)
	G.anchor_bottom_wide(pick, 176, 34, 90)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	_novel_layer.add_child(row)
	G.anchor_bottom_wide(row, 130, 46, 90)
	for cfg in [["EASY", 0], ["NORMAL", 1], ["HYPER", 2]]:
		var di: int = cfg[1]
		row.add_child(G.button(str(cfg[0]), func():
			G.play_sfx("click", 1.3)
			G.story_playlist = (st.songs as Array).duplicate()
			G.story_idx = 0
			G.story_diff = di
			_start_playlist_song()))


func _start_playlist_song() -> void:
	var songs := RhythmMap.load_songs()
	var want: String = str(G.story_playlist[G.story_idx])
	for s in songs:
		if str(s.get("id", "")) == want:
			G.selected_song = s
			var diffs := RhythmMap.diffs_of(s)
			G.selected_diff = clampi(G.story_diff, 0, diffs.size() - 1)
			G.main.start_game()
			return
	# song is missing - skip to the next one
	G.story_idx += 1
	if G.story_idx < G.story_playlist.size():
		_start_playlist_song()
	else:
		G.main.goto_story()


func _unhandled_input(event: InputEvent) -> void:
	if _novel_layer != null:
		if event is InputEventMouseButton and event.pressed:
			_advance()
		elif event is InputEventScreenTouch and event.pressed:
			_advance()
		elif event.is_action_pressed("ui_accept"):
			_advance()
		elif event.is_action_pressed("ui_cancel"):
			go_back()
		return
	if event.is_action_pressed("ui_cancel"):
		go_back()
		return


## Esc, and the Android back button. During a cutscene it skips ahead a line
## rather than dropping the player out of the story.
func go_back() -> void:
	if _novel_layer != null:
		# finish the line, then the next one, then leave
		if _li < _lines.size():
			_advance()
		else:
			G.main.goto_menu()
		return
	G.main.goto_menu()
