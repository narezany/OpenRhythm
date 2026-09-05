class_name Updater
extends Node
## Checks GitHub for a newer release and, if the player wants it, downloads and
## installs it.
##
## The game cannot overwrite its own running executable and then keep going, so
## on desktop the new build is unpacked next to the old one and a tiny helper
## script waits for this process to exit, swaps the file and starts it again.
## On Android the downloaded APK is handed to the system package installer -
## installing is the system's job, not ours.
##
## Nothing happens without a click: the check is a single HTTPS request to the
## GitHub API, and it can be turned off in the settings.

signal check_done(available: bool, version: String)
signal progress(done: int, total: int)
signal failed(reason: String)
signal ready_to_install(path: String)

const API := "https://api.github.com/repos/%s/releases/latest"
const DOWNLOAD_DIR := "user://update"

var latest := ""
var notes := ""
var asset_url := ""
var asset_name := ""

var _http: HTTPRequest
var _downloading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 30.0
	add_child(_http)


## Semantic comparison: 1 if a is newer than b, -1 if older, 0 if the same.
static func compare(a: String, b: String) -> int:
	var pa := a.strip_edges().trim_prefix("v").split(".")
	var pb := b.strip_edges().trim_prefix("v").split(".")
	for i in 3:
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


## Which release asset suits the machine we are running on.
static func platform_key() -> String:
	if OS.has_feature("android"):
		return "android"
	if OS.has_feature("windows"):
		return "windows"
	if OS.has_feature("linux"):
		return "linux"
	return ""


func can_update() -> bool:
	# a browser build updates by reloading the page, and an editor run is not
	# something to overwrite
	return platform_key() != "" and not OS.has_feature("editor") \
		and not OS.has_feature("web")


func check() -> void:
	if not can_update():
		check_done.emit(false, "")
		return
	_http.request_completed.connect(_on_check, CONNECT_ONE_SHOT)
	var err := _http.request(API % G.REPO, ["Accept: application/vnd.github+json"])
	if err != OK:
		_http.request_completed.disconnect(_on_check)
		check_done.emit(false, "")


func _on_check(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		check_done.emit(false, "")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary):
		check_done.emit(false, "")
		return
	latest = str(data.get("tag_name", "")).trim_prefix("v")
	notes = str(data.get("body", ""))
	asset_url = ""
	asset_name = ""
	var key := platform_key()
	for a in data.get("assets", []):
		var name := str(a.get("name", "")).to_lower()
		if key == "android":
			if name.ends_with(".apk"):
				asset_url = str(a.get("browser_download_url", ""))
				asset_name = str(a.get("name", ""))
		elif name.contains(key) and name.ends_with(".zip"):
			asset_url = str(a.get("browser_download_url", ""))
			asset_name = str(a.get("name", ""))
	var newer := latest != "" and compare(latest, G.VERSION) > 0
	check_done.emit(newer and asset_url != "", latest)


func download() -> void:
	if _downloading or asset_url == "":
		return
	_downloading = true
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_DIR)
	var path := DOWNLOAD_DIR + "/" + asset_name
	_http.download_file = path
	_http.request_completed.connect(_on_download.bind(path), CONNECT_ONE_SHOT)
	var err := _http.request(asset_url)
	if err != OK:
		_downloading = false
		_http.request_completed.disconnect(_on_download)
		failed.emit("Could not start the download")


func _process(_delta: float) -> void:
	if _downloading:
		progress.emit(_http.get_downloaded_bytes(), _http.get_body_size())


func _on_download(result: int, code: int, _h: PackedStringArray,
		_b: PackedByteArray, path: String) -> void:
	_downloading = false
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		failed.emit("Download failed")
		return
	if not FileAccess.file_exists(path) or FileAccess.open(path, FileAccess.READ).get_length() < 1024:
		failed.emit("The downloaded file is empty")
		return
	ready_to_install.emit(path)


## Hand the update over. On Android that means the package installer; on
## desktop, a helper that waits for us to quit and swaps the binary.
func install(path: String) -> void:
	match platform_key():
		"android":
			_install_android(path)
		"linux":
			_install_desktop(path, false)
		"windows":
			_install_desktop(path, true)
		_:
			failed.emit("Nothing to install on this platform")


func _install_android(path: String) -> void:
	# somewhere the installer can actually read it
	var dst := "/storage/emulated/0/Download/" + asset_name
	DirAccess.make_dir_recursive_absolute("/storage/emulated/0/Download")
	var bytes := FileAccess.get_file_as_bytes(path)
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f == null or bytes.is_empty():
		failed.emit("Could not write the APK to Downloads")
		return
	f.store_buffer(bytes)
	f.close()
	OS.shell_open("file://" + dst)
	ready_to_install.emit(dst)


func _install_desktop(zip_path: String, windows: bool) -> void:
	var exe := OS.get_executable_path()
	var unpack := DOWNLOAD_DIR + "/unpacked"
	_rm_rf(unpack)
	DirAccess.make_dir_recursive_absolute(unpack)
	if RhythmMap.extract_zip(zip_path, unpack) != OK:
		failed.emit("Could not unpack the update")
		return
	var new_exe := _find_executable(unpack, windows)
	if new_exe == "":
		failed.emit("The update did not contain a game binary")
		return
	var abs_new := ProjectSettings.globalize_path(new_exe)
	var pid := OS.get_process_id()
	if windows:
		var bat := ProjectSettings.globalize_path(DOWNLOAD_DIR + "/apply.bat")
		var w := FileAccess.open(bat, FileAccess.WRITE)
		w.store_string(":wait\r\ntasklist /FI \"PID eq %d\" | find \"%d\" >nul && (timeout /t 1 >nul & goto wait)\r\nmove /Y \"%s\" \"%s\"\r\nstart \"\" \"%s\"\r\n"
			% [pid, pid, abs_new, exe, exe])
		w.close()
		OS.create_process("cmd.exe", ["/c", bat])
	else:
		var sh := "while kill -0 %d 2>/dev/null; do sleep 0.2; done; cp -f '%s' '%s'; chmod +x '%s'; exec '%s'" \
			% [pid, abs_new, exe, exe, exe]
		OS.create_process("/bin/sh", ["-c", sh])
	get_tree().quit()


static func _find_executable(dir: String, windows: bool) -> String:
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var full := dir + "/" + f
		if d.current_is_dir():
			var deeper := _find_executable(full, windows)
			if deeper != "":
				return deeper
		else:
			var ext := f.get_extension().to_lower()
			if windows and ext == "exe":
				return full
			if not windows and (ext == "x86_64" or ext == ""):
				return full
		f = d.get_next()
	return ""


static func _rm_rf(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			_rm_rf(path + "/" + f)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + "/" + f))
		f = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
