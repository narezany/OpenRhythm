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


## Put the row in the top right of a screen, above whatever it is filtering.
static func attach(parent: Control, on_changed: Callable) -> ModeBar:
	var bar := ModeBar.new()
	bar.add_theme_constant_override("separation", 10)
	parent.add_child(bar)
	bar.changed.connect(on_changed)
	bar.size = Vector2(178, 52)
	G.anchor_corner(bar, true, false, 26, 30, Vector2(178, 52))
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
		icon.tooltip_text = "%s — %s" % [tr(str(m.label)), tr(str(m.hint))] \
			if not icon.disabled else \
			"%s — %s" % [tr(str(m.label)), tr("Needs a headset.")]
		icon.pressed.connect(_pick.bind(id))
		add_child(icon)
		_buttons.append(icon)
	_paint()


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
