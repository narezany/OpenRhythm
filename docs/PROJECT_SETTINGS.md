# Project settings worth explaining

**Do not put comments in `project.godot`.** A `#` line inside a section is
folded into the name of the key that follows it, so `xr/openxr/enabled` was
exported as `xr/#Oneverywhere...openxr/enabled` and the engine never saw the
setting at all. Nothing warns you: the key is simply absent, the default
applies, and the failure surfaces somewhere else entirely. That one habit cost
days here — it turned off VR, turned off the engine's log file, and turned the
Android back button back into "quit the app", each of which looked like an
unrelated bug. Explanations go in this file instead, and
`tools/CoreTest.tscn` checks that the settings below are actually in force.

### `application/config/quit_on_go_back=false`

The Android back button is handled by `Main`, which turns it into Esc: pause,
close a panel, step back a screen. Left at its default the engine closes the
game before any of that runs.

### `debug/file_logging/enable_file_logging=true`

Keeps the engine's own log on disk. On a headset there is no console to read
and often no cable that works, and the reason OpenXR refuses is written by the
engine rather than by the game. `G.dump_logcat()` covers the same ground on
Android by reading the app's own system log.

### `xr/openxr/enabled=true`

One desktop build covers flat and VR: it looks for a runtime at startup, finds
one when SteamVR is up and nothing when it is not. The phone package is
exported with XR mode off, so it has no OpenXR to try in the first place.

### `xr/openxr/startup_alert=false`

Most players are on a flat screen, and a runtime that is simply not running is
not worth an alert box. `Boot` falls back to a window on its own.

### `rendering/renderer/rendering_method.mobile="gl_compatibility"`

The phone package runs on Compatibility. The headset packages need Vulkan -
OpenXR on Android binds to the graphics API when it creates its session - and
that cannot be expressed here: the engine picks a renderer before it knows
which custom features an export declares, so a feature-tagged override is never
read. `tools/build_headsets.sh` flips this line for the length of those two
builds and puts it back afterwards.
