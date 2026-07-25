#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
flutter create --platforms=android --org com.hoangluan --project-name an_do "$TMP/base"
# Keep authored application files. Copy only wrapper and launcher binaries if absent.
cp -n "$TMP/base/android/gradlew" "$ROOT/android/gradlew" || true
cp -n "$TMP/base/android/gradlew.bat" "$ROOT/android/gradlew.bat" || true
mkdir -p "$ROOT/android/gradle/wrapper"
cp -n "$TMP/base/android/gradle/wrapper/gradle-wrapper.jar" "$ROOT/android/gradle/wrapper/gradle-wrapper.jar" || true
cp -n "$TMP/base/android/gradle/wrapper/gradle-wrapper.properties" "$ROOT/android/gradle/wrapper/gradle-wrapper.properties" || true
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  mkdir -p "$ROOT/android/app/src/main/res/mipmap-$d"
  cp -n "$TMP/base/android/app/src/main/res/mipmap-$d/ic_launcher.png" "$ROOT/android/app/src/main/res/mipmap-$d/ic_launcher.png" || true
done
rm -rf "$TMP"
echo "Platform wrapper and launcher scaffolding repaired."
