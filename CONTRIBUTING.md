# Contributing

## Maps first

The most useful thing you can add is a map. Build one in the in-game editor,
then open a pull request with the song folder — **without the audio** unless
you own it or the author has said yes in writing. A `map.json` on its own is
fine: players point it at their own copy of the track.

Read [docs/MAP_FORMAT.md](docs/MAP_FORMAT.md) first.

## Code

The project is plain Godot 4 + GDScript. No plugins, no C#.

```
scripts/
├── G.gd                 autoload: settings, save file, palette, UI helpers
├── Loc.gd               autoload: runtime translations
├── Conductor.gd         autoload: the musical clock
├── UICursor.gd          autoload: the game's own cursor
├── Main.gd              screen state machine
├── *Screen.gd           one file per screen
├── core/                Judge, RhythmMap, MapImport, Replay, Achievements, Binds
├── editor/              EditorTimeline (piano roll), EditorHistory (undo)
└── playfield/           note/frame/effect views, Melly's rig
```

House style, matching what is already there:

* Tabs for indentation, `snake_case` for functions and variables,
  `PascalCase` for classes.
* Static types wherever they are not noise (`var x := 0.0`).
* Comments in **English**, and only where the *why* is not obvious from the
  code. Docstring (`##`) at the top of every file saying what it is for.
* No new autoloads without a good reason.
* UI strings go through the existing English literals — `Loc.gd` translates
  them by source string, so adding a string means adding a key to the five
  language tables there if you want it translated.

## Adding a language

`scripts/Loc.gd` is **generated** - edit `tools/gen_loc.py` instead. Every
string is one `add()` call with the English source and the five translations,
and the script rewrites `Loc.gd`:

```bash
python3 tools/gen_loc.py
```

It also prints every UI string it found in the scripts that has no entry yet,
so coverage cannot rot quietly. Keys are the English source strings, so Godot
translates any Control automatically and untranslated keys fall back to
English on their own.

To add a language, add it to `LANGS` in the script and give every `add()` call
one more argument.

## Charts

`tools/charting.py` turns a list of musical events into the three difficulties.
It works in phrases - a movement pattern every two bars, seeded per song - so no
two tracks end up with the same shape, and it places holds first because a hold
owns the cursor for its whole length.

Where those events come from is the important part. `tools/beatgrid.py`
measures the tempo and the position of the first beat **from the audio**, and
`tools/rechart.py` puts a note only where there is an attack to hear:

```bash
python3 tools/beatgrid.py --selftest   # prove the detector's own timing first
python3 tools/rechart.py --all --dry   # measure every song, write nothing
python3 tools/rechart.py --all         # rebuild the difficulties
python3 tools/beatgrid.py --check      # fail if a chart drifted off its music
```

Never take the BPM in `map.json` on trust when rebuilding a chart. An earlier
version of the re-charter did exactly that, and for the songs whose declared
tempo was wrong it snapped every note onto a grid the music does not follow -
which the player hears as the hitsound tapping somewhere between the beats,
getting worse the further into the song they get. The tempo is measured now,
and `--check` keeps it that way: every difficulty has to sit within 15 ms of
the attacks in its own audio.

The detector reports onsets about 43 ms before the sound that caused them,
because the analysis window reaches back in time. That constant is measured by
`--selftest` against a click track at known times and taken out of everything
`beatgrid` reports. If you change the window or the hop, run the self-test and
re-measure it, or every chart in the library will look 43 ms out of time.

## Tests

There is a small headless test harness. CI runs the first one on every push.

```bash
# save file round-trip, hold notes, judging, modifiers, conductor offset
godot --headless --path . res://tools/CoreTest.tscn

# import a map from another game and print what came out
godot --headless --path . res://tools/ImportTest.tscn -- /path/to/map.sspm
```

The versus handshake needs two processes:

```bash
OR_NET=host godot --headless --path . res://tools/NetTest.tscn   # one terminal
OR_NET=join godot --headless --path . res://tools/NetTest.tscn   # another
```

Add `OR_NET_BAD=1` to the host to check that a mismatched chart is refused
rather than played.

`CoreTest` exits non-zero when a check fails, and prints one `PASS`/`FAIL`
line per check. Add to `tools/test_core.gd` when you touch saving, judging or
the map format.

Note that the tests write to `user://`, so run them with the same Godot build
you play with or they will land in a different sandbox.

## Before opening a PR

* Run `CoreTest`, then play through the screens you touched.
* Keep `export_presets.cfg` clean: **no keystore paths, no passwords**. CI
  rejects a commit that carries them.
* Do not commit anything under `build/`, `.godot/`, or a song folder with
  third-party audio.

## Reporting bugs

Say which platform and build you were on, what the song folder looked like if
it is a library or import problem, and attach the map when you can.
