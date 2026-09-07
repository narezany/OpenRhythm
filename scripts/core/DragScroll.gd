class_name DragScroll
extends Node
## Grab a list anywhere and pull it.
##
## A ScrollContainer only scrolls from its scrollbar or from the empty gaps
## between its children: everything else - a song card, a button, a label with
## a filter on it - takes the press and keeps it. With a mouse that is merely
## annoying. On a phone it means the list can only be moved by hitting a strip
## a few pixels wide, and at the end of a laser pointer in a headset it is not
## a thing anybody can do at all.
##
## So the drag is watched from `_input`, which runs before the interface gets
## its turn and where nothing can swallow it. A press arms; once it has
## travelled far enough it becomes a scroll, and the button it started on is
## told to forget about it with a release delivered somewhere it is not.
##
##     DragScroll.attach(scroll)
##
## Momentum is here because a list that stops dead the moment you let go feels
## broken on a touchscreen, and because a flick is how people move a long list.

## How far a press has to travel before it stops being a click.
const SLOP := 9.0
## Anything slower than this at the moment of release is a stop, not a throw.
const FLICK_MIN := 90.0        # pixels per second
const FLICK_MAX := 4200.0
## How quickly a throw runs out, as a fraction of its speed kept per second.
const DRAG := 0.11

var scroll: ScrollContainer = null

var _armed := false
var _dragging := false
var _from := Vector2.ZERO
var _at := 0
var _speed := 0.0
var _last_y := 0.0
var _last_t := 0.0


## Give a scroll container the ability to be dragged. Returns the helper, which
## lives as a child of the container and dies with it.
static func attach(target: ScrollContainer) -> DragScroll:
	var ds := DragScroll.new()
	ds.scroll = target
	ds.name = "DragScroll"
	target.add_child(ds)
	return ds


func _ready() -> void:
	# the pause menu is a list too, and a paused tree must not freeze it
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if scroll == null or not is_instance_valid(scroll) or not scroll.is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press(mb.position)
		else:
			_release()
	elif event is InputEventMouseMotion and _armed:
		_move((event as InputEventMouseMotion).position)


func _press(at: Vector2) -> void:
	if not scroll.get_global_rect().has_point(at):
		return
	_armed = true
	_dragging = false
	_from = at
	_at = scroll.scroll_vertical
	_speed = 0.0
	_last_y = at.y
	_last_t = _now()


func _move(at: Vector2) -> void:
	var moved: float = at.y - _from.y
	if not _dragging:
		if absf(moved) < SLOP:
			return
		_dragging = true
		# The press already reached whatever is under the finger, and a button
		# that never hears the release stays stuck down. So it is released
		# somewhere it is not, which clears it without pressing it.
		_cancel_press_under_pointer()
	scroll.scroll_vertical = _at - int(moved)
	var t := _now()
	var dt: float = t - _last_t
	if dt > 0.004:
		_speed = (at.y - _last_y) / dt
		_last_y = at.y
		_last_t = t
	get_viewport().set_input_as_handled()


func _release() -> void:
	if _dragging:
		get_viewport().set_input_as_handled()
		if absf(_speed) < FLICK_MIN:
			_speed = 0.0
		else:
			_speed = clampf(_speed, -FLICK_MAX, FLICK_MAX)
	else:
		_speed = 0.0
	_armed = false
	_dragging = false


func _process(delta: float) -> void:
	if _dragging or absf(_speed) < 1.0:
		return
	if scroll == null or not is_instance_valid(scroll):
		return
	scroll.scroll_vertical -= int(round(_speed * delta))
	_speed *= pow(DRAG, delta)
	if absf(_speed) < 1.0:
		_speed = 0.0


## Take the press off whatever is under the pointer without pressing it.
func _cancel_press_under_pointer() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = Vector2(-4000, -4000)
	ev.global_position = ev.position
	get_viewport().push_input(ev, true)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
