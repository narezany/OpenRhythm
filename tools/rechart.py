#!/usr/bin/env python3
"""Rebuild the difficulties of a song that only ships a map.json.

The OST generators keep their own note events, so they chart from the music
itself. Everything else - imported maps, older hand-made ones - only has note
times on disk. Those times came from the audio, so they are worth keeping: this
snaps them to the beat grid, works out what each one is (downbeat, backbeat,
off-beat, subdivision) and hands the result to the shared chart builder.

  python3 tools/rechart.py songs/monster songs/verity
  python3 tools/rechart.py --all            # every song except the tutorial
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from charting import build_chart, describe   # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP = {"tutorial"}                      # hand-made teaching chart, leave alone
OST = {"neon_drift", "hyper_drive", "midnight_pulse", "bass_rush",
       "crimson_step", "afterburner"}    # charted by their own generators


def best_phase(times, step):
    """Grid offset that lines the notes up with the least total error.

    A map whose first beat is not at zero would otherwise get shifted by
    quantising, which is exactly how a chart ends up off the beat.
    """
    best, best_err = 0.0, None
    for i in range(24):
        phase = step * i / 24.0
        err = 0.0
        for t in times:
            d = (t - phase) % step
            err += min(d, step - d)
        if best_err is None or err < best_err:
            best, best_err = phase, err
    return best


def quantise(times, step, phase):
    out = []
    for t in times:
        q = phase + round((t - phase) / step) * step
        # leave a note alone if the grid disagrees badly - better an honest
        # off-grid note than one dragged onto the wrong beat
        out.append(q if abs(q - t) <= step * 0.42 else t)
    return sorted(out)


def synth_events(times, beat):
    """Give every time a kind from where it sits inside the bar.

    Every source note is a real onset, so none of them become "hat" - that kind
    is reserved for the filler below, which only Hyper takes. Otherwise most of
    a track's notes would be invisible on Normal.
    """
    events = []
    bar = beat * 4.0
    for t in times:
        pos = (t % bar) / beat
        frac = pos - int(pos)
        if frac < 0.12 or frac > 0.88:
            whole = round(pos) % 4
            kind = "snare" if whole == 2 else "kick"
        else:
            kind = "lead"
        events.append((t, kind, 0, 1.0))
    return events


def add_filler(events, beat):
    """Half-beat filler in the holes, so Hyper can actually be dense.

    A recharted track can only be as busy as its source onsets. Filler sits on
    the grid between two notes that are far apart, and is tagged "hat" so only
    Hyper picks it up.
    """
    out = list(events)
    times = [t for (t, _k, _m, _v) in events]
    for a, b in zip(times, times[1:]):
        gap = b - a
        if gap < beat * 1.4:
            continue
        n = int(gap / (beat * 0.5))
        for i in range(1, n):
            t = a + beat * 0.5 * i
            if b - t > beat * 0.4:
                out.append((t, "hat", 0, 0.9))
    out.sort(key=lambda e: e[0])
    return out


def rechart(song_dir):
    path = os.path.join(song_dir, "map.json")
    if not os.path.exists(path):
        return False
    data = json.load(open(path, encoding="utf-8"))
    sid = str(data.get("id", os.path.basename(song_dir)))
    if sid in SKIP:
        print("  %-16s skipped (hand-made)" % sid)
        return False
    bpm = float(data.get("bpm", 120.0))
    beat = 60.0 / max(bpm, 1.0)
    length = float(data.get("length", 0.0))

    # the densest difficulty carries the most onsets, so it is the best source
    diffs = data.get("difficulties", [])
    if not diffs:
        return False
    src = max(diffs, key=lambda d: len(d.get("notes", [])))
    times = sorted({round(float(n["t"]), 3) for n in src.get("notes", [])})
    if len(times) < 16:
        print("  %-16s skipped (only %d notes)" % (sid, len(times)))
        return False

    step = beat / 4.0
    phase = best_phase(times, step)
    times = quantise(times, step, phase)
    events = add_filler(synth_events(times, beat), beat)
    if length <= 0.0:
        length = times[-1] + 2.0

    print("  %s  (%d source notes, %.1f BPM, grid phase %+.3f s)" % (
        sid, len(times), bpm, phase))
    out = []
    for name, level in (("Easy", 0), ("Normal", 1), ("Hyper", 2)):
        notes = build_chart(events, level, beat, sid)
        out.append({"name": name, "notes": notes})
        print("    %-7s %s" % (name, describe(notes, length)))
    data["difficulties"] = out
    json.dump(data, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return True


def main(argv):
    targets = []
    if "--all" in argv:
        base = os.path.join(ROOT, "songs")
        for name in sorted(os.listdir(base)):
            d = os.path.join(base, name)
            if os.path.isdir(d) and name not in OST:
                targets.append(d)
    else:
        targets = [a if os.path.isabs(a) else os.path.join(ROOT, a)
                   for a in argv if not a.startswith("-")]
    if not targets:
        print(__doc__)
        return 1
    n = 0
    for d in targets:
        if rechart(d):
            n += 1
    print("rebuilt %d song(s)" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
