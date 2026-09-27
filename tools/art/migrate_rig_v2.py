#!/usr/bin/env python3
"""One-time migration of the v01 paper-doll rig into the skeletal rig format (v2).

The v2 file is owned by the in-game rig editor afterwards (`-- --rig-editor`); rerunning
this script overwrites the editor's work, so it refuses unless --force is given.

Format summary (see docs/art/RIG_FORMAT.md):
  bones      name, parent, length, setup{view: {x, y, rotation, scale_x, scale_y}}
  slots      name, bone, dye, z{view: int}
  skins      default[slot][attachment][view] = {image, pivot, rotation, scale, region?}
  animations clip = {duration, loop, tracks{view|"*": {bone: {rotate|translate|scale: keys}}}}
Units are rig pixels, origin = ground between the feet, y points down, angles in degrees.
"""
import json, math, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
V1 = ROOT / "assets/generated/protagonist/v01/rig.json"
PART_ROOT = "res://assets/generated/protagonist/"
PARTS = ROOT / "assets/generated/protagonist/v01/parts"
OUT = ROOT / "assets/characters/captain/captain.rig.json"
VIEW = "front"


def r2(v):
    return round(float(v), 3)


def main():
    if OUT.exists() and "--force" not in sys.argv:
        sys.exit(f"{OUT} exists (edited in the rig editor?). Pass --force to overwrite.")
    v1 = json.loads(V1.read_text())
    entries = [dict(n) for n in v1["nodes"]]
    for a in v1["attachments"]:
        e = dict(a)
        e["region"] = None
        e["scale_x"] = e.get("scale", 1.0)
        e["scale_y"] = e.get("scale", 1.0)
        entries.append(e)
    joints = {e["name"]: e["joint"] for e in entries}
    bones = [{"name": "root", "parent": "", "length": 0,
              "setup": {VIEW: {"x": 0, "y": 0, "rotation": 0, "scale_x": 1, "scale_y": 1}}}]
    # Parents must precede children in the bone list.
    pending = list(entries)
    placed = {"root"}
    while pending:
        for e in list(pending):
            parent = e["parent"] or "root"
            if parent not in placed:
                continue
            pj = joints.get(parent, (0, 0))
            child_len = [c for c in entries if c["parent"] == e["name"]]
            length = 0
            if child_len:
                c = child_len[0]["joint"]
                length = round(math.dist(c, e["joint"]))
            bones.append({"name": e["name"], "parent": parent, "length": length,
                          "setup": {VIEW: {"x": e["joint"][0] - pj[0], "y": e["joint"][1] - pj[1],
                                           "rotation": r2(math.degrees(e.get("rotation", 0.0))),
                                           "scale_x": 1, "scale_y": 1}}})
            placed.add(e["name"])
            pending.remove(e)
    # Attachment names equal slot names so per-view art can be dropped in as
    # views/<view>/<slot>.png; hairstyles keep their own names in the head slot.
    custom = {"hair_slot": "head", "base_head": "head",
              "gear_slots": ["scarf", "cloak", "goggles", "cap", "satchel", "charm"],
              "dye_slots": ["scarf", "cloak"]}
    slots, skin = [], {}
    for e in sorted(entries, key=lambda e: e["z"]):
        slots.append({"name": e["name"], "bone": e["name"], "attachment": e["name"],
                      "dye": e["name"] in custom["dye_slots"], "z": {VIEW: e["z"]}})
        pivot = list(e["pivot"])
        att = {"image": f"v01/parts/{e['part']}.png", "rotation": 0,
               "scale": [r2(e.get("scale_x", 1.0)), r2(e.get("scale_y", 1.0))]}
        if e.get("region"):
            att["region"] = e["region"]
            pivot = [pivot[0] - e["region"][0], pivot[1] - e["region"][1]]
        att["pivot"] = pivot
        skin[e["name"]] = {e["name"]: {VIEW: att}}
    head_joint = joints["head"]
    lift = v1["head_joint_y"] - head_joint[1]
    hs = v1["head_scale"]
    for hair in v1["hair_heads"]:
        w, h = Image.open(PARTS / f"{hair}.png").size
        skin["head"][hair] = {VIEW: {"image": f"v01/parts/{hair}.png", "rotation": 0,
                                     "scale": [hs, hs], "pivot": [r2(w * 0.5), r2(h - lift / hs)]}}

    def deg(x):
        return r2(math.degrees(x))

    def sampled(duration, steps, fn):
        return [[r2(duration * k / steps), deg(fn(2 * math.pi * k / steps)), "smooth"] for k in range(steps + 1)]

    def translated(duration, steps, fn):
        return [[r2(duration * k / steps), 0, r2(fn(2 * math.pi * k / steps)), "smooth"] for k in range(steps + 1)]

    T = 2 * math.pi / 8.5
    s = math.sin
    walk = {
        "thigh_l": {"rotate": sampled(T, 8, lambda p: 0.2 * s(p))},
        "thigh_r": {"rotate": sampled(T, 8, lambda p: -0.2 * s(p))},
        "shin_l": {"rotate": sampled(T, 8, lambda p: 0.22 * max(0, -s(p)))},
        "shin_r": {"rotate": sampled(T, 8, lambda p: 0.22 * max(0, s(p)))},
        "boot_l": {"rotate": sampled(T, 8, lambda p: -0.1 * max(0, -s(p)))},
        "boot_r": {"rotate": sampled(T, 8, lambda p: -0.1 * max(0, s(p)))},
        "arm_l": {"rotate": sampled(T, 8, lambda p: -0.17 * s(p))},
        "arm_r": {"rotate": sampled(T, 8, lambda p: -0.17 * s(p))},
        "fore_l": {"rotate": sampled(T, 8, lambda p: -0.1 - 0.08 * abs(s(p)))},
        "fore_r": {"rotate": sampled(T, 8, lambda p: -0.1 - 0.08 * abs(s(p)))},
        "chest": {"rotate": sampled(T, 8, lambda p: 0.015 * s(p))},
        "head": {"rotate": sampled(T, 8, lambda p: 0.012 * s(p + 0.6))},
        "cloak": {"rotate": sampled(T, 8, lambda p: 0.05 + 0.06 * s(p - 0.8))},
        "satchel": {"rotate": sampled(T, 8, lambda p: 0.12 * s(p - 0.5))},
        "charm": {"rotate": sampled(T, 8, lambda p: 0.2 * s(p - 0.7))},
        "hips": {"translate": translated(T, 8, lambda p: -abs(math.cos(p)) * 9)},
    }
    R = 0.52
    run = {
        "thigh_l": {"rotate": sampled(R, 8, lambda p: 0.32 * s(p))},
        "thigh_r": {"rotate": sampled(R, 8, lambda p: -0.32 * s(p))},
        "shin_l": {"rotate": sampled(R, 8, lambda p: 0.4 * max(0, -s(p)))},
        "shin_r": {"rotate": sampled(R, 8, lambda p: 0.4 * max(0, s(p)))},
        "boot_l": {"rotate": sampled(R, 8, lambda p: -0.16 * max(0, -s(p)))},
        "boot_r": {"rotate": sampled(R, 8, lambda p: -0.16 * max(0, s(p)))},
        "arm_l": {"rotate": sampled(R, 8, lambda p: -0.3 * s(p))},
        "arm_r": {"rotate": sampled(R, 8, lambda p: -0.3 * s(p))},
        "fore_l": {"rotate": sampled(R, 8, lambda p: -0.35 - 0.1 * abs(s(p)))},
        "fore_r": {"rotate": sampled(R, 8, lambda p: -0.35 - 0.1 * abs(s(p)))},
        "chest": {"rotate": sampled(R, 8, lambda p: 0.025 * s(p))},
        "head": {"rotate": sampled(R, 8, lambda p: 0.02 * s(p + 0.6))},
        "cloak": {"rotate": sampled(R, 8, lambda p: 0.14 + 0.08 * s(p - 0.8))},
        "satchel": {"rotate": sampled(R, 8, lambda p: 0.22 * s(p - 0.5))},
        "charm": {"rotate": sampled(R, 8, lambda p: 0.35 * s(p - 0.7))},
        "hips": {"translate": translated(R, 8, lambda p: -abs(math.cos(p)) * 15 - 4)},
    }
    I = 4.0

    def slow(fn):
        return [[r2(t * 0.5), deg(fn(t * 0.5)), "smooth"] for t in range(9)]

    idle = {
        "hips": {"translate": [[r2(t * 0.5), 0, r2(-1 - math.sin(math.pi * t * 0.5)), "smooth"] for t in range(9)]},
        "chest": {"rotate": slow(lambda t: 0.006 * math.sin(math.pi * t))},
        "arm_l": {"rotate": slow(lambda t: 0.03 * math.sin(2 * math.pi * t / I))},
        "arm_r": {"rotate": slow(lambda t: -0.03 * math.sin(2 * math.pi * t / I))},
        "fore_l": {"rotate": [[0, deg(-0.04), "linear"]]},
        "fore_r": {"rotate": [[0, deg(-0.04), "linear"]]},
        "head": {"rotate": slow(lambda t: 0.02 * math.sin(2 * math.pi * t / I + 1))},
        "cloak": {"rotate": slow(lambda t: 0.03 * math.sin(math.pi * t - 0.6))},
        "charm": {"rotate": slow(lambda t: 0.08 * math.sin(2 * math.pi * t / (I / 3)))},
    }
    rig = {
        "format": "bountyhaven-rig", "version": 2, "name": "captain",
        "units": "rig px; origin = ground between the feet; y down; angles in degrees",
        "part_root": PART_ROOT,
        "views": [VIEW],
        "bones": bones, "slots": slots, "skins": {"default": skin},
        "customize": custom,
        "animations": {
            "idle": {"duration": I, "loop": True, "tracks": {"*": idle}},
            "walk": {"duration": r2(T), "loop": True, "ref_speed": 160, "tracks": {"*": walk}},
            "run": {"duration": R, "loop": True, "ref_speed": 265, "tracks": {"*": run}},
        },
    }
    OUT.write_text(json.dumps(rig, ensure_ascii=False, indent="\t") + "\n")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(bones)} bones, {len(slots)} slots, "
          f"{sum(len(v) for v in skin.values())} attachments, {len(rig['animations'])} clips")


if __name__ == "__main__":
    main()
