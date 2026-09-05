#!/usr/bin/env python3
"""Pack a song folder into a .zip the game can install.

Drop the resulting file in the songs folder and press RESCAN: the game
unpacks it on the next scan. It is also the format to hand someone in a chat.

The files go in at the top level of the archive, not inside a folder, because
that is where the game looks for map.json after unpacking.

  python3 tools/pack_song.py local_songs/verity
  python3 tools/pack_song.py local_songs/*  --out dist
"""
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Not worth carrying to someone else: Godot's import bookkeeping is rebuilt on
# the other side, and the waveform cache is derived from the audio.
SKIP_EXT = {".import", ".uid"}
SKIP_NAME = {"waveform.json"}


def pack(song_dir: str, out_dir: str) -> str:
    song_dir = os.path.abspath(song_dir)
    name = os.path.basename(song_dir.rstrip("/"))
    if not os.path.exists(os.path.join(song_dir, "map.json")):
        print("  %-16s no map.json, skipped" % name)
        return ""
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, name + ".zip")
    total = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _dirs, files in os.walk(song_dir):
            for f in sorted(files):
                if os.path.splitext(f)[1] in SKIP_EXT or f in SKIP_NAME:
                    continue
                full = os.path.join(root, f)
                rel = os.path.relpath(full, song_dir)
                z.write(full, rel)
                total += os.path.getsize(full)
    size = os.path.getsize(out)
    print("  %-16s %6.1f MB  (%d files, %.1f MB raw)"
          % (name, size / 1e6, len(zipfile.ZipFile(out).namelist()), total / 1e6))
    return out


def main(argv):
    args = [a for a in argv if not a.startswith("-")]
    out_dir = os.path.join(ROOT, "dist")
    if "--out" in argv:
        out_dir = argv[argv.index("--out") + 1]
        args = [a for a in args if a != out_dir]
    if not args:
        print(__doc__)
        return 1
    for a in args:
        pack(a if os.path.isabs(a) else os.path.join(ROOT, a), out_dir)
    print("packed into %s" % out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
