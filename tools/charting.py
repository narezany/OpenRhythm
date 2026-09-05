#!/usr/bin/env python3
"""Chart builder shared by the OST generators.

The old builder walked a fixed four-cell cycle, which produced the same
top-middle-bottom snake in every song. This one works in phrases: every two
bars it picks a movement pattern, walks it, and lets melody notes take their
row from pitch, so two tracks never look alike and the chart follows the music.

Difficulty is a density curve plus a minimum gap between notes. There is one
cursor, so the gap is the real difficulty knob - it decides how far you have to
travel and how fast.
"""
import hashlib

# Cell ids on the 3x3 grid: row * 3 + col, 0 = top-left, 4 = centre.
# Each pattern is a walk; a phrase picks one and steps through it.
PATTERNS = {
    "row_top":  [0, 1, 2, 1],
    "row_mid":  [3, 4, 5, 4],
    "row_bot":  [6, 7, 8, 7],
    "col_left": [0, 3, 6, 3],
    "col_mid":  [1, 4, 7, 4],
    "col_right": [2, 5, 8, 5],
    "diag_a":   [0, 4, 8, 4],
    "diag_b":   [2, 4, 6, 4],
    "corners":  [0, 2, 8, 6],
    "star":     [4, 0, 4, 8, 4, 2, 4, 6],
    "edges":    [1, 5, 7, 3],
    "box":      [0, 1, 2, 5, 8, 7, 6, 3],
    "zigzag":   [0, 5, 1, 8, 3, 7, 2, 6],
    "wide":     [0, 8, 2, 6],
    "bounce":   [3, 5, 3, 5, 0, 8],
    "spiral":   [0, 1, 2, 5, 8, 7, 6, 3, 4],
}

# Which patterns a difficulty is allowed to use. Easy stays close to the
# centre, Hyper gets the ones with long jumps.
POOLS = {
    0: ["row_mid", "col_mid", "diag_a", "diag_b", "row_top", "row_bot", "edges"],
    1: ["row_top", "row_mid", "row_bot", "col_left", "col_mid", "col_right",
        "diag_a", "diag_b", "corners", "edges", "box", "star"],
    2: ["corners", "star", "box", "zigzag", "wide", "bounce", "spiral",
        "diag_a", "diag_b", "col_left", "col_right", "row_top", "row_bot"],
}

# Per level: minimum gap in beats, an absolute floor in seconds, note size.
# The floor matters more than the beat fraction: without it a 174 BPM track
# turns Normal into a wall, which is exactly what happened to Hyper Drive.
GAP_BEATS = [1.00, 0.55, 0.28]
GAP_FLOOR = [0.55, 0.30, 0.16]
SIZE_MUL = [1.25, 1.05, 0.88]

# Hold length in beats per level, and the gap left after one ends. Nothing else
# is placed while a hold runs - there is one cursor, so a note flying in during
# a hold is a note you cannot take.
HOLD_BEATS = [1.5, 1.25, 1.0]
HOLD_TAIL = 0.35          # beats of breathing room after a hold releases
HOLD_EVERY = [5, 4, 3]    # one in N eligible bass notes becomes a hold

# One in N strong hits becomes a click note. Easy gets none.
CLICK_EVERY = [0, 6, 4]

# which event kinds each level keeps
KINDS = [
    {"kick", "snare", "clap"},
    {"kick", "snare", "clap", "lead", "bass"},
    {"kick", "snare", "clap", "lead", "bass", "hat"},
]


def _inside(windows, t):
    for (a, b) in windows:
        if a <= t < b:
            return True
        if t < a:
            break
    return False


def _place_holds(events, level, beat, enabled):
    """Pick the hold notes and the windows they own. Returns (notes, windows).

    Sustained bass is the natural source; a track without any gets its holds
    from bar-start kicks instead, so every chart has a few.
    """
    if not enabled or HOLD_EVERY[level] <= 0:
        return [], []
    hold_len = beat * HOLD_BEATS[level]
    bars = beat * 4.0
    cands = [(t, m) for (t, k, m, _v) in events if k == "bass"]
    if not cands:
        cands = [(t, 0) for (t, k, _m, _v) in events if k == "kick"
                 and abs((t / bars) - round(t / bars)) < 0.02]
    if not cands:
        return [], []
    cands.sort()
    out = []
    windows = []
    last_end = -9.0
    step = max(HOLD_EVERY[level], 1)
    # spread them out: one every `step` candidates and never back to back
    for i, (t, midi) in enumerate(cands):
        if i % step:
            continue
        if t < last_end + bars * 1.5:
            continue
        cell = 4 if midi <= 0 else (1 + (i // step) % 3) + 3 * ((i // step) % 3)
        cell = int(min(max(cell, 0), 8))
        out.append({"t": round(float(t), 3), "cell": cell,
                    "s": round(SIZE_MUL[level] * 1.15, 2),
                    "h": round(hold_len, 3)})
        last_end = t + hold_len
        windows.append((t - beat * 0.35, last_end + beat * HOLD_TAIL))
    return out, windows


def _phrase_pattern(level, song_key, phrase):
    """Deterministic per-song, per-phrase pattern pick - no two songs match."""
    pool = POOLS[level]
    h = hashlib.sha1(("%s|%d|%d" % (song_key, level, phrase)).encode()).digest()
    return PATTERNS[pool[h[0] % len(pool)]], h[1]


def _pitch_row(midi, lo, hi):
    """Low notes at the bottom of the grid, high notes at the top."""
    if hi <= lo:
        return 1
    f = (midi - lo) / float(hi - lo)
    return 2 - min(2, max(0, int(f * 3.0)))


def _dist(a, b):
    return abs(a // 3 - b // 3) + abs(a % 3 - b % 3)


def build_chart(events, level, beat, song_key, holds=True, clicks=True,
                bars_per_phrase=2):
    """Build one difficulty.

    events: [(t, kind, midi, vel)]. level: 0 easy, 1 normal, 2 hyper.
    holds:  place hold notes on sustained bass, blocking the cursor while they
            run. clicks: mark some strong hits as click notes.
    """
    keep = KINDS[level]
    pitches = [m for (_, k, m, _) in events if k == "lead" and m > 0]
    lo = min(pitches) if pitches else 48
    hi = max(pitches) if pitches else 84
    min_gap = max(GAP_FLOOR[level], beat * GAP_BEATS[level])
    phrase_len = beat * 4 * bars_per_phrase

    # Holds are placed first. A bass event usually lands on the same beat as a
    # kick, so if it went through the normal gap filter it would always lose
    # and no hold would ever survive.
    hold_notes, blocked = _place_holds(events, level, beat, holds)

    notes = list(hold_notes)
    last_t = -9.0
    prev_cell = -1
    cell_last = {}
    step = 0
    cur_phrase = -1
    pattern = PATTERNS["row_mid"]
    salt = 0
    hat_i = 0
    strong_i = 0
    click_every = CLICK_EVERY[level] if clicks else 0

    for (t, kind, midi, vel) in sorted(events, key=lambda e: e[0]):
        if kind not in keep:
            continue
        # a hold owns the cursor until it releases
        if _inside(blocked, t):
            continue
        # Easy only wants the strong half of the drums
        if level == 0 and kind == "kick" and int(round(t / beat)) % 2 == 1:
            continue
        # hats are the filler that makes Hyper genuinely dense on tracks whose
        # drums alone are sparse
        if kind == "hat":
            hat_i += 1
            if vel < 0.55:
                continue
        if t - last_t < min_gap:
            continue

        phrase = int(t / phrase_len) if phrase_len > 0 else 0
        if phrase != cur_phrase:
            cur_phrase = phrase
            pattern, salt = _phrase_pattern(level, song_key, phrase)
            step = salt % len(pattern)

        if kind == "lead" and midi > 0:
            row = _pitch_row(midi, lo, hi)
            col = pattern[step % len(pattern)] % 3
            cell = row * 3 + col
        else:
            cell = pattern[step % len(pattern)]
        step += 1

        # never twice in a row in the same place, and give hyper real travel
        if cell == prev_cell or (level == 2 and prev_cell >= 0
                                 and _dist(cell, prev_cell) < 1):
            cell = (cell + 4) % 9
        if t - cell_last.get(cell, -9.0) < min_gap * 1.4:
            alt = (cell + 5) % 9
            if t - cell_last.get(alt, -9.0) >= min_gap * 1.4:
                cell = alt

        size = SIZE_MUL[level]
        if kind == "kick":
            size *= 1.08
        elif kind == "hat":
            size *= 0.9
        note = {"t": round(float(t), 3), "cell": int(cell), "s": round(size, 2)}

        # Click notes land on the strong hits, where a press feels natural.
        if click_every and kind in ("kick", "snare", "clap"):
            strong_i += 1
            if strong_i % click_every == 0:
                note["c"] = True

        notes.append(note)
        cell_last[cell] = t
        prev_cell = cell
        last_t = t

    notes.sort(key=lambda n: n["t"])
    return notes


def describe(notes, length):
    """A quick sanity read: density, holds, clicks and how varied the cells are."""
    if not notes or length <= 0:
        return "0 notes"
    holds = sum(1 for n in notes if n.get("h"))
    clicks = sum(1 for n in notes if n.get("c"))
    cells = len(set(n["cell"] for n in notes))
    runs = set()
    for i in range(len(notes) - 3):
        runs.add(tuple(notes[j]["cell"] for j in range(i, i + 4)))
    variety = len(runs) / max(len(notes) - 3, 1)
    return "%3d notes %.2f/s  holds %-3d clicks %-3d cells %d/9  variety %.2f" % (
        len(notes), len(notes) / length, holds, clicks, cells, variety)
