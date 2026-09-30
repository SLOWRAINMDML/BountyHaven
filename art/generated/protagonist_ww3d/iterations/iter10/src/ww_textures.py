"""Paint toon textures from the Codex (ima2) outputs at the measured landmark positions.

python3 ww_textures.py   -> exports/textures/{face_base,cloak_color,cloak_alpha}.png
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
C = os.path.join(ROOT, "concepts")
T = os.path.join(ROOT, "exports", "textures")
os.makedirs(T, exist_ok=True)
LM = json.load(open(os.path.join(ROOT, "measure", "landmarks.json")))
FY, FX = LM["front_y"], LM["front_x"]
PX = 1.78 / (FY["sole"] - FY["hair_top"])
Z = lambda k: (FY["sole"] - FY[k]) * PX
SKIN = (240, 196, 160)
rng = np.random.default_rng(3)


def smooth_noise(h, w, scale, seed):
    r = np.random.default_rng(seed).random((max(2, h // scale), max(2, w // scale)))
    im = Image.fromarray((r * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im, np.float32) / 255.0


# ----------------------------------------------------------------------------- face
def cut_parts():
    """Split the face-parts atlas into RGBA elements (white keyed, closed outlines filled)."""
    src = Image.open(os.path.join(C, "03_ww_face_parts.png"))
    rgba = np.asarray(src.convert("RGBA")).astype(np.float32)
    if src.mode == "RGBA" and rgba[..., 3].min() < 10:
        ink = rgba[..., 3] > 20                       # ima2 returned a transparent background
    else:
        ink = (255 - rgba[..., :3].min(axis=2)) > 12
        rgba[..., 3] = ndimage.binary_fill_holes(ndimage.binary_closing(ink, iterations=3)) * 255.0
    lab, n = ndimage.label(ndimage.binary_dilation(ink, iterations=6))
    out = []
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(ys) < 400:
            continue
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        sub = rgba[y0:y1, x0:x1].copy()
        sub[..., 3] *= (lab[y0:y1, x0:x1] == i)
        out.append(((x0 + x1) / 2, (y0 + y1) / 2, Image.fromarray(sub.clip(0, 255).astype(np.uint8))))
    return out


def face_texture(size=1024):
    x0, z0, span = -0.10, Z("chin") - 0.02, 0.20
    to_px = lambda x, z: ((x - x0) / span * size, (1 - (z - z0) / span) * size)
    img = Image.new("RGBA", (size, size), (*SKIN, 255))
    # soft warm blush + slight jaw/neck warm shade (painted, not lit)
    blush = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(blush)
    for sx in (-1, 1):
        cx, cy = to_px(sx * 0.045, Z("nose") + 0.004)
        d.ellipse((cx - 40, cy - 18, cx + 40, cy + 18), fill=38)
    blush = blush.filter(ImageFilter.GaussianBlur(22))
    img = Image.composite(Image.new("RGBA", (size, size), (232, 150, 128, 255)), img, blush)
    parts = cut_parts()
    src_h = Image.open(os.path.join(C, '03_ww_face_parts.png')).height
    eyes = sorted([p for p in parts if p[1] < src_h * 0.5], key=lambda p: p[0])
    lower = sorted([p for p in parts if p[1] >= src_h * 0.5], key=lambda p: p[0])
    brows, mouth = lower[:-1], lower[-1]
    eye_w = 0.060                          # decal width incl. lashes; aperture ~ measured eye_w
    ex = (FX["eye_r"] - FX["eye_l"]) / 2 * PX
    for sx, (_, _, im) in zip((-1, 1), eyes):
        w = int(eye_w / span * size)
        h = int(im.height * w / im.width)
        e = im.resize((w, h), Image.LANCZOS)
        cx, cy = to_px(sx * ex, Z("eye"))
        img.alpha_composite(e, (int(cx - w / 2 - sx * 4), int(cy - h * 0.55)))
    for sx, (_, _, im) in zip((-1, 1), brows):
        w = int(0.052 / span * size)
        h = int(im.height * w / im.width)
        b = im.resize((w, h), Image.LANCZOS)
        cx, cy = to_px(sx * (ex + 0.004), Z("brow") + 0.003)
        img.alpha_composite(b, (int(cx - w / 2), int(cy - h / 2)))
    w = int(0.032 / span * size)
    im = mouth[2]
    h = int(im.height * w / im.width)
    cx, cy = to_px(0, Z("mouth"))
    img.alpha_composite(im.resize((w, h), Image.LANCZOS), (int(cx - w / 2), int(cy - h / 2)))
    # nose: small shadow tick on the shaded side, like the illustration
    d = ImageDraw.Draw(img)
    nx, ny = to_px(0.004, Z("nose"))
    d.line([(nx, ny - 20), (nx + 6, ny + 2), (nx - 2, ny + 6)], fill=(186, 118, 96, 255), width=4)
    img.convert("RGB").save(os.path.join(T, "face_base.png"))


# ----------------------------------------------------------------------------- cloak
def cloak_textures(w=2048, h=1024):
    u = np.linspace(0, 1, w)[None, :].repeat(h, 0)
    v = np.linspace(1, 0, h)[:, None].repeat(w, 1)   # image row 0 = UV v 1 = cloak hem
    n1 = smooth_noise(h, w, 64, 1)
    n2 = smooth_noise(h, w, 12, 2)
    base = np.array((184, 66, 42), np.float32)
    col = base[None, None, :] * (0.9 + 0.18 * n1[..., None] + 0.06 * n2[..., None])
    # faded pale splotches concentrated near the hem (illustration: bleached spots)
    spots = (smooth_noise(h, w, 20, 5) > 0.72) & (v > 0.55 + 0.25 * n1)
    spots = ndimage.gaussian_filter(spots.astype(np.float32), 2)
    col = col * (1 - spots[..., None] * 0.7) + np.array((236, 214, 196))[None, None, :] * spots[..., None] * 0.7
    # emblem on the back (u = 0.478 is the spine)
    em_path = os.path.join(C, "04_ww_emblem.png")
    if os.path.exists(em_path):
        em = Image.open(em_path).convert("L")
        ew, eh = int(0.2 / 0.96 * w), int(0.2 / 0.77 * h)
        em = np.asarray(em.resize((ew, eh), Image.LANCZOS), np.float32) / 255.0
        cx, cy = int(0.478 * w), int(0.66 * h)
        sl = (slice(cy - eh // 2, cy - eh // 2 + eh), slice(cx - ew // 2, cx - ew // 2 + ew))
        em = em * (0.85 + 0.15 * n2[sl])
        col[sl] = col[sl] * (1 - em[..., None] * 0.85) + np.array((236, 220, 200))[None, None, :] * em[..., None] * 0.85
    Image.fromarray(col.clip(0, 255).astype(np.uint8)).save(os.path.join(T, "cloak_color.png"))
    # torn hem + holes
    jag = 0.035 * np.abs(np.sin(u * 90 + 7 * n1)) + 0.06 * smooth_noise(h, w, 40, 7) + 0.05 * (smooth_noise(h, w, 8, 8) > 0.6)
    hem = v < (0.9 - jag)
    holes = (smooth_noise(h, w, 10, 9) > 0.8) & (v > 0.7)
    alpha = hem & ~holes
    alpha[:, :] = alpha
    Image.fromarray((alpha * 255).astype(np.uint8)).save(os.path.join(T, "cloak_alpha.png"))


def swatches():
    """Split the Codex swatch sheet into mean-normalised detail tiles (multiplied over the toon colours)."""
    src = os.path.join(C, "07_ww_cloth_swatches.png")
    if not os.path.exists(src):
        return
    im = Image.open(src).convert("RGB")
    w, h = im.size
    for name, box in (("red", (0, 0, w // 2, h // 2)), ("cream", (w // 2, 0, w, h // 2)),
                      ("twill", (0, h // 2, w // 2, h)), ("leather", (w // 2, h // 2, w, h))):
        t = np.asarray(im.crop(box).resize((1024, 1024), Image.LANCZOS), np.float32)
        lum = t.mean(axis=2, keepdims=True)
        t = t / lum.mean() * 0.93 * 255 * (0.5 + 0.5 * lum / lum.mean()) / (0.5 + 0.5 * lum / lum.mean())
        detail = (lum / lum.mean()) ** 1.2 * (t / (lum + 1e-3))  # keep hue shifts of stains, unit mean
        detail = detail / detail.mean() * 0.93
        Image.fromarray((detail.clip(0, 1) * 255).astype(np.uint8)).save(os.path.join(T, f"detail_{name}.png"))


def patch(size=512):
    """Round shoulder patch: cream canvas disc, dark stitched ring, rust compass emblem (Codex 04)."""
    im = Image.new("RGB", (size, size), (228, 214, 188))
    d = ImageDraw.Draw(im)
    d.ellipse((6, 6, size - 6, size - 6), outline=(70, 50, 38), width=26)
    d.ellipse((44, 44, size - 44, size - 44), outline=(150, 110, 70), width=6)
    em_path = os.path.join(C, "04_ww_emblem.png")
    if os.path.exists(em_path):
        em = Image.open(em_path).convert("L").resize((size - 150, size - 150), Image.LANCZOS)
        im.paste(Image.new("RGB", em.size, (150, 58, 38)), (75, 75), em)
    im.save(os.path.join(T, "patch.png"))


if __name__ == "__main__":
    patch()
    swatches()
    face_texture()
    cloak_textures()
    print("textures ok")
