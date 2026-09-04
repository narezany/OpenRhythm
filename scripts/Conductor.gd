extends Node
## Conductor - the musical clock. Two players hand the track over to each other
## so looping is seamless; everything downstream reads song time from here.

var music: AudioStreamPlayer
var song_time := 0.0
var playing := false
var bpm := 120.0
var length := 0.0
var looping := true
var rate := 1.0

var _echo: AudioStreamPlayer
var _use_echo := false          # which player currently drives the clock
var _stuck := 0.0
var _fallback := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	_echo = AudioStreamPlayer.new()
	_echo.bus = "Music"
	add_child(_echo)


func play_music(stream: AudioStream, from := 0.0, bpm_ := 120.0, db := 0.0,
		loop := true, rate_ := 1.0) -> void:
	stop_music()
	looping = loop
	rate = maxf(rate_, 0.1)
	music.stream = stream
	music.volume_db = db
	music.pitch_scale = rate
	_echo.stream = stream
	_echo.volume_db = db
	_echo.pitch_scale = rate
	bpm = maxf(bpm_, 1.0)
	length = stream.get_length() if stream != null else 0.0
	_fallback = stream == null
	_stuck = 0.0
	_use_echo = false
	song_time = from
	if stream != null:
		music.play(from)
	playing = true


func stop_music() -> void:
	music.stop()
	_echo.stop()
	playing = false
	_use_echo = false
	rate = 1.0
	music.pitch_scale = 1.0
	_echo.pitch_scale = 1.0


func set_paused(p: bool) -> void:
	music.stream_paused = p
	_echo.stream_paused = p


func seek(t: float) -> void:
	song_time = t
	_echo.stop()
	_use_echo = false
	if playing and music.stream != null:
		music.seek(t)
	_fallback = false
	_stuck = 0.0


## Time the player actually *hears*. Notes are judged and drawn against this so
## a calibrated output delay shifts gameplay, not just the audio.
func play_time() -> float:
	return song_time - G.audio_offset


## Menu background music: Hyper Drive (the tutorial track is for the tutorial).
func ensure_menu_music() -> void:
	if playing:
		return
	var songs: Array = RhythmMap.load_songs()
	if songs.is_empty():
		return
	var s0: Dictionary = songs[0]
	for s in songs:
		if str(s.get("id", "")) == "hyper_drive":
			s0 = s
			break
	play_music(RhythmMap.audio_stream(s0), float(s0.get("preview_start", 0.0)),
		float(s0.get("bpm", 120.0)), -14.0, true)


func _process(delta: float) -> void:
	if not playing:
		return
	var p := _echo if _use_echo else music
	if p.stream_paused:
		return
	var raw := p.get_playback_position()
	var t := raw + AudioServer.get_time_since_last_mix() * rate \
		- minf(AudioServer.get_output_latency(), 0.25) * rate
	# guard against a dead track: if the player never started, run off delta
	if raw <= 0.001:
		_stuck += delta
	else:
		_stuck = 0.0
	if _stuck > 0.6:
		_fallback = true
	if _fallback:
		song_time += delta * rate
	else:
		if t < song_time - 0.05:
			t = song_time
		song_time = t
	# --- seamless loop: the idle player starts one output-latency early, so its
	# first audible sample lands exactly where the leader runs out ---
	if looping and length > 0.0 and not _fallback and p.stream != null:
		var remain := length - song_time
		var ahead := music if _use_echo else _echo
		if remain <= AudioServer.get_output_latency() + 0.02 and not ahead.playing:
			ahead.play(0.0)
		if song_time >= length:
			p.stop()
			_use_echo = not _use_echo
			song_time = fposmod(song_time, length)
			_fallback = false
			_stuck = 0.0


func beat() -> float:
	return play_time() * bpm / 60.0


func phase() -> float:
	return fposmod(beat(), 1.0)


func bar_phase() -> float:
	return fposmod(beat() / 4.0, 1.0)
