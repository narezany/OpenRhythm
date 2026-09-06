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

# The OpenXR loader - the library that finds the runtime on the device - is not
# in the vendor AARs and is not added by the build template either: the template
# names a version for it and then never asks for it. Without it the interface
# loads, xrCreateInstance has nothing to talk to, and the session is never
# created, which is precisely what a headset stuck on its loading screen looks
# like. So the dependency is added here, once, to the gradle build these two
# packages use. The phone package does not go through gradle at all.
GRADLE="android/build/build.gradle"
if [ ! -f "$GRADLE" ]; then
  echo "no Android build template - run Godot with --install-android-build-template first" >&2
  exit 1
fi
if ! grep -q "openxr_loader_for_android" "$GRADLE"; then
  sed -i 's|^\(\s*\)implementation "androidx.documentfile:documentfile:\$versions.documentfileVersion"|&\n\1// added by tools/build_headsets.sh: the runtime loader for OpenXR\n\1implementation "org.khronos.openxr:openxr_loader_for_android:$versions.openxrLoaderVersion"|' "$GRADLE"
  grep -q "openxr_loader_for_android" "$GRADLE" || {
    echo "could not add the OpenXR loader dependency to $GRADLE" >&2
    exit 1
  }
  echo "added the OpenXR loader dependency to the gradle build"
fi

mkdir -p build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Meta Quest" build/OpenRhythm-quest.apk
"$GODOT" --headless --path . --export-release "Pico" build/OpenRhythm-pico.apk
# A second Pico package on the generic Khronos loader, which finds the runtime
# through the broker rather than through PICO's own plugin. Same game either
# way; it is here because only a headset can say which of the two a device
# actually accepts.
"$GODOT" --headless --path . --export-release "Pico (Khronos loader)" \
  build/OpenRhythm-pico-khronos.apk

# And one Pico package with the vendor plugin taken out of the project
# altogether: nothing but the engine's own OpenXR and the Khronos loader. If
# the plugin is what takes the app down before a single line of game code runs,
# this is the one that survives.
if [ -d addons/godotopenxrvendors ]; then
  mv addons/godotopenxrvendors "$PWD/.godotopenxrvendors.aside"
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
  "$GODOT" --headless --path . --export-release "Pico (no vendor plugin)" \
    build/OpenRhythm-pico-plain.apk || true
  mv "$PWD/.godotopenxrvendors.aside" addons/godotopenxrvendors
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi

for f in quest pico pico-khronos pico-plain; do
  apk="build/OpenRhythm-${f}.apk"
  printf '%-34s %s\n' "$apk" "$(unzip -l "$apk" 2>/dev/null | grep -c libopenxr_loader.so) loader"
done
ls -la build/OpenRhythm-*.apk
