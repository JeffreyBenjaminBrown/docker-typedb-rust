#!/usr/bin/env bash
# Searches your nixpkgs for packages related to the OpenAI Codex CLI and
# (sanity check) Claude Code. Output goes to out/01-codex.log for Claude
# to read.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
LOG="out/01-codex.log"

{
  echo "=== date ==="
  date
  echo

  echo "=== nixpkgs channel ==="
  nix-channel --list 2>&1 || true
  echo

  echo "=== nix-env -qaP | grep -i codex ==="
  nix-env -qaP 2>/dev/null | grep -i codex || echo "(no matches)"
  echo

  echo "=== nix-env -qaP | grep -iE 'claude|anthropic' ==="
  nix-env -qaP 2>/dev/null | grep -iE 'claude|anthropic' || echo "(no matches)"
  echo
} > "$LOG" 2>&1

echo "wrote $LOG"
