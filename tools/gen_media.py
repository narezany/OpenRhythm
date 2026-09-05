#!/usr/bin/env python3
"""Open Rhythm music, chart and sfx generator.
Synthesises two tracks (synthwave / edm), lays out Normal and Hyper charts and
writes WAV + JSON into songs/<id>/ plus the sfx into assets/sfx/.
Run from the project root: python3 tools/gen_media.py
"""
import json
import math
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from charting import build_chart, describe   # noqa: E402

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
np.random.seed(7)


def midi2f(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def fft_filter(x, kind, fc):
    """Simple FFT filtering for short samples."""
    n = len(x)
    if n < 8:
        return x.copy()
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    if kind == "lp":
        H = 1.0 / (1.0 + (f / fc) ** 2)
    elif kind == "hp":
        H = (f / fc) ** 2 / (1.0 + (f / fc) ** 2)
    else:  # bp
        H = (f / fc) / (1.0 + (f / fc) ** 2)
    return np.fft.irfft(X * H, n)


class Song:
    def __init__(self, bpm, bars):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.len_s = bars * 4 * self.beat + 2.2
        self.n = int(self.len_s * SR)
        self.buf = np.zeros(self.n)
        self.duck = np.ones(self.n)
        self.events = []  # (time, kind, midi, vel)

    # -- place signals ----------------------------------------------------
    def place(self, t0, sig, gain=1.0, ducked=True):
        i0 = int(t0 * SR)
        if i0 >= self.n:
            return
        i1 = min(self.n, i0 + len(sig))
        seg = sig[: i1 - i0] * gain
        if ducked:
            seg = seg * self.duck[i0:i1]
        self.buf[i0:i1] += seg

    def duck_curve(self, kick_times, depth=0.5, dur=0.30):
        for t in kick_times:
            i0 = int(t * SR)
            n = int(dur * SR)
            if i0 >= self.n:
                continue
            i1 = min(self.n, i0 + n)
            tseg = np.arange(i1 - i0) / SR
            self.duck[i0:i1] *= 1.0 - depth * np.exp(-tseg / 0.075)

    # -- instruments -------------------------------------------------------
    def kick(self, t0, vel=1.0):
        dur = 0.38
        t = np.arange(int(dur * SR)) / SR
        f = 46 + (150 - 46) * np.exp(-t * 26)
        ph = 2 * np.pi * np.cumsum(f) / SR
        body = np.sin(ph) * np.exp(-t / 0.115)
        click = fft_filter(np.random.randn(int(0.008 * SR)), "hp", 3000) * np.exp(
            -np.arange(int(0.008 * SR)) / SR / 0.003
        )
        sig = body.copy()
        sig[: len(click)] += click * 0.5
        sig = np.tanh(sig * 2.2)
        self.place(t0, sig, 0.95 * vel, ducked=False)
        self.events.append((t0, "kick", 0, vel))

    def hat(self, t0, open_=False, vel=1.0):
        dur = 0.22 if open_ else 0.055
        x = np.random.randn(int(dur * SR))
        sig = fft_filter(x, "hp", 6500)
        t = np.arange(len(sig)) / SR
        sig *= np.exp(-t / (0.11 if open_ else 0.016))
        self.place(t0, sig, 0.16 * vel)
        # recorded so the chart builder can use hats as filler on Hyper
        self.events.append((t0, "hat", 0, vel))

    def clap(self, t0, vel=1.0):
        n = int(0.32 * SR)
        x = fft_filter(np.random.randn(n), "hp", 900) * fft_filter(
            np.random.randn(n), "lp", 4500
        )
        env = np.zeros(n)
        for off in (0.0, 0.011, 0.023):
            i0 = int(off * SR)
            d = int(0.013 * SR)
            env[i0 : i0 + d] += np.exp(-np.arange(d) / SR / 0.005)
        i0 = int(0.036 * SR)
        env[i0:] += np.exp(-np.arange(n - i0) / SR / 0.10) * 0.7
        self.place(t0, x * env, 0.5 * vel)
        self.events.append((t0, "clap", 0, vel))

    def bass(self, t0, dur, midi, vel=1.0):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = midi2f(midi)
        saw = 2.0 * ((t * f) % 1.0) - 1.0
        sub = np.sin(2 * np.pi * f / 2 * t)
        sig = fft_filter(saw * 0.7 + sub * 0.55, "lp", 700)
        env = np.minimum(t / 0.004, 1.0) * np.exp(-np.maximum(t - dur * 0.75, 0) / 0.05)
        self.place(t0, sig * env, 0.5 * vel)
        self.events.append((t0, "bass", midi, vel))

    def lead(self, t0, dur, midi, vel=1.0):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = midi2f(midi)
        sig = (
            2.0 * ((t * f * 1.0035) % 1.0)
            + 2.0 * ((t * f * 0.9965) % 1.0)
            + 0.55 * np.sin(2 * np.pi * f * 2.0 * t)
        ) / 3.0
        sig = fft_filter(sig, "lp", 3800)
        env = np.minimum(t / 0.005, 1.0)
        env *= np.exp(-np.maximum(t - dur * 0.55, 0) / (0.16 * dur + 0.02))
        sig = sig * env
        echo = int(self.beat * 0.75 * SR)
        out = np.zeros(len(sig) + echo * 2)
        out[: len(sig)] += sig
        out[echo : echo + len(sig)] += sig * 0.34
        out[2 * echo : 2 * echo + len(sig)] += sig * 0.12
        self.place(t0, out, 0.30 * vel)

    def crash(self, t0, vel=1.0):
        dur = 1.1
        x = fft_filter(np.random.randn(int(dur * SR)), "hp", 5200)
        t = np.arange(len(x)) / SR
        self.place(t0, x * np.exp(-t / 0.45), 0.22 * vel)

    # -- master -------------------------------------------------------------
    def master(self):
        mix = np.tanh(self.buf * 1.35) * 0.88
        peak = np.max(np.abs(mix)) or 1.0
        if peak > 0.95:
            mix *= 0.95 / peak
        d = int(0.00024 * SR)
        R = mix * 0.982
        R[d:] = R[d:] + mix[:-d] * 0.018
        return mix, R

    def save(self, path):
        L, R = self.master()
        pcm = np.empty((len(L) * 2,), dtype=np.int16)
        pcm[0::2] = np.clip(L * 32767, -32768, 32767).astype(np.int16)
        pcm[1::2] = np.clip(R * 32767, -32768, 32767).astype(np.int16)
        with wave.open(path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        rms = float(np.sqrt(np.mean(L**2)))
        print(
            f"  wav: {path}  {len(L)/SR:.1f}s  peak={np.max(np.abs(L)):.2f} rms={rms:.3f}"
        )


# --------------------------------------------------------------------------
# Track 1 — Neon Drift (120 bpm, A minor, 30 bars)
# --------------------------------------------------------------------------
def track_neon_drift():
    s = Song(120, 30)
    B = s.beat
    roots = [45, 41, 48, 43]  # Am F C G
    arp_pat = [0, 7, 3, 12, 0, 7, 3, 10, 0, 7, 3, 12, 15, 12, 10, 7]
    bass_pat = [0, 0, 7, 0, 0, 0, 7, 12]
    kick_times = []

    def section(b):
        if b < 4:
            return "intro"
        if b < 8:
            return "build"
        if b < 16:
            return "dropA"
        if b < 20:
            return "break"
        if b < 28:
            return "dropB"
        return "outro"

    for b in range(30):
        sec = section(b)
        t0 = b * 4 * B
        root = roots[b % 4]
        # drums
        if sec != "break":
            for k in range(4):
                s.kick(t0 + k * B, 1.0 if k % 2 == 0 else 0.9)
                kick_times.append(t0 + k * B)
        if sec == "outro" and b == 29:
            continue
        if sec == "intro":
            for e in range(8):
                s.hat(t0 + e * B / 2, vel=0.7 if e % 2 else 1.0)
        elif sec == "build":
            for e in range(8):
                s.hat(t0 + e * B / 2, vel=0.8 if e % 2 else 1.0)
            s.hat(t0 + 3.5 * B, open_=True, vel=0.9)
        elif sec in ("dropA", "dropB"):
            for e in range(8):
                s.hat(t0 + e * B / 2, open_=(e == 3 or e == 7), vel=0.9 if e % 2 else 1.0)
        elif sec == "break":
            for e in range(8):
                s.hat(t0 + e * B / 2, vel=0.45 if e % 2 else 0.6)
        if sec in ("build", "dropA", "dropB", "break"):
            for k in (1, 3):
                s.clap(t0 + k * B, 0.9 if sec != "break" else 0.7)
        # bass
        if sec == "build":
            for e, off in enumerate(bass_pat):
                s.bass(t0 + e * B / 2, B / 2 * 0.9, root + off, 0.9)
        elif sec in ("dropA", "dropB"):
            for e, off in enumerate(bass_pat):
                s.bass(t0 + e * B / 2, B / 2 * 0.9, root + off, 1.0)
        elif sec == "break":
            s.bass(t0, B * 2.4, root, 0.8)
            s.bass(t0 + 2 * B, B * 1.6, root + 7, 0.7)
        # lead
        if sec == "dropA":
            for i, off in enumerate(arp_pat):
                if i % 8 in (1, 6) and b % 2 == 1:  # a little air
                    continue
                s.lead(t0 + i * B / 4, B / 4 * 0.95, root + 24 + off, 0.9 if i % 4 == 0 else 0.72)
                s.events.append(
                    (t0 + i * B / 4, "lead", root + 24 + off, 0.9 if i % 4 == 0 else 0.72)
                )
        elif sec == "dropB":
            for i, off in enumerate(arp_pat):
                s.lead(t0 + i * B / 4, B / 4 * 0.95, root + 36 + off, 0.8 if i % 4 == 0 else 0.6)
                s.events.append(
                    (t0 + i * B / 4, "lead", root + 36 + off, 0.8 if i % 4 == 0 else 0.6)
                )
        elif sec == "break":
            for k, off in enumerate([0, 3, 7, 12]):
                s.lead(t0 + k * B, B * 0.9, root + 24 + off, 0.75)
                s.events.append((t0 + k * B, "lead", root + 24 + off, 0.75))
        elif sec == "outro":
            for k in range(4):
                s.lead(t0 + k * B, B * 0.8, root + 24 + [0, 7, 12, 7][k], 0.6)
                s.events.append((t0 + k * B, "lead", root + 24 + [0, 7, 12, 7][k], 0.6))
        if b in (8, 20, 28):
            s.crash(t0, 1.0)
        if b == 29:
            s.kick(t0 + 2 * B, 1.1)
            s.crash(t0 + 2 * B, 1.0)
            s.bass(t0 + 2 * B, B * 2, root, 1.0)
            kick_times.append(t0 + 2 * B)

    s.duck_curve(kick_times)
    return s


# --------------------------------------------------------------------------
# Track 2 — Hyper Drive (160 bpm, E minor, 28 bars)
# --------------------------------------------------------------------------
def track_hyper_drive():
    s = Song(160, 28)
    B = s.beat
    roots = [40, 36, 43, 38]  # Em C G D
    arp_pat = [0, 3, 7, 12, 7, 3, 0, 7, 12, 15, 12, 7, 3, 7, 10, 7]
    kick_times = []

    def section(b):
        if b < 4:
            return "intro"
        if b < 12:
            return "drop"
        if b < 16:
            return "break"
        if b < 24:
            return "drop2"
        return "outro"

    for b in range(28):
        sec = section(b)
        t0 = b * 4 * B
        root = roots[b % 4]
        if sec != "break":
            for k in range(4):
                s.kick(t0 + k * B)
                kick_times.append(t0 + k * B)
                if sec == "drop2" and k in (1, 3) and b % 2 == 1:
                    s.kick(t0 + k * B + B * 0.5, 0.75)
                    kick_times.append(t0 + k * B + B * 0.5)
        for i in range(16):
            if sec == "break" and i % 4 != 0:
                continue
            s.hat(t0 + i * B / 4, open_=(sec != "intro" and i % 8 == 6),
                  vel=0.8 if i % 4 else 1.0)
        if sec in ("drop", "drop2", "outro", "break"):
            for k in (1, 3):
                s.clap(t0 + k * B, 0.8 if sec != "break" else 0.6)
        if sec in ("drop", "drop2"):
            for i in range(16):
                off = [0, 0, 12, 0, 7, 0, 0, 10, 0, 0, 12, 0, 7, 3, 0, 12][i]
                s.bass(t0 + i * B / 4, B / 4 * 0.85, root + off, 0.95)
            for i, off in enumerate(arp_pat):
                oct_ = 24 if sec == "drop" else 36
                vel = 0.85 if i % 4 == 0 else 0.6
                s.lead(t0 + i * B / 4, B / 4 * 0.9, root + oct_ + off, vel)
                s.events.append((t0 + i * B / 4, "lead", root + oct_ + off, vel))
        elif sec == "break":
            s.bass(t0, B * 3.6, root, 0.85)
            for k, off in enumerate([0, 7, 12, 15]):
                s.lead(t0 + k * B, B * 0.85, root + 24 + off, 0.7)
                s.events.append((t0 + k * B, "lead", root + 24 + off, 0.7))
        elif sec == "intro":
            for e, off in enumerate([0, 0, 7, 0, 0, 0, 7, 12]):
                s.bass(t0 + e * B / 2, B / 2 * 0.9, root + off, 0.9)
            for k, off in enumerate([0, 7, 3, 12]):
                s.lead(t0 + k * B, B * 0.7, root + 24 + off, 0.55)
                s.events.append((t0 + k * B, "lead", root + 24 + off, 0.55))
        elif sec == "outro":
            for e, off in enumerate([0, 0, 7, 0, 0, 0, 7, 12]):
                s.bass(t0 + e * B / 2, B / 2 * 0.9, root + off, 0.9 if b < 27 else 0.6)
            for k, off in enumerate([0, 3, 7, 12]):
                s.lead(t0 + k * B, B * 0.8, root + 24 + off, 0.55)
                s.events.append((t0 + k * B, "lead", root + 24 + off, 0.55))
        if b in (4, 16, 24):
            s.crash(t0)
        if b == 27:
            s.kick(t0 + 2 * B, 1.1)
            s.crash(t0 + 2 * B)
            kick_times.append(t0 + 2 * B)

    s.duck_curve(kick_times, depth=0.55)
    return s


# --------------------------------------------------------------------------
# Charts
# --------------------------------------------------------------------------
LANE_ANGLE = 45.0  # deg per lane; lane*45, 0 = up, clockwise


def pitch_lane(midi, base):
    return int(round((midi - base) / 2.0)) % 8


def build_notes(events, dense):
    notes = []
    lane_last = {}
    li = 0
    cycle = [0, 4, 2, 6, 1, 5, 3, 7]
    last_any = -1.0
    for (t, kind, midi, vel) in sorted(events, key=lambda e: e[0]):
        cand = []
        if kind == "kick":
            lane = cycle[li % 8]
            li += 1
            cand = [(lane, 0.45 if li % 2 else 0.6, 1.25 if li % 8 == 1 else 1.0)]
        elif kind == "clap":
            pair = [(2, 6), (1, 5), (3, 7)][li % 3]
            cand = [(pair[0], 0.5, 1.05), (pair[1], 0.5, 1.05)]
        elif kind == "lead":
            if not dense and t - last_any < 0.12:
                continue
            if not dense and vel < 0.7:
                continue
            lane = pitch_lane(midi, 36)
            cand = [(lane, 0.3 if vel > 0.7 else 0.22, 0.9 if vel > 0.7 else 0.75)]
            if dense and vel > 0.8:
                cand.append(((lane + 4) % 8, 0.3, 0.7))
        else:
            continue
        for (lane, d, sz) in cand:
            if t - lane_last.get(lane, -9) < 0.1:
                lane2 = (lane + 4) % 8
                if t - lane_last.get(lane2, -9) < 0.1:
                    continue
                lane = lane2
            lane_last[lane] = t
            notes.append({"t": round(t, 3), "a": lane * LANE_ANGLE, "d": d, "s": sz})
            last_any = t
    notes.sort(key=lambda n: n["t"])
    return notes


def open_hat_notes(s, dense):
    pass  # hats stay out of the chart, it is dense enough already


def _diffs(song, key):
    """Easy / Normal / Hyper from the same events, via the shared builder."""
    out = []
    for name, level in (("Easy", 0), ("Normal", 1), ("Hyper", 2)):
        notes = build_chart(song.events, level, song.beat, key)
        out.append((name, notes))
        print("    %-7s %s" % (name, describe(notes, song.len_s - 2.0)))
    return out


def write_song(song_dir, meta, song, diffs):
    os.makedirs(song_dir, exist_ok=True)
    song.save(os.path.join(song_dir, "audio.wav"))
    data = dict(meta)
    data["length"] = round(song.len_s - 2.0, 2)
    data["audio"] = "audio.wav"
    data["difficulties"] = []
    for name, notes in diffs:
        data["difficulties"].append({"name": name, "notes": notes})
    with open(os.path.join(song_dir, "map.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    for d in data["difficulties"]:
        print(f"  map: {meta['id']} / {d['name']}: {len(d['notes'])} notes")


def write_sfx():
    out = os.path.join(ROOT, "assets", "sfx")
    os.makedirs(out, exist_ok=True)

    def save(name, sig, gain):
        sig = np.tanh(sig * 1.5) * gain
        pcm = (np.clip(sig, -1, 1) * 32767).astype(np.int16)
        with wave.open(os.path.join(out, name), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())

    # hit: a bright tick
    t = np.arange(int(0.09 * SR)) / SR
    sig = np.sin(2 * np.pi * 1250 * t) * np.exp(-t / 0.018)
    sig += np.sin(2 * np.pi * 2500 * t) * np.exp(-t / 0.008) * 0.5
    sig += fft_filter(np.random.randn(len(t)), "hp", 4000) * np.exp(-t / 0.004) * 0.4
    save("hit.wav", sig, 0.6)
    # miss: a dull thud
    t = np.arange(int(0.16 * SR)) / SR
    f = 120 * np.exp(-t * 8) + 55
    sig = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.07)
    sig += fft_filter(np.random.randn(len(t)), "lp", 350) * np.exp(-t / 0.05) * 0.8
    save("miss.wav", sig, 0.55)
    # click: the interface sound
    t = np.arange(int(0.05 * SR)) / SR
    sig = np.sin(2 * np.pi * 850 * t) * np.exp(-t / 0.012)
    save("click.wav", sig, 0.4)
    print(f"  sfx -> {out}")


def main():
    print("SFX:")
    write_sfx()
    print("Neon Drift:")
    s1 = track_neon_drift()
    write_song(
        os.path.join(ROOT, "songs", "neon_drift"),
        {
            "id": "neon_drift",
            "title": "Neon Drift",
            "artist": "Open Rhythm OST",
            "bpm": 120.0,
            "preview_start": 16.0,
        },
        s1,
        _diffs(s1, "neon_drift"),
    )
    print("Hyper Drive:")
    s2 = track_hyper_drive()
    write_song(
        os.path.join(ROOT, "songs", "hyper_drive"),
        {
            "id": "hyper_drive",
            "title": "Hyper Drive",
            "artist": "Open Rhythm OST",
            "bpm": 160.0,
            "preview_start": 6.0,
        },
        s2,
        _diffs(s2, "hyper_drive"),
    )
    print("done.")


if __name__ == "__main__":
    main()
