class_name DisclaimerScreen
extends Control
## Shown once, on the very first launch: this is a game, not a music player.
## The point is to send people to the artists rather than let the game stand in
## for listening to their work.

const TITLE := "BEFORE YOU START"

const BODY := [
	"Open Rhythm is a rhythm game, not a music player.",
	"",
	"The tracks here exist so there is something to play to. If a song grabs you — go and listen to it properly: Spotify, Apple Music, YouTube, Bandcamp, wherever the artist actually gets paid for it.",
	"",
	"We support the original authors. Maps are built on their songs out of respect for the music, and where an author has given their blessing we say so — the Verity tracks are used with the author's permission.",
	"",
	"If you are an artist and you want your track out of this game, tell us in Telegram or Discord and it is gone.",
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(BackgroundFX.new(true))

	var title := G.label(TITLE, 44, G.C_PRIMARY, true)
	title.position = Vector2(0, 54)
	title.size = Vector2(G.DESIGN.x, 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.7)))
	panel.position = Vector2(180, 130)
	panel.size = Vector2(G.DESIGN.x - 360, 400)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	for line in BODY:
		if line == "":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 10)
			vb.add_child(sp)
			continue
		var l := G.label(line, 19, G.C_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(G.DESIGN.x - 420, 0)
		vb.add_child(l)

	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 16)
	links.position = Vector2(0, G.DESIGN.y - 150)
	links.size = Vector2(G.DESIGN.x, 46)
	add_child(links)
	var tg := G.button("Telegram forum", func():
		OS.shell_open("https://t.me/openrhythmforum"), 18)
	links.add_child(tg)
	var dc := G.button("Discord", func():
		OS.shell_open("https://discord.gg/rc79e2sfqC"), 18)
	links.add_child(dc)

	var ok := G.button("I understand", _accept, 26)
	ok.position = Vector2(G.DESIGN.x / 2.0 - 140, G.DESIGN.y - 92)
	ok.custom_minimum_size = Vector2(280, 0)
	add_child(ok)

	G.view_changed.connect(func():
		var vis := G.visible_rect_design()
		panel.position = Vector2(vis.get_center().x - panel.size.x / 2.0, vis.position.y + 130.0)
		ok.position = Vector2(vis.get_center().x - 140.0, vis.end.y - 92.0)
		links.position.y = vis.end.y - 150.0)


func _accept() -> void:
	G.play_sfx("click")
	G.disclaimer_seen = true
	G.save_all()
	G.main.goto_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_accept()
