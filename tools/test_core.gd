extends Node
## Sanity checks for the save file, hold notes and the judge. Run with:
##   godot --headless --path . res://tools/CoreTest.tscn

var fails := 0


## Progress also goes to user://coretest.log, flushed line by line. Stdout is
## buffered when it is redirected, so a run that hangs loses everything it had
## printed - which is exactly when you need to know how far it got.
var _log: FileAccess = null


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	_say("%s  %s" % ["PASS" if cond else "FAIL", what])


func _say(line: String) -> void:
	print(line)
	if _log == null:
		_log = FileAccess.open("user://coretest.log", FileAccess.WRITE)
	if _log != null:
		_log.store_line("%6d ms  %s" % [Time.get_ticks_msec(), line])
		_log.flush()


func _ready() -> void:
	_test_project_settings()
	_test_settings_roundtrip()
	_test_hold_notes()
	_test_judge()
	_test_updater()
	_test_offset()
	_test_fork_audio()
	_test_beat()
	_test_editor_roundtrip()
	await _test_editor_scale()
	await _test_back_button()
	_test_touch_cursor()
	_test_mouse_cursor()
	_test_vr_room()
	_test_game_mode()
	_test_dialogue()
	_test_rounded()
	_test_charter()
	_test_coins()
	_test_events()
	_test_fonts()
	print("--- failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _test_settings_roundtrip() -> void:
	_say("== settings round-trip ==")
	G.master_vol = 0.42
	G.music_vol = 0.31
	G.sfx_vol = 0.77
	G.hitsound = false
	G.audio_offset = 0.083
	G.reduce_motion = true
	G.reduce_flashes = true
	G.max_fps = 144
	G.cursor_scale = 1.6
	G.gamepad_speed = 1234.0
	G.locale = "de"
	G.key_binds = {Binds.PAUSE: [KEY_P]}
	G.save_all()

	# wipe in memory, then reload from disk the way a fresh launch would
	G.master_vol = 0.0
	G.music_vol = 0.0
	G.sfx_vol = 0.0
	G.hitsound = true
	G.audio_offset = 0.0
	G.reduce_motion = false
	G.max_fps = 0
	G.locale = ""
	G.key_binds = {}
	G._load_save()

	ok(is_equal_approx(G.master_vol, 0.42), "master volume survives a restart")
	ok(is_equal_approx(G.music_vol, 0.31), "music volume survives a restart")
	ok(is_equal_approx(G.sfx_vol, 0.77), "sfx volume survives a restart")
	ok(G.hitsound == false, "hitsound toggle survives")
	ok(is_equal_approx(G.audio_offset, 0.083), "audio offset survives")
	ok(G.reduce_motion and G.reduce_flashes, "accessibility toggles survive")
	ok(G.max_fps == 144, "fps limit survives")
	ok(is_equal_approx(G.cursor_scale, 1.6), "cursor size survives")
	ok(is_equal_approx(G.gamepad_speed, 1234.0), "gamepad speed survives")
	ok(G.locale == "de", "language survives")
	ok(G.key_binds.get(Binds.PAUSE, []) == [KEY_P], "key binds survive")
	# the buses must actually be at the reloaded level, not the default
	var db := AudioServer.get_bus_volume_db(0)
	ok(absf(db - linear_to_db(0.42)) < 0.01, "master bus applied after load")


func _test_hold_notes() -> void:
	_say("== hold notes ==")
	var song := RhythmMap.create_new_song("Hold Test")
	var notes := [
		{"t": 1.0, "cell": 4, "s": 1.0},
		{"t": 2.0, "cell": 0, "s": 1.0, "h": 0.75},
		{"t": 3.5, "cell": 8, "s": 1.25, "h": 2.0},
	]
	RhythmMap.save_custom(song, notes)
	var back: Array = RhythmMap.diffs_of(song)[0].get("notes", [])
	ok(back.size() == 3, "all notes written and read back")
	ok(absf(float(back[1].get("h", 0.0)) - 0.75) < 0.001, "hold length survives a save")
	ok(absf(float(back[2].get("h", 0.0)) - 2.0) < 0.001, "long hold survives a save")
	ok(float(back[0].get("h", 0.0)) == 0.0, "plain note stays plain")

	# click notes survive a round-trip too
	RhythmMap.save_custom(song, [
		{"t": 1.0, "cell": 4, "s": 1.0},
		{"t": 2.0, "cell": 2, "s": 1.0, "c": true},
	])
	var back2: Array = RhythmMap.diffs_of(song)[0].get("notes", [])
	ok(bool(back2[1].get("c", false)), "click flag survives a save")
	ok(not bool(back2[0].get("c", false)), "plain note is not a click note")
	RhythmMap.delete_song(song)
	ok(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(str(song.dir))),
		"delete_song removes the folder it was given")

	# editing a built-in song has to fork it: res:// cannot be written to
	var built_in: Dictionary = {}
	for s3 in RhythmMap.load_songs():
		if not RhythmMap.is_user_song(s3):
			built_in = s3
			break
	if built_in.is_empty():
		ok(true, "no built-in song to fork from (running outside the export)")
	else:
		var fork := RhythmMap.fork_song(built_in)
		ok(not fork.is_empty() and RhythmMap.is_user_song(fork),
			"fork_song puts a built-in song into the library")
		ok(FileAccess.file_exists(str(fork.dir) + "/" + str(fork.audio)),
			"the forked copy carries its audio")
		ok(RhythmMap.diffs_of(fork).size() == RhythmMap.diffs_of(built_in).size(),
			"the forked copy keeps every difficulty")
		RhythmMap.save_custom(fork, [{"t": 5.0, "cell": 1, "s": 1.0}], 0)
		ok(RhythmMap.diffs_of(fork)[0].get("notes", []).size() == 1,
			"save_custom writes into the difficulty it was given")
		RhythmMap.delete_song(fork)


func _test_judge() -> void:
	_say("== judge ==")
	ok(Judge.label_for(0.0, 0.9) == "PERFECT", "centre hit is PERFECT")
	ok(Judge.label_for(0.0, 0.05) == "BULLSHIT", "edge hit is BULLSHIT")
	ok(Judge.hold_acc(1.0, 1.0) > Judge.hold_acc(1.0, 0.2), "a fully held note beats a dropped one")
	ok(Judge.degrade("PERFECT", 1.0) == "PERFECT", "a clean hold keeps its rank")
	ok(Judge.degrade("PERFECT", 0.3) == "GOOD", "a badly dropped hold loses two steps")
	ok(Judge.HOLD_MIN > 0.5 and Judge.HOLD_GRACE < 0.3,
		"a hold has to be carried nearly to the end to count")
	ok(Judge.holding(Vector2(10, 0), Vector2.ZERO, 52.0), "cursor near the cell holds")
	ok(not Judge.holding(Vector2(400, 0), Vector2.ZERO, 52.0), "cursor far away drops the hold")
	ok(G.mirror_cell(0) == 2 and G.mirror_cell(3) == 5 and G.mirror_cell(8) == 6,
		"MIRROR flips cells horizontally")
	ok(is_equal_approx(G.mod_rate(["speed"]), 1.4) and is_equal_approx(G.mod_rate([]), 1.0),
		"speed modifier sets the playback rate")
	ok(G.mod_mult(["clicky"]) > 1.3, "CLICKY pays a bonus")

	# every shipped chart must keep the cursor free while a hold runs
	var overlaps := 0
	var holds_seen := 0
	var clicks_seen := 0
	for s2 in RhythmMap.load_songs():
		for d in RhythmMap.diffs_of(s2):
			var ns: Array = d.get("notes", [])
			for i in ns.size():
				var h := float(ns[i].get("h", 0.0))
				if bool(ns[i].get("c", false)):
					clicks_seen += 1
				if h <= 0.0:
					continue
				holds_seen += 1
				var end: float = float(ns[i].t) + h
				for j in range(i + 1, ns.size()):
					if float(ns[j].t) >= end:
						break
					overlaps += 1
	ok(overlaps == 0, "nothing flies while a hold runs (%d holds checked)" % holds_seen)

	# two cubes at once is a note the player cannot take - there is one cursor
	var tightest := 99.0
	var tight_where := ""
	for s4 in RhythmMap.load_songs():
		for d in RhythmMap.diffs_of(s4):
			var ns: Array = d.get("notes", [])
			for i in range(1, ns.size()):
				var gap: float = float(ns[i].t) - float(ns[i - 1].t)
				if gap < tightest:
					tightest = gap
					tight_where = "%s/%s" % [str(s4.get("id", "")), str(d.get("name", ""))]
	ok(tightest >= 0.14, "no chart stacks notes on one cursor (tightest %.3f s in %s)"
		% [tightest, tight_where])
	ok(holds_seen > 0 and clicks_seen > 0,
		"shipped charts contain holds (%d) and click notes (%d)" % [holds_seen, clicks_seen])


func _test_updater() -> void:
	_say("== updater ==")
	ok(Updater.compare("0.3.1", "0.3.0") > 0, "a newer patch is newer")
	ok(Updater.compare("v0.4.0", "0.3.9") > 0, "a leading v is ignored")
	ok(Updater.compare("1.0.0", "0.9.9") > 0, "a major bump is newer")
	ok(Updater.compare("0.3.0", "0.3.0") == 0, "the same version is not an update")
	ok(Updater.compare("0.2.9", "0.3.0") < 0, "an older release is not offered")
	ok(Updater.compare("0.3", "0.3.0") == 0, "a missing patch counts as zero")
	# Two parts or three, and every part a number. Not three exactly: 0.4 is a
	# version somebody would write, and Updater.compare already treats a
	# missing patch as zero - so the rule is that it can be compared, which is
	# the only thing the version is for.
	var parts := G.VERSION.split(".")
	var numeric := parts.size() == 2 or parts.size() == 3
	for part in parts:
		if not part.is_valid_int():
			numeric = false
	ok(numeric, "the game version can be compared (%s)" % G.VERSION)
	ok(Updater.compare(G.VERSION, "0.3.2") > 0,
		"and is newer than the last release")
	# a release carries three .apk files now; a phone must not be offered a
	# headset build just because it also ends in .apk
	var up := Updater.new()
	add_child(up)
	var names := ["OpenRhythm-v0.3.1-quest.apk", "OpenRhythm-v0.3.1-android.apk",
		"OpenRhythm-v0.3.1-pico.apk", "OpenRhythm-v0.3.1-linux.zip"]
	var assets: Array = []
	for n in names:
		assets.append({"name": n, "browser_download_url": "https://x/" + n})
	up._pick_asset({"tag_name": "v9.9.9", "assets": assets}, "android")
	ok(up.asset_name == "OpenRhythm-v0.3.1-android.apk",
		"the phone is offered the phone package (%s)" % up.asset_name)
	up._pick_asset({"tag_name": "v9.9.9", "assets": assets}, "linux")
	ok(up.asset_name == "OpenRhythm-v0.3.1-linux.zip",
		"and the desktop its own archive (%s)" % up.asset_name)
	up._pick_asset({"tag_name": "v9.9.9", "assets": assets}, "quest")
	ok(up.asset_name == "OpenRhythm-v0.3.1-quest.apk",
		"a headset is offered its own build, not the phone one (%s)" % up.asset_name)
	up._pick_asset({"tag_name": "v9.9.9", "assets": assets}, "pico")
	ok(up.asset_name == "OpenRhythm-v0.3.1-pico.apk",
		"and so is the other one (%s)" % up.asset_name)
	up.free()


func _test_offset() -> void:
	_say("== conductor offset ==")
	# Informational: how far behind the audio device is on this machine. Every
	# hitsound is handed over that early, so if this is large and the sound
	# still lands late, the compensation is not being applied.
	print("      output latency here: %.1f ms" % (AudioServer.get_output_latency() * 1000.0))
	G.audio_offset = 0.0
	Conductor.song_time = 10.0
	ok(is_equal_approx(Conductor.play_time(), 10.0), "no offset means play time is song time")
	G.audio_offset = 0.05
	ok(is_equal_approx(Conductor.play_time(), 9.95), "a positive offset judges notes later")
	G.audio_offset = 0.0


## The Android back button. It has to behave like Esc, and - this is the part
## that kept crashing - it must not swap screens while the engine is still
## delivering the notification, because that frees the node being processed.
func _test_back_button() -> void:
	_say("== android back button ==")
	var screens := {
		"SongSelectScreen": true, "GameScreen": true, "EditorScreen": true,
		"SettingsScreen": true, "SongsScreen": true, "StatsScreen": true,
		"StoryScreen": true, "CreditsScreen": true, "ResultsScreen": true,
		"VersusScreen": true, "CalibrationScreen": true, "PlayChoiceScreen": true,
	}
	var missing: Array[String] = []
	for name_ in screens:
		var src: GDScript = load("res://scripts/%s.gd" % name_)
		var has := false
		for m in src.get_script_method_list():
			if str(m.get("name", "")) == "go_back":
				has = true
		if not has:
			missing.append(name_)
	ok(missing.is_empty(), "every screen answers the back button (%s)"
		% ("all " + str(screens.size()) if missing.is_empty() else str(missing)))

	G.shot_mode = ""
	var main: Node = load("res://scripts/Main.gd").new()
	add_child(main)
	await get_tree().process_frame
	ok(main.current is MenuScreen, "the game starts on the menu")

	main.goto_settings()
	await get_tree().process_frame
	ok(main.current is SettingsScreen, "settings opened")
	main.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	ok(main.current is SettingsScreen,
		"back does not tear the screen down inside the notification")
	await get_tree().process_frame
	await get_tree().process_frame
	ok(is_instance_valid(main) and main.current is MenuScreen,
		"a frame later back has returned to the menu")

	# a repeat of the same press is swallowed rather than acted on twice
	main._back_at = Time.get_ticks_msec()
	main.goto_songs()
	await get_tree().process_frame
	main.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(main.current is SongsScreen, "a second press within a moment is ignored")

	# and again, from a screen that has a panel to close first
	main._back_at = -100000
	main.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(is_instance_valid(main) and main.current is MenuScreen, "back works from the song list")

	# the menu is the end of the line: back does nothing and never closes the game
	main._back_at = -100000
	main.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(is_instance_valid(main) and main.current is MenuScreen,
		"back on the menu leaves the game alone")
	main.free()


## One finger steers, the rest are taps. Two fingers used to fight over the
## cursor; now the second one is free to hit a click note where the first is.
func _test_touch_cursor() -> void:
	_say("== touch cursor ==")
	G.view_w = 1280.0
	G.view_h = 720.0
	G.mouse_sens = 1.0
	var c := UICursor
	c._fingers.clear()
	c._cursor_finger = -1
	c._touch_input(_touch(0, true, Vector2(300, 300)))
	ok(c.pos.is_equal_approx(Vector2(300, 300)), "the first finger takes the cursor")
	c._touch_input(_drag(0, Vector2(340, 300)))
	ok(c.pos.is_equal_approx(Vector2(340, 300)), "and moves it")
	c._touch_input(_touch(1, true, Vector2(900, 620)))
	ok(c.pos.is_equal_approx(Vector2(340, 300)), "a second finger does not snatch the cursor")
	c._touch_input(_drag(1, Vector2(950, 650)))
	ok(c.pos.is_equal_approx(Vector2(340, 300)), "nor drag it around")
	c._touch_input(_touch(1, false, Vector2(950, 650)))
	ok(c.pos.is_equal_approx(Vector2(340, 300)) and c._cursor_finger == 0,
		"lifting it leaves the first finger in charge")
	c._touch_input(_touch(1, true, Vector2(200, 200)))
	c._touch_input(_touch(0, false, Vector2(340, 300)))
	ok(c._cursor_finger == 1, "lifting the steering finger hands over to the one still down")
	c._touch_input(_drag(1, Vector2(210, 200)))
	ok(c.pos.is_equal_approx(Vector2(350, 300)),
		"the new steering finger carries on from where the cursor was")
	c._touch_input(_touch(1, false, Vector2(210, 200)))
	ok(c._fingers.is_empty() and c._cursor_finger == -1, "letting go clears every finger")


func _touch(idx: int, pressed: bool, at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = pressed
	e.position = at
	return e


func _drag(idx: int, at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = at
	return e


## Forking a built-in song. The copy may not carry the audio file itself - in an
## exported build the original is packed as an imported resource - but it still
## has music, and the editor must not tell the player otherwise.
func _test_fork_audio() -> void:
	_say("== forked songs keep their music ==")
	var songs := RhythmMap.load_songs()
	var src := {}
	for s in songs:
		if str(s.get("dir", "")).begins_with("res://") and RhythmMap.has_audio(s):
			src = s
			break
	if src.is_empty():
		ok(false, "a built-in song with audio was found to fork")
		return
	var fork := RhythmMap.fork_song(src, "Fork Test")
	ok(not fork.is_empty(), "the fork was created")
	ok(RhythmMap.has_audio(fork), "the fork reports that it has audio")
	ok(RhythmMap.audio_path(fork) != "", "and a path to play it from")
	ok(RhythmMap.audio_stream(fork) != null, "which really does load as a stream")
	# and it survives a save/load round trip, which is what the editor does
	RhythmMap.write_map(fork)
	var reloaded: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(str(fork["dir"]) + "/map.json"))
	if reloaded is Dictionary:
		reloaded["dir"] = fork["dir"]
		ok(RhythmMap.has_audio(reloaded), "and after being saved and read back")
	else:
		ok(false, "the forked map.json reads back")
	# the exported-build shape: no file of its own, only a reference back to the
	# packed original. This is the case that showed the "no audio" banner.
	var packed := fork.duplicate()
	packed["audio_ref"] = str(src["dir"]) + "/" + str(src.get("audio", ""))
	packed["audio"] = ""
	ok(RhythmMap.has_audio(packed), "a fork that only references its original still has audio")
	ok(RhythmMap.audio_stream(packed) != null, "and that reference still plays")
	_wipe(str(fork["dir"]))


## Remove a folder the test made under user://.
func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir():
			d.remove(f)
		f = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(dir)


## The beat analyser the editor's auto button uses.
##
## Everything it produces rests on its timing being right, so the timing is
## measured against a click track at times we already know rather than assumed.
func _test_beat() -> void:
	_say("== beat analysis ==")
	var bpm := 128.0
	var dur := 24.0
	var sr := 22050
	var truth: Array[float] = []
	var t := 0.0
	while t < dur - 0.5:
		truth.append(t)
		t += 60.0 / bpm / 2.0
	var n := int(dur * sr)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in truth.size():
		var at := int(truth[i] * sr)
		var loud := 0.8 if i % 2 == 0 else 0.36
		for j in int(0.02 * sr):
			if at + j >= n:
				break
			var shape: float = exp(-float(j) / (0.004 * sr))
			var tone: float = sin(TAU * 180.0 * float(j) / sr) + 0.6 * rng.randfn(0.0, 1.0)
			buf[at + j] += shape * tone * loud
	for i in n:
		var v := int(clampf(buf[i] * 0.5, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.data = pcm

	var b := Beat.of_stream(wav, 0.0)
	ok(b.ok, "the analyser read the stream")
	if not b.ok:
		return
	var ons := b.onsets()
	var d: Array[float] = []
	for o in ons:
		var near: float = truth[0]
		for x in truth:
			if absf(x - o) < absf(near - o):
				near = x
		d.append(o - near)
	d.sort()
	var bias: float = d[d.size() / 2] if d.size() > 0 else 99.0
	print("      onsets %d for %d clicks, bias %+.1f ms" % [ons.size(), truth.size(), bias * 1000.0])
	ok(absf(bias) < 0.008, "attacks are found within 8 ms of the sound (%+.1f ms)" % (bias * 1000.0))
	ok(absf(b.bpm - bpm) < 0.5, "the tempo is measured, not guessed (%.2f BPM)" % b.bpm)
	var period := 60.0 / bpm
	var phase: float = fposmod(b.first + period * 0.5, period) - period * 0.5
	ok(absf(phase) < 0.015, "the first beat is where it really is (%+.1f ms)" % (phase * 1000.0))

	# and the chart it builds has to be rhythmically regular: every gap a whole
	# number of the subdivision the bar was charted at
	b.length = dur
	var picked := b.select(2)
	ok(picked.size() > 20, "it picked enough notes to chart (%d)" % picked.size())
	var notes := Charter.build(picked, 2, 60.0 / b.bpm, "selftest")
	var sixteenth := 60.0 / b.bpm / 4.0
	var odd := 0
	for i in range(1, notes.size()):
		var gap: float = float(notes[i]["t"]) - float(notes[i - 1]["t"])
		var q: float = gap / sixteenth
		if absf(q - roundf(q)) > 0.12 or int(roundf(q)) % 2 != 0:
			odd += 1
	ok(odd == 0, "every gap is a whole eighth (%d notes, %d odd)" % [notes.size(), odd])


## Saving from the editor, and forking a song to edit it.
##
## Both of these lose work when they go wrong, and the way they went wrong was
## quiet: a fork carried all three difficulties, so the copy was saved into
## whichever index was being edited while the editor reopened it at another,
## and the notes - click markers and all - looked like they had never been
## saved.
func _test_editor_roundtrip() -> void:
	_say("== editor save and fork ==")
	var song := RhythmMap.create_new_song("Roundtrip Test")
	song["difficulties"] = [
		{"name": "Easy", "notes": []},
		{"name": "Normal", "notes": []},
		{"name": "Hyper", "notes": []},
	]
	var notes := [
		{"t": 1.0, "cell": 4, "s": 1.0},
		{"t": 2.0, "cell": 1, "s": 1.0, "c": true},
		{"t": 3.0, "cell": 7, "s": 1.0, "h": 0.5, "c": true},
	]
	RhythmMap.save_custom(song, notes, 1)
	var back := {}
	for x in RhythmMap.load_songs():
		if str(x.get("id", "")) == str(song.get("id", "")):
			back = x
	ok(not back.is_empty(), "the saved song is in the library")
	if back.is_empty():
		return
	var diffs := RhythmMap.diffs_of(back)
	ok(diffs.size() == 3, "it still has its three difficulties")
	var got: Array = diffs[1].get("notes", [])
	ok(got.size() == 3, "the notes landed in the difficulty that was edited")
	var clicks := 0
	var holds := 0
	for n in got:
		if bool(n.get("c", false)):
			clicks += 1
		if float(n.get("h", 0.0)) > 0.0:
			holds += 1
	ok(clicks == 2, "click notes survived the save (%d of 2)" % clicks)
	ok(holds == 1, "so did the hold")

	var fork := RhythmMap.fork_song(back, "Roundtrip Fork", 1)
	var fdiffs: Array = fork.get("difficulties", [])
	ok(fdiffs.size() == 1, "forking one difficulty copies one, not all three (%d)"
		% fdiffs.size())
	if fdiffs.size() == 1:
		ok(str(fdiffs[0].get("name", "")) == "Normal",
			"and it is the one that was picked")
		var fclicks := 0
		for n in fdiffs[0].get("notes", []):
			if bool(n.get("c", false)):
				fclicks += 1
		ok(fclicks == 2, "the copy kept its click notes")
	_wipe(str(song["dir"]))
	_wipe(str(fork.get("dir", "")))


## The drawn cursor must never end up somewhere the system pointer is not.
##
## It used to add movements together, so one clamped or dropped event left a
## gap that stayed for the rest of the session: players saw the cursor drift
## off to one side while their clicks landed somewhere else entirely, and only
## alt-tabbing put it back.
func _test_mouse_cursor() -> void:
	_say("== mouse cursor ==")
	G.mouse_sens = 1.0
	var c := UICursor
	c._fingers.clear()
	c._cursor_finger = -1
	c._os_expected = Vector2.INF
	var rect := c._visible_rect()
	ok(rect.size.x > 16.0 and rect.size.y > 16.0,
		"the visible area is real (%.0fx%.0f)" % [rect.size.x, rect.size.y])

	c._input(_motion(Vector2(400, 300)))
	ok(c.pos.is_equal_approx(Vector2(400, 300)), "the cursor sits on the pointer")
	# shove it far outside, the way a pointer at the edge of the screen does
	c._input(_motion(rect.end + Vector2(500, 500)))
	c._input(_motion(Vector2(640, 360)))
	ok(c.pos.is_equal_approx(Vector2(640, 360)),
		"and finds its way back after being pushed past the edge")
	var drift := 0.0
	for i in 40:
		var p := Vector2(200.0 + float(i) * 11.0, 240.0 + float(i % 7) * 9.0)
		c._input(_motion(p))
		drift = maxf(drift, c.pos.distance_to(p))
	ok(drift < 0.01, "and never drifts away from it (worst %.2f px)" % drift)


func _motion(at: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	return e


## A long, dense chart has to stay editable.
##
## Select-all and delete used to hang the game outright: every note removed
## re-sorted the chart and rebuilt every view, comparing each note against
## every node on screen. On a seventeen-minute track that is billions of
## comparisons and the editor never came back.
func _test_editor_scale() -> void:
	_say("== editor on a long chart ==")
	var song := RhythmMap.create_new_song("Scale Test")
	var big: Array = []
	var t := 1.0
	while t < 17.0 * 60.0:
		big.append({"t": snappedf(t, 0.001), "cell": int(t * 7.0) % 9, "s": 1.0})
		t += 0.25
	RhythmMap.save_custom(song, big, 0)
	var loaded := {}
	for x in RhythmMap.load_songs():
		if str(x.get("id", "")) == str(song.get("id", "")):
			loaded = x
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	main.open_editor(loaded, 0)
	await get_tree().process_frame
	var ed = main.current
	var open_ms := Time.get_ticks_msec() - t0
	ok(ed.notes.size() == big.size(),
		"a %d note chart opens (%d ms)" % [ed.notes.size(), open_ms])
	ok(open_ms < 6000, "and opening it does not take all day (%d ms)" % open_ms)
	ed.cur_time = 300.0
	ed.notes_changed()
	var live: int = ed.notes_root.get_child_count()
	ok(live > 0 and live < 200,
		"the notes around the playhead have a node, and only those (%d)" % live)
	ed.cur_time = 900.0
	ed.notes_changed()
	ok(ed.notes_root.get_child_count() > 0,
		"and they follow the playhead down the track")

	ed.timeline.selection = ed.notes.duplicate()
	t0 = Time.get_ticks_msec()
	ed._delete_selection()
	var del_ms := Time.get_ticks_msec() - t0
	ok(ed.notes.is_empty(), "select all and delete clears the chart")
	ok(del_ms < 2000, "and finishes rather than hanging (%d ms)" % del_ms)
	main.free()
	_wipe(str(song["dir"]))


## The project settings the game actually depends on, checked to be in force.
##
## A comment line in project.godot is folded into the name of the key below it,
## so the key silently disappears and its default takes over. That is not a
## hypothetical: it switched off VR, switched off the engine's log file, and
## turned the Android back button back into "quit the app", and each one looked
## like a separate bug somewhere else. Nothing warns you, so this does.
func _test_project_settings() -> void:
	_say("== project settings ==")
	for name in ["application/config/quit_on_go_back", "xr/openxr/enabled",
			"xr/openxr/startup_alert", "xr/shaders/enabled",
			"debug/file_logging/enable_file_logging",
			"rendering/renderer/rendering_method",
			"rendering/renderer/rendering_method.mobile",
			"input_devices/pointing/emulate_mouse_from_touch"]:
		ok(ProjectSettings.has_setting(name), "%s survived into the project" % name)
	ok(ProjectSettings.get_setting_with_override("application/config/quit_on_go_back") == false,
		"back does not close the game by itself")
	ok(bool(ProjectSettings.get_setting_with_override("xr/openxr/enabled")),
		"OpenXR is on, so a headset can be found at startup")
	# and no key carries a comment inside its name
	var mangled: Array[String] = []
	for prop in ProjectSettings.get_property_list():
		var n := str(prop.get("name", ""))
		if n.contains("#"):
			mangled.append(n.substr(0, 40))
	ok(mangled.is_empty(), "no setting name has a comment folded into it (%s)"
		% ("none" if mangled.is_empty() else str(mangled)))


## The VR room, as far as it can be checked without a headset: the cubes are
## the shape the flat game draws, and they are given long enough to be seen
## coming.
func _test_vr_room() -> void:
	_say("== vr room ==")
	var stage := VRStage.new()

	# Rounded, and rounded by the same fraction the flat cards use. A sharp
	# unit cube reaches sqrt(3)/2 from its middle; a rounded one cannot.
	var mesh: ArrayMesh = stage._rounded_box(VRStage.CUBE_ROUND, 5)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	ok(verts.size() >= 6 * 5 * 5 * 6, "the cube mesh is built (%d vertices)" % verts.size())
	var far := 0.0
	var out := 0.0
	for v in verts:
		far = maxf(far, v.length())
		out = maxf(out, maxf(absf(v.x), maxf(absf(v.y), absf(v.z))))
	var inner: float = 0.5 - VRStage.CUBE_ROUND
	var corner: float = inner * sqrt(3.0) + VRStage.CUBE_ROUND
	ok(absf(far - corner) < 0.01,
		"its corners are rounded off, not square (%.3f, square would be %.3f)"
		% [far, sqrt(3.0) * 0.5])
	ok(out <= 0.5 + 0.001,
		"and it still fits the cube it replaces, so nothing changes size")

	# Wound the same way round as the engine's own box. The black outline is
	# the cube drawn again, bigger and inside out, and inside out is only a
	# thing you can ask for if the faces face the way the renderer expects.
	ok(signf(_signed_volume(mesh)) == signf(_signed_volume(BoxMesh.new())),
		"and is wound the way the engine winds its own box (%.3f against %.3f)"
		% [_signed_volume(mesh), _signed_volume(BoxMesh.new())])

	# A blade against a cube, in the cube's own space.
	ok(stage._seg_box(Vector3(-2, 0, 0), Vector3(2, 0, 0)), "a sweep straight through cuts")
	ok(stage._seg_box(Vector3(0, 0, 0), Vector3(0, 0, 0.2)), "so does one that starts inside")
	ok(not stage._seg_box(Vector3(-2, 2, 0), Vector3(2, 2, 0)), "one passing over the top does not")
	ok(not stage._seg_box(Vector3(-2, 0, 0), Vector3(-0.9, 0, 0)), "nor one that stops short")
	ok(stage._seg_box(Vector3(-1, -1, -1), Vector3(1, 1, 1)), "a diagonal sweep cuts")
	ok(not stage._seg_box(Vector3(-2, 0.6, 0), Vector3(2, 0.6, 0)), "a near miss is a miss")
	ok(stage._seg_box(Vector3(-2, 0.6, 0), Vector3(2, 0.6, 0), Vector3.ONE * 0.15),
		"and lands once the cube is given its slack")

	# Long enough to see coming. The flat game's one second is a few hundred
	# pixels; here it is seven metres, and at 7 m/s a cube is a speck and then
	# it is on you.
	ok(VRStage.VR_APPROACH > GameScreen.APPROACH,
		"a cube is visible longer in VR than flat (%.1fs against %.1fs)"
		% [VRStage.VR_APPROACH, GameScreen.APPROACH])
	var speed: float = VRStage.FLIGHT / VRStage.VR_APPROACH
	ok(speed < 5.0, "so it flies at a speed you can read (%.1f m/s)" % speed)

	# And it grows into place rather than appearing at full size.
	ok(stage._grow(0.0) < 0.35, "a cube starts its run small (%.2f)" % stage._grow(0.0))
	ok(absf(stage._grow(VRStage.BIRTH) - 1.0) < 0.001, "and is full size once it is out")
	ok(absf(stage._grow(1.0) - 1.0) < 0.001, "and stays that way all the way in")
	var last := -1.0
	var climbs := true
	for i in 20:
		var g: float = stage._grow(float(i) / 19.0 * VRStage.BIRTH)
		climbs = climbs and g >= last
		last = g
	ok(climbs, "and never shrinks on the way")

	# A cut is graded on when, not where. These numbers are the whole feel of
	# saber play, so they are pinned rather than left to drift.
	ok(absf(Judge.time_acc(0.0) - 1.0) < 0.001, "a cut on the beat is dead centre")
	ok(Judge.label_for(0.0, Judge.time_acc(0.0)) == "PERFECT", "and reads PERFECT")
	ok(Judge.label_for(0.03, Judge.time_acc(0.03)) == "PERFECT", "30 ms out is still PERFECT")
	ok(Judge.label_for(-0.03, Judge.time_acc(-0.03)) == "PERFECT", "early or late alike")
	ok(Judge.label_for(0.08, Judge.time_acc(0.08)) == "GREAT", "80 ms out is GREAT")
	ok(Judge.label_for(0.10, Judge.time_acc(0.10)) == "GOOD", "100 ms out is GOOD")
	ok(Judge.label_for(0.20, Judge.time_acc(0.20)) == "BULLSHIT", "200 ms out barely counts")
	ok(VRStage.CUT_WINDOW > Judge.T_ZONE,
		"and a cube can be reached a little before it can be graded well")

	# Saber play has no long notes: they open out into a run of ordinary ones.
	var gs := GameScreen.new()
	gs.notes = [
		{"t": 1.0, "h": 0.0, "click": false},
		{"t": 2.0, "h": 0.64, "click": false},
		{"t": 4.0, "h": 0.5, "click": true},
	]
	var was_active := G.vr_active
	var was_mode := G.game_mode
	G.vr_active = true
	G.game_mode = "saber"
	gs._saber_chart()
	G.vr_active = was_active
	G.game_mode = was_mode
	var holds := 0
	var in_order := true
	for i in gs.notes.size():
		if float(gs.notes[i].get("h", 0.0)) > 0.0 and not bool(gs.notes[i].get("click", false)):
			holds += 1
		if i > 0 and float(gs.notes[i].t) < float(gs.notes[i - 1].t):
			in_order = false
	ok(gs.notes.size() == 7, "a 0.64s hold becomes a run of cubes (%d notes now)" % gs.notes.size())
	ok(holds == 0, "and no plain hold is left to park a blade in")
	ok(in_order, "and the chart is still in time order")
	ok(float(gs.notes[-1].h) > 0.0 and bool(gs.notes[-1].click),
		"a click note keeps its hold - those have their own answer in VR")
	gs.free()

	# Melly can be picked up, and wherever they are let go of they end on the
	# floor - there is nothing to stand them on in mid-air.
	ok(VRStage.GRAB_REACH > 0.0 and VRStage.DROP_GRAV > 0.0, "they can be picked up")
	var rig := MellyRig.new()
	rig.limp = true
	rig.arm_l = 2.0
	for _i in 240:
		rig._sim(1.0 / 90.0)
	ok(rig.arm_l < 0.0, "a limp arm hangs (%.2f rad)" % rig.arm_l)
	var before := rig.arm_l
	rig.shake(3.0)
	ok(absf(rig.arm_lv) > 0.0 and rig.arm_l == before,
		"and shaking them moves the joints rather than teleporting them")
	rig.free()


	# The room is placed under the player's eyes, not at a fixed height.
	ok(VRStage.PANEL_DROP > 0.0 and VRStage.EYE_ASSUMED - VRStage.PANEL_DROP < 1.5,
		"the screen hangs below eye level rather than above it")
	stage.free()


## Six times the volume a triangle soup encloses. Positive or negative says
## which way its faces are wound; the number itself is only used for the log.
func _signed_volume(mesh: Mesh) -> float:
	var arr: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null \
		else PackedInt32Array()
	var total := 0.0
	var count: int = idx.size() if idx.size() > 0 else v.size()
	var i := 0
	while i + 2 < count:
		var a: Vector3 = v[idx[i]] if idx.size() > 0 else v[i]
		var b: Vector3 = v[idx[i + 1]] if idx.size() > 0 else v[i + 1]
		var c: Vector3 = v[idx[i + 2]] if idx.size() > 0 else v[i + 2]
		total += a.dot(b.cross(c))
		i += 3
	return total


## The shipped fonts have to be able to draw the languages the game is
## translated into, without borrowing anything from the machine it is running
## on. A browser has nothing to lend, and the whole Russian translation came
## out of the web build as boxes with hex codes in them.
func _test_fonts() -> void:
	_say("== winning and losing ==")
	# Losing belongs to story mode and to the health bar. Free play cannot be
	# failed at all - a bad run there is a bad score, which is what practising
	# looks like - so no letter rank is a loss, however poor.
	ok(Judge.failed(Judge.DEAD), "only the health bar running out is a loss")
	for a in [0.0, 0.2, 0.55, 0.62, 0.99]:
		ok(not Judge.failed(Judge.rank_for(a)),
			"a %.0f%% run is a score, not a failure" % (a * 100.0))
	ok(Judge.rank_color(Judge.DEAD) != Judge.rank_color("C"),
		"and it is not painted like a rank")

	# The misses a story allows before the bar is empty, by difficulty.
	var gs2 := GameScreen.new()
	gs2._set_miss_budget(0, 1)
	var only := 1.0 / gs2._miss_cost
	gs2._set_miss_budget(0, 5)
	var easiest := 1.0 / gs2._miss_cost
	gs2._set_miss_budget(4, 5)
	var hardest := 1.0 / gs2._miss_cost
	gs2.free()
	ok(absf(hardest - GameScreen.MISS_BUDGET_HARD) < 0.01,
		"the hardest difficulty allows %.0f misses in a row" % hardest)
	ok(absf(easiest - GameScreen.MISS_BUDGET_EASY) < 0.01,
		"the easiest allows %.0f" % easiest)
	ok(only == easiest, "a song with one difficulty is treated as its easiest")

	_say("== fonts ==")
	var sample := {
		"English": "Rg", "Русский": "ЯжЁй", "Deutsch": "üßÄ",
		"Español": "ñ¿á", "Nederlands": "ij",
	}
	for lang in sample:
		var missing := ""
		for i in str(sample[lang]).length():
			var c: int = str(sample[lang]).unicode_at(i)
			if not G.font_body.has_char(c) or not G.font_bold.has_char(c):
				missing += char(c)
		ok(missing == "", "%s is drawable by the fonts we ship%s"
			% [lang, "" if missing == "" else " (missing %s)" % missing])
	# Chinese and the symbols come from the cut-down fallback, which is built
	# from the game's own text - so this is really asking whether that build
	# has been run since the text last changed.
	for pair in [["中文", "Chinese"], ["← → ▶ ★ ♪ ⏸", "the symbols the interface uses"]]:
		var gone := ""
		for i in str(pair[0]).length():
			var c: int = str(pair[0]).unicode_at(i)
			if c > 0x20 and not G.font_body.has_char(c):
				gone += char(c)
		ok(gone == "", "%s can be drawn too%s"
			% [pair[1], "" if gone == "" else " (missing %s - rerun tools/gen_fontpack.py)" % gone])


## The mode picker is one choice, and VR reads it rather than keeping a second
## one of its own that could disagree with the list you are looking at.
func _test_game_mode() -> void:
	_say("== game mode ==")
	var was := G.game_mode
	G.game_mode = "laser"
	ok(G.vr_style == "pointer", "picking the laser puts a pointer in your hand")
	G.game_mode = "saber"
	ok(G.vr_style == "saber", "picking sabers gives you a blade")
	G.game_mode = "all"
	ok(G.vr_style == "saber", "and \"all\" plays sabers, which is what a headset is for")
	var song := {"id": "x"}
	for m in ["all", "laser", "saber"]:
		ok(RhythmMap.supports_mode(song, m), "every song plays in %s today" % m)
	ok(not RhythmMap.supports_mode({"modes": ["laser"]}, "saber"),
		"but a song may say which modes it is written for")
	G.game_mode = was


## The story script, checked as data rather than read by eye. A line with a
## pose nobody has built is a character who stands wrong for a whole sentence,
## and a line with nobody saying it is a name box that keeps the last name.
func _test_dialogue() -> void:
	_say("== story dialogue ==")
	var lines := 0
	var players := 0
	var bad_pose := ""
	var bad_who := ""
	for st in StoryScreen.STORIES:
		for raw in st.get("dialog", []):
			lines += 1
			ok(raw is Dictionary, "every line says who is speaking")
			var who := str((raw as Dictionary).get("who", ""))
			if not (who in ["melly", "you"]):
				bad_who = who
			if who == "you":
				players += 1
			elif not MellyRig.POSES.has(str((raw as Dictionary).get("pose", "talk"))):
				bad_pose = str((raw as Dictionary).get("pose", ""))
			if str((raw as Dictionary).get("text", "")).strip_edges() == "":
				bad_who = "(a line with no words)"
	ok(bad_who == "", "and it is somebody who exists%s"
		% ("" if bad_who == "" else " (%s)" % bad_who))
	ok(bad_pose == "", "and stands in a pose that was built%s"
		% ("" if bad_pose == "" else " (%s)" % bad_pose))
	ok(players > 0, "the player answers back (%d of %d lines)" % [players, lines])
	ok(MellyRig.POSES.has("listen"),
		"and Melly has something to do while being talked at")
	# the two voices have to be two voices, not the same beep twice
	ok(G.VOICES.has("melly") and G.VOICES.has("player"),
		"both speakers have a voice")
	ok(G.VOICES["melly"]["shape"] != G.VOICES["player"]["shape"],
		"and they are different sounds, not one pitched twice")
	# every face a pose asks for has to be drawable
	var missing := ""
	for name in MellyRig.POSES:
		var f := str(MellyRig.POSES[name]["face"])
		if not (f in ["idle", "happy", "very", "sad"]) \
				and MellyFaces.get_face(f) == null:
			missing += f + " "
	ok(missing == "", "and every face a pose asks for can be drawn%s"
		% ("" if missing == "" else " (%s)" % missing))


## A rounded rectangle has to come out as a polygon the renderer can actually
## fill. The health bar asks for a stadium - a radius of exactly half the
## height - which made neighbouring corners share a centre, put the same point
## in the outline twice, and left draw_colored_polygon printing "triangulation
## failed" and drawing nothing while the bar looked empty.
func _test_rounded() -> void:
	_say("== rounded rectangles ==")
	var cases := [
		["a stadium (radius exactly half the height)", Rect2(0, 0, 420, 11), 5.5],
		["a circle (as wide as it is tall)", Rect2(0, 0, 24, 24), 12.0],
		["a radius larger than the box", Rect2(0, 0, 30, 12), 40.0],
		["an ordinary card", Rect2(0, 0, 560, 440), 26.0],
	]
	for c in cases:
		var pts: PackedVector2Array = G.rounded_points(c[1], c[2])
		var repeats := 0
		for i in pts.size():
			if pts[i].distance_squared_to(pts[(i + 1) % pts.size()]) <= 0.0001:
				repeats += 1
		ok(pts.size() >= 3 and repeats == 0,
			"%s comes out fillable (%d points, %d repeated)"
			% [str(c[0]), pts.size(), repeats])


## The auto builder, as data. A pool naming a shape that does not exist is a
## crash the first time that phrase comes up in a song nobody has generated
## yet, and a per-level table one entry short is the same thing at the top of
## the slider.
func _test_charter() -> void:
	_say("== auto builder ==")
	var levels := Charter.POOLS.size()
	ok(levels == 4, "there are four difficulties to build (%d)" % levels)
	for table in [["SIZE_MUL", Charter.SIZE_MUL], ["HOLD_BARS", Charter.HOLD_BARS],
			["HOLD_LEN_BEATS", Charter.HOLD_LEN_BEATS],
			["CLICK_EVERY", Charter.CLICK_EVERY],
			["GAP_BEATS", Beat.GAP_BEATS], ["GAP_FLOOR", Beat.GAP_FLOOR]]:
		ok((table[1] as Array).size() >= levels,
			"%s covers all of them (%d)" % [str(table[0]), (table[1] as Array).size()])
	var unknown := ""
	for lv in Charter.POOLS:
		for name in Charter.POOLS[lv]:
			if not Charter.PATTERNS.has(name):
				unknown += "%s " % name
	ok(unknown == "", "every shape a pool asks for exists%s"
		% ("" if unknown == "" else " (%s)" % unknown))
	ok(Charter.PATTERNS.size() >= 30,
		"and there are enough of them to not repeat (%d)" % Charter.PATTERNS.size())
	# each step up is tighter than the one below it, or the slider is a lie
	var tighter := true
	for i in range(1, levels):
		if Beat.GAP_BEATS[i] >= Beat.GAP_BEATS[i - 1]:
			tighter = false
	ok(tighter, "and each difficulty is tighter than the one below it")

	# a real build: harder settings put more cubes down and move you further
	var times: Array = []
	var t := 0.0
	while t < 40.0:
		times.append({"t": t, "v": 1.0, "slot": int(t / 0.125) % 16})
		t += 0.125
	var last_n := 0
	var grew := true
	for lv in levels:
		var chart := Charter.build(times, lv, 0.5, "test", false, true)
		if lv > 0 and chart.size() < last_n:
			grew = false
		last_n = chart.size()
	ok(grew and last_n > 0, "and a harder setting never puts down fewer cubes")


## Coins, as arithmetic. The rules matter more than most because they decide
## how long somebody has to play for a hat, and a mistake here is either a
## currency nobody can earn or one that means nothing.
func _test_coins() -> void:
	_say("== coins ==")
	ok(Coins.for_run(false, "SS", 2, 3, true) == 0,
		"a chart you wrote yourself pays nothing")
	ok(Coins.for_run(true, Judge.DEAD, 2, 3, true) == 0, "and a run you lost pays nothing")
	var first := Coins.for_run(true, "S", 2, 3, true)
	var again := Coins.for_run(true, "S", 2, 3, false)
	ok(first > 0, "a first clear pays (%d)" % first)
	ok(again == int(round(first * Coins.REPEAT_SHARE)) or absi(again * 2 - first) <= 1,
		"and every one after it pays half (%d)" % again)
	var good := Coins.for_run(true, "SS", 2, 3, true)
	var scrape := Coins.for_run(true, "D", 2, 3, true)
	ok(good > scrape and scrape > 0, "a better rank pays more (%d against %d)" % [good, scrape])
	var easy := Coins.for_run(true, "SS", 0, 4, true)
	var hard := Coins.for_run(true, "SS", 3, 4, true)
	ok(hard > easy, "and a harder chart pays more (%d against %d)" % [hard, easy])
	# a wardrobe has to cost real play
	var cheapest := 999999
	for it in MellyShop.ITEMS:
		cheapest = mini(cheapest, int(it.price))
	ok(cheapest >= good * 8,
		"the cheapest item costs real play (%d coins, about %d clears of a hard chart)"
		% [cheapest, int(round(float(cheapest) / float(maxi(good, 1))))])

	# every item can be built, and every slot it claims is a real one
	var broken := ""
	for it in MellyShop.ITEMS:
		if not (str(it.slot) in MellyShop.SLOTS):
			broken += "%s:slot " % str(it.id)
		var art := MellyShop.build(str(it.id))
		if art == null:
			broken += "%s:art " % str(it.id)
		else:
			art.free()
	ok(broken == "", "every item in the wardrobe exists and can be built%s"
		% ("" if broken == "" else " (%s)" % broken))


## The events editor has to offer every command the game can run, and only
## those. A command with no fields is a row somebody can add and never fill in;
## a field for a command that does not exist is a line written into a map that
## the game will ignore without saying so.
func _test_events() -> void:
	_say("== event editor ==")
	var missing := ""
	for cmd in SongScript.COMMANDS:
		if not EventEditor.FIELDS.has(cmd):
			missing += "%s " % str(cmd)
	ok(missing == "", "every command can be edited%s"
		% ("" if missing == "" else " (%s)" % missing))
	var extra := ""
	for cmd in EventEditor.FIELDS:
		if not (cmd in SongScript.COMMANDS):
			extra += "%s " % str(cmd)
	ok(extra == "", "and nothing is offered that the game cannot run%s"
		% ("" if extra == "" else " (%s)" % extra))
	var bad := ""
	for cmd in EventEditor.FIELDS:
		for f in EventEditor.FIELDS[cmd]:
			if not (f as Dictionary).has("key") or not (f as Dictionary).has("def"):
				bad += "%s " % str(cmd)
			elif str(f.kind) == "num" and not ((f as Dictionary).has("lo")
					and (f as Dictionary).has("hi")):
				bad += "%s.%s " % [str(cmd), str(f.key)]
	ok(bad == "", "and every field has a default and a range%s"
		% ("" if bad == "" else " (%s)" % bad))
	# a caption is the one with settings, so it is the one worth pinning
	var keys: Array = []
	for f in EventEditor.FIELDS["text"]:
		keys.append(str(f.key))
	for want in ["value", "x", "y", "size", "color", "hold"]:
		ok(want in keys, "a caption can set its %s" % want)
