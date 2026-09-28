"""Cut the painted features (eyes, brows, nose line, mouth) out of each face paint into an RGBA decal.
Skin, the face outline and the neck/scarf become transparent, so the decal sits on the flat-skin head
like a ZZZ-style face texture and follows the face surface from any angle.

python3 paint/extract_face.py   -> exports/textures/face_<expression>.png
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_paint import _head_rows

ROOT = Path(__file__).resolve().parent.parent
P = ROOT / "paint"
OUT = ROOT / "exports" / "textures"
EXPR = ["neutral", "focused", "gentle_smile", "determined", "surprised", "battle_ready", "tired", "worried", "eyes_closed"]


def head_mask(render):
    a = np.asarray(render.split()[3]) > 20
    top, neck = _head_rows(a)
    m = np.zeros_like(a)
    m[top:neck] = a[top:neck]
    return m, top, neck


def erode(mask, px):
    im = Image.fromarray((mask * 255).astype("uint8")).filter(ImageFilter.MinFilter(px * 2 + 1))
    return np.asarray(im) > 127


def main():
    render = Image.open(P / "renders" / "head_bare_front.png").convert("RGBA")
    hm, top, neck = head_mask(render)
    width = hm.sum(axis=1).max()
    inner = erode(hm, max(3, int(width * 0.13)))
    inner[neck - int((neck - top) * 0.06):] = False  # drop the chin outline
    OUT.mkdir(parents=True, exist_ok=True)
    for e in EXPR:
        f = P / "painted" / f"face_{e}.png"
        if not f.exists():
            continue
        img = np.asarray(Image.open(f).convert("RGB").resize(render.size), dtype=np.float32)
        skin_px = img[inner]
        skin = np.median(skin_px, axis=0)
        d = np.linalg.norm(img - skin, axis=2)
        lum = img.mean(axis=2) - skin.mean()
        alpha = np.maximum(np.clip((d - 32) / 40, 0, 1), np.clip((lum - 18) / 25, 0, 1)) * inner  # dark ink or eye whites
        alpha = np.asarray(Image.fromarray((alpha * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float32) / 255
        # bolder ink so eyes/brows survive at game distance: grow the mask 1 px, deepen dark strokes
        grown = np.asarray(Image.fromarray((alpha * 255).astype("uint8")).filter(ImageFilter.MaxFilter(3)), dtype=np.float32) / 255
        alpha = np.maximum(alpha, grown * 0.85)
        dark = img.mean(axis=2, keepdims=True) < skin.mean() - 20
        img = np.where(dark, img * 0.7, img)
        rgba = np.dstack([img, alpha * 255]).clip(0, 255).astype("uint8")
        Image.fromarray(rgba).save(OUT / f"face_{e}.png")
        print("decal", e, "skin", skin.round(), "coverage %.3f" % (alpha > 0.5).mean())
    (OUT / "skin_tone.txt").write_text(" ".join(str(int(c)) for c in skin))


if __name__ == "__main__":
    main()
