class_name CreditsScreen
extends Control
## CREDITS: кто сделал игру, ссылки, благодарности.

const LINES := [
	["Open Rhythm", 44, "title"],
	["created by narezany", 26, "text"],
	["", 10, "gap"],
	["coding — GLM 5.3 (thanks for the late nights!)", 19, "muted"],
	["game idea — inspired by Rhythia", 19, "muted"],
	["", 10, "gap"],
	["want more maps, contests and news?", 21, "text"],
	["join the community — buttons below", 24, "link"],
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(BackgroundFX.new(true))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.position = Vector2(0, 60)
	vb.size = Vector2(G.DESIGN.x, 520)
	add_child(vb)
	for ln in LINES:
		var kind: String = ln[2]
		if kind == "gap":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 14)
			vb.add_child(sp)
			continue
		var col: Color = G.C_TEXT
		if kind == "muted":
			col = G.C_MUTED
		elif kind == "link":
			col = Color("5865f2")
		var l := G.label(str(ln[0]), int(ln[1]), col, kind == "title")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 18)
	hb.position = Vector2(0, G.DESIGN.y - 160)
	hb.size = Vector2(G.DESIGN.x, 60)
	add_child(hb)
	var tg := G.button("Telegram forum", func():
		OS.shell_open("https://t.me/openrhythmforum"))
	tg.add_theme_color_override("font_color", Color("2aabee"))
	hb.add_child(tg)
	var dc := G.button("Discord", func():
		OS.shell_open("https://discord.gg/rc79e2sfqC"))
	dc.add_theme_color_override("font_color", Color("5865f2"))
	hb.add_child(dc)

	var back := G.button("← Back", func():
		G.play_sfx("click")
		G.main.goto_menu())
	back.position = Vector2(G.DESIGN.x / 2.0 - 110, G.DESIGN.y - 72)
	back.custom_minimum_size = Vector2(220, 0)
	add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		G.main.goto_menu()
