"""VRoid-style face parts from the Codex decal atlas: eye white / iris / highlight / eyeline / brow / mouth layers.

Used by ww_textures.face_texture when face_spec "eye_mode" == "layered". Writes exports/textures/fp_*.png and
exports/textures/face_parts.json (part rectangles in metres, front-projected on the face, x right = character left).
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


def split_eye(rgba):
    """rgba: HxWx4 float 0..1 eye element. Returns dict of layer arrays + geometry in element pixels."""
    rgb, a = rgba[..., :3], rgba[..., 3]
    hsv = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8)).convert("HSV")).astype(np.float32) / 255
    s, v = hsv[..., 1], hsv[..., 2]
    on = a > 0.4
    dark = (v < 0.36) & on
    iris = (s > 0.35) & (v >= 0.2) & (v < 0.92) & on & ~dark
    lab, n = ndimage.label(iris)
    if n:
        iris = lab == (1 + int(np.argmax(ndimage.sum(iris, lab, range(1, n + 1)))))
    hl = (v > 0.92) & (s < 0.15) & on
    sclera = on & ~dark & ~iris & ~hl
    lab, n = ndimage.label(sclera)
    if n:
        sizes = ndimage.sum(sclera, lab, range(1, n + 1))
        keep = [i + 1 for i, z in enumerate(sizes) if z > sizes.max() * 0.15]
        sclera = np.isin(lab, keep)
    H, W = a.shape
    ys, xs = np.where(iris)
    x0, x1, y1 = xs.min(), xs.max(), ys.max()
    r_or = (x1 - x0) / 2
    R = r_or * 1.22                                   # dark ring outside the orange
    cx, cy = (x0 + x1) / 2, y1 - r_or
    # eye opening: top/bottom curves fitted on sclera columns (the iris top merges with the lash line)
    cols = np.where((sclera | iris).any(axis=0))[0]
    top, bot = [], []
    for c in cols:
        col = np.where(sclera[:, c])[0]
        if len(col) and abs(c - cx) > R * 1.05:
            top.append((c, col.min()))
        cb = np.where((sclera | iris)[:, c])[0]
        bot.append((c, cb.max()))
    top, bot = np.array(top, float), np.array(bot, float)
    pt = np.polyfit(top[:, 0], top[:, 1], 2)
    pb = np.polyfit(bot[:, 0], bot[:, 1], 2)
    xx = np.arange(W)
    ty, by = np.polyval(pt, xx), np.polyval(pb, xx)
    yy = np.arange(H)[:, None]
    opening = (yy >= ty[None, :] - 1) & (yy <= by[None, :] + 1) & (xx[None, :] >= cols.min()) & (xx[None, :] <= cols.max())
    opening = ndimage.binary_opening(opening, iterations=2)   # smooth almond between the fitted lid curves
    # full iris disc from the radial profile of the visible part
    yy2, xx2 = np.mgrid[0:H, 0:W]
    rr = np.hypot(xx2 - cx, yy2 - cy)
    prof = np.zeros((64, 3))
    for i in range(64):
        m = iris & (rr >= i / 64 * r_or) & (rr < (i + 1) / 64 * r_or)
        prof[i] = np.median(rgb[m], axis=0) if m.sum() > 3 else np.nan
    for i in range(64):                                # fill pupil / missing bins inward from the nearest valid one
        if np.isnan(prof[i]).any():
            j = next((k for k in range(i, 64) if not np.isnan(prof[k]).any()), None)
            prof[i] = prof[j] if j is not None else (0.3, 0.18, 0.1)
    ring_col = np.median(rgb[dark & (rr > r_or) & (rr < R * 1.05)], axis=0) if (dark & (rr > r_or) & (rr < R)).sum() else (0.2, 0.12, 0.08)
    hl_c = np.array(ndimage.center_of_mass(hl)) if hl.sum() else np.array([cy - R * 0.4, cx + R * 0.3])
    hl_r = max(np.sqrt(hl.sum() / np.pi), R * 0.12)
    return {"opening": opening, "dark": dark & ~opening, "prof": prof,
            "ring": np.array(ring_col), "cx": cx, "cy": cy, "R": R, "r_or": r_or,
            "hl": (hl_c[1], hl_c[0], hl_r), "sclera_col": np.median(rgb[sclera], axis=0)}


def iris_texture(prof, ring, size=256):
    yy, xx = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    r = np.hypot(xx - c, yy - c) / c                   # 0..1 = full iris radius R (orange ends at 1/1.16)
    ro = r * 1.22
    idx = np.clip((ro * 64).astype(int), 0, 63)
    col = prof[idx]
    col = np.where((ro >= 1.0)[..., None], ring[None, None, :], col)
    pupil = r < 0.3
    col = np.where(pupil[..., None], np.array([0.12, 0.06, 0.04])[None, None, :], col)
    shade = 1 - 0.35 * np.clip((c - yy) / c, 0, 1) ** 1.2            # darker under the upper lid (anime iris)
    col = col * shade[..., None]
    alpha = np.clip((1 - r) * size * 0.5, 0, 1)
    return Image.fromarray((np.dstack([col, alpha]) * 255).clip(0, 255).astype(np.uint8))


def build(face_img, to_px, size, span, parts, FS, Z, T):
    """Cut the eye openings out of the face texture and write the separate part textures + rectangles."""
    eyes = parts["eyes"]
    meta = {"eyes": {}, "brows": {}, "mouth": {}}
    face = np.asarray(face_img).astype(np.float32)
    ex = FS["iod"] / 2
    ze = Z("eye") + FS["eye_dz"]
    m_per_px = span / size
    iris_done = False
    for sx, S, im in ((-1, "R", eyes[0]), (1, "L", eyes[1])):
        rgba = np.asarray(im).astype(np.float32) / 255
        L = split_eye(rgba)
        eh, ew = rgba.shape[:2]
        w = FS["eye_w"]
        k = w / ew                                       # metres per element pixel
        kz = k * FS["eye_squash"]
        x_left = sx * ex - w / 2 - sx * 4 * m_per_px
        z_top = ze + 0.55 * eh * kz
        e2m = lambda px, py: (x_left + px * k, z_top - py * kz)
        # opening hole in the face texture (alpha 0)
        op = Image.fromarray((L["opening"] * 255).astype(np.uint8))
        X0, Y0 = to_px(*e2m(0, 0))
        X1, Y1 = to_px(*e2m(ew, eh))
        opr = np.asarray(op.resize((int(round(X1 - X0)), int(round(Y1 - Y0))), Image.BILINEAR)) / 255.0
        ys, xs = int(round(Y0)), int(round(X0))
        face[ys:ys + opr.shape[0], xs:xs + opr.shape[1], 3] *= (1 - (opr > 0.5))
        # eyeline layer (lash lines) and eye-white layer (opening shape, sclera colour with lid shadow)
        dl = np.zeros((eh, ew, 4), np.float32)
        dl[..., :3] = rgba[..., :3] * 0.6                         # eyeline reads as strongly as the sheet's ink
        dl[..., 3] = ndimage.gaussian_filter(ndimage.binary_dilation(L["dark"], iterations=2).astype(np.float32), 0.8)
        Image.fromarray((dl * 255).astype(np.uint8)).save(os.path.join(T, f"fp_eyeline_{S}.png"))
        wl = np.zeros((eh, ew, 4), np.float32)
        yy = np.arange(eh)[:, None] / eh
        wl[..., :3] = L["sclera_col"][None, None, :] * (0.78 + 0.22 * np.clip((yy - 0.15) / 0.5, 0, 1))[..., None]
        wl[..., 3] = 1.0
        Image.fromarray((wl * 255).astype(np.uint8)).save(os.path.join(T, f"fp_eyewhite_{S}.png"))
        if not iris_done:
            iris_texture(L["prof"], L["ring"]).save(os.path.join(T, "fp_iris.png"))
            hs = 128
            hlim = Image.new("RGBA", (hs, hs), (0, 0, 0, 0))
            ImageDraw.Draw(hlim).ellipse((8, 8, hs - 8, hs - 8), fill=(255, 255, 255, 255))
            hlim.save(os.path.join(T, "fp_highlight.png"))
            iris_done = True
        cxm, czm = e2m(L["cx"], L["cy"])
        hx, hz = e2m(L["hl"][0], L["hl"][1])
        ty, by = np.where(L["opening"].any(axis=1))[0][[0, -1]]
        meta["eyes"][S] = {"rect": [x_left, z_top - eh * kz, x_left + w, z_top], "iris": [cxm, czm, L["R"] * k],
                           "highlight": [hx, hz, L["hl"][2] * k], "open_top": z_top - ty * kz, "open_bot": z_top - by * kz}
    for sx, S, im in ((-1, "R", parts["brows"][0]), (1, "L", parts["brows"][1])):
        w = FS["brow_w"]
        h = im.height * w / im.width
        cx, cz = sx * (ex + FS["brow_dx"]), Z("eye") + FS["brow_dz"]
        im.save(os.path.join(T, f"fp_brow_{S}.png"))
        meta["brows"][S] = {"rect": [cx - w / 2, cz - h / 2, cx + w / 2, cz + h / 2]}
    mim = parts["mouth"]
    w = FS["mouth_w"]
    h = mim.height * w / mim.width
    cz = Z("eye") + FS["mouth_dz"]
    mim.save(os.path.join(T, "fp_mouth.png"))
    meta["mouth"] = {"rect": [-w / 2, cz - h / 2, w / 2, cz + h / 2]}
    # mouth interior (shown by the lip-sync / surprised shapes): dark red with an upper teeth band
    mi = Image.new("RGBA", (128, 64), (88, 34, 34, 255))
    ImageDraw.Draw(mi).rectangle((0, 0, 127, 12), fill=(236, 228, 220, 255))
    mi.save(os.path.join(T, "fp_mouth_inner.png"))
    json.dump(meta, open(os.path.join(T, "face_parts.json"), "w"), indent=1)
    return Image.fromarray(face.clip(0, 255).astype(np.uint8))
