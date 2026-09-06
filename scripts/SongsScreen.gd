class_name SongsScreen
extends Control
## Song manager: show the library folder, enable/disable, delete, import maps
## from other games.

var list_vb: VBoxContainer
var scroll: ScrollContainer
var toast: Label
var _import_dialog: FileDialog
var _toast_tween: Tween


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	add_child(BackgroundFX.new(true))

	var title := G.label("SONGS", 46, G.C_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	G.anchor_top_wide(title, 24, 60)

	var path_row := HBoxContainer.new()
	path_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(path_row)
	G.anchor_top_wide(path_row, 84, 26)
	var pl := G.label("%s  %s" % [tr("Library folder:"), RhythmMap.user_songs_dir()],
		16, G.C_MUTED)
	path_row.add_child(pl)
	var copy_btn := G.button("Copy path", func():
		DisplayServer.clipboard_set(RhythmMap.user_songs_dir())
		G.play_sfx("click"), 14)
	copy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	path_row.add_child(copy_btn)

	var hint := G.label("Drop song folders or .zip packs here, then press RESCAN. Or press IMPORT and pick a pack, an .sspm or a Sound Space map.",
		15, Color(1, 1, 1, 0.4))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	G.anchor_top_wide(hint, 110, 22)

	if RhythmMap.storage_denied_flag:
		var warn := G.label(
			"Storage access denied — I can't see your custom songs, dude.\nAllow \"All files access\" for Open Rhythm in Android Settings → Apps → Open Rhythm → Permissions.",
			16, G.C_GOLD)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(warn)
		G.anchor_top_wide(warn, 134, 44)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	G.anchor_margins(scroll, 160, 146, 160, 112)

	list_vb = VBoxContainer.new()
	list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vb.add_theme_constant_override("separation", 12)
	scroll.add_child(list_vb)

	toast = G.label("", 19, G.C_GOLD)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	add_child(toast)
	G.anchor_bottom_wide(toast, 104, 26)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	add_child(hb)
	G.anchor_bottom_wide(hb, 42, 50)
	hb.add_child(G.button("IMPORT MAP", _open_import, 24))
	hb.add_child(G.button("RESCAN", _rebuild, 24))
	hb.add_child(G.button("← Back", func(): G.main.goto_menu(), 24))

	_rebuild()


func _rebuild() -> void:
	for c in list_vb.get_children():
		c.queue_free()
	var songs := RhythmMap.load_songs()
	var disabled: Array = G.disabled_songs
	for song in songs:
		var sid := str(song.get("id", ""))
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", G.panel_style())
		var hb2 := HBoxContainer.new()
		hb2.add_theme_constant_override("separation", 16)
		row.add_child(hb2)

		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		var t := G.label(str(song.get("title", "?")), 26,
			G.C_TEXT if not sid in disabled else G.C_MUTED)
		left.add_child(t)
		var bits := "%s  •  %d BPM" % [str(song.get("artist", "")),
			roundi(float(song.get("bpm", 120.0)))]
		if str(song.get("video", "")) != "":
			bits += "  •  ♪ video"
		if str(song.get("source", "")) != "":
			bits += "  •  imported"
		if sid in disabled:
			bits += "  •  DISABLED"
		left.add_child(G.label(bits, 15, G.C_MUTED))
		hb2.add_child(left)

		var tog := G.button("Enable" if sid in disabled else "Disable",
			_toggle.bind(sid), 18)
		tog.custom_minimum_size = Vector2(120, 0)
		hb2.add_child(tog)
		if RhythmMap.is_user_song(song):
			var del := G.button("Delete", _delete.bind(song), 18)
			del.custom_minimum_size = Vector2(120, 0)
			hb2.add_child(del)
		list_vb.add_child(row)

	if songs.is_empty():
		var e := G.label("Library is empty.", 22, G.C_MUTED)
		e.size = Vector2(0, 60)
		list_vb.add_child(e)


func _toggle(sid: String) -> void:
	if sid in G.disabled_songs:
		G.disabled_songs.erase(sid)
	else:
		G.disabled_songs.append(sid)
	G.save_all()
	G.play_sfx("click")
	_rebuild()


## Delete by the song's own folder - the folder name and the id need not match.
func _delete(song: Dictionary) -> void:
	if RhythmMap.delete_song(song):
		_toast("%s: %s" % [tr("Delete"), str(song.get("title", ""))])
	else:
		_toast("Could not delete that folder")
	G.play_sfx("click", 0.7, -4.0)
	_rebuild()


# ---------------------------------------------------------------- import
func _open_import() -> void:
	G.play_sfx("click")
	if _import_dialog == null:
		_import_dialog = FileDialog.new()
		_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_import_dialog.filters = PackedStringArray([
			"*.zip ; Open Rhythm song pack",
			"*.sspm ; Sound Space Plus / Rhythia map",
			"*.txt ; Sound Space map data",
		])
		_import_dialog.title = "Import a song pack or a map"
		_import_dialog.size = Vector2i(900, 600)
		_import_dialog.file_selected.connect(_do_import)
		add_child(_import_dialog)
	_import_dialog.current_dir = RhythmMap.user_songs_dir()
	_import_dialog.popup_centered()


func _do_import(path: String) -> void:
	# One of ours goes straight into the library - it is already a song, not a
	# map from another game that has to be converted into one.
	if path.get_extension().to_lower() == "zip":
		var pack := RhythmMap.install_zip(path)
		if not pack.get("ok", false):
			_toast(str(pack.get("error", "Import failed")))
			G.play_sfx("miss", 1.0, -6.0)
			return
		_toast("%s added" % str(pack.get("name", "")))
		G.play_sfx("click", 1.3)
		_rebuild()
		return
	var res := MapImport.import_path(path)
	if not res.get("ok", false):
		_toast(str(res.get("error", "Import failed")))
		G.play_sfx("miss", 1.0, -6.0)
		return
	Achievements.unlock("importer")
	var song: Dictionary = res.get("song", {})
	var msg := "%s — %d notes" % [str(song.get("title", "")), int(res.get("note_count", 0))]
	if res.get("needs_audio", false):
		msg += " — drop an audio file into the song folder"
	_toast(msg)
	G.play_sfx("click", 1.3)
	_rebuild()


func _toast(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		return


## Esc, and the Android back button: close the import dialog first.
func go_back() -> void:
	if _import_dialog != null and _import_dialog.visible:
		_import_dialog.hide()
		return
	G.main.goto_menu()
