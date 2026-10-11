#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f ci/run_checked.sh ]]; then
  echo 'FAIL: checked Godot runner is missing'
  exit 1
fi
bash ci/run_checked.sh bash -c 'printf "ordinary output\n"'
if bash ci/run_checked.sh bash -c 'printf "SCRIPT ERROR: Parse Error: deliberate fixture\n"; exit 0'; then
  echo 'FAIL: script error with zero status was accepted'
  exit 1
fi
if bash ci/run_checked.sh bash -c 'exit 23'; then
  echo 'FAIL: nonzero command status was accepted'
  exit 1
fi
echo 'CI_GUARD_TESTS: 3/3 passed'

