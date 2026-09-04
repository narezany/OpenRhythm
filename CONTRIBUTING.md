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

`scripts/Loc.gd` holds one dictionary per language, keyed by the English
string. Add your language to `LANGS`, add a table, register it in `_ready()`.
Untranslated keys fall back to English on their own.

## Tests

There is a small headless test harness. CI runs the first one on every push.

```bash
# save file round-trip, hold notes, judging, modifiers, conductor offset
godot --headless --path . res://tools/CoreTest.tscn

# import a map from another game and print what came out
godot --headless --path . res://tools/ImportTest.tscn -- /path/to/map.sspm
```

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
