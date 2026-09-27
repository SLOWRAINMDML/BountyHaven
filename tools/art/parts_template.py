#!/usr/bin/env python3
"""Render the per-view parts template: every slot of the captain rig laid out once with its
file name, pivot dot and rig-pixel scale, next to the assembled front pose. Attach it with
the cutout sheet when generating a new view so the new parts keep the same names, scale
and joint overlaps. Usage: parts_template.py <rig.json> <out.png>"""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]


def font(size):
    for path in ["/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
                 "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    rig = json.loads(Path(sys.argv[1]).read_text())
    out = Path(sys.argv[2])
    root = ROOT / rig["part_root"].replace("res://", "")
    view = rig["views"][0]
    parts = []
    for slot in rig["slots"]:
        att = rig["skins"]["default"][slot["name"]][slot["attachment"]][view]
        img = Image.open(root / att["image"]).convert("RGBA")
        pivot = list(att["pivot"])
        if att.get("region"):
            x, y, w, h = att["region"]
            img = img.crop((x, y, x + w, y + h))
        sx, sy = att.get("scale", [1, 1])
        if (sx, sy) != (1, 1):
            img = img.resize((max(1, round(img.width * sx)), max(1, round(img.height * sy))), Image.LANCZOS)
            pivot = [pivot[0] * sx, pivot[1] * sy]
        parts.append((slot["name"], img, pivot))
    cols, cell_w, cell_h, pad = 5, 250, 290, 24
    rows = (len(parts) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w + 2 * pad, rows * cell_h + 164), (236, 232, 218))
    draw = ImageDraw.Draw(sheet)
    title, small = font(30), font(20)
    draw.text((pad, 20), "BountyHaven captain rig: one PNG per part, file name = label", fill=(41, 73, 80), font=title)
    draw.text((pad, 60), "Same pixel scale as the cutout sheet (full body about 660 px). Red dot = joint pivot. Transparent background, 8 px margin.",
              fill=(90, 110, 108), font=small)
    draw.text((pad, 84), "Extend limb ends past the joint so bends leave no gaps.", fill=(90, 110, 108), font=small)
    draw.text((pad, 108), "Side and three-quarter views face screen-right; the character's LEFT limbs (_l) are nearest the camera.",
              fill=(168, 72, 58), font=small)
    for i, (name, img, pivot) in enumerate(parts):
        cx = pad + (i % cols) * cell_w
        cy = 144 + (i // cols) * cell_h
        draw.rectangle([cx + 6, cy + 6, cx + cell_w - 6, cy + cell_h - 6], outline=(188, 198, 183))
        fit = min(1.0, (cell_w - 30) / img.width, (cell_h - 60) / img.height)
        shown = img if fit == 1.0 else img.resize((round(img.width * fit), round(img.height * fit)), Image.LANCZOS)
        ox = cx + (cell_w - shown.width) // 2
        oy = cy + 12 + (cell_h - 60 - shown.height) // 2
        sheet.paste(shown, (ox, oy), shown)
        px, py = ox + pivot[0] * fit, oy + pivot[1] * fit
        draw.ellipse([px - 5, py - 5, px + 5, py + 5], fill=(200, 50, 40))
        note = f"{name}.png" + ("" if fit == 1.0 else f"  (shown {fit:.0%})")
        draw.text((cx + 14, cy + cell_h - 42), note, fill=(41, 73, 80), font=small)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"wrote {out} ({sheet.width}x{sheet.height}, {len(parts)} parts)")


if __name__ == "__main__":
    main()
