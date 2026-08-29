#!/usr/bin/env bash
# Play a completion sound for the main agent, but stay silent for subagents.

payload="$(cat)"
if printf '%s' "$payload" | grep -q '"agent_id"'; then
  exit 0
fi

name="${1:-beep-soothing}"
case "$name" in
  */*|*.wav)
    echo "Usage: $0 [basename-without-extension]" >&2
    exit 64
    ;;
esac

export XDG_RUNTIME_DIR=/run/user/1000
export PIPEWIRE_RUNTIME_DIR=/run/user/1000

# `setsid -f` lets the sound outlive the hook process. These candidates are a
# defensive fallback for Nix/NixOS environments where setsid exists but its
# system profile is not on PATH; a purpose-built image could instead include
# util-linux on PATH and call setsid directly.
# TODO : The latter (include util-linux on PATH)would be more elegant.
setsid_bin="$(command -v setsid 2>/dev/null || true)"
if [ -z "$setsid_bin" ]; then
  for candidate in /run/current-system/sw/bin/setsid /nix/store/*-system-path/bin/setsid; do
    if [ -x "$candidate" ]; then
      setsid_bin="$candidate"
      break
    fi
  done
fi

if [ -n "$setsid_bin" ]; then
  "$setsid_bin" -f timeout -s KILL 5 \
    pw-play "/home/sound/${name}.wav" >/dev/null 2>&1
else
  timeout -s KILL 5 pw-play "/home/sound/${name}.wav" >/dev/null 2>&1 &
  disown
fi

exit 0
