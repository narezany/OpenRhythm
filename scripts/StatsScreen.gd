class_name StatsScreen
extends Control
## Profile: lifetime counters, per-song records, achievements and saved replays.

const TABS := ["Records", "Achievements", "Replays"]

var tab := 0
var _tab_buttons: Array = []
var _body: VBoxContainer


func _ready() -> void:
	G.anchor_full(self)   # fill the canvas: children anchor against this
	add_child(BackgroundFX.new(true))

	var title := G.label("STATS", 44, G.C_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	G.anchor_top_wide(title, 26, 56)

	var summary := G.label(_summary_text(), 17, G.C_MUTED)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(summary)
	G.anchor_top_wide(summary, 82, 24)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	add_child(tabs)
	G.anchor_top_wide(tabs, 112, 44)
	for i in TABS.size():
		var idx := i
		var b := G.button(TABS[i], func(): _switch(idx), 20)
		tabs.add_child(b)
		_tab_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	G.anchor_margins(scroll, 150, 166, 150, 84)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)

	var back := G.button("← Back", func():
		G.play_sfx("click")
		G.main.goto_menu(), 22)
	add_child(back)
	G.anchor_bottom_center(back, 18, Vector2(200, 46))

	_switch(0)


func _summary_text() -> String:
	var mins := int(G.stat_playtime) / 60
	return "%s: %d   •   %s: %s   •   %s: %d   •   %s: %d:%02d   •   %s: %s" % [
		tr("Songs played"), G.stat_plays,
		tr("Notes hit"), G.fmt_score(G.stat_notes),
		tr("Best combo"), G.stat_best_combo,
		tr("Play time"), mins / 60, mins % 60,
		tr("TOTAL SCORE"), G.fmt_score(G.total_score),
	]


func _switch(i: int) -> void:
	tab = i
	G.play_sfx("click", 1.2, -8.0)
	for j in _tab_buttons.size():
		var b: Button = _tab_buttons[j]
		b.add_theme_color_override("font_color", G.C_PRIMARY if j == i else G.C_MUTED)
	for c in _body.get_children():
		c.queue_free()
	match i:
		0: _build_records()
		1: _build_achievements()
		2: _build_replays()


func _build_records() -> void:
	var songs := RhythmMap.load_songs()
	var any := false
	for song in songs:
		var sid := str(song.get("id", ""))
		var diffs := RhythmMap.diffs_of(song)
		var rows: Array = []
		for d in diffs:
			var dn := str(d.get("name", "?"))
			var b := G.get_best(sid, dn)
			if not b.is_empty():
				rows.append([dn, b])
		if rows.is_empty():
			continue
		any = true
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", G.panel_style())
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		panel.add_child(vb)
		vb.add_child(G.label(str(song.get("title", "?")), 24, G.C_TEXT))
		for r in rows:
			var b: Dictionary = r[1]
			var line := "%s — %s   •   %.2f%%   •   x%d   •   %s" % [
				str(r[0]), G.fmt_score(int(b.get("score", 0))),
				float(b.get("acc", 0.0)) * 100.0, int(b.get("combo", 0)),
				Judge.rank_for(float(b.get("acc", 0.0)))]
			vb.add_child(G.label(line, 17, G.C_MUTED))
		_body.add_child(panel)
	if not any:
		_body.add_child(G.label("No records yet — go play something.", 20, G.C_MUTED))


func _build_achievements() -> void:
	for a in Achievements.LIST:
		var got: bool = Achievements.has(str(a.id))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", G.panel_style(
			Color(G.C_GOLD.r, G.C_GOLD.g, G.C_GOLD.b, 0.6) if got \
			else Color(1, 1, 1, 0.10)))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		panel.add_child(hb)
		var ic := AchievementIcon.new(str(a.icon), 46.0)
		ic.tint = G.C_GOLD
		ic.locked = not got
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 0)
		vb.add_child(G.label(str(a.name), 21, G.C_TEXT if got else G.C_MUTED))
		vb.add_child(G.label(str(a.desc), 16, G.C_MUTED))
		hb.add_child(vb)
		_body.add_child(panel)


func _build_replays() -> void:
	var list := Replay.list_all()
	if list.is_empty():
		_body.add_child(G.label("No saved replays yet.", 20, G.C_MUTED))
		return
	for m in list:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", G.panel_style())
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		panel.add_child(hb)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 0)
		vb.add_child(G.label("%s  [%s]" % [str(m.get("title", "?")), str(m.get("diff", ""))],
			22, G.C_TEXT))
		vb.add_child(G.label("%s   •   %s   •   %.2f%%   •   %s" % [
			str(m.get("date", "")), G.fmt_score(int(m.get("score", 0))),
			float(m.get("acc", 0.0)) * 100.0, str(m.get("rank", ""))], 16, G.C_MUTED))
		hb.add_child(vb)
		var path := str(m.get("path", ""))
		hb.add_child(G.button("Play", func():
			G.play_sfx("click")
			G.main.watch_replay(path), 18))
		hb.add_child(G.button("Delete", func():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			G.play_sfx("click", 0.7)
			_switch(2), 18))
		_body.add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		G.main.goto_menu()
