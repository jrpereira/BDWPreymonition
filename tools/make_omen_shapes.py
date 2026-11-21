"""Draws the Solid and Chevron arrows as painted-style pictures, in the layout of
images/omen_fancy.png: 1774 by 1774, the glow on the left half and the core on the right,
each half an arrow pointing right with its tip at column 687, row 866.5 (as Fancy's).

The glow half holds the shape with a black outline, a dimmer inset (55% grey) and the
full body, so the mod's tint colours the body and inset and leaves the outline black. The
core half is empty. The shapes' design constants below are this script's own: the
pictures it writes are the only definition of Solid and Chevron.

usage: python3 tools/make_omen_shapes.py [folder]   (from the Preymonition folder; images/ by default)
"""
import math
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HALF_W, H = 887, 1774
TIP = (687.0, 866.5)
ANGLE = math.radians(135 / 2)      # the reference arm angle from the axis; sets scale and Solid
OUTLINE, INSET, DIM = 3, 4, 0.55   # outline and inset widths in design units; the inset's grey
BASE = 100                         # Solid's base, design units
ARM, THICKNESS = 70, 16            # Chevron's arm length and thickness, design units
SOLID_WIDTH = 0.9                  # Solid's width as a share of the reference chevron's
CHEVRON_WIDTH = 1.1                # Chevron's width as a share of the reference chevron's
MARGIN = 24                       # pixels kept clear at the top and bottom


def encode(width, height, rows):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    raw = b''.join(b'\x00' + bytes(row) for row in rows)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def inside(poly, x, y):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        (xi, yi), (xj, yj) = poly[i], poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def edge_distance(poly, x, y):
    best = float('inf')
    for i in range(len(poly)):
        (ax, ay), (bx, by) = poly[i], poly[(i + 1) % len(poly)]
        dx, dy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(x - ax - t * dx, y - ay - t * dy))
    return best


def solid():
    """The triangle sharing Chevron's tip and height, its base corners level with the top and
    bottom of Chevron's arms and SOLID_WIDTH of the ANGLE chevron's width back from the tip.
    Returns it and the pixels per design unit."""
    poly, _ = chevron(ANGLE)
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    tx, ty = TIP
    left = tx - SOLID_WIDTH * (tx - min(xs))
    return [(tx, ty), (left, max(ys)), (left, min(ys))], (max(ys) - min(ys)) / BASE


def chevron(angle=None):
    """The chevron, its arms reaching as far as the half allows. The arm thickness and the
    pixels per design unit are those of the ANGLE chevron; by default the arms open at the
    lower angle that makes it CHEVRON_WIDTH times as wide."""
    reach = min(TIP[1], H - TIP[1]) - MARGIN
    scale = reach / (ARM * math.sin(ANGLE))
    thickness = THICKNESS * scale

    def shape(a):
        arm = reach / math.sin(a)
        shift = thickness / math.sin(a)           # along the axis, for the arms' thickness
        tx, ty = TIP
        up = (tx - math.cos(a) * arm, ty - reach)
        down = (tx - math.cos(a) * arm, ty + reach)
        return [(tx, ty), up, (up[0] - shift, up[1]), (tx - shift, ty), (down[0] - shift, down[1]), down]

    def width(a):
        return TIP[0] - min(p[0] for p in shape(a))

    if angle is None:
        target, low, high = CHEVRON_WIDTH * width(ANGLE), math.radians(10), ANGLE
        for _ in range(60):                       # the width grows as the angle falls
            mid = (low + high) / 2
            low, high = (mid, high) if width(mid) > target else (low, mid)
        angle = (low + high) / 2
    return shape(angle), scale


def picture(poly, scale):
    outline, inset = OUTLINE * scale, (OUTLINE + INSET) * scale
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    left, right = int(min(xs)) - 2, int(max(xs)) + 2
    top, bottom = int(min(ys)) - 2, int(max(ys)) + 2
    rows = []
    for y in range(H):
        glow = bytearray(4 * HALF_W)
        if top <= y <= bottom:
            for x in range(max(0, left), min(HALF_W, right + 1)):
                cx, cy = x + 0.5, y + 0.5
                d = edge_distance(poly, cx, cy)
                signed = d if inside(poly, cx, cy) else -d
                alpha = max(0.0, min(1.0, signed + 0.5))
                if alpha <= 0:
                    continue
                # Black outline, then the dim inset, then the body, each edge smoothed over a pixel.
                into_inset = max(0.0, min(1.0, signed - outline + 0.5))
                into_body = max(0.0, min(1.0, signed - inset + 0.5))
                grey = into_inset * (DIM + (1 - DIM) * into_body)
                level = round(255 * grey)
                glow[4 * x:4 * x + 4] = bytes((level, level, level, round(255 * alpha)))
        rows.append(glow + bytearray(4 * HALF_W))
    return encode(2 * HALF_W, H, rows)


def main():
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'images'
    for name, shape in (('solid', solid), ('chevron', chevron)):
        poly, scale = shape()
        path = folder / f'omen_{name}.png'
        path.write_bytes(picture(poly, scale))
        print('wrote', path)


if __name__ == '__main__':
    main()
