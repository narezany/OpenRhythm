class_name Replay
extends RefCounted
## Cursor replays. Only the cursor path is stored - judgement is deterministic
## for a given path, so replaying the path reproduces the run. Samples are taken
## at a fixed rate and interpolated on playback, which keeps files small.

const DIR := "user://replays"
const RATE := 30.0                 # samples per second
const VERSION := 1

var meta := {}
var times: PackedFloat32Array = PackedFloat32Array()
var xs: PackedFloat32Array = PackedFloat32Array()
var ys: PackedFloat32Array = PackedFloat32Array()
## Song times at which the player clicked - click notes need them to replay.
var clicks: PackedFloat32Array = PackedFloat32Array()

var _next_sample := 0.0


func start(song: Dictionary, diff: String, mods: Array) -> void:
	meta = {
		"version": VERSION,
		"song_id": str(song.get("id", "")),
		"title": str(song.get("title", "")),
		"diff": diff,
		"mods": mods.duplicate(),
		"date": Time.get_datetime_string_from_system(false, true),
	}
	times.clear()
	xs.clear()
	ys.clear()
	clicks.clear()
	_next_sample = 0.0


func capture(t: float, pos: Vector2) -> void:
	if t < _next_sample:
		return
	_next_sample = t + 1.0 / RATE
	times.append(t)
	xs.append(pos.x)
	ys.append(pos.y)


func click(t: float) -> void:
	clicks.append(t)


## True when a click was recorded inside the window that just elapsed.
func clicked_between(a: float, b: float) -> bool:
	for c in clicks:
		if c >= a and c < b:
			return true
	return false


func finish(results: Dictionary) -> void:
	meta["score"] = int(results.get("score", 0))
	meta["acc"] = float(results.get("acc", 0.0))
	meta["max_combo"] = int(results.get("max_combo", 0))
	meta["rank"] = str(results.get("rank", ""))


## Cursor position at a point in time, linearly interpolated between samples.
func pos_at(t: float) -> Vector2:
	var n := times.size()
	if n == 0:
		return G.DESIGN / 2.0
	if t <= times[0]:
		return Vector2(xs[0], ys[0])
	if t >= times[n - 1]:
		return Vector2(xs[n - 1], ys[n - 1])
	var lo := 0
	var hi := n - 1
	while lo + 1 < hi:
		var mid := (lo + hi) / 2
		if times[mid] <= t:
			lo = mid
		else:
			hi = mid
	var span: float = times[hi] - times[lo]
	var k: float = 0.0 if span <= 0.0 else (t - times[lo]) / span
	return Vector2(xs[lo], ys[lo]).lerp(Vector2(xs[hi], ys[hi]), k)


func save() -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var name := "%s_%s_%d.orr" % [str(meta.get("song_id", "song")),
		str(meta.get("diff", "d")).to_lower().replace(" ", "_"),
		Time.get_unix_time_from_system()]
	var path := DIR + "/" + name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	var pts: Array = []
	for i in times.size():
		pts.append(snappedf(times[i], 0.001))
		pts.append(roundi(xs[i]))
		pts.append(roundi(ys[i]))
	var cl: Array = []
	for c in clicks:
		cl.append(snappedf(c, 0.001))
	f.store_string(JSON.stringify({"meta": meta, "p": pts, "c": cl}))
	f.close()
	return path


static func load_file(path: String) -> Replay:
	if not FileAccess.file_exists(path):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return null
	var r := Replay.new()
	r.meta = data.get("meta", {})
	for c in data.get("c", []):
		r.clicks.append(float(c))
	var pts: Array = data.get("p", [])
	var i := 0
	while i + 2 < pts.size():
		r.times.append(float(pts[i]))
		r.xs.append(float(pts[i + 1]))
		r.ys.append(float(pts[i + 2]))
		i += 3
	return r


## Every saved replay, newest first.
static func list_all() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.get_extension().to_lower() == "orr":
			var data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/" + f))
			if data is Dictionary:
				var m: Dictionary = data.get("meta", {})
				m["path"] = DIR + "/" + f
				out.append(m)
		f = dir.get_next()
	out.sort_custom(func(a, b): return str(a.get("date", "")) > str(b.get("date", "")))
	return out


static func list_for(song_id: String) -> Array:
	return list_all().filter(func(m): return str(m.get("song_id", "")) == song_id)
