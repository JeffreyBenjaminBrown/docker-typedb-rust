#!/usr/bin/env bash
# Starts the rust-typedb container detached. Uses `sleep infinity` as PID 1
# so it stays up without a tty attached. Output goes to out/04-run.log.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
LOG="out/04-run.log"

CONTAINER_NAME=rust-typedb
HOST_PROJECT="$HOME/hodal/docker-typedb-rust"
IMAGE_NAME="jeffreybbrown/hode:latest"

{
  echo "=== date ==="
  date
  echo

  echo "=== HOST_PROJECT=$HOST_PROJECT ==="
  [ -d "$HOST_PROJECT" ] || echo "WARNING: HOST_PROJECT not a dir"
  echo "=== cleaning up any prior container ==="
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm   "$CONTAINER_NAME" 2>/dev/null || true
  echo

  AUDIO_GID=$(getent group audio | cut -d: -f3)
  echo "=== audio gid: $AUDIO_GID ==="
  echo

  echo "=== docker run ==="
  docker run --name "$CONTAINER_NAME" -d \
    -v "$HOST_PROJECT":/home/ubuntu/host \
    -v /nix/store:/nix/store:ro \
    -v /run/user/1000/pipewire-0:/run/user/1000/pipewire-0 \
    -e PIPEWIRE_RUNTIME_DIR=/run/user/1000 \
    --group-add "$AUDIO_GID" \
    --ulimit rtprio=95 \
    --ulimit memlock=-1 \
    --network host \
    --platform linux/amd64 \
    --user 1000:1000 \
    --dns 8.8.8.8 --dns 1.1.1.1 \
    "$IMAGE_NAME" sleep infinity
  echo

  sleep 1
  echo "=== docker ps -a --filter name=$CONTAINER_NAME ==="
  docker ps -a --filter "name=$CONTAINER_NAME" \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}'
  echo

  echo "=== docker logs $CONTAINER_NAME (last 50 lines) ==="
  docker logs --tail 50 "$CONTAINER_NAME" 2>&1 || true
} > "$LOG" 2>&1

status=$?
echo "wrote $LOG  (exit=$status)"
exit "$status"
