#!/usr/bin/env bash
# After a successful nix-build, load the image archive into Docker.
# Output goes to out/03-load.log.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
LOG="out/03-load.log"

{
  echo "=== date ==="
  date
  echo

  if [ ! -e result ]; then
    echo "ERROR: ./result does not exist. Run ./scripts/02-build.sh first."
    exit 1
  fi

  echo "=== docker load < result ==="
  docker load < result
  echo

  echo "=== docker images | grep -E 'REPOSITORY|hode' ==="
  docker images | grep -E 'REPOSITORY|hode' || true
} > "$LOG" 2>&1

status=$?
echo "wrote $LOG  (exit=$status)"
exit "$status"
