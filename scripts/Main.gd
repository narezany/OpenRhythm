extends Node
## Main - the screen state machine: menu -> select -> game -> results -> editor.

var current: Node = null


func _ready() -> void:
	G.main = self
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	get_viewport().size_changed.connect(_update_view)
	_update_view()
	match G.shot_mode:
		"select":
			goto_select("play")
		"game":
			var songs := RhythmMap.load_songs()
			if songs.is_empty():
				goto_menu()
				return
			var want := OS.get_environment("OR_SONG")
			G.selected_song = songs[0]
			for s in songs:
				if str(s.get("id", "")) == want:
					G.selected_song = s
			G.selected_diff = 0
			start_game()
		"results":
			_fake_results()
		"editor":
			var songs := RhythmMap.load_songs()
			if songs.is_empty():
				goto_menu()
				return
			open_editor(songs[0], 0)
		"settings":
			goto_settings()
		"songs":
			goto_songs()
		"calibration":
			goto_calibration()
		"stats":
			goto_stats()
		"disclaimer":
			goto_disclaimer()
		"story":
			goto_story()
		"credits":
			goto_credits()
		_:
			if not G.disclaimer_seen:
				goto_disclaimer()
			else:
				goto_menu()


func _fake_results() -> void:
	G.results = {
		"title": "Neon Drift", "artist": "Open Rhythm OST", "diff": "Hyper",
		"score": 234567, "acc": 0.9312, "max_combo": 187,
		"counts": {"PERFECT": 300, "GREAT": 98, "GOOD": 31, "BULLSHIT": 4, "MISS": 12},
		"rank": "S", "new_best": true, "mods": [], "unlocked": [],
	}
	show_results(G.results)


func switch_to(node: Node) -> void:
	if is_instance_valid(current):
		current.queue_free()
	current = node
	add_child(node)


## Android "back" behaves like Esc (pause / back), not like quitting the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var ev := InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = true
		Input.parse_input_event(ev)
		get_viewport().set_input_as_handled()


## Real visible window aspect, for the adaptive layout.
func _update_view() -> void:
	var sz := DisplayServer.window_get_size()
	if sz.x > 0 and sz.y > 0:
		G.view_w = float(sz.x)
		G.view_h = float(sz.y)
		G.view_changed.emit()


func goto_disclaimer() -> void:
	G.touch_zone = false
	switch_to(DisclaimerScreen.new())
	Conductor.ensure_menu_music()


func goto_menu() -> void:
	G.touch_zone = false
	G.replay_mode = false
	switch_to(MenuScreen.new())
	Conductor.ensure_menu_music()


func goto_songs() -> void:
	G.touch_zone = false
	switch_to(SongsScreen.new())
	Conductor.ensure_menu_music()


func goto_settings() -> void:
	G.touch_zone = false
	if not Conductor.playing:
		Conductor.ensure_menu_music()
	switch_to(SettingsScreen.new())


func goto_calibration() -> void:
	G.touch_zone = false
	switch_to(CalibrationScreen.new())


func goto_stats() -> void:
	G.touch_zone = false
	switch_to(StatsScreen.new())
	Conductor.ensure_menu_music()


func goto_select(mode := "play") -> void:
	G.touch_zone = false
	var s := SongSelectScreen.new()
	s.mode = mode
	switch_to(s)


## PLAY from the menu: free play (after the tutorial) or story mode.
func goto_play_menu() -> void:
	G.touch_zone = false
	switch_to(PlayChoiceScreen.new())
	Conductor.ensure_menu_music()


func goto_story() -> void:
	G.touch_zone = false
	switch_to(StoryScreen.new())
	Conductor.ensure_menu_music()


func goto_credits() -> void:
	G.touch_zone = false
	switch_to(CreditsScreen.new())
	Conductor.ensure_menu_music()


func start_game() -> void:
	Conductor.stop_music()
	G.touch_zone = true
	switch_to(GameScreen.new())


## Watch a saved replay: the cursor is driven by the recording.
func watch_replay(path: String) -> void:
	var r = Replay.load_file(path)
	if r == null:
		return
	var songs := RhythmMap.load_songs()
	var want := str(r.meta.get("song_id", ""))
	for s in songs:
		if str(s.get("id", "")) == want:
			G.selected_song = s
			var diffs := RhythmMap.diffs_of(s)
			var want_diff := str(r.meta.get("diff", ""))
			G.selected_diff = 0
			for i in diffs.size():
				if str(diffs[i].get("name", "")) == want_diff:
					G.selected_diff = i
			G.active_mods = r.meta.get("mods", []).duplicate()
			G.replay = r
			G.replay_mode = true
			start_game()
			return


func show_results(_res: Dictionary) -> void:
	G.touch_zone = false
	var s := ResultsScreen.new()
	s.data = _res
	switch_to(s)


func open_editor(song: Dictionary, diff_idx: int) -> void:
	Conductor.stop_music()
	G.touch_zone = true
	var e := EditorScreen.new()
	e.song = song
	e.diff_idx = diff_idx
	switch_to(e)
