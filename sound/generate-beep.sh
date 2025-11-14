# Generate a beep sound file at /tmp/beep.wav

python3 << 'EOF'
import wave
import math
import struct

duration = 0.2  # seconds
frequency = 1000  # Hz
sample_rate = 48000
amplitude = 0.3

with wave.open('/tmp/beep.wav', 'w') as wav_file:
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(sample_rate)

    num_samples = int(duration * sample_rate)
    for i in range(num_samples):
        value = int(amplitude * 32767 * math.sin(2 * math.pi * frequency * i / sample_rate))
        wav_file.writeframes(struct.pack('h', value))

print("Beep file created at /tmp/beep.wav")
EOF
