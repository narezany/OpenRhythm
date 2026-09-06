#!/usr/bin/env python3
"""Build the fallback font: exactly the characters the game's own fonts cannot draw.

Rajdhani and Orbitron are Latin (and Devanagari); Exo 2 adds Cyrillic. Between
them they still cannot spell Chinese, and they have none of the arrows, the
transport symbols, the star or the eighth note the interface uses. On a desktop
or a phone that never showed, because the engine borrows a system font for
anything its own cannot draw - but a browser has nothing to lend, and the web
build printed hex codes in boxes instead.

Shipping a whole CJK face to fix it means 18 MB on a 21 MB download, paid for
by everyone. So this takes the characters the game actually uses - all of them,
in every language, from the scripts and the song files - subtracts what the
shipped fonts already cover, and cuts a font down to just what is left. Six
hundred characters instead of thirty thousand.

Run it after adding or changing UI text in a language the Latin fonts cannot
write, or after a new translation:

    pip install fonttools brotli
    python3 tools/gen_fontpack.py

The sources are downloaded on first run and cached outside the repo. Only the
result is committed, so an ordinary build needs none of this.
"""
import glob
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.expanduser("~/.cache/openrhythm-fonts")
OUT = os.path.join(ROOT, "assets", "fonts", "ORFallback-Subset.ttf")

# What the game already ships. Anything these can draw is not our problem.
BASE = [
    "assets/fonts/Rajdhani-SemiBold.ttf",
    "assets/fonts/Rajdhani-Bold.ttf",
    "assets/fonts/Orbitron-Variable.ttf",
    "assets/fonts/Exo2-Variable.ttf",
]

# Where the rest comes from, in order of preference.
SOURCES = [
    ("NotoSansSC.ttf",
     "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/"
     "NotoSansSC%5Bwght%5D.ttf",
     "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt"),
    ("NotoSansSymbols2.ttf",
     "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssymbols2/"
     "NotoSansSymbols2-Regular.ttf",
     "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssymbols2/OFL.txt"),
]

# The OFL reserves the family names of the fonts we are cutting up, so what
# comes out must not claim to be them.
FAMILY = "OR Fallback"
STYLE = "Regular"

STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')


def used_characters():
    """Every character that can end up on screen, from wherever it is written."""
    chars = set()
    for path in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
        with open(path, encoding="utf-8") as fh:
            for m in STRING.finditer(fh.read()):
                chars |= set(m.group(1))
    songs = glob.glob(os.path.join(ROOT, "songs", "*", "map.json"))
    songs += glob.glob(os.path.join(ROOT, "local_songs", "*", "map.json"))
    for path in songs:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        for key in ("title", "artist", "id"):
            chars |= set(str(data.get(key, "")))
        for key in ("hints", "hints_saber"):
            for hint in data.get(key, []):
                chars |= set(str(hint.get("text", "")))
    return {c for c in chars if ord(c) > 0x20}


def covered_by(paths):
    from fontTools.ttLib import TTFont
    seen = set()
    for rel in paths:
        seen |= set(TTFont(os.path.join(ROOT, rel)).getBestCmap())
    return seen


def fetch(name, url, licence_url):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        print("downloading %s ..." % name)
        urllib.request.urlretrieve(url, path)
        urllib.request.urlretrieve(
            licence_url, os.path.join(CACHE, name.replace(".ttf", "-OFL.txt")))
    return path


#: The weight the cut is taken at. The sources are variable fonts and the
#: result must not be - two variable fonts cannot be merged, and a fallback
#: carrying a whole weight axis for one static use is paying for nothing. 500
#: sits between the SemiBold body face and the Bold one it also stands in for;
#: Chinese will not go bolder in a heading, which is a fair price.
WEIGHT = 500


def subset(src, codepoints, out):
    from fontTools import subset as fsubset
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    font = TTFont(src)
    if "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": WEIGHT}, inplace=True)
    opts = fsubset.Options()
    opts.desubroutinize = True
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    opts.recalc_bounds = True
    subsetter = fsubset.Subsetter(options=opts)
    subsetter.populate(unicodes=codepoints)
    subsetter.subset(font)
    font.save(out)
    return out


def rename(path):
    """The OFL reserves these families' names: what we cut must not wear them."""
    from fontTools.ttLib import TTFont
    font = TTFont(path)
    name = font["name"]
    for record in list(name.names):
        if record.nameID == 1:
            name.setName(FAMILY, 1, record.platformID, record.platEncID, record.langID)
        elif record.nameID == 2:
            name.setName(STYLE, 2, record.platformID, record.platEncID, record.langID)
        elif record.nameID == 4:
            name.setName("%s %s" % (FAMILY, STYLE), 4,
                         record.platformID, record.platEncID, record.langID)
        elif record.nameID == 6:
            name.setName("ORFallback-%s" % STYLE, 6,
                         record.platformID, record.platEncID, record.langID)
    font.save(path)


def main():
    try:
        from fontTools.merge import Merger
    except ImportError:
        sys.exit("needs fonttools: pip install fonttools brotli")

    want = used_characters()
    have = covered_by(BASE)
    missing = sorted(ord(c) for c in want if ord(c) not in have)
    print("%d characters in the game's text, %d of them unspellable by the "
          "fonts it ships" % (len(want), len(missing)))
    if not missing:
        print("nothing to build")
        return

    from fontTools.ttLib import TTFont
    left = set(missing)
    pieces = []
    os.makedirs(CACHE, exist_ok=True)
    for name, url, licence in SOURCES:
        if not left:
            break
        src = fetch(name, url, licence)
        can = set(TTFont(src).getBestCmap()) & left
        if not can:
            continue
        out = os.path.join(CACHE, "cut-" + name)
        subset(src, can, out)
        pieces.append(out)
        print("  %-24s %4d characters, %6.1f KB"
              % (name, len(can), os.path.getsize(out) / 1024.0))
        left -= can
    if left:
        print("still nowhere to be found: %s"
              % " ".join("U+%04X" % c for c in sorted(left)))

    if len(pieces) == 1:
        os.replace(pieces[0], OUT)
    else:
        # merge rather than ship a handful of files: one fallback is one thing
        # to load, one thing to license and one thing to think about
        merged = Merger().merge(pieces)
        merged.save(OUT)
    rename(OUT)
    print("wrote %s  %.1f KB, %d characters"
          % (os.path.relpath(OUT, ROOT), os.path.getsize(OUT) / 1024.0,
             len(missing) - len(left)))


if __name__ == "__main__":
    main()
