class_name ModeBar
extends HBoxContainer
## Which game mode the song lists are showing, in the corner of the lists
## themselves.
##
## It used to live in the settings, which meant choosing sabers in a headset
## was a trip out of the song list, through a menu, and back - and worse, the
## setting could disagree with what you were looking at. The choice belongs
## where the songs are.
##
## Three modes today and the same maps behind all of them, so nothing is
## filtered out yet. That is deliberate rather than unfinished: the filter is
## asked for every song through RhythmMap.supports_mode(), so when a mode
## arrives that a chart has to be written for, the lists already know.

signal changed

const MODES := [
	{"id": "all", "label": "All modes",
	 "hint": "Every song in the library. In a headset this plays with sabers."},
	{"id": "laser", "label": "Laser pointer",
	 "hint": "Aim and press: the mouse on a screen, a pointer in a headset."},
	{"id": "saber", "label": "Sabers",
	 "hint": "Cut the cubes out of the air with a blade in each hand."},
]

var _buttons: Array[ModeIcon] = []
var _hint: PanelContainer = null
var _hint_lbl: Label = null
var _hover := -1
var _hover_t := 0.0


## Put the row in the top right of a screen, above whatever it is filtering.
static func attach(parent: Control, on_changed: Callable) -> ModeBar:
	var bar := ModeBar.new()
	bar.add_theme_constant_override("separation", 10)
	parent.add_child(bar)
	bar.changed.connect(on_changed)
	bar.size = Vector2(178, 52)
	G.anchor_corner(bar, true, false, 26, 30, Vector2(178, 52))
	bar._build_hint(parent)
	return bar


func _ready() -> void:
	for m in MODES:
		var id := str(m.id)
		var icon := ModeIcon.new()
		icon.kind = id
		icon.custom_minimum_size = Vector2(52, 52)
		# sabers need two tracked hands; on a flat screen there is nothing to
		# hold, so the mode is shown greyed rather than hidden - it is a real
		# way to play and worth knowing about before you own a headset
		icon.disabled = id == "saber" and not G.vr_active
		icon.hint = "%s — %s" % [tr(str(m.label)), tr(str(m.hint))] \
			if not icon.disabled else \
			"%s — %s" % [tr(str(m.label)), tr("Needs a headset.")]
		icon.pressed.connect(_pick.bind(id))
		add_child(icon)
		_buttons.append(icon)
	_paint()


## The hint, drawn rather than left to the engine.
##
## Godot shows a tooltip once the pointer has been still for half a second, and
## in this game it never is: the cursor is drawn by the game and warped every
## frame, so the timer restarts forever and the tooltip never arrives. In a
## headset there is no system cursor to hover at all. So the hint is a panel of
## our own, under the row, that appears when a button has been hovered for a
## moment.
func _build_hint(parent: Control) -> void:
	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.75)))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	parent.add_child(_hint)
	_hint_lbl = G.label("", 16, G.C_TEXT)
	_hint_lbl.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_lbl.custom_minimum_size = Vector2(300, 0)
	_hint.add_child(_hint_lbl)


func _process(delta: float) -> void:
	if _hint == null or not is_instance_valid(_hint):
		return
	# Asked of the rectangles rather than of the buttons: a disabled button
	# takes no mouse input and so is never "hovered", and the greyed-out saber
	# is exactly the one whose hint somebody needs - it is the one that has to
	# explain why it cannot be pressed.
	var at := get_global_mouse_position()
	var over := -1
	for i in _buttons.size():
		if _buttons[i].get_global_rect().has_point(at):
			over = i
			break
	if over != _hover:
		_hover = over
		_hover_t = 0.0
		if over >= 0:
			_hint_lbl.text = _buttons[over].hint
	var want := 0.0
	if _hover >= 0:
		_hover_t += delta
		if _hover_t > 0.28:
			want = 1.0
			# under the row, hanging off its right edge like a real tooltip
			_hint.size = Vector2(320, 0)
			_hint.position = Vector2(
				global_position.x + size.x - 320.0, global_position.y + size.y + 10.0)
	_hint.modulate.a = move_toward(_hint.modulate.a, want, delta * 6.0)


func _pick(id: String) -> void:
	if G.game_mode == id:
		return
	G.game_mode = id
	G.save_all()
	G.play_sfx("click")
	_paint()
	changed.emit()


func _paint() -> void:
	for i in _buttons.size():
		_buttons[i].chosen = str(MODES[i].id) == G.game_mode
		_buttons[i].queue_redraw()
