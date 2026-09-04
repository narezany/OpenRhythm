class_name MapImport
extends RefCounted
## Importers for outside map formats.
##
## .sspm  - Sound Space Plus / Rhythia binary maps, v1 and v2. Layout follows
##          the upstream spec (basils-garden/types, sspm v1.md and v2.md):
##          header "SS+m" + uint16 version, then the version body. Audio and
##          cover are embedded, so an imported song is playable immediately.
## .txt   - legacy Sound Space map data: "audioId,x|y|ms,x|y|ms,...". No audio
##          is embedded; the player drops an audio file into the folder after.
##
## Grid convention: SS coordinates run x to the right and y downwards with
## (0,0) at the top-left, which is exactly how OpenRhythm indexes its 3x3 grid,
## so cells map straight across with no mirroring.

const MAGIC := [0x53, 0x53, 0x2b, 0x6d]   # "SS+m"

const DIFF_NAMES := ["Unrated", "Easy", "Medium", "Hard", "Logic", "Tasukete"]

# custom-data / marker value type ids from the v2 spec
const T_END := 0x00
const T_ARRAY := 0x0c


## Import any supported file. Returns {"ok": bool, "error": String,
## "song": Dictionary, "needs_audio": bool}.
static func import_path(path: String) -> Dictionary:
	var ext := path.get_extension().to_lower()
	match ext:
		"sspm":
			return import_sspm(path)
		"txt":
			return import_ss_text(path)
	return {"ok": false, "error": "Unsupported file type: ." + ext}


# ---------------------------------------------------------------- sspm
static func import_sspm(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "Cannot open " + path.get_file()}
	f.big_endian = false
	var magic := f.get_buffer(4)
	if magic.size() < 4 or magic[0] != MAGIC[0] or magic[1] != MAGIC[1] \
			or magic[2] != MAGIC[2] or magic[3] != MAGIC[3]:
		f.close()
		return {"ok": false, "error": "Not an SSPM file (bad signature)"}
	var version := f.get_16()
	var parsed: Dictionary
	if version == 2:
		f.get_32()                     # 4 reserved bytes
		parsed = _read_v2(f)
	elif version == 1:
		f.get_16()                     # 2 reserved bytes
		parsed = _read_v1(f)
	else:
		f.close()
		return {"ok": false, "error": "Unsupported SSPM version %d" % version}
	f.close()
	if not parsed.get("ok", false):
		return parsed
	return _write_song(parsed)


static func _read_v2(f: FileAccess) -> Dictionary:
	f.get_buffer(20)                        # sha1 of the marker block
	var last_ms := f.get_32()
	var note_count := f.get_32()
	f.get_32()                              # marker count, notes included
	var difficulty := f.get_8()
	f.get_16()                              # map rating
	var has_audio := f.get_8() == 1
	var has_cover := f.get_8() == 1
	f.get_8()                               # requires a mod to play

	var p_custom := _pointer(f)
	var p_audio := _pointer(f)
	var p_cover := _pointer(f)
	var p_defs := _pointer(f)
	var p_markers := _pointer(f)

	var map_id := _str16(f)
	var map_name := _str16(f)
	var song_name := _str16(f)
	var mapper_count := f.get_16()
	var mappers: Array = []
	for i in mapper_count:
		mappers.append(_str16(f))

	var audio := PackedByteArray()
	if has_audio and p_audio[1] > 0:
		f.seek(p_audio[0])
		audio = f.get_buffer(int(p_audio[1]))
	var cover := PackedByteArray()
	if has_cover and p_cover[1] > 0:
		f.seek(p_cover[0])
		cover = f.get_buffer(int(p_cover[1]))

	# marker definitions: notes exist only when "ssp_note" is definition 0
	var has_notes := false
	if p_defs[1] > 0:
		f.seek(p_defs[0])
		var def_count := f.get_8()
		for i in def_count:
			var dname := _str16(f)
			if i == 0 and dname == "ssp_note":
				has_notes = true
			f.get_8()                       # value count, arrays included
			while f.get_8() != T_END:
				pass                        # walk the type list to its terminator

	var notes: Array = []
	if has_notes and p_markers[1] > 0:
		f.seek(p_markers[0])
		notes = _read_notes(f, note_count, true)

	var title: String = song_name if song_name.strip_edges() != "" else map_name
	return {
		"ok": true,
		"title": title if title.strip_edges() != "" else map_id,
		"artist": ", ".join(mappers) if mappers.size() > 0 else "Sound Space",
		"diff_name": _diff_name(difficulty),
		"notes": notes,
		"last_ms": last_ms,
		"audio": audio,
		"cover": cover,
		"source_id": map_id,
	}


static func _read_v1(f: FileAccess) -> Dictionary:
	var map_id := _str_nl(f)
	var map_name := _str_nl(f)
	var mappers := _str_nl(f)
	var last_ms := f.get_32()
	var note_count := f.get_32()
	var difficulty := f.get_8()

	var cover := PackedByteArray()
	var cover_type := f.get_8()
	if cover_type == 0x02:
		cover = f.get_buffer(int(f.get_64()))

	var audio := PackedByteArray()
	var audio_type := f.get_8()
	if audio_type == 0x01:
		audio = f.get_buffer(int(f.get_64()))

	var notes := _read_notes(f, note_count, false)
	return {
		"ok": true,
		"title": map_name if map_name.strip_edges() != "" else map_id,
		"artist": mappers if mappers.strip_edges() != "" else "Sound Space",
		"diff_name": _diff_name(difficulty),
		"notes": notes,
		"last_ms": last_ms,
		"audio": audio,
		"cover": cover,
		"source_id": map_id,
	}


## One note marker: uint32 ms, (v2 only) uint8 marker type, then a flag byte -
## 0 means two bytes of x/y, anything else means two float32 (a quantum map).
static func _read_notes(f: FileAccess, count: int, has_type_byte: bool) -> Array:
	var out: Array = []
	for i in count:
		if f.eof_reached():
			break
		var ms := f.get_32()
		if has_type_byte:
			f.get_8()
		var x := 0.0
		var y := 0.0
		if f.get_8() == 0:
			x = float(f.get_8())
			y = float(f.get_8())
		else:
			x = f.get_float()
			y = f.get_float()
		out.append({"t": float(ms) / 1000.0, "cell": _cell(x, y), "s": 1.0})
	out.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return out


static func _pointer(f: FileAccess) -> Array:
	var off := f.get_64()
	var len_ := f.get_64()
	return [off, len_]


static func _str16(f: FileAccess) -> String:
	var n := f.get_16()
	if n <= 0:
		return ""
	return f.get_buffer(n).get_string_from_utf8()


static func _str_nl(f: FileAccess) -> String:
	var buf := PackedByteArray()
	while not f.eof_reached():
		var b := f.get_8()
		if b == 0x0a:
			break
		buf.append(b)
	return buf.get_string_from_utf8()


# ---------------------------------------------------------------- legacy text
static func import_ss_text(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	if raw.strip_edges() == "":
		return {"ok": false, "error": "File is empty"}
	var parsed := parse_ss_text(raw)
	if not parsed.get("ok", false):
		return parsed
	parsed["title"] = path.get_file().get_basename()
	return _write_song(parsed)


## Parse the classic "audioId,x|y|ms,x|y|ms,..." string.
static func parse_ss_text(raw: String) -> Dictionary:
	var parts := raw.strip_edges().split(",", false)
	if parts.size() < 2:
		return {"ok": false, "error": "Not a Sound Space map string"}
	var notes: Array = []
	var last_ms := 0
	for i in range(1, parts.size()):
		var bits := str(parts[i]).split("|")
		if bits.size() < 3:
			continue
		var x := float(bits[0])
		var y := float(bits[1])
		var ms := int(float(bits[2]))
		last_ms = maxi(last_ms, ms)
		notes.append({"t": float(ms) / 1000.0, "cell": _cell(x, y), "s": 1.0})
	if notes.is_empty():
		return {"ok": false, "error": "No notes found in the map string"}
	notes.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return {
		"ok": true, "title": str(parts[0]), "artist": "Sound Space",
		"diff_name": "Imported", "notes": notes, "last_ms": last_ms,
		"audio": PackedByteArray(), "cover": PackedByteArray(),
		"source_id": str(parts[0]),
	}


# ---------------------------------------------------------------- shared
static func _cell(x: float, y: float) -> int:
	var cx := clampi(roundi(x), 0, 2)
	var cy := clampi(roundi(y), 0, 2)
	return cy * 3 + cx


static func _diff_name(d: int) -> String:
	return DIFF_NAMES[d] if d >= 0 and d < DIFF_NAMES.size() else "Imported"


## Guess the container from the first bytes so the file lands with a usable
## extension - RhythmMap picks its loader by extension.
static func _audio_ext(data: PackedByteArray) -> String:
	if data.size() < 4:
		return ""
	if data[0] == 0x4f and data[1] == 0x67 and data[2] == 0x67 and data[3] == 0x53:
		return "ogg"                                   # OggS
	if data[0] == 0x52 and data[1] == 0x49 and data[2] == 0x46 and data[3] == 0x46:
		return "wav"                                   # RIFF
	if data[0] == 0x49 and data[1] == 0x44 and data[2] == 0x33:
		return "mp3"                                   # ID3
	if data[0] == 0xff and (data[1] & 0xe0) == 0xe0:
		return "mp3"                                   # raw MPEG frame
	return "mp3"


## SSPM carries no BPM. Estimate one from the most common gap between notes so
## the beat grid in the editor and the on-beat effects are roughly right.
static func estimate_bpm(notes: Array) -> float:
	if notes.size() < 8:
		return 120.0
	var gaps: Array = []
	for i in range(1, mini(notes.size(), 600)):
		var g: float = float(notes[i].t) - float(notes[i - 1].t)
		if g > 0.04 and g < 2.0:
			gaps.append(g)
	if gaps.is_empty():
		return 120.0
	gaps.sort()
	var median: float = gaps[gaps.size() / 2]
	# a gap is usually a half or quarter beat; fold the guess into 100..200 BPM
	var bpm := 60.0 / maxf(median, 0.001)
	while bpm > 200.0:
		bpm *= 0.5
	while bpm < 100.0:
		bpm *= 2.0
	return snappedf(bpm, 0.5)


static func _write_song(data: Dictionary) -> Dictionary:
	var notes: Array = data.get("notes", [])
	if notes.is_empty():
		return {"ok": false, "error": "The map contains no notes"}
	var title := str(data.get("title", "Imported map")).strip_edges()
	if title == "":
		title = "Imported map"
	var song := RhythmMap.create_new_song(title)
	var dir := str(song["dir"])

	var audio: PackedByteArray = data.get("audio", PackedByteArray())
	var audio_name := ""
	if audio.size() > 0:
		audio_name = "audio." + _audio_ext(audio)
		var af := FileAccess.open(dir + "/" + audio_name, FileAccess.WRITE)
		if af != null:
			af.store_buffer(audio)
			af.close()
		else:
			audio_name = ""
	var cover: PackedByteArray = data.get("cover", PackedByteArray())
	if cover.size() > 0:
		var cf := FileAccess.open(dir + "/cover.png", FileAccess.WRITE)
		if cf != null:
			cf.store_buffer(cover)
			cf.close()

	song["artist"] = str(data.get("artist", ""))
	song["audio"] = audio_name
	song["bpm"] = estimate_bpm(notes)
	song["length"] = float(data.get("last_ms", 0)) / 1000.0 + 2.0
	song["source"] = "sspm"
	song["source_id"] = str(data.get("source_id", ""))
	song["difficulties"] = [{"name": str(data.get("diff_name", "Imported")), "notes": notes}]
	RhythmMap.write_map(song)
	return {
		"ok": true, "song": song, "needs_audio": audio_name == "",
		"note_count": notes.size(),
	}
