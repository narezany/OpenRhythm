class_name MapManager
extends Control
## Everything about a map that is not the notes: its name, who made the music,
## and which difficulties it has.
##
## All of it lived in map.json and nowhere else. Renaming a map, fixing an
## artist you typed wrong, or adding a second difficulty meant opening the file
## by hand - and deleting one meant knowing which array element to cut out
## without breaking the rest of it.
##
## Only for maps in the player's own library. A song that ships inside the
## binary cannot be written to at all, and the editor already knows how to fork
## one into the library when you save.

signal changed

var song: Dictionary

var _title: LineEdit
var _artist: LineEdit
var _rows: VBoxContainer
var _toast: Label


func _ready() -> void:
	G.anchor_full(self)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.004, 0.008, 0.9)
	add_child(dim)
	G.anchor_full(dim)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.8)))
	add_child(panel)
	G.anchor_margins(panel, 200, 70, 200, 70)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	DragScroll.attach(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	scroll.add_child(vb)

	var head := G.label("MAP DETAILS", 30, G.C_TEXT, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)

	vb.add_child(G.label("Title", 16, G.C_MUTED))
	_title = _line(str(song.get("title", "")))
	vb.add_child(_title)

	vb.add_child(G.label("Artist", 16, G.C_MUTED))
	_artist = _line(str(song.get("artist", "")))
	vb.add_child(_artist)

	vb.add_child(G.label("Difficulties", 16, G.C_MUTED))
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	vb.add_child(_rows)
	_fill_rows()

	var add := G.button("+  Add a difficulty", _add_diff, 19)
	vb.add_child(add)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(bar)
	bar.add_child(G.button("Save", _save, 22))
	bar.add_child(G.button("Close", _close, 22))

	_toast = G.label("", 16, G.C_GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	vb.add_child(_toast)


func _fill_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var diffs: Array = song.get("difficulties", [])
	for i in diffs.size():
		var idx := i
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_edit := _line(str(diffs[idx].get("name", "")))
		name_edit.custom_minimum_size = Vector2(280, 0)
		name_edit.text_changed.connect(func(t): diffs[idx]["name"] = t)
		row.add_child(name_edit)
		var count := (diffs[idx].get("notes", []) as Array).size()
		var n := G.label("%d notes" % count, 15, G.C_MUTED)
		n.custom_minimum_size = Vector2(110, 0)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(n)
		row.add_child(G.button("Edit", func(): _edit(idx), 17))
		row.add_child(G.button("Delete", func(): _delete(idx), 17))
		_rows.add_child(row)


## A new difficulty starts empty and is named after where it sits, because a
## second one called the same as the first is the one mistake this panel can
## make that the game cannot undo for you.
func _add_diff() -> void:
	var diffs: Array = song.get("difficulties", [])
	if diffs.is_empty():
		song["difficulties"] = diffs
	var name := "Level %d" % (diffs.size() + 1)
	diffs.append({"name": name, "notes": []})
	song["difficulties"] = diffs
	G.play_sfx("click")
	_fill_rows()


func _delete(idx: int) -> void:
	var diffs: Array = song.get("difficulties", [])
	if diffs.size() <= 1:
		_say("A map needs at least one difficulty.")
		G.play_sfx("miss", 1.0, -6.0)
		return
	diffs.remove_at(idx)
	song["difficulties"] = diffs
	G.play_sfx("click", 0.9, -8.0)
	_fill_rows()


func _edit(idx: int) -> void:
	_apply_names()
	if RhythmMap.write_map(song) == "":
		_say("Could not write map.json")
		return
	G.play_sfx("click")
	G.main.open_editor(song, idx)


func _apply_names() -> void:
	song["title"] = _title.text.strip_edges()
	song["artist"] = _artist.text.strip_edges()


func _save() -> void:
	_apply_names()
	if RhythmMap.write_map(song) == "":
		_say("Could not write map.json")
		G.play_sfx("miss", 1.0, -6.0)
		return
	_say("Saved")
	G.play_sfx("click")
	changed.emit()


func _close() -> void:
	G.play_sfx("click")
	changed.emit()
	queue_free()


func _line(text: String) -> LineEdit:
	var le := LineEdit.new()
	le.text = text
	le.custom_minimum_size = Vector2(360, 0)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return le


func _say(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
