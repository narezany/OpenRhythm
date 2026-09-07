class_name ResultsScreen
extends Control
## Results: rank, breakdown, records, unlocked achievements, confetti.

var data: Dictionary
var buttons: HBoxContainer
var _versus_row: HBoxContainer
var _versus_verdict: Label


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	add_child(BackgroundFX.new(true))

	var rank: String = str(data.get("rank", "D"))
	var rcol := Judge.rank_color(rank)

	var rank_label := G.label(rank, 170, rcol, true)
	rank_label.position = Vector2(0, 150)
	rank_label.size = Vector2(464, 240)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(rank_label)
	rank_label.pivot_offset = rank_label.size / 2.0
	rank_label.scale = Vector2(3.0, 3.0)
	rank_label.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rank_label, "scale", Vector2.ONE, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rank_label, "modulate:a", 1.0, 0.25)

	# A lost run says so, in the one place the eye goes first. It used to read
	# RESULTS in muted grey whether you had cleared the song or been buried by
	# it, which is how a failed run came to look exactly like a win.
	var failed: bool = bool(data.get("failed", Judge.failed(rank)))
	var sub := G.label("FAILED" if failed else "RESULTS", 22,
		G.JUDGE_COLORS["MISS"] if failed else G.C_MUTED)
	sub.position = Vector2(0, 118)
	sub.size = Vector2(464, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	# Melly celebrates a good run and sulks at a D
	var rig := MellyRig.new()
	rig.position = Vector2(G.DESIGN.x - 340, G.DESIGN.y - 420)
	rig.size = Vector2(340, 400)
	add_child(rig)
	# adaptive anchors: Melly bottom-right, panel centred, buttons to the bottom
	var vis0 := G.visible_rect_design()
	rig.position = Vector2(vis0.end.x - rig.size.x, vis0.end.y - rig.size.y)
	rig.set_mood("sad" if failed else "very")

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", G.panel_style())
	panel.position = Vector2(464, 96)
	panel.size = Vector2(560, 440)
	add_child(panel)

	# The panel holds however much the run turned out to be worth saying: mods,
	# a versus verdict, a handful of achievements. On a short window, or after a
	# run that unlocked three things at once, that used to run off the bottom of
	# the screen with no way to reach it. It scrolls now, the way the modifier
	# list does, and it can be pulled by grabbing anywhere in it.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	DragScroll.attach(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	var title := G.label("%s  [%s]" % [str(data.get("title", "?")), str(data.get("diff", ""))], 30, G.C_TEXT)
	vb.add_child(title)
	vb.add_child(G.label(str(data.get("artist", "")), 18, G.C_MUTED))

	var mods: Array = data.get("mods", [])
	if not mods.is_empty():
		var names: Array = []
		for id in mods:
			for md in G.MODS:
				if md.id == id:
					names.append(str(md.label))
		vb.add_child(G.label("mods: " + "  ".join(names), 17, G.C_EMBER))

	vb.add_child(HSpacer.new(10))
	vb.add_child(_row("SCORE", G.fmt_score(int(data.get("score", 0))), G.C_TEXT, 34))
	vb.add_child(_row("ACCURACY", "%.2f%%" % (float(data.get("acc", 0.0)) * 100.0), G.C_GOLD, 30))
	vb.add_child(_row("MAX COMBO", str(int(data.get("max_combo", 0))), G.C_PRIMARY, 26))
	vb.add_child(HSpacer.new(8))

	var counts: Dictionary = data.get("counts", {})
	vb.add_child(_row("PERFECT", str(counts.get("PERFECT", 0)), G.JUDGE_COLORS["PERFECT"], 22))
	vb.add_child(_row("GREAT", str(counts.get("GREAT", 0)), G.JUDGE_COLORS["GREAT"], 22))
	vb.add_child(_row("GOOD", str(counts.get("GOOD", 0)), G.JUDGE_COLORS["GOOD"], 22))
	if int(counts.get("BULLSHIT", 0)) > 0:
		vb.add_child(_row("BULLSHIT", str(counts.get("BULLSHIT", 0)), G.JUDGE_COLORS["BULLSHIT"], 22))
	vb.add_child(_row("MISS", str(counts.get("MISS", 0)), G.JUDGE_COLORS["MISS"], 22))

	if data.get("on_mobile", false):
		var ml := G.label("played on phone  •  bigger hit zones", 15, G.C_MUTED)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(ml)

	if data.get("story_complete", false):
		var sc := G.label("★ STORY COMPLETE ★", 26, Color("ffd700"), true)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(sc)

	# versus: the other player's score, and who took it
	if data.get("versus", false):
		vb.add_child(HSpacer.new(8))
		_versus_row = _row("VERSUS", "…", G.C_EMBER, 26)
		vb.add_child(_versus_row)
		_versus_verdict = G.label("", 24, G.C_GOLD, true)
		_versus_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(_versus_verdict)
		if not Net.opponent_finished.is_connected(_on_opponent_done):
			Net.opponent_finished.connect(_on_opponent_done)
		_update_versus()

	var unlocked: Array = data.get("unlocked", [])
	if not unlocked.is_empty():
		vb.add_child(HSpacer.new(6))
		for id in unlocked:
			var a := Achievements.def_of(str(id))
			if a.is_empty():
				continue
			var arow := HBoxContainer.new()
			arow.add_theme_constant_override("separation", 10)
			var ic := AchievementIcon.new(str(a.icon), 34.0)
			ic.tint = G.C_GOLD
			arow.add_child(ic)
			var al := G.label("%s — %s" % [str(a.name), str(a.desc)], 17, G.C_GOLD)
			al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			arow.add_child(al)
			vb.add_child(arow)

	if data.get("new_best", false):
		var nb := G.label("★ NEW RECORD ★", 24, Color("ffd700"))
		nb.position = Vector2(0, 396)
		nb.size = Vector2(464, 30)
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(nb)
		var ft := create_tween().set_loops()
		ft.tween_property(nb, "modulate:a", 0.35, 0.45)
		ft.tween_property(nb, "modulate:a", 1.0, 0.45)

	# buttons
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	add_child(hb)
	G.anchor_corner(hb, false, true, 90, 46, Vector2(600, 54))
	buttons = hb
	# story mode: straight on to the next song
	if data.has("story_next_id"):
		var next_id: String = str(data["story_next_id"])
		hb.add_child(G.button("Continue story →", func():
			G.play_sfx("click")
			var songs := RhythmMap.load_songs()
			for s in songs:
				if str(s.get("id", "")) == next_id:
					G.selected_song = s
					var diffs := RhythmMap.diffs_of(s)
					G.selected_diff = clampi(int(data.get("story_diff", 1)),
						0, diffs.size() - 1)
					Conductor.stop_music()
					G.main.start_game()
					return
			G.main.goto_story()))
	hb.add_child(G.button("Retry", func():
		G.play_sfx("click")
		G.main.start_game()))
	if data.get("has_replay", false) and G.replay != null:
		var save_btn := G.button("Save replay", func(): pass)
		save_btn.pressed.connect(func():
			var path: String = G.replay.save()
			if path != "":
				Achievements.unlock("replay_saved")
			G.play_sfx("click", 1.3)
			save_btn.text = tr("Replay saved") if path != "" else tr("Save replay")
			save_btn.disabled = path != "")
		hb.add_child(save_btn)
	if G.return_screen == "editor":
		hb.add_child(G.button("← Back to editor", func():
			G.play_sfx("click")
			G.return_screen = ""
			G.main.open_editor(G.editor_song, G.editor_diff)))
	hb.add_child(G.button("Main menu", func():
		G.play_sfx("click")
		G.custom_test = {}
		Net.end_match()
		G.main.goto_menu()))
	if data.get("versus", false):
		hb.add_child(G.button("Back to versus", func():
			G.play_sfx("click")
			Net.end_match()
			G.main.goto_versus()))

	# confetti for S and SS
	if rank == "S" or rank == "SS":
		var p := CPUParticles2D.new()
		p.position = Vector2(G.canvas_size().x / 2.0, -20)
		p.amount = 90
		p.lifetime = 2.2
		p.emitting = true
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(G.canvas_size().x / 2.0, 8)
		p.direction = Vector2(0, 1)
		p.spread = 30.0
		p.gravity = Vector2(0, 320)
		p.initial_velocity_min = 40.0
		p.initial_velocity_max = 160.0
		p.angular_velocity_min = -300.0
		p.angular_velocity_max = 300.0
		p.scale_amount_min = 3.0
		p.scale_amount_max = 7.0
		p.texture = G.part_tex
		p.color_ramp = _confetti_ramp()
		add_child(p)

	if not Conductor.playing:
		var songs := RhythmMap.load_songs()
		if not songs.is_empty():
			var s0: Dictionary = songs[0]
			for s in songs:
				if str(s.get("id", "")) == "hyper_drive":
					s0 = s
					break
			Conductor.play_music(RhythmMap.audio_stream(s0),
				float(s0.get("preview_start", 0.0)), float(s0.get("bpm", 120.0)), -14.0)

	_fit_panel(panel)
	# re-layout when the window changes
	G.view_changed.connect(func():
		var vis := G.visible_rect_design()
		rig.position = Vector2(vis.end.x - rig.size.x, vis.end.y - rig.size.y)
		_fit_panel(panel)
		buttons.position.y = vis.end.y - buttons.size.y - 30.0)


func _on_opponent_done(_result: Dictionary) -> void:
	_update_versus()


## Their score, and the verdict once they have finished too.
func _update_versus() -> void:
	if _versus_row == null or not is_instance_valid(_versus_row):
		return
	var them := int(Net.opponent.get("score", 0))
	var done: bool = bool(Net.opponent.get("done", false))
	var value := _versus_row.get_child(1) as Label
	if value != null:
		value.text = G.fmt_score(them) if done else "%s…" % G.fmt_score(them)
	if not done:
		_versus_verdict.text = tr("Waiting for the other player…")
		_versus_verdict.add_theme_color_override("font_color", G.C_MUTED)
		return
	var mine := int(data.get("score", 0))
	if mine > them:
		_versus_verdict.text = tr("YOU WIN")
		_versus_verdict.add_theme_color_override("font_color", G.C_GOLD)
	elif mine < them:
		_versus_verdict.text = tr("YOU LOSE")
		_versus_verdict.add_theme_color_override("font_color", G.C_PRIMARY)
	else:
		_versus_verdict.text = tr("A DRAW")
		_versus_verdict.add_theme_color_override("font_color", G.C_TEXT)


func _confetti_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	return g


func _row(name: String, value: String, color: Color, size: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l := G.label(name, size - 6, G.C_MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	var v := G.label(value, size, color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(v)
	return hb


class HSpacer extends Control:
	var h := 10.0

	func _init(h_ := 10.0) -> void:
		h = h_
		custom_minimum_size = Vector2(0, h)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		return


## Esc, and the Android back button.
func go_back() -> void:
	G.custom_test = {}
	G.main.goto_menu()


## Sit the panel in the window rather than at a fixed height, stopping short of
## the buttons along the bottom. Anything that no longer fits is scrolled to
## rather than lost off the edge.
func _fit_panel(panel: PanelContainer) -> void:
	var vis := G.visible_rect_design()
	var top: float = vis.position.y + 96.0
	var bottom: float = vis.end.y - 104.0
	panel.size = Vector2(panel.size.x, maxf(200.0, bottom - top))
	panel.position = Vector2(vis.get_center().x - panel.size.x / 2.0 + 40.0, top)
