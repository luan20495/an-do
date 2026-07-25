#!/usr/bin/env bash
set -euo pipefail
python3 tool/validate_repo.py
flutter pub get
flutter analyze
flutter test
