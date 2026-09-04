class_name PlayChoiceScreen
extends Control
## PLAY: two big buttons, Free Play and Story Mode.
## Free Play unlocks once the tutorial has been cleared.

const CARD := [Vector2(340, 200), Vector2(620, 200)]


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	add_child(BackgroundFX.new(true))

	var title := G.label("PLAY", 52, G.C_TEXT, true)
	title.position = Vector2(0, 70)
	G.anchor_top_wide(title, title.position.y, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var locked := not _tutorial_done()

	# --- Free Play, unlocked after the tutorial ---
	_card(Vector2(220, 210), "FREE PLAY",
		"Every song in your library.\nMods, difficulties, records.",
		func(): G.main.goto_select("play"), locked)
	# --- Story Mode, always open: story 1 is the tutorial ---
	_card(Vector2(640, 210), "STORY MODE",
		"Two stories: learn with Melly,\nthen prove yourself on Night Drive.",
		func(): G.main.goto_story(), false)

	var lock_note := G.label(
		"finish the TUTORIAL first (Story Mode) to unlock Free Play" if locked else "",
		18, G.C_MUTED)
	lock_note.position = Vector2(0, 470)
	G.anchor_top_wide(lock_note, lock_note.position.y, 30)
	lock_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lock_note)

	var back := G.button("← Back", func():
		G.play_sfx("click")
		G.main.goto_menu())
	G.anchor_bottom_center(back, 38, Vector2(220, 46))
	back.custom_minimum_size = Vector2(220, 0)
	add_child(back)


func _tutorial_done() -> bool:
	return not G.get_best("tutorial", "Easy").is_empty()


func _card(pos: Vector2, title: String, sub: String, on_pick: Callable, locked: bool) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.25 if locked else 0.8)))
	p.position = pos
	p.size = Vector2(420, 230)
	add_child(p)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	var t := G.label(title, 34, G.C_GOLD if not locked else G.C_MUTED, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var s := G.label(sub, 17, G.C_TEXT if not locked else G.C_MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	var b := G.button("OPEN" if not locked else "LOCKED", func():
		if locked:
			G.play_sfx("miss", 1.0, -6.0)
			return
		G.play_sfx("click")
		on_pick.call())
	b.custom_minimum_size = Vector2(200, 0)
	vb.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		G.main.goto_menu()
