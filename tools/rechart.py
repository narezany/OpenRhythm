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
from charting import build_chart, describe, GAP_BEATS, GAP_FLOOR   # noqa: E402
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
# How full a subdivision has to be before a bar is charted at it. Higher means
# steadier chart and fewer notes: at eighths, a bar that clears this bar gives
# gaps of two sixteenths with the occasional four, which is what a stream of
# eighth notes feels like under the cursor.
COVER = 0.50


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


def slot_grid(env, bpm: float, first: float, length: float, floor: float = FLOOR):
    """Onset strength on every sixteenth of the song, 0 where nothing happens.

    Everything downstream works on this grid rather than on loose onset times,
    because what makes a chart feel like the music is not only landing on the
    attacks but landing on a regular subdivision of the bar.
    """
    step = 60.0 / bpm / 4.0
    n = max(1, int((length - first) / step) + 2)
    slots = np.zeros(n)
    for t in bg.onset_times(env, thresh=floor):
        k = int(round((t - first) / step))
        if k < 0 or k >= n:
            continue
        if abs(first + k * step - t) > step * SNAP:
            continue                     # the grid does not explain this one
        i = int(round((t - bg.ONSET_LAG) * bg.FPS))
        i = min(max(i, 0), len(env) - 1)
        slots[k] = max(slots[k], float(env[i]))
    return slots


def select_times(slots, level: int, bpm: float, first: float):
    """Pick the note times for one difficulty, a bar at a time.

    A bar is charted at ONE subdivision - sixteenths, eighths, quarters or
    every other beat - chosen as the fastest the difficulty allows that the
    music actually fills. Notes then go on the slots of that subdivision which
    have an attack.

    This is the part that decides whether a chart feels like music or like
    noise. Picking every attack that happens to clear a minimum gap leaves
    dotted, three-sixteenth stutters between the notes that survive, and that
    is exactly what an unplayable mess sounds like. Committing to one
    subdivision per bar means every gap is a whole number of that subdivision.
    """
    step = 60.0 / bpm / 4.0
    min_gap = max(GAP_FLOOR[level], (60.0 / bpm) * GAP_BEATS[level])
    allowed = [d for d in (1, 2, 4, 8) if d * step >= min_gap - 1e-6] or [8]
    times = []
    for bar in range(0, len(slots), 16):
        window = slots[bar:bar + 16]
        if not window.any():
            continue
        pick = allowed[-1]
        for d in allowed:
            hits = window[::d]
            if len(hits) and float((hits > 0).mean()) >= COVER:
                pick = d
                break
        for j in range(0, len(window), pick):
            if window[j] > 0:
                times.append((first + (bar + j) * step, float(window[j]),
                              (bar + j) % 16))
    return times


def to_events(times):
    """Chart events for one difficulty.

    Everything selected is already the right density for the level, so it is
    all tagged as something every difficulty accepts - the thinning happened
    when the subdivision was chosen, and letting the builder thin it again by
    kind would put the stutter straight back.
    """
    events = []
    for (t, strength, slot) in times:
        beat_in_bar = slot // 4
        if slot % 4:
            # off the beat. Only Hyper ever gets these, and tagging them apart
            # keeps the click markers on the beats, where a player expects to
            # be asked to press something
            kind = "lead"
        else:
            kind = "snare" if beat_in_bar in (1, 3) else "kick"
        events.append((round(t, 3), kind, 0, round(min(1.0, 0.5 + strength), 2)))
    return events


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
    length = float(data.get("length", 0.0))
    env, bpm, first, spread = measure(audio, claimed)
    if length <= 0.0:
        length = len(env) / bg.FPS
    slots = slot_grid(env, bpm, first, length)
    quiet = slot_grid(env, bpm, first, length, floor=FLOOR * 0.45)

    note = "" if abs(bpm - claimed) < 0.01 else "  (chart said %.2f)" % claimed
    print("  %-16s %.2f BPM, first beat %+.3f s, hold %.3f s%s, %d filled slots"
          % (sid, bpm, first, spread, note, int((slots > 0).sum())))
    if dry:
        return False

    data["bpm"] = round(bpm, 3)
    out = []
    for name, level in (("Easy", 0), ("Normal", 1), ("Hyper", 2)):
        times = select_times(slots, level, bpm, first)
        if len(times) < 16:
            # a quiet track: listen harder rather than ship an empty chart
            times = select_times(quiet, level, bpm, first)
        notes = build_chart(to_events(times), level, beat_of(bpm), sid)
        out.append({"name": name, "notes": notes})
        print("    %-7s %s" % (name, describe(notes, length)))
    data["difficulties"] = out
    json.dump(data, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return True


def beat_of(bpm: float) -> float:
    return 60.0 / bpm


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
