extends Node
## Round-trip check for the map importers. Run with:
##   godot --headless --path . res://tools/ImportTest.tscn -- <file.sspm>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://test_tmp.sspm"
	print("importing: ", path, "  exists=", FileAccess.file_exists(path))
	var res := MapImport.import_path(path)
	print("ok=", res.get("ok", false), "  error=", res.get("error", ""))
	if not res.get("ok", false):
		get_tree().quit(1)
		return
	var song: Dictionary = res["song"]
	print("title=", song.get("title"), " | artist=", song.get("artist"))
	print("bpm=", song.get("bpm"), " length=", song.get("length"),
		" audio=", song.get("audio"), " needs_audio=", res.get("needs_audio"))
	print("dir=", song.get("dir"))
	for d in song.get("difficulties", []):
		var notes: Array = d.get("notes", [])
		print("diff '", d.get("name"), "' notes=", notes.size())
		for n in notes:
			print("   t=%.3f cell=%d s=%.2f" % [float(n.t), int(n.cell), float(n.s)])
	var reread = JSON.parse_string(FileAccess.get_file_as_string(str(song.dir) + "/map.json"))
	print("map.json ok=", reread is Dictionary,
		" notes_on_disk=", reread["difficulties"][0]["notes"].size())
	print("audio_on_disk=", FileAccess.file_exists(str(song.dir) + "/" + str(song.audio)))
	print("library_sees_it=", _in_library(str(song.get("id", ""))))
	get_tree().quit(0)


func _in_library(id: String) -> bool:
	for s in RhythmMap.load_songs():
		if str(s.get("id", "")) == id:
			return true
	return false
