extends Node
## Sanity checks for the save file, hold notes and the judge. Run with:
##   godot --headless --path . res://tools/CoreTest.tscn

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("%s  %s" % ["PASS" if cond else "FAIL", what])


func _ready() -> void:
	_test_settings_roundtrip()
	_test_hold_notes()
	_test_judge()
	_test_offset()
	print("--- failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _test_settings_roundtrip() -> void:
	print("== settings round-trip ==")
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
	G.disclaimer_seen = true
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
	ok(G.disclaimer_seen, "first-launch flag survives")
	ok(G.key_binds.get(Binds.PAUSE, []) == [KEY_P], "key binds survive")
	# the buses must actually be at the reloaded level, not the default
	var db := AudioServer.get_bus_volume_db(0)
	ok(absf(db - linear_to_db(0.42)) < 0.01, "master bus applied after load")


func _test_hold_notes() -> void:
	print("== hold notes ==")
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


func _test_judge() -> void:
	print("== judge ==")
	ok(Judge.label_for(0.0, 0.9) == "PERFECT", "centre hit is PERFECT")
	ok(Judge.label_for(0.0, 0.05) == "BULLSHIT", "edge hit is BULLSHIT")
	ok(Judge.hold_acc(1.0, 1.0) > Judge.hold_acc(1.0, 0.2), "a fully held note beats a dropped one")
	ok(Judge.degrade("PERFECT", 1.0) == "PERFECT", "a clean hold keeps its rank")
	ok(Judge.degrade("PERFECT", 0.3) == "GOOD", "a badly dropped hold loses two steps")
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
	ok(holds_seen > 0 and clicks_seen > 0,
		"shipped charts contain holds (%d) and click notes (%d)" % [holds_seen, clicks_seen])


func _test_offset() -> void:
	print("== conductor offset ==")
	G.audio_offset = 0.0
	Conductor.song_time = 10.0
	ok(is_equal_approx(Conductor.play_time(), 10.0), "no offset means play time is song time")
	G.audio_offset = 0.05
	ok(is_equal_approx(Conductor.play_time(), 9.95), "a positive offset judges notes later")
	G.audio_offset = 0.0
