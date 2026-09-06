extends Node
## Layout check: build every screen at a range of window sizes and report any
## control that lands outside the canvas. Catches both "does not fit" and
## "flies off somewhere" without needing a real window manager.
##   godot --headless --path . res://tools/LayoutTest.tscn

const CASES := [
	Vector2i(1280, 720),    # design
	Vector2i(1920, 1080),   # 16:9
	Vector2i(2400, 1080),   # 20:9 phone in landscape
	Vector2i(2560, 1080),   # 21:9 ultrawide
	Vector2i(1024, 768),    # 4:3
	Vector2i(800, 1280),    # portrait
]

var fails := 0


func _ready() -> void:
	for sz in CASES:
		await _run_case(sz)
	print("--- overflowing controls: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _run_case(sz: Vector2i) -> void:
	get_window().size = sz
	G.view_w = float(sz.x)
	G.view_h = float(sz.y)
	G.view_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var canvas := G.canvas_size()
	print("== window %dx%d -> canvas %.0fx%.0f" % [sz.x, sz.y, canvas.x, canvas.y])
	for entry in [
		["MenuScreen", MenuScreen], ["SettingsScreen", SettingsScreen],
		["SongsScreen", SongsScreen], ["SongSelectScreen", SongSelectScreen],
		["StatsScreen", StatsScreen], ["CalibrationScreen", CalibrationScreen],
		["DisclaimerScreen", DisclaimerScreen], ["CreditsScreen", CreditsScreen],
		["StoryScreen", StoryScreen], ["PlayChoiceScreen", PlayChoiceScreen],
		["VersusScreen", VersusScreen],
	]:
		await _check(str(entry[0]), entry[1].new(), canvas)
	# the modifier panel is hidden until a difficulty is picked, and a hidden
	# branch is never laid out - open it explicitly or it is never checked
	var sel := SongSelectScreen.new()
	sel.mode = "play"
	add_child(sel)
	await get_tree().process_frame
	sel._fill_mods(true)
	sel._mods_layer.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var bad: Array = []
	_walk(sel, canvas, bad)
	if bad.is_empty():
		print("  ok   modifier panel")
	else:
		fails += bad.size()
		print("  BAD  modifier panel")
		for b in bad:
			print("         %s" % b)
	sel.queue_free()
	await get_tree().process_frame

	# Every settings tab, not just the one that opens first. A tab is only built
	# when it is opened, so an unopened one is never laid out and never run at
	# all - which is how a crash in the VR tab shipped without a test noticing.
	var st := SettingsScreen.new()
	add_child(st)
	await get_tree().process_frame
	for tab in SettingsScreen.TABS.size():
		st._switch(tab)
		await get_tree().process_frame
		await get_tree().process_frame
		var tab_bad: Array = []
		_walk(st, canvas, tab_bad)
		if tab_bad.is_empty():
			print("  ok   settings: %s" % SettingsScreen.TABS[tab])
		else:
			fails += tab_bad.size()
			print("  BAD  settings: %s" % SettingsScreen.TABS[tab])
			for b in tab_bad:
				print("         %s" % b)
	st.queue_free()
	await get_tree().process_frame
	var songs := RhythmMap.load_songs()
	if not songs.is_empty():
		var e := EditorScreen.new()
		e.song = songs[0]
		e.diff_idx = 0
		await _check("EditorScreen", e, canvas)


func _check(name: String, screen: Node, canvas: Vector2) -> void:
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var bad: Array = []
	_walk(screen, canvas, bad)
	if not bad.is_empty():
		fails += bad.size()
		print("  BAD  %s (root size %s)" % [name,
			str((screen as Control).size) if screen is Control else "n/a"])
		for b in bad:
			print("         %s" % b)
	screen.queue_free()
	await get_tree().process_frame


func _walk(node: Node, canvas: Vector2, bad: Array) -> void:
	for c in node.get_children():
		if c is Control and not _skip(c):
			var r: Rect2 = (c as Control).get_global_rect()
			if r.size.x > 0.5 and r.size.y > 0.5:
				if r.end.x > canvas.x + 1.5 or r.end.y > canvas.y + 1.5 \
						or r.position.x < -1.5 or r.position.y < -1.5:
					bad.append("%s %s %s" % [c.get_class(), c.name, str(r)])
		_walk(c, canvas, bad)


## Skip things that are meant to spill: scroll contents, the overscanned
## background rect and the SubViewport Melly renders into.
func _skip(c: Node) -> bool:
	if c is SubViewportContainer or c is MellyRig:
		return true
	if not (c as CanvasItem).is_visible_in_tree():
		return true   # hidden branches are not sorted by their containers
	if c is ColorRect and (c as ColorRect).material != null:
		return true
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer or p is MellyRig:
			return true
		p = p.get_parent()
	return false
