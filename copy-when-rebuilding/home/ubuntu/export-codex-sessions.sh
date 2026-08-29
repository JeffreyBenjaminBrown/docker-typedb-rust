#!/usr/bin/env bash
set -euo pipefail

# Move ALL Codex state out of the container's home directory and onto the
# host-backed project mount. Codex normally saves this state at
# /home/ubuntu/.codex; "homestate" means the Codex state that was saved under
# the container user's home directory (/home/ubuntu/).
#
# Keeping the complete directory at /home/ubuntu/host/.codex/homestate makes
# it survive removal of this container, so bash/docker.sh can mount it back at
# /home/ubuntu/.codex when starting a container from a new Docker image.
# Nothing is filtered: sessions, databases, auth, config, logs, caches, skills,
# plugins, and any future Codex files all move together.

CONTAINER_CODEX_HOME="/home/ubuntu/.codex"
HOST_MOUNT="/home/ubuntu/host"
HOST_CODEX_DIR="$HOST_MOUNT/.codex"
CODEX_HOMESTATE="$HOST_CODEX_DIR/homestate"

die() {
  echo "export-codex-sessions.sh: $*" >&2
  exit 1
}

# In a container created by the updated docker.sh, these are two paths to the
# same bind-mounted directory. In the old container, the symlink made below
# also makes them the same. Either case means the export is already complete.
if [ -e "$CODEX_HOMESTATE" ] \
  && [ "$CONTAINER_CODEX_HOME" -ef "$CODEX_HOMESTATE" ]; then
  echo "Codex homestate is already host-backed at $CODEX_HOMESTATE"
  exit 0
fi

[ -d "$CONTAINER_CODEX_HOME" ] \
  || die "can't find the Codex state directory $CONTAINER_CODEX_HOME"
[ -d "$HOST_MOUNT" ] \
  || die "can't find the host-backed project directory $HOST_MOUNT"

# Refuse to put the only copy back onto the container filesystem if this
# script is accidentally run somewhere other than the intended container.
awk '$5 == "/home/ubuntu/host" { found = 1 }
     END { exit(found ? 0 : 1) }' /proc/self/mountinfo \
  || die "$HOST_MOUNT is not a mount point; refusing to move Codex state"

# Codex uses SQLite and append-only session files. Moving them while Codex is
# running could capture an inconsistent state, so make the user exit it first.
if pgrep -u "$(id -u)" -x codex >/dev/null 2>&1 \
  || pgrep -u "$(id -u)" -x codex-code-mode >/dev/null 2>&1; then
  die "Codex is still running; exit every Codex process, then run this script again"
fi

mkdir -p "$HOST_CODEX_DIR"

if [ -e "$CODEX_HOMESTATE" ] || [ -L "$CODEX_HOMESTATE" ]; then
  # docker.sh may have prepared an empty mount source before this one-time
  # export. An empty directory is safe to replace; anything else is preserved.
  if [ -d "$CODEX_HOMESTATE" ] \
    && [ -z "$(find "$CODEX_HOMESTATE" -mindepth 1 -print -quit)" ]; then
    rmdir "$CODEX_HOMESTATE"
  else
    die "$CODEX_HOMESTATE already exists and is not empty; refusing to overwrite it"
  fi
fi

echo "Moving all Codex state:"
echo "  from $CONTAINER_CODEX_HOME"
echo "  to   $CODEX_HOMESTATE"
mv "$CONTAINER_CODEX_HOME" "$CODEX_HOMESTATE"

# Keep Codex usable in this container after the export. New containers use the
# bind mount in bash/docker.sh instead of relying on this symlink.
ln -s "$CODEX_HOMESTATE" "$CONTAINER_CODEX_HOME"

echo "Done. The complete Codex home state is now on the host and can be"
echo "restored in a container created from a new Docker image."
