#!/usr/bin/env bash
# Builds a debug APK and prints its path.
set -euo pipefail
cd "$(dirname "$0")/.."
./gradlew assembleDebug
find app/build/outputs/apk/debug -name '*.apk'
