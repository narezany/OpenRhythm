extends Node
## Two-process check of the versus handshake. Run one of each:
##   OR_NET=host godot --headless --path . res://tools/NetTest.tscn
##   OR_NET=join godot --headless --path . res://tools/NetTest.tscn

const PORT := 27099

var role := ""
var started := false
var got_progress := false
var got_result := false


func _ready() -> void:
	role = OS.get_environment("OR_NET")
	Net.state_changed.connect(func(t): print("[%s] state: %s" % [role, t]))
	Net.match_refused.connect(func(r): print("[%s] REFUSED: %s" % [role, r]))
	Net.match_ready.connect(func(sid, d): print("[%s] ready: %s [%s]" % [role, sid, d]))
	Net.match_start.connect(_on_start)
	Net.opponent_progress.connect(func(sc, _c, _a):
		if not got_progress:
			got_progress = true
			print("[%s] opponent progress: %d" % [role, sc]))
	Net.opponent_finished.connect(func(r):
		got_result = true
		print("[%s] opponent finished: %d" % [role, int(r.get("score", 0))]))

	if role == "host":
		var err := Net.host(PORT)
		print("[host] listening err=", err if err != "" else "none")
		# wait for the other side rather than guessing at a delay
		var waited := 0.0
		while not Net.connected and waited < 12.0:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		if not Net.connected:
			print("[host] nobody joined")
			get_tree().quit(1)
			return
		var song := _find("afterburner")
		print("[host] chart hash: ", Net.chart_hash(song, 1).substr(0, 16))
		if OS.get_environment("OR_NET_BAD") != "":
			# a chart that does not match must be refused, not played
			print("[host] offering a tampered chart")
			Net._offer.rpc(Net.PROTOCOL, G.VERSION, "afterburner", "Normal",
				"deadbeef" .repeat(8))
			await get_tree().create_timer(3.0).timeout
			print("[host] RESULT started=%s (expected false)" % started)
			Net.close()
			get_tree().quit(0 if not started else 1)
			return
		Net.match_ready.connect(func(_a, _b): Net.start_match(), CONNECT_ONE_SHOT)
		Net.offer(song, 1)
	else:
		await get_tree().create_timer(0.6).timeout
		var err := Net.join("127.0.0.1", PORT)
		print("[join] connect err=", err if err != "" else "none")

	await get_tree().create_timer(7.0).timeout
	print("[%s] RESULT started=%s progress=%s result=%s" % [
		role, started, got_progress, got_result])
	Net.close()
	get_tree().quit(0 if started and got_progress and got_result else 1)


func _find(id: String) -> Dictionary:
	for s in RhythmMap.load_songs():
		if str(s.get("id", "")) == id:
			return s
	return {}


func _on_start() -> void:
	started = true
	print("[%s] MATCH START song=%s diff=%s" % [role, Net.want_song, Net.want_diff])
	# pretend to play: send a few progress packets and a result
	var t := 0.0
	for i in 6:
		await get_tree().create_timer(0.3).timeout
		t += 0.3
		Net.send_progress(t, (i + 1) * 1000 + (500 if role == "host" else 0), i, 0.9)
	Net.send_result({"score": 7000 if role == "host" else 6500, "acc": 0.93,
		"max_combo": 40, "rank": "S"})
