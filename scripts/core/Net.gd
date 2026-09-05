extends Node
## Net - direct peer-to-peer versus. One player hosts, the other joins by
## address; there is no server in the middle and nothing is uploaded anywhere.
##
## Both sides must be running the same build and holding the same chart, so the
## handshake compares a protocol number, the game version and a hash of the
## notes themselves. Custom maps work exactly like the bundled ones as long as
## the charts are identical - the audio file name and any video are left out of
## the hash, since neither changes what you play.

const PROTOCOL := 1
const DEFAULT_PORT := 27015

signal state_changed(text: String)
signal match_ready(song_id: String, diff: String)
signal match_refused(reason: String)
signal match_start()
signal opponent_progress(score: int, combo: int, acc: float)
signal opponent_finished(result: Dictionary)

var role := ""                  # "", "host", "client"
var connected := false
var in_match := false
var opponent := {}              # score, combo, acc, done, result
var want_song := ""
var want_diff := ""
var want_hash := ""

var _peer: ENetMultiplayerPeer = null
var _send_at := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


# ---------------------------------------------------------------- lifecycle
func host(port := DEFAULT_PORT) -> String:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, 1)
	if err != OK:
		_peer = null
		return "Could not open port %d" % port
	multiplayer.multiplayer_peer = _peer
	role = "host"
	state_changed.emit("Waiting for a player…")
	return ""


func join(address: String, port := DEFAULT_PORT) -> String:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address.strip_edges(), port)
	if err != OK:
		_peer = null
		return "Could not reach %s" % address
	multiplayer.multiplayer_peer = _peer
	role = "client"
	state_changed.emit("Connecting to %s…" % address)
	return ""


func close() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	role = ""
	connected = false
	in_match = false
	opponent = {}
	want_song = ""
	want_diff = ""
	want_hash = ""


func is_active() -> bool:
	return role != ""


func _on_peer_connected(_id: int) -> void:
	connected = true
	state_changed.emit("Player connected")


func _on_connected() -> void:
	connected = true
	state_changed.emit("Connected — waiting for the host to pick a song")


func _on_peer_disconnected(_id: int) -> void:
	connected = false
	in_match = false
	state_changed.emit("The other player left")


func _on_failed() -> void:
	close()
	match_refused.emit("Could not connect")


func _on_server_gone() -> void:
	close()
	match_refused.emit("The host closed the game")


# ---------------------------------------------------------------- chart hash
## Identity of a chart: the notes, the difficulty name and the song id. The
## audio file name and any video are deliberately left out.
static func chart_hash(song: Dictionary, diff_idx: int) -> String:
	var diffs := RhythmMap.diffs_of(song)
	if diff_idx < 0 or diff_idx >= diffs.size():
		return ""
	var d: Dictionary = diffs[diff_idx]
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%s|%s|%.3f|" % [str(song.get("id", "")), str(d.get("name", "")),
		float(song.get("bpm", 120.0))]).to_utf8_buffer())
	for n in d.get("notes", []):
		ctx.update(("%.3f,%d,%.2f,%.3f,%d;" % [
			float(n.get("t", 0.0)), int(n.get("cell", 4)), float(n.get("s", 1.0)),
			float(n.get("h", 0.0)), 1 if bool(n.get("c", false)) else 0
		]).to_utf8_buffer())
	return ctx.finish().hex_encode()


# ---------------------------------------------------------------- handshake
## Host: offer a chart to the other side.
func offer(song: Dictionary, diff_idx: int) -> void:
	if role != "host" or not connected:
		return
	var diffs := RhythmMap.diffs_of(song)
	want_song = str(song.get("id", ""))
	want_diff = str(diffs[diff_idx].get("name", "")) if diff_idx < diffs.size() else ""
	want_hash = chart_hash(song, diff_idx)
	_offer.rpc(PROTOCOL, G.VERSION, want_song, want_diff, want_hash)


@rpc("any_peer", "reliable")
func _offer(proto: int, version: String, song_id: String, diff: String,
		hash_: String) -> void:
	if proto != PROTOCOL:
		_refuse.rpc("Different network protocol — one of you is on an older build")
		match_refused.emit("Different network protocol")
		return
	if version != G.VERSION:
		_refuse.rpc("Different game version: %s vs %s" % [version, G.VERSION])
		match_refused.emit("Different game version")
		return
	# find the same chart on this side
	for s in RhythmMap.load_songs():
		if str(s.get("id", "")) != song_id:
			continue
		var diffs := RhythmMap.diffs_of(s)
		for i in diffs.size():
			if str(diffs[i].get("name", "")) != diff:
				continue
			if chart_hash(s, i) != hash_:
				_refuse.rpc("Your \"%s\" chart is different from mine" % diff)
				match_refused.emit("The charts do not match")
				return
			want_song = song_id
			want_diff = diff
			want_hash = hash_
			G.selected_song = s
			G.selected_diff = i
			_accept.rpc()
			match_ready.emit(song_id, diff)
			return
	_refuse.rpc("I do not have \"%s\"" % song_id)
	match_refused.emit("You do not have that song")


@rpc("any_peer", "reliable")
func _accept() -> void:
	match_ready.emit(want_song, want_diff)


@rpc("any_peer", "reliable")
func _refuse(reason: String) -> void:
	match_refused.emit(reason)


# ---------------------------------------------------------------- the match
func start_match() -> void:
	if role != "host":
		return
	# call_local means the rpc already runs here too - calling it again would
	# start the match twice on the host
	_go.rpc()


@rpc("any_peer", "call_local", "reliable")
func _go() -> void:
	in_match = true
	opponent = {"score": 0, "combo": 0, "acc": 1.0, "done": false, "result": {}}
	match_start.emit()


## Called from the game loop; throttled, so it can be called every frame.
func send_progress(t: float, score: int, combo: int, acc: float) -> void:
	if not in_match or not connected:
		return
	if t < _send_at:
		return
	_send_at = t + 0.25
	_progress.rpc(score, combo, acc)


@rpc("any_peer", "unreliable_ordered")
func _progress(score: int, combo: int, acc: float) -> void:
	opponent["score"] = score
	opponent["combo"] = combo
	opponent["acc"] = acc
	opponent_progress.emit(score, combo, acc)


func send_result(result: Dictionary) -> void:
	if not in_match or not connected:
		return
	_result.rpc({
		"score": int(result.get("score", 0)),
		"acc": float(result.get("acc", 0.0)),
		"max_combo": int(result.get("max_combo", 0)),
		"rank": str(result.get("rank", "")),
	})


@rpc("any_peer", "reliable")
func _result(result: Dictionary) -> void:
	opponent["done"] = true
	opponent["result"] = result
	opponent["score"] = int(result.get("score", 0))
	opponent_finished.emit(result)


func end_match() -> void:
	in_match = false
	_send_at = 0.0
