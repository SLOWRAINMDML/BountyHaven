"""Score a render set against the illustration and build the side-by-side sheet.

python3 ww_compare.py <iter_dir> "<note>"
-> <iter_dir>/sheet.png, <iter_dir>/score.json
Metrics: silhouette IoU per view (illustration mask vs render alpha, horizontal alignment searched,
vertical fixed by the sole), landmark height error (% of body height) and width error (%) measured
from the evaluated Blender geometry.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
M = os.path.join(ROOT, "measure")
D = sys.argv[1]
NOTE = sys.argv[2] if len(sys.argv) > 2 else ""
PAPER = (236, 230, 218)
try:
    FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 22)
    FONT_S = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 16)
except OSError:
    FONT = FONT_S = ImageFont.load_default()


def ill_mask(im):
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    border = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3)])
    paper = np.median(border, axis=0)
    diff = np.abs(a - paper).max(axis=2)
    dark = a.mean(axis=2) < paper.mean() - 40
    m = (diff > 38) | dark
    m = ndimage.binary_closing(m, iterations=2)
    m = ndimage.binary_fill_holes(m)
    m = ndimage.binary_opening(m, iterations=2)
    lab, n = ndimage.label(m)
    if n:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = lab == (1 + int(np.argmax(sizes)))
    m = ndimage.binary_fill_holes(m)
    # drop the ground shadow strip under the soles
    return m


def iou_search(ill, ren, max_dx=40, max_dy=6):
    best = (0, 0, 0)
    for dy in range(-max_dy, max_dy + 1, 2):
        for dx in range(-max_dx, max_dx + 1, 1):
            r = np.roll(np.roll(ren, dy, 0), dx, 1)
            inter = (ill & r).sum()
            uni = (ill | r).sum()
            v = inter / max(uni, 1)
            if v > best[0]:
                best = (v, dx, dy)
    return best


views = ["front", "q34", "side", "back"]
rows = []
scores = {}
for v in views:
    ill = Image.open(os.path.join(M, f"ill_{v}.png")).convert("RGB")
    ren = Image.open(os.path.join(D, f"view_{v}.png")).convert("RGBA").resize(ill.size, Image.LANCZOS)
    im_ill = ill_mask(ill)
    im_ren = np.asarray(ren)[..., 3] > 128
    iou, dx, dy = iou_search(im_ill, im_ren)
    scores[v] = {"iou": round(float(iou), 4), "dx": dx, "dy": dy}
    big = (ill.width * 2, ill.height * 2)
    ren2 = Image.open(os.path.join(D, f"view_{v}.png")).convert("RGBA")
    ren2 = Image.fromarray(np.roll(np.roll(np.asarray(ren2), dy * 2, 0), dx * 2, 1))
    comp = Image.new("RGBA", ren2.size, (*PAPER, 255))
    comp.alpha_composite(ren2)
    # overlay: illustration contour on the render
    edge = ndimage.binary_dilation(im_ill, iterations=1) ^ ndimage.binary_erosion(im_ill, iterations=1)
    edge_im = Image.fromarray((edge * 255).astype(np.uint8)).resize(big, Image.NEAREST)
    ov = comp.copy()
    ov.paste((230, 0, 150, 255), (0, 0), edge_im)
    rows.append((v, ill.resize(big, Image.LANCZOS), comp.convert("RGB"), ov.convert("RGB")))

lm = json.load(open(os.path.join(D, "landmarks_3d.json")))
H = 1.78
h_err, w_err = {}, {}
for k in ("hair_top", "skull_top", "eye", "chin", "fingertip", "waist", "crotch", "knee", "sole"):
    h_err[k] = round(abs(lm["model"][k] - lm["target"][k]) / H * 100, 2)
for k in ("face_w", "hair_w", "shoulder_w", "feet_span"):
    w_err[k] = round(abs(lm["model"][k] - lm["target"][k]) / lm["target"][k] * 100, 1)
mean_iou = float(np.mean([scores[v]["iou"] for v in views]))
score = {"iou": scores, "mean_iou": round(mean_iou, 4), "height_err_pct": h_err,
         "mean_height_err_pct": round(float(np.mean(list(h_err.values()))), 3),
         "width_err_pct": w_err, "mean_width_err_pct": round(float(np.mean(list(w_err.values()))), 2), "note": NOTE}
json.dump(score, open(os.path.join(D, "score.json"), "w"), indent=1, ensure_ascii=False)

# ----------------------------------------------------------------------------- sheet
pad = 16
col_w = [max(r[1].width for r in rows)] * 3
row_h = rows[0][1].height
body_w = sum(r[1].width for r in rows) * 3 + pad * (len(rows) * 3 + 1)
face_h = 420
W = body_w
Hh = 90 + row_h + 50 + face_h + 60
sheet = Image.new("RGB", (W, Hh), (246, 243, 236))
d = ImageDraw.Draw(sheet)
it = os.path.basename(os.path.normpath(D))
d.text((pad, 14), f"{it} — {NOTE}", fill=(40, 30, 25), font=FONT)
d.text((pad, 46), "IoU  " + "  ".join(f"{v}:{scores[v]['iou']:.3f}" for v in views)
       + f"   mean {mean_iou:.3f}   | height err {score['mean_height_err_pct']:.2f}% H   | width err {score['mean_width_err_pct']:.1f}%",
       fill=(90, 60, 40), font=FONT_S)
x = pad
for v, a, b, c in rows:
    for lab, im in (("illustration", a), ("3D", b), ("overlay", c)):
        sheet.paste(im, (x, 90))
        d.text((x + 4, 92 + row_h + 4), f"{v} · {lab}", fill=(70, 60, 50), font=FONT_S)
        x += im.width + pad
# faces
y = 90 + row_h + 40
ill_front = Image.open(os.path.join(M, "ill_front.png")).crop((70, 0, 180, 110)).resize((face_h, face_h), Image.LANCZOS)
tiles = [("illustration face", ill_front)]
cf = os.path.join(ROOT, "concepts", "02_ww_face.png")
if os.path.exists(cf):
    c = Image.open(cf).convert("RGB")
    tiles.append(("codex style target", c.crop((0, 0, c.width // 3, c.width // 3)).resize((face_h, face_h), Image.LANCZOS)))
for n in ("face_front", "face_q34"):
    p = os.path.join(D, n + ".png")
    if os.path.exists(p):
        f = Image.open(p).convert("RGBA")
        bg = Image.new("RGBA", f.size, (*PAPER, 255))
        bg.alpha_composite(f)
        tiles.append(("3D " + n.split("_")[1], bg.convert("RGB").resize((face_h, face_h), Image.LANCZOS)))
vfx = os.path.join(D, "vfx.png")
if os.path.exists(vfx):
    f = Image.open(vfx).convert("RGB")
    tiles.append(("VFX shot", f.resize((int(face_h * f.width / f.height), face_h), Image.LANCZOS)))
x = pad
for lab, im in tiles:
    if x + im.width > W:
        break
    sheet.paste(im, (x, y))
    d.text((x + 4, y + face_h + 4), lab, fill=(70, 60, 50), font=FONT_S)
    x += im.width + pad
sheet.save(os.path.join(D, "sheet.png"))
print(json.dumps({"mean_iou": score["mean_iou"], "h": score["mean_height_err_pct"], "w": score["mean_width_err_pct"],
                  "views": {v: scores[v]["iou"] for v in views}, "w_err": w_err, "h_err": h_err}))
