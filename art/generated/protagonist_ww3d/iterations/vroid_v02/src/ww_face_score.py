"""Face-only scoring: illustration face crops vs 3D face close-ups.

python3 ww_face_score.py <iter_dir> "<note>"  -> <iter_dir>/face_sheet.png, face_score.json
Per view (front / q34 / side):
  * the render is aligned to the illustration by the eye pair (front, q34: similarity) or by eye + ear
    distance (side: eye + chin similarity; the rotation absorbs head pitch);
  * landmark error = mean distance of the other landmarks (brow, nose, mouth corners, chin, ear) in % of the
    reference inter-ocular distance (front, q34) or eye-chin distance (side);
  * outline IoU = skin-region IoU (HSV skin mask) above the chin line, after the same alignment.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MF = os.path.join(ROOT, "measure", "face")
D = sys.argv[1]
NOTE = sys.argv[2] if len(sys.argv) > 2 else ""
REF = json.load(open(os.path.join(MF, "face_landmarks.json")))
M3 = json.load(open(os.path.join(D, "face_landmarks_3d.json")))
PAPER = (236, 230, 218)
try:
    FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
    FS_ = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 15)
except OSError:
    FONT = FS_ = ImageFont.load_default()

# reference name -> model landmark name
PAIRS = {"front": {"eye_r": "eye_r", "eye_l": "eye_l", "brow_r": "brow_r", "brow_l": "brow_l", "nose": "nose",
                   "mouth": "mouth", "mouth_rc": "mouth_rc", "mouth_lc": "mouth_lc", "chin": "chin"},
         "q34": {"eye_far": "eye_r", "eye_near": "eye_l", "nose": "nose", "mouth": "mouth", "chin": "chin", "ear": "ear"},
         "side": {"eye": "eye_l", "nose": "nose", "mouth": "mouth", "chin": "chin", "ear": "ear"}}
ALIGN = {"front": ("eye_r", "eye_l"), "q34": ("eye_far", "eye_near"), "side": ("eye", "chin")}


def skin_mask(im):
    hsv = np.asarray(im.convert("RGB").convert("HSV")).astype(np.float32)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    m = (h > 5) & (h < 30) & (s > 45) & (s < 175) & (v > 125)
    m = ndimage.binary_opening(m, iterations=1)
    m = ndimage.binary_closing(m, iterations=2)
    lab, n = ndimage.label(m)
    if n:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = lab == (1 + int(np.argmax(sizes)))
    return ndimage.binary_fill_holes(m)


def similarity(view, ref, mod):
    a1, a2 = ALIGN[view]
    r1, r2 = complex(*ref[a1]), complex(*ref[a2])
    m1, m2 = complex(*mod[PAIRS[view][a1]]), complex(*mod[PAIRS[view][a2]])
    a = (r2 - r1) / (m2 - m1)                    # similarity; for the profile the rotation absorbs head pitch
    b = r1 - a * m1
    return a, b


rows, score = [], {}
for view in ("front", "q34", "side"):
    ref = REF[view]
    mod = M3[view]
    rim = Image.open(os.path.join(MF, f"ref_{view}.png")).convert("RGB")
    ren = Image.open(os.path.join(D, f"fface_{view}.png")).convert("RGBA")
    bg = Image.new("RGBA", ren.size, (*PAPER, 255))
    bg.alpha_composite(ren)
    ren = bg.convert("RGB")
    a, b = similarity(view, ref, mod)
    A, B = 1 / a, -b / a
    W, H = rim.size
    k = 4                                            # supersample the aligned render
    data = (A.real / k, -A.imag / k, B.real, A.imag / k, A.real / k, B.imag) if isinstance(A, complex) else \
        (A / k, 0, B.real, 0, A / k, B.imag)
    aligned = ren.transform((W * k, H * k), Image.AFFINE, data, resample=Image.BICUBIC, fillcolor=PAPER)
    al_small = aligned.resize((W, H), Image.LANCZOS)
    scale = abs(complex(*ref[ALIGN[view][1]]) - complex(*ref[ALIGN[view][0]]))
    errs = {}
    for rn, mn in PAIRS[view].items():
        if rn in ALIGN[view]:
            continue
        p = a * complex(*mod[mn]) + b
        errs[rn] = round(abs(p - complex(*ref[rn])) / scale * 100, 1)
    chin_y = ref["chin"][1] + 0.12 * scale
    sm_r, sm_m = skin_mask(rim), skin_mask(al_small)
    sm_r[int(chin_y):] = False
    sm_m[int(chin_y):] = False
    iou = (sm_r & sm_m).sum() / max((sm_r | sm_m).sum(), 1)

    def lit_skin(im, m):
        px = np.asarray(im.convert("RGB"))[m].astype(np.float32)
        lum = px.mean(axis=1)
        return np.median(px[lum > np.percentile(lum, 70)], axis=0) if len(px) else np.zeros(3)
    col_err = float(np.linalg.norm(lit_skin(rim, sm_r) - lit_skin(al_small, sm_m)))
    score[view] = {"lm_err_pct": errs, "mean_lm_err_pct": round(float(np.mean(list(errs.values()))), 2),
                   "skin_iou": round(float(iou), 4), "skin_color_err": round(col_err, 1)}
    # tiles
    Z = 520 / H
    T = (int(W * Z), 520)
    t_ref = rim.resize(T, Image.LANCZOS)
    t_mod = aligned.resize(T, Image.LANCZOS)
    t_ov = t_mod.copy()
    d = ImageDraw.Draw(t_ov)
    edge = ndimage.binary_dilation(sm_r, iterations=1) ^ ndimage.binary_erosion(sm_r, iterations=1)
    t_ov.paste((230, 0, 150), (0, 0), Image.fromarray((edge * 255).astype(np.uint8)).resize(T, Image.NEAREST))
    for rn, mn in PAIRS[view].items():
        rx, ry = ref[rn]
        p = a * complex(*mod[mn]) + b
        d.ellipse((rx * Z - 5, ry * Z - 5, rx * Z + 5, ry * Z + 5), outline=(230, 0, 150), width=2)
        d.ellipse((p.real * Z - 4, p.imag * Z - 4, p.real * Z + 4, p.imag * Z + 4), fill=(0, 170, 255))
        d.line([(rx * Z, ry * Z), (p.real * Z, p.imag * Z)], fill=(0, 170, 255), width=2)
    rows.append((view, t_ref, t_mod, t_ov))

lm = float(np.mean([score[v]["mean_lm_err_pct"] for v in score]))
iou = float(np.mean([score[v]["skin_iou"] for v in score]))
ce = float(np.mean([score[v]["skin_color_err"] for v in score]))
out = {"views": score, "mean_lm_err_pct": round(lm, 2), "mean_skin_iou": round(iou, 4), "skin_color_err": round(ce, 1), "note": NOTE,
       "mesh": M3.get("mesh", {})}
json.dump(out, open(os.path.join(D, "face_score.json"), "w"), indent=1, ensure_ascii=False)

pad = 14
Wt = sum(t.width for r in rows for t in r[1:]) + pad * (len(rows) * 3 + 1)
sheet = Image.new("RGB", (Wt, 520 + 110), (246, 243, 236))
d = ImageDraw.Draw(sheet)
d.text((pad, 10), f"{os.path.basename(os.path.normpath(D))} — {NOTE}", fill=(40, 30, 25), font=FONT)
d.text((pad, 40), f"landmark err {lm:.1f}% (of IOD / eye-chin)   skin-outline IoU {iou:.3f}   skin colour err {ce:.0f} (RGB)   | " +
       "  ".join(f"{v}: {score[v]['mean_lm_err_pct']:.1f}% / {score[v]['skin_iou']:.3f}" for v in score),
       fill=(90, 60, 40), font=FS_)
x = pad
for view, a_, b_, c_ in rows:
    for lab, im in (("illustration", a_), ("3D (aligned by eyes)", b_), ("overlay: pink = illustration", c_)):
        sheet.paste(im, (x, 70))
        d.text((x + 2, 70 + 520 + 6), f"{view} · {lab}", fill=(70, 60, 50), font=FS_)
        x += im.width + pad
sheet.save(os.path.join(D, "face_sheet.png"))
print(json.dumps({"lm": round(lm, 2), "iou": round(iou, 4), "col": round(ce, 1), **{v: (score[v]["mean_lm_err_pct"], score[v]["skin_iou"]) for v in score}}))
