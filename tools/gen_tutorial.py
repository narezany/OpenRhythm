#!/usr/bin/env python3
"""Open Rhythm — туториал: короткая синтезированная песня + обучающая карта.
Первые ~35 секунд — текстовые подсказки и одиночные «поймай квадрат»,
затем простая мелодия. Запуск: python3 tools/gen_tutorial.py (из корня).
"""
import json
import math
import os
import wave
import struct

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "songs", "tutorial")
os.makedirs(OUT, exist_ok=True)


def midi2f(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def synth(freq, dur, vol=0.4, attack=0.01, release=0.08):
    """Мягкий synth-плюк: синус + квинта, экспоненциальный спад."""
    n = int(dur * SR)
    buf = []
    for i in range(n):
        t = i / SR
        env = 1.0
        if t < attack:
            env = t / attack
        elif t > dur - release:
            env = max(0.0, (dur - t) / release)
        s = math.sin(2 * math.pi * freq * t) * 0.7 \
            + math.sin(2 * math.pi * freq * 1.5 * t) * 0.2 \
            + math.sin(2 * math.pi * freq * 2.0 * t) * 0.1
        buf.append(s * env * vol)
    return buf


def add(buf, samples, at):
    i0 = int(at * SR)
    for i, s in enumerate(samples):
        j = i0 + i
        if j < len(buf):
            buf[j] += s


def mixdown(events, length):
    n = int(length * SR)
    buf = [0.0] * n
    for t, midi, dur, vol in events:
        add(buf, synth(midi2f(midi), dur, vol), t)
    # мягкий лимитер
    peak = max(1e-6, max(abs(s) for s in buf))
    if peak > 0.95:
        k = 0.95 / peak
        buf = [s * k for s in buf]
    return buf


BPM = 100.0
BEAT = 60.0 / BPM
INTRO_END = 32.0   # конец обучающей части

events = []
# --- аккордовый фон (бар стоит на месте, создаёт настроение, не мешает) ---
chords = [(45, 52, 57), (43, 50, 55), (41, 48, 53), (43, 50, 55)]  # Am G F G
t = 0.0
bar = 0
while t < 64.0:
    ch = chords[bar % len(chords)]
    for m in ch:
        events.append((t, m - 12, BEAT * 3.6, 0.10))   # бас
        events.append((t, m, BEAT * 3.2, 0.07))        # пад
    events.append((t + 0.0, ch[0] + 24, 0.18, 0.05))   # тик
    events.append((t + 2 * BEAT, ch[1] + 24, 0.18, 0.05))
    t += 4 * BEAT
    bar += 1

# --- часть 1: «поймай квадрат» — 4 медленные одиночные ноты ---
catch_times = [12.0, 18.0, 23.0, 28.0]
catch_notes = [69, 72, 74, 76]   # A4 C5 D5 E5 — приятно и заметно
for tt, mm in zip(catch_times, catch_notes):
    events.append((tt, mm, 0.5, 0.34))
    events.append((tt + 0.12, mm + 12, 0.25, 0.10))   # блик

# --- часть 2: простая мелодия (32 такта духа нет — 16 битов) ---
melody = [69, 72, 76, 72, 74, 77, 74, 72, 69, 72, 76, 79, 77, 76, 74, 72]
t = INTRO_END
for i, m in enumerate(melody):
    events.append((t, m, BEAT * 0.9, 0.30))
    if i % 4 == 0:
        events.append((t, m - 12, BEAT * 1.8, 0.12))
    t += BEAT
# повтор мелодии на октаву выше с большей плотностью
t = INTRO_END + len(melody) * BEAT
for i, m in enumerate(melody):
    events.append((t, m + 12, BEAT * 0.9, 0.24))
    events.append((t + BEAT * 0.5, m + 7, BEAT * 0.45, 0.16))
    t += BEAT

end = t + 2.0
buf = mixdown(events, end)

# --- запись wav ---
with wave.open(os.path.join(OUT, "audio.wav"), "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    frames = bytearray()
    for s in buf:
        v = max(-1.0, min(1.0, s))
        frames += struct.pack("<h", int(v * 32767))
    w.writeframes(bytes(frames))

# --- карта: туториальные подсказки + простая раскладка ---
notes = []
# фаза «поймай квадрат»: нота ровно там, где звук
CELLS = [4, 2, 6, 8]   # центр, лево-верх, право-верх, низ
for i, tt in enumerate(catch_times):
    notes.append({"t": round(tt, 3), "cell": CELLS[i], "s": 1.35})  # крупный куб

# фаза мелодии: нота на каждый звук, чередуя клетки
cells_cycle = [4, 1, 3, 7, 5, 1, 3, 7, 4, 2, 6, 8, 5, 3, 7, 1]
for i in range(len(melody) * 2):
    tt = INTRO_END + i * BEAT
    notes.append({"t": round(tt, 3), "cell": cells_cycle[i % len(cells_cycle)], "s": 1.0})

m = {
    "id": "tutorial",
    "title": "TUTORIAL",
    "artist": "Open Rhythm",
    "bpm": BPM,
    "preview_start": 0.0,
    "length": round(end, 2),
    "audio": "audio.wav",
    "difficulties": [{"name": "Easy", "notes": notes}],
}
with open(os.path.join(OUT, "map.json"), "w") as f:
    json.dump(m, f, indent=1)

print("tutorial: %d notes, %.1fs, audio.wav written" % (len(notes), end))
