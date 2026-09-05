# Map format

A song is a folder. The game scans for folders containing a `map.json`; the
folder name does not matter, the `id` inside the file does.

```
my_song/
├── map.json        required
├── audio.ogg       .wav, .ogg or .mp3 — the name is set in map.json
├── video.ogv       optional, Theora; played behind the playfield
└── cover.png       optional, written by the .sspm importer
```

A folder can also be shipped as a `.zip` with the same layout at the archive
root — drop it into the library folder and the game unpacks it on the next
scan.

## Where the library lives

| Platform | Folder |
|---|---|
| Linux / Windows / macOS | `user://songs` (`~/.local/share/godot/app_userdata/Open Rhythm/songs` on Linux) |
| Android | `/storage/emulated/0/OpenRhythm/songs` |

The exact path is printed on the **Songs** screen, with a *Copy path* button.

## map.json

```json
{
  "id": "neon_drift",
  "title": "Neon Drift",
  "artist": "Open Rhythm OST",
  "bpm": 120.0,
  "preview_start": 0.0,
  "length": 60.2,
  "audio": "audio.wav",
  "difficulties": [
    { "name": "Normal", "notes": [ ... ] },
    { "name": "Hyper",  "notes": [ ... ] }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | Unique key. Scores, records and replays are stored against it. Defaults to the folder name. |
| `title`, `artist` | Shown on the select screen and in the HUD. |
| `bpm` | Drives the beat grid in the editor and the on-beat effects. Not used for judging. |
| `preview_start` | Second the hover preview starts from. |
| `length` | Song length in seconds; used for the progress bar before the audio loads. |
| `audio` | File name inside the folder. Empty means "no audio yet". |
| `difficulties` | Ordered list. Each has a `name` and a `notes` array. |

## Notes

```json
{ "t": 12.5, "cell": 4, "s": 1.0, "h": 0.5, "c": true }
```

| Field | Default | Meaning |
|---|---|---|
| `t` | — | Time in seconds when the cube lands. |
| `cell` | — | Grid cell, `0..8`, left to right then top to bottom. `0` is top-left, `4` is the centre, `8` is bottom-right. |
| `s` | `1.0` | Size multiplier of the cube, `0.4..`. Bigger cubes are easier. |
| `h` | `0` | Hold length in seconds. `0` (or absent) is a normal note. |
| `c` | `false` | Marks a click note. Off unless the player turns CLICKS on. |

### Hold notes

A note with `h > 0` is a **hold**: the cube lands as usual, and then the cursor
has to stay inside its cell for `h` seconds. The rank comes from the landing
position, and is dropped a step if a good chunk of the hold was lost. Score is
scaled up with the hold length.

In the editor, drag the right edge of a note in the timeline to give it a
length, or select notes and press **H** to toggle a one-beat hold.

**Do not let anything else fly while a hold runs.** There is one cursor: a note
arriving during a hold is a note the player cannot take. The bundled charts
leave the whole hold window empty, and the editor's auto-generator does the
same.

### Click notes

A note with `"c": true` is *marked* as a click note, but it plays as a normal
cube unless the player switches them on. Clicking is not for everyone, so a
chart never forces it and never costs anything for leaving it off - a run
without clicks scores the usual 100%.

Two modifiers control them:

* **CLICKS** (+15%) turns the chart's own click notes on. It only appears in
  the modifier list when the chosen difficulty actually has some.
* **CLICKY** (+40%) turns *every* note into a click note, on any chart.

An active click note has to be pressed - mouse button, tap or the gamepad
button - while the cursor is on it. Covering it is not enough, and the catch
window ends in a miss if no press arrives. They are drawn as ember cubes inside
a target ring.

### Legacy fields

Older maps used an `a` field (an angle in degrees) instead of `cell`. It still
loads — the angle is snapped to the nearest cell. New maps should write `cell`.

## Rebuilding a chart

`tools/rechart.py` rebuilds the difficulties of any song from the note times
already in its `map.json`. Those times came from the audio, so they are worth
keeping; what gets rebuilt is the placement, the difficulty spread and the
holds.

```bash
python3 tools/rechart.py songs/my_song
python3 tools/rechart.py --all      # everything except the OST and the tutorial
```

It snaps the notes to the beat grid first, working out the grid phase from the
notes themselves so a track whose first beat is not at zero does not get
dragged onto the wrong beat.

## Importing from other games

The **Songs** screen imports:

* `.sspm` — Sound Space Plus / Rhythia maps, both v1 and v2. Audio and cover
  art are embedded in the file, so an imported song is playable straight away.
  BPM is not part of the format and is estimated from the note spacing; adjust
  it in the editor if the beat grid looks wrong.
* `.txt` — the classic Sound Space map string, `audioId,x|y|ms,x|y|ms,…`.
  There is no audio in it, so drop an audio file into the created folder
  afterwards and attach it in the editor.

Sound Space coordinates run x to the right and y downwards with `(0,0)` at the
top-left, which is the same convention as `cell`, so grids map across without
mirroring. Quantum (off-grid) positions are snapped to the nearest cell.
