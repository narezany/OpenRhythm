#!/usr/bin/env python3
"""Chart builder shared by the OST generators and the re-charter.

Two rules drive everything here.

*Reachability.* There is one cursor. How far the next cube may sit from the
last one is decided by how much time there is to get there: notes 0.15 s apart
land next door, notes half a second apart can be anywhere. Ignoring this is
what turns a dense chart into a pile of cubes nobody enjoys dragging a mouse
across.

*Phrasing.* A movement pattern is chosen per two bars and seeded per song, so a
chart sweeps and circles instead of jittering, and no two tracks share a shape.

Holds sit at phrase ends and own the cursor for their whole length - nothing
else is charted while one runs.
"""
import hashlib

# Cell ids on the 3x3 grid: row * 3 + col, 0 = top-left, 4 = centre.
PATTERNS = {
    "row_top":   [0, 1, 2, 1],
    "row_mid":   [3, 4, 5, 4],
    "row_bot":   [6, 7, 8, 7],
    "col_left":  [0, 3, 6, 3],
    "col_mid":   [1, 4, 7, 4],
    "col_right": [2, 5, 8, 5],
    "diag_a":    [0, 4, 8, 4],
    "diag_b":    [2, 4, 6, 4],
    "corners":   [0, 2, 8, 6],
    "star":      [4, 0, 4, 8, 4, 2, 4, 6],
    "edges":     [1, 5, 7, 3],
    "box":       [0, 1, 2, 5, 8, 7, 6, 3],
    "snake":     [0, 1, 2, 5, 4, 3, 6, 7, 8],
    "wide":      [0, 8, 2, 6],
    "bounce":    [3, 4, 5, 4],
    "spiral":    [0, 1, 2, 5, 8, 7, 6, 3, 4],
    "vee":       [0, 4, 2, 5, 8, 4, 6, 3],
}

POOLS = {
    0: ["row_mid", "col_mid", "diag_a", "diag_b", "row_top", "row_bot", "edges"],
    1: ["row_top", "row_mid", "row_bot", "col_left", "col_mid", "col_right",
        "diag_a", "diag_b", "corners", "edges", "box", "star", "snake"],
    2: ["snake", "box", "spiral", "vee", "star", "corners", "row_top", "row_bot",
        "col_left", "col_right", "diag_a", "diag_b", "wide", "bounce"],
}

# Minimum gap between notes: beats, and an absolute floor in seconds. The floor
# is what stops a fast track from turning Normal into a wall.
GAP_BEATS = [1.00, 0.55, 0.30]
GAP_FLOOR = [0.55, 0.30, 0.17]
SIZE_MUL = [1.25, 1.05, 0.92]

# How far the next cube may be, by how much time there is to travel. Grid
# distance is manhattan, so 4 is corner to opposite corner.
REACH = [(0.18, 1), (0.28, 2), (0.45, 3)]   # above the last threshold: 4

# One hold per this many bars, and how long it runs, in beats.
HOLD_BARS = [8, 8, 12]
HOLD_LEN_BEATS = [2.0, 2.0, 1.5]
HOLD_TAIL = 0.5            # beats of room after a hold releases

# One in N strong hits carries a click marker. Easy carries none. They only
# come alive if the player turns the CLICKS modifier on.
CLICK_EVERY = [0, 6, 5]

KINDS = [
    {"kick", "snare", "clap"},
    {"kick", "snare", "clap", "lead"},
    {"kick", "snare", "clap", "lead", "hat"},
]


def _dist(a, b):
    return abs(a // 3 - b // 3) + abs(a % 3 - b % 3)


def _reach_for(gap):
    for limit, d in REACH:
        if gap < limit:
            return d
    return 4


def _pick_cell(target, prev, gap):
    """Nearest cell to `target` that the cursor can actually get to in `gap`."""
    if prev < 0:
        return target
    max_d = _reach_for(gap)
    if _dist(target, prev) <= max_d and target != prev:
        return target
    best = None
    best_key = None
    for c in range(9):
        if c == prev:
            continue
        d = _dist(c, prev)
        if d > max_d:
            continue
        # closest to where the pattern wanted to go, then the bigger move -
        # a chart that always takes the smallest step feels limp
        key = (_dist(c, target), -d)
        if best_key is None or key < best_key:
            best_key = key
            best = c
    return best if best is not None else prev


def _phrase_pattern(level, song_key, phrase):
    pool = POOLS[level]
    h = hashlib.sha1(("%s|%d|%d" % (song_key, level, phrase)).encode()).digest()
    return PATTERNS[pool[h[0] % len(pool)]], h[1]


def _pitch_row(midi, lo, hi):
    if hi <= lo:
        return 1
    f = (midi - lo) / float(hi - lo)
    return 2 - min(2, max(0, int(f * 3.0)))


def _inside(windows, t):
    for (a, b) in windows:
        if a <= t < b:
            return True
        if t < a:
            break
    return False


def _place_holds(events, level, beat, enabled, song_key):
    """One hold per phrase boundary, on a sustained note if there is one."""
    if not enabled:
        return [], []
    bars = beat * 4.0
    every = HOLD_BARS[level] * bars
    hold_len = beat * HOLD_LEN_BEATS[level]
    if not events:
        return [], []
    end = max(t for (t, _k, _m, _v) in events)
    # candidates near each phrase boundary, preferring a bass note
    bass = sorted(t for (t, k, _m, _v) in events if k == "bass")
    strong = sorted(t for (t, k, _m, _v) in events if k in ("kick", "snare"))
    out, windows = [], []
    mark = every
    i = 0
    while mark < end - hold_len - bars:
        pool = bass if bass else strong
        near = min(pool, key=lambda t: abs(t - mark)) if pool else mark
        if abs(near - mark) > bars:
            near = mark
        h = hashlib.sha1(("%s|hold|%d" % (song_key, i)).encode()).digest()
        cell = [4, 1, 3, 5, 7][h[0] % 5]
        out.append({"t": round(float(near), 3), "cell": cell,
                    "s": round(SIZE_MUL[level] * 1.2, 2),
                    "h": round(hold_len, 3)})
        windows.append((near - beat * 0.4, near + hold_len + beat * HOLD_TAIL))
        mark += every
        i += 1
    return out, windows


# How much a note of each kind is worth as something to chart. A chart wants
# the hits a listener is actually counting, so a kick outranks a hat.
KIND_WEIGHT = {"kick": 1.0, "snare": 0.95, "clap": 0.95, "bass": 0.7,
               "lead": 0.6, "hat": 0.35}
# How full a subdivision has to be before a bar is charted at it.
COVER = 0.35


def select_times(events, level, beat):
    """Note times for one difficulty, decided a bar at a time.

    Two rules, and both of them are about the chart sounding like the music.

    Only the layers this difficulty follows are considered - Easy hears the
    drums, Normal the melody as well, Hyper everything - so a cube always lands
    on something the player can hear, rather than on a hat nobody is counting.

    And a bar is charted at ONE subdivision: the fastest this difficulty allows
    that the music actually fills. Every gap in the bar is then a whole number
    of that subdivision. Taking whichever hits happen to clear a minimum
    spacing instead leaves dotted three-sixteenth stutters between the
    survivors, which is what turns a chart into noise even when every note is
    on a real hit.
    """
    keep = KINDS[level]
    step = beat / 4.0
    slots = {}
    for (t, kind, _midi, vel) in events:
        if kind not in keep:
            continue
        k = int(round(t / step))
        if k < 0 or abs(k * step - t) > step * 0.4:
            continue                      # not on the grid this music runs on
        w = KIND_WEIGHT.get(kind, 0.5) * max(float(vel), 0.1)
        if k not in slots or w > slots[k][0]:
            slots[k] = (w, kind)
    if not slots:
        return []
    min_gap = max(GAP_FLOOR[level], beat * GAP_BEATS[level])
    allowed = [d for d in (1, 2, 4, 8) if d * step >= min_gap - 1e-6] or [8]
    out = []
    last_bar = max(slots) // 16
    for bar in range(int(last_bar) + 1):
        base = bar * 16
        window = [slots.get(base + j) for j in range(16)]
        if not any(window):
            continue
        pick, off = allowed[-1], 0
        for d in allowed:
            # Which beat of the bar the subdivision starts on matters as much
            # as how fast it is: a backbeat sits on two and four, and counting
            # only from the bar line would miss it entirely and halve the
            # chart.
            best_off, best_score = 0, -1.0
            for o in range(d):
                at = [window[j] for j in range(o, 16, d)]
                score = sum(x[0] for x in at if x)
                if score > best_score:
                    best_score, best_off = score, o
            at = [window[j] for j in range(best_off, 16, d)]
            if at and sum(1 for x in at if x) / float(len(at)) >= COVER:
                pick, off = d, best_off
                break
        for j in range(off, 16, pick):
            hit = window[j]
            if hit:
                out.append(((base + j) * step, hit[1], hit[0], (base + j) % 16))
    return out


def build_from_events(events, level, beat, song_key, holds=True, clicks=True):
    """Chart one difficulty straight from the music's own note events."""
    picked = select_times(events, level, beat)
    return build_chart([(t, kind, 0, w) for (t, kind, w, _slot) in picked],
                       level, beat, song_key, holds, clicks, pre_selected=True)


def build_chart(events, level, beat, song_key, holds=True, clicks=True,
                bars_per_phrase=2, pre_selected=False):
    """Build one difficulty. events: [(t, kind, midi, vel)]."""
    keep = KINDS[level]
    pitches = [m for (_t, k, m, _v) in events if k == "lead" and m > 0]
    lo = min(pitches) if pitches else 48
    hi = max(pitches) if pitches else 84
    min_gap = max(GAP_FLOOR[level], beat * GAP_BEATS[level])
    phrase_len = beat * 4 * bars_per_phrase
    click_every = CLICK_EVERY[level] if clicks else 0

    hold_notes, blocked = _place_holds(events, level, beat, holds, song_key)
    notes = list(hold_notes)

    last_t = -9.0
    prev_cell = -1
    step = 0
    cur_phrase = -1
    pattern = PATTERNS["row_mid"]
    strong_i = 0

    for (t, kind, midi, vel) in sorted(events, key=lambda e: e[0]):
        if _inside(blocked, t):
            continue
        if not pre_selected and kind not in keep:
            continue
        gap = t - last_t
        # Times chosen by select_times are already spaced for this difficulty,
        # and dropping any of them here would break the run they belong to.
        if not pre_selected:
            if gap < min_gap:
                continue
            # hats are filler: only where the groove has actually left a hole
            if kind == "hat" and gap < min_gap * 1.4:
                continue
        elif gap < min_gap * 0.55:
            continue                      # a hold pushed two notes together
        phrase = int(t / phrase_len) if phrase_len > 0 else 0
        if phrase != cur_phrase:
            cur_phrase = phrase
            pattern, salt = _phrase_pattern(level, song_key, phrase)
            step = salt % len(pattern)

        if kind == "lead" and midi > 0:
            target = _pitch_row(midi, lo, hi) * 3 + pattern[step % len(pattern)] % 3
        else:
            target = pattern[step % len(pattern)]
        step += 1

        cell = _pick_cell(int(target), prev_cell, gap)
        size = SIZE_MUL[level] * (1.08 if kind == "kick" else
                                  0.92 if kind == "hat" else 1.0)
        note = {"t": round(float(t), 3), "cell": int(cell), "s": round(size, 2)}
        if click_every and kind in ("kick", "snare", "clap"):
            strong_i += 1
            if strong_i % click_every == 0:
                note["c"] = True
        notes.append(note)
        prev_cell = cell
        last_t = t

    notes.sort(key=lambda n: n["t"])
    return _enforce_reach(notes)


def _enforce_reach(notes):
    """Final pass over the merged list, holds included.

    Holds are placed in their own pass, so the note before and after one never
    went through the reach check. Walking the finished chart once catches those
    and any other pair that ended up further apart than the gap allows.
    """
    prev = -1
    prev_end = -9.0
    for n in notes:
        gap = n["t"] - prev_end
        cell = _pick_cell(n["cell"], prev, gap) if prev >= 0 else n["cell"]
        n["cell"] = int(cell)
        prev = n["cell"]
        prev_end = n["t"] + float(n.get("h", 0) or 0)
    return notes


def describe(notes, length):
    """Density, holds, clicks, cell coverage and the worst travel demand."""
    if not notes or length <= 0:
        return "0 notes"
    holds = sum(1 for n in notes if n.get("h"))
    clicks = sum(1 for n in notes if n.get("c"))
    cells = len(set(n["cell"] for n in notes))
    runs = set()
    for i in range(len(notes) - 3):
        runs.add(tuple(notes[j]["cell"] for j in range(i, i + 4)))
    variety = len(runs) / max(len(notes) - 3, 1)
    # the tightest "distance per second" the chart ever asks for
    worst = 0.0
    for a, b in zip(notes, notes[1:]):
        gap = b["t"] - a["t"] - float(a.get("h", 0) or 0)
        if gap > 0.02:
            worst = max(worst, _dist(a["cell"], b["cell"]) / gap)
    return ("%3d notes %.2f/s  holds %-3d clicks %-3d cells %d/9  variety %.2f  "
            "peak %.1f cells/s" % (len(notes), len(notes) / length, holds, clicks,
                                   cells, variety, worst))
