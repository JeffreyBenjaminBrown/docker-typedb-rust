#!/usr/bin/env bash
# Runs `--version` / `which` / sanity checks for every major tool the
# image is supposed to contain. Output goes to out/05-smoke.log.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
LOG="out/05-smoke.log"
CONTAINER_NAME=rust-typedb

exec_in() {
  echo "=== \$ $* ==="
  docker exec "$CONTAINER_NAME" bash -lc "$*" 2>&1 || echo "(exit $?)"
  echo
}

{
  echo "=== date ==="
  date
  echo

  echo "=== docker ps (is the container up?) ==="
  docker ps --filter "name=$CONTAINER_NAME" --format 'table {{.Names}}\t{{.Status}}'
  echo

  # identity / fs sanity
  exec_in 'id'
  exec_in 'whoami 2>&1 || true'
  exec_in 'echo "HOME=$HOME  USER=$USER"'
  exec_in 'ls -la /home/ubuntu | head -20'
  exec_in 'cat /etc/passwd'
  exec_in 'ls /etc'

  # shell + core
  exec_in 'bash --version | head -1'
  exec_in 'ls /bin | head -30'

  # version control + search
  exec_in 'git --version'
  exec_in 'rg --version | head -1'

  # rust
  exec_in 'rustc --version 2>&1 || echo rustc-missing'
  exec_in 'cargo --version  2>&1 || echo cargo-missing'
  exec_in 'cargo-watch --version   2>&1 | head -1 || true'
  exec_in 'cargo-nextest --version 2>&1 | head -1 || true'

  # databases
  exec_in 'which typedb; readlink -f "$(which typedb)" 2>&1 || true'
  exec_in 'ls -ld /opt/typedb /opt/typedb/server /opt/typedb/server/data /opt/typedb/core/server /opt/typedb/core/server/data /var/lib/typedb /var/lib/typedb/data 2>&1 || true'
  exec_in 'bash -lc '\''test -w /opt/typedb && test -w /var/lib/typedb/data'\'' && echo typedb-paths-writable || echo typedb-paths-not-writable'
  exec_in 'which typedb; typedb --version 2>&1 | head -3 || echo typedb-exited'

  # ai clis
  exec_in 'which claude; claude --version 2>&1 || echo claude-missing'
  exec_in 'which codex;  codex  --version 2>&1 || echo codex-missing'

  # editor + python + node
  exec_in 'emacs --version | head -1'
  exec_in 'emacs --batch --eval "(progn (require '\''magit) (princ \"magit-ok\n\"))"'
  exec_in 'python3 --version'
  exec_in 'node --version'
  exec_in 'npm --version'

  # audio plumbing
  exec_in 'ls -l /run/user/1000/pipewire-0 2>&1 || echo no-pipewire-socket'
  exec_in 'pw-cli info 0 2>&1 | head -5 || echo pw-cli-missing-or-cant-connect'

  # sound samples
  exec_in 'ls /home/sound/'

  # host bind-mount
  exec_in 'ls /home/ubuntu/host/ | head -10'
} > "$LOG" 2>&1

echo "wrote $LOG"
