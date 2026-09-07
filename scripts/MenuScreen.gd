class_name MenuScreen
extends Control
## Main menu: rotating frames pulsing on the beat behind a three-card carousel;
## the centre card is the one in focus.

const ITEMS := [
	{"id": "play", "title": "PLAY", "sub": "free play\nor story mode"},
	{"id": "edit", "title": "MAP EDITOR", "sub": "create maps\nfor any track"},
	{"id": "songs", "title": "SONGS", "sub": "manage library\ndelete / disable"},
	{"id": "versus", "title": "VERSUS", "sub": "BETA · two players\none chart"},
	{"id": "stats", "title": "STATS", "sub": "records\nachievements"},
	{"id": "melly", "title": "MELLY", "sub": "colours\nand wardrobe"},
	{"id": "settings", "title": "SETTINGS", "sub": "audio\ncursor"},
	{"id": "credits", "title": "CREDITS", "sub": "who made this\nand why"},
	{"id": "quit", "title": "QUIT", "sub": "see you soon"},
]
const CARD_GAP := 460.0

var cur := 0
var trio: Array = []          # [{card, base_x, scale, alpha}]
var dots: Array = []
var _busy := false
var _press := Vector2.INF
var _dragging := false
var logo: Label
var tagline: Label
var score_hdr: Label
var score_val: Label
var footer: Label
var back_btn: Button
var carousel_y := 300.0
## Where to find the rest of it. Brand colours rather than one tint: on a black
## menu they are the fastest way to tell one small glyph from another.
const SOCIALS := [
	{"icon": "discord", "name": "Discord", "color": Color("5865f2"),
	 "url": "https://discord.gg/rc79e2sfqC"},
	{"icon": "telegram", "name": "Telegram forum", "color": Color("2aabee"),
	 "url": "https://t.me/openrhythmforum"},
	{"icon": "reddit", "name": "Reddit", "color": Color("ff4500"),
	 "url": "https://www.reddit.com/r/OpenRhythm/"},
	{"icon": "youtube", "name": "YouTube", "color": Color("ff0033"),
	 "url": "https://www.youtube.com/channel/UC4CKawg1MJ0bKah8IyvAyfg"},
]

## Two ways to give money, because one of them only works for some people.
const DONATE := [
	{"label": "YooMoney", "note": "Cards issued in Russia",
	 "url": "https://yoomoney.ru/to/4100118196133693"},
	{"label": "Boosty", "note": "Everywhere else",
	 "url": "https://boosty.to/ega_link"},
]

var _social_btns: Array = []
var _donate_layer: CanvasLayer = null

# --- update banner ---
var _updater: Updater
var _update_panel: PanelContainer
var _update_label: Label
var _update_btn: Button


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	add_child(BackgroundFX.new(true))
	add_child(BackdropRig.new())

	# plain white wordmark instead of an emblem
	logo = G.label("Open Rhythm", 64, Color(1, 1, 1, 0.97), true)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(logo)
	G.anchor_top_wide(logo, 52, 90)

	tagline = G.label("", 18, G.C_MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tagline)
	G.anchor_top_wide(tagline, 218, 26)

	# lifetime score, top right
	score_hdr = G.label("TOTAL SCORE", 13, G.C_MUTED)
	score_hdr.position = Vector2(G.DESIGN.x - 240, 18)
	score_hdr.size = Vector2(220, 18)
	score_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(score_hdr)
	score_val = G.label(G.fmt_score(G.total_score), 30, G.C_GOLD, true)
	score_val.position = Vector2(G.DESIGN.x - 240, 36)
	score_val.size = Vector2(220, 40)
	score_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(score_val)

	for cfg in [
		{"x": -CARD_GAP, "sc": 0.72, "a": 0.42},
		{"x": 0.0, "sc": 1.0, "a": 1.0},
		{"x": CARD_GAP, "sc": 0.72, "a": 0.42},
	]:
		var c := MenuCard.new()
		c.size = Vector2(500, 250)
		c.position = Vector2(G.DESIGN.x / 2.0 + float(cfg.x) - c.size.x / 2.0, 300)
		c.scale = Vector2.ONE * float(cfg.sc)
		c.modulate.a = float(cfg.a)
		c.pivot_offset = c.size / 2.0
		c.menu = self
		c.slot_x = float(cfg.x)
		add_child(c)
		trio.append({"card": c, "x": float(cfg.x), "sc": float(cfg.sc), "a": float(cfg.a)})

	for i in ITEMS.size():
		var d := ColorRect.new()
		d.size = Vector2(10, 10)
		d.position = Vector2(G.DESIGN.x / 2.0 - (ITEMS.size() * 18) / 2.0 + i * 18, 606)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(d)
		dots.append(d)

	footer = G.label(G.VERSION, 15, Color(1, 1, 1, 0.4))
	footer.position = Vector2(16, G.DESIGN.y - 32)
	footer.size = Vector2(200, 24)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(footer)

	# social links: small icons bottom right, newest on the left
	for i in SOCIALS.size():
		var so: Dictionary = SOCIALS[i]
		_add_social(str(so.icon), str(so.name), str(so.url), i, so.color)
	_add_donate(SOCIALS.size())

	# Everything already in the save is cashed in here, once - the menu is the
	# first place the song list is definitely loaded, and it is where the coin
	# count is about to be looked at.
	var back_pay := G.backfill_coins()
	if back_pay > 0:
		G.dev_log("coins: %d for what was already cleared" % back_pay)

	_build_update_banner()

	# adaptive anchors: headers to the edges, footer to the visible bottom
	G.view_changed.connect(_relayout)
	_relayout()
	_refill()
	Conductor.ensure_menu_music()


## A quiet strip under the logo: it only appears once GitHub has confirmed
## there is a newer release for this platform.
func _build_update_banner() -> void:
	_update_panel = PanelContainer.new()
	_update_panel.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_GOLD.r, G.C_GOLD.g, G.C_GOLD.b, 0.75)))
	_update_panel.visible = false
	add_child(_update_panel)
	G.anchor_top_wide(_update_panel, 150, 54, 320)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	_update_panel.add_child(hb)
	_update_label = G.label("", 18, G.C_GOLD)
	_update_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(_update_label)
	_update_btn = G.button("Update", _start_update, 16)
	hb.add_child(_update_btn)

	if not G.check_updates:
		return
	_updater = Updater.new()
	add_child(_updater)
	_updater.check_done.connect(_on_update_check)
	_updater.progress.connect(_on_update_progress)
	_updater.failed.connect(_on_update_failed)
	_updater.ready_to_install.connect(_on_update_ready)
	if _updater.can_update():
		_updater.check()


func _on_update_check(available: bool, version: String) -> void:
	if not available or _update_panel == null:
		return
	_update_label.text = tr("Version %s is out — you have %s") % [version, G.VERSION]
	_update_panel.visible = true
	G.play_sfx("click", 1.4, -12.0)


func _start_update() -> void:
	G.play_sfx("click")
	_update_btn.disabled = true
	_update_label.text = tr("Downloading…")
	_updater.download()


func _on_update_progress(done: int, total: int) -> void:
	if total <= 0:
		return
	_update_label.text = "%s  %d%%  (%.0f / %.0f MB)" % [tr("Downloading…"),
		int(100.0 * done / total), done / 1048576.0, total / 1048576.0]


func _on_update_failed(reason: String) -> void:
	_update_label.text = reason
	_update_btn.disabled = false
	_update_btn.text = tr("Retry")


func _on_update_ready(path: String) -> void:
	if OS.has_feature("android"):
		_update_label.text = tr("Saved to Downloads — open it to install")
		_update_btn.visible = false
		return
	_update_label.text = tr("Installing — the game will restart")
	_updater.install(path)


func _relayout() -> void:
	var vis := G.visible_rect_design()
	G.stick_right(score_hdr, 24)
	G.stick_right(score_val, 24)
	G.stick_bottom(footer, 10)
	footer.position.x = vis.position.x + 16.0
	for i in _social_btns.size():
		var b: Button = _social_btns[i]
		b.position = Vector2(vis.end.x - 52.0 - i * 56.0, vis.end.y - 62.0)
	for d in dots:
		G.stick_bottom(d, 92)
	# cards centred vertically inside the visible area
	carousel_y = vis.get_center().y - 125.0
	for slot in trio:
		var c: MenuCard = slot.card
		c.position.y = carousel_y
	# cards centred horizontally too, not just vertically
	var cx: float = vis.get_center().x
	for slot in trio:
		var c2: MenuCard = slot.card
		c2.position.x = cx + float(slot.x) - c2.size.x / 2.0
	G.anchor_top_wide(logo, minf(52.0, maxf(24.0, vis.size.y * 0.06)), 90)
	G.anchor_top_wide(tagline, carousel_y - 205.0, 26)
	# dots sit above the footer
	for d in dots:
		d.position.x = vis.get_center().x - (ITEMS.size() * 18) / 2.0 + dots.find(d) * 18


func _refill() -> void:
	var n := ITEMS.size()
	for i in trio.size():
		var slot: Dictionary = trio[i]
		var card: MenuCard = slot.card
		var idx := wrapi(cur + (i - 1), 0, n)
		var center: bool = i == 1
		card.setup(str(ITEMS[idx].title), str(ITEMS[idx].sub), _activate, center)
	for i in dots.size():
		var d: ColorRect = dots[i]
		d.color = G.C_PRIMARY if i == cur else Color(1, 1, 1, 0.18)


func _step(dir: int) -> void:
	if _busy or ITEMS.size() < 2:
		return
	_busy = true
	G.play_sfx("click", 1.2, -10.0)
	cur = wrapi(cur + dir, 0, ITEMS.size())
	# phase 1: slide out in the travel direction and fade
	var tw := create_tween().set_parallel(true)
	for slot in trio:
		var card: MenuCard = slot.card
		tw.tween_property(card, "position:x", card.position.x - dir * 110.0, 0.10) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 0.0, 0.10)
	tw.chain().tween_callback(func():
		# phase 2: the new trio slides in from the opposite side
		_refill()
		var cx: float = G.visible_rect_design().get_center().x
		var tw2 := create_tween().set_parallel(true)
		for slot in trio:
			var card: MenuCard = slot.card
			card.position.x = cx + float(slot.x) - card.size.x / 2.0 + dir * 110.0
			card.scale = Vector2.ONE * float(slot.sc)
			tw2.tween_property(card, "position:x",
				cx + float(slot.x) - card.size.x / 2.0, 0.14) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw2.tween_property(card, "modulate:a", float(slot.a), 0.14)
		tw2.chain().tween_callback(func(): _busy = false))


func _activate() -> void:
	var it: Dictionary = ITEMS[cur]
	G.play_sfx("click")
	match str(it.id):
		"play":
			G.main.goto_play_menu()
		"edit":
			G.main.goto_select("edit")
		"songs":
			G.main.goto_songs()
		"stats":
			G.main.goto_stats()
		"melly":
			G.main.goto_melly()
		"versus":
			G.main.goto_versus()
		"settings":
			G.main.goto_settings()
		"credits":
			G.main.goto_credits()
		"quit":
			get_tree().quit()


## Small social icon in the bottom-right corner.
func _add_social(icon: String, name_: String, url: String, idx: int,
		tint := Color.WHITE) -> void:
	var b := _icon_button(icon, name_, tint)
	b.pressed.connect(func():
		G.play_sfx("click")
		OS.shell_open(url))
	b.position = Vector2(G.DESIGN.x - 46 - idx * 56, G.DESIGN.y - 60)
	add_child(b)
	_social_btns.append(b)


## The donate button forks rather than going straight out: one of the two ways
## to pay only works with a card issued in Russia, and sending everybody else
## to a page they cannot use is worse than asking.
func _add_donate(idx: int) -> void:
	var b := _icon_button("heart", "Support the game", G.C_GOLD)
	b.pressed.connect(func():
		G.play_sfx("click")
		_show_donate())
	b.position = Vector2(G.DESIGN.x - 46 - idx * 56, G.DESIGN.y - 60)
	add_child(b)
	_social_btns.append(b)


func _icon_button(icon: String, name_: String, tint: Color) -> Button:
	var b := Button.new()
	b.tooltip_text = name_
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(46, 46)
	var path := "res://assets/icons/%s.svg" % icon
	var tr := TextureRect.new()
	tr.texture = load(path) if ResourceLoader.exists(path) else null
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(34, 34)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the artwork is monochrome, so the brand colour is applied here rather
	# than baked into the file - one place to change, and no surprise when a
	# logo turns out to be black on a black menu
	tr.modulate = Color(tint.r, tint.g, tint.b, 0.86)
	b.add_child(tr)
	b.mouse_entered.connect(func(): tr.modulate.a = 1.0)
	b.mouse_exited.connect(func(): tr.modulate.a = 0.86)
	return b


## The fork: which way you can actually pay.
func _show_donate() -> void:
	if _donate_layer != null and is_instance_valid(_donate_layer):
		_donate_layer.queue_free()
	_donate_layer = CanvasLayer.new()
	_donate_layer.layer = 60
	add_child(_donate_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.004, 0.008, 0.82)
	_donate_layer.add_child(dim)
	G.anchor_full(dim)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_donate_layer.queue_free())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_GOLD.r, G.C_GOLD.g, G.C_GOLD.b, 0.6)))
	_donate_layer.add_child(panel)
	panel.size = Vector2(520, 300)
	panel.position = (G.canvas_size() - panel.size) * 0.5
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var t := G.label("Support the game", 28, G.C_GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub2 := G.label("Open Rhythm is free and stays free. This only helps it get made.",
		16, G.C_MUTED)
	sub2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub2)
	for d in DONATE:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var url := str(d.url)
		var btn := G.button(str(d.label), func():
			G.play_sfx("click")
			OS.shell_open(url), 24)
		row.add_child(btn)
		var note := G.label(str(d.note), 15, G.C_MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(note)
		vb.add_child(row)
	var close := G.button("Close", func():
		G.play_sfx("click")
		_donate_layer.queue_free(), 20)
	vb.add_child(close)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_step(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_step(1)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				_step(-1)
			KEY_RIGHT:
				_step(1)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_press = st.position
			_dragging = true
		else:
			if _dragging and _press != Vector2.INF:
				var dx := st.position.x - _press.x
				if absf(dx) > 70.0:
					_step(-1 if dx > 0 else 1)
			_dragging = false
			_press = Vector2.INF


## Rotating translucent frames in the background, pulsing on the beat.
class BackdropRig extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		position = G.DESIGN / 2.0
		queue_redraw()

	func _draw() -> void:
		var pulse := pow(1.0 - Conductor.phase(), 3.0) * 0.03 if Conductor.playing else 0.0
		rotation = t * 0.10
		scale = Vector2.ONE * (1.0 + pulse)
		var pts1 := G.rounded_points(Rect2(-360, -360, 720, 720), 54.0)
		pts1.append(pts1[0])
		draw_polyline(pts1, Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.22), 4.0, true)
		var pts2 := G.rounded_points(Rect2(-455, -455, 910, 910), 70.0)
		pts2.append(pts2[0])
		draw_polyline(pts2, Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.10), 2.5, true)
		for k in 4:
			var a := TAU * float(k) / 4.0 + PI / 4.0
			draw_circle(Vector2(cos(a), sin(a)) * 360.0, 4.0, Color(1, 1, 1, 0.30))



## One carousel card. The centre card activates, the side ones step the carousel.
class MenuCard extends Control:
	var title := ""
	var sub := ""
	var cb: Callable
	var is_center := false
	var menu: Node
	var slot_x := 0.0
	var hover := 0.0

	## draw_string does not auto-translate the way a Label does, so the card
	## text is translated here, once, when it is set.
	func setup(t: String, s: String, c: Callable, center: bool) -> void:
		title = tr(t)
		sub = tr(s)
		cb = c
		is_center = center
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		queue_redraw()

	func _ready() -> void:
		mouse_entered.connect(func(): hover = 1.0)
		mouse_exited.connect(func(): hover = 0.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			if is_center:
				if cb.is_valid():
					cb.call()
			elif menu != null:
				menu._step(1 if slot_x > 0.0 else -1)

	func _process(delta: float) -> void:
		hover = maxf(0.0, hover - delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var lift := hover * (10.0 if is_center else 4.0)
		var rr := r.grow(lift)
		G.draw_rounded_rect(self, rr, 26.0, Color(0.055, 0.010, 0.020, 0.82 + hover * 0.12))
		G.draw_rounded_outline(self, rr, 26.0,
			Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b,
				(0.5 + hover * 0.45) if is_center else 0.18 + hover * 0.2), 3.5 if is_center else 2.0)
		var fs := 58 + int(hover * 5) if is_center else 40
		var tw := G.font_logo.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(G.font_logo, Vector2(r.size.x / 2.0 - tw / 2.0, r.size.y * 0.44),
			title, HORIZONTAL_ALIGNMENT_LEFT, tw, fs,
			Color(G.C_TEXT.r, G.C_TEXT.g, G.C_TEXT.b, 0.95))
		var lines := sub.split("\n")
		var yy := r.size.y * 0.62
		for ln in lines:
			var sw := G.font_body.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(G.font_body, Vector2(r.size.x / 2.0 - sw / 2.0, yy), ln,
				HORIZONTAL_ALIGNMENT_LEFT, sw, 20 if is_center else 15,
				Color(G.C_MUTED.r, G.C_MUTED.g, G.C_MUTED.b, 0.85))
			yy += 25.0 if is_center else 19.0
		draw_rect(Rect2(r.size.x * 0.5 - 40.0 - lift * 2.4, r.size.y - 22.0,
			(80.0 + lift * 4.8), 4.0), Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.9))
