class_name CreditsScreen
extends Control
## Credits: who made the game, links and thanks.

const LINES := [
	["Open Rhythm", 44, "title"],
	["created by narezany", 26, "text"],
	["", 10, "gap"],
	["coding — Claude Opus 5 (thanks for the late nights!)", 19, "muted"],
	["game idea — inspired by Rhythia", 19, "muted"],
	["", 10, "gap"],
	["want more maps, contests and news?", 21, "text"],
	["join the community — buttons below", 24, "link"],
]


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	add_child(BackgroundFX.new(true))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	G.anchor_top_wide(vb, 60, 520)
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
	add_child(hb)
	G.anchor_bottom_wide(hb, 100, 60)
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
	add_child(back)
	G.anchor_bottom_center(back, 26, Vector2(220, 46))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		G.main.goto_menu()
