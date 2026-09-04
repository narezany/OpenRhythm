class_name CalibrationScreen
extends Control
## Audio offset calibration. A metronome ticks at a fixed period; the player taps
## along. The gap between a tap and the tick it belongs to is the delay between
## what the game plays and what the player hears, which is exactly the offset
## gameplay needs. The median of the taps is used, so a few sloppy ones are free.

const BPM := 120.0
const PERIOD := 60.0 / BPM
const MIN_TAPS := 8
const MAX_TAPS := 32

var _start_us := 0
var _beat := -1
var _pulse := 0.0
var _deltas: Array = []
var _result := 0.0

var _taps_lbl: Label
var _offset_lbl: Label
var _hint_lbl: Label
var _viz: TapViz
var _apply_btn: Button
var _ring: BeatRing


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(BackgroundFX.new(true))

	var title := G.label("CALIBRATION", 46, G.C_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	G.anchor_top_wide(title, 44, 60)

	var sub := G.label("Space / click / tap on the beat. The game measures your delay itself.",
		20, G.C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	G.anchor_top_wide(sub, 104, 30)

	var ring := BeatRing.new()
	ring.screen = self
	add_child(ring)
	_ring = ring

	_viz = TapViz.new()
	_viz.screen = self
	_viz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viz)
	G.anchor_top_wide(_viz, 420, 60, 0.0)

	_taps_lbl = G.label("", 22, G.C_MUTED)
	G.anchor_top_wide(_taps_lbl, 492, 28)
	_taps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_taps_lbl)

	_offset_lbl = G.label("", 34, G.C_GOLD, true)
	G.anchor_top_wide(_offset_lbl, 522, 46)
	_offset_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_offset_lbl)

	_hint_lbl = G.label("Keep tapping — at least 8 taps needed", 17, Color(1, 1, 1, 0.45))
	G.anchor_top_wide(_hint_lbl, 568, 24)
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint_lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	G.anchor_bottom_wide(row, 42, 54)
	_apply_btn = G.button("Apply", _apply, 24)
	_apply_btn.custom_minimum_size = Vector2(190, 0)
	_apply_btn.disabled = true
	row.add_child(_apply_btn)
	row.add_child(G.button("Reset", _reset, 22))
	row.add_child(G.button("← Back", func():
		G.play_sfx("click")
		G.main.goto_settings(), 22))

	Conductor.stop_music()
	_start_us = Time.get_ticks_usec()
	_update_labels()


func _now() -> float:
	return float(Time.get_ticks_usec() - _start_us) / 1_000_000.0


func _process(delta: float) -> void:
	if _ring != null:
		# the ring lives in world space, so it is centred by hand
		_ring.position = Vector2(G.canvas_size().x * 0.5, 300.0)
	var t := _now()
	var b := int(floor(t / PERIOD))
	if b != _beat:
		_beat = b
		_pulse = 1.0
		G.play_sfx("click", 1.0, -4.0)
	_pulse = maxf(0.0, _pulse - delta * 3.4)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		G.main.goto_settings()
		return
	var tapped := false
	if event is InputEventKey and event.pressed and not event.echo:
		tapped = event.keycode == KEY_SPACE or event.keycode == KEY_ENTER
	elif event is InputEventMouseButton and event.pressed:
		tapped = event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventJoypadButton and event.pressed:
		tapped = true
	if tapped:
		_tap()


func _tap() -> void:
	var t := _now()
	# distance to the nearest tick, folded into a half period either way
	var d := fposmod(t, PERIOD)
	if d > PERIOD * 0.5:
		d -= PERIOD
	_deltas.append(d)
	if _deltas.size() > MAX_TAPS:
		_deltas.pop_front()
	_result = _median(_deltas)
	_update_labels()


static func _median(vals: Array) -> float:
	if vals.is_empty():
		return 0.0
	var s := vals.duplicate()
	s.sort()
	var n := s.size()
	if n % 2 == 1:
		return float(s[n / 2])
	return (float(s[n / 2 - 1]) + float(s[n / 2])) * 0.5


func _update_labels() -> void:
	_taps_lbl.text = "%s: %d" % [tr("Taps"), _deltas.size()]
	var ready := _deltas.size() >= MIN_TAPS
	_apply_btn.disabled = not ready
	if ready:
		_offset_lbl.text = "%s: %+d ms" % [tr("Detected offset"), roundi(_result * 1000.0)]
		_hint_lbl.text = "%s: %+d ms" % [tr("Audio offset"), roundi(G.audio_offset * 1000.0)]
	else:
		_offset_lbl.text = ""
		_hint_lbl.text = "Keep tapping — at least 8 taps needed"


func _apply() -> void:
	G.audio_offset = clampf(_result, -0.4, 0.4)
	G.save_all()
	Achievements.unlock("calibrated")
	G.play_sfx("click", 1.3)
	_update_labels()


func _reset() -> void:
	_deltas.clear()
	_result = 0.0
	G.audio_offset = 0.0
	G.save_all()
	G.play_sfx("click", 0.8)
	_update_labels()


## Pulsing ring that flashes on every metronome tick.
class BeatRing extends Node2D:
	var screen: CalibrationScreen

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if screen == null:
			return
		var p: float = screen._pulse
		draw_arc(Vector2.ZERO, 92.0, 0, TAU, 64, Color(1, 1, 1, 0.10), 3.0, true)
		draw_arc(Vector2.ZERO, 92.0 - p * 18.0, 0, TAU, 64,
			Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.25 + p * 0.75),
			4.0 + p * 4.0, true)
		draw_circle(Vector2.ZERO, 12.0 + p * 22.0,
			Color(1.0, 0.9, 0.85, 0.15 + p * 0.55))


## Scatter of the recorded taps around the beat, newest brightest.
class TapViz extends Control:
	var screen: CalibrationScreen

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if screen == null:
			return
		var w := size.x
		var mid := w * 0.5
		var y := size.y * 0.5
		draw_rect(Rect2(0, y - 1, w, 2), Color(1, 1, 1, 0.10))
		draw_rect(Rect2(mid - 1, y - 16, 2, 32), Color(1, 1, 1, 0.35))
		var span: float = CalibrationScreen.PERIOD * 0.5
		var n: int = screen._deltas.size()
		for i in n:
			var d: float = float(screen._deltas[i])
			var x: float = mid + (d / span) * (w * 0.5)
			var a: float = 0.25 + 0.75 * float(i + 1) / float(maxi(n, 1))
			draw_circle(Vector2(clampf(x, 0.0, w), y), 4.0,
				Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, a))
		if n >= CalibrationScreen.MIN_TAPS:
			var rx: float = mid + (screen._result / span) * (w * 0.5)
			draw_rect(Rect2(clampf(rx, 0.0, w) - 1.5, y - 20, 3, 40),
				Color(G.C_GOLD.r, G.C_GOLD.g, G.C_GOLD.b, 0.9))
