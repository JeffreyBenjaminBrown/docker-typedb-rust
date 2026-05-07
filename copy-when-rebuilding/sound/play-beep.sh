#!/usr/bin/env bash
# Plays the image-built default beep unless a path is supplied.

pw-play "${1:-/home/sound/beep.wav}" 2>/dev/null
