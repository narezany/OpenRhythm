class_name Charter
extends RefCounted
## Turns note times into a playable chart: which cell each cube lands in, how
## big it is, where the holds go and which cubes are clickable.
##
## This is the GDScript half of tools/charting.py, so the auto button in the
## editor produces the same kind of chart as the ones that ship with the game
## rather than a cube per attack in a fixed rotation.
##
## Two rules do the work. There is one cursor, so how far the next cube may sit
## from the last one depends on how much time there is to get there. And a
## movement pattern is chosen per two bars and seeded per song, so a chart
## sweeps and circles instead of jittering from cell to cell.

## Cell ids on the 3x3 grid: row * 3 + col, 0 is top-left, 4 is the centre.
const PATTERNS := {
	"row_top": [0, 1, 2, 1],
	"row_mid": [3, 4, 5, 4],
	"row_bot": [6, 7, 8, 7],
	"col_left": [0, 3, 6, 3],
	"col_mid": [1, 4, 7, 4],
	"col_right": [2, 5, 8, 5],
	"diag_a": [0, 4, 8, 4],
	"diag_b": [2, 4, 6, 4],
	"corners": [0, 2, 8, 6],
	"star": [4, 0, 4, 8, 4, 2, 4, 6],
	"edges": [1, 5, 7, 3],
	"box": [0, 1, 2, 5, 8, 7, 6, 3],
	"snake": [0, 1, 2, 5, 4, 3, 6, 7, 8],
	"wide": [0, 8, 2, 6],
	"bounce": [3, 4, 5, 4],
	"spiral": [0, 1, 2, 5, 8, 7, 6, 3, 4],
	"vee": [0, 4, 2, 5, 8, 4, 6, 3],
}

const POOLS := {
	0: ["row_mid", "col_mid", "diag_a", "diag_b", "row_top", "row_bot", "edges"],
	1: ["row_top", "row_mid", "row_bot", "col_left", "col_mid", "col_right",
		"diag_a", "diag_b", "corners", "edges", "box", "star", "snake"],
	2: ["snake", "box", "spiral", "vee", "star", "corners", "row_top", "row_bot",
		"col_left", "col_right", "diag_a", "diag_b", "wide", "bounce"],
}

const SIZE_MUL := [1.25, 1.05, 0.92]
## How far the next cube may be, by how much time there is to travel. Distance
## is measured across the grid, so 4 is corner to opposite corner.
const REACH_T := [0.18, 0.28, 0.45]
const REACH_D := [1, 2, 3]
## One hold per this many bars, and how long it runs, in beats.
const HOLD_BARS := [8, 8, 12]
const HOLD_LEN_BEATS := [2.0, 2.0, 1.5]
const HOLD_TAIL := 0.5
## One in this many on-beat notes carries a click marker. Easy carries none.
const CLICK_EVERY := [0, 6, 5]


## times: [{t, v, slot}] as Beat.select returns. Returns chart notes.
static func build(times: Array, level: int, beat: float, seed_key: String,
		holds := true, clicks := true) -> Array:
	if times.is_empty():
		return []
	var phrase_len := beat * 4.0 * 2.0
	var click_every: int = CLICK_EVERY[level] if clicks else 0
	var res := _place_holds(times, level, beat, holds, seed_key)
	var out: Array = res[0]
	var blocked: Array = res[1]

	var prev_cell := -1
	var last_t := -9.0
	var step := 0
	var cur_phrase := -1
	var pattern: Array = PATTERNS["row_mid"]
	var strong := 0
	for item in times:
		var t := float(item["t"])
		if _inside(blocked, t):
			continue
		var gap := t - last_t
		var phrase := int(t / phrase_len) if phrase_len > 0.0 else 0
		if phrase != cur_phrase:
			cur_phrase = phrase
			var h := _hash(seed_key, level, phrase)
			var pool: Array = POOLS[level]
			pattern = PATTERNS[pool[h % pool.size()]]
			step = (h >> 8) % pattern.size()
		var target: int = pattern[step % pattern.size()]
		step += 1
		var cell := _pick_cell(target, prev_cell, gap)
		var on_beat: bool = int(item.get("slot", 0)) % 4 == 0
		var size: float = SIZE_MUL[level] * (1.08 if on_beat else 0.94)
		var note := {"t": snappedf(t, 0.001), "cell": cell,
			"s": snappedf(size, 0.01)}
		if click_every > 0 and on_beat:
			strong += 1
			if strong % click_every == 0:
				note["c"] = true
		out.append(note)
		prev_cell = cell
		last_t = t
	out.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	return _enforce_reach(out)


static func _dist(a: int, b: int) -> int:
	return absi(a / 3 - b / 3) + absi(a % 3 - b % 3)


static func _reach_for(gap: float) -> int:
	for i in REACH_T.size():
		if gap < REACH_T[i]:
			return REACH_D[i]
	return 4


## Nearest cell to the one the pattern wanted that the cursor can actually
## reach in the time available.
static func _pick_cell(target: int, prev: int, gap: float) -> int:
	if prev < 0:
		return target
	var max_d := _reach_for(gap)
	if _dist(target, prev) <= max_d and target != prev:
		return target
	var best := -1
	var best_a := 99
	var best_b := 0
	for c in 9:
		if c == prev:
			continue
		var d := _dist(c, prev)
		if d > max_d:
			continue
		# closest to where the pattern wanted to go, then the bigger move: a
		# chart that always takes the smallest step feels limp
		var a := _dist(c, target)
		if best < 0 or a < best_a or (a == best_a and d > best_b):
			best = c
			best_a = a
			best_b = d
	return best if best >= 0 else prev


static func _inside(windows: Array, t: float) -> bool:
	for w in windows:
		if float(w[0]) <= t and t < float(w[1]):
			return true
		if t < float(w[0]):
			break
	return false


## One hold every few phrases. A hold owns the cursor for its whole length, so
## the window it covers is blocked and nothing else is charted inside it.
static func _place_holds(times: Array, level: int, beat: float, enabled: bool,
		seed_key: String) -> Array:
	if not enabled or times.is_empty():
		return [[], []]
	var bar := beat * 4.0
	var every: float = HOLD_BARS[level] * bar
	var hold_len: float = beat * HOLD_LEN_BEATS[level]
	var end := float(times[times.size() - 1]["t"])
	var on_beat: Array = []
	for item in times:
		if int(item.get("slot", 0)) % 4 == 0:
			on_beat.append(float(item["t"]))
	if on_beat.is_empty():
		return [[], []]
	var out: Array = []
	var windows: Array = []
	var mark := every
	var i := 0
	while mark < end - hold_len - bar:
		var near: float = on_beat[0]
		for t in on_beat:
			if absf(t - mark) < absf(near - mark):
				near = t
		if absf(near - mark) > bar:
			near = mark
		var h := _hash(seed_key, 90 + level, i)
		var cells := [4, 1, 3, 5, 7]
		out.append({"t": snappedf(near, 0.001), "cell": cells[h % cells.size()],
			"s": snappedf(SIZE_MUL[level] * 1.2, 0.01),
			"h": snappedf(hold_len, 0.001)})
		windows.append([near - beat * 0.4, near + hold_len + beat * HOLD_TAIL])
		mark += every
		i += 1
	return [out, windows]


## Final pass over the merged list, holds included: the notes either side of a
## hold never went through the reach check, so walk the finished chart once.
static func _enforce_reach(notes: Array) -> Array:
	var prev := -1
	var prev_end := -9.0
	for n in notes:
		var gap: float = float(n["t"]) - prev_end
		var cell := int(n["cell"])
		if prev >= 0 and _dist(cell, prev) > _reach_for(gap):
			cell = _pick_cell(cell, prev, gap)
			n["cell"] = cell
		prev = cell
		prev_end = float(n["t"]) + float(n.get("h", 0.0))
	return notes


## Small deterministic hash, so the same song always gets the same shapes.
static func _hash(key: String, a: int, b: int) -> int:
	var h := 2166136261
	var s := "%s|%d|%d" % [key, a, b]
	for i in s.length():
		h = (h ^ s.unicode_at(i)) * 16777619
		h = h & 0x7FFFFFFF
	return h
