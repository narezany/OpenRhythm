#!/usr/bin/env python3
"""Rebuild the difficulties of a song from the music itself.

Every note time here comes from an attack in the audio, quantised to a beat
grid measured from that same audio. Nothing is taken from the map file except
the notes' own history - and that history is the reason this exists: the old
version of this script trusted the BPM written in map.json, snapped the note
times onto that grid and wrote them back. Where the declared tempo was wrong
the whole chart was dragged off the music, worse the further into the song you
got, and the hitsound went with it.

So the tempo is measured, not believed, and a note is only placed where there
is something to hear.

  python3 tools/rechart.py songs/monster songs/verity
  python3 tools/rechart.py --all            # every song except the tutorial
  python3 tools/rechart.py --all --dry      # measure and report, write nothing
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from charting import build_chart, describe   # noqa: E402
import beatgrid as bg                        # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP = {"tutorial"}                      # hand-made teaching chart, leave alone

# How far off the grid an attack may sit and still be counted as being on it,
# as a fraction of a sixteenth. Anything further is something the tempo does
# not explain - a fill, a vocal, noise - and charting it would put a cube where
# the player hears no beat.
SNAP = 0.40
# An attack has to be at least this strong, relative to the loudest in the
# track, to be worth a cube.
FLOOR = 0.10


def bands(x: np.ndarray):
    """Onset strength split into low, mid and high, for telling a kick from a
    hat. Cheap, and enough to keep the drums and the top end apart."""
    n = 1 + (len(x) - bg.NFFT) // bg.HOP
    if n < 4:
        z = np.zeros(1)
        return z, z, z
    win = np.hanning(bg.NFFT).astype(np.float32)
    frames = np.lib.stride_tricks.as_strided(
        x, shape=(n, bg.NFFT), strides=(x.strides[0] * bg.HOP, x.strides[0])) * win
    mag = np.abs(np.fft.rfft(frames, axis=1))
    logmag = np.log1p(mag * 8.0)
    flux = np.maximum(np.diff(logmag, axis=0), 0.0)
    hz = bg.SR / bg.NFFT
    lo = flux[:, :int(150 / hz)].sum(axis=1)
    mid = flux[:, int(150 / hz):int(2000 / hz)].sum(axis=1)
    hi = flux[:, int(2000 / hz):].sum(axis=1)
    out = []
    for b in (lo, mid, hi):
        peak = b.max()
        out.append(b / peak if peak > 0 else b)
    return out[0], out[1], out[2]


def measure(path: str, claimed: float):
    """(bpm, first beat, how tightly the song holds it) straight from the audio."""
    env = bg.onset_envelope(bg.decode(path))
    # only octaves of the written tempo are worth seeding: a seed at three
    # quarters of it locks onto a grid that fits the onsets but is not the beat
    seeds = [claimed, claimed * 2.0, claimed / 2.0, claimed * 4.0]
    rough = bg.tempo_phase(env, hint=claimed)[0]
    seeds += [rough, rough * 2.0, rough / 2.0]
    bpm, first, spread = bg.best_tempo(env, seeds)
    # A tempo written by hand is usually a round number and usually right; keep
    # it when the measurement agrees, so a track synthesised at exactly 120
    # stays at exactly 120 instead of becoming 119.994. Anything further apart
    # than that means the written tempo is simply wrong and loses.
    if claimed > 0 and abs(bpm - claimed) / claimed < 0.0015:
        bpm = claimed
    first = phase_from_onsets(env, bpm, first)
    # a first beat a few milliseconds off zero is the measurement, not the
    # music: a track that starts on the beat should say so
    if min(first, 60.0 / bpm - first) < 0.012:
        first = 0.0
    return env, bpm, first % (60.0 / bpm), spread


def phase_from_onsets(env, bpm: float, first: float) -> float:
    """Slide the grid until it sits on the attacks themselves.

    Locking the tempo fits a line through the beat positions, which gets the
    rate right but can leave the whole grid a few milliseconds beside the
    drums. Since what the player hears is the drums, the last word goes to
    them: the grid is shifted by the median offset of every attack it explains.
    """
    step = 60.0 / bpm / 4.0
    peaks = bg.onset_times(env, thresh=FLOOR)
    if len(peaks) < 8:
        return first
    for _ in range(3):
        r = ((peaks - first + step / 2.0) % step) - step / 2.0
        keep = r[np.abs(r) < step * SNAP]
        if len(keep) < 8:
            break
        shift = float(np.median(keep))
        first += shift
        if abs(shift) < 0.0005:
            break
    return first % (60.0 / bpm)


def events_from_audio(x, env, bpm: float, first: float):
    """Turn the attacks in the music into chart events on the measured grid.

    The kind decides which difficulties see a note: Easy takes only what is on
    a beat, Normal adds the eighths, Hyper the rest. That is the same shape a
    listener hears in the music, so the difficulties differ by how much of the
    groove they ask for rather than by an arbitrary thinning.
    """
    lo, mid, hi = bands(x)
    beat = 60.0 / bpm
    step = beat / 4.0
    peaks = bg.onset_times(env, thresh=FLOOR)
    best = {}
    for t in peaks:
        k = round((t - first) / step)
        if k < 0:
            continue
        q = first + k * step
        if abs(q - t) > step * SNAP:
            continue                      # the grid does not explain this one
        i = int(round((t - bg.ONSET_LAG) * bg.FPS))
        i = min(max(i, 0), len(env) - 1)
        strength = float(env[i])
        if k not in best or strength > best[k][0]:
            best[k] = (strength, float(lo[min(i, len(lo) - 1)]),
                       float(mid[min(i, len(mid) - 1)]),
                       float(hi[min(i, len(hi) - 1)]))
    on_beat, off_beat = [], []
    for k in sorted(best):
        strength, l, m, h = best[k]
        t = first + k * step
        beat_in_bar = (k // 4) % 4
        if k % 4 == 0:
            kind = "snare" if beat_in_bar in (1, 3) and (m + h) > l else "kick"
            on_beat.append((round(t, 3), kind, 0, round(min(1.0, 0.5 + strength), 2)))
        else:
            off_beat.append((round(t, 3), strength))
    # Which offbeats a difficulty sees is decided by how loud they are, not by
    # where they happen to fall: the loudest ones are the ones a player hears
    # and expects to hit. Roughly as many are promoted as there are on-beat
    # notes, which is what makes Normal about twice the work of Easy while
    # Hyper picks up the rest.
    off_beat.sort(key=lambda e: -e[1])
    promote = len(on_beat)
    events = list(on_beat)
    for i, (t, strength) in enumerate(off_beat):
        kind = "lead" if i < promote else "hat"
        events.append((t, kind, 0, round(min(1.0, 0.5 + strength), 2)))
    events.sort(key=lambda e: e[0])
    return events, beat


def ensure_skeleton(events, env, bpm, first, length):
    """If the attacks left Easy with almost nothing, put a note on the beats
    that do carry energy. A quiet track still has a pulse to follow."""
    strong = [e for e in events if e[1] in ("kick", "snare", "clap")]
    if len(strong) >= 24:
        return events
    beat = 60.0 / bpm
    have = {round(t, 3) for (t, _k, _m, _v) in events}
    extra = []
    k = 0
    while first + k * beat < length:
        t = round(first + k * beat, 3)
        i = int(round((t - bg.ONSET_LAG) * bg.FPS))
        if 0 <= i < len(env) and t not in have and float(env[i]) > FLOOR * 0.5:
            extra.append((t, "kick", 0, 0.8))
        k += 1
    return sorted(events + extra, key=lambda e: e[0])


def rechart(song_dir: str, dry: bool = False) -> bool:
    path = os.path.join(song_dir, "map.json")
    if not os.path.exists(path):
        return False
    data = json.load(open(path, encoding="utf-8"))
    sid = str(data.get("id", os.path.basename(song_dir)))
    if sid in SKIP:
        print("  %-16s skipped (hand-made)" % sid)
        return False
    audio = bg.audio_of(sid)
    if audio is None:
        print("  %-16s skipped (no audio to measure)" % sid)
        return False

    claimed = float(data.get("bpm", 120.0))
    x = bg.decode(audio)
    env, bpm, first, spread = measure(audio, claimed)
    length = float(data.get("length", 0.0)) or len(x) / bg.SR
    events, beat = events_from_audio(x, env, bpm, first)
    events = ensure_skeleton(events, env, bpm, first, length)

    note = "" if abs(bpm - claimed) < 0.01 else "  (chart said %.2f)" % claimed
    print("  %-16s %.2f BPM, first beat %+.3f s, hold %.3f s%s, %d attacks"
          % (sid, bpm, first, spread, note, len(events)))
    if dry:
        return False

    data["bpm"] = round(bpm, 3)
    out = []
    for name, level in (("Easy", 0), ("Normal", 1), ("Hyper", 2)):
        notes = build_chart(events, level, beat, sid)
        out.append({"name": name, "notes": notes})
        print("    %-7s %s" % (name, describe(notes, length)))
    data["difficulties"] = out
    json.dump(data, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return True


def main(argv):
    dry = "--dry" in argv
    targets = []
    if "--all" in argv:
        base = os.path.join(ROOT, "songs")
        for name in sorted(os.listdir(base)):
            d = os.path.join(base, name)
            if os.path.isdir(d):
                targets.append(d)
    else:
        targets = [a if os.path.isabs(a) else os.path.join(ROOT, a)
                   for a in argv if not a.startswith("-")]
    if not targets:
        print(__doc__)
        return 1
    n = 0
    for d in targets:
        if rechart(d, dry):
            n += 1
    print("rebuilt %d song(s)" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
