"""Builds the synthesised cue sounds Ping, Bell and Knock into work/sounds_original/:
short mono 16-bit 48 kHz WAV files, made from scratch so the mod owns them
outright. sounds/ is built from work/sounds_original/ by tools/normalize_sounds.py;
run that afterwards, from the module root, and commit both folders' changed files:

    python3 tools/normalize_sounds.py work/sounds_original sounds --mono --rate 48000 \
        --codec pcm_s16le --onset cue_=12 --onset unblockable_=24 --boost unblockable_=2.5
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
PEAK = 0.8


def envelope(t, attack, decay):
    rise = min(1.0, t / attack) if attack > 0 else 1.0
    return rise * math.exp(-t / decay)


def ping(n):
    # A bright sine with a soft octave: clean and short, above the fight.
    t = n / RATE
    e = envelope(t, 0.002, 0.07)
    return e * (math.sin(2 * math.pi * 1320 * t) + 0.25 * math.sin(2 * math.pi * 2640 * t))


def bell(n):
    # Inharmonic partials of a small bell, the high ones dying first.
    t = n / RATE
    partials = ((880, 1.0, 0.22), (2368, 0.5, 0.10), (3520, 0.3, 0.06), (5104, 0.15, 0.04))
    return sum(a * envelope(t, 0.001, d) * math.sin(2 * math.pi * f * t) for f, a, d in partials)


_noise = random.Random(7)


def knock(n):
    # A wooden knock: a falling low tone under a short burst of noise.
    t = n / RATE
    tone = envelope(t, 0.001, 0.035) * math.sin(2 * math.pi * (420 - 1800 * t) * t)
    burst = envelope(t, 0.0005, 0.006) * (_noise.random() * 2 - 1)
    return tone + 0.5 * burst


SOUNDS = {
    "cue_ping.wav": (ping, 0.35),
    "cue_bell.wav": (bell, 0.6),
    "cue_knock.wav": (knock, 0.2),
}


def write(path, voice, seconds):
    samples = [voice(n) for n in range(int(seconds * RATE))]
    # A 5 ms fade-out so the end never clicks.
    fade = int(0.005 * RATE)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    scale = PEAK / max(abs(s) for s in samples)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", round(s * scale * 32767)) for s in samples))


def main():
    folder = Path(__file__).resolve().parents[1] / "work" / "sounds_original"
    folder.mkdir(exist_ok=True)
    for name, (voice, seconds) in SOUNDS.items():
        write(folder / name, voice, seconds)
        print(folder / name)


if __name__ == "__main__":
    main()
