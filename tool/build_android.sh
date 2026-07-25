#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f android/gradle/wrapper/gradle-wrapper.jar ]]; then
  ./tool/repair_platform_scaffold.sh
fi
flutter pub get
flutter analyze
flutter test
flutter build apk --flavor dev --debug --dart-define=FIREBASE_ENABLED=false
