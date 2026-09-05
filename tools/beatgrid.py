"""Beat analysis for the song library.

Measures where the music's beat actually is - tempo and the position of the
first beat - straight from the audio, and reports how far the charted notes sit
from it. The game plays a hitsound the moment a cube lands, so a note that is
off the beat is heard as the game being out of time with the music.

Used by tools/rechart.py and by beatfix.py; runs on its own for a report:

    python3 tools/beatgrid.py                 # every song
    python3 tools/beatgrid.py verity monster  # named songs
    python3 tools/beatgrid.py --check         # fail if a chart is off the beat
    python3 tools/beatgrid.py --selftest      # prove the detector's own timing
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

import numpy as np

SONGS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "songs")
SR = 22050
HOP = 256
NFFT = 1024
FPS = SR / HOP                      # onset envelope frames per second

# A spectral-flux peak lands before the attack that caused it: the analysis
# window reaches back in time, so energy shows up in a frame that started
# earlier than the sound. Measured against a click track at known times
# (--selftest), the lag is this constant, and every time this file reports is
# corrected by it. Without the correction every note in the library looks about
# 43 ms out of time when it is in fact dead on.
ONSET_LAG = 0.0428


# ----------------------------------------------------------------- decoding
def decode(path: str) -> np.ndarray:
    """Mono float32 samples at SR, via ffmpeg so any format works."""
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1",
         "-ar", str(SR), "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.float32)


def onset_envelope(x: np.ndarray) -> np.ndarray:
    """Spectral flux: how much energy appeared since the previous frame.

    Percussive attacks show up as sharp peaks, which is what a listener locks
    onto when they decide where the beat is.
    """
    n = 1 + (len(x) - NFFT) // HOP
    if n < 4:
        return np.zeros(1, dtype=np.float64)
    win = np.hanning(NFFT).astype(np.float32)
    frames = np.lib.stride_tricks.as_strided(
        x, shape=(n, NFFT), strides=(x.strides[0] * HOP, x.strides[0])) * win
    mag = np.abs(np.fft.rfft(frames, axis=1))
    logmag = np.log1p(mag * 8.0)
    flux = np.diff(logmag, axis=0)
    env = np.maximum(flux, 0.0).sum(axis=1)
    # take out the slow swell of the track so a loud chorus does not outvote a
    # quiet verse when the tempo is measured
    k = int(FPS * 0.4) | 1
    pad = np.pad(env, (k // 2, k // 2), mode="edge")
    local = np.convolve(pad, np.ones(k) / k, mode="valid")[:len(env)]
    env = np.maximum(env - local, 0.0)
    peak = env.max()
    return env / peak if peak > 0 else env


# ------------------------------------------------------------------- tempo
def comb(env: np.ndarray, bpm: float) -> tuple[float, float]:
    """(strength, first beat) of a candidate tempo against the onsets."""
    t = np.arange(len(env)) / FPS
    f = bpm / 60.0
    z = np.sum(env * np.exp(-2j * np.pi * f * t))
    first = (-np.angle(z) / (2 * np.pi)) / f + ONSET_LAG
    return (abs(z) / len(env), first % (1.0 / f))


def tempo_phase(env: np.ndarray, lo: float = 60.0, hi: float = 210.0,
                hint: float | None = None) -> tuple[float, float, float]:
    """Best (bpm, first beat in seconds, strength) for this envelope.

    The tempo is found by asking, for a range of candidate periods, how much
    onset energy lands on that period's beats - a comb filter. The phase comes
    from the same sum read as a complex number, which is exact rather than
    quantised to a frame.
    """
    if len(env) < int(FPS * 4):
        return (0.0, 0.0, 0.0)
    t = np.arange(len(env)) / FPS
    best = (0.0, 0.0, -1.0)
    cands = np.arange(lo, hi + 1e-6, 0.02)
    if hint:
        # a chart already claims a tempo; look hard around it and its obvious
        # relatives before considering anything else
        near = []
        for mult in (0.5, 1.0, 2.0):
            near.append(np.arange(hint * mult - 1.5, hint * mult + 1.5, 0.005))
        cands = np.concatenate([np.concatenate(near), cands])
    for bpm in cands:
        f = bpm / 60.0
        z = np.sum(env * np.exp(-2j * np.pi * f * t))
        strength = abs(z) / len(env)
        if strength > best[2]:
            # the angle of that sum is where the beats sit inside the period
            first = (-np.angle(z) / (2 * np.pi)) / f + ONSET_LAG
            first %= 1.0 / f
            best = (float(bpm), float(first), float(strength))
    # The comb cannot tell 128 from 256: at the slower tempo the offbeats land
    # in anti-phase and cancel, so double tempo always scores higher. What
    # separates them is that music leans on alternate beats - kick, hat, kick -
    # so the octave is decided by comparing those two halves of the grid.
    bpm, first, strength = best
    while bpm / 2.0 >= lo:
        pair = _alternation(env, bpm, first)
        if pair is None:
            break
        weak, start = pair
        if weak > 0.8:
            break                   # both halves are equally strong: a real pulse
        bpm, first = bpm / 2.0, start
    return (bpm, first, strength)


def _alternation(env: np.ndarray, bpm: float, first: float):
    """How much weaker the weaker half of this grid is, and where the stronger
    half starts. None when there is not enough of the song to tell."""
    step = 60.0 / bpm
    halves = ([], [])
    k = 0
    while True:
        t = first + k * step
        i = int(round((t - ONSET_LAG) * FPS))
        if i >= len(env):
            break
        if i >= 0:
            halves[k % 2].append(env[i])
        k += 1
    if len(halves[0]) < 8 or len(halves[1]) < 8:
        return None
    m0, m1 = float(np.mean(halves[0])), float(np.mean(halves[1]))
    if max(m0, m1) <= 0.0:
        return None
    if m0 >= m1:
        return (m1 / m0, first)
    return (m0 / m1, first + step)


def refine(env: np.ndarray, bpm: float) -> tuple[float, float]:
    """Sharpen a known tempo: search a narrow window at fine resolution."""
    best = (bpm, 0.0, -1.0)
    t = np.arange(len(env)) / FPS
    for cand in np.arange(bpm - 0.6, bpm + 0.6, 0.002):
        f = cand / 60.0
        z = np.sum(env * np.exp(-2j * np.pi * f * t))
        s = abs(z)
        if s > best[2]:
            first = (-np.angle(z) / (2 * np.pi)) / f + ONSET_LAG
            first %= 1.0 / f
            best = (float(cand), float(first), float(s))
    return best[0], best[1]



# ------------------------------------------------------------------- lock
def _phases(env: np.ndarray, bpm: float, win: float = 12.0) -> np.ndarray:
    """Where the beat sits inside each window of the song, unwrapped.

    A tempo that is even slightly wrong makes this slide steadily in one
    direction, which is exactly what a listener hears as the game falling out
    of time halfway through a long track.
    """
    step = 60.0 / bpm
    w = int(FPS * win)
    if w < 8 or len(env) < w * 2:
        return np.zeros(0)
    out = []
    for s0 in range(0, len(env) - w, w):
        seg = env[s0:s0 + w]
        t = (np.arange(len(seg)) + s0) / FPS
        z = np.sum(seg * np.exp(-2j * np.pi * (bpm / 60.0) * t))
        out.append(((-np.angle(z) / (2 * np.pi)) * step) % step)
    ph = np.array(out)
    return np.unwrap(ph / step * 2 * np.pi) / (2 * np.pi) * step


def lock(env: np.ndarray, bpm: float, win: float = 12.0) -> tuple[float, float, float]:
    """Refine a tempo until the beat stops sliding.

    Returns (bpm, first beat, spread). Spread is how far the beat still wanders
    from a straight line, in seconds - small means the track really does hold
    that tempo, large means it does not and no single grid will fit it.
    """
    for _ in range(24):
        ph = _phases(env, bpm, win)
        if len(ph) < 3:
            return (bpm, comb(env, bpm)[1], float("inf"))
        t = np.arange(len(ph)) * win
        slope, _icept = np.polyfit(t, ph, 1)
        step = 60.0 / bpm
        new = 60.0 / (step + slope * step * step)
        if abs(new - bpm) < 1e-5:
            bpm = new
            break
        bpm = new
    ph = _phases(env, bpm, win)
    t = np.arange(len(ph)) * win
    slope, icept = np.polyfit(t, ph, 1)
    spread = float(np.std(ph - (slope * t + icept)))
    step = 60.0 / bpm
    first = (icept + ONSET_LAG) % step
    return (float(bpm), float(first), spread)


def best_tempo(env: np.ndarray, seeds: list[float],
               lo: float = 60.0) -> tuple[float, float, float]:
    """Try several starting tempos and keep the one the song actually holds.

    Candidates are compared on how far the beat wanders as a fraction of the
    beat itself, not in seconds: a faster grid always looks steadier in
    absolute terms, which would pick double tempo every time. The octave is
    then settled the same way as everywhere else in this file, by asking
    whether the music leans on alternate beats.
    """
    best = (0.0, 0.0, float("inf"))
    for seed in seeds:
        if seed < 40.0 or seed > 400.0:
            continue
        bpm, first, spread = lock(env, seed)
        rel = spread / (60.0 / bpm)
        if rel < best[2]:
            best = (bpm, first, rel)
    bpm, first, rel = best
    if bpm <= 0.0:
        return best
    bpm, first = _octave(env, bpm, first)
    return (bpm, first % (60.0 / bpm), rel * (60.0 / bpm))


# The range people actually count in. Every octave of a tempo fits the onsets
# equally well - 85, 170 and 340 are the same groove - so the one that gets
# written down is the one a listener would tap.
TAP_LO, TAP_HI = 85.0, 185.0


def _octave(env: np.ndarray, bpm: float, first: float) -> tuple[float, float]:
    """Pick which octave of a locked tempo to call the tempo."""
    fam = []
    for k in range(-3, 4):
        b = bpm * (2.0 ** k)
        if b < 40.0 or b > 400.0:
            continue
        f = first
        if k < 0:
            # halving leaves two possible downbeats; keep the stronger half
            f = comb(env, b)[1]
        fam.append((b, f % (60.0 / b)))
    inrange = [(b, f) for (b, f) in fam if TAP_LO <= b < TAP_HI]
    if not inrange:
        return (bpm, first)
    # fastest first: a tempo is only called half as fast when the music really
    # does lean on alternate beats hard enough to hear it that way
    for b, f in sorted(inrange, key=lambda p: -p[0]):
        pair = _alternation(env, b, f)
        if pair is None or pair[0] >= 0.65:
            return (b, f if pair is None else pair[1])
    return sorted(inrange, key=lambda p: -p[0])[0]


# ------------------------------------------------------------------ onsets
def onset_times(env: np.ndarray, thresh: float = 0.12) -> np.ndarray:
    """Frame indices of clear attacks, in seconds."""
    if len(env) < 3:
        return np.zeros(0)
    prev, nxt = env[:-2], env[2:]
    mid = env[1:-1]
    peaks = np.where((mid > prev) & (mid >= nxt) & (mid > thresh))[0] + 1
    return peaks / FPS + ONSET_LAG


def align_error(times: np.ndarray, onsets: np.ndarray) -> tuple[float, float]:
    """Mean and median distance from each note to the nearest attack, in ms."""
    if len(times) == 0 or len(onsets) == 0:
        return (float("nan"), float("nan"))
    idx = np.searchsorted(onsets, times)
    idx = np.clip(idx, 1, len(onsets) - 1)
    left = onsets[idx - 1]
    right = onsets[np.clip(idx, 0, len(onsets) - 1)]
    d = np.minimum(np.abs(times - left), np.abs(times - right))
    return (float(np.mean(d) * 1000.0), float(np.median(d) * 1000.0))


def grid_error(times: np.ndarray, bpm: float, first: float,
               div: int = 4) -> tuple[float, float]:
    """Mean and median distance from each note to the beat grid, in ms."""
    if len(times) == 0 or bpm <= 0:
        return (float("nan"), float("nan"))
    step = 60.0 / bpm / div
    d = np.abs(((times - first + step / 2) % step) - step / 2)
    return (float(np.mean(d) * 1000.0), float(np.median(d) * 1000.0))


# ------------------------------------------------------------------ report
def audio_of(sid: str) -> str | None:
    folder = os.path.join(SONGS, sid)
    if not os.path.isdir(folder):
        return None
    mp = os.path.join(folder, "map.json")
    if os.path.exists(mp):
        name = json.load(open(mp)).get("audio", "")
        if name and os.path.exists(os.path.join(folder, name)):
            return os.path.join(folder, name)
    for f in sorted(os.listdir(folder)):
        if f.rsplit(".", 1)[-1].lower() in ("wav", "ogg", "mp3"):
            return os.path.join(folder, f)
    return None


def analyse(sid: str) -> dict:
    folder = os.path.join(SONGS, sid)
    mp = json.load(open(os.path.join(folder, "map.json")))
    path = audio_of(sid)
    if path is None:
        return {"id": sid, "error": "no audio"}
    env = onset_envelope(decode(path))
    claimed = float(mp.get("bpm", 120.0))
    rough = tempo_phase(env, hint=claimed)[0]
    bpm, first, strength = best_tempo(
        env, [claimed, claimed * 2.0, claimed / 2.0, rough, rough * 2.0, rough / 2.0])
    ons = onset_times(env)
    out = {
        "id": sid, "audio": os.path.basename(path), "claimed_bpm": claimed,
        "bpm": bpm, "first_beat": first, "strength": strength,
        "onsets": len(ons), "diffs": {},
    }
    for d in mp.get("difficulties", []):
        times = np.array([float(n["t"]) for n in d.get("notes", [])])
        out["diffs"][d.get("name", "?")] = {
            "notes": len(times),
            "to_onset": align_error(times, ons),
            "to_grid_now": grid_error(times, claimed, 0.0),
            "to_grid_true": grid_error(times, bpm, first),
        }
    return out


def selftest() -> int:
    """Measure the detector against clicks at times we already know.

    Everything here rests on the timing being right, so the timing is checked
    rather than assumed.
    """
    rng = np.random.default_rng(7)
    bpm, dur = 128.0, 30.0
    x = np.zeros(int(SR * dur), dtype=np.float32)
    truth = np.arange(0.0, dur - 0.5, 60.0 / bpm / 2.0)
    for k, t in enumerate(truth):
        i = int(t * SR)
        n = int(0.02 * SR)
        shape = np.exp(-np.arange(n) / (0.004 * SR))
        tone = np.sin(2 * np.pi * 180 * np.arange(n) / SR) + 0.6 * rng.standard_normal(n)
        # a kick on the beat, a quieter hat between: without that difference
        # there is nothing in the signal to say whether the tempo is 128 or 256
        loud = 0.8 if k % 2 == 0 else 0.36
        x[i:i + n] += (shape * tone).astype(np.float32) * loud
    x += (rng.standard_normal(len(x)) * 0.01).astype(np.float32)
    env = onset_envelope(x)
    ons = onset_times(env)
    d = np.array([o - truth[np.argmin(np.abs(truth - o))] for o in ons])
    got_bpm, first, _ = tempo_phase(env, hint=bpm)
    bias = float(np.median(d)) * 1000.0
    phase = ((first + 60.0 / bpm / 2.0) % (60.0 / bpm)) - 60.0 / bpm / 2.0
    print("onsets     %d found for %d clicks" % (len(ons), len(truth)))
    print("bias       %+.1f ms (median), spread %.1f ms" % (bias, float(d.std()) * 1000.0))
    print("tempo      %.3f BPM, wanted %.1f" % (got_bpm, bpm))
    print("first beat %+.1f ms from zero" % (phase * 1000.0))
    bad = abs(bias) > 6.0 or abs(got_bpm - bpm) > 0.1 or abs(phase) > 0.012
    print("FAIL - the detector is not trustworthy" if bad else "OK")
    return 1 if bad else 0


## How far the middle note of a difficulty may sit from the attack it is meant
## to land on. The detector itself is good to about 3 ms, so anything under
## this is inaudible; a chart on the wrong tempo lands in the tens or hundreds.
CHECK_MS = 15.0


def check(ids: list[str]) -> int:
    """Fail if any chart has drifted off the music it is charted against."""
    bad = 0
    for sid in ids:
        if not os.path.isdir(os.path.join(SONGS, sid)):
            continue
        r = analyse(sid)
        if "error" in r:
            continue
        for name, d in r["diffs"].items():
            median = d["to_onset"][1]
            ok = median <= CHECK_MS
            bad += 0 if ok else 1
            print("%s  %-15s %-7s %5.1f ms from the music"
                  % ("PASS" if ok else "FAIL", r["id"], name, median))
    print("--- charts off the beat: %d" % bad)
    return 1 if bad else 0


def main(argv: list[str]) -> None:
    if argv and argv[0] == "--selftest":
        raise SystemExit(selftest())
    if argv and argv[0] == "--check":
        raise SystemExit(check(argv[1:] or sorted(os.listdir(SONGS))))
    ids = argv or sorted(os.listdir(SONGS))
    for sid in ids:
        if not os.path.isdir(os.path.join(SONGS, sid)):
            continue
        r = analyse(sid)
        if "error" in r:
            print("%-15s %s" % (sid, r["error"]))
            continue
        drift = (r["bpm"] - r["claimed_bpm"]) / max(r["claimed_bpm"], 1e-9)
        print("%-15s chart %6.2f BPM | audio %6.2f BPM (%+0.2f%%), first beat %6.3f s"
              % (sid, r["claimed_bpm"], r["bpm"], drift * 100.0, r["first_beat"]))
        for name, d in r["diffs"].items():
            print("      %-7s %4d notes | to onset %6.1f/%6.1f ms | "
                  "grid as charted %6.1f ms | grid measured %6.1f ms"
                  % (name, d["notes"], d["to_onset"][0], d["to_onset"][1],
                     d["to_grid_now"][1], d["to_grid_true"][1]))


if __name__ == "__main__":
    main(sys.argv[1:])
