#!/usr/bin/env bash
# Godot's editor import can return zero even when a GDScript fails to parse.
set -euo pipefail
mcx_log_file=$(mktemp)
trap 'rm -f "$mcx_log_file"' EXIT
mcx_status=0
"$@" 2>&1 | tee "$mcx_log_file" || mcx_status=$?
if [[ "$mcx_status" -ne 0 ]]; then
  exit "$mcx_status"
fi
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed to load script' "$mcx_log_file"; then
  echo '::error::Godot reported a script error; refusing to accept this build.'
  exit 1
fi
