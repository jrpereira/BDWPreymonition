"""Writes the Edges Flash gradient pictures to images/: white, opaque at the screen edge and
fading to transparent inward, so the template tints them yellow or red and stretches them
across its Thickness. Standard library only.

Per fade, two pictures: edge_<fade>_v.png fades down its height (the top edge; the bottom
edge flips it) and edge_<fade>_h.png fades along its width (the left edge; the right edge
flips it). Fades: linear (opacity falls evenly) and soft (it falls fast near the edge and
eases out inward, like a glow).

usage: python3 tools/make_edge_gradients.py   (from the Preymonition folder)
"""
import struct
import zlib
from pathlib import Path

LENGTH, ACROSS = 512, 4
FADES = {
    'linear': lambda t: 1 - t,
    'soft': lambda t: (1 - t) ** 2,
}


def png(width, height, alpha_at):
    """An RGBA PNG, white, alpha_at(x, y) in 0..1."""
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            rows += bytes((255, 255, 255, round(255 * max(0.0, min(1.0, alpha_at(x, y))))))

    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)

    header = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header)
            + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b''))


def main():
    images = Path(__file__).resolve().parent.parent / 'images'
    for name, fade in FADES.items():
        # t runs 0 at the screen edge to 1 at the inner end, through pixel centres.
        def at(i):
            return fade((i + 0.5) / LENGTH)
        (images / f'edge_{name}_v.png').write_bytes(png(ACROSS, LENGTH, lambda x, y: at(y)))
        (images / f'edge_{name}_h.png').write_bytes(png(LENGTH, ACROSS, lambda x, y: at(x)))
        print('wrote', f'edge_{name}_v.png', f'edge_{name}_h.png')


if __name__ == '__main__':
    main()
