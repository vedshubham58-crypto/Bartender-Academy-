#!/usr/bin/env bash
# Usage: crash_check.sh <dir with test.apk and store-universal.apk>
# Opens each build on the running emulator and prints crashes from logcat.
set -u
PKG=com.vedshubham.bartenderacademy
for build in test.apk store-universal.apk; do
  echo "================ $build ================"
  adb uninstall "$PKG" >/dev/null 2>&1
  adb install -r "$1/$build" || { echo "INSTALL FAILED"; continue; }
  adb logcat -c
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
  sleep 40
  if adb shell pidof "$PKG" >/dev/null; then echo "RESULT: $build still running after 40 s"; else echo "RESULT: $build NOT running (crashed or closed)"; fi
  echo "---- crash buffer ----"
  adb logcat -d -b crash | tail -n 120
  echo "---- errors (godot, runtime, native) ----"
  adb logcat -d '*:E' | grep -iE "godot|AndroidRuntime|DEBUG|FATAL|libc|bartender|neonads|Ads" | tail -n 150
done
