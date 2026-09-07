class_name EventEditor
extends Control
## The events editor: a map's storyboard, edited instead of hand-written.
##
## Events were always data - a list of {"t": seconds, "do": command, ...} in
## events.json next to the map - which is what makes them safe to download from
## a stranger. They were also invisible: the only way to add one was to open the
## file in a text editor and know the schema, which meant almost nobody did.
##
## Nothing about the format changes here. This reads the same file, writes the
## same file, and knows which arguments each command takes so the fields it puts
## on screen are the fields that command actually has.

signal closed

## The arguments each command takes, in the order they should be shown.
## kind: num | text | color. lo/hi bound the numbers; step is the spinner step.
const FIELDS := {
	"bg_color": [
		{"key": "hue", "kind": "num", "lo": 0.0, "hi": 1.0, "step": 0.005, "def": 0.985,
		 "hint": "0 red, 0.33 green, 0.66 blue"},
		{"key": "fade", "kind": "num", "lo": 0.0, "hi": 20.0, "step": 0.1, "def": 1.0,
		 "hint": "seconds to get there, 0 for at once"},
	],
	"bg_image": [
		{"key": "file", "kind": "text", "def": "",
		 "hint": "a file in this song's own folder"},
		{"key": "fade", "kind": "num", "lo": 0.0, "hi": 20.0, "step": 0.1, "def": 0.5},
		{"key": "dim", "kind": "num", "lo": 0.0, "hi": 1.0, "step": 0.05, "def": 0.6,
		 "hint": "how far it is pushed into the background"},
	],
	"note_skin": [
		{"key": "file", "kind": "text", "def": "",
		 "hint": "leave empty to go back to plain cubes"},
	],
	"note_scale": [
		{"key": "value", "kind": "num", "lo": 0.2, "hi": 6.0, "step": 0.05, "def": 1.0},
	],
	"flash": [
		{"key": "value", "kind": "num", "lo": 0.0, "hi": 1.0, "step": 0.05, "def": 0.6},
	],
	"shake": [
		{"key": "value", "kind": "num", "lo": 0.0, "hi": 1.0, "step": 0.05, "def": 0.5},
	],
	"zoom": [
		{"key": "value", "kind": "num", "lo": 0.6, "hi": 2.0, "step": 0.01, "def": 1.1},
		{"key": "fade", "kind": "num", "lo": 0.0, "hi": 20.0, "step": 0.1, "def": 0.4},
	],
	"text": [
		{"key": "value", "kind": "text", "def": "DROP"},
		{"key": "x", "kind": "num", "lo": -900.0, "hi": 900.0, "step": 5.0, "def": 0.0,
		 "hint": "from the middle of the playfield"},
		{"key": "y", "kind": "num", "lo": -900.0, "hi": 900.0, "step": 5.0, "def": 0.0},
		{"key": "size", "kind": "num", "lo": 0.0, "hi": 200.0, "step": 2.0, "def": 40.0,
		 "hint": "0 for the usual size"},
		{"key": "color", "kind": "color", "def": "ff2b3a"},
		{"key": "hold", "kind": "num", "lo": 0.05, "hi": 30.0, "step": 0.1, "def": 2.0,
		 "hint": "seconds on screen"},
	],
}

var song: Dictionary
var events: Array = []

var _list: VBoxContainer
var _form: VBoxContainer
var _sel := -1
var _toast: Label


func _ready() -> void:
	G.anchor_full(self)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.004, 0.008, 0.88)
	add_child(dim)
	G.anchor_full(dim)

	var title := G.label("EVENTS", 32, G.C_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	G.anchor_top_wide(title, 22, 44)

	var hint := G.label("A song's storyboard: backgrounds, note skins, camera moves and captions, on a timeline of their own.",
		15, G.C_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	G.anchor_top_wide(hint, 66, 24)

	# left: what there is
	var lscroll := ScrollContainer.new()
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(lscroll)
	G.anchor_margins(lscroll, 60, 108, 700, 92)
	DragScroll.attach(lscroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	lscroll.add_child(_list)

	# right: what the selected one says
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(rscroll)
	G.anchor_margins(rscroll, 600, 108, 60, 92)
	DragScroll.attach(rscroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 8)
	rscroll.add_child(_form)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	G.anchor_bottom_wide(bar, 26, 46, 60)
	bar.add_child(G.button("Add", _add, 20))
	bar.add_child(G.button("Delete", _delete, 20))
	bar.add_child(G.button("Save", _save, 20))
	bar.add_child(G.button("Close", func():
		G.play_sfx("click")
		closed.emit()
		queue_free(), 20))

	_toast = G.label("", 17, G.C_GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)
	G.anchor_bottom_wide(_toast, 82, 24, 60)

	_load()
	_refresh()


# ---------------------------------------------------------------- the file
func _path() -> String:
	return str(song.get("dir", "")) + "/events.json"


func _load() -> void:
	events = []
	var inline = song.get("events", [])
	if inline is Array and not (inline as Array).is_empty():
		events = (inline as Array).duplicate(true)
	elif FileAccess.file_exists(_path()):
		var data = JSON.parse_string(FileAccess.get_file_as_string(_path()))
		if data is Array:
			events = (data as Array).duplicate(true)
		elif data is Dictionary:
			events = ((data as Dictionary).get("events", []) as Array).duplicate(true)
	_sort()


func _sort() -> void:
	events.sort_custom(func(a, b): return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))


func _save() -> void:
	if not RhythmMap.is_user_song(song):
		_say("Save the map first — a built-in song has to be copied into your library.")
		G.play_sfx("miss", 1.0, -6.0)
		return
	_sort()
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		_say("Could not write events.json")
		G.play_sfx("miss", 1.0, -6.0)
		return
	f.store_string(JSON.stringify(events, "\t"))
	f.close()
	# the song carries them inline too, so a test run picks them up without a
	# trip back through the library scan
	song["events"] = events.duplicate(true)
	_say("Saved %d events" % events.size())
	G.play_sfx("click")


# ---------------------------------------------------------------- the list
func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if events.is_empty():
		_list.add_child(G.label("Nothing yet. Add is below.", 17, G.C_MUTED))
	for i in events.size():
		var idx := i
		var e: Dictionary = events[i]
		var b := G.button("%7.2fs   %s   %s" % [float(e.get("t", 0.0)),
			str(e.get("do", "?")), _summary(e)], func(): _select(idx), 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == _sel:
			b.add_theme_color_override("font_color", G.C_GOLD)
		_list.add_child(b)
	_build_form()


## One line saying what this event will do, so the list can be read without
## clicking every row in it.
func _summary(e: Dictionary) -> String:
	match str(e.get("do", "")):
		"bg_color": return "hue %.3f" % float(e.get("hue", 0.0))
		"bg_image", "note_skin": return str(e.get("file", ""))
		"text": return "\"%s\"" % str(e.get("value", ""))
		_: return "%.2f" % float(e.get("value", 0.0))


func _select(i: int) -> void:
	_sel = i
	G.play_sfx("click", 1.2, -12.0)
	_refresh()


func _add() -> void:
	G.play_sfx("click")
	var e := {"t": 0.0, "do": "flash"}
	for f in FIELDS["flash"]:
		e[str(f.key)] = f.def
	events.append(e)
	_sort()
	_sel = events.find(e)
	_refresh()


func _delete() -> void:
	if _sel < 0 or _sel >= events.size():
		return
	G.play_sfx("click", 0.9, -8.0)
	events.remove_at(_sel)
	_sel = mini(_sel, events.size() - 1)
	_refresh()


# ---------------------------------------------------------------- the form
func _build_form() -> void:
	for c in _form.get_children():
		c.queue_free()
	if _sel < 0 or _sel >= events.size():
		_form.add_child(G.label("Pick an event on the left, or add one.", 17, G.C_MUTED))
		return
	var e: Dictionary = events[_sel]

	_form.add_child(G.label("When", 16, G.C_MUTED))
	_form.add_child(_num_row(float(e.get("t", 0.0)), 0.0, 3600.0, 0.05, func(v):
		e["t"] = v
		_sort()
		_sel = events.find(e)
		_refresh()))

	_form.add_child(G.label("What", 16, G.C_MUTED))
	var pick := OptionButton.new()
	for cmd in SongScript.COMMANDS:
		pick.add_item(str(cmd))
	pick.selected = SongScript.COMMANDS.find(str(e.get("do", "flash")))
	pick.item_selected.connect(func(i):
		_switch_command(e, str(SongScript.COMMANDS[i])))
	_form.add_child(pick)

	var cmd := str(e.get("do", ""))
	for f in FIELDS.get(cmd, []):
		var key := str(f.key)
		_form.add_child(G.label(key, 16, G.C_MUTED))
		match str(f.kind):
			"num":
				_form.add_child(_num_row(float(e.get(key, f.def)),
					float(f.lo), float(f.hi), float(f.step), func(v):
						e[key] = v
						_refresh_row_only()))
			_:
				var le := LineEdit.new()
				le.text = str(e.get(key, f.def))
				le.custom_minimum_size = Vector2(240, 0)
				le.text_changed.connect(func(t):
					e[key] = t
					_refresh_row_only())
				_form.add_child(le)
		if f.has("hint"):
			var h := G.label(str(f.hint), 13, Color(1, 1, 1, 0.4))
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_form.add_child(h)


## Changing the command keeps the time and throws the rest away: the arguments
## of one command mean nothing to another, and carrying them over is how a
## half-filled event ends up in the file.
func _switch_command(e: Dictionary, cmd: String) -> void:
	var when: float = float(e.get("t", 0.0))
	e.clear()
	e["t"] = when
	e["do"] = cmd
	for f in FIELDS.get(cmd, []):
		e[str(f.key)] = f.def
	_refresh()


## The list line for the selected event, without rebuilding the form under the
## cursor - a field being typed into must not lose focus on every keystroke.
func _refresh_row_only() -> void:
	if _sel < 0 or _sel >= events.size() or _sel >= _list.get_child_count():
		return
	var b := _list.get_child(_sel) as Button
	if b == null:
		return
	var e: Dictionary = events[_sel]
	b.text = "%7.2fs   %s   %s" % [float(e.get("t", 0.0)), str(e.get("do", "?")),
		_summary(e)]


func _num_row(value: float, lo: float, hi: float, step: float, on: Callable) -> Control:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = value
	sb.custom_minimum_size = Vector2(180, 0)
	sb.value_changed.connect(on)
	return sb


func _say(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
