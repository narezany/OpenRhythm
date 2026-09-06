# VR: where it got to

The desktop half is done. The headset half is not, and this is the note that
stops the next attempt from re-walking ground already covered.

## What works

- **Desktop.** One build covers flat and VR: `Boot` looks for an OpenXR runtime
  at startup and opens in whichever way it finds it. With no runtime the engine
  says "OpenXR was requested but failed to start" and the game opens in a
  window - confirmed in an exported build. With SteamVR running it should take
  the headset; that path has never been run against a real runtime, so it is
  untested rather than known-good.
- **The room itself.** `OR_VR=preview`, or *Settings → VR → Look at the VR room
  on this screen*, draws the whole thing on a monitor with the mouse for a
  hand: the game's screen hanging in front of the camera, the floor, the 3x3
  grid, the notes. 120 frames and no errors. Whatever is wrong on a headset, it
  is not the scene.
- **The packages build.** Quest and Pico export through gradle with the OpenXR
  loader in them and the right manifest for each store.

## What does not

On a **Pico 4 (Android 10, PICO OS)** the headset package crashes about half a
second in, before a single line of game code runs - `last_run.log` gets nothing
new however many times it is restarted, and the game's own step probe never
gets to run either. The crash is inside the engine's OpenXR startup.

## Ruled out, with the evidence

| Suspected | How it was checked | Verdict |
|---|---|---|
| No OpenXR loader in the package | `libopenxr_loader.so` present in the APK | not it |
| Manifest / Android 11 package visibility | runtime broker `<queries>`, OpenXR permissions, `android.hardware.vr.headtracking`, `pvr.app.type=vr` all present | not it |
| Wrong renderer | device log: `Vulkan 1.1.128 - Forward Mobile` | not it |
| Settings not reaching the engine | unpacked `project.binary`; comments in `project.godot` had been folded into the key names. Fixed, and CoreTest now guards it | **was a real bug** |
| The OpenXR vendors plugin | package built with the plugin removed from the project entirely | still crashes |
| Godot version | whole game rebuilt on Godot 4.6.3 (109 tests, 0 failures) and packaged | still crashes |
| Our VR scene | rendered on the desktop with no OpenXR at all | not it |

An older OpenXR loader was considered and dropped: the version cannot be forced
from our side, another dependency pins it and wins (1.1.54 landed in the
package when 1.0.34 was asked for).

## What it needs next

A device log. Everything else is closed, and the answer is one `adb logcat`
away - the crash is native and happens before anything that can write a log
itself. That needs a USB-C **data** cable, which is what stalled this: the
headset's own cable is charge-only (enumerates at full speed), a Link cable
fails to enumerate on three different ports and two controllers with
`error -71`, and no other USB-C cable was to hand. Wireless debugging is not an
option either - the Pico 4 runs Android 10, and pairing codes arrived in
Android 11.

With that log this is one change, not another round of guesses.
