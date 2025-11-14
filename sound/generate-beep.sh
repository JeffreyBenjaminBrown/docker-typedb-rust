# Writes a file to /tmp/beep.wav.

python3 << 'EOF'
import wave
import math
import struct

duration = 0.2  # seconds
base_frequency = 800  # Hz
sample_rate = 48000
amplitude = 16

# Just intonation intervals in semitones
intervals = [-24, -12, -5,
              0, 3.86, 7.02, 10.88,
              12, 14.04, 17.51, 20.41,
              22.88, 24, 26.04, 26.97 ]
intervals = (            intervals
  + [i + 25.105 for i in intervals]
  + [i + 15.86  for i in intervals]
  + [i + 9.69   for i in intervals] )

# Pitch shift parameters
pitch_shift_start = 0
pitch_shift_end = 1/2

def triangle_wave(frequency, t, sample_rate):
  """UNUSED for now. Generates a triangle wave value at time t."""
  period = sample_rate / frequency
  phase = (t % period) / period
  if phase < 0.5:
    return 4 * phase - 1
  else:
    return 3 - 4 * phase

with wave.open('/tmp/beep.wav', 'w') as wav_file:
  wav_file.setnchannels(1)
  wav_file.setsampwidth(2)
  wav_file.setframerate(sample_rate)

  num_samples = int(duration * sample_rate)

  for i in range(num_samples):
    sample_value = 0

    # Calculate current pitch shift based on position in the sound
    progress = i / num_samples  # 0 to 1
    current_pitch_shift = pitch_shift_start + (pitch_shift_end - pitch_shift_start) * progress

    # Add each note in the chord
    for interval in intervals:
      total_interval = interval + current_pitch_shift
      frequency = base_frequency * (2 ** (total_interval / 12))

      # Volume scales inversely with frequency: doubling frequency halves volume
      frequency_ratio = frequency / base_frequency
      volume_scale = 1.0 / frequency_ratio

      sample_value += volume_scale * math.sin(2 * math.pi * frequency * i / sample_rate)

    # Average the waves and scale to 16-bit range
    sample_value = sample_value / len(intervals)
    value = int(amplitude * 32767 * sample_value)

    # Clamp to prevent clipping
    value = max(-32767, min(32767, value))

    wav_file.writeframes(struct.pack('h', value))

print("Chord beep file created at /tmp/beep.wav")
EOF
