#!/usr/bin/env bash
# Build the Quest and Pico packages.
#
# They are the same game as the phone package with one difference: the
# renderer. OpenXR on Android binds to the graphics API when it creates its
# session, and it wants Vulkan; on the OpenGL ES binding the interface loads,
# the session never starts, and the headset shows its own loading screen
# forever while the game runs behind it.
#
# That cannot be expressed as a per-export setting. The engine chooses the
# renderer before it knows which custom features an export declares, so a
# feature-tagged override for a headset is never read. So the setting is
# flipped for the length of these two builds and put back afterwards - on the
# way out too, whatever happens.
#
#   tools/build_headsets.sh [godot-command]
#
# Signing works the same as every other Android build: pass the keystore
# through GODOT_ANDROID_KEYSTORE_RELEASE_* in the environment.
set -euo pipefail

GODOT="${1:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SETTING='renderer/rendering_method.mobile'
BACKUP="$(mktemp)"
cp project.godot "$BACKUP"
restore() {
  cp "$BACKUP" project.godot
  rm -f "$BACKUP"
  echo "project.godot restored to the Compatibility renderer"
}
trap restore EXIT

sed -i "s|^${SETTING}=\"gl_compatibility\"|${SETTING}=\"mobile\"|" project.godot
grep -q "^${SETTING}=\"mobile\"" project.godot || {
  echo "could not switch the renderer - has ${SETTING} moved?" >&2
  exit 1
}
echo "building the headset packages on the Mobile (Vulkan) renderer"

mkdir -p build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Meta Quest" build/OpenRhythm-quest.apk
"$GODOT" --headless --path . --export-release "Pico" build/OpenRhythm-pico.apk

ls -la build/OpenRhythm-quest.apk build/OpenRhythm-pico.apk
