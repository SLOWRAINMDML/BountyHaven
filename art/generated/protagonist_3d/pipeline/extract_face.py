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


# Feature heights measured on the protagonist illustration, as a fraction of chin -> skull top
FEATURE_T = {"mouth": 0.19, "nose": 0.29, "eye": 0.47, "brow": 0.565}
CHIN_Z, CROWN_Z = 1.535, 1.765
FRAME = (1.64, 0.62)  # face paint framing: centre z, ortho size (HEAD_FRAME in paint_project.py)


def z_of(py, H):
    return FRAME[0] + (0.5 - py / H) * FRAME[1]


def py_of(z, H):
    return (0.5 - (z - FRAME[0]) / FRAME[1]) * H


def feature_rows(alpha, H):
    """Detected heights (z) of brow, eye, nose and mouth from the decal's row coverage."""
    rows = (alpha > 0.5).sum(axis=1)
    bands, start = [], None
    for y, r in enumerate(list(rows) + [0]):
        if r > 0 and start is None:
            start = y
        elif r == 0 and start is not None:
            if rows[start:y].sum() > 20:
                bands.append((start, y - 1, rows[start:y].sum()))
            start = None
    if len(bands) < 2:
        return None
    big = max(bands, key=lambda b: b[2])          # brows + eyes
    below = [b for b in bands if b[0] > big[1]]
    mouth = below[-1] if below else None
    nose = below[0] if len(below) > 1 else None
    t, b = z_of(big[0], H), z_of(big[1], H)
    out = {"brow": t - (t - b) * 0.2, "eye": b + (t - b) * 0.3}
    if mouth:
        out["mouth"] = z_of((mouth[0] + mouth[1]) / 2, H)
    if nose:
        out["nose"] = z_of((nose[0] + nose[1]) / 2, H)
    return out


def remap_features(rgba, alpha_src):
    """Vertical piecewise-linear warp so the painted features land on the illustration's heights."""
    H = rgba.shape[0]
    found = feature_rows(alpha_src, H)
    if not found:
        return rgba
    pts = [(CHIN_Z, CHIN_Z)]
    for k in ("mouth", "nose", "eye", "brow"):
        if k in found:
            pts.append((found[k], CHIN_Z + FEATURE_T[k] * (CROWN_Z - CHIN_Z)))
    pts.append((CROWN_Z + 0.02, CROWN_Z + 0.02))
    pts.sort(key=lambda p: p[1])
    tgt = np.array([p[1] for p in pts])
    src = np.array([p[0] for p in pts])
    out = np.zeros_like(rgba)
    for y in range(H):
        zt = z_of(y, H)
        zs = np.interp(zt, tgt, src)
        ys = py_of(zs, H)
        y0 = int(np.floor(ys))
        if 0 <= y0 < H - 1:
            f = ys - y0
            out[y] = rgba[y0] * (1 - f) + rgba[y0 + 1] * f
    return out


def main():
    render = Image.open(P / "renders" / "head_bare_front.png").convert("RGBA")
    hm, top, neck = head_mask(render)
    width = hm.sum(axis=1).max()
    inner = erode(hm, max(3, int(width * 0.13)))
    inner[neck - int((neck - top) * 0.06):] = False  # drop the chin outline
    OUT.mkdir(parents=True, exist_ok=True)
    ref_alpha = None
    for e in EXPR:  # neutral first: its feature heights drive the warp for every expression
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
        rgba = np.dstack([img, alpha * 255]).astype(np.float32)
        if e == "neutral":
            ref_alpha = alpha
        rgba = remap_features(rgba, ref_alpha).clip(0, 255).astype("uint8")
        Image.fromarray(rgba).save(OUT / f"face_{e}.png")
        print("decal", e, "skin", skin.round(), "coverage %.3f" % (alpha > 0.5).mean())
    (OUT / "skin_tone.txt").write_text(" ".join(str(int(c)) for c in skin))


if __name__ == "__main__":
    main()
