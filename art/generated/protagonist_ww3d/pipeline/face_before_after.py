"""Before/after face board: illustration | face_iter00 | face_iter10 for front, 3/4 and side (aligned by the eyes)."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
IT = os.path.join(os.path.dirname(HERE), "iterations")
first, last = sys.argv[1] if len(sys.argv) > 1 else "face_iter00", sys.argv[2] if len(sys.argv) > 2 else "face_iter10"
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 22)
tiles = []
for k, view in enumerate(("front", "q34", "side")):
    row = []
    for name in (first, last):
        sheet = Image.open(os.path.join(IT, name, "face_sheet.png"))
        row.append(sheet)
    tiles.append(row)
# the face sheets hold [ref, 3D aligned, overlay] per view at 520 px height from y=70; cut them by width ratios
out = []
for name in (first, last):
    sh = Image.open(os.path.join(IT, name, "face_sheet.png")).convert("RGB")
    out.append(sh)
W = 3
refs, before, after = [], [], []
for sh, store in ((out[0], before), (out[1], after)):
    x = 14
    widths = []
    ref_w = {"front": 184, "q34": 311, "side": 155}
    hts = {"front": 198, "q34": 368, "side": 135}
    for view in ("front", "q34", "side"):
        tw = int(ref_w[view] * 520 / hts[view])
        r = sh.crop((x, 70, x + tw, 590)); x += tw + 14
        m = sh.crop((x, 70, x + tw, 590)); x += tw + 14
        x += tw + 14
        store.append((view, r, m))
cols = [("illustration", [b[1] for b in before]), (first, [b[2] for b in before]), (last, [a[2] for a in after])]
total_w = sum(t.width for t in cols[0][1]) + 14 * 4
board = Image.new("RGB", (total_w, 3 * 520 + 3 * 40 + 20), (246, 243, 236))
d = ImageDraw.Draw(board)
y = 10
for lab, ims in cols:
    x = 14
    d.text((14, y), lab, fill=(60, 40, 30), font=font)
    for im in ims:
        board.paste(im, (x, y + 32)); x += im.width + 14
    y += 520 + 40
board.save(os.path.join(IT, last, "face_before_after.png"))
print("ok")
