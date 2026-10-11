#!/usr/bin/env bash
set -euo pipefail
mcx_godot_bin="${MCX_GODOT_BIN:-godot}"
bash tests/test_ci_guard.sh
bash ci/run_checked.sh "$mcx_godot_bin" --headless --path . --script ci/export_diagnostics.gd
for test_script in tests/test_*.gd; do
  bash ci/run_checked.sh "$mcx_godot_bin" --headless --path . --script "$test_script"
done
