class_name SettingsScreen
extends Control
## Settings, split into tabs: audio (with the offset), video, accessibility,
## controls (including key rebinding), language and Melly's colours.

## Preset swatches for Melly - not a full picker, just a palette.
const PRESETS := [
	"ff2b3a", "9c1022", "ff7a45", "ffb547",
	"f2e8e4", "8a8a92", "26262b", "27408b",
	"4a7dff", "2ec4b6", "46c46e", "9ade3b",
	"b04ad9", "ff6fa8", "7a4a2a", "ffd23f",
]

const TABS := ["Audio", "Video", "Accessibility", "Controls", "Language", "Melly"]
const FPS_STEPS := [0, 30, 60, 90, 120, 144, 165, 240]

var tab := 0
var _tab_buttons: Array = []
var _panel: PanelContainer
var _body: VBoxContainer
var _rig: MellyRig
var _rebinding := ""
var _rebind_rows := {}


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	add_child(BackgroundFX.new(true))

	var title := G.label("SETTINGS", 46, G.C_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	G.anchor_top_wide(title, 34, 60)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	G.anchor_top_wide(tabs, 100, 46)
	for i in TABS.size():
		var idx := i
		var b := G.button(TABS[i], func(): _switch(idx), 20)
		tabs.add_child(b)
		_tab_buttons.append(b)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", G.panel_style())
	add_child(_panel)
	G.anchor_margins(_panel, 150, 158, 150, 82)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)

	var back := G.button("Back", func():
		G.play_sfx("click")
		G.main.goto_menu(), 24)
	add_child(back)
	G.anchor_bottom_center(back, 16, Vector2(220, 46))

	_switch(0)


func _switch(i: int) -> void:
	tab = i
	_rebinding = ""
	G.play_sfx("click", 1.2, -8.0)
	for j in _tab_buttons.size():
		var b: Button = _tab_buttons[j]
		b.add_theme_color_override("font_color", G.C_PRIMARY if j == i else G.C_MUTED)
	for c in _body.get_children():
		c.queue_free()
	_rig = null
	_rebind_rows.clear()
	match i:
		0: _build_audio()
		1: _build_video()
		2: _build_a11y()
		3: _build_controls()
		4: _build_language()
		5: _build_melly()


# ---------------------------------------------------------------- tabs
func _build_audio() -> void:
	_body.add_child(_slider("Master volume", G.master_vol, 0.0, 1.0, 0.05,
		func(v): G.set_master_volume(v); G.save_all()))
	_body.add_child(_slider("Music volume", G.music_vol, 0.0, 1.0, 0.05,
		func(v): G.set_music_volume(v); G.save_all()))
	_body.add_child(_slider("SFX volume", G.sfx_vol, 0.0, 1.0, 0.05,
		func(v): G.set_sfx_volume(v); G.save_all()))
	_body.add_child(_check("Hitsounds", G.hitsound,
		func(on): G.hitsound = on; G.save_all()))
	_body.add_child(_sep())

	var off_lbl := G.label("", 17, G.C_MUTED)
	var upd := func():
		off_lbl.text = "%+d ms" % roundi(G.audio_offset * 1000.0)
	_body.add_child(_slider("Audio offset", G.audio_offset * 1000.0, -250.0, 250.0, 1.0,
		func(v):
			G.audio_offset = float(v) / 1000.0
			upd.call()
			G.save_all()))
	upd.call()
	_body.add_child(off_lbl)
	var hint := G.label("Positive values judge notes later, for when you hear the audio late. Let the game measure it for you:",
		15, Color(1, 1, 1, 0.45))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(hint)
	var cal := G.button("Calibrate", func():
		G.play_sfx("click")
		G.main.goto_calibration(), 22)
	cal.custom_minimum_size = Vector2(240, 0)
	_body.add_child(cal)
	_body.add_child(_sep())

	var hit_lbl := G.label("", 17, G.C_MUTED)
	var hit_upd := func():
		hit_lbl.text = "%+d ms" % roundi(G.hit_offset * 1000.0)
	_body.add_child(_slider("Hitsound offset", G.hit_offset * 1000.0, -200.0, 200.0, 1.0,
		func(v):
			G.hit_offset = float(v) / 1000.0
			hit_upd.call()
			G.save_all()))
	hit_upd.call()
	_body.add_child(hit_lbl)
	var hit_hint := G.label("Only the hitsound, not the judging. Phones often play sound later than they admit to; raise this until the tap sits on the beat.",
		15, Color(1, 1, 1, 0.45))
	hit_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hit_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(hit_hint)


func _build_video() -> void:
	if not G.is_mobile():
		_body.add_child(_check("Fullscreen", G.fullscreen, func(on):
			G.fullscreen = on
			G.apply_video()
			G.save_all()))
	_body.add_child(_check("V-Sync", G.vsync, func(on):
		G.vsync = on
		G.apply_video()
		G.save_all()))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := G.label("FPS limit", 20, G.C_MUTED)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.add_theme_font_override("font", G.font_body)
	opt.add_theme_font_size_override("font_size", 19)
	for i in FPS_STEPS.size():
		opt.add_item("unlimited" if FPS_STEPS[i] == 0 else str(FPS_STEPS[i]), i)
		if FPS_STEPS[i] == G.max_fps:
			opt.select(i)
	opt.item_selected.connect(func(i):
		G.max_fps = int(FPS_STEPS[i])
		G.apply_video()
		G.save_all())
	row.add_child(opt)
	_body.add_child(row)

	_body.add_child(_sep())
	_body.add_child(_check("Disable song video", G.disable_song_video, func(on):
		G.disable_song_video = on
		G.save_all()))
	_body.add_child(_check("Check for updates", G.check_updates, func(on):
		G.check_updates = on
		G.save_all()))
	var uh := G.label("Asks GitHub once, when the menu opens, whether a newer release exists. Nothing is sent.",
		15, Color(1, 1, 1, 0.45))
	uh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(uh)


func _build_a11y() -> void:
	_body.add_child(_check("Reduce motion", G.reduce_motion, func(on):
		G.reduce_motion = on
		G.save_all()))
	var m := G.label("Damps camera shake, zoom punches and parallax.", 15, Color(1, 1, 1, 0.45))
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(m)

	_body.add_child(_check("Reduce flashes", G.reduce_flashes, func(on):
		G.reduce_flashes = on
		G.save_all()))
	var f := G.label("Damps full-screen flashes and strobing on the beat. Recommended if bright flashing bothers you.",
		15, Color(1, 1, 1, 0.45))
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(f)

	_body.add_child(_sep())
	_body.add_child(_check("Disable song video", G.disable_song_video, func(on):
		G.disable_song_video = on
		G.save_all()))
	_body.add_child(_slider("Cursor size", G.cursor_scale, 0.6, 2.2, 0.1,
		func(v): G.cursor_scale = v; G.save_all()))


func _build_controls() -> void:
	if G.is_mobile():
		_body.add_child(_check("Relative touch cursor", G.relative_touch, func(on):
			G.relative_touch = on
			G.save_all()))
		var hint := G.label("Cursor moves with finger offset, stays where left. Game/editor only.",
			15, G.C_MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.add_child(hint)
	else:
		_body.add_child(_slider("Cursor sensitivity", G.mouse_sens, 0.4, 2.0, 0.05,
			func(v): G.mouse_sens = v; G.save_all()))
	_body.add_child(_slider("Gamepad cursor speed", G.gamepad_speed, 300.0, 2000.0, 50.0,
		func(v): G.gamepad_speed = v; G.save_all()))
	_body.add_child(_sep())

	for action in Binds.ACTIONS:
		_body.add_child(_bind_row(action))
	var reset := G.button("Reset to defaults", func():
		G.key_binds.clear()
		Binds.apply(G.key_binds)
		G.save_all()
		G.play_sfx("click")
		_switch(3), 20)
	reset.custom_minimum_size = Vector2(260, 0)
	_body.add_child(reset)


func _build_language() -> void:
	for l in Loc.LANGS:
		var code := str(l.code)
		var b := G.button(str(l.name), func():
			G.set_locale(code)
			G.play_sfx("click")
			_switch(4), 22)
		b.custom_minimum_size = Vector2(300, 0)
		if code == G.locale:
			b.add_theme_color_override("font_color", G.C_PRIMARY)
		_body.add_child(b)
	var note := G.label("Some in-game text is only in English for now.", 15, Color(1, 1, 1, 0.4))
	_body.add_child(note)


func _build_melly() -> void:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(0, 176)
	_body.add_child(cc)
	_rig = MellyRig.new()
	_rig.size = Vector2(168, 172)
	_rig.custom_minimum_size = Vector2(168, 172)
	cc.add_child(_rig)

	for part in MellyRig.PARTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var pl := G.label(MellyRig.PART_NAMES[part], 15, G.C_MUTED)
		pl.custom_minimum_size = Vector2(90, 0)
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(pl)
		for hex in PRESETS:
			row.add_child(_swatch(hex, part))
		_body.add_child(row)


# ---------------------------------------------------------------- widgets
func _sep() -> Control:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.08)
	c.custom_minimum_size = Vector2(0, 2)
	return c


func _check(text: String, value: bool, cb: Callable) -> CheckButton:
	var chk := CheckButton.new()
	chk.text = text
	chk.button_pressed = value
	chk.add_theme_font_override("font", G.font_body)
	chk.add_theme_font_size_override("font_size", 21)
	chk.toggled.connect(cb)
	return chk


func _slider(text: String, value: float, mn: float, mx: float, step: float,
		cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := G.label(text, 20, G.C_MUTED)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 26)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(cb)
	row.add_child(s)
	return row


func _bind_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := G.label(Binds.label_of(action), 19, G.C_MUTED)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var b := G.button(Binds.keys_text(G.key_binds, action), func():
		_rebinding = action
		_refresh_binds(), 18)
	b.custom_minimum_size = Vector2(240, 0)
	row.add_child(b)
	_rebind_rows[action] = b
	return row


func _refresh_binds() -> void:
	for action in _rebind_rows:
		var b: Button = _rebind_rows[action]
		b.text = "press a key…" if action == _rebinding \
			else Binds.keys_text(G.key_binds, action)


func _swatch(hex: String, part: String) -> Button:
	var b := Button.new()
	var c := Color(hex)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.25)
	var sbh := sb.duplicate()
	sbh.border_color = Color(1, 1, 1, 0.9)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(19, 19)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = part
	b.pressed.connect(func():
		G.melly_colors[part] = c
		G.save_all()
		Achievements.unlock("melly_paint")
		G.play_sfx("click", 1.3, -6.0)
		if _rig != null:
			_rig.apply_colors()
		if G.melly != null and G.melly != _rig:
			G.melly.apply_colors())
	return b


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if _rebinding != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_rebinding = ""
			else:
				G.key_binds[_rebinding] = [int(event.physical_keycode)]
				Binds.apply(G.key_binds)
				G.save_all()
				_rebinding = ""
			_refresh_binds()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		go_back()
		return


## Esc, and the Android back button.
func go_back() -> void:
	G.main.goto_menu()
