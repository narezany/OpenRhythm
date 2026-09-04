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
	G.anchor_full(self)   # fill the canvas: children anchor against this
	add_child(BackgroundFX.new(true))

	var title := G.label(TITLE, 44, G.C_PRIMARY, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	G.anchor_top_wide(title, 54, 58)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", G.panel_style(
		Color(G.C_PRIMARY.r, G.C_PRIMARY.g, G.C_PRIMARY.b, 0.7)))
	add_child(panel)
	G.anchor_margins(panel, 180, 130, 180, 190)

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
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(l)

	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 16)
	add_child(links)
	G.anchor_bottom_wide(links, 104, 46)
	var tg := G.button("Telegram forum", func():
		OS.shell_open("https://t.me/openrhythmforum"), 18)
	links.add_child(tg)
	var dc := G.button("Discord", func():
		OS.shell_open("https://discord.gg/rc79e2sfqC"), 18)
	links.add_child(dc)

	var ok := G.button("I understand", _accept, 26)
	add_child(ok)
	G.anchor_bottom_center(ok, 40, Vector2(280, 50))


func _accept() -> void:
	G.play_sfx("click")
	G.disclaimer_seen = true
	G.save_all()
	G.main.goto_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_accept()
