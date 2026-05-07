#!/usr/bin/env bash
# Writes a file to the first argument, or /tmp/glorious-beep.wav by default.
# A three-second V7-I organ cadence in C.
# The top voice moves from scale degree 4 (F) to scale degree 3 (E).

output_path="${1:-/tmp/glorious-beep.wav}"
export SKG_BEEP_OUTPUT="$output_path"

python3 << 'EOF'
import math
import os
import struct
import wave

output_path = os.environ["SKG_BEEP_OUTPUT"]
output_dir = os.path.dirname(output_path)
if output_dir:
  os.makedirs(output_dir, exist_ok=True)

sample_rate = 48000
duration = 3.0
amplitude = 0.22

# Frequencies are in Hz. The top voice is F4 -> E4.
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

def smoothstep(x):
  x = max(0.0, min(1.0, x))
  return x * x * (3.0 - 2.0 * x)

def envelope(t):
  attack = 0.08
  release_start = 2.55
  if t < attack:
    return smoothstep(t / attack)
  if t > release_start:
    return 1.0 - smoothstep((t - release_start) / (duration - release_start))
  return 1.0

def chord_weights(t):
  # Hold V7, then bloom into I with a brief overlap instead of a hard cut.
  if t < 1.18:
    return 1.0, 0.0
  if t > 1.58:
    return 0.0, 1.0
  x = smoothstep((t - 1.18) / 0.40)
  return 1.0 - x, x

def organ_tone(freq, t):
  # Add drawbar-like upper harmonics. Keep them phase-locked for pipe-organ clarity.
  return (
    math.sin(2 * math.pi * freq * t)
    + 0.42 * math.sin(2 * math.pi * freq * 2 * t)
    + 0.24 * math.sin(2 * math.pi * freq * 3 * t)
    + 0.11 * math.sin(2 * math.pi * freq * 4 * t)
    + 0.06 * math.sin(2 * math.pi * freq * 5 * t)
  )

def soft_clip(x):
  return math.tanh(1.35 * x) / math.tanh(1.35)

with wave.open(output_path, "w") as wav_file:
  wav_file.setnchannels(1)
  wav_file.setsampwidth(2)
  wav_file.setframerate(sample_rate)

  total = int(duration * sample_rate)
  for n in range(total):
    t = n / sample_rate
    v_weight, i_weight = chord_weights(t)
    sample = 0.0

    for freq, gain in v7:
      # Slow tremulant for a living organ sound.
      trem = 1.0 + 0.035 * math.sin(2 * math.pi * 5.2 * t + freq * 0.01)
      sample += v_weight * gain * trem * organ_tone(freq, t)

    for freq, gain in i_chord:
      trem = 1.0 + 0.030 * math.sin(2 * math.pi * 4.8 * t + freq * 0.008)
      sample += i_weight * gain * trem * organ_tone(freq, t)

    # A small low tonic pedal arrives with the resolution.
    sample += i_weight * 0.20 * organ_tone(32.70, t)
    sample *= envelope(t) / 2.8
    sample = soft_clip(sample)

    value = int(max(-1.0, min(1.0, sample * amplitude)) * 32767)
    wav_file.writeframes(struct.pack("h", value))

print(f"Glorious beep created at {output_path}")
EOF
