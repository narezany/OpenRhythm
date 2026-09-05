class_name SongScript
extends RefCounted
## Map scripting: a timeline of events a song can run while it plays, plus the
## art it brings with it.
##
## Events are data, not code. A map pack is something you download from a
## stranger, so running a real script out of it would be handing that stranger
## your machine. Everything here is a fixed set of commands with numeric
## arguments and image files from the song's own folder - it covers what a
## storyboard is for (colours, pictures, note skins, huge notes, camera work)
## without that risk.
##
## Events live in the song folder as events.json, or inline in map.json under
## "events". Each one is {"t": seconds, "do": command, ...arguments}.
##
##   {"t": 0.0,  "do": "bg_color",   "hue": 0.62, "fade": 2.0}
##   {"t": 12.0, "do": "bg_image",   "file": "city.png", "fade": 1.0, "dim": 0.7}
##   {"t": 24.0, "do": "note_skin",  "file": "cube.png"}
##   {"t": 36.0, "do": "note_scale", "value": 1.6}
##   {"t": 48.0, "do": "flash",      "value": 0.8}
##   {"t": 48.0, "do": "shake",      "value": 0.5}
##   {"t": 60.0, "do": "zoom",       "value": 1.15, "fade": 0.5}
##   {"t": 64.0, "do": "text",       "value": "DROP"}

const COMMANDS := ["bg_color", "bg_image", "note_skin", "note_scale",
	"flash", "shake", "zoom", "text"]
const MAX_IMAGE_PX := 4096
const MAX_EVENTS := 4000

var events: Array = []
var dir := ""

var _next := 0
var _textures := {}


static func load_for(song: Dictionary) -> SongScript:
	var s := SongScript.new()
	s.dir = str(song.get("dir", ""))
	var raw: Array = song.get("events", [])
	var path := s.dir + "/events.json"
	if raw.is_empty() and FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Array:
			raw = data
		elif data is Dictionary:
			raw = data.get("events", [])
	for e in raw:
		if not (e is Dictionary):
			continue
		var cmd := str(e.get("do", ""))
		if not (cmd in COMMANDS):
			continue
		var ev := (e as Dictionary).duplicate()
		ev["t"] = float(e.get("t", 0.0))
		ev["do"] = cmd
		s.events.append(ev)
		if s.events.size() >= MAX_EVENTS:
			break
	s.events.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return s


func is_empty() -> bool:
	return events.is_empty()


func rewind() -> void:
	_next = 0


## Every event whose time has arrived since the last call.
func advance(t: float) -> Array:
	var out: Array = []
	while _next < events.size() and float(events[_next].t) <= t:
		out.append(events[_next])
		_next += 1
	return out


## An image from the song's own folder. Nothing outside it can be reached, and
## anything oversized is refused rather than eating the whole frame budget.
func texture(file: String) -> Texture2D:
	var name := file.get_file()          # strip any path: stay in the folder
	if name == "":
		return null
	if _textures.has(name):
		return _textures[name]
	var path := dir + "/" + name
	var tex: Texture2D = null
	# A song shipped inside the binary has its art imported as a resource; a
	# song in the player's library is just a file on disk. Try both, because a
	# folder dropped into res:// by hand has not been imported yet either.
	if path.begins_with("res://") and ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		var img := Image.new()
		var ok := false
		if FileAccess.file_exists(path):
			ok = img.load(path) == OK
		if not ok:
			var bytes := FileAccess.get_file_as_bytes(path)
			if not bytes.is_empty():
				ok = img.load_png_from_buffer(bytes) == OK \
					or img.load_jpg_from_buffer(bytes) == OK \
					or img.load_webp_from_buffer(bytes) == OK
		if ok and img.get_width() <= MAX_IMAGE_PX \
				and img.get_height() <= MAX_IMAGE_PX:
			tex = ImageTexture.create_from_image(img)
	_textures[name] = tex
	return tex
