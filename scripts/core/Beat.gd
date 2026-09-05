class_name Beat
extends RefCounted
## Finds the beat in a piece of music, and picks the times a chart should use.
##
## This is the same analysis tools/rechart.py runs offline on the bundled
## songs, so a map built by the editor's auto button comes out of the same
## reasoning as the ones that ship with the game.
##
## Two ideas do most of the work. The tempo is measured from the audio rather
## than taken from whatever number is in the map file, because a chart snapped
## onto a tempo the music does not have drifts further out of time the longer
## it plays. And a bar is charted at ONE subdivision - sixteenths, eighths,
## quarters - so every gap between notes is a whole number of that
## subdivision. Picking whichever attacks happen to clear a minimum gap
## instead is what produces dotted, stuttering charts that feel like noise
## even when every note is on an attack.

## Analysis frame rate: about 86 frames a second, matching the offline tool.
const HOP := 128
## Loudness a peak needs, relative to the loudest in the track, to be an attack.
const FLOOR := 0.10
## How far off the grid an attack may sit and still count as being on it, as a
## fraction of a sixteenth.
const SNAP := 0.40
## How full a subdivision has to be before a bar is charted at it.
const COVER := 0.50
## Minimum spacing per difficulty, in beats and as an absolute floor.
const GAP_BEATS := [1.00, 0.55, 0.30]
const GAP_FLOOR := [0.55, 0.30, 0.17]

## The flux peak arrives before the sound that causes it: the envelope is built
## from differences between frames, so a change is noticed at the end of the
## frame it happened in. Measured against a click track at known times by the
## beat section of tools/CoreTest.tscn - if the frame rate or the filters here
## change, run it again and put the new figure here, or every chart the editor
## builds will sit that far behind the music.
const LAG := 0.0044

var rate := 11025.0            # analysis sample rate
var fps := 86.13               # envelope frames per second
var env := PackedFloat32Array()
## The same envelope built from the top end alone. Timing is read off this one:
## a snare or a hat starts far more sharply than a bass note, so where the beat
## sits is clearer up there even though the low end is louder.
var env_hi := PackedFloat32Array()
var bpm := 120.0
var first := 0.0               # where the first beat lands, in seconds
var length := 0.0
var ok := false


## Analyse a stream. `hint` is a tempo worth trying first, usually whatever the
## map already claims; it is checked, not trusted.
static func of_stream(stream: AudioStream, hint := 0.0) -> Beat:
	var b := Beat.new()
	if stream == null:
		return b
	b.length = stream.get_length()
	var mono := b._decode(stream)
	if mono.size() < int(b.rate * 3.0):
		return b
	b.env = b._envelope(mono)
	if b.env.size() < 32:
		return b
	b._find_tempo(hint)
	b.ok = b.bpm > 0.0
	return b


## Decode the whole stream to mono, a quarter of the mixer's rate. mix_audio
## runs far faster than real time and works for every format the game can
## open, so ogg and mp3 are analysed as readily as wav.
func _decode(stream: AudioStream) -> PackedFloat32Array:
	var pb := stream.instantiate_playback()
	if pb == null:
		return PackedFloat32Array()
	rate = AudioServer.get_mix_rate() / 4.0
	fps = rate / float(HOP)
	pb.start(0.0)
	var out := PackedFloat32Array()
	var acc := 0.0
	var n := 0
	var guard := int(stream.get_length() * AudioServer.get_mix_rate()) + 8192
	var read := 0
	while read < guard:
		var buf: PackedVector2Array = pb.mix_audio(1.0, 8192)
		if buf.size() == 0:
			break
		read += buf.size()
		for v in buf:
			acc += v.x + v.y
			n += 1
			if n == 4:
				out.append(acc * 0.125)
				acc = 0.0
				n = 0
	pb.stop()
	return out


## Onset strength over time: how much energy appeared since the previous frame,
## counted low and high separately so a loud bass line cannot drown out the
## hats and vice versa.
func _envelope(mono: PackedFloat32Array) -> PackedFloat32Array:
	var raw := PackedFloat32Array()
	var raw_hi := PackedFloat32Array()
	var lp := 0.0
	var e_lo := 0.0
	var e_hi := 0.0
	var k := 0
	# one pole at roughly 150 Hz splits the kick from everything above it
	var a: float = clampf(2.0 * PI * 150.0 / rate, 0.01, 0.5)
	var prev_lo := 0.0
	var prev_hi := 0.0
	for i in mono.size():
		var x: float = mono[i]
		lp += a * (x - lp)
		e_lo += lp * lp
		var h: float = x - lp
		e_hi += h * h
		k += 1
		if k == HOP:
			var lo := log(1.0 + 8.0 * sqrt(e_lo / HOP))
			var hi := log(1.0 + 8.0 * sqrt(e_hi / HOP))
			raw.append(maxf(0.0, lo - prev_lo) + maxf(0.0, hi - prev_hi))
			raw_hi.append(maxf(0.0, hi - prev_hi))
			prev_lo = lo
			prev_hi = hi
			e_lo = 0.0
			e_hi = 0.0
			k = 0
	# take out the slow swell of the track, so a quiet verse is measured on its
	# own terms instead of being outvoted by a loud chorus
	var win := int(fps * 0.4) | 1
	var half := win / 2
	var out := PackedFloat32Array()
	out.resize(raw.size())
	var run := 0.0
	for i in raw.size():
		if i == 0:
			for j in range(-half, half + 1):
				run += raw[clampi(j, 0, raw.size() - 1)]
		else:
			run += raw[clampi(i + half, 0, raw.size() - 1)]
			run -= raw[clampi(i - half - 1, 0, raw.size() - 1)]
		out[i] = maxf(0.0, raw[i] - run / float(win))
	var peak := 0.0
	for v in out:
		peak = maxf(peak, v)
	if peak > 0.0:
		for i in out.size():
			out[i] = out[i] / peak
	env_hi = _flatten(raw_hi)
	return out


## Same smoothing and scaling as the main envelope.
func _flatten(raw: PackedFloat32Array) -> PackedFloat32Array:
	var win := int(fps * 0.4) | 1
	var half := win / 2
	var out := PackedFloat32Array()
	out.resize(raw.size())
	var run := 0.0
	for i in raw.size():
		if i == 0:
			for j in range(-half, half + 1):
				run += raw[clampi(j, 0, raw.size() - 1)]
		else:
			run += raw[clampi(i + half, 0, raw.size() - 1)]
			run -= raw[clampi(i - half - 1, 0, raw.size() - 1)]
		out[i] = maxf(0.0, raw[i] - run / float(win))
	var peak := 0.0
	for v in out:
		peak = maxf(peak, v)
	if peak > 0.0:
		for i in out.size():
			out[i] = out[i] / peak
	return out


# ---------------------------------------------------------------- tempo
## Strength and phase of a candidate tempo, read as a single frequency of the
## onset envelope. The angle of the sum says where inside the beat the attacks
## sit, which is exact rather than rounded to a frame.
func _comb(cand: float) -> Array:
	var f := cand / 60.0
	var re := 0.0
	var im := 0.0
	for i in env.size():
		var t := float(i) / fps
		var ang := -TAU * f * t
		re += env[i] * cos(ang)
		im += env[i] * sin(ang)
	var period := 60.0 / cand
	var ph := (-atan2(im, re) / TAU) * period + LAG
	return [sqrt(re * re + im * im) / float(env.size()), fposmod(ph, period)]


func _find_tempo(hint: float) -> void:
	var coarse := _autocorr_bpm()
	# Self-similarity peaks just as happily at two beats or half a beat as at
	# one, so the rough answer is offered at every nearby octave and the lock
	# below decides which of them the music actually holds.
	var seeds: Array[float] = [coarse, coarse * 2.0, coarse * 0.5, coarse * 4.0]
	if hint > 20.0:
		seeds.append(hint)
		seeds.append(hint * 2.0)
		seeds.append(hint * 0.5)
	var best_rel := INF
	for s in seeds:
		if s < 40.0 or s > 400.0:
			continue
		var r := _lock(s)
		var cand: float = r[0]
		var rel: float = r[2] / (60.0 / cand)
		if rel < best_rel:
			best_rel = rel
			bpm = cand
			first = r[1]
	if best_rel == INF:
		# too short to watch the beat drift; take the rough tempo and read its
		# phase straight off the whole track
		bpm = clampf(coarse, 40.0, 400.0)
		first = _comb(bpm)[1]
	_choose_octave()
	first = _phase_from_onsets()


## Rough tempo from the envelope's self-similarity: the lag at which the track
## most resembles itself is one beat.
func _autocorr_bpm() -> float:
	var lo := int(fps * 60.0 / 210.0)
	var hi := int(fps * 60.0 / 60.0)
	var best := 0.0
	var best_lag := lo
	for lag in range(lo, mini(hi, env.size() / 2)):
		var s := 0.0
		for i in range(0, env.size() - lag, 2):
			s += env[i] * env[i + lag]
		s /= float(env.size() - lag)
		if s > best:
			best = s
			best_lag = lag
	return 60.0 * fps / float(best_lag)


## Refine a tempo until the beat stops sliding through the song.
##
## A tempo that is a little wrong shows up as the beat position drifting
## steadily from one window to the next; the size of that drift says exactly
## how wrong it is, so a few passes converge on the tempo the track holds.
func _lock(seed: float) -> Array:
	var cand := seed
	# Long windows measure the drift more finely, but a short track has to be
	# cut into enough of them to draw a line through at all.
	var win: float = clampf(float(env.size()) / fps / 6.0, 2.0, 12.0)
	for pass_ in 16:
		var ph := _phases(cand, win)
		if ph.size() < 3:
			return [cand, _comb(cand)[1], INF]
		var fit := _fit(ph, win)
		var step := 60.0 / cand
		var slope: float = fit[0]
		var next: float = 60.0 / (step + slope * step * step)
		if absf(next - cand) < 1e-5 or next < 40.0 or next > 400.0:
			cand = next if next > 40.0 and next < 400.0 else cand
			break
		cand = next
	var ph2 := _phases(cand, win)
	if ph2.size() < 3:
		return [cand, _comb(cand)[1], INF]
	var fit2 := _fit(ph2, win)
	var slope2: float = fit2[0]
	var icept2: float = fit2[1]
	var spread := 0.0
	for i in ph2.size():
		var d: float = ph2[i] - (slope2 * float(i) * win + icept2)
		spread += d * d
	spread = sqrt(spread / float(ph2.size()))
	return [cand, fposmod(icept2 + LAG, 60.0 / cand), spread]


## Where the beat sits inside each window of the song, unwrapped so the drift
## reads as a straight line rather than jumping at every wrap.
func _phases(cand: float, win: float) -> PackedFloat32Array:
	var step := 60.0 / cand
	var w := int(fps * win)
	var out := PackedFloat32Array()
	if w < 8 or env.size() < w * 2:
		return out
	var f := cand / 60.0
	var s0 := 0
	var prev := 0.0
	while s0 + w < env.size():
		var re := 0.0
		var im := 0.0
		for i in range(s0, s0 + w):
			var ang := -TAU * f * (float(i) / fps)
			re += env[i] * cos(ang)
			im += env[i] * sin(ang)
		var p := fposmod((-atan2(im, re) / TAU) * step, step)
		if out.size() > 0:
			# unwrap: keep the value nearest the previous one
			while p - prev > step * 0.5:
				p -= step
			while prev - p > step * 0.5:
				p += step
		out.append(p)
		prev = p
		s0 += w
	return out


## Least squares line through the phases: [slope, intercept].
func _fit(ph: PackedFloat32Array, win: float) -> Array:
	var n := float(ph.size())
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	for i in ph.size():
		var x := float(i) * win
		sx += x
		sy += ph[i]
		sxx += x * x
		sxy += x * ph[i]
	var d := n * sxx - sx * sx
	if absf(d) < 1e-9:
		return [0.0, sy / maxf(n, 1.0)]
	var slope := (n * sxy - sx * sy) / d
	return [slope, (sy - slope * sx) / n]


## Every octave of a tempo fits the onsets equally well - 85, 170 and 340 are
## the same groove. The one worth writing down is the one a listener taps, so
## the fastest that still leans evenly on its beats wins.
func _choose_octave() -> void:
	var cands: Array[float] = []
	for k in range(-3, 4):
		var b: float = bpm * pow(2.0, k)
		if b >= 85.0 and b < 185.0:
			cands.append(b)
	if cands.is_empty():
		return
	cands.sort()
	cands.reverse()
	for b in cands:
		var f: float = first if is_equal_approx(b, bpm) else _comb(b)[1]
		var alt := _alternation(b, f)
		if alt[0] < 0.0 or alt[0] >= 0.65:
			bpm = b
			first = alt[1] if alt[0] >= 0.0 else f
			return
	bpm = cands[0]
	first = _comb(bpm)[1]


## How much weaker the weaker half of a grid is, and where the stronger half
## starts. [-1, first] when there is not enough song to tell.
func _alternation(cand: float, ph: float) -> Array:
	var step := 60.0 / cand
	var sum := [0.0, 0.0]
	var cnt := [0, 0]
	var k := 0
	while true:
		var i := int(round((ph + float(k) * step - LAG) * fps))
		if i >= env.size():
			break
		if i >= 0:
			sum[k % 2] += env[i]
			cnt[k % 2] += 1
		k += 1
	if cnt[0] < 8 or cnt[1] < 8:
		return [-1.0, ph]
	var m0: float = sum[0] / float(cnt[0])
	var m1: float = sum[1] / float(cnt[1])
	if maxf(m0, m1) <= 0.0:
		return [-1.0, ph]
	if m0 >= m1:
		return [m1 / m0, ph]
	return [m0 / m1, ph + step]


## Slide the grid onto the attacks themselves.
##
## Locking the tempo gets the rate right but can leave the whole grid a few
## milliseconds beside the drums, and the drums are what the player hears. The
## search is over the beats rather than every sixteenth: beats carry the loud,
## regular hits, so the energy landing on them changes sharply with the phase,
## while a sixteenth grid on a busy track collects much the same energy
## whatever the phase and says nothing useful.
func _phase_from_onsets() -> float:
	var beat := 60.0 / bpm
	var step := beat / 4.0
	if env.is_empty() or step <= 0.0:
		return first
	var src := env_hi if env_hi.size() == env.size() else env
	var best := -1.0
	var best_ph := first
	for i in 65:
		var ph: float = first + step * (float(i) / 64.0 - 0.5)
		var sum := 0.0
		var k := 0
		while true:
			var idx := int(round((ph + float(k) * beat - LAG) * fps))
			if idx >= src.size():
				break
			if idx >= 0:
				# a short window, so a hit a frame either side still counts
				sum += src[idx]
				if idx > 0:
					sum += src[idx - 1] * 0.5
				if idx + 1 < src.size():
					sum += src[idx + 1] * 0.5
			k += 1
		if sum > best:
			best = sum
			best_ph = ph
	return fposmod(best_ph, beat)


# ---------------------------------------------------------------- attacks
## Times of the clear attacks in the track.
func onsets(floor_ := FLOOR) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(1, env.size() - 1):
		if env[i] > env[i - 1] and env[i] >= env[i + 1] and env[i] > floor_:
			out.append(float(i) / fps + LAG)
	return out


## Onset strength on every sixteenth of the song, zero where nothing happens.
func slots(floor_ := FLOOR) -> PackedFloat32Array:
	var step := 60.0 / bpm / 4.0
	var n := maxi(1, int((length - first) / step) + 2)
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	for t in onsets(floor_):
		var k := int(round((t - first) / step))
		if k < 0 or k >= n:
			continue
		if absf(first + float(k) * step - t) > step * SNAP:
			continue
		var i := clampi(int(round((t - LAG) * fps)), 0, env.size() - 1)
		out[k] = maxf(out[k], env[i])
	return out


## Note times for one difficulty, decided a bar at a time.
##
## Each bar is charted at one subdivision: the fastest the difficulty allows
## that the music actually fills. Notes then go on the slots of that
## subdivision which have an attack, so every gap in the finished bar is a
## whole number of that subdivision.
func select(level: int, floor_ := FLOOR) -> Array:
	var sl := slots(floor_)
	var step := 60.0 / bpm / 4.0
	var min_gap: float = maxf(GAP_FLOOR[level], (60.0 / bpm) * GAP_BEATS[level])
	var allowed: Array[int] = []
	for d in [1, 2, 4, 8]:
		if float(d) * step >= min_gap - 1e-6:
			allowed.append(d)
	if allowed.is_empty():
		allowed.append(8)
	var out: Array = []
	var bar := 0
	while bar < sl.size():
		var last: int = mini(bar + 16, sl.size())
		var any := false
		for j in range(bar, last):
			if sl[j] > 0.0:
				any = true
				break
		if not any:
			bar += 16
			continue
		var pick: int = allowed[allowed.size() - 1]
		for d in allowed:
			var hit := 0
			var tot := 0
			var j := bar
			while j < last:
				tot += 1
				if sl[j] > 0.0:
					hit += 1
				j += d
			if tot > 0 and float(hit) / float(tot) >= COVER:
				pick = d
				break
		var j2 := bar
		while j2 < last:
			if sl[j2] > 0.0:
				out.append({"t": first + float(j2) * step, "v": sl[j2],
					"slot": j2 % 16})
			j2 += pick
		bar += 16
	return out
