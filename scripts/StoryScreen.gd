class_name StoryScreen
extends Control
## STORY MODE.
## Phase 1: a scrollable list of stories.
## Phase 2: a visual-novel dialog - Melly centred, a name box, text typed out
## with a soft beep per couple of characters, click to advance.

const DIALOG_TUTORIAL := [
	"Hey! You want to learn how to play Open Rhythm?",
	"Then watch closely — I'll show you everything myself!",
]
const DIALOG_DRIVE := [
	"Well, how's your first impression of the game?",
	"Yeah, you can't really enjoy a tutorial... let's do it for real!",
]

var story := 1            # chosen story; 0 means nothing picked yet
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# clicks advance the dialog from _unhandled_input, so the root must let
	# them through; the buttons and cards keep their own input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(BackgroundFX.new(true))
	_build_list()
	Conductor.ensure_menu_music()


# ------------------------------------------------------------- phase 1: list
func _build_list() -> void:
	_list_root = Control.new()
	_list_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_list_root)

	var title := G.label("STORY MODE", 42, G.C_TEXT, true)
	title.position = Vector2(0, 28)
	title.size = Vector2(G.DESIGN.x, 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list_root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(290, 100)
	scroll.size = Vector2(700, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_root.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 18)
	scroll.add_child(vb)

	# story 1 on top, it is read first; story 2 below it
	var locked := not _tutorial_done()
	vb.add_child(_story_card("1 • FIRST STEPS",
		"Learn the basics with Melly.\nTutorial song.",
		func(): _open_story(1), false))
	vb.add_child(_story_card("2 • NIGHT DRIVE",
		"Hyper Drive + Neon Drift.\nChoose your difficulty.",
		func(): _open_story(2), locked))
	var back := G.button("← Back", func():
		G.play_sfx("click")
		G.main.goto_menu(), 22)
	back.position = Vector2(24, G.DESIGN.y - 78)
	back.custom_minimum_size = Vector2(180, 0)
	_list_root.add_child(back)


func _tutorial_done() -> bool:
	return not G.get_best("tutorial", "Easy").is_empty()


func _story_card(title: String, sub: String, on_open: Callable, locked: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.22 if locked else 0.75)))
	p.custom_minimum_size = Vector2(660, 170)
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
	hb.add_child(b)
	return p


# --------------------------------------------- phase 2: novel dialog
func _open_story(which: int) -> void:
	story = which
	_lines = DIALOG_TUTORIAL if which == 1 else DIALOG_DRIVE
	_li = 0
	_build_novel()
	_start_line()


func _build_novel() -> void:
	if _list_root != null:
		_list_root.visible = false
	_novel_layer = Control.new()
	_novel_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_novel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_novel_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.004, 0.01, 0.82)
	dim.size = G.DESIGN
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novel_layer.add_child(dim)

	# Melly in the middle of the screen
	_rig = MellyRig.new()
	_rig.position = Vector2(G.DESIGN.x / 2.0 - 230.0, 60)
	_rig.size = Vector2(460, 470)
	if _rig is Control:
		(_rig as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novel_layer.add_child(_rig)

	# a visual-novel style dialog box
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.85)))
	box.position = Vector2(90, 560)
	box.size = Vector2(G.DESIGN.x - 180, 140)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novel_layer.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vb)
	_name_lbl = G.label("MELLY", 17, G.C_GOLD, true)
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_name_lbl)
	_text_lbl = G.label("", 22, G.C_TEXT)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.custom_minimum_size = Vector2(G.DESIGN.x - 240, 74)
	_text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_text_lbl)
	_hint_lbl = G.label("▼", 18, G.C_PRIMARY)
	_hint_lbl.position = Vector2(G.DESIGN.x - 150, 668)
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novel_layer.add_child(_hint_lbl)


func _start_line() -> void:
	_shown = 0.0
	_typing = true
	_text_lbl.text = ""


func _process(delta: float) -> void:
	if _novel_layer == null or not _typing:
		return
	var full: String = str(_lines[_li])
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


func _advance() -> void:
	if _novel_layer == null:
		return
	var full: String = str(_lines[_li])
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
	# story 1: the tutorial on Easy, then both songs back to back
	if story == 1:
		G.story_playlist = ["tutorial", "hyper_drive", "neon_drift"]
		G.story_idx = 0
		G.story_diff = 0
		_start_playlist_song()
		return
	# story 2: pick a difficulty, then both songs back to back
	_hint_lbl.visible = false
	var pick := G.label("Choose your difficulty:", 22, G.C_GOLD)
	pick.position = Vector2(90, 510)
	pick.size = Vector2(G.DESIGN.x - 180, 34)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_novel_layer.add_child(pick)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	row.position = Vector2(90, 545)
	row.size = Vector2(G.DESIGN.x - 180, 0)
	_novel_layer.add_child(row)
	for cfg in [["NORMAL", 0], ["HYPER", 1]]:
		var di: int = cfg[1]
		row.add_child(G.button(str(cfg[0]), func():
			G.play_sfx("click", 1.3)
			G.story_playlist = ["hyper_drive", "neon_drift"]
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


func _unhandled_input(event: InputEvent) -> void:
	if _novel_layer != null:
		if event is InputEventMouseButton and event.pressed:
			_advance()
		elif event is InputEventScreenTouch and event.pressed:
			_advance()
		elif event.is_action_pressed("ui_accept"):
			_advance()
		elif event.is_action_pressed("ui_cancel"):
			# Esc: finish the line, then the next one, then leave
			_advance() if _li < _lines.size() else G.main.goto_menu()
		return
	if event.is_action_pressed("ui_cancel"):
		G.main.goto_menu()
