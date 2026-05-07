import math
import os
import struct
import wave


SAMPLE_RATE = 48000


def output_path(name):
  return os.path.join(os.environ["SKG_SOUND_DIR"], f"{name}.wav")


def clamp(value, low=-1.0, high=1.0):
  return max(low, min(high, value))


def smoothstep(x):
  x = clamp(x)
  return x * x * (3.0 - 2.0 * x)


def soft_clip(x, drive=1.35):
  return math.tanh(drive * x) / math.tanh(drive)


def write_wav(path, duration, volume, sample_at):
  os.makedirs(os.path.dirname(path), exist_ok=True)
  total = int(duration * SAMPLE_RATE)

  with wave.open(path, "w") as wav_file:
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(SAMPLE_RATE)

    for n in range(total):
      t = n / SAMPLE_RATE
      sample = clamp(sample_at(n, t) * volume)
      wav_file.writeframes(struct.pack("h", int(sample * 32767)))
