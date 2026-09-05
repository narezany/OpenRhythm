#!/usr/bin/env python3
"""Open Rhythm tutorial: a calm teaching track and the chart that goes with it.

The chart is written by hand, not generated: the whole point is that each
section teaches exactly one thing, in order - catch a cube, hold a long one,
click a ringed one - and the music marks every section change so the player can
hear where they are.

Hints live in map.json next to the notes, so their timing can never drift away
from the chart.

Run from the project root:  python3 tools/gen_tutorial.py
"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_media import SR, ROOT                        # noqa: E402
from gen_pack2 import Track, write_waveform           # noqa: E402

np.random.seed(11)

BPM = 96.0
BEAT = 60.0 / BPM          # 0.625 s
BAR = BEAT * 4             # 2.5 s
BARS = 30

# section starts, in bars
S_INTRO, S_BASIC, S_FASTER, S_HOLD, S_CLICK, S_MIX = 0, 4, 9, 13, 18, 22

# A minor: i - VI - III - VII, one chord per bar
CHORDS = [[57, 60, 64], [53, 57, 60], [60, 64, 67], [55, 59, 62]]


def bar_t(bar, beat=0.0):
    return bar * BAR + beat * BEAT


def build():
    s = Track(BPM, BARS)
    notes = []
    kicks = []

    def note(t, cell, size=1.35, hold=0.0, click=False):
        n = {"t": round(t, 3), "cell": int(cell), "s": size}
        if hold > 0.0:
            n["h"] = round(hold, 3)
        if click:
            n["c"] = True
        notes.append(n)

    for b in range(BARS):
        t = bar_t(b)
        ch = CHORDS[b % 4]
        s.pad(t, BAR * 1.02, [m + 12 for m in ch], 0.75 if b >= S_BASIC else 0.55)

        # drums come in with the first cubes, so the beat is obvious
        if b >= S_BASIC:
            for k in (0, 2):
                kt = t + k * BEAT
                s.kick(kt, 1.0 if k == 0 else 0.9)
                kicks.append(kt)
        if b >= S_FASTER:
            for k in range(4):
                s.hat(t + k * BEAT + BEAT * 0.5, open_=(k == 3), vel=0.75)
        if b >= S_MIX:
            s.snare(t + 2 * BEAT, 0.9)
        if b in (S_BASIC, S_HOLD, S_CLICK, S_MIX):
            s.crash(t, 0.7)                      # every section change is audible
        if b >= S_FASTER:
            s.sub(t, BEAT * 1.6, ch[0] - 12, 0.8)
            s.sub(t + 2 * BEAT, BEAT * 1.6, ch[0] - 12, 0.7)

    # --- one cube per bar: land it, that is all -----------------------------
    for i, cell in enumerate([4, 1, 7, 3]):
        t = bar_t(S_BASIC + i)
        s.pluck(t, BEAT * 1.4, CHORDS[i % 4][2] + 12, 1.0)
        note(t, cell, 1.45)

    # --- two per bar --------------------------------------------------------
    for i in range(4):
        b = S_FASTER + i
        for k, cell in enumerate([[0, 8], [2, 6], [5, 3], [1, 7]][i]):
            t = bar_t(b, k * 2)
            s.pluck(t, BEAT * 1.1, CHORDS[b % 4][k % 3] + 12, 0.95)
            note(t, cell, 1.3)

    # --- holds: a sustained note under a long cube --------------------------
    for i, cell in enumerate([4, 2, 6, 4, 8]):
        b = S_HOLD + i
        t = bar_t(b)
        hold = BEAT * 2.0
        s.wobble(t, hold, CHORDS[b % 4][0] - 12, 1.0, 0.95)
        s.pluck(t, BEAT * 0.9, CHORDS[b % 4][1] + 12, 0.8)
        note(t, cell, 1.4, hold=hold)

    # --- clicks: a stab under every ringed cube -----------------------------
    for i, cell in enumerate([4, 0, 8, 2, 6, 4]):
        b = S_CLICK + i // 2
        t = bar_t(b, (i % 2) * 2)
        s.stab(t, BEAT * 1.2, [m + 12 for m in CHORDS[b % 4]], 1.0)
        note(t, cell, 1.4, click=True)

    # --- everything together ------------------------------------------------
    # (bar offset, beat inside the bar, cell, hold length, click)
    mix = [
        (0, 0.0, 1, 0.0, False), (0, 2.0, 5, 0.0, False),
        (1, 0.0, 4, BEAT * 2.0, False),
        (2, 0.0, 3, 0.0, True), (2, 2.0, 7, 0.0, False),
        (3, 0.0, 1, 0.0, False), (3, 2.0, 5, 0.0, False),
        (4, 0.0, 4, BEAT * 2.0, False),
        (5, 0.0, 2, 0.0, True), (5, 2.0, 6, 0.0, False),
        (6, 0.0, 0, 0.0, False), (6, 2.0, 8, 0.0, False),
        (7, 0.0, 4, 0.0, True),
    ]
    for (db, beat_off, cell, hold, click) in mix:
        b = S_MIX + db
        t = bar_t(b, beat_off)
        if hold > 0.0:
            s.wobble(t, hold, CHORDS[b % 4][0] - 12, 1.0, 0.95)
        elif click:
            s.stab(t, BEAT * 1.2, [m + 12 for m in CHORDS[b % 4]], 1.0)
        else:
            s.pluck(t, BEAT * 1.0, CHORDS[b % 4][2] + 12, 0.95)
        note(t, cell, 1.3, hold=hold, click=click)

    s.duck_curve(kicks, 0.35, 0.24)
    notes.sort(key=lambda n: n["t"])
    validate(notes)
    return s, notes


def validate(notes):
    """There is one cursor: two cubes at once, or a cube during a hold, is a
    note the player physically cannot take. Fail loudly rather than ship it."""
    problems = []
    for a, b in zip(notes, notes[1:]):
        gap = b["t"] - a["t"]
        if gap < 0.2:
            problems.append("notes %.3f and %.3f are %.3f s apart"
                            % (a["t"], b["t"], gap))
        hold = float(a.get("h", 0) or 0)
        if hold > 0.0 and b["t"] < a["t"] + hold:
            problems.append("note at %.3f lands during the hold at %.3f"
                            % (b["t"], a["t"]))
    if problems:
        raise SystemExit("tutorial chart is unplayable:\n  " + "\n  ".join(problems))


HINTS = [
    (1.0, "Welcome to the tutorial! Let's learn how to play."),
    (5.0, "Watch the frame: a cube will fly into one of the nine cells."),
    (bar_t(S_BASIC) - 1.2, "Move your cursor onto that cell and CATCH the cube when it lands!"),
    (bar_t(S_BASIC + 2), "Dead center = PERFECT. A bit off = GREAT or GOOD. Edge = BULLSHIT."),
    (bar_t(S_FASTER), "Missed? No worries — try again, nobody's watching."),
    (bar_t(S_HOLD) - 1.6, "Long cubes are HOLDS: stay on them until they run out."),
    (bar_t(S_HOLD + 2), "Let go early and the hold does not count. Carry it to the end."),
    (bar_t(S_CLICK) - 1.6, "A cube in a ring has to be CLICKED, not just covered."),
    (bar_t(S_CLICK + 2), "In other songs clicks are off until you switch on the CLICKS modifier."),
    (bar_t(S_MIX) - 1.4, "All three together now — good luck!"),
]


def main():
    song_dir = os.path.join(ROOT, "songs", "tutorial")
    os.makedirs(song_dir, exist_ok=True)
    s, notes = build()
    wav = os.path.join(song_dir, "audio.wav")
    s.save(wav)
    left, _ = s.master()
    write_waveform(song_dir, left)
    ogg = os.path.join(song_dir, "audio.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
                    "-c:a", "libvorbis", "-qscale:a", "5", ogg], check=True)
    os.remove(wav)
    for stale in ("audio.wav.import",):
        p = os.path.join(song_dir, stale)
        if os.path.exists(p):
            os.remove(p)

    data = {
        "id": "tutorial",
        "title": "TUTORIAL",
        "artist": "Open Rhythm",
        "bpm": BPM,
        "preview_start": bar_t(S_MIX),
        "length": round(s.len_s - 2.0, 2),
        "audio": "audio.ogg",
        "hints": [{"t": round(t, 2), "text": txt} for t, txt in HINTS],
        "difficulties": [{"name": "Easy", "notes": notes}],
    }
    with open(os.path.join(song_dir, "map.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    holds = sum(1 for n in notes if n.get("h"))
    clicks = sum(1 for n in notes if n.get("c"))
    print("tutorial: %.1fs, %d notes (%d holds, %d clicks), %d hints, ogg %.1f MB" % (
        data["length"], len(notes), holds, clicks, len(HINTS),
        os.path.getsize(ogg) / 1e6))


if __name__ == "__main__":
    main()
