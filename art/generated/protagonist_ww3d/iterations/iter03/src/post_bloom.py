"""Bloom + light grade for the VFX render (post, outside Blender). python3 post_bloom.py in.png out.png"""
import sys
import numpy as np
from PIL import Image, ImageFilter
im = Image.open(sys.argv[1]).convert("RGB")
a = np.asarray(im, np.float32) / 255
lum = a.max(axis=2)
bright = (a * np.clip((lum - 0.75) / 0.25, 0, 1)[..., None] * 255).astype(np.uint8)
b = Image.fromarray(bright)
glow = sum(np.asarray(b.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255 * w for r, w in ((6, 0.6), (18, 0.5), (48, 0.45)))
out = 1 - (1 - a) * (1 - np.clip(glow, 0, 1))          # screen blend
h, w = lum.shape
yy, xx = np.mgrid[0:h, 0:w]
vig = 1 - 0.35 * (((xx - w / 2) / w) ** 2 + ((yy - h / 2) / h) ** 2) * 2
Image.fromarray((np.clip(out * vig[..., None], 0, 1) * 255).astype(np.uint8)).save(sys.argv[2])
