#!/usr/bin/env bash
# Runs `nix-build docker.nix` and captures output to out/02-build.log.
# First run will almost certainly fail (TypeDB tarball hash placeholder).
# Rerun after each fix.
set -o pipefail
cd "$(dirname "$0")/.."
mkdir -p out
LOG="out/02-build.log"

{
  echo "=== date ==="
  date
  echo
  echo "=== nix-build docker.nix ==="
} > "$LOG"

nix-build docker.nix 2>&1 | tee -a "$LOG"
status=${PIPESTATUS[0]}

{
  echo
  echo "=== exit status: $status ==="
  echo "=== ls -l result ==="
  ls -l result 2>&1 || true
} >> "$LOG"

echo "wrote $LOG  (exit=$status)"
exit "$status"
