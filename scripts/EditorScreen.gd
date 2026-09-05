class_name EditorScreen
extends Control
## Map editor.
##
## Layout: the 3x3 playfield on the left places notes at the playhead, the tool
## panel sits top right, and the bottom half is a piano roll - nine lanes over
## time with a waveform and a beat grid. Notes are selected, moved, copied and
## given a hold length there.
##
## Keys: Space play/pause, arrows seek (Shift = a bar), 1..8 snap, Ctrl+Z/Y
## undo/redo, Ctrl+C/V copy/paste, Ctrl+A select all, Ctrl+D duplicate,
## Delete remove, H toggle hold on the selection, Ctrl+S save, T test.

const APPROACH := 1.0
const SIZES := [0.8, 1.0, 1.25]
const SNAPS := [1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0]
const RATES := [0.5, 0.75, 1.0]
const WAVE_RATE := 100.0        # waveform peaks per second
const FIELD_MIN := 0.42         # never shrink the playfield below this

var song: Dictionary
var diff_idx := 0
var notes: Array = []           # {t, cell, s, h, hit, half, node, ...}
var cur_time := 0.0
var playing := false
var bpm := 120.0
var length := 60.0
var snap_div := 4.0
var size_i := 1
var rate_i := 2

var wave_peaks: PackedFloat32Array = PackedFloat32Array()
var wave_rate := WAVE_RATE

var history := EditorHistory.new()
var clipboard: Array = []

var bg: BackgroundFX
var frame_view: FrameView
var ghost_layer: GhostLayer
var notes_root: Node2D
var shock: ShockLayer
var timeline: EditorTimeline

var hud: CanvasLayer
var info_label: Label
var toast: Label
var play_btn: Button
var bpm_label: Label
var snap_label: Label
var size_btn: Button
var rate_btn: Button
var side_panel: PanelContainer
var top_bar: HFlowContainer
var audio_panel: PanelContainer
var auto_dense: HSlider
var auto_holds: CheckBox
var auto_clicks: CheckBox
var click_btn: Button
## New notes placed on the playfield become click notes while this is on.
var click_mode := false
var _audio_path: LineEdit
var _toast_tween: Tween
var _file_dialog: FileDialog

var drag_note: Dictionary = {}
var drag_offset := Vector2.ZERO
var _press_t_ms := 0
var _press_local := Vector2.ZERO
var _longfired := false
var _touch_gen := 0

var playfield_center := Vector2(330, 250)
var field_scale := 0.78


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	# the root must not swallow clicks: the playfield is driven from
	# _unhandled_input, while the HUD children keep their own events
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bpm = float(song.get("bpm", 120.0))
	length = float(song.get("length", 60.0))
	G.editor_song = song
	G.editor_diff = diff_idx

	var custom := RhythmMap.custom_of(song)
	if not custom.is_empty():
		_load_notes(custom)
	else:
		var diffs := RhythmMap.diffs_of(song)
		var d: Dictionary = diffs[clampi(diff_idx, 0, diffs.size() - 1)]
		_load_notes(d.get("notes", []))

	_build()
	_compute_waveform()
	_set_status()


# ---------------------------------------------------------------- data
func _load_notes(raw: Array) -> void:
	for nd in raw:
		var n := {
			"t": float(nd.get("t", 0.0)),
			"s": maxf(float(nd.get("s", 1.0)), 0.4),
			"h": maxf(float(nd.get("h", 0.0)), 0.0),
			"c": bool(nd.get("c", false)),
		}
		if nd.has("cell"):
			n["cell"] = wrapi(int(nd.get("cell", 0)), 0, 9)
		else:
			n["cell"] = G.angle_to_cell(float(nd.get("a", 0.0)))
		recalc(n)
		notes.append(n)
	notes.sort_custom(func(a, b): return a.t < b.t)


func recalc(n: Dictionary) -> void:
	var cell := int(n.get("cell", 4))
	n["half"] = 52.0 * float(n.s)
	n["hit"] = G.cell_pos(cell)
	n["spawn"] = n.hit * (0.10 + 0.22 * float(n.get("d", 0.35)))
	n["color"] = Color.WHITE
	n["spin"] = 0.8
	if not n.has("node"):
		n["node"] = null


func _serialize() -> Array:
	var out: Array = []
	for n in notes:
		var e := {"t": snappedf(float(n.t), 0.001), "cell": int(n.cell),
			"s": float(n.s)}
		if float(n.get("h", 0.0)) > 0.0:
			e["h"] = snappedf(float(n.h), 0.001)
		if bool(n.get("c", false)):
			e["c"] = true
		out.append(e)
	return out


# ---------------------------------------------------------------- edit API
## Snap a time to the current grid division.
func snap_time(t: float) -> float:
	return maxf(snappedf(t, _snap_step()), 0.0)


func _snap_step() -> float:
	return 60.0 / maxf(bpm, 1.0) / maxf(snap_div, 1.0)


func push_history(label := "") -> void:
	history.push(notes, label)


func add_note(t: float, cell: int, hold := 0.0, click := false) -> Dictionary:
	for n in notes:
		if int(n.cell) == cell and absf(float(n.t) - t) < 0.001:
			return n
	var n := {"t": t, "cell": cell, "s": SIZES[size_i], "h": hold, "c": click}
	recalc(n)
	notes.append(n)
	notes_changed()
	G.play_sfx("click", 1.3, -6.0)
	return n


func erase_note(n: Dictionary) -> void:
	if n.get("node") != null and is_instance_valid(n.node):
		n.node.queue_free()
	notes.erase(n)
	notes_changed()
	G.play_sfx("click", 0.8, -8.0)


## Re-sort, refresh views and the status line after any edit.
func notes_changed() -> void:
	notes.sort_custom(func(a, b): return float(a.t) < float(b.t))
	_sync_note_views()
	_set_status()
	if timeline != null:
		timeline.queue_redraw()


func _restore(snapshot: Array) -> void:
	for n in notes:
		if n.get("node") != null and is_instance_valid(n.node):
			n.node.queue_free()
	notes.clear()
	for nd in snapshot:
		var n := {"t": float(nd.t), "cell": int(nd.cell), "s": float(nd.s),
			"h": float(nd.get("h", 0.0)), "c": bool(nd.get("c", false)),
			"node": null}
		recalc(n)
		notes.append(n)
	if timeline != null:
		timeline.selection.clear()
	notes_changed()


func _undo() -> void:
	if not history.can_undo():
		_show_toast("Nothing to undo")
		return
	_restore(history.undo(notes))
	_show_toast("Undo")


func _redo() -> void:
	if not history.can_redo():
		return
	_restore(history.redo(notes))
	_show_toast("Redo")


func _copy() -> void:
	if timeline.selection.is_empty():
		return
	var base := INF
	for n in timeline.selection:
		base = minf(base, float(n.t))
	clipboard.clear()
	for n in timeline.selection:
		clipboard.append({"dt": float(n.t) - base, "cell": int(n.cell),
			"s": float(n.s), "h": float(n.get("h", 0.0)),
			"c": bool(n.get("c", false))})
	_show_toast("Copied %d notes" % clipboard.size())


func _paste() -> void:
	if clipboard.is_empty():
		return
	push_history("paste")
	var added: Array = []
	for e in clipboard:
		added.append(add_note(cur_time + float(e.dt), int(e.cell), float(e.h),
			bool(e.get("c", false))))
	timeline.selection = added
	_show_toast("Pasted %d notes" % added.size())


func _duplicate() -> void:
	if timeline.selection.is_empty():
		return
	push_history("duplicate")
	var span := 0.0
	var base := INF
	for n in timeline.selection:
		base = minf(base, float(n.t))
		span = maxf(span, float(n.t) + float(n.get("h", 0.0)))
	var shift := maxf(span - base, _snap_step())
	var added: Array = []
	for n in timeline.selection:
		added.append(add_note(float(n.t) + shift, int(n.cell),
			float(n.get("h", 0.0)), bool(n.get("c", false))))
	timeline.selection = added


func _delete_selection() -> void:
	if timeline.selection.is_empty():
		return
	push_history("delete")
	for n in timeline.selection.duplicate():
		erase_note(n)
	timeline.selection.clear()


## C: make the selection click notes, or take it back if they already are.
func _toggle_click() -> void:
	if timeline.selection.is_empty():
		click_mode = not click_mode
		_update_click_btn()
		_show_toast("New notes are click notes" if click_mode
			else "New notes are normal")
		return
	push_history("click")
	var any_plain := false
	for n in timeline.selection:
		if not bool(n.get("c", false)):
			any_plain = true
	for n in timeline.selection:
		n["c"] = any_plain
	notes_changed()
	_show_toast("Click notes: %s" % ("on" if any_plain else "off"))


func _update_click_btn() -> void:
	if click_btn != null:
		click_btn.add_theme_color_override("font_color",
			G.C_PRIMARY if click_mode else G.C_TEXT)


## H: give the selection a one-beat hold, or take it away if it already has one.
func _toggle_hold() -> void:
	if timeline.selection.is_empty():
		_show_toast("Select notes first (drag in the timeline)")
		return
	push_history("hold")
	var beat := 60.0 / maxf(bpm, 1.0)
	var any_plain := false
	for n in timeline.selection:
		if float(n.get("h", 0.0)) <= 0.0:
			any_plain = true
	for n in timeline.selection:
		n["h"] = beat if any_plain else 0.0
	notes_changed()
	_show_toast("Hold notes: %s" % ("on" if any_plain else "off"))


# ---------------------------------------------------------------- build
func _build() -> void:
	bg = BackgroundFX.new()
	add_child(bg)

	# the playfield is shrunk to leave the bottom half to the timeline; every
	# layer shares the same scale so hit tests and drawing stay aligned
	ghost_layer = GhostLayer.new()
	ghost_layer.position = playfield_center
	ghost_layer.scale = Vector2.ONE * field_scale
	add_child(ghost_layer)
	frame_view = FrameView.new()
	frame_view.position = playfield_center
	frame_view.grid_alpha = 0.18
	frame_view.scale = Vector2.ONE * field_scale
	add_child(frame_view)
	notes_root = Node2D.new()
	notes_root.position = playfield_center
	notes_root.scale = Vector2.ONE * field_scale
	add_child(notes_root)
	shock = ShockLayer.new()
	shock.position = playfield_center
	shock.scale = Vector2.ONE * field_scale
	add_child(shock)

	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var title := G.label("EDITOR — %s" % str(song.get("title", "?")), 22, G.C_TEXT)
	title.position = Vector2(14, 6)
	hud.add_child(title)
	info_label = G.label("", 16, G.C_MUTED)
	info_label.position = Vector2(14, 30)
	hud.add_child(info_label)

	_build_top_bar()
	_build_side_panel()

	timeline = EditorTimeline.new()
	timeline.ed = self
	hud.add_child(timeline)

	toast = G.label("", 19, G.C_GOLD)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	hud.add_child(toast)

	if str(song.get("audio", "")) == "":
		_build_audio_row()

	if G.is_mobile():
		var note := G.label("Touch editing works, but the desktop build is far comfier for serious mapping.",
			14, Color(1, 1, 1, 0.4))
		note.position = Vector2(14, 50)
		hud.add_child(note)

	G.view_changed.connect(_relayout)
	_relayout()


func _build_top_bar() -> void:
	# a flow container so the transport wraps onto a second line on a narrow
	# window instead of sliding off the right edge
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	row.alignment = FlowContainer.ALIGNMENT_END
	hud.add_child(row)
	top_bar = row

	play_btn = G.button("▶  Play", _toggle_play, 18)
	play_btn.custom_minimum_size = Vector2(120, 0)
	row.add_child(play_btn)
	row.add_child(G.button("⏮", func(): seek_to(0.0), 18))
	row.add_child(G.button("Undo", _undo, 18))
	row.add_child(G.button("Redo", _redo, 18))
	row.add_child(G.button("Save", _save, 18))
	row.add_child(G.button("Test", _test, 18))
	row.add_child(G.button("← Back", func():
		_save()
		G.main.goto_select("edit"), 18))


func _build_side_panel() -> void:
	side_panel = PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", G.panel_style())
	hud.add_child(side_panel)

	# the tools live in a scroll: whatever the window size, nothing is cut off
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)

	# --- snap ---
	var snap_row := HFlowContainer.new()
	snap_row.add_theme_constant_override("h_separation", 4)
	snap_row.add_theme_constant_override("v_separation", 4)
	snap_row.add_child(_tag("Snap"))
	for d in SNAPS:
		var div: float = d
		var b := G.button("1/%d" % int(d), func(): _set_snap(div), 15)
		b.custom_minimum_size = Vector2(52, 0)
		snap_row.add_child(b)
	vb.add_child(snap_row)
	snap_label = G.label("", 15, G.C_MUTED)
	vb.add_child(snap_label)

	# --- bpm / rate / size ---
	var row2 := HFlowContainer.new()
	row2.add_theme_constant_override("v_separation", 6)
	row2.add_theme_constant_override("h_separation", 6)
	row2.add_child(_tag("BPM"))
	row2.add_child(G.button("−1", func(): _bpm_change(-1.0), 15))
	bpm_label = G.label("%d" % roundi(bpm), 20, G.C_TEXT)
	bpm_label.custom_minimum_size = Vector2(58, 0)
	bpm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row2.add_child(bpm_label)
	row2.add_child(G.button("+1", func(): _bpm_change(1.0), 15))
	row2.add_child(G.button("−0.1", func(): _bpm_change(-0.1), 15))
	row2.add_child(G.button("+0.1", func(): _bpm_change(0.1), 15))
	vb.add_child(row2)

	var row3 := HFlowContainer.new()
	row3.add_theme_constant_override("v_separation", 6)
	row3.add_theme_constant_override("h_separation", 6)
	size_btn = G.button("Size  x%.2f" % SIZES[size_i], _cycle_size, 15)
	row3.add_child(size_btn)
	rate_btn = G.button("Speed  %.2fx" % RATES[rate_i], _cycle_rate, 15)
	row3.add_child(rate_btn)
	row3.add_child(G.button("Hold note", _toggle_hold, 15))
	click_btn = G.button("Click note", _toggle_click, 15)
	row3.add_child(click_btn)
	row3.add_child(G.button("Select all", func(): timeline.select_all(), 15))
	vb.add_child(row3)

	var row4 := HFlowContainer.new()
	row4.add_theme_constant_override("v_separation", 6)
	row4.add_theme_constant_override("h_separation", 6)
	row4.add_child(G.button("Copy", _copy, 15))
	row4.add_child(G.button("Paste", _paste, 15))
	row4.add_child(G.button("Duplicate", _duplicate, 15))
	row4.add_child(G.button("Delete", _delete_selection, 15))
	vb.add_child(row4)

	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.custom_minimum_size = Vector2(0, 2)
	vb.add_child(sep)

	# --- auto generator ---
	vb.add_child(_tag("Auto-generate from the audio"))
	var row5 := HFlowContainer.new()
	row5.add_theme_constant_override("v_separation", 6)
	row5.add_theme_constant_override("h_separation", 8)
	auto_dense = HSlider.new()
	auto_dense.min_value = 20.0
	auto_dense.max_value = 100.0
	auto_dense.step = 5.0
	auto_dense.value = 60.0
	auto_dense.custom_minimum_size = Vector2(220, 24)
	row5.add_child(auto_dense)
	auto_holds = _auto_check("Hold notes", true)
	row5.add_child(auto_holds)
	auto_clicks = _auto_check("Click notes", true)
	row5.add_child(auto_clicks)
	row5.add_child(G.button("Generate", _auto_build, 16))
	vb.add_child(row5)
	var ahint := G.label("Replaces the whole chart. Onset detection needs a .wav; other formats get an even beat grid.",
		13, Color(1, 1, 1, 0.4))
	ahint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ahint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ahint.custom_minimum_size = Vector2(200, 0)
	vb.add_child(ahint)

	var keys := G.label("Timeline: drag = select · Ctrl+click = add · drag the right edge = hold length · wheel = scroll · Ctrl+wheel = zoom · middle drag = pan",
		13, Color(1, 1, 1, 0.35))
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.custom_minimum_size = Vector2(200, 0)
	vb.add_child(keys)

	_update_snap_label()


func _auto_check(text: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_override("font", G.font_body)
	c.add_theme_font_size_override("font_size", 15)
	return c


func _tag(text: String) -> Label:
	var l := G.label(text, 16, G.C_MUTED)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(74, 0)
	return l


## Fit the three regions - transport, playfield + tools, timeline - into
## whatever canvas we got. Everything is anchored, so this runs on a resize
## rather than every frame.
func _relayout() -> void:
	var canvas := G.canvas_size()
	var tl_h: float = clampf(canvas.y * 0.42, 190.0, 360.0)
	var work_top := 58.0
	var work_h: float = maxf(canvas.y - tl_h - work_top - 24.0, 140.0)

	if timeline != null:
		G.anchor_bottom_wide(timeline, 12.0, tl_h, 14.0)
	if top_bar != null:
		G.anchor_margins(top_bar, minf(canvas.x * 0.34, 430.0), 6.0, 14.0,
			maxf(canvas.y - 52.0, 0.0))
	if toast != null:
		G.anchor_top_wide(toast, 54.0, 26.0)
	if info_label != null:
		info_label.position = Vector2(14.0, 30.0)

	# the tool panel takes the right half, the playfield what is left
	var panel_w: float = clampf(canvas.x * 0.46, 320.0, 760.0)
	if side_panel != null:
		G.anchor_margins(side_panel, canvas.x - panel_w - 14.0, work_top,
			14.0, tl_h + 24.0)
	var left_w: float = maxf(canvas.x - panel_w - 42.0, 200.0)
	playfield_center = Vector2(14.0 + left_w * 0.5, work_top + work_h * 0.5)
	# 560 design units is the frame plus a margin; shrink to fit, never grow
	field_scale = clampf(minf(left_w, work_h) / 560.0, FIELD_MIN, 1.0)
	for n in [frame_view, ghost_layer, notes_root, shock]:
		if n != null and is_instance_valid(n):
			n.position = playfield_center
			n.scale = Vector2.ONE * field_scale
	if audio_panel != null and is_instance_valid(audio_panel):
		G.anchor_margins(audio_panel, 14.0, work_top + work_h - 106.0,
			canvas.x - left_w + 14.0, tl_h + 24.0)


# ---------------------------------------------------------------- playfield
func _update_note_view(n: Dictionary) -> void:
	if n.get("node") == null or not is_instance_valid(n.node):
		return
	var near: bool = absf(float(n.t) - cur_time) <= (APPROACH if playing else 0.35)
	n.node.visible = near
	if not near:
		return
	n.node.progress = 1.0
	n.node.position = n.hit
	n.node.rotation = 0.0
	n.node.hold_total = float(n.get("h", 0.0))
	n.node.is_click = bool(n.get("c", false))
	n.node.hold_left = 1.0
	n.node.scale = Vector2.ONE


func _ghost_items() -> Array:
	var items: Array = []
	for n in notes:
		if absf(float(n.t) - cur_time) <= 0.35:
			items.append({"hit": n.hit, "half": n.half, "progress": 1.0,
				"color": n.color, "done": false, "hover": false, "node": n.get("node")})
	return items


## Rebuild missing views and drop orphans - the cure for phantom notes.
func _sync_note_views() -> void:
	for n in notes:
		if n.get("node") == null or not is_instance_valid(n.node):
			var v := NoteView.new()
			v.half = n.half
			v.hold_total = float(n.get("h", 0.0))
			v.is_click = bool(n.get("c", false))
			v.set_color(n.color)
			notes_root.add_child(v)
			notes_root.move_child(v, 0)
			n["node"] = v
			_update_note_view(n)
	for c in notes_root.get_children():
		var found := false
		for n in notes:
			if n.get("node") == c:
				found = true
				break
		if not found:
			c.queue_free()


func _place(local: Vector2) -> void:
	push_history("add note")
	var n := add_note(snap_time(cur_time), G.cell_index(local), 0.0, click_mode)
	shock.ring(n.hit, Color.WHITE, 70.0)
	if timeline != null:
		timeline.selection = [n]


func _delete_at(local: Vector2) -> void:
	var best: Dictionary = {}
	var best_d := 70.0
	for n in notes:
		if absf(float(n.t) - cur_time) > maxf(_snap_step(), 0.12):
			continue
		var d: float = local.distance_to(n.hit)
		if d < best_d:
			best_d = d
			best = n
	if not best.is_empty():
		push_history("delete note")
		erase_note(best)


func _pick(local: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 70.0
	for n in notes:
		if absf(float(n.t) - cur_time) > 0.35:
			continue
		var d: float = local.distance_to(n.hit)
		if d < best_d:
			best_d = d
			best = n
	return best


# ---------------------------------------------------------------- transport
func _seek(beats: float) -> void:
	seek_to(cur_time + beats * 60.0 / bpm)


func seek_to(t: float) -> void:
	cur_time = clampf(t, 0.0, maxf(length - 0.05, 0.0))
	Conductor.seek(cur_time)
	if timeline != null:
		timeline.follow(cur_time)
	_set_status()


func _toggle_play() -> void:
	if playing:
		playing = false
		Conductor.stop_music()
		play_btn.text = "▶  Play"
	else:
		playing = true
		Conductor.play_music(RhythmMap.audio_stream(song), cur_time, bpm,
			0.0, false, RATES[rate_i])
		play_btn.text = "⏸  Pause"


func _set_snap(div: float) -> void:
	snap_div = div
	_update_snap_label()
	if timeline != null:
		timeline.queue_redraw()


func _update_snap_label() -> void:
	if snap_label != null:
		snap_label.text = tr("grid 1/%d   •   step %.3f s") % [int(snap_div), _snap_step()]


func _cycle_size() -> void:
	size_i = (size_i + 1) % SIZES.size()
	size_btn.text = "Size  x%.2f" % SIZES[size_i]


func _cycle_rate() -> void:
	rate_i = (rate_i + 1) % RATES.size()
	rate_btn.text = "Speed  %.2fx" % RATES[rate_i]
	if playing:
		_toggle_play()
		_toggle_play()


func _bpm_change(delta_bpm: float) -> void:
	bpm = clampf(bpm + delta_bpm, 40.0, 300.0)
	song["bpm"] = bpm
	if bpm_label != null:
		bpm_label.text = "%.1f" % bpm
	_update_snap_label()
	if timeline != null:
		timeline.queue_redraw()
	_set_status()


func _save() -> String:
	# A built-in song lives inside the binary and cannot be written to, so the
	# first save forks it into the player's library and the editor carries on
	# in the copy - the same as if the map had been created from scratch.
	if not RhythmMap.is_user_song(song):
		var copy := RhythmMap.fork_song(song)
		if copy.is_empty():
			_show_toast("Could not copy this song into your library")
			return ""
		song = copy
		G.editor_song = song
		_show_toast("Copied to your library: %s" % str(song.get("dir", "")))
	var path := RhythmMap.save_custom(song, _serialize(), diff_idx)
	if path != "":
		_show_toast("Saved: %s" % path)
		Achievements.unlock("mapper")
		G.play_sfx("click")
	return path


func _test() -> void:
	_save()
	G.custom_test = {"song": song, "notes": _serialize(), "name": "Custom"}
	G.return_screen = "editor"
	G.main.start_game()


# ------------------------------------------------------------- audio analysis
## Single pass over a WAV: 20 ms energy frames for onset detection plus peak
## amplitudes for the waveform strip. Other formats cannot be decoded from
## GDScript, so they get the beat grid only.
func _analyze_wav(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	f.seek(12)
	var sr := 44100
	var bits := 16
	var ch := 1
	while f.get_position() < f.get_length() - 8:
		var id4 := f.get_buffer(4).get_string_from_ascii()
		var sz := f.get_32()
		if id4 == "fmt ":
			f.get_16()
			ch = f.get_16()
			sr = f.get_32()
			f.get_32()
			f.get_16()
			bits = f.get_16()
			if sz > 16:
				f.seek(f.get_position() + sz - 16)
		elif id4 == "data":
			var frames := int(sz / maxi(bits / 8 * ch, 1))
			var win := int(sr * 0.02)
			var pwin := int(sr / WAVE_RATE)
			var energies: Array = []
			var peaks := PackedFloat32Array()
			var acc := 0.0
			var cnt := 0
			var pk := 0.0
			var pcnt := 0
			for i in frames:
				var v := 0.0
				if bits == 16:
					v = f.get_16() / 32768.0
					if v > 1.0:
						v -= 2.0                # get_16 is unsigned
					if ch == 2:
						var v2 := f.get_16() / 32768.0
						if v2 > 1.0:
							v2 -= 2.0
						v = (v + v2) * 0.5
				elif bits == 8:
					v = (f.get_8() - 128) / 128.0
				else:
					f.seek(f.get_position() + bits / 8 - 1)
				acc += v * v
				cnt += 1
				pk = maxf(pk, absf(v))
				pcnt += 1
				if cnt >= win:
					energies.append(acc / cnt)
					acc = 0.0
					cnt = 0
				if pcnt >= pwin:
					peaks.append(pk)
					pk = 0.0
					pcnt = 0
			if cnt > 0:
				energies.append(acc / cnt)
			if pcnt > 0:
				peaks.append(pk)
			return {"frame": 0.02, "e": energies, "peaks": peaks}
		else:
			f.seek(f.get_position() + sz + (sz & 1))
	return {}


func _compute_waveform() -> void:
	wave_peaks = PackedFloat32Array()
	var path := str(song.get("dir", "")) + "/" + str(song.get("audio", ""))
	if not FileAccess.file_exists(path) or path.get_extension().to_lower() != "wav":
		return
	var a := _analyze_wav(path)
	if a.is_empty():
		return
	var peaks: PackedFloat32Array = a.get("peaks", PackedFloat32Array())
	var mx := 0.0
	for p in peaks:
		mx = maxf(mx, p)
	if mx <= 0.0001:
		return
	for i in peaks.size():
		peaks[i] = peaks[i] / mx
	wave_peaks = peaks
	if timeline != null:
		timeline.queue_redraw()


func _flux_of(energies: Array) -> Array:
	var mx := 0.0
	for e in energies:
		mx = maxf(mx, e)
	if mx <= 0.0:
		return []
	var fl: Array = []
	for i in range(1, energies.size()):
		var dv: float = energies[i] - energies[i - 1]
		fl.append(maxf(dv, 0.0) / mx)
	return fl


## Comb filter: sum the flux at beat positions across 60..200 BPM.
func _detect_bpm(flux: Array, frame: float) -> float:
	var best := 120.0
	var best_s := -1.0
	var b := 60.0
	while b <= 200.0:
		var L := int(round(60.0 / b / frame))
		if L < 2:
			break
		var s := 0.0
		var c := 0
		var t := 0
		while t < flux.size():
			s += flux[t]
			c += 1
			t += L
		s /= maxf(c, 1)
		if s > best_s:
			best_s = s
			best = b
		b += 1.0
	return best


func _auto_build() -> void:
	var path := str(song.get("dir", "")) + "/" + str(song.get("audio", ""))
	var use_bpm := bpm
	var onsets: Array = []
	if FileAccess.file_exists(path) and path.get_extension().to_lower() == "wav":
		var en := _analyze_wav(path)
		if not en.is_empty():
			var fl := _flux_of(en["e"])
			if absf(bpm - 120.0) < 0.01 and not fl.is_empty():
				use_bpm = snappedf(_detect_bpm(fl, en["frame"]), 0.1)
			var frame: float = en["frame"]
			var last := -10.0
			for i in fl.size():
				var t := i * frame
				if fl[i] > 0.18 and t - last >= 0.11:
					onsets.append(t)
					last = t
	else:
		onsets = _grid_onsets(use_bpm)
	if onsets.is_empty():
		_show_toast("Auto: no audio or too quiet")
		return
	var pct := auto_dense.value / 100.0
	var step := maxi(1, roundi(1.0 / maxf(pct, 0.1)))
	var notes_out: Array = []
	var cycle := [4, 1, 5, 7, 3, 0, 2, 8, 6]
	var spb := 60.0 / use_bpm
	var min_gap := spb * 0.5
	var last_t := -10.0
	var i2 := 0
	for t in onsets:
		if i2 % step == 0:
			if notes_out.is_empty() or t - last_t >= min_gap - 0.001:
				var cell: int = cycle[i2 % cycle.size()]
				var sz := 1.0 + 0.15 * sin(float(i2) * 0.7)
				notes_out.append({"t": snappedf(t, 0.001), "cell": cell, "s": sz})
				last_t = t
		i2 += 1
	if notes_out.size() < 8:
		_show_toast("Auto: too few notes (%d)" % notes_out.size())
		return
	notes_out = _auto_decorate(notes_out, spb)
	push_history("auto-generate")
	for n in notes:
		if n.get("node") != null and is_instance_valid(n.node):
			n.node.queue_free()
	notes.clear()
	for nd in notes_out:
		var n := {"t": float(nd.t), "s": float(nd.s), "cell": int(nd.cell),
			"h": float(nd.get("h", 0.0)), "c": bool(nd.get("c", false)),
			"node": null}
		recalc(n)
		notes.append(n)
	bpm = use_bpm
	song["bpm"] = use_bpm
	if bpm_label != null:
		bpm_label.text = "%.1f" % use_bpm
	timeline.selection.clear()
	notes_changed()
	_save()
	_show_toast("Auto: %d notes @ %.1f BPM" % [notes.size(), use_bpm])
	G.play_sfx("click")


## Turn some of the generated notes into holds and click notes, per the two
## checkboxes. Nothing is placed while a hold runs - there is one cursor, so a
## note flying in during a hold is a note you cannot take.
func _auto_decorate(raw: Array, spb: float) -> Array:
	var want_holds: bool = auto_holds != null and auto_holds.button_pressed
	var want_clicks: bool = auto_clicks != null and auto_clicks.button_pressed
	if not want_holds and not want_clicks:
		return raw
	var hold_len := spb * 1.25
	var out: Array = []
	var blocked_until := -9.0
	var i := 0
	var strong := 0
	for nd in raw:
		var t := float(nd.t)
		if t < blocked_until:
			continue
		var e: Dictionary = nd.duplicate()
		i += 1
		if want_holds and i % 6 == 0:
			e["h"] = snappedf(hold_len, 0.001)
			blocked_until = t + hold_len + spb * 0.35
		elif want_clicks:
			strong += 1
			if strong % 5 == 0:
				e["c"] = true
		out.append(e)
	return out


## Ogg/mp3: an even half-beat grid; a hash picks which subdivisions survive so
## the pattern is not perfectly uniform.
func _grid_onsets(use_bpm: float) -> Array:
	var stream := RhythmMap.audio_stream(song)
	var dur := stream.get_length() if stream != null else 60.0
	var out: Array = []
	var spb := 60.0 / use_bpm
	var t := spb
	while t < dur - 1.0:
		var h := float((int(t * 97.0) * 2654435761) % 1000) / 1000.0
		if h > 0.18:
			out.append(t)
		t += spb * 0.5
	return out


func _show_toast(text: String) -> void:
	toast.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)


func _set_status() -> void:
	if info_label == null:
		return
	var beat := cur_time * bpm / 60.0
	var sel := timeline.selection.size() if timeline != null else 0
	info_label.text = tr("Bar %d.%d   •   %02d:%04.1f   •   notes: %d   •   selected: %d") % [
		int(beat / 4.0) + 1, int(fposmod(beat, 4.0)) + 1,
		int(cur_time) / 60, fposmod(cur_time, 60.0), notes.size(), sel]


# ---------------------------------------------------------------- audio attach
func _start_dir() -> String:
	if OS.has_feature("android"):
		return "/storage/emulated/0/OpenRhythm"
	var d := str(song.get("dir", ""))
	if d == "" or d.begins_with("res://"):
		d = RhythmMap.user_songs_dir()
	return ProjectSettings.globalize_path(d)


func _open_audio_dialog() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = ["*.wav ; WAV audio", "*.ogg ; OGG audio", "*.mp3 ; MP3 audio"]
		_file_dialog.file_selected.connect(_on_audio_file_picked)
		add_child(_file_dialog)
	_file_dialog.current_dir = _start_dir()
	_file_dialog.popup_centered(Vector2i(920, 620))


func _on_audio_file_picked(p: String) -> void:
	var dst: String = str(song.get("dir", "")) + "/" + p.get_file()
	if not FileAccess.file_exists(dst):
		DirAccess.copy_absolute(p, dst)
	song["audio"] = p.get_file()
	_after_audio_attached()


func _build_audio_row() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_GOLD.r, G.C_GOLD.g, G.C_GOLD.b, 0.55)))
	hud.add_child(panel)
	audio_panel = panel

	var vb2 := VBoxContainer.new()
	vb2.add_theme_constant_override("separation", 6)
	panel.add_child(vb2)

	vb2.add_child(G.label("No audio yet. Pick a file — it is copied into this song's folder.",
		15, G.C_GOLD))

	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 8)
	vb2.add_child(hb2)
	hb2.add_child(G.button("Pick audio file…", _open_audio_dialog, 15))
	hb2.add_child(G.button("Scan song folder", _scan_audio, 15))
	_audio_path = LineEdit.new()
	_audio_path.placeholder_text = "…or paste a full path"
	_audio_path.add_theme_font_override("font", G.font_body)
	_audio_path.add_theme_font_size_override("font_size", 15)
	_audio_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb2.add_child(_audio_path)
	hb2.add_child(G.button("Attach", _attach_audio_path, 15))
	vb2.add_child(G.label("Folder: %s" % _start_dir(), 12, G.C_MUTED))


func _scan_audio() -> void:
	var dir := DirAccess.open(str(song.get("dir", "")))
	if dir == null:
		_show_toast("Song folder missing")
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			var ext := f.get_extension().to_lower()
			if ext in ["wav", "ogg", "mp3"]:
				song["audio"] = f
				break
		f = dir.get_next()
	if str(song.get("audio", "")) != "":
		_after_audio_attached()
	else:
		_show_toast("No audio files in the song folder")


func _attach_audio_path() -> void:
	var p := _audio_path.text.strip_edges()
	if p == "" or not FileAccess.file_exists(p):
		_show_toast("File not found")
		return
	var dst: String = str(song.get("dir", "")) + "/" + p.get_file()
	if not FileAccess.file_exists(dst):
		DirAccess.copy_absolute(p, dst)
	song["audio"] = p.get_file()
	_after_audio_attached()


func _after_audio_attached() -> void:
	var stream := RhythmMap.import_audio(
		str(song.get("dir", "")) + "/" + str(song.get("audio", "")))
	if stream != null:
		song["length"] = stream.get_length()
		length = float(song["length"])
	RhythmMap.write_map(song)
	if audio_panel != null:
		audio_panel.queue_free()
		audio_panel = null
	_compute_waveform()
	_show_toast("Audio attached: %s" % str(song.get("audio", "")))


# ---------------------------------------------------------------- loop
func _process(_delta: float) -> void:
	if playing:
		cur_time = Conductor.song_time
		if cur_time >= length - 0.05:
			playing = false
			Conductor.stop_music()
			play_btn.text = "▶  Play"
		timeline.follow(cur_time)
		timeline.queue_redraw()
		_set_status()
	for n in notes:
		_update_note_view(n)
	ghost_layer.items = _ghost_items()

	var bp := Conductor.phase() if playing else 0.0
	var env := pow(1.0 - bp, 3.0) if playing else 0.0
	frame_view.pulse = env
	if playing:
		bg.beat_env = env


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_save()
		G.main.goto_select("edit")
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _key(event as InputEventKey):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		if G.is_mobile():
			return
		_playfield_mouse(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_playfield_motion(event as InputEventMouseMotion)
	elif event is InputEventScreenTouch:
		_playfield_touch(event as InputEventScreenTouch)


func _key(k: InputEventKey) -> bool:
	var ctrl := k.ctrl_pressed
	if ctrl:
		match k.keycode:
			KEY_Z:
				if k.shift_pressed: _redo()
				else: _undo()
				return true
			KEY_Y:
				_redo()
				return true
			KEY_C:
				_copy()
				return true
			KEY_V:
				_paste()
				return true
			KEY_D:
				_duplicate()
				return true
			KEY_A:
				timeline.select_all()
				_set_status()
				return true
			KEY_S:
				_save()
				return true
		return false
	match k.keycode:
		KEY_SPACE:
			_toggle_play()
			return true
		KEY_LEFT:
			_seek(-4.0 if k.shift_pressed else -_snap_beats())
			return true
		KEY_RIGHT:
			_seek(4.0 if k.shift_pressed else _snap_beats())
			return true
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selection()
			return true
		KEY_H:
			_toggle_hold()
			return true
		KEY_C:
			_toggle_click()
			return true
		KEY_T:
			_test()
			return true
		KEY_ESCAPE:
			timeline.clear_selection()
			return true
	var digits := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
	for i in digits.size():
		if k.keycode == digits[i]:
			_set_snap(SNAPS[i])
			return true
	return false


func _snap_beats() -> float:
	return 1.0 / maxf(snap_div, 1.0)


func _local_of(pos: Vector2) -> Vector2:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * pos
	return (world - playfield_center) / field_scale


func _playfield_mouse(mb: InputEventMouseButton) -> void:
	var local := _local_of(mb.position)
	if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		drag_note = {}
		return
	if not (local.length() <= G.FRAME_HALF * 1.45 and mb.pressed):
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var picked := _pick(local)
		if picked.is_empty():
			_place(local)
		else:
			drag_note = picked
			drag_offset = picked.hit - local
			if timeline != null:
				timeline.selection = [picked]
			push_history("move note")
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_delete_at(local)


func _playfield_motion(mm: InputEventMouseMotion) -> void:
	if drag_note.is_empty():
		return
	var local := _local_of(mm.position)
	var new_cell := G.cell_index(local + drag_offset)
	if int(drag_note.cell) != new_cell:
		drag_note["cell"] = new_cell
		recalc(drag_note)
		if timeline != null:
			timeline.queue_redraw()
		G.play_sfx("click", 1.1, -12.0)


## Phone: a long press deletes, a tap places. The generation counter kills a
## pending long-press timer so a freshly placed note is not eaten by it.
func _playfield_touch(st: InputEventScreenTouch) -> void:
	var local := _local_of(st.position)
	if local.length() > G.FRAME_HALF * 1.45:
		_touch_gen += 1
		return
	if st.pressed:
		_press_t_ms = Time.get_ticks_msec()
		_press_local = local
		_longfired = false
		var gen := _touch_gen
		var tmr := get_tree().create_timer(0.45)
		tmr.timeout.connect(func():
			if gen == _touch_gen and not _longfired and _press_t_ms > 0 \
					and Time.get_ticks_msec() - _press_t_ms >= 440:
				_longfired = true
				_touch_gen += 1
				_delete_at(_press_local))
	else:
		_touch_gen += 1
		if _longfired:
			return
		var held := Time.get_ticks_msec() - _press_t_ms
		if _press_t_ms > 0 and held < 440:
			if _pick(local).is_empty():
				_place(local)
		_press_t_ms = 0
