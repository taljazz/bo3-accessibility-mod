"""Generate simple beacon beep WAV files for the proximity system.

Creates 3 STEREO 48kHz 16-bit WAV tones (BO3 sound converter requires stereo):
- aud_acc_beacon_close.wav  — short high-pitched beep (you're very close)
- aud_acc_beacon_near.wav   — medium beep
- aud_acc_beacon_far.wav    — low soft beep (far away)
"""
import os
import struct
import math

SAMPLE_RATE = 48000
BITS = 16
CHANNELS = 2  # STEREO — BO3 sound converter requires stereo input

OUTPUT_DIR = r"C:\Coding Projects\bo3 mod\sound\accessibility\beacons"
# Deploy to ALL locations the linker / snd_convert might look
DEPLOY_DIRS = [
    # snd_convert.exe resolves FileSpec paths relative to THIS directory:
    r"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\sound_assets\accessibility\beacons",
    r"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\share\raw\sound\accessibility\beacons",
    r"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\mods\zm_accessibility\sound\accessibility\beacons",
]

def generate_beep(freq, duration_ms, amplitude=0.8, fade_ms=10):
    """Generate a sine wave beep as a list of 16-bit signed samples (mono)."""
    num_samples = int(SAMPLE_RATE * duration_ms / 1000)
    fade_samples = int(SAMPLE_RATE * fade_ms / 1000)
    samples = []

    for i in range(num_samples):
        t = i / SAMPLE_RATE
        value = math.sin(2 * math.pi * freq * t) * amplitude

        # Fade in/out to avoid clicks
        if i < fade_samples:
            value *= i / fade_samples
        elif i > num_samples - fade_samples:
            value *= (num_samples - i) / fade_samples

        sample = int(value * 32767)
        sample = max(-32768, min(32767, sample))
        samples.append(sample)

    return samples

def write_wav_stereo(filepath, samples):
    """Write stereo 16-bit 48kHz WAV file (identical L/R channels)."""
    num_samples = len(samples)
    data_size = num_samples * CHANNELS * 2  # 2 bytes per sample per channel
    file_size = 36 + data_size

    with open(filepath, "wb") as f:
        # RIFF header
        f.write(b"RIFF")
        f.write(struct.pack("<I", file_size))
        f.write(b"WAVE")
        # fmt chunk
        f.write(b"fmt ")
        f.write(struct.pack("<I", 16))
        f.write(struct.pack("<H", 1))       # PCM
        f.write(struct.pack("<H", CHANNELS))
        f.write(struct.pack("<I", SAMPLE_RATE))
        f.write(struct.pack("<I", SAMPLE_RATE * CHANNELS * 2))
        f.write(struct.pack("<H", CHANNELS * 2))
        f.write(struct.pack("<H", BITS))
        # data chunk
        f.write(b"data")
        f.write(struct.pack("<I", data_size))
        for s in samples:
            # Write same sample to both L and R channels
            f.write(struct.pack("<h", s))
            f.write(struct.pack("<h", s))

# Define the 3 beacon tones
beacons = {
    "aud_acc_beacon_close": {"freq": 880, "duration_ms": 120, "amplitude": 0.9},
    "aud_acc_beacon_near":  {"freq": 660, "duration_ms": 150, "amplitude": 0.7},
    "aud_acc_beacon_far":   {"freq": 440, "duration_ms": 200, "amplitude": 0.5},
}

# Create output directories
for d in [OUTPUT_DIR] + DEPLOY_DIRS:
    os.makedirs(d, exist_ok=True)

for name, params in beacons.items():
    samples = generate_beep(params["freq"], params["duration_ms"], params["amplitude"])

    # Write to all locations
    for d in [OUTPUT_DIR] + DEPLOY_DIRS:
        path = os.path.join(d, f"{name}.wav")
        write_wav_stereo(path, samples)

    duration = len(samples) / SAMPLE_RATE * 1000
    print(f"  {name}.wav — {params['freq']}Hz, {duration:.0f}ms, stereo 48kHz 16-bit")

print(f"\nGenerated {len(beacons)} stereo beacon WAVs to all locations")
