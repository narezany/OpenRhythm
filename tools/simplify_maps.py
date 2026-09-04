#!/usr/bin/env python3
"""Simplify existing maps: quantize note times to the beat grid, thin density,
convert angle lanes to the 3x3 grid cells. Normal keeps >= 1 beat between notes,
Hyper keeps >= 0.5 beat. Run from project root: python3 tools/simplify_maps.py"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# pleasing traversal of the 3x3 grid (cells 0..8, 4 = center)
CYCLE = [4, 1, 5, 7, 3, 0, 2, 8, 6]
SIZES = [1.0, 0.85, 1.0, 1.15]

# old angle -> cell conversion (0 = up, clockwise)
ANGLE_TO_CELL = {
    0: 1, 45: 2, 90: 5, 135: 8, 180: 7, 225: 6, 270: 3, 315: 0,
}


def cell_from_angle(a):
    return ANGLE_TO_CELL.get(int(round(a / 45.0)) * 45 % 360, 4)


def simplify(notes, bpm, min_beats):
    beat = 60.0 / bpm
    grid = beat * 0.5           # half-beat slots
    slots = {}
    for n in sorted(notes, key=lambda x: x["t"]):
        q = int(round(n["t"] / grid))
        if q not in slots:
            slots[q] = n
    keys = sorted(slots.keys())
    out = []
    last_q = -10**9
    ci = 0
    for q in keys:
        if q - last_q < min_beats * 2:   # min gap in half-beat slots
            continue
        last_q = q
        n = slots[q]
        cell = cell_from_angle(n.get("a", 0.0))
        # avoid same cell twice in a row
        if out and out[-1]["cell"] == cell:
            ci += 1
            cell = CYCLE[ci % len(CYCLE)]
        else:
            ci = (ci + 1) % len(CYCLE)
        out.append({
            "t": round(q * grid, 3),
            "cell": cell if cell != CYCLE[(ci - 1) % len(CYCLE)] else cell,
            "s": SIZES[len(out) % len(SIZES)],
        })
    return out


def main():
    songs_dir = os.path.join(ROOT, "songs")
    for sid in sorted(os.listdir(songs_dir)):
        mp = os.path.join(songs_dir, sid, "map.json")
        if not os.path.isfile(mp):
            continue
        with open(mp, encoding="utf-8") as f:
            data = json.load(f)
        bpm = float(data.get("bpm", 120.0))
        data["preview_start"] = 0.0
        for d in data.get("difficulties", []):
            before = len(d["notes"])
            min_beats = 1.0 if d["name"] == "Normal" else 0.5
            d["notes"] = simplify(d["notes"], bpm, min_beats)
            print(f"{sid}/{d['name']}: {before} -> {len(d['notes'])} notes")
        with open(mp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
