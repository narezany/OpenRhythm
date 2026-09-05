extends CanvasLayer
## UICursor - the game's own cursor. Position follows the system mouse, scaled
## by G.mouse_sens; the hidden system pointer is warped onto the drawn cursor so
## GUI clicks land where the player sees it. Deltas are measured against the
## EXPECTED OS position, so the warp echo is a zero delta and never compounds.
## A gamepad left stick drives the same cursor.

var pos := Vector2(640, 360)
var hover_boost := 0.0
var touch_mode := false
var cursor_visible := true

var _trail: Array[Vector2] = []
## index -> last known position, for every finger currently down
var _fingers := {}
## the one finger that moves the cursor; -1 when nothing is down
var _cursor_finger := -1
var _draw_node: Node2D
var _os_expected := Vector2.INF   # where we believe the system pointer is
## Warping is only used to keep the system pointer under a cursor moving at a
## different speed. Some platforms refuse to move the pointer at all, so the
## request is checked rather than assumed.
var _warp_ok := true
var _warp_want := Vector2.INF
var _warp_miss := 0
var relay_node: Node
var _pad_vec := Vector2.ZERO
var _has_focus := true


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = CursorDraw.new()
	_draw_node.cursor = self
	add_child(_draw_node)
	pos = G.DESIGN / 2.0
	# RelayNode at the tree root sees raw touches regardless of GUI focus, so
	# relative touch mode does not drop out when a finger lands on a button
	relay_node = RelayNode.new()
	relay_node.cursor = self
	get_tree().root.call_deferred("add_child", relay_node)


## Visible area in design coordinates.
##
## Taken from the viewport itself rather than from the cached window size: that
## cache is only refreshed when the window reports a resize, and a stale one
## makes this rect smaller than the screen really is. The cursor then stops at
## an edge that is not there while the system pointer carries on past it, and
## because motion was being accumulated it never found its way back - which is
## what "the cursor drifts off to the left and the real one is over on the
## right" was.
func _visible_rect() -> Rect2:
	var vp := get_viewport()
	if vp != null:
		var r := vp.get_visible_rect()
		if r.size.x > 16.0 and r.size.y > 16.0:
			return r
	return G.visible_rect_design()


## True while the drawn cursor is being kept apart from the system pointer.
## Only sensitivity does that, and only where warping actually works.
func _warping() -> bool:
	return _warp_ok and absf(G.mouse_sens - 1.0) > 0.01


func _input(event: InputEvent) -> void:
	# Touch is handled by the relay below, which sees every finger regardless of
	# which control it landed on. Here we only deal with the mouse.
	if not (event is InputEventMouseMotion):
		return
	if not _fingers.is_empty():
		# The project emulates a mouse from touch so that buttons react to a
		# finger, which means a drag arrives twice: once as a touch event and
		# once as mouse motion. Counting both moved the cursor at double speed.
		return
	var mm := event as InputEventMouseMotion
	if not _warping():
		# The drawn cursor IS the system pointer, so take its position rather
		# than adding up movements. Accumulating cannot survive a single
		# clamped or dropped event: the error stays for good, and every click
		# after it lands somewhere the player is not looking.
		pos = mm.position
		var vis0 := _visible_rect()
		pos = pos.clamp(vis0.position, vis0.end)
		_os_expected = mm.position
		touch_mode = false
		return
	if _warp_want != Vector2.INF:
		# did the warp we asked for actually happen?
		if mm.position.distance_to(_warp_want) > 96.0:
			_warp_miss += 1
			if _warp_miss >= 3:
				# The platform is ignoring warp requests - Wayland does unless
				# the pointer is locked. Carrying on would drag the drawn
				# cursor further from the real one with every movement, so
				# sensitivity is dropped and the two are pinned together.
				_warp_ok = false
				_os_expected = Vector2.INF
				push_warning("cursor: mouse warp does not work here, "
					+ "sensitivity disabled to keep the pointer under the cursor")
				return
		else:
			_warp_miss = 0
		_warp_want = Vector2.INF
	if _os_expected == Vector2.INF:
		# first event: initial sync, sensitivity not applied
		_os_expected = mm.position
		pos = mm.position
		return
	var d: Vector2 = mm.position - _os_expected
	_os_expected = mm.position
	if d.length() > 300.0:
		return   # a teleport (alt-tab, OS warp) is not player movement
	pos += d * G.mouse_sens
	var vis := _visible_rect()
	pos = pos.clamp(vis.position, vis.end)
	touch_mode = false


## All touch input, from the relay at the tree root.
##
## Exactly one finger drives the cursor at a time. Every other finger is a tap:
## that is what lets you steer with one thumb and hit a click note with the
## other, and it is why laying two fingers down no longer makes the cursor
## shake between them.
func _touch_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_fingers[st.index] = st.position
			touch_mode = true
			if _cursor_finger < 0:
				_cursor_finger = st.index
				if not (G.relative_touch and G.touch_zone):
					# absolute: jump straight to the tap, otherwise a quick tap
					# only catches the cursor halfway through a lerp
					pos = st.position
					_trail.clear()
			# a press from any other finger is a tap in place: the cursor does
			# not move, which is what makes two-thumb play work
		else:
			_fingers.erase(st.index)
			if st.index == _cursor_finger:
				# hand control to whatever finger is still down
				_cursor_finger = -1
				for i in _fingers:
					_cursor_finger = i
					break
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		var prev = _fingers.get(dr.index, dr.position)
		_fingers[dr.index] = dr.position
		if dr.index != _cursor_finger:
			return                      # a second finger never steers
		if G.relative_touch and G.touch_zone:
			# the finger is a stick: it pushes the cursor, and sensitivity says
			# how hard
			pos += (dr.position - prev) * G.mouse_sens
		else:
			# the cursor is under the finger and stays there. Sensitivity is a
			# mouse setting; scaling a touch drag makes the cursor outrun the
			# finger it is supposed to be sitting on.
			pos += dr.position - prev
		var vis := _visible_rect()
		pos = pos.clamp(vis.position, vis.end)


## Raw touch sink at the tree root: sees every touch no matter which control
## the finger hit, which keeps relative mode stable.
class RelayNode extends Node:
	var cursor

	func _input(event: InputEvent) -> void:
		if cursor != null:
			cursor._touch_input(event)


func _process(_delta: float) -> void:
	_pad_vec = Vector2.ZERO
	if not _typing():
		var keys := Vector2.ZERO
		if InputMap.has_action(Binds.CURSOR_LEFT):
			keys = Input.get_vector(Binds.CURSOR_LEFT, Binds.CURSOR_RIGHT,
				Binds.CURSOR_UP, Binds.CURSOR_DOWN)
		_pad_vec = (keys + _stick()).limit_length(1.0)
	if _pad_vec.length() > 0.01:
		# gamepad or keyboard drives the cursor directly
		touch_mode = false
		pos += _pad_vec * G.gamepad_speed * _delta
		var vis0 := _visible_rect()
		pos = pos.clamp(vis0.position, vis0.end)
	# At sensitivity 1.0 the drawn cursor already sits exactly on the system
	# pointer, so there is nothing to correct and no reason to touch it at all.
	if _warping() and not touch_mode and DisplayServer.get_name() != "headless" \
			and _focused():
		# keep the hidden system pointer under the drawn cursor, otherwise GUI
		# clicks miss
		if _os_expected == Vector2.INF or pos.distance_to(_os_expected) > 0.5:
			_os_expected = pos
			_warp_want = pos
			Input.warp_mouse(get_viewport().get_final_transform() * pos)
	var vis := _visible_rect()
	pos = pos.clamp(vis.position, vis.end)
	_trail.push_front(pos)
	if _trail.size() > 7:
		_trail.pop_back()
	hover_boost = maxf(0.0, hover_boost - _delta * 6.0)
	_draw_node.queue_redraw()


func jump_to(p: Vector2) -> void:
	pos = p
	_trail.clear()


## Left stick with a radial deadzone, rescaled so it still reaches full speed.
## A worn stick rests slightly off centre; feeding that through the input
## actions is what made the cursor creep upwards on its own.
func _stick() -> Vector2:
	# Only a joypad the engine recognises as a gamepad is read. Plenty of HID
	# devices - some mice and keyboards among them - enumerate as joypads with
	# axes resting at -1, which is exactly what dragged the cursor up and left
	# for someone playing on WASD.
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return Vector2.ZERO
	var dev := -1
	for p in pads:
		if Input.is_joy_known(p):
			dev = p
			break
	if dev < 0:
		return Vector2.ZERO
	var v := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	var len_ := v.length()
	if len_ <= Binds.STICK_DEADZONE:
		return Vector2.ZERO
	return v.normalized() * ((len_ - Binds.STICK_DEADZONE) / (1.0 - Binds.STICK_DEADZONE))


## True while the game window is the focused one. Warping the system pointer
## while another window is on top (a file dialog, a screenshot prompt) drags
## the mouse back into the game and makes the other window unusable, so the
## cursor lets go the moment focus leaves.
func _focused() -> bool:
	# Polled, not remembered: focus notifications are not delivered reliably on
	# every window manager, and getting this wrong means the game keeps yanking
	# the pointer out of whatever window is on top.
	if DisplayServer.has_method("window_is_focused"):
		return DisplayServer.window_is_focused()
	return _has_focus


## Release the OS cursor when focus is lost and take it back on return.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_has_focus = false
			_os_expected = Vector2.INF
			if DisplayServer.get_name() != "headless":
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_has_focus = true
			_os_expected = Vector2.INF
			if DisplayServer.get_name() != "headless":
				Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


## True while a text field has focus, so WASD types instead of steering.
func _typing() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var f := vp.gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


## Internal drawing: a round cursor with a spinning ember arc.
class CursorDraw extends Node2D:
	var cursor
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if cursor == null or not cursor.cursor_visible or not cursor._has_focus:
			return   # another window is on top: leave the pointer to it
		var cs: float = clampf(G.cursor_scale, 0.5, 2.5)
		# trail
		var n: int = cursor._trail.size()
		for i in n:
			var p: Vector2 = cursor._trail[i]
			var a := 0.16 * (1.0 - float(i) / float(maxi(n, 1)))
			draw_circle(p, (4.5 - float(i) * 0.35) * cs,
				Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, a))
		var p0: Vector2 = cursor.pos
		var boost: float = cursor.hover_boost
		var r := (11.0 + boost * 4.0) * cs
		# white ring and core
		draw_arc(p0, r, 0, TAU, 40, Color(1.0, 0.96, 0.94, 0.9), 2.2, true)
		draw_circle(p0, (3.2 + boost * 2.0) * cs, Color(1.0, 0.96, 0.94, 0.95))
		# spinning ember arc around the rim
		var rr := r + 5.0 * cs
		draw_arc(p0, rr, t * 3.1, t * 3.1 + TAU * 0.28, 20,
			Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, 0.85 + boost * 0.15), 2.6, true)
		draw_arc(p0, rr, t * 3.1 + PI, t * 3.1 + PI + TAU * 0.28, 20,
			Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, 0.45), 2.2, true)
		# satellite dot on the ring
		var a2 := t * 3.1
		draw_circle(p0 + Vector2(cos(a2), sin(a2)) * rr, 2.6 * cs,
			Color(G.C_EMBER.r, G.C_EMBER.g, G.C_EMBER.b, 0.95))
