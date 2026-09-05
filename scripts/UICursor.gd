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
var _last_drag := Vector2.INF
var _draw_node: Node2D
var _os_expected := Vector2.INF   # where we believe the system pointer is
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


## Visible window area in design coordinates (aspect=fill can crop).
func _visible_rect() -> Rect2:
	return G.visible_rect_design()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
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
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_mode = true
			_last_drag = event.position
			if G.relative_touch and G.touch_zone:
				# relative: the cursor stays put, the finger acts as a stick
				pass
			else:
				# absolute: jump straight to the tap, otherwise a quick tap
				# only catches the cursor halfway through a lerp
				pos = event.position
				_trail.clear()
		else:
			_last_drag = Vector2.INF
	elif event is InputEventScreenDrag:
		if _last_drag != Vector2.INF:
			pos += (event.position - _last_drag) * G.mouse_sens
		_last_drag = event.position


## Raw touch handler: events before GUI controls swallow them, so relative
## mode keeps working when a finger lands on a button.
func _touch_input(event: InputEvent) -> void:
	if not (G.relative_touch and G.touch_zone):
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			touch_mode = true
			_last_drag = st.position
		else:
			_last_drag = Vector2.INF
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if _last_drag != Vector2.INF:
			pos += (dr.position - _last_drag) * G.mouse_sens
		_last_drag = dr.position


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
	var needs_warp := absf(G.mouse_sens - 1.0) > 0.01
	if needs_warp and not touch_mode and DisplayServer.get_name() != "headless" \
			and _focused():
		# keep the hidden system pointer under the drawn cursor, otherwise GUI
		# clicks miss
		if _os_expected == Vector2.INF or pos.distance_to(_os_expected) > 0.5:
			_os_expected = pos
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
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
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
