#!/usr/bin/env bash
# Writes beep-harsh.wav next to this script.

VOLUME=16

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SKG_SOUND_DIR="$script_dir"
export SKG_VOLUME="$VOLUME"

python3 << 'EOF'
import math
import os
import sys

sys.path.insert(0, os.environ["SKG_SOUND_DIR"])
from sound_common import SAMPLE_RATE, output_path, write_wav

duration = 0.2
base_frequency = 800
volume = float(os.environ["SKG_VOLUME"])

intervals = [-24, -12, -5,
              0, 3.86, 7.02, 10.88,
              14.04, 17.51, 20.41,
              22.88, 26.97 ]
intervals = (            intervals
  + [i + 25.105 for i in intervals]
  + [i + 15.86  for i in intervals]
  + [i + 9.69   for i in intervals] )

pitch_shift_start = 0
pitch_shift_end = 1/2

def sample_at(n, _t):
  sample_value = 0.0
  progress = n / int(duration * SAMPLE_RATE)
  current_pitch_shift = (
    pitch_shift_start
    + (pitch_shift_end - pitch_shift_start) * progress )

  for interval in intervals:
    total_interval = interval + current_pitch_shift
    frequency = base_frequency * (2 ** (total_interval / 12))
    volume_scale = base_frequency / frequency
    sample_value += (
      volume_scale
      * math.sin(2 * math.pi * frequency * n / SAMPLE_RATE) )

  return sample_value / len(intervals)

path = output_path("beep-harsh")
write_wav(path, duration, volume, sample_at)
print(f"Harsh beep created at {path}")
EOF
