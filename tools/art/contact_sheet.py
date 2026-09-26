#!/usr/bin/env python3
"""Lay extracted parts on a dark and a saturated backdrop to inspect edges and holes."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
d = Path(sys.argv[1]); out = Path(sys.argv[2])
files = sorted(p for p in d.glob('*.png'))
cols, cell = 10, 170
rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGBA', (cols * cell, rows * cell * 2), (0, 0, 0, 255))
for i, p in enumerate(files):
    im = Image.open(p); im.thumbnail((cell - 10, cell - 22))
    x, y = (i % cols) * cell, (i // cols) * cell * 2
    for k, col in enumerate([(24, 38, 48, 255), (200, 40, 160, 255)]):
        tile = Image.new('RGBA', (cell, cell), col)
        tile.alpha_composite(im, ((cell - im.width) // 2, 4))
        ImageDraw.Draw(tile).text((4, cell - 16), p.stem[:26], fill=(255, 255, 255, 255))
        sheet.alpha_composite(tile, (x, y + k * cell))
sheet.convert('RGB').save(out)
