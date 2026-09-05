class_name VersusScreen
extends Control
## Versus: two players, one chart, whoever scores more wins.
##
## The connection is direct - one side hosts and the other types their address.
## Nothing goes through a server, so both machines have to be able to reach each
## other: the same network, or the host forwarding the port.

var _status: Label
var _addr: LineEdit
var _port: LineEdit
var _list_root: VBoxContainer
var _start_btn: Button
var _pick_song: Dictionary = {}
var _pick_diff := 0
var _ready_to_start := false


func _ready() -> void:
	G.anchor_full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(BackgroundFX.new(true))

	var title := G.label("VERSUS  ·  BETA", 46, G.C_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	G.anchor_top_wide(title, 30, 60)

	var sub := G.label("Two players, one chart, higher score wins. Direct connection, no server.",
		17, G.C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	G.anchor_top_wide(sub, 90, 24)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	G.anchor_top_wide(row, 124, 46)
	row.add_child(G.button("HOST", _host, 22))
	_addr = LineEdit.new()
	_addr.placeholder_text = "host address, e.g. 192.168.1.42"
	_addr.add_theme_font_override("font", G.font_body)
	_addr.add_theme_font_size_override("font_size", 18)
	_addr.custom_minimum_size = Vector2(320, 0)
	row.add_child(_addr)
	_port = LineEdit.new()
	_port.text = str(Net.DEFAULT_PORT)
	_port.add_theme_font_override("font", G.font_body)
	_port.add_theme_font_size_override("font_size", 18)
	_port.custom_minimum_size = Vector2(90, 0)
	row.add_child(_port)
	row.add_child(G.button("JOIN", _join, 22))
	row.add_child(G.button("Disconnect", _disconnect, 18))

	_status = G.label("Not connected", 19, G.C_GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	G.anchor_top_wide(_status, 178, 48, 120)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	G.anchor_margins(scroll, 150, 232, 150, 116)
	_list_root = VBoxContainer.new()
	_list_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_root.add_theme_constant_override("separation", 12)
	scroll.add_child(_list_root)

	_start_btn = G.button("START THE MATCH", _start, 24)
	_start_btn.disabled = true
	add_child(_start_btn)
	G.anchor_bottom_center(_start_btn, 62, Vector2(320, 48))

	var back := G.button("← Back", func():
		G.play_sfx("click")
		Net.close()
		G.main.goto_menu(), 20)
	add_child(back)
	G.anchor_corner(back, false, true, 24, 20, Vector2(180, 44))

	Net.state_changed.connect(_on_state)
	Net.match_ready.connect(_on_ready)
	Net.match_refused.connect(_on_refused)
	Net.match_start.connect(_on_start)
	_build_songs()
	_refresh()


# ---------------------------------------------------------------- connection
func _host() -> void:
	G.play_sfx("click")
	var err := Net.host(_port_value())
	if err != "":
		_on_state(err)
	_refresh()


func _join() -> void:
	G.play_sfx("click")
	if _addr.text.strip_edges() == "":
		_on_state("Type the host's address first")
		return
	var err := Net.join(_addr.text, _port_value())
	if err != "":
		_on_state(err)
	_refresh()


func _disconnect() -> void:
	G.play_sfx("click", 0.8)
	Net.close()
	_ready_to_start = false
	_on_state("Not connected")
	_refresh()


func _port_value() -> int:
	var p := int(_port.text)
	return p if p > 0 and p < 65536 else Net.DEFAULT_PORT


func _on_state(text: String) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", G.C_GOLD)
	_refresh()


func _on_ready(song_id: String, diff: String) -> void:
	_ready_to_start = true
	_status.text = "Both of you have %s [%s] — ready" % [song_id, diff]
	_status.add_theme_color_override("font_color", G.C_GOLD)
	_refresh()


func _on_refused(reason: String) -> void:
	_ready_to_start = false
	_status.text = reason
	_status.add_theme_color_override("font_color", G.C_PRIMARY)
	G.play_sfx("miss", 1.0, -6.0)
	_refresh()


func _on_start() -> void:
	G.active_mods.clear()
	Conductor.stop_music()
	G.main.start_game()


func _start() -> void:
	G.play_sfx("click", 1.3)
	Net.start_match()


func _refresh() -> void:
	var host_ready: bool = Net.role == "host" and Net.connected
	_start_btn.disabled = not (host_ready and _ready_to_start)
	_list_root.visible = Net.role == "host"


# ---------------------------------------------------------------- song list
func _build_songs() -> void:
	for song: Dictionary in RhythmMap.load_songs():
		if not RhythmMap.is_playable(song):
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", G.panel_style())
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 20)
		panel.add_child(hb)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		left.add_child(G.label(str(song.get("title", "?")), 26, G.C_TEXT))
		left.add_child(G.label(str(song.get("artist", "")), 16, G.C_MUTED))
		hb.add_child(left)
		var diffs := RhythmMap.diffs_of(song)
		for i in diffs.size():
			var idx := i
			var s: Dictionary = song
			hb.add_child(G.button(str(diffs[i].get("name", "?")),
				func(): _offer(s, idx), 18))
		_list_root.add_child(panel)


func _offer(song: Dictionary, diff_idx: int) -> void:
	if Net.role != "host" or not Net.connected:
		_on_state("Nobody has joined yet")
		return
	G.play_sfx("click")
	_pick_song = song
	_pick_diff = diff_idx
	G.selected_song = song
	G.selected_diff = diff_idx
	_ready_to_start = false
	_status.text = "Checking the other player has the same chart…"
	Net.offer(song, diff_idx)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		return


## Esc, and the Android back button.
func go_back() -> void:
	Net.close()
	G.main.goto_menu()
