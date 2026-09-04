class_name EditorTimeline
extends Control
## The editor's piano roll: nine lanes (one per grid cell) laid out over time,
## with a waveform strip, a beat grid, selection, dragging and hold-length
## handles. This is where a chart is actually read and shaped; the 3x3 playfield
## is only for quick placement at the playhead.

const LANE_LABELS := ["↖", "↑", "↗", "←", "•", "→", "↙", "↓", "↘"]
const RULER_H := 20.0
const WAVE_H := 34.0
const EDGE_GRAB := 7.0        # px around a note's right edge that starts a resize
const MIN_NOTE_PX := 9.0

var ed = null                 # EditorScreen; untyped to avoid a class cycle

var view_start := 0.0         # leftmost visible second
var px_per_sec := 120.0

var selection: Array = []     # note dictionaries currently selected

# --- interaction state ---
var _mode := ""               # "", "band", "move", "resize", "pan", "scrub"
var _band_from := Vector2.ZERO
var _band_to := Vector2.ZERO
var _drag_ref := Vector2.ZERO
var _drag_start: Array = []   # [{note, t, cell}] captured at drag start
var _resize_note: Dictionary = {}
var _pan_ref := 0.0
var _hover: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


# ---------------------------------------------------------------- geometry
func lane_h() -> float:
	return maxf((size.y - RULER_H - WAVE_H) / 9.0, 6.0)


func time_to_x(t: float) -> float:
	return (t - view_start) * px_per_sec


func x_to_time(x: float) -> float:
	return view_start + x / maxf(px_per_sec, 1.0)


func lane_to_y(cell: int) -> float:
	return RULER_H + WAVE_H + float(cell) * lane_h()


func y_to_lane(y: float) -> int:
	return clampi(int((y - RULER_H - WAVE_H) / lane_h()), 0, 8)


func visible_span() -> float:
	return size.x / maxf(px_per_sec, 1.0)


## Keep the playhead on screen while the track plays.
func follow(t: float) -> void:
	var span := visible_span()
	if t < view_start + span * 0.1 or t > view_start + span * 0.75:
		view_start = maxf(0.0, t - span * 0.35)
	queue_redraw()


func zoom_at(factor: float, mouse_x: float) -> void:
	var anchor := x_to_time(mouse_x)
	px_per_sec = clampf(px_per_sec * factor, 12.0, 1400.0)
	view_start = maxf(0.0, anchor - mouse_x / px_per_sec)
	queue_redraw()


func scroll_by(seconds: float) -> void:
	var maxlen: float = maxf(float(ed.length) - visible_span() * 0.25, 0.0)
	view_start = clampf(view_start + seconds, 0.0, maxlen)
	queue_redraw()


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if ed == null:
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.045, 0.012, 0.020, 0.94))

	_draw_grid()
	_draw_waveform()
	_draw_lanes()
	_draw_notes()

	if _mode == "band":
		var r := Rect2(_band_from, _band_to - _band_from).abs()
		draw_rect(r, Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.14))
		draw_rect(r, Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.7), false, 1.5)

	# playhead
	var px := time_to_x(float(ed.cur_time))
	if px >= -2.0 and px <= w + 2.0:
		draw_rect(Rect2(px - 1.0, 0, 2.0, h), Color(1, 1, 1, 0.92))
		draw_circle(Vector2(px, RULER_H * 0.5), 5.0, Color(1, 1, 1, 0.95))


func _draw_grid() -> void:
	var spb: float = 60.0 / maxf(float(ed.bpm), 1.0)
	var div: float = maxf(float(ed.snap_div), 1.0)
	var step: float = spb / div
	if step * px_per_sec < 5.0:
		step = spb                      # too dense to read - fall back to beats
	var t0: float = floor(view_start / step) * step
	var t := t0
	var t_end := view_start + visible_span()
	while t <= t_end:
		var x := time_to_x(t)
		var beat := t / spb
		var on_bar := absf(fposmod(beat, 4.0)) < 0.01 or absf(fposmod(beat, 4.0) - 4.0) < 0.01
		var on_beat := absf(fposmod(beat, 1.0)) < 0.01 or absf(fposmod(beat, 1.0) - 1.0) < 0.01
		var col := Color(1, 1, 1, 0.05)
		if on_bar:
			col = Color(1, 1, 1, 0.26)
		elif on_beat:
			col = Color(1, 1, 1, 0.13)
		draw_rect(Rect2(x, RULER_H, 1.0, size.y - RULER_H), col)
		if on_bar:
			var bar := int(round(beat / 4.0)) + 1
			draw_string(G.font_body, Vector2(x + 4.0, RULER_H - 6.0), str(bar),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.45))
		t += step
	draw_rect(Rect2(0, RULER_H - 1.0, size.x, 1.0), Color(1, 1, 1, 0.12))


func _draw_waveform() -> void:
	var peaks: PackedFloat32Array = ed.wave_peaks
	var y0 := RULER_H
	draw_rect(Rect2(0, y0, size.x, WAVE_H), Color(0, 0, 0, 0.25))
	if peaks.is_empty():
		draw_string(G.font_body, Vector2(8, y0 + WAVE_H - 10.0),
			"waveform: .wav only", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(1, 1, 1, 0.25))
		return
	var rate: float = float(ed.wave_rate)
	var mid := y0 + WAVE_H * 0.5
	var col := Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, 0.55)
	var x := 0.0
	while x < size.x:
		var t := x_to_time(x)
		var i := int(t * rate)
		if i >= 0 and i < peaks.size():
			var a: float = clampf(peaks[i], 0.0, 1.0) * (WAVE_H * 0.46)
			draw_rect(Rect2(x, mid - a, 1.0, a * 2.0), col)
		x += 1.0


func _draw_lanes() -> void:
	var lh := lane_h()
	for c in 9:
		var y := lane_to_y(c)
		var band := c % 3
		var col := Color(1, 1, 1, 0.035 if band == 1 else 0.015)
		draw_rect(Rect2(0, y, size.x, lh), col)
		draw_rect(Rect2(0, y, size.x, 1.0), Color(1, 1, 1, 0.06))
		draw_string(G.font_body, Vector2(4, y + lh * 0.5 + 5.0), LANE_LABELS[c],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.28))


func _draw_notes() -> void:
	var lh := lane_h()
	var t0 := view_start
	var t1 := view_start + visible_span()
	for n in ed.notes:
		var nt := float(n.t)
		var nh := float(n.get("h", 0.0))
		if nt + nh < t0 - 0.2 or nt > t1 + 0.2:
			continue
		var x := time_to_x(nt)
		var wpx := maxf(nh * px_per_sec, MIN_NOTE_PX)
		var y := lane_to_y(int(n.cell)) + 2.0
		var hh := lh - 4.0
		var picked: bool = n in selection
		var base := Color(0.92, 0.90, 0.90, 0.92)
		if nh > 0.0:
			base = Color(1.0, 0.72, 0.42, 0.92)
		if picked:
			base = Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.95)
		draw_rect(Rect2(x, y, wpx, hh), base)
		draw_rect(Rect2(x, y, wpx, hh), Color(0, 0, 0, 0.5), false, 1.0)
		if nh > 0.0:
			# handle on the right edge, the thing you grab to change the length
			draw_rect(Rect2(x + wpx - 3.0, y, 3.0, hh), Color(1, 1, 1, 0.8))
		if n == _hover:
			draw_rect(Rect2(x - 1.0, y - 1.0, wpx + 2.0, hh + 2.0),
				Color(1, 1, 1, 0.55), false, 1.0)


# ---------------------------------------------------------------- hit testing
func note_at(pos: Vector2) -> Dictionary:
	var lh := lane_h()
	var lane := y_to_lane(pos.y)
	var best: Dictionary = {}
	for n in ed.notes:
		if int(n.cell) != lane:
			continue
		var x := time_to_x(float(n.t))
		var wpx := maxf(float(n.get("h", 0.0)) * px_per_sec, MIN_NOTE_PX)
		if pos.x >= x - 2.0 and pos.x <= x + wpx + 2.0:
			best = n
	return best


func _on_right_edge(n: Dictionary, pos: Vector2) -> bool:
	if n.is_empty():
		return false
	var x := time_to_x(float(n.t))
	var wpx := maxf(float(n.get("h", 0.0)) * px_per_sec, MIN_NOTE_PX)
	return absf(pos.x - (x + wpx)) <= EDGE_GRAB


# ---------------------------------------------------------------- input
func _gui_input(event: InputEvent) -> void:
	if ed == null:
		return
	if event is InputEventMouseButton:
		_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_motion(event as InputEventMouseMotion)


func _button(mb: InputEventMouseButton) -> void:
	var pos := mb.position
	var ctrl := Input.is_key_pressed(KEY_CTRL)
	var shift := Input.is_key_pressed(KEY_SHIFT)

	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		if ctrl:
			zoom_at(1.18, pos.x)
		elif shift:
			ed.seek_to(float(ed.cur_time) - ed._snap_step())
		else:
			scroll_by(-visible_span() * 0.12)
		accept_event()
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		if ctrl:
			zoom_at(1.0 / 1.18, pos.x)
		elif shift:
			ed.seek_to(float(ed.cur_time) + ed._snap_step())
		else:
			scroll_by(visible_span() * 0.12)
		accept_event()
		return

	if mb.button_index == MOUSE_BUTTON_MIDDLE:
		if mb.pressed:
			_mode = "pan"
			_pan_ref = pos.x
		elif _mode == "pan":
			_mode = ""
		accept_event()
		return

	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var n := note_at(pos)
		if not n.is_empty():
			ed.push_history("delete note")
			ed.erase_note(n)
			selection.erase(n)
			queue_redraw()
		accept_event()
		return

	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if mb.pressed:
		if pos.y < RULER_H:
			_mode = "scrub"
			ed.seek_to(x_to_time(pos.x))
			accept_event()
			return
		var n := note_at(pos)
		if n.is_empty():
			if ctrl:
				ed.push_history("add note")
				var added = ed.add_note(ed.snap_time(x_to_time(pos.x)), y_to_lane(pos.y))
				selection = [added]
				queue_redraw()
			else:
				_mode = "band"
				_band_from = pos
				_band_to = pos
			accept_event()
			return
		if _on_right_edge(n, pos):
			_mode = "resize"
			_resize_note = n
			ed.push_history("hold length")
			accept_event()
			return
		if shift:
			if n in selection:
				selection.erase(n)
			else:
				selection.append(n)
		elif not (n in selection):
			selection = [n]
		_mode = "move"
		_drag_ref = pos
		_drag_start.clear()
		for s in selection:
			_drag_start.append({"n": s, "t": float(s.t), "cell": int(s.cell)})
		ed.push_history("move notes")
		accept_event()
	else:
		if _mode == "band":
			_apply_band(Input.is_key_pressed(KEY_SHIFT))
		_mode = ""
		_drag_start.clear()
		_resize_note = {}
		ed.notes_changed()
		queue_redraw()


func _motion(mm: InputEventMouseMotion) -> void:
	var pos := mm.position
	match _mode:
		"pan":
			scroll_by(-(pos.x - _pan_ref) / px_per_sec)
			_pan_ref = pos.x
			return
		"scrub":
			ed.seek_to(x_to_time(pos.x))
			return
		"band":
			_band_to = pos
			queue_redraw()
			return
		"resize":
			var t0 := float(_resize_note.t)
			var raw := x_to_time(pos.x)
			var snapped_t: float = ed.snap_time(raw)
			var h := maxf(snapped_t - t0, 0.0)
			# below a sixteenth it is a normal note again, not a stubby hold
			if h < ed._snap_step() * 0.5:
				h = 0.0
			_resize_note["h"] = h
			queue_redraw()
			return
		"move":
			var dt := (pos.x - _drag_ref.x) / maxf(px_per_sec, 1.0)
			var lane_delta := y_to_lane(pos.y) - y_to_lane(_drag_ref.y)
			for e in _drag_start:
				var n: Dictionary = e.n
				n["t"] = maxf(ed.snap_time(float(e.t) + dt), 0.0)
				n["cell"] = clampi(int(e.cell) + lane_delta, 0, 8)
				ed.recalc(n)
			queue_redraw()
			return
	var hovered := note_at(pos)
	if not (hovered.is_empty() and _hover.is_empty()) and hovered != _hover:
		_hover = hovered
		queue_redraw()
	mouse_default_cursor_shape = Control.CURSOR_HSIZE if _on_right_edge(hovered, pos) \
		else Control.CURSOR_ARROW


func _apply_band(additive: bool) -> void:
	var r := Rect2(_band_from, _band_to - _band_from).abs()
	if not additive:
		selection.clear()
	var lh := lane_h()
	for n in ed.notes:
		var x := time_to_x(float(n.t))
		var wpx := maxf(float(n.get("h", 0.0)) * px_per_sec, MIN_NOTE_PX)
		var y := lane_to_y(int(n.cell))
		if r.intersects(Rect2(x, y, wpx, lh)) and not (n in selection):
			selection.append(n)


func select_all() -> void:
	selection = ed.notes.duplicate()
	queue_redraw()


func clear_selection() -> void:
	selection.clear()
	queue_redraw()
