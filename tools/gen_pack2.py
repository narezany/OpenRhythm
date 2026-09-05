#!/usr/bin/env python3
"""Open Rhythm second music pack: four club-leaning original tracks with charts.

Reuses the synth toolkit from gen_media.py and adds the instruments the heavier
styles need. Audio is written as WAV, encoded to OGG with ffmpeg and the WAV is
dropped, so the repository stays small. A waveform.json is written next to each
track so the editor can draw a waveform for a compressed file too.

Run from the project root:  python3 tools/gen_pack2.py
"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_media import SR, ROOT, Song, fft_filter, midi2f   # noqa: E402
from charting import build_chart, describe                 # noqa: E402

np.random.seed(1312)

WAVE_RATE = 100.0          # waveform peaks per second, matches the editor


# --------------------------------------------------------------------------
# Extra instruments
# --------------------------------------------------------------------------
class Track(Song):
    def snare(self, t0, vel=1.0):
        n = int(0.26 * SR)
        t = np.arange(n) / SR
        noise = fft_filter(np.random.randn(n), "hp", 1400) * np.exp(-t / 0.075)
        body = (np.sin(2 * np.pi * 185 * t) + np.sin(2 * np.pi * 278 * t)) * np.exp(-t / 0.045)
        sig = np.tanh((noise * 0.9 + body * 0.5) * 1.6)
        self.place(t0, sig, 0.42 * vel)
        self.events.append((t0, "snare", 0, vel))

    def sub(self, t0, dur, midi, vel=1.0):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = midi2f(midi)
        sig = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(4 * np.pi * f * t)
        env = np.minimum(t / 0.006, 1.0) * np.exp(-np.maximum(t - dur * 0.8, 0) / 0.04)
        self.place(t0, sig * env, 0.44 * vel)

    def reese(self, t0, dur, midi, vel=1.0):
        """Detuned saw pair with slow movement - the classic drum'n'bass bass."""
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = midi2f(midi)
        lfo = 1.0 + 0.012 * np.sin(2 * np.pi * 5.5 * t)
        a = 2.0 * ((t * f * 0.995 * lfo) % 1.0) - 1.0
        b = 2.0 * ((t * f * 1.006 / lfo) % 1.0) - 1.0
        c = np.sin(2 * np.pi * f * 0.5 * t)
        sig = fft_filter(a * 0.5 + b * 0.5 + c * 0.6, "lp", 520)
        env = np.minimum(t / 0.01, 1.0) * np.minimum((dur - t) / 0.05, 1.0).clip(0, 1)
        self.place(t0, np.tanh(sig * 1.4) * env, 0.40 * vel)
        self.events.append((t0, "bass", midi, vel))

    def wobble(self, t0, dur, midi, rate=2.0, vel=1.0):
        """LFO-swept saw: the cutoff moves, so the tone breathes."""
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = midi2f(midi)
        saw = 2.0 * ((t * f) % 1.0) - 1.0
        saw += 2.0 * ((t * f * 1.004) % 1.0) - 1.0
        out = np.zeros(n)
        step = int(0.02 * SR)
        for i in range(0, n, step):
            j = min(n, i + step)
            phase = 0.5 - 0.5 * np.cos(2 * np.pi * rate * (i / SR))
            fc = 180.0 + 2100.0 * phase
            out[i:j] = fft_filter(saw[i:j], "lp", fc)
        env = np.minimum(t / 0.01, 1.0) * np.minimum((dur - t) / 0.04, 1.0).clip(0, 1)
        self.place(t0, np.tanh(out * 1.3) * env, 0.34 * vel)
        self.events.append((t0, "bass", midi, vel))

    def stab(self, t0, dur, chord, vel=1.0):
        """Short detuned chord hit."""
        n = int(dur * SR)
        t = np.arange(n) / SR
        sig = np.zeros(n)
        for m in chord:
            f = midi2f(m)
            sig += 2.0 * ((t * f * 1.0025) % 1.0) - 1.0
            sig += 2.0 * ((t * f * 0.9975) % 1.0) - 1.0
        sig = fft_filter(sig / (2 * len(chord)), "lp", 2600)
        env = np.minimum(t / 0.004, 1.0) * np.exp(-t / (dur * 0.32))
        self.place(t0, sig * env, 0.34 * vel)
        self.events.append((t0, "lead", chord[0], vel))

    def pluck(self, t0, dur, midi, vel=1.0):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = midi2f(midi)
        sig = np.sin(2 * np.pi * f * t) + 0.42 * np.sin(4 * np.pi * f * t) \
            + 0.2 * np.sin(6 * np.pi * f * t)
        env = np.minimum(t / 0.003, 1.0) * np.exp(-t / (0.09 + dur * 0.2))
        sig = fft_filter(sig * env, "lp", 5200)
        echo = int(self.beat * 0.5 * SR)
        out = np.zeros(n + echo * 2)
        out[:n] += sig
        out[echo:echo + n] += sig * 0.3
        out[2 * echo:2 * echo + n] += sig * 0.1
        self.place(t0, out, 0.30 * vel)
        self.events.append((t0, "lead", midi, vel))

    def pad(self, t0, dur, chord, vel=1.0):
        n = int(dur * SR)
        t = np.arange(n) / SR
        sig = np.zeros(n)
        for k, m in enumerate(chord):
            f = midi2f(m)
            sig += np.sin(2 * np.pi * f * t + k) * (1.0 / (k + 1.4))
            sig += 0.3 * (2.0 * ((t * f * 1.003) % 1.0) - 1.0)
        sig = fft_filter(sig / len(chord), "lp", 1500)
        env = np.minimum(t / (dur * 0.25), 1.0) * np.minimum((dur - t) / (dur * 0.3), 1.0)
        self.place(t0, sig * env.clip(0, 1), 0.16 * vel)

    def riser(self, t0, dur, vel=1.0):
        n = int(dur * SR)
        t = np.arange(n) / SR
        x = np.random.randn(n)
        out = np.zeros(n)
        step = int(0.05 * SR)
        for i in range(0, n, step):
            j = min(n, i + step)
            fc = 300.0 + 6000.0 * (i / n) ** 2
            out[i:j] = fft_filter(x[i:j], "hp", fc)
        self.place(t0, out * (t / dur) ** 2, 0.13 * vel)

    def sweep_down(self, t0, dur, vel=1.0):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = 900 * np.exp(-t * 3.0) + 40
        ph = 2 * np.pi * np.cumsum(f) / SR
        self.place(t0, np.sin(ph) * np.exp(-t / (dur * 0.4)), 0.25 * vel)


# --------------------------------------------------------------------------
# Tracks
# --------------------------------------------------------------------------
def track_midnight_pulse():
    """126 BPM deep house: four on the floor, offbeat hats, warm chords."""
    s = Track(126.0, 44)
    b = s.beat
    bar = b * 4
    chords = [[45, 52, 57, 60], [43, 50, 55, 59], [41, 48, 53, 57], [46, 53, 58, 62]]
    kicks = []
    for i in range(s.bars):
        t = i * bar
        ch = chords[i % 4]
        if i >= 2:
            for k in range(4):
                kt = t + k * b
                s.kick(kt, 1.0 if k % 2 == 0 else 0.9)
                kicks.append(kt)
        for k in range(4):
            s.hat(t + k * b + b * 0.5, open_=(k == 3), vel=0.85)
        if i >= 4:
            s.clap(t + b, 0.9)
            s.clap(t + 3 * b, 0.9)
        if i >= 2:
            for k in range(8):
                if k % 2 == 1 or k in (0, 6):
                    s.sub(t + k * b * 0.5, b * 0.45, ch[0] - 12, 0.9)
        s.pad(t, bar * 1.02, [m + 12 for m in ch], 0.9 if i >= 6 else 0.6)
        if i >= 8:
            mel = [ch[2] + 12, ch[3] + 12, ch[1] + 12, ch[2] + 12]
            for k, m in enumerate(mel):
                if (i + k) % 3 != 2:
                    s.pluck(t + k * b + (b * 0.5 if k % 2 else 0), b * 0.9, m, 0.9)
        if i >= 20 and i % 8 == 4:
            s.stab(t + 2 * b, b * 1.6, [m + 12 for m in ch[:3]], 1.0)
        if i % 8 == 0 and i >= 8:
            s.crash(t, 0.8)
        if i % 16 == 15:
            s.riser(t, bar, 1.0)
    s.duck_curve(kicks, 0.42, 0.26)
    return s


def track_bass_rush():
    """174 BPM drum and bass: broken beat, reese bass, bright stabs."""
    s = Track(174.0, 64)
    b = s.beat
    bar = b * 4
    root = [38, 38, 41, 36, 38, 43, 41, 36]
    kicks = []
    for i in range(s.bars):
        t = i * bar
        if i >= 4:
            for kt in (t, t + b * 2.5):
                s.kick(kt, 1.0)
                kicks.append(kt)
            s.snare(t + b, 1.0)
            s.snare(t + b * 3, 1.0)
            if i % 4 == 3:
                s.snare(t + b * 3.5, 0.7)
        for k in range(8):
            s.hat(t + k * b * 0.5, open_=(k == 5), vel=0.6 if k % 2 else 0.85)
        r = root[i % 8]
        if i >= 8:
            s.reese(t, bar * 0.62, r - 12, 1.0)
            s.reese(t + bar * 0.65, bar * 0.3, r - 12 + 3, 0.9)
        if i >= 16:
            notes = [r + 12, r + 19, r + 15, r + 24]
            for k, m in enumerate(notes):
                if (i + k) % 4 != 3:
                    s.pluck(t + k * b, b * 0.7, m, 0.95)
        if i >= 32 and i % 8 in (4, 6):
            s.stab(t + b * 2, b * 1.2, [r + 12, r + 15, r + 19], 1.0)
        s.pad(t, bar, [r, r + 7, r + 12], 0.5 if i < 16 else 0.8)
        if i % 8 == 0 and i >= 8:
            s.crash(t, 0.9)
        if i % 16 == 15:
            s.riser(t, bar, 1.0)
    s.duck_curve(kicks, 0.35, 0.2)
    return s


def track_crimson_step():
    """140 BPM half-time: sparse heavy drums and a wobbling bass."""
    s = Track(140.0, 52)
    b = s.beat
    bar = b * 4
    root = [33, 33, 36, 31, 33, 38, 36, 31]
    kicks = []
    for i in range(s.bars):
        t = i * bar
        if i >= 4:
            s.kick(t, 1.0)
            kicks.append(t)
            s.snare(t + b * 2, 1.0)
            if i % 2 == 1:
                s.kick(t + b * 2.75, 0.85)
                kicks.append(t + b * 2.75)
        for k in range(4):
            s.hat(t + k * b + b * 0.5, open_=(k == 2), vel=0.7)
        r = root[i % 8]
        if i >= 8:
            rate = [1.0, 2.0, 4.0, 2.0][i % 4]
            s.wobble(t, bar * 0.48, r, rate, 1.0)
            s.wobble(t + bar * 0.5, bar * 0.46, r + (0 if i % 2 else 5), rate * 2, 0.95)
        if i >= 16 and i % 4 != 3:
            mel = [r + 24, r + 29, r + 27, r + 31]
            for k, m in enumerate(mel):
                if k % 2 == (i // 4) % 2:
                    s.pluck(t + k * b, b * 0.8, m, 0.9)
        if i >= 24 and i % 8 == 0:
            s.stab(t + b * 3, b * 1.4, [r + 12, r + 17, r + 20], 1.0)
        s.pad(t, bar, [r + 12, r + 19, r + 24], 0.7)
        if i % 8 == 0 and i >= 8:
            s.crash(t, 0.85)
        if i % 8 == 7:
            s.sweep_down(t + b * 3, b, 0.9)
    s.duck_curve(kicks, 0.45, 0.3)
    return s


def track_afterburner():
    """172 BPM rave: relentless kick, hoover stabs, an acid line on top."""
    s = Track(172.0, 68)
    b = s.beat
    bar = b * 4
    root = [40, 40, 45, 43, 40, 47, 45, 38]
    acid = [0, 12, 7, 10, 3, 12, 7, 5]
    kicks = []
    for i in range(s.bars):
        t = i * bar
        if i >= 4:
            for k in range(4):
                kt = t + k * b
                s.kick(kt, 1.0)
                kicks.append(kt)
        for k in range(8):
            s.hat(t + k * b * 0.5, open_=(k % 4 == 3), vel=0.55 if k % 2 else 0.8)
        if i >= 8 and i % 2 == 1:
            s.clap(t + b * 2, 1.0)
        r = root[i % 8]
        if i >= 6:
            for k in range(8):
                s.sub(t + k * b * 0.5, b * 0.4, r - 12, 0.85)
        if i >= 12:
            for k in range(8):
                m = r + 12 + acid[(i * 3 + k) % 8]
                if (i + k) % 3 != 1:
                    s.pluck(t + k * b * 0.5, b * 0.42, m, 0.85)
        if i >= 20 and i % 4 == 0:
            s.stab(t, b * 2.2, [r + 12, r + 16, r + 19, r + 24], 1.0)
        s.pad(t, bar, [r, r + 7, r + 12], 0.6)
        if i % 8 == 0 and i >= 8:
            s.crash(t, 0.95)
        if i % 16 == 15:
            s.riser(t, bar, 1.0)
    s.duck_curve(kicks, 0.4, 0.22)
    return s


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------
def write_waveform(song_dir, mono):
    step = int(SR / WAVE_RATE)
    n = len(mono) // step
    peaks = np.abs(mono[: n * step].reshape(n, step)).max(axis=1)
    mx = float(peaks.max()) or 1.0
    peaks = (peaks / mx).round(3)
    with open(os.path.join(song_dir, "waveform.json"), "w") as f:
        json.dump({"rate": WAVE_RATE, "peaks": [float(p) for p in peaks]}, f)


# background hue per track, 0..1 - a song without a video still looks like
# itself instead of every screen being the same red
HUES = {"midnight_pulse": 0.62, "bass_rush": 0.38,
        "crimson_step": 0.985, "afterburner": 0.12}


def write_track(sid, title, bpm, preview, song, diffs):
    song_dir = os.path.join(ROOT, "songs", sid)
    os.makedirs(song_dir, exist_ok=True)
    wav = os.path.join(song_dir, "audio.wav")
    song.save(wav)
    L, _ = song.master()
    write_waveform(song_dir, L)
    ogg = os.path.join(song_dir, "audio.ogg")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
         "-qscale:a", "5", ogg],
        check=True,
    )
    os.remove(wav)
    data = {
        "id": sid,
        "title": title,
        "artist": "Open Rhythm OST",
        "bpm": bpm,
        "preview_start": preview,
        "length": round(song.len_s - 2.0, 2),
        "audio": "audio.ogg",
        "hue": HUES.get(sid, 0.985),
        "difficulties": [{"name": n, "notes": v} for n, v in diffs],
    }
    with open(os.path.join(song_dir, "map.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    size = os.path.getsize(ogg) / 1e6
    print(f"  {sid}: {data['length']}s, ogg {size:.1f} MB, "
          + ", ".join(f"{n}={len(v)}" for n, v in diffs))


def main():
    plan = [
        ("midnight_pulse", "Midnight Pulse", 126.0, 16.0, track_midnight_pulse),
        ("bass_rush", "Bass Rush", 174.0, 22.0, track_bass_rush),
        ("crimson_step", "Crimson Step", 140.0, 18.0, track_crimson_step),
        ("afterburner", "Afterburner", 172.0, 24.0, track_afterburner),
    ]
    for sid, title, bpm, preview, fn in plan:
        print(f"{title}:")
        s = fn()
        diffs = []
        for name, level in (("Easy", 0), ("Normal", 1), ("Hyper", 2)):
            notes = build_chart(s.events, level, s.beat, sid)
            diffs.append((name, notes))
            print("    %-7s %s" % (name, describe(notes, s.len_s - 2.0)))
        write_track(sid, title, bpm, preview, s, diffs)
    print("done.")


if __name__ == "__main__":
    main()
