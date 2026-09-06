# VR: where it got to

Desktop VR works and has been played. The headset half has not, and this is the
note that stops the next attempt from re-walking ground already covered.

## What works

- **Desktop, for real.** Played through WiVRn on a Radeon RX 580: the room, the
  screen, the cubes, the pointer and the sticks. One build covers flat and VR -
  `Boot` looks for an OpenXR runtime at startup and opens whichever way it
  finds it. With no runtime the engine says "OpenXR was requested but failed to
  start" and the game opens in a window.

### The renderer, which is the whole story

**Desktop VR needs Vulkan. On the Compatibility renderer the headset shows
black while head tracking works perfectly.**

The game ships on Compatibility because that is what phones want. That renderer
draws both eyes in one pass through `GL_OVR_multiview2` - and Mesa offers that
extension to GLES contexts only, while Godot on Linux draws through desktop GL.
The engine asks for multiview anyway (it takes the entry point through EGL,
which Mesa hands out regardless), so every 3D shader in the game is compiled
with `USE_MULTIVIEW` and every one of them fails:

    error: `gl_ViewID_OVR' undeclared

Nothing else fails. OpenXR connects, the session runs, the head pose is right,
frames go out - `[OR] rendering: 120 frames out, head at (0.958, 1.098, 0.165)`
- and the headset shows an empty room, because there is not a single 3D shader
left to draw it with. It reads exactly like a broken stream and is not one.

`glxinfo | grep OVR` prints nothing on this machine; `eglinfo | grep OVR` prints
both multiview extensions. That one-line difference is the entire bug.

It cannot be fixed with a project setting - the renderer is chosen before the
engine knows a headset is there - so `Boot._restart_on_vulkan()` starts the game
again with `--rendering-method forward_plus` when an OpenXR runtime is installed
and we are on Compatibility, then steps aside. The child is given 1.2 s to prove
it is alive first: a machine with no working Vulkan must end up with a flat
game, not with no game at all. Every way out of that function says in the log
which one it took.
- **The room itself.** `OR_VR=preview`, or *Settings → VR → Look at the VR room
  on this screen*, draws the whole thing on a monitor with the mouse for a
  hand: the game's screen hanging in front of the camera, the floor, the 3x3
  grid, the notes. Whatever is wrong on a headset, it is not the scene.
- **Standing where you want to.** Left stick walks, right stick turns about
  your own head, grip plus B recentres and undoes both. The room is built
  under the player's measured eye height rather than at a height in metres -
  sampled once when tracking settles and again on a recentre, never followed
  frame by frame, because a screen that drifts with your head is the quickest
  way to make someone ill.
- **The packages build.** Quest and Pico export through gradle with the OpenXR
  loader in them and the right manifest for each store.

## How it plays

Sabers are the default. There is no grid in saber play - the cube is the target
and you cut it where it is, with any part of the blade from any direction. The
rank comes from timing rather than from where in a cell the cursor was, because
there is no cell to be off-centre in when you meet a cube in the air, and the
error is reported in milliseconds. A cut settles the note there and then: it
used to be left to land under a cursor that had already swung on to the next
cube, which read as a miss unless you parked the blade in the cube.

Long notes do not exist in saber play. `GameScreen._saber_chart()` opens each
hold out into a run of ordinary cubes in the same cell, so clearing it means
swinging at one spot. That changes the note count and what a full score is
worth, which is the point rather than a side effect.

Ringed cubes cannot be cut. Holding the trigger makes the blade live: a live
blade passes through plain cubes and burns ringed ones. The tutorial has a
second script - `hints_saber` in `songs/tutorial/map.json` - that teaches this,
translated like every other string.

Melly stands in the room. They can be patted (a hand moving across their head,
or a cursor on a flat screen) and picked up with the grip, and while held
the rig goes `limp`: the same springs that animate them, set slack with nothing
driving them, kicked by how hard the hand moves. There is no ragdoll in the
model - it has a skeleton and no physical bones - and this is the honest way to
get a doll out of what is already there. Let go and they fall to the floor.

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
