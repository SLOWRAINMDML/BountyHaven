#!/usr/bin/env python3
"""Define the protagonist cutout rig and render previews.

Each node names a part PNG (optionally a sub-region), a joint position in rig space
(origin = ground between the feet, y down, units = sheet pixels) and a pivot in the part's
own pixels. The rig is written to rig.json for Godot (scripts/world/paper_doll.gd) and
rendered here at rest and mid-stride next to the sheet's assembled reference.
"""
import json, math, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PARTS = ROOT / "assets/generated/protagonist/v01/parts"
OUT = ROOT / "assets/generated/protagonist/v01/rig.json"

# name: part, region [x,y,w,h] or None, joint (rig space), pivot (part px), parent, z
# Optional horizontal scale per node (the sheet drew the separate leg pieces slimmer
# than the assembled reference).
SCALE_X = {"thigh_l": 1.18, "thigh_r": 1.18, "shin_l": 1.15, "shin_r": 1.15}

# Hair-sheet heads are drawn smaller and cut at the neck: bottom-centre pivot, scaled so
# the face height matches the cutout head.
HEAD_SCALE = 1.3
HEAD_JOINT_Y = -534
HAIR_HEADS = ["hair_01_tousled", "hair_02_tidy_crop", "hair_03_windswept", "hair_04_layered_shag",
              "hair_05_side_part", "hair_06_undercut", "hair_07_tied_low", "hair_08_tied_high",
              "hair_09_travel_braid", "hair_10_braided_tail", "hair_11_half_up", "hair_12_messy_long",
              "hair_13_rough_wild", "hair_14_scruffy", "hair_15_rebellious", "hair_16_rugged"]

# Optional gear: (name, part, parent node, pivot position in rig space, pivot px, z, scale, rotation)
ATTACHMENTS = [
    ("goggles", "goggles", "head", (0, -632), (47, 23), 55, 0.62, 0.0),
    ("cap", "cap", "head", (0, -628), (44, 40), 56, 1.0, 0.0),
    ("satchel", "satchel_side", "hips", (-74, -352), (34, 10), 33, 0.8, 0.0),
    ("charm", "compass_charm", "hips", (40, -360), (16, 4), 42, 0.7, 0.0),
]
NODES = [
    ("hips",     "pelvis_front", None,              (0, -372),  (60, 10),  "",       30),
    ("cloak",    "cloak_c",      None,              (44, -508), (52, 8),   "chest",  0),
    ("thigh_l",  "thigh_l",      None,              (-30, -340),(35, 14),  "hips",   22),
    ("shin_l",   "shin_l",       None,              (-31, -196),(28, 10),  "thigh_l",20),
    ("boot_l",   "boot_l",       None,              (-34, -92), (38, 12),  "shin_l", 24),
    ("thigh_r",  "thigh_r",      None,              (30, -340), (33, 14),  "hips",   22),
    ("shin_r",   "shin_r",       None,              (31, -196), (27, 10),  "thigh_r",20),
    ("boot_r",   "boot_r",       None,              (34, -92),  (36, 12),  "shin_r", 24),
    ("chest",    "torso_front",  [0, 0, 161, 190],  (0, -372),  (80, 152), "hips",   40),
    ("fore_l",   "arm_l",        [0, 88, 59, 122],  (-72, -392),(30, 96),  "arm_l",  35),
    ("arm_l",    "arm_l",        [0, 0, 59, 104],   (-68, -500),(30, -12), "chest",  36),
    ("fore_r",   "arm_r",        [0, 88, 54, 121],  (72, -392), (27, 96),  "arm_r",  35),
    ("arm_r",    "arm_r",        [0, 0, 54, 104],   (68, -500), (27, -12), "chest",  36),
    ("scarf",    "neckwrap_front",None,             (0, -518),  (73, 22),  "chest",  52),
    ("head",     "head_front",   None,              (0, -512),  (57, 128), "chest",  50),
]


def render(pose: dict, scale: float = 1.0, head: str = "", gear=()) -> Image.Image:
    world = {}
    canvas = Image.new("RGBA", (420, 720), (24, 38, 48, 255))
    origin = (210, 690)
    by_name = {n[0]: n for n in NODES}

    def xform(name):
        if name in world:
            return world[name]
        node = by_name[name]
        joint = node[3]
        parent = node[5]
        if not parent:
            wx, wy, wr = joint[0], joint[1], pose.get(name, 0.0)
        else:
            px, py, pr = xform(parent)
            pj = by_name[parent][3]
            dx, dy = joint[0] - pj[0], joint[1] - pj[1]
            c, s = math.cos(pr), math.sin(pr)
            wx, wy = px + dx * c - dy * s, py + dx * s + dy * c
            wr = pr + pose.get(name, 0.0)
        world[name] = (wx, wy, wr)
        return world[name]

    draw = [(n, None) for n in NODES]
    for a in ATTACHMENTS:
        if a[0] in gear:
            draw.append(((a[0], a[1], None, a[3], a[4], a[2], a[5]), a))
    for node, att in sorted(draw, key=lambda d: d[0][6]):
        name, part, region, joint, pivot, parent, z = node
        if name == "head" and head:
            part = head
        img = Image.open(PARTS / f"{part}.png")
        if name == "head" and head:
            img = img.resize((int(img.width * HEAD_SCALE), int(img.height * HEAD_SCALE)), Image.LANCZOS)
            # Sprite offset inside the head node: its bottom sits at HEAD_JOINT_Y.
            pivot = (img.width / 2, img.height - (HEAD_JOINT_Y - joint[1]))
        if att:
            sc = att[6]
            img = img.resize((max(1, int(img.width * sc)), max(1, int(img.height * sc))), Image.LANCZOS)
            pivot = (pivot[0] * sc, pivot[1] * sc)
            # Attachments ride on their parent's transform.
            px, py, pr = xform(parent)
            pj = by_name[parent][3]
            dx, dy = joint[0] - pj[0], joint[1] - pj[1]
            c_, s_ = math.cos(pr), math.sin(pr)
            world[name] = (px + dx * c_ - dy * s_, py + dx * s_ + dy * c_, pr + att[7])
        if region:
            x, y, w, h = region
            img = img.crop((x, y, x + w, y + h))
            pivot = (pivot[0] - x, pivot[1] - y)
        sx = SCALE_X.get(name, 1.0)
        if sx != 1.0:
            img = img.resize((int(img.width * sx), img.height), Image.LANCZOS)
            pivot = (pivot[0] * sx, pivot[1])
        wx, wy, wr = xform(name)
        # Rotate about the pivot: pad so the pivot is the image centre, then rotate.
        pw = max(pivot[0], img.width - pivot[0]); ph = max(pivot[1], img.height - pivot[1])
        pad = Image.new("RGBA", (int(pw * 2), int(ph * 2)), (0, 0, 0, 0))
        pad.alpha_composite(img, (int(pw - pivot[0]), int(ph - pivot[1])))
        rot = pad.rotate(-math.degrees(wr), resample=Image.BICUBIC, expand=True)
        canvas.alpha_composite(rot, (int(origin[0] + wx - rot.width / 2), int(origin[1] + wy - rot.height / 2)))
    return canvas


def main() -> int:
    rig = {"version": 1, "units": "sheet_px", "origin": "ground between feet", "nodes": []}
    for name, part, region, joint, pivot, parent, z in NODES:
        rig["nodes"].append({"name": name, "part": part, "region": region, "joint": list(joint), "pivot": list(pivot), "parent": parent, "z": z, "scale_x": SCALE_X.get(name, 1.0)})
    rig["hair_heads"] = HAIR_HEADS
    rig["head_scale"] = HEAD_SCALE
    rig["head_joint_y"] = HEAD_JOINT_Y
    rig["attachments"] = [{"name": a[0], "part": a[1], "parent": a[2], "joint": list(a[3]), "pivot": list(a[4]), "z": a[5], "scale": a[6], "rotation": a[7]} for a in ATTACHMENTS]
    OUT.write_text(json.dumps(rig, indent=1))
    ref = Image.open(PARTS / "ref_assembled.png")
    rest = render({}, head="hair_01_tousled", gear=("goggles", "satchel", "charm"))
    stride = render(head="hair_08_tied_high", gear=("cap",), pose={"thigh_l": 0.2, "shin_l": -0.15, "thigh_r": -0.12, "shin_r": 0.05, "arm_l": -0.18, "fore_l": -0.15, "arm_r": 0.18, "fore_r": -0.2, "head": 0.03}, )
    sheet = Image.new("RGBA", (420 * 3, 720), (24, 38, 48, 255))
    sheet.alpha_composite(ref, (210 - ref.width // 2, 690 - 638))
    sheet.alpha_composite(rest, (420, 0))
    sheet.alpha_composite(stride, (840, 0))
    sheet.convert("RGB").save(sys.argv[1] if len(sys.argv) > 1 else "/tmp/rig_preview.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
