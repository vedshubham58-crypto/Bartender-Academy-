#!/usr/bin/env bash
# Usage: crash_check.sh <dir> [apk names...]  (default: test.apk store-universal.apk)
# Opens each build on the running emulator and prints crashes from logcat.
set -u
PKG=com.vedshubham.bartenderacademy
DIR=$1; shift
BUILDS=("$@"); [ ${#BUILDS[@]} -eq 0 ] && BUILDS=(test.apk store-universal.apk)
for build in "${BUILDS[@]}"; do
  echo "================ $build ================"
  adb uninstall "$PKG" >/dev/null 2>&1
  adb install -r "$DIR/$build" || { echo "INSTALL FAILED"; continue; }
  adb logcat -c
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
  sleep 40
  if adb shell pidof "$PKG" >/dev/null; then echo "RESULT: $build still running after 40 s"; else echo "RESULT: $build NOT running (crashed or closed)"; fi
  echo "---- crash buffer ----"
  adb logcat -d -b crash | tail -n 120
  echo "---- errors (godot, runtime, native) ----"
  adb logcat -d '*:E' | grep -iE "godot|AndroidRuntime|DEBUG|FATAL|libc|bartender|neonads|Ads" | uniq | tail -n 150
  echo "---- what happened to the process ----"
  adb logcat -d | grep -E "$PKG|AndroidRuntime|lowmemorykiller|libprocessgroup" | grep -v "shader_gles3\|GL_MAX_FRAGMENT" | uniq | tail -n 60
  echo "---- godot log (all levels) ----"
  adb logcat -d -s godot:V | grep -v "shader_gles3\|Program linking\|GL_MAX_FRAGMENT\|godot   : $\|godot   : 1: $\|Method/function failed" | uniq | tail -n 80
done
