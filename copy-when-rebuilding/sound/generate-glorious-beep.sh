#!/usr/bin/env bash
# Writes beep-glorious.wav next to this script.
# A three-second V7-I organ cadence in C.
# The top voice moves from scale degree 4 (F) to scale degree 3 (E).

VOLUME=0.22

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SKG_SOUND_DIR="$script_dir"
export SKG_VOLUME="$VOLUME"

python3 << 'EOF'
import math
import os
import sys

sys.path.insert(0, os.environ["SKG_SOUND_DIR"])
from sound_common import output_path, smoothstep, soft_clip, write_wav

duration = 3.0
volume = float(os.environ["SKG_VOLUME"])

v7 = [
  (98.00, 0.58),   # G2
  (123.47, 0.48),  # B2
  (146.83, 0.46),  # D3
  (174.61, 0.42),  # F3
  (349.23, 0.34),  # F4, top voice
]
i_chord = [
  (65.41, 0.56),   # C2
  (98.00, 0.42),   # G2
  (130.81, 0.50),  # C3
  (196.00, 0.38),  # G3
  (329.63, 0.36),  # E4, top voice
]

def envelope(t):
  attack = 0.08
  release_start = 2.55
  if t < attack:
    return smoothstep(t / attack)
  if t > release_start:
    return 1.0 - smoothstep((t - release_start) / (duration - release_start))
  return 1.0

def chord_weights(t):
  if t < 1.18:
    return 1.0, 0.0
  if t > 1.58:
    return 0.0, 1.0
  x = smoothstep((t - 1.18) / 0.40)
  return 1.0 - x, x

def organ_tone(freq, t):
  return (
    math.sin(2 * math.pi * freq * t)
    + 0.42 * math.sin(2 * math.pi * freq * 2 * t)
    + 0.24 * math.sin(2 * math.pi * freq * 3 * t)
    + 0.11 * math.sin(2 * math.pi * freq * 4 * t)
    + 0.06 * math.sin(2 * math.pi * freq * 5 * t)
  )

def sample_at(_n, t):
  v_weight, i_weight = chord_weights(t)
  sample = 0.0

  for freq, gain in v7:
    trem = 1.0 + 0.035 * math.sin(2 * math.pi * 5.2 * t + freq * 0.01)
    sample += v_weight * gain * trem * organ_tone(freq, t)

  for freq, gain in i_chord:
    trem = 1.0 + 0.030 * math.sin(2 * math.pi * 4.8 * t + freq * 0.008)
    sample += i_weight * gain * trem * organ_tone(freq, t)

  sample += i_weight * 0.20 * organ_tone(32.70, t)
  sample *= envelope(t) / 2.8
  return soft_clip(sample)

path = output_path("beep-glorious")
write_wav(path, duration, volume, sample_at)
print(f"Glorious beep created at {path}")
EOF
