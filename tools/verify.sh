#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p artifacts
touch artifacts/.gdignore
"$GODOT" --headless --editor --path . --quit 2>&1 | tee artifacts/import.log
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' artifacts/import.log; then exit 1; fi
"$GODOT" --headless --path . --audio-driver Dummy -- --self-test 2>&1 | tee artifacts/tests.log
if grep -Eq 'SCRIPT ERROR|Parse Error|TEST FAIL' artifacts/tests.log; then exit 1; fi
