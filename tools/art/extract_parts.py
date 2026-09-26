#!/usr/bin/env python3
"""Cut protagonist parts out of the supplied design sheets into transparent PNGs.

The sheets in assets/protagonist_customization/ are painted on cream paper with ink
outlines. Each part is cropped from a listed box, the paper connected to the crop edge is
flood-filled away (enclosed paint stays), stray neighbours and labels are dropped, and a
1px soft edge is kept. Output PNGs are trimmed; the manifest records every part's sheet
origin so the rig can place parts exactly as they were drawn.

Usage: python3 tools/art/extract_parts.py art/generated/protagonist/v01/parts_spec.json
Needs numpy, pillow, scipy.
"""
import hashlib, json, sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]


def paper_mask(rgb: np.ndarray, paper: np.ndarray, tol: float) -> np.ndarray:
    dist = np.sqrt(((rgb - paper) ** 2).sum(-1))
    sat = rgb.max(-1) - rgb.min(-1)
    return (dist < tol) & (sat < 48)


def sheet_paper(sheet: np.ndarray) -> np.ndarray:
    """Paper colour of a whole sheet: median of its bright, unsaturated pixels."""
    rgb = sheet[::4, ::4].reshape(-1, 3).astype(np.float32)
    light = rgb[(rgb.max(-1) > 200) & (rgb.max(-1) - rgb.min(-1) < 40)]
    return np.median(light, axis=0)


def cut(sheet: np.ndarray, box, tol: float, keep_ratio: float, clip: bool = False, paper=None):
    h, w = sheet.shape[:2]
    m = 8
    x0, y0, x1, y1 = box
    X0, Y0, X1, Y1 = max(0, x0 - m), max(0, y0 - m), min(w, x1 + m), min(h, y1 + m)
    rgb = sheet[Y0:Y1, X0:X1].astype(np.float32)
    if paper is None:
        border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
        paper = np.median(border, axis=0)
    bg = paper_mask(rgb, paper, tol)
    lab, n = ndi.label(bg)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    outside = np.isin(lab, list(edge))
    fg = ~outside
    fg = ndi.binary_opening(fg, iterations=1)
    # Keep the blobs that belong to this part (inside the listed box), drop neighbours/labels.
    lab2, n2 = ndi.label(fg)
    if n2 == 0:
        raise SystemExit(f"empty part at {box}")
    areas = ndi.sum(fg, lab2, range(1, n2 + 1))
    biggest = areas.max()
    inner = np.zeros_like(fg)
    inner[y0 - Y0:y1 - Y0, x0 - X0:x1 - X0] = True
    keep = np.zeros_like(fg)
    for i, a in enumerate(areas, start=1):
        comp = lab2 == i
        if a >= biggest * keep_ratio and (comp & inner).sum() > a * 0.6:
            keep |= comp
    if clip:
        # Neighbouring drawings touch this one (e.g. a row of head turnarounds): hard-cut
        # to the listed box instead of following the paint.
        keep &= inner
    # Close pin-holes the paper test punched inside light paint.
    holes = ndi.binary_fill_holes(keep) & ~keep
    hl, hn = ndi.label(holes)
    if hn:
        hs = ndi.sum(holes, hl, range(1, hn + 1))
        for i, a in enumerate(hs, start=1):
            if a < 260:
                keep |= hl == i
    alpha = ndi.gaussian_filter(keep.astype(np.float32), 0.7)
    alpha = np.clip((alpha - 0.15) / 0.7, 0, 1) * keep.astype(np.float32) + np.clip((alpha - 0.5) * 2, 0, 1) * (~keep)
    ys, xs = np.nonzero(alpha > 0.02)
    ty0, ty1, tx0, tx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)[ty0:ty1, tx0:tx1]
    return rgba, (int(X0 + tx0), int(Y0 + ty0))


def main() -> int:
    spec_path = Path(sys.argv[1])
    spec = json.loads(spec_path.read_text())
    out_dir = ROOT / spec["output"]
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = {"source_sheets": {}, "parts": {}}
    sheets = {}
    papers = {}
    for part in spec["parts"]:
        sheet_name = part.get("sheet", spec["default_sheet"])
        if sheet_name not in sheets:
            p = ROOT / spec["sheet_dir"] / sheet_name
            data = p.read_bytes()
            manifest["source_sheets"][sheet_name] = hashlib.sha256(data).hexdigest()
            sheets[sheet_name] = np.asarray(Image.open(p).convert("RGB"))
            papers[sheet_name] = sheet_paper(sheets[sheet_name])
        rgba, origin = cut(sheets[sheet_name], part["box"], part.get("tol", 34.0), part.get("keep", 0.04), part.get("clip", False), papers[sheet_name] if part.get("clip", False) else None)
        splits = part.get("split")
        pieces = [(part["name"], rgba, origin)]
        if splits:
            # Horizontal cut at a joint; the lower piece reaches up under the upper one.
            y = splits["y"] - origin[1]
            ov = splits.get("overlap", 10)
            pieces = [(part["name"] + "_upper", rgba[:y], origin),
                      (part["name"] + "_lower", rgba[y - ov:], (origin[0], origin[1] + y - ov))]
        for name, img, org in pieces:
            Image.fromarray(img, "RGBA").save(out_dir / f"{name}.png", optimize=True)
            manifest["parts"][name] = {"sheet": sheet_name, "origin": list(org), "size": [img.shape[1], img.shape[0]]}
    (out_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
    print(f"{len(manifest['parts'])} parts -> {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
