#!/usr/bin/env bash
set -euo pipefail

# Move ALL Codex state out of the container's home directory and onto a
# writable host-backed mount. Nothing is filtered: sessions, databases, auth,
# config, logs, caches, skills, plugins, and future Codex files move together.
#
# Usage:
#   export-codex-sessions.sh [--dry-run] [DESTINATION]
#
# DESTINATION is the final directory as seen inside the container. It defaults
# to /home/ubuntu/host/.codex/homestate for a simple writable project mount, or
# to <writable-worktree>/.codex/homestate for the split worktree mount layout.
# Set CODEX_HOMESTATE or pass DESTINATION to override detection.

CONTAINER_CODEX_HOME="${CONTAINER_CODEX_HOME:-/home/ubuntu/.codex}"
HOST_MOUNT_PREFIX="${HOST_MOUNT_PREFIX:-/home/ubuntu/host}"

die() {
  echo "export-codex-sessions.sh: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: export-codex-sessions.sh [--dry-run] [DESTINATION]

Move /home/ubuntu/.codex to a writable host-backed directory. When omitted,
DESTINATION is detected for the standard simple-repository and linked-worktree
container layouts. If detection is ambiguous, an interactive shell prompts.
EOF
}

# Print the deepest mount point and its mount options for a path. The path may
# not exist yet, so walk upward to an existing ancestor before consulting
# mountinfo.
mount_record_for() {
  local target="$1"
  while [ ! -e "$target" ] && [ "$target" != "/" ]; do
    target="$(dirname -- "$target")"
  done

  awk -v target="$target" '
    function covers(mountpoint, path) {
      return mountpoint == "/" || path == mountpoint \
        || index(path, mountpoint "/") == 1
    }
    covers($5, target) && length($5) > length(best) {
      best = $5
      options = $6
    }
    END {
      if (best == "") exit 1
      print best "\t" options
    }
  ' /proc/self/mountinfo
}

# Reject the container's root filesystem even though it is writable: state
# stored there would disappear with the container.
rw_external_mount_for() {
  local record mountpoint options
  record="$(mount_record_for "$1")" || return 1
  mountpoint="${record%%$'\t'*}"
  options="${record#*$'\t'}"
  [ "$mountpoint" != "/" ] || return 1
  case ",$options," in
    *,rw,*) printf '%s\n' "$record" ;;
    *) return 1 ;;
  esac
}

suggest_destination() {
  local default record mountpoint candidate count
  default="$HOST_MOUNT_PREFIX/.codex/homestate"

  # A simple repository maps the whole project here read-write.
  if rw_external_mount_for "$default" >/dev/null; then
    printf '%s\n' "$default"
    return
  fi

  # In the split layout, use the writable worktree mount containing the
  # caller, even if the caller happens to be inside a nested Git repository.
  if record="$(rw_external_mount_for "$PWD" 2>/dev/null)"; then
    mountpoint="${record%%$'\t'*}"
    case "$mountpoint" in
      "$HOST_MOUNT_PREFIX"/worktrees/*)
        printf '%s\n' "$mountpoint/.codex/homestate"
        return
        ;;
    esac
  fi

  # docker exec can start in /home/ubuntu. If exactly one writable worktree is
  # mounted, it is still unambiguous even though PWD is outside that mount.
  candidate=""
  count=0
  while IFS=$'\t' read -r mountpoint options; do
    case "$mountpoint:$options" in
      "$HOST_MOUNT_PREFIX"/worktrees/*:rw,*|"$HOST_MOUNT_PREFIX"/worktrees/*:*,rw,*)
        candidate="$mountpoint/.codex/homestate"
        count=$((count + 1))
        ;;
    esac
  done < <(awk '{ print $5 "\t" $6 }' /proc/self/mountinfo)

  if [ "$count" -eq 1 ]; then
    printf '%s\n' "$candidate"
  fi
  return 0
}

dry_run=false
case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --dry-run)
    dry_run=true
    shift
    ;;
esac
[ "$#" -le 1 ] || { usage >&2; exit 64; }

destination="${1:-${CODEX_HOMESTATE:-}}"
if [ -z "$destination" ]; then
  suggestion="$(suggest_destination)"
  if [ -t 0 ]; then
    if [ -n "$suggestion" ]; then
      printf 'Host-backed Codex destination [%s]: ' "$suggestion" >&2
    else
      printf 'Host-backed Codex destination: ' >&2
    fi
    IFS= read -r destination \
      || die "could not read a destination"
    destination="${destination:-$suggestion}"
  else
    destination="$suggestion"
  fi
fi
[ -n "$destination" ] \
  || die "could not detect a writable mount; pass the destination path explicitly"
case "$destination" in
  /*) ;;
  *) die "destination must be an absolute path inside the container" ;;
esac
destination="$(readlink -m -- "$destination")"
case "$destination" in
  "$CONTAINER_CODEX_HOME"|"$CONTAINER_CODEX_HOME"/*)
    die "destination must not be inside $CONTAINER_CODEX_HOME"
    ;;
esac

mount_record="$(rw_external_mount_for "$destination" 2>/dev/null)" \
  || die "$destination is not on a writable external mount"
destination_mount="${mount_record%%$'\t'*}"

# In a restored container, these can be two paths to the same bind-mounted
# directory. The symlink made by a previous export has the same effect.
if [ -e "$destination" ] \
  && [ "$CONTAINER_CODEX_HOME" -ef "$destination" ]; then
  echo "Codex homestate is already host-backed at $destination"
  exit 0
fi

[ -d "$CONTAINER_CODEX_HOME" ] \
  || die "can't find the Codex state directory $CONTAINER_CODEX_HOME"

if $dry_run; then
  echo "Would move all Codex state:"
  echo "  from  $CONTAINER_CODEX_HOME"
  echo "  to    $destination"
  echo "  mount $destination_mount (read-write)"
  exit 0
fi

# Codex uses SQLite and append-only session files. Moving them while Codex is
# running could capture an inconsistent state, so make the user exit it first.
if pgrep -u "$(id -u)" -x codex >/dev/null 2>&1 \
  || pgrep -u "$(id -u)" -x codex-code-mode >/dev/null 2>&1; then
  die "Codex is still running; exit every Codex process, then run this script again"
fi

destination_parent="$(dirname -- "$destination")"
mkdir -p "$destination_parent" \
  || die "could not create $destination_parent"

if [ -e "$destination" ] || [ -L "$destination" ]; then
  # docker.sh may have prepared an empty mount source before this one-time
  # export. An empty directory is safe to replace; anything else is preserved.
  if [ -d "$destination" ] \
    && [ -z "$(find "$destination" -mindepth 1 -print -quit)" ]; then
    rmdir "$destination"
  else
    die "$destination already exists and is not empty; refusing to overwrite it"
  fi
fi

echo "Moving all Codex state:"
echo "  from $CONTAINER_CODEX_HOME"
echo "  to   $destination"
mv "$CONTAINER_CODEX_HOME" "$destination"

# Keep Codex usable in this container after the export. New containers use the
# launcher's bind mount instead of relying on this symlink.
ln -s "$destination" "$CONTAINER_CODEX_HOME"

echo "Done. The complete Codex home state is now on the host and can be"
echo "restored by bind-mounting it at $CONTAINER_CODEX_HOME in a new container."
