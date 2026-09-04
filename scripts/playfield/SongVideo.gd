class_name SongVideo
extends Node2D
## Song video behind the playfield, taken from the song folder (.ogv).
## Covers the design resolution and is kept in sync with the conductor, so a
## pause or a hitch does not leave the picture drifting away from the music.

const RESYNC_EVERY := 1.5      # seconds between sync checks
const RESYNC_TOLERANCE := 0.35 # drift allowed before seeking

var song: Dictionary
var _vp: VideoStreamPlayer
var _backdrop: ColorRect
var _check := 0.0
var _paused := false


func _init(p_song: Dictionary) -> void:
	song = p_song
	z_index = -90


func _ready() -> void:
	var stream := RhythmMap.video_stream(song)
	if stream == null:
		queue_free()
		return

	# solid backdrop so nothing shows through the letterboxed edges
	_backdrop = ColorRect.new()
	_backdrop.size = G.DESIGN * 1.25
	_backdrop.position = -G.DESIGN * 0.125
	_backdrop.color = Color(0.02, 0.0, 0.004, 1.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_vp = VideoStreamPlayer.new()
	_vp.stream = stream
	_vp.volume_db = -60.0          # music comes from the audio file, not the clip
	_vp.bus = "Music"
	_vp.expand = true
	var cover := G.DESIGN * 1.25
	_vp.size = cover
	_vp.position = -G.DESIGN * 0.125
	_vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vp)
	_vp.finished.connect(_on_finished)
	_vp.play()


func _process(delta: float) -> void:
	if _vp == null or not is_instance_valid(_vp) or _paused or not _vp.is_playing():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = RESYNC_EVERY
	var want := Conductor.play_time()
	if want < 0.0:
		return
	# Theora seeks are expensive, so only correct real drift.
	if absf(_vp.stream_position - want) > RESYNC_TOLERANCE:
		_vp.stream_position = want


## The clip is usually shorter than the song: loop it back to where the music is.
func _on_finished() -> void:
	if _vp == null or not is_instance_valid(_vp):
		return
	_vp.play()
	_check = RESYNC_EVERY


func set_paused(p: bool) -> void:
	_paused = p
	if _vp != null and is_instance_valid(_vp):
		_vp.paused = p


func fade_out(dur := 0.5) -> void:
	if _vp != null:
		_vp.stop()
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, dur)
	tw.tween_callback(queue_free)
