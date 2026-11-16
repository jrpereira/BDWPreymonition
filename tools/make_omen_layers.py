"""Writes a painted arrow Style's picture, images/omen_<style>.png, from its colour art in
art/<style>.png: the glow on the left half and the core on the right, each the art's size.

The art is a yellow arrow pointing right with white-hot strokes on a transparent
background, laid out like Fancy's (see Scripts/preymonition/omens_fancy.lua). The Omens
draw the glow tinted (yellow, or red in the Perfect Opportunity window) and the core on top
untinted, so one picture serves both states and its colours come from the mod.

- Core: white, as opaque as the art is white (its blue channel, where the yellow glow has
  little).
- Glow: grey by the art's brightness (scaled to the glow's brightest), lifted by LIFT so
  it keeps its gold under the tint without flattening the centre's detail.

Standard library only.
usage: python3 tools/make_omen_layers.py [style ...]   (from the Preymonition folder; all art/*.png by default)
"""
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# The glow's lift: grey ** CURVE * GAIN, alpha * GAIN (chosen 2026-11-16 from rendered variants).
CURVE, GAIN = 0.8, 1.1
# Blue above CORE_FROM (0..1) starts to count as core, fully at 1.
CORE_FROM = 0.35


def chunks(data):
    pos = 8
    while pos < len(data):
        n = struct.unpack('>I', data[pos:pos + 4])[0]
        yield data[pos + 4:pos + 8], data[pos + 8:pos + 8 + n]
        pos += 12 + n


def decode(path):
    """(width, height, rows of RGBA bytes) of an 8-bit RGB or RGBA PNG."""
    idat = b''
    for kind, body in chunks(path.read_bytes()):
        if kind == b'IHDR':
            width, height, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', body)
            if depth != 8 or ctype not in (2, 6) or interlace:
                raise SystemExit(f'{path}: needs an 8-bit, non-interlaced RGB or RGBA PNG')
            channels = 4 if ctype == 6 else 3
        elif kind == b'IDAT':
            idat += body
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, prev, at = [], bytearray(stride), 0
    for _ in range(height):
        kind = raw[at]
        line = bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for x in range(stride):
            left = line[x - channels] if x >= channels else 0
            up = prev[x]
            if kind == 1:
                line[x] = (line[x] + left) & 255
            elif kind == 2:
                line[x] = (line[x] + up) & 255
            elif kind == 3:
                line[x] = (line[x] + ((left + up) >> 1)) & 255
            elif kind == 4:
                corner = prev[x - channels] if x >= channels else 0
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                line[x] = (line[x] + (left if pa <= pb and pa <= pc else up if pb <= pc else corner)) & 255
        rgba = bytearray()
        for x in range(0, stride, channels):
            rgba += line[x:x + 3] + (bytes((line[x + 3],)) if channels == 4 else b'\xff')
        rows.append(rgba)
        prev = line
    return width, height, rows


def encode(width, height, rows):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    raw = b''.join(b'\x00' + bytes(row) for row in rows)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def layers(width, height, rows):
    def brightness(r, g, b):
        return (0.3 * r + 0.59 * g + 0.11 * b) / 255
    peak = max((brightness(*row[x:x + 3]) for row in rows for x in range(0, len(row), 4)
                if row[x + 3] > 128 and row[x + 2] < 120), default=1) or 1
    out = []
    for row in rows:
        glow, core = bytearray(), bytearray()
        for x in range(0, len(row), 4):
            r, g, b, a = row[x:x + 4]
            alpha = a / 255
            grey = min(1.0, (min(1.0, brightness(r, g, b) / peak) ** CURVE) * GAIN)
            shown = min(1.0, alpha * GAIN)
            white = max(0.0, (b / 255 - CORE_FROM) / (1 - CORE_FROM))
            level = round(255 * grey)
            glow += bytes((level, level, level, round(255 * shown)))
            core += bytes((255, 255, 255, round(255 * alpha * white)))
        out.append(glow + core)
    return width * 2, height, out


def main(styles):
    art = ROOT / 'art'
    styles = styles or sorted(p.stem for p in art.glob('*.png'))
    for style in styles:
        width, height, rows = decode(art / f'{style}.png')
        target = ROOT / 'images' / f'omen_{style}.png'
        target.write_bytes(encode(*layers(width, height, rows)))
        print('wrote', target.relative_to(ROOT), f'{width * 2}x{height}')


if __name__ == '__main__':
    main(sys.argv[1:])
