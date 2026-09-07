class_name StoryScreen
extends Control
## Story mode.
## Phase 1: a scrollable list of stories.
## Phase 2: a visual-novel dialog - Melly centred, a name box, text typed out
## with a soft beep per couple of characters, click to advance.
##
## Each story is a playlist played back to back. A story unlocks when the one
## before it has been cleared.

## A line is who says it, how they stand while they say it, and the words.
## Melly's poses come from MellyRig.POSES; the player has no body on screen, so
## theirs are ignored and Melly steps back into the dark instead.
const STORIES := [
	{
		"key": "first_steps",
		"title": "1 • FIRST STEPS",
		"sub": "Learn the basics with Melly.\nJust the tutorial.",
		"songs": ["tutorial"],
		"pick_diff": false,
		"needs": "",
		"dialog": [
			{"who": "melly", "pose": "surprised",
			 "text": "Oh — somebody actually opened this. Hi!"},
			{"who": "you", "text": "I'm not here to play a game. I'm here to train."},
			{"who": "melly", "pose": "ask", "text": "Train. For what?"},
			{"who": "you",
			 "text": "Laser tag. Regionals are in three months and I can't hit anything that moves."},
			{"who": "melly", "pose": "surprised",
			 "text": "...so you downloaded a rhythm game."},
			{"who": "you",
			 "text": "A friend swore it fixes your aim. Cubes fly at you, you put the cursor on them, on the beat."},
			{"who": "melly", "pose": "smug",
			 "text": "That is, annoyingly, exactly what this is."},
			{"who": "melly", "pose": "explain",
			 "text": "Aim is two questions. Where, and when. Almost everybody only ever practises where."},
			{"who": "you", "text": "And the music asks the when."},
			{"who": "melly", "pose": "cheer",
			 "text": "Now you're getting it! Come on — I'll walk you through the whole thing myself."},
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
			{"who": "melly", "pose": "talk", "text": "So? First impressions."},
			{"who": "you",
			 "text": "A tutorial isn't a fight. Nothing came at me fast enough to miss."},
			{"who": "melly", "pose": "smug",
			 "text": "Say that to me again in about four minutes."},
			{"who": "melly", "pose": "explain",
			 "text": "Three tracks, back to back. This is where you find out what your hands do under pressure."},
			{"who": "you", "text": "And if I lose?"},
			{"who": "melly", "pose": "worried",
			 "text": "Then the bar along the bottom runs out and we stop there. Missing costs you; landing pays it back."},
			{"who": "you", "text": "No lives? No continues?"},
			{"who": "melly", "pose": "talk",
			 "text": "It's a match. You don't get to be bad for thirty seconds and still be in it."},
			{"who": "melly", "pose": "wink",
			 "text": "The last one's my favourite. Try to still be alive for it."},
		],
	},
	{
		"key": "overdrive",
		"title": "3 • OVERDRIVE",
		"sub": "Bass Rush, Crimson Step, Afterburner.\nThe heavy set.",
		"songs": ["bass_rush", "crimson_step", "afterburner"],
		"pick_diff": true,
		"needs": "midnight_pulse",
		"dialog": [
			{"who": "melly", "pose": "surprised", "text": "You came back."},
			{"who": "you", "text": "Regionals moved. Six weeks."},
			{"who": "melly", "pose": "worried", "text": "Six weeks..."},
			{"who": "you", "text": "Say something useful."},
			{"who": "melly", "pose": "explain",
			 "text": "Fine. Everything you have played so far was a metronome being polite to you."},
			{"who": "melly", "pose": "talk",
			 "text": "This set is not polite. It gets ahead of you and it does not wait."},
			{"who": "you", "text": "Good."},
			{"who": "melly", "pose": "ask", "text": "...good?"},
			{"who": "you", "text": "Nobody on the other team is going to wait either."},
			{"who": "melly", "pose": "cheer",
			 "text": "Okay. Okay! Now I actually want to watch this."},
		],
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
var _last_tap_ms := 0
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
		vb.add_child(_story_card(st, func(): _open_story(idx)))

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


## How much of a story has been played. The list used to say nothing at all -
## whether you had finished a chapter or never opened it, the card looked the
## same, and the only way to find out was to play it again and see.
func _cleared_count(st: Dictionary) -> int:
	var n := 0
	for id in st.get("songs", []):
		if _song_cleared(str(id)):
			n += 1
	return n


## What clearing a whole chapter pays: every song in it plus the chapter bonus,
## at the rate each of them is actually on. A song already cleared pays half,
## so the number on a finished chapter is the number for playing it again.
func _worth(st: Dictionary) -> int:
	var total := Coins.story_bonus((st.get("songs", []) as Array).size())
	var songs := RhythmMap.load_songs()
	for id in st.get("songs", []):
		for song in songs:
			if str(song.get("id", "")) != str(id):
				continue
			var diffs := RhythmMap.diffs_of(song)
			var pick: int = clampi(G.story_diff, 0, maxi(diffs.size() - 1, 0))
			var dname := str(diffs[pick].get("name", "")) if not diffs.is_empty() else ""
			var again: bool = G.coins_paid.has(Coins.key_for(str(id), dname))
			# an honest figure needs a rank to assume, and the one it assumes is
			# a clean run - anything worse pays less, which is the point of it
			total += Coins.for_run(not RhythmMap.is_user_song(song), "S",
				pick, diffs.size(), not again)
			break
	return total


func _story_card(st: Dictionary, on_open: Callable) -> PanelContainer:
	var locked := not _unlocked(st)
	var total: int = (st.get("songs", []) as Array).size()
	var done := _cleared_count(st)
	var finished: bool = not locked and total > 0 and done >= total

	var p := PanelContainer.new()
	var edge: Color = G.C_GOLD if finished else G.C_PRIMARY
	p.add_theme_stylebox_override("panel", G.panel_style(
		Color(edge.r, edge.g, edge.b, 0.22 if locked else 0.75)))
	p.custom_minimum_size = Vector2(660, 160)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	p.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	hb.add_child(vb)
	var t := G.label(str(st.title), 30, G.C_GOLD if not locked else G.C_MUTED, true)
	vb.add_child(t)
	var s := G.label(str(st.sub), 17, G.C_TEXT if not locked else G.C_MUTED)
	vb.add_child(s)
	# where you got to, in words rather than left to memory
	if locked:
		vb.add_child(G.label("Locked — finish the story before it", 16, G.C_MUTED))
	elif finished:
		vb.add_child(G.label("✓ COMPLETE", 18, G.C_GOLD, true))
	elif done > 0:
		vb.add_child(G.label("%d / %d cleared" % [done, total], 17, G.C_EMBER))
	else:
		vb.add_child(G.label("Not played yet", 16, G.C_MUTED))
	if not locked:
		# what finishing it is worth, before you decide whether to
		vb.add_child(G.label("%d ◆ for finishing it" % _worth(st), 16, G.C_GOLD))

	var b := G.button(("LOCKED" if locked else ("REPLAY" if finished else
		("CONTINUE" if done > 0 else "PLAY"))), func():
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

	# Melly, close enough to read a face on. A conversation happens at talking
	# distance; the full-length view is for the corner of a results screen.
	_rig = MellyRig.new()
	# The rig is a viewport with a camera in it, and anything outside the
	# viewport is simply not drawn - so a box sized to Melly clipped their arms
	# off the moment a pose put the arms anywhere. It fills the screen instead
	# and the camera does the framing, which is the job the camera is for.
	if _rig is Control:
		(_rig as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_novel_layer.add_child(_rig)
	G.anchor_full(_rig)
	_rig.frame_bust()

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
	_name_lbl.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
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


## Who is speaking, how they stand, and the sound their words make.
##
## While the player talks Melly steps back into the dark rather than standing
## there mouthing along - there is no sprite for the player, and the light
## going off them is what says the line is not theirs.
func _start_line() -> void:
	_shown = 0.0
	_typing = true
	_text_lbl.text = ""
	var line := _line()
	var mine: bool = str(line.get("who", "melly")) == "you"
	_name_lbl.text = tr("YOU") if mine else tr("MELLY")
	_name_lbl.add_theme_color_override("font_color",
		G.C_PRIMARY if mine else G.C_GOLD)
	if _rig != null and is_instance_valid(_rig):
		_rig.set_pose("listen" if mine else str(line.get("pose", "talk")))
		_rig.talking = not mine
		var tw := create_tween()
		tw.tween_property(_rig, "modulate",
			Color(0.30, 0.26, 0.32, 1.0) if mine else Color.WHITE, 0.22)


## The line being spoken, whatever shape it was written in.
func _line() -> Dictionary:
	if _li < 0 or _li >= _lines.size():
		return {}
	var raw = _lines[_li]
	return raw if raw is Dictionary else {"who": "melly", "text": str(raw)}


func _process(delta: float) -> void:
	if _novel_layer == null or not _typing:
		return
	var full := _line_text()
	if _shown < full.length():
		var prev := int(_shown)
		_shown = minf(_shown + delta * 38.0, float(full.length()))
		var cur := int(_shown)
		_text_lbl.text = full.substr(0, cur)
		# One note per couple of letters, in the voice of whoever is speaking.
		#
		# Asked as "have we crossed an even letter", not as "did two letters
		# arrive this frame": at thirty-eight letters a second and sixty frames
		# a second, two letters almost never land in the same frame, so the old
		# test was silent on any machine that was keeping up.
		if cur > prev and (cur >> 1) != (prev >> 1) \
				and full.substr(maxi(0, cur - 1), 1).strip_edges() != "":
			G.blip("player" if str(_line().get("who", "melly")) == "you" else "melly")
	else:
		_typing = false
		_text_lbl.text = full
		if _rig != null and is_instance_valid(_rig):
			_rig.talking = false


## The current line, already translated.
func _line_text() -> String:
	var line := _line()
	return tr(str(line.get("text", ""))) if not line.is_empty() else ""


## One press, however many events the platform makes out of it.
func _tap() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 90:
		return
	_last_tap_ms = now
	_advance()


func _advance() -> void:
	if _novel_layer == null:
		return
	var full := _line_text()
	if _typing:
		_shown = float(full.length())   # finish the line instantly
		_text_lbl.text = full
		_typing = false
		return
	if _rig != null and is_instance_valid(_rig):
		_rig.talking = false
	_li += 1
	if _li < _lines.size():
		G.play_sfx("click", 1.4, -14.0)
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
		# A tap on a phone arrives twice: once as a touch and once as the mouse
		# click the engine makes out of it. Both branches fired, so one tap
		# finished the line and skipped straight past it. Both are kept - touch
		# still has to work if mouse emulation is ever turned off - and the
		# second one within a moment is dropped instead.
		if event is InputEventMouseButton and event.pressed:
			_tap()
		elif event is InputEventScreenTouch and event.pressed:
			_tap()
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
