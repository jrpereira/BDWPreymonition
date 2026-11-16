"""Fits warning-cue WAV files to a length while keeping their nature.

For each SRC/<glob> file (read as mono 48 kHz, written as float WAV to DST):

0. Subsonic swing: when more than a tenth of a file's energy lies below 20 Hz
   (a slow offset drift nobody hears, but which pushes the speaker and thumps
   when it starts or stops), a 60 ms moving average of the waveform, mirrored
   at the edges, is subtracted from it.
1. Inaudible tail: the file ends where the level last comes within --tail-db of
   its sustained peak (peaks under 10 ms ignored). The fade-out covers only what
   comes after the level last falls --quiet-db below the peak (at least 50 ms),
   so a sound that
   dies away keeps its own decay; a sound still loud at its end fades over
   --fade ms. Fades decay linearly in dB, like a natural decay, so nothing ends
   abruptly; this fade takes at most a quarter of the sound. Every file also
   fades in over 5 ms, so none starts with a click.
2. Length: files still longer than a limit are brought to its target; by
   default above 650 ms to 600 ms, otherwise above 500 ms to 450 ms
   (--fit LIMIT=TARGET, longest limit first). How depends on what lies past the
   target:
   - decay (level there at most --decay-db below the peak): the sound fades out
     early, ending at the target, as if damped a little sooner. The fade spans
     the last 40% of the target, 100 to 250 ms.
   - sustained sound: everything after the attack plays faster, pitch kept
     (rubberband), so the whole sound still unfolds. The attack (to the first
     envelope peak + 20 ms, at most 80 ms) stays untouched and joins the faster
     body where their waveforms match best, with a 10 ms crossfade. It ends
     with a fade as long as the decay case's: these sounds barely decay on their
     own, so a short fade would sound like a cut.

Run normalize_sounds.py on DST afterwards for loudness and format.

    python3 tools/fit_sounds.py SRC DST [--glob 'cue_*.wav'] [--tail-db 60]
        [--quiet-db 40] [--fade 150] [--decay-db 20] [--fit 650=600 --fit 500=450]
"""
import argparse
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as windows

RATE = 48000
SPIKE = RATE // 100  # 10 ms


def decode(path, tempo=None):
    chain = "aformat=channel_layouts=mono"
    if tempo:
        chain = f"rubberband=tempo={tempo:.4f}:transients=mixed:window=standard," + chain
    raw = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path), "-af", chain,
         "-ar", str(RATE), "-f", "f32le", "-acodec", "pcm_f32le", "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").copy()


def encode(samples, path):
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1",
         "-i", "-", "-c:a", "pcm_f32le", str(path)],
        input=samples.astype("<f4").tobytes(), check=True)


def envelope(samples):
    """Peak envelope (max over 10 ms) in dB below the sustained peak."""
    level = np.abs(samples)
    env = windows(level, SPIKE).max(axis=1) if len(level) > SPIKE else level
    held = windows(env, SPIKE).min(axis=1).max() if len(env) > SPIKE else env.max()
    return 20 * np.log10(np.maximum(env, 1e-9) / max(held, 1e-9))


def last_within(db, below):
    above = np.nonzero(db >= -below)[0]
    return above[-1] + SPIKE if len(above) else len(db)


def fade_out(samples, length, depth=60.0):
    """Fades the last `length` samples as a natural decay: linear in dB down to
    -depth, then to zero over the last 2 ms. A cosine fade ends too steeply and
    an audible sound faded that way sounds unplugged."""
    length = min(len(samples), length)
    if length:
        samples[-length:] *= 10 ** (-depth / 20 * np.linspace(0, 1, length))
        tail = min(length, RATE // 500)
        samples[-tail:] *= np.linspace(1, 0, tail)
    return samples


def remove_subsonic(samples, share=0.1):
    """Subtracts the waveform's slow swing when it holds more than `share` of the energy."""
    power = np.abs(np.fft.rfft(samples)) ** 2
    freqs = np.fft.rfftfreq(len(samples), 1 / RATE)
    if power[freqs < 20].sum() <= share * power.sum():
        return samples, False
    width = RATE * 6 // 100
    window = np.hanning(width)
    padded = np.pad(samples, width, mode="reflect")
    baseline = np.convolve(padded, window / window.sum(), mode="same")[width:-width]
    return (samples - baseline).astype(samples.dtype), True


def splice(head, body, at, search, cross):
    """head[:at] then body from its best match to head around `at`, crossfaded."""
    probe = head[at - cross:at]
    lo, hi = max(0, at - cross - search), min(len(body) - cross, at - cross + search)
    scores = [np.dot(probe, body[i:i + cross]) / (np.linalg.norm(body[i:i + cross]) + 1e-9)
              for i in range(lo, hi)]
    start = lo + int(np.argmax(scores))
    ramp = np.linspace(0, 1, cross)
    joint = head[at - cross:at] * (1 - ramp) + body[start:start + cross] * ramp
    return np.concatenate([head[:at - cross], joint, body[start + cross:]])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("src", type=Path)
    parser.add_argument("dst", type=Path)
    parser.add_argument("--glob", default="cue_*.wav")
    parser.add_argument("--tail-db", type=float, default=60.0)
    parser.add_argument("--quiet-db", type=float, default=40.0)
    parser.add_argument("--fade", type=float, default=150.0)
    parser.add_argument("--decay-db", type=float, default=20.0)
    parser.add_argument("--fit", action="append", default=[], metavar="LIMIT=TARGET")
    args = parser.parse_args()
    fits = sorted(((float(a), float(b)) for a, b in (f.split("=") for f in args.fit or ["650=600", "500=450"])),
                  reverse=True)
    ms = lambda n: 1000 * n / RATE
    count = lambda m: int(RATE * m / 1000)

    args.dst.mkdir(parents=True, exist_ok=True)
    print(f"{'file':20} {'dur':>5} {'tail':>5} {'fit':>5}  how")
    for src in sorted(args.src.glob(args.glob)):
        samples = decode(src)
        before = len(samples)
        # 0. Subsonic swing.
        samples, subsonic = remove_subsonic(samples)
        how = "subsonic swing removed; " if subsonic else ""
        # 1. Inaudible tail.
        db = envelope(samples)
        end = min(len(samples), last_within(db, args.tail_db))
        quiet = min(end, last_within(db, args.quiet_db))
        fade = max(end - quiet, count(50)) if end - quiet >= count(10) else count(args.fade)
        samples = fade_out(samples[:end].copy(), min(fade, end // 4))
        tail = len(samples)
        # 2. Length.
        target = next((t for limit, t in fits if ms(len(samples)) > limit), None)
        if target:
            db = envelope(samples)
            cut = count(target)
            if db[min(cut, len(db) - 1)] <= -args.decay_db:
                samples = fade_out(samples[:cut].copy(), count(min(250, max(100, target * 0.4))))
                how += f"earlier fade ({db[cut]:.0f} dB at the target)"
            else:
                attack = min(count(80), int(np.argmax(db[:count(200)])) + count(20))
                tempo = (len(samples) - attack) / (cut - attack)
                with tempfile.TemporaryDirectory() as scratch:
                    trimmed = Path(scratch) / "in.wav"
                    encode(samples, trimmed)
                    for _ in range(4):
                        body = decode(trimmed, tempo)
                        # The faster body's attack sits at attack / tempo; join there.
                        joined = splice(samples, np.concatenate([np.zeros(attack - int(attack / tempo)), body]),
                                        attack, count(15), count(10))
                        if abs(len(joined) - cut) < count(5):
                            break
                        tempo *= (len(joined) - attack) / (cut - attack)
                samples = fade_out(joined[:cut].copy(), count(min(250, max(100, target * 0.4))))
                how += f"body x{tempo:.2f} after a {ms(attack):.0f} ms attack"
        lead = min(len(samples), count(5))
        samples[:lead] *= np.linspace(0, 1, lead)
        encode(samples, args.dst / src.name)
        print(f"{src.name:20} {ms(before):5.0f} {ms(tail):5.0f} {ms(len(samples)):5.0f}  {how}")


if __name__ == "__main__":
    main()
