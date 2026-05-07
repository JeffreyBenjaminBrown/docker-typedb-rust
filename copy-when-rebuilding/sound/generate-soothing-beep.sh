#!/usr/bin/env bash
# Writes beep-soothing.wav next to this script.
# Soothing hawaiian guitar-like tones:
# soft sinewaves with slight warmth,
# drifting independently between 300-800 Hz.

VOLUME=0.12

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SKG_SOUND_DIR="$script_dir"
export SKG_VOLUME="$VOLUME"

python3 << 'EOF'
import math
import os
import sys

sys.path.insert(0, os.environ["SKG_SOUND_DIR"])
from sound_common import SAMPLE_RATE, output_path, soft_clip, write_wav

duration = 3.0
volume = float(os.environ["SKG_VOLUME"])

voices = [
  {"start_freq": 420, "end_freq": 360, "drift_rate": 0.23},
  {"start_freq": 530, "end_freq": 620, "drift_rate": 0.31},
  {"start_freq": 340, "end_freq": 295, "drift_rate": 0.17},
]

def envelope(t, dur, attack=0.4, release=1.2):
  if t < attack:
    return t / attack
  if t > dur - release:
    return (dur - t) / release
  return 1.0

phases = [0.0 for _ in voices]

def sample_at(n, t):
  progress = n / int(duration * SAMPLE_RATE)
  sample_value = 0.0

  for vi, voice in enumerate(voices):
    drift = (
      voice["start_freq"]
      + (voice["end_freq"] - voice["start_freq"]) * progress )
    wobble = math.sin(2 * math.pi * voice["drift_rate"] * t) * 12
    freq = drift + wobble

    phases[vi] += 2 * math.pi * freq / SAMPLE_RATE
    wave_val = math.sin(phases[vi])
    wave_val += 0.06 * math.sin(2 * phases[vi])
    sample_value += wave_val

  sample_value = sample_value / len(voices)
  sample_value *= envelope(t, duration)
  return soft_clip(sample_value * 1.1, drive=1.0)

path = output_path("beep-soothing")
write_wav(path, duration, volume, sample_at)
print(f"Soothing beep created at {path}")
EOF
