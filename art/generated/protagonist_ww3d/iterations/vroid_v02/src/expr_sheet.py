"""Expression board: illustration expression-sheet tiles vs the 3D VRM preset expressions.

python3 expr_sheet.py <dir>  -> <dir>/expr_sheet.png
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
D = sys.argv[1]
src = Image.open(os.path.join(REPO, "assets", "protagonist_customization", "바운티헤이븐_주인공_표정_시트.png")).convert("RGB")
s = src.width / 1024
TILES = {"NEUTRAL": (375, 95), "FOCUSED": (530, 95), "GENTLE SMILE": (690, 95), "DETERMINED": (850, 95),
         "SKEPTICAL": (375, 270), "AMUSED": (530, 270), "TIRED": (690, 270), "WORRIED": (850, 270),
         "SURPRISED": (375, 445), "BATTLE-READY": (530, 445), "SIDE GLANCE": (690, 445), "SOFT": (850, 445)}
PAIRS = [("neutral", "NEUTRAL"), ("happy", "GENTLE SMILE"), ("angry", "DETERMINED"), ("sad", "WORRIED"),
         ("surprised", "SURPRISED"), ("relaxed", "TIRED"), ("blinkRight", "AMUSED"), ("aa", None), ("oh", None),
         ("ih", None), ("ou", None), ("ee", None)]
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 18)
T = 230
cols = 6
rows_ = (len(PAIRS) + cols - 1) // cols
board = Image.new("RGB", (cols * (T + 12) + 12, rows_ * (2 * T + 70) + 10), (246, 243, 236))
d = ImageDraw.Draw(board)
for i, (expr, tile) in enumerate(PAIRS):
    cx = 12 + (i % cols) * (T + 12)
    cy = 10 + (i // cols) * (2 * T + 70)
    if tile:
        x, y = TILES[tile]
        im = src.crop((int(x * s), int(y * s), int((x + 145) * s), int((y + 150) * s))).resize((T, T), Image.LANCZOS)
        board.paste(im, (cx, cy + 22))
        d.text((cx, cy), tile.lower(), fill=(90, 60, 40), font=font)
    else:
        d.text((cx, cy), "(lip sync)", fill=(150, 130, 120), font=font)
    r = Image.open(os.path.join(D, f"expr_{expr}.png")).convert("RGBA")
    bg = Image.new("RGBA", r.size, (236, 230, 218, 255))
    bg.alpha_composite(r)
    r = bg.convert("RGB")
    r = r.crop((int(r.width * 0.2), int(r.height * 0.12), int(r.width * 0.8), int(r.height * 0.72))).resize((T, T), Image.LANCZOS)
    board.paste(r, (cx, cy + 22 + T + 24))
    d.text((cx, cy + 22 + T + 2), "3D: " + expr, fill=(40, 30, 25), font=font)
board.save(os.path.join(D, "expr_sheet.png"))
print("ok")
