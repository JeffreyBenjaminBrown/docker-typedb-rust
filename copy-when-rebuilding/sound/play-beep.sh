#!/usr/bin/env bash
# Plays a sound by basename, without path or extension.

name="${1:-beep-harsh}"

case "$name" in
  */*|*.wav)
    echo "Usage: $0 [basename-without-extension]" >&2
    exit 64
    ;;
esac

pw-play "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$name.wav" 2>/dev/null
