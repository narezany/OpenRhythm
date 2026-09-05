class_name RhythmMap
extends RefCounted
## Song library. Built-in songs live in res://songs (map.json), user songs live
## in user://songs — as plain folders OR .zip archives (auto-extracted).
## A song folder may contain: map.json, audio file, optional video .ogv
## (played darkened behind the playfield).

const USER_SONGS := "user://songs"
const CUSTOM_NAME := "Custom"


## Android: the public /storage/emulated/0/OpenRhythm folder (visible in a file
## manager and over USB); every other platform uses user://songs.
static func user_songs_dir() -> String:
	if OS.has_feature("android"):
		var root := "/storage/emulated/0/OpenRhythm"
		DirAccess.make_dir_recursive_absolute(root)
		DirAccess.make_dir_recursive_absolute(root + "/songs")
		return root + "/songs"
	DirAccess.make_dir_recursive_absolute(USER_SONGS)
	return ProjectSettings.globalize_path(USER_SONGS)


## Public roots scanned for songs on Android. Both the folder the Songs screen
## advertises and the OpenRhythm root itself work, so a song dropped in either
## place is found.
static func _android_scan_roots() -> Array:
	return ["/storage/emulated/0/OpenRhythm/songs", "/storage/emulated/0/OpenRhythm"]


## Android: request the dangerous permissions from the manifest, files included.
## Returns false when the user refused - screens then show a hint.
static func _request_android_storage() -> bool:
	if not OS.has_feature("android"):
		return true
	OS.request_permissions()
	# permissions arrive asynchronously: if none of them is in the current
	# snapshot we treat that as a refusal (the dialog was shown or suppressed)
	var granted := OS.get_granted_permissions()
	var ok := "android.permission.READ_EXTERNAL_STORAGE" in granted \
		or "android.permission.MANAGE_EXTERNAL_STORAGE" in granted \
		or "android.permission.READ_MEDIA_AUDIO" in granted
	storage_denied_flag = not ok
	return ok


## True when the Android user denied file access.
static var storage_denied_flag := false


# ---------------------------------------------------------------- library
static func load_songs() -> Array:
	DirAccess.make_dir_recursive_absolute(USER_SONGS)
	_extract_user_zips()
	if OS.has_feature("android"):
		_request_android_storage()
	var out: Array = []
	for base in ["res://songs", USER_SONGS]:
		_scan_base(base, out)
	if OS.has_feature("android"):
		for base in _android_scan_roots():
			_scan_base(base, out)
	out = _dedupe(out)
	# tutorial first, everything else alphabetical
	out.sort_custom(func(a, b): return str(a.get("title", "")) < str(b.get("title", "")))
	out.sort_custom(func(a, b):
		var at: bool = str(a.get("id", "")) == "tutorial"
		var bt: bool = str(b.get("id", "")) == "tutorial"
		return at and not bt)
	# disabled songs stay in the library (shown greyed on Songs screen);
	# only gameplay/select flows hide them via is_playable()
	return out


## Two folders can legitimately resolve to the same song (the Android root and
## the songs/ folder inside it overlap). Keep the first hit for each directory
## and each id so the library never shows a song twice.
static func _dedupe(songs: Array) -> Array:
	var seen_dir := {}
	var seen_id := {}
	var out: Array = []
	for s in songs:
		var d := str(s.get("dir", ""))
		var i := str(s.get("id", ""))
		if seen_dir.has(d) or seen_id.has(i):
			continue
		seen_dir[d] = true
		seen_id[i] = true
		out.append(s)
	return out


static func _scan_base(base: String, out: Array) -> void:
	var dir := DirAccess.open(base)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var full: String = base + "/" + f
		if dir.current_is_dir() and not f.begins_with("."):
			if FileAccess.file_exists(full + "/map.json"):
				var data = JSON.parse_string(FileAccess.get_file_as_string(full + "/map.json"))
				if data is Dictionary:
					data["dir"] = full
					data["id"] = data.get("id", f)
					_detect_video(data)
					out.append(data)
			elif OS.has_feature("android") and base.ends_with("OpenRhythm"):
				pass   # a nested folder without map.json is not a song
		elif not dir.current_is_dir() and f.get_extension().to_lower() == "zip":
			pass   # zip songs are handled by _extract_user_zips
		f = dir.get_next()


## False for songs toggled off on the Songs screen - they remain visible there.
static func is_playable(song: Dictionary) -> bool:
	return not (str(song.get("id", "")) in G.disabled_songs)


## A song the player owns and may edit or delete: anything not shipped in the
## binary. On Android that includes the public folder, so Delete works there.
static func is_user_song(song: Dictionary) -> bool:
	return not str(song.get("dir", "")).begins_with("res://")


## Where newly created or imported songs are written. On Android this is the
## public folder the Songs screen advertises, so the player can find them.
static func songs_write_dir() -> String:
	if OS.has_feature("android"):
		var root := "/storage/emulated/0/OpenRhythm/songs"
		DirAccess.make_dir_recursive_absolute(root)
		return root
	DirAccess.make_dir_recursive_absolute(USER_SONGS)
	return USER_SONGS


## Delete a song by its own folder. Never rebuild the path from the id: the
## folder name and the id in map.json do not have to match.
static func delete_song(song: Dictionary) -> bool:
	var dir := str(song.get("dir", ""))
	if dir == "" or not is_user_song(song):
		return false
	var abs := ProjectSettings.globalize_path(dir) if dir.begins_with("user://") else dir
	if OS.move_to_trash(abs) == OK:
		return true
	return _remove_recursive(abs) == OK


static func _remove_recursive(path: String) -> Error:
	var dir := DirAccess.open(path)
	if dir == null:
		return ERR_FILE_NOT_FOUND
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if dir.current_is_dir():
			_remove_recursive(path + "/" + f)
		else:
			DirAccess.remove_absolute(path + "/" + f)
		f = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(path)


## Extract every user://songs/*.zip that has no extracted folder yet.
static func _extract_user_zips() -> void:
	var bases: Array = [USER_SONGS]
	if OS.has_feature("android"):
		bases.append("/storage/emulated/0/OpenRhythm")
		bases.append("/storage/emulated/0/OpenRhythm/songs")
	for base in bases:
		var dir := DirAccess.open(base)
		if dir == null:
			continue
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			var full: String = base + "/" + f
			if not dir.current_is_dir() and f.get_extension().to_lower() == "zip":
				var target: String = base + "/" + f.get_basename()
				if not FileAccess.file_exists(target + "/map.json"):
					var err := extract_zip(full, target)
					if err == OK:
						print("[OR] extracted song zip: ", f)
					else:
						print("[OR] zip extract FAILED (%s): %s" % [f, err])
			f = dir.get_next()


## Extract a song zip via the built-in ZIPReader.
static func extract_zip(zip_path: String, target_dir: String) -> Error:
	DirAccess.make_dir_recursive_absolute(target_dir)
	var zr := ZIPReader.new()
	var err := zr.open(zip_path)
	if err != OK:
		return err
	for fpath in zr.get_files():
		if fpath.ends_with("/"):
			continue
		var data := zr.read_file(fpath)
		if data.is_empty():
			continue
		var out_path: String = target_dir + "/" + fpath
		var out_dir: String = out_path.get_base_dir()
		if out_dir.begins_with(target_dir):
			DirAccess.make_dir_recursive_absolute(out_dir)
		var of := FileAccess.open(out_path, FileAccess.WRITE)
		if of != null:
			of.store_buffer(data)
			of.close()
	zr.close()
	return OK


static func _detect_video(song: Dictionary) -> void:
	var dir := DirAccess.open(str(song.get("dir", "")))
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.get_extension().to_lower() == "ogv":
			song["video"] = f
			return
		f = dir.get_next()


# ---------------------------------------------------------------- difficulties
static func diffs_of(song: Dictionary) -> Array:
	var diffs: Array = []
	for d in song.get("difficulties", []):
		diffs.append(d)
	if not is_user_song(song):
		var cpath: String = song["dir"] + "/map_custom.json"
		if FileAccess.file_exists(cpath):
			var data = JSON.parse_string(FileAccess.get_file_as_string(cpath))
			if data is Dictionary and data.get("difficulties") is Array \
					and data["difficulties"].size() > 0:
				diffs.append(data["difficulties"][0])
	return diffs


static func custom_of(song: Dictionary) -> Array:
	var cpath: String = song["dir"] + "/map_custom.json"
	if FileAccess.file_exists(cpath):
		var data = JSON.parse_string(FileAccess.get_file_as_string(cpath))
		if data is Dictionary and data.get("difficulties") is Array \
				and data["difficulties"].size() > 0:
			return data["difficulties"][0].get("notes", [])
	return []


# ---------------------------------------------------------------- audio/video
static func audio_stream(song: Dictionary) -> AudioStream:
	var name := str(song.get("audio", "audio.wav"))
	if name != "":
		var path: String = str(song["dir"]) + "/" + name
		if path.begins_with("res://"):
			return load(path)
		var s := import_audio(path)
		if s != null:
			return s
	# A song forked from a built-in one cannot always carry a copy of the
	# audio: in an exported build the original is packed as an imported
	# resource, not as a file, so the fork points back at it instead.
	var ref := str(song.get("audio_ref", ""))
	if ref == "":
		return null
	if ref.begins_with("res://"):
		return load(ref)
	return import_audio(ref)


## Runtime audio import from any path (user:// or absolute).
static func import_audio(path: String) -> AudioStream:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var ext := path.get_extension().to_lower()
	match ext:
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			# assigning .data directly leaves packet_sequence uninitialised
			return AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes(path))
		"mp3":
			return AudioStreamMP3.load_from_buffer(FileAccess.get_file_as_bytes(path))
	return null


static func video_stream(song: Dictionary) -> VideoStream:
	var vname := str(song.get("video", ""))
	if vname == "":
		var vref := str(song.get("video_ref", ""))
		if vref == "":
			return null
		if vref.begins_with("res://"):
			return load(vref)
		var vs2 := VideoStreamTheora.new()
		vs2.file = ProjectSettings.globalize_path(vref)
		return vs2
	var path: String = str(song["dir"]) + "/" + vname
	if not FileAccess.file_exists(path):
		return null
	if path.begins_with("res://"):
		return load(path)
	var vs := VideoStreamTheora.new()
	vs.file = ProjectSettings.globalize_path(path)
	return vs


# ---------------------------------------------------------------- write
## Create a fresh empty user song folder; returns the song dict.
static func create_new_song(title: String) -> Dictionary:
	var slug := _slugify(title)
	if slug == "":
		slug = "untitled"
	var base := songs_write_dir()
	var dir := "%s/%s" % [base, slug]
	var n := 1
	while DirAccess.dir_exists_absolute(dir):
		n += 1
		dir = "%s/%s_%d" % [base, slug, n]
	DirAccess.make_dir_recursive_absolute(dir)
	var song := {
		"id": slug,
		"title": title.strip_edges() if title.strip_edges() != "" else "Untitled",
		"artist": "Custom",
		"bpm": 120.0,
		"preview_start": 0.0,
		"length": 60.0,
		"audio": "",
		"dir": dir,
		"difficulties": [{"name": "Custom", "notes": []}],
	}
	write_map(song)
	return song


static func _slugify(s: String) -> String:
	var lower := s.to_lower()
	var clean := ""
	for ch in lower:
		clean += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") \
			or ch == "-" or ch == "_" else "_"
	while clean.contains("__"):
		clean = clean.replace("__", "_")
	return clean.strip_edges().trim_suffix("_")


## Save the whole song dictionary to dir/map.json.
static func write_map(song: Dictionary) -> String:
	var dir: String = str(song.get("dir", ""))
	if dir == "":
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/map.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	var clean := song.duplicate()
	clean.erase("dir")
	# "video" is detected from the folder on load, but a forked song has to
	# remember the file it copied, so only drop the probe result
	if not FileAccess.file_exists(dir + "/" + str(song.get("video", ""))):
		clean.erase("video")
	f.store_string(JSON.stringify(clean, "\t"))
	return path


## Copy a built-in song into the player's library so it can be edited.
##
## A res:// song lives inside the exported binary and cannot be written to, so
## editing one has to fork it: the audio, the video and the metadata are copied
## into a fresh folder and the editor carries on there.
static func fork_song(song: Dictionary) -> Dictionary:
	var src := str(song.get("dir", ""))
	if src == "":
		return {}
	var copy := create_new_song(str(song.get("title", "Song")) + " (edit)")
	var dst := str(copy["dir"])
	for key in ["audio", "video"]:
		var name := str(song.get(key, ""))
		if name == "":
			continue
		var bytes := FileAccess.get_file_as_bytes(src + "/" + name)
		if bytes.is_empty():
			# exported build: the original is packed as an imported resource,
			# so there are no raw bytes to copy - reference it instead
			copy[key] = ""
			copy[key + "_ref"] = src + "/" + name
			continue
		var f := FileAccess.open(dst + "/" + name, FileAccess.WRITE)
		if f != null:
			f.store_buffer(bytes)
			f.close()
			copy[key] = name
	copy["title"] = str(song.get("title", "Song"))
	copy["artist"] = str(song.get("artist", ""))
	copy["bpm"] = float(song.get("bpm", 120.0))
	copy["preview_start"] = float(song.get("preview_start", 0.0))
	copy["length"] = float(song.get("length", 60.0))
	copy["forked_from"] = str(song.get("id", ""))
	var diffs: Array = []
	for d in song.get("difficulties", []):
		diffs.append({"name": str(d.get("name", CUSTOM_NAME)),
			"notes": (d.get("notes", []) as Array).duplicate(true)})
	if diffs.is_empty():
		diffs = [{"name": CUSTOM_NAME, "notes": []}]
	copy["difficulties"] = diffs
	write_map(copy)
	return copy


## Save notes into one difficulty. res-songs get a side map_custom.json; user
## songs are the single source of truth in their own map.json.
static func save_custom(song: Dictionary, notes: Array, diff_idx := 0) -> String:
	if is_user_song(song):
		var diffs: Array = song.get("difficulties", [])
		if diffs.is_empty():
			diffs = [{"name": CUSTOM_NAME, "notes": []}]
			song["difficulties"] = diffs
		var i := clampi(diff_idx, 0, diffs.size() - 1)
		diffs[i]["notes"] = notes
		return write_map(song)
	var data := {
		"id": song.get("id", "unknown"),
		"title": song.get("title", "Unknown"),
		"artist": song.get("artist", ""),
		"bpm": song.get("bpm", 120.0),
		"audio": song.get("audio", "audio.wav"),
		"difficulties": [{"name": CUSTOM_NAME, "notes": notes}],
	}
	var path: String = str(song["dir"]) + "/map_custom.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	return path
