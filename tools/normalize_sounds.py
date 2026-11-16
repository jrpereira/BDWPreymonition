"""Prepares warning-cue WAV files: format, fast onset, loudness.

The cues are fast warnings, so what counts is how they start.

1. Format: --mono downmixes, --rate resamples, --codec sets the sample format
   (e.g. pcm_s16le); unset, each file keeps its own.
2. Onset: --onset PREFIX=DB cuts files whose name starts with PREFIX so they
   begin where the level first comes within DB dB of the sound's sustained
   peak, removing leading silence and slow lead-ins; a --fade ms fade-in keeps
   the cut from clicking. Files matching no prefix are not cut.
3. Loudness: each file is measured by its loudest momentary loudness (EBU R128,
   400 ms window) within the first --early seconds, then gained to --target,
   plus --boost PREFIX=DB for files whose name starts with PREFIX.

Peaks too brief to register (shorter than --spike ms) do not hold the gain
back; a lookahead limiter, run at 4x the sample rate, shaves them under the
ceiling. Only sustained peaks limit the gain, so the limiter never takes more
than --max-reduction dB off anything that lasts.

    python3 tools/normalize_sounds.py SRC DST [--target -16] [--early 0.5]
        [--ceiling -1.5] [--spike 10] [--max-reduction 6] [--boost PREFIX=DB ...]
        [--onset PREFIX=DB ...] [--fade 3] [--mono] [--rate HZ] [--codec NAME]
        [--report]

Run from the module root. DST files are overwritten.
"""
import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as windows

FRAME = re.compile(r"\bt:\s*([\d.]+)\s.*?\bM:\s*(-?[\d.]+|-inf)")
PEAK = re.compile(r"Peak:\s*(-?[\d.]+|-inf)\s*dBFS")
SILENCE = 10 ** (-50 / 20)


def probe(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
         "stream=codec_name,sample_rate,channels", "-of", "json", str(path)],
        capture_output=True, text=True, check=True).stdout
    return json.loads(out)["streams"][0]


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def decode(path):
    info = probe(path)
    raw = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path), "-f", "f32le", "-acodec", "pcm_f32le", "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, info["channels"]), int(info["sample_rate"])


def held_envelope(level, width):
    """Level held for at least `width` samples: max over width (bridges waveform
    cycles), then min over a further width (drops clicks and single transients)."""
    if len(level) < 2 * width:
        return np.full(1, level.max() if len(level) else 0.0)
    return windows(windows(level, width).max(axis=1), width).min(axis=1)


def sustained_peak(path, spike_ms):
    samples, rate = decode(path)
    held = held_envelope(np.abs(samples).max(axis=1), max(1, int(rate * spike_ms / 1000))).max()
    return 20 * np.log10(max(held, 1e-9))


def onset_ms(path, spike_ms, below_db):
    """Time at which the level first comes within below_db of the sustained peak."""
    samples, rate = decode(path)
    level = np.abs(samples).max(axis=1)
    held = held_envelope(level, max(1, int(rate * spike_ms / 1000))).max()
    loud = np.nonzero(level >= held * 10 ** (-below_db / 20))[0]
    return 1000 * loud[0] / rate if len(loud) else 0.0


def lead_ms(path):
    samples, rate = decode(path)
    loud = np.nonzero(np.abs(samples).max(axis=1) > SILENCE)[0]
    return 1000 * loud[0] / rate if len(loud) else 0.0


def stage(src, dst, args):
    """Format conversion and onset cut, into a float WAV for measuring."""
    chain = []
    if args.mono and probe(src)["channels"] > 1:
        chain.append("pan=mono|c0=0.5*c0+0.5*c1")
    if args.rate:
        chain.append(f"aresample={args.rate}:resampler=soxr")
    ffmpeg("-i", str(src), *(["-af", ",".join(chain)] if chain else []), "-c:a", "pcm_f32le", str(dst))
    below = prefix_value(src.name, args.onset)
    if below is None:
        return 0.0
    cut = max(0.0, onset_ms(dst, args.spike, below) - args.fade)
    if cut > 0:
        trimmed = dst.with_suffix(".cut.wav")
        ffmpeg("-i", str(dst), "-af", f"atrim=start={cut / 1000:.4f},asetpts=PTS-STARTPTS,"
               f"afade=t=in:d={args.fade / 1000:.4f}", "-c:a", "pcm_f32le", str(trimmed))
        trimmed.replace(dst)
    return cut


def measure(path, early):
    """Loudest momentary loudness (LUFS) in the first `early` s, and true peak (dBTP)."""
    # Pad so cues shorter than the 400 ms window still yield a reading.
    err = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-v", "verbose", "-i", str(path),
         "-af", "apad=pad_dur=0.5,ebur128=framelog=verbose:peak=true", "-f", "null", "-"],
        capture_output=True, text=True, check=True).stderr
    # Frame t covers [t - 0.4, t]; the first full window ends at 0.4 s.
    last = max(early, 0.4) + 0.05
    values = [float(m) for t, m in FRAME.findall(err) if m != "-inf" and 0.35 < float(t) <= last]
    peaks = [float(v) for v in PEAK.findall(err) if v != "-inf"]
    return (max(values) if values else float("-inf")), (max(peaks) if peaks else float("-inf"))


def process(staged, dst, gain, ceiling, codec):
    rate = int(probe(staged)["sample_rate"])
    limit = 10 ** (ceiling / 20)
    chain = [
        f"volume={gain:.2f}dB",
        # Limit at 4x the rate so peaks between samples are caught too.
        f"aresample={rate * 4}",
        f"alimiter=limit={limit:.4f}:level=0:latency=1:attack=1:release=60",
        f"aresample={rate}:dither_method=triangular",
    ]
    ffmpeg("-i", str(staged), "-af", ",".join(chain), "-c:a", codec, "-ar", str(rate),
           "-map_metadata", "-1", str(dst))


def prefix_value(name, pairs):
    values = [value for prefix, value in pairs if name.startswith(prefix)]
    return values[0] if values else None


def parse_pair(text):
    prefix, _, value = text.partition("=")
    return prefix, float(value)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("src", type=Path)
    parser.add_argument("dst", type=Path)
    parser.add_argument("--target", type=float, default=-16.0, help="early momentary loudness, LUFS")
    parser.add_argument("--early", type=float, default=0.5, help="seconds from the start that count")
    parser.add_argument("--ceiling", type=float, default=-1.5, help="peak ceiling, dBFS")
    parser.add_argument("--spike", type=float, default=10.0, help="peaks shorter than this (ms) are shaved freely")
    parser.add_argument("--max-reduction", type=float, default=6.0, help="most limiting on sustained peaks, dB")
    parser.add_argument("--boost", type=parse_pair, action="append", default=[], metavar="PREFIX=DB")
    parser.add_argument("--onset", type=parse_pair, action="append", default=[], metavar="PREFIX=DB")
    parser.add_argument("--fade", type=float, default=3.0, help="fade-in after an onset cut, ms")
    parser.add_argument("--mono", action="store_true")
    parser.add_argument("--rate", type=int)
    parser.add_argument("--codec")
    parser.add_argument("--report", action="store_true", help="measure only")
    args = parser.parse_args()

    args.dst.mkdir(parents=True, exist_ok=True)
    print(f"{'file':26} {'cut':>4} {'early':>6} {'sust':>5} {'want':>6} {'gain':>6}  {'out':>6} {'outTP':>5}"
          f" {'lead':>4} {'-10dB':>5}")
    with tempfile.TemporaryDirectory() as scratch:
        for src in sorted(args.src.glob("*.wav")):
            staged = Path(scratch) / src.name
            cut = stage(src, staged, args)
            loud, _ = measure(staged, args.early)
            cap = args.ceiling + args.max_reduction - sustained_peak(staged, args.spike)
            want = args.target + (prefix_value(src.name, args.boost) or 0.0)
            gain = min(want - loud, cap)
            line = f"{src.name:26} {cut:4.0f} {loud:6.1f} {args.ceiling + args.max_reduction - cap:5.1f} {want:6.1f}"
            if args.report:
                print(f"{line} {gain:+6.1f}")
                continue
            dst = args.dst / src.name
            codec = args.codec or probe(src)["codec_name"]
            # Limiting can pull the result under the target; correct for it, within the cap.
            for _ in range(3):
                process(staged, dst, gain, args.ceiling, codec)
                out_loud, out_peak = measure(dst, args.early)
                better = min(gain + (want - out_loud), cap)
                if abs(want - out_loud) < 0.3 or better - gain < 0.1:
                    break
                gain = better
            print(f"{line} {gain:+6.1f}  {out_loud:6.1f} {out_peak:5.1f} {lead_ms(dst):4.0f}"
                  f" {onset_ms(dst, args.spike, 10):5.0f}")


if __name__ == "__main__":
    main()
