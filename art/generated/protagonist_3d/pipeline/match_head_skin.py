"""Match the skin tone of the side/back head paints to the front face paint (removes the seam)."""
from pathlib import Path
import numpy as np
from PIL import Image

P = Path(__file__).resolve().parent / "painted"


def skin_mean(img):
    a = np.asarray(img, dtype=np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (r > 120) & (r > g + 12) & (g > b) & (a.min(axis=2) < 236) & (np.arange(a.shape[0])[:, None] < a.shape[0] * 0.62)
    return a[m].mean(axis=0), m


ref, _ = skin_mean(Image.open(P / "face_neutral.png").convert("RGB"))
for side in ("left", "right", "back"):
    f = P / f"head_bare_{side}.png"
    im = Image.open(f).convert("RGB")
    mean, mask = skin_mean(im)
    gain = ref / np.maximum(mean, 1)
    a = np.asarray(im, dtype=np.float32)
    # apply the gain to skin-coloured pixels only, feathered by how skin-like they are
    a[mask] = np.clip(a[mask] * gain, 0, 255)
    Image.fromarray(a.astype("uint8")).save(f)
    print(side, "gain", np.round(gain, 3))
