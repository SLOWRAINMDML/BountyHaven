"""BountyHaven protagonist - ink & watercolor NPR 3D character builder.

Run headless:
  blender -b -P blender/build_character.py -- [--out-dir exports] [--no-render]

Builds the BountyHaven protagonist (SLOWRAINMDML/BountyHaven design sheets:
brown tousled hair, rust-red scarf/cloak with compass mark, cream pilot jacket,
dark grey cargo trousers, buckled boots) as a rigged, customizable 3D character
that renders like the approved ink-drawing + watercolor illustrations:
  * humanoid armature (Godot/glTF friendly bone names)
  * skinned base body + rigid head
  * outfit sets   : Outfit_<name>_*   (pilot, vest, mechanic, guild)
  * accessories   : Acc_<name>        (scarf, cloak, satchel, goggles, gloves)
  * hair styles   : Hair_<name>        (tousled, tidy_crop, windswept, tied_low, travel_braid, messy_long)
  * face features : Face mesh with expression shape keys
  * weapons       : Weapon_Baton / Weapon_Pistol on the right hand
  * animations    : idle, walk, run, attack, shoot, gadget, guard, hit, death, victory
Saved to blender/bountyhaven_hero.blend and exported to exports/bountyhaven_hero.glb.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.join(ROOT, ARGS[ARGS.index("--out-dir") + 1]) if "--out-dir" in ARGS else os.path.join(ROOT, "exports")
DO_RENDER = "--no-render" not in ARGS
BRUSH_TEX = os.path.join(ROOT, "concept", "08_watercolor_paper_texture_512.png")
FPS = 30

# --------------------------------------------------------------------------
# Palette (sampled from the BountyHaven protagonist design sheet swatches)
# --------------------------------------------------------------------------
PALETTE = {
    "skin": (0.80, 0.58, 0.44),
    "hair_brown": (0.30, 0.16, 0.08),
    "scarf_red": (0.62, 0.20, 0.12),
    "cream": (0.86, 0.80, 0.66),
    "canvas_tan": (0.62, 0.50, 0.36),
    "leather": (0.42, 0.26, 0.14),
    "leather_dark": (0.24, 0.15, 0.09),
    "navy": (0.17, 0.20, 0.27),
    "slate": (0.30, 0.36, 0.44),
    "trouser_grey": (0.28, 0.28, 0.28),
    "olive": (0.40, 0.40, 0.30),
    "mustard": (0.78, 0.60, 0.28),
    "brass": (0.70, 0.54, 0.26),
    "steel": (0.55, 0.57, 0.60),
    "lens": (0.55, 0.70, 0.80),
    "eye": (0.26, 0.14, 0.07),
    "brow": (0.24, 0.13, 0.07),
    "mouth": (0.50, 0.24, 0.18),
    "outline": (0.13, 0.08, 0.05),   # brown ink, never pure black
}
SHADOW_TINT = (0.56, 0.64, 0.82)      # slate-blue watercolor shadow
LIGHT_TINT = (1.04, 1.0, 0.93)        # warm cream light


# --------------------------------------------------------------------------
# Scene helpers
# --------------------------------------------------------------------------
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = FPS
    scn.unit_settings.system = "METRIC"
    return scn


def collection(name, parent=None):
    col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if col.name not in (parent or bpy.context.scene.collection).children:
        (parent or bpy.context.scene.collection).children.link(col)
    return col


def link(obj, col):
    for c in obj.users_collection:
        c.objects.unlink(obj)
    col.objects.link(obj)


def activate(obj):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_modifiers(obj):
    activate(obj)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def mesh_from_bmesh(name, bm, col):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    col.objects.link(obj)
    return obj


def smart_uv(obj, scale=2.5):
    """Box-projected UVs (headless-safe); the brush texture just needs even density."""
    me = obj.data
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    mw = obj.matrix_world
    for p in me.polygons:
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            u, v = [(co.y, co.z), (co.x, co.z), (co.x, co.y)][ax]
            uv.data[li].uv = (u * scale, v * scale)


def shade_smooth(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


# --------------------------------------------------------------------------
# Materials: palette colour x watercolor paper texture (glTF: baseColorFactor * texture)
#   Principled BSDF = what glTF exports; the NPR branch (toon washes + pigment edge)
#   is what Blender renders. set_npr() switches the Material Output between them.
# --------------------------------------------------------------------------
_brush_image = None


def brush_image():
    global _brush_image
    if _brush_image:
        return _brush_image
    if os.path.exists(BRUSH_TEX):
        _brush_image = bpy.data.images.load(BRUSH_TEX)
    else:  # procedural fallback so the script works before the texture exists
        import numpy as np
        n = 256
        rng = np.random.default_rng(7)
        base = rng.normal(0.92, 0.04, (n, n))
        for _ in range(3):
            base = (base + np.roll(base, 1, 0) + np.roll(base, 1, 1)) / 3.0
        rgba = np.dstack([base, base * 0.98, base * 0.95, np.ones_like(base)]).clip(0, 1)
        _brush_image = bpy.data.images.new("paper_fallback", n, n)
        _brush_image.pixels = rgba.astype("float32").ravel()
        _brush_image.pack()
    _brush_image.name = "watercolor_paper"
    return _brush_image


_materials = {}


def material(key, color=None, metallic=0.0, roughness=0.9, textured=True, ink=False, image=None, soft=False):
    name = f"M_{key}"
    if name in _materials:
        return _materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    out = nt.nodes["Material Output"]
    col = color or PALETTE[key]
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = 0.3 if metallic else 0.05
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    if image is not None:  # painted (projected) texture already carries colour and shading
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.name = "PaintTex"
        mix.inputs[7].default_value = (1, 1, 1, 1)
        nt.links.new(tex.outputs["Color"], mix.inputs[6])
    elif textured:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = brush_image()
        # the paper texture averages ~0.85, so lift the factor to keep the palette value
        mix.inputs[7].default_value = (*(min(1.0, c * 1.15) for c in col), 1.0)
        nt.links.new(tex.outputs["Color"], mix.inputs[6])
    else:
        mix.inputs[6].default_value = (1, 1, 1, 1)
        mix.inputs[7].default_value = (*col, 1.0)
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])

    # ---- NPR watercolor branch (render only) ----
    npr_out = nt.nodes.new("ShaderNodeEmission")
    npr_out.name = "NPR"
    if ink:
        npr_out.inputs["Color"].default_value = (*col, 1.0)
    else:
        diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
        s2rgb = nt.nodes.new("ShaderNodeShaderToRGB")
        bw = nt.nodes.new("ShaderNodeRGBToBW")
        ramp = nt.nodes.new("ShaderNodeValToRGB")  # 3 soft-edged washes
        ramp.color_ramp.interpolation = "EASE"
        e = ramp.color_ramp.elements
        lo = 0.72 if soft else 0.0  # painted textures already hold their shading
        e[0].position, e[0].color = 0.0, (lo, lo, lo, 1)
        e[1].position, e[1].color = 0.55, (1.0, 1.0, 1.0, 1)
        mid = e.new(0.22)
        mid.color = ((1 + lo) * 0.55,) * 3 + (1,)
        shadow = nt.nodes.new("ShaderNodeMix"); shadow.data_type = "RGBA"; shadow.blend_type = "MULTIPLY"
        shadow.inputs[0].default_value = 1.0; shadow.inputs[7].default_value = (*SHADOW_TINT, 1)
        light = nt.nodes.new("ShaderNodeMix"); light.data_type = "RGBA"; light.blend_type = "MULTIPLY"
        light.inputs[0].default_value = 1.0; light.inputs[7].default_value = (*LIGHT_TINT, 1)
        wash = nt.nodes.new("ShaderNodeMix"); wash.data_type = "RGBA"
        lw = nt.nodes.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.35
        edge = nt.nodes.new("ShaderNodeMix"); edge.data_type = "RGBA"; edge.blend_type = "MULTIPLY"
        edge.inputs[7].default_value = (0.78, 0.72, 0.70, 1)  # pigment pooling at silhouettes
        nt.links.new(diff.outputs[0], s2rgb.inputs[0])
        nt.links.new(s2rgb.outputs["Color"], bw.inputs[0])
        nt.links.new(bw.outputs[0], ramp.inputs[0])
        nt.links.new(mix.outputs[2], shadow.inputs[6])
        nt.links.new(mix.outputs[2], light.inputs[6])
        nt.links.new(ramp.outputs["Color"], wash.inputs[0])
        nt.links.new(shadow.outputs[2], wash.inputs[6])
        nt.links.new(light.outputs[2], wash.inputs[7])
        nt.links.new(lw.outputs["Facing"], edge.inputs[0])
        nt.links.new(wash.outputs[2], edge.inputs[6])
        nt.links.new(edge.outputs[2], npr_out.inputs["Color"])
    nt.links.new(npr_out.outputs[0], out.inputs["Surface"])
    mat.diffuse_color = (*col, 1.0)
    _materials[name] = mat
    return mat


def set_npr(enabled):
    """Route every material to the NPR branch (render) or the Principled BSDF (glTF export)."""
    for mat in bpy.data.materials:
        if not mat.node_tree or "NPR" not in mat.node_tree.nodes:
            continue
        nt = mat.node_tree
        src = nt.nodes["NPR"] if enabled else nt.nodes["Principled BSDF"]
        nt.links.new(src.outputs[0], nt.nodes["Material Output"].inputs["Surface"])


def set_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def add_outline(obj, thickness=0.006):
    """Inverted-hull outline (exports to glTF as geometry, like the game's 3D outlines)."""
    mat_out = _materials.get("M_outline")
    if not mat_out:
        mat_out = material("outline", textured=False, roughness=1.0, ink=True)
        mat_out.use_backface_culling = True
    if mat_out.name not in obj.data.materials:
        obj.data.materials.append(mat_out)
    m = obj.modifiers.new("Outline", "SOLIDIFY")
    m.thickness = -thickness
    m.offset = 1.0
    m.use_flip_normals = True
    m.use_rim = False
    m.material_offset = len(obj.data.materials) - 1


# --------------------------------------------------------------------------
# Armature
# --------------------------------------------------------------------------
# (name, head, tail, parent, align_roll_z)
FRONT = (0, -1, 0)
BACK = (0, 1, 0)
BONES = [
    ("root", (0, 0, 0), (0, 0.25, 0), None, (0, 0, 1)),
    ("hips", (0, 0, 0.93), (0, 0, 1.05), "root", FRONT),
    ("spine", (0, 0, 1.05), (0, 0, 1.22), "hips", FRONT),
    ("chest", (0, 0, 1.22), (0, 0, 1.44), "spine", FRONT),
    ("neck", (0, 0, 1.44), (0, -0.01, 1.53), "chest", FRONT),
    ("head", (0, -0.01, 1.53), (0, -0.01, 1.78), "neck", FRONT),
]
for s, x in (("L", 1), ("R", -1)):
    BONES += [
        (f"shoulder.{s}", (0.03 * x, 0, 1.42), (0.19 * x, 0.01, 1.43), "chest", FRONT),
        (f"upper_arm.{s}", (0.19 * x, 0.01, 1.43), (0.39 * x, 0.02, 1.235), f"shoulder.{s}", FRONT),
        (f"forearm.{s}", (0.39 * x, 0.02, 1.235), (0.565 * x, 0.0, 1.06), f"upper_arm.{s}", FRONT),
        (f"hand.{s}", (0.565 * x, 0.0, 1.06), (0.625 * x, -0.005, 0.995), f"forearm.{s}", FRONT),
        (f"thigh.{s}", (0.095 * x, 0, 0.93), (0.10 * x, 0.005, 0.50), "hips", BACK),
        (f"shin.{s}", (0.10 * x, 0.005, 0.50), (0.10 * x, 0.02, 0.085), f"thigh.{s}", BACK),
        (f"foot.{s}", (0.10 * x, 0.02, 0.085), (0.10 * x, -0.10, 0.025), f"shin.{s}", (0, 0, 1)),
        (f"toe.{s}", (0.10 * x, -0.10, 0.025), (0.10 * x, -0.16, 0.02), f"foot.{s}", (0, 0, 1)),
    ]

# fingers: 2 phalanges each, spread across the palm (palm faces the body in the A-pose)
HAND_DIR = Vector((0.06, -0.005, -0.065)).normalized()
FINGERS = {  # name: (spread offset along Y from the palm centre, length scale)
    "index": (-0.022, 1.0), "middle": (-0.007, 1.08), "ring": (0.008, 1.0), "pinky": (0.022, 0.8),
}
for s, x in (("L", 1), ("R", -1)):
    d = Vector((HAND_DIR.x * x, HAND_DIR.y, HAND_DIR.z))
    knuckle = Vector((0.625 * x, -0.005, 0.995))
    for f, (dy, k) in FINGERS.items():
        a = knuckle + Vector((0, dy, 0))
        b = a + d * 0.036 * k
        c = b + d * 0.03 * k
        BONES += [(f"{f}_01.{s}", tuple(a), tuple(b), f"hand.{s}", (0, 0, 1)),
                  (f"{f}_02.{s}", tuple(b), tuple(c), f"{f}_01.{s}", (0, 0, 1))]
    t0 = Vector((0.583 * x, -0.03, 1.035))
    td = (d + Vector((0, -0.9, 0))).normalized()
    BONES += [(f"thumb_01.{s}", tuple(t0), tuple(t0 + td * 0.034), f"hand.{s}", (0, 0, 1)),
              (f"thumb_02.{s}", tuple(t0 + td * 0.034), tuple(t0 + td * 0.062), f"thumb_01.{s}", (0, 0, 1))]

# hair: 7 two-segment chains hanging from the skull (bangs, sides, back) for secondary motion
HAIR_CHAINS = {"front.L": 0.55, "front.R": -0.55, "side.L": 1.45, "side.R": -1.45,
               "back.L": 2.3, "back.R": -2.3, "back.C": math.pi}


def _hair_chain_points(theta):
    c, r = Vector((0, -0.012, 1.6426)), Vector((0.101, 0.11, 0.115))
    def on(phi, lift):
        d = Vector((math.sin(phi) * math.sin(theta), -math.sin(phi) * math.cos(theta), math.cos(phi)))
        return c + Vector((d.x * r.x, d.y * r.y, d.z * r.z)) * lift
    root = on(math.radians(45), 1.12)
    mid = on(math.radians(85), 1.16)
    tip = mid + Vector((0, 0, -0.14)) + (mid - c).normalized() * 0.01
    return root, mid, tip


for name, th in HAIR_CHAINS.items():
    r0, r1, r2 = _hair_chain_points(th)
    BONES += [(f"hair_{name}_01", tuple(r0), tuple(r1), "head", FRONT),
              (f"hair_{name}_02", tuple(r1), tuple(r2), f"hair_{name}_01", FRONT)]
FINGER_BONES = [b[0] for b in BONES if b[0].split("_")[0] in ("index", "middle", "ring", "pinky", "thumb")]
HAIR_BONES = [b[0] for b in BONES if b[0].startswith("hair_")]


def build_armature(col):
    arm_data = bpy.data.armatures.new("HeroRig")
    arm = bpy.data.objects.new("HeroRig", arm_data)
    col.objects.link(arm)
    activate(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for name, h, t, parent, roll_z in BONES:
        b = eb.new(name)
        b.head, b.tail = Vector(h), Vector(t)
        b.align_roll(Vector(roll_z))
        if parent:
            b.parent = eb[parent]
            b.use_connect = (Vector(h) - eb[parent].tail).length < 1e-4 and name not in ("hips",)
        b.use_deform = name != "root"
    bpy.ops.object.mode_set(mode="OBJECT")
    arm_data.display_type = "STICK"
    arm.show_in_front = True
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


# --------------------------------------------------------------------------
# Body (skin modifier on a joint skeleton) and head
# --------------------------------------------------------------------------
def build_body(col):
    # joint name -> (position, (radius_x, radius_y))
    J = {
        "pelvis": ((0, 0.0, 0.95), (0.135, 0.095)),
        "waist": ((0, 0.0, 1.07), (0.12, 0.085)),
        "chest": ((0, 0.0, 1.27), (0.175, 0.11)),
        "upper_chest": ((0, 0.0, 1.38), (0.195, 0.105)),
        "neck": ((0, -0.005, 1.47), (0.07, 0.066)),
        "neck_top": ((0, -0.008, 1.545), (0.06, 0.058)),
    }
    E = [("pelvis", "waist"), ("waist", "chest"), ("chest", "upper_chest"),
         ("upper_chest", "neck"), ("neck", "neck_top")]
    for s, x in (("L", 1), ("R", -1)):
        J.update({
            f"shoulder{s}": ((0.19 * x, 0.01, 1.42), (0.072, 0.068)),
            f"elbow{s}": ((0.39 * x, 0.02, 1.235), (0.056, 0.054)),
            f"wrist{s}": ((0.565 * x, 0.0, 1.06), (0.043, 0.038)),
            f"hand{s}": ((0.605 * x, -0.004, 1.017), (0.05, 0.03)),
            f"hip{s}": ((0.097 * x, 0.0, 0.90), (0.095, 0.094)),
            f"knee{s}": ((0.10 * x, 0.005, 0.50), (0.068, 0.07)),
            f"ankle{s}": ((0.10 * x, 0.02, 0.09), (0.054, 0.056)),
            f"toe{s}": ((0.10 * x, -0.155, 0.04), (0.058, 0.042)),
        })
        E += [("upper_chest", f"shoulder{s}"), (f"shoulder{s}", f"elbow{s}"), (f"elbow{s}", f"wrist{s}"),
              (f"wrist{s}", f"hand{s}"), ("pelvis", f"hip{s}"), (f"hip{s}", f"knee{s}"),
              (f"knee{s}", f"ankle{s}"), (f"ankle{s}", f"toe{s}")]
    names = list(J)
    me = bpy.data.meshes.new("Body")
    me.from_pydata([J[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in E], [])
    body = bpy.data.objects.new("Body", me)
    col.objects.link(body)
    skin = body.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    for i, n in enumerate(names):
        body.data.skin_vertices[0].data[i].radius = J[n][1]
        body.data.skin_vertices[0].data[i].use_root = n == "pelvis"
    sub = body.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 2
    apply_modifiers(body)
    shade_smooth(body)
    return body


def smooth_weights(obj, iters=4, keep=4):
    """Average each vertex's bone weights with its neighbours so joints fold softly."""
    import numpy as np
    me = obj.data
    names = [g.name for g in obj.vertex_groups]
    w = np.zeros((len(me.vertices), len(names)))
    for v in me.vertices:
        for g in v.groups:
            w[v.index, g.group] = g.weight
    e = np.array([ed.vertices[:] for ed in me.edges])
    deg = np.maximum(np.bincount(e.ravel(), minlength=len(w)), 1).astype(float)[:, None]
    for _ in range(iters):
        acc = np.zeros_like(w)
        np.add.at(acc, e[:, 0], w[e[:, 1]])
        np.add.at(acc, e[:, 1], w[e[:, 0]])
        w = 0.5 * w + 0.5 * acc / deg
    idx = np.argsort(-w, axis=1)[:, :keep]
    for g in list(obj.vertex_groups):
        g.remove(list(range(len(me.vertices))))
    top = w[np.arange(len(w))[:, None], idx]
    top /= np.maximum(top.sum(axis=1, keepdims=True), 1e-9)
    for vi in range(len(w)):
        for k in range(keep):
            if top[vi, k] > 0.01:
                obj.vertex_groups[idx[vi, k]].add([vi], float(top[vi, k]), "REPLACE")


def build_fingers(col, arm):
    """Each phalanx is a small capsule owned 100% by its bone (like SRPG_STD's voxel cells),
    merged into one skinned mesh per look so it deforms without any weight blending."""
    out = {}
    for name, mat, pad in (("Fingers", material("skin"), 0.0), ("Acc_GloveFingers", material("leather_dark"), 0.0035)):
        bm = bmesh.new()
        dl = bm.verts.layers.deform.verify()
        groups = []
        for b in arm.data.bones:
            if b.name not in FINGER_BONES and not b.name.startswith("hand."):
                continue
            gi = len(groups)
            groups.append(b.name)
            h, t = b.head_local, b.tail_local
            axis = (t - h).normalized()
            rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
            if b.name.startswith("hand."):  # palm: flat block from wrist to knuckles, as wide as the fingers
                side = Vector((0, 1, 0))
                flat = axis.cross(side).normalized()
                basis = Matrix((flat, side, axis)).transposed().to_4x4()
                m = Matrix.Translation(h + (t - h) * 0.62) @ basis @ Matrix.Diagonal((0.021 + pad, 0.036 + pad, 0.052 + pad, 1))
            else:
                r = (0.0135 if b.name.startswith("thumb") else 0.0118) * (0.88 if b.name.endswith(("_02.L", "_02.R")) else 1.0) + pad
                m = Matrix.Translation((h + t) / 2) @ rot @ Matrix.Diagonal((r, r, (t - h).length / 2 + r * 0.9, 1))
            before = set(bm.verts)
            bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=1.0, matrix=m)
            for v in bm.verts:
                if v not in before:
                    v[dl][gi] = 1.0
        obj = mesh_from_bmesh(name, bm, col)
        for g in groups:
            obj.vertex_groups.new(name=g)
        shade_smooth(obj)
        set_material(obj, mat)
        bind(obj, arm)
        out[name] = obj
    return out


def skin_hair(obj, arm):
    """Crown stays on the head; strands blend down their nearest hair chain (root -> tip)."""
    import numpy as np
    bones = {b.name: b for b in arm.data.bones}
    chains = [n[len("hair_"):-3] for n in HAIR_BONES if n.endswith("_01")]
    names = ["head"] + HAIR_BONES
    for n in names:
        obj.vertex_groups.new(name=n)
    top = HEAD_C.z + HEAD_R.z * 0.55
    for v in obj.data.vertices:
        co = v.co
        rel = co - HEAD_C
        theta = math.atan2(rel.x, -rel.y)
        ch = min(chains, key=lambda c: abs(math.remainder(theta - HAIR_CHAINS[c], 2 * math.pi)))
        b1, b2 = bones[f"hair_{ch}_01"], bones[f"hair_{ch}_02"]
        root_z, mid_z = b1.head_local.z, b2.head_local.z
        if co.z >= top:
            ws = {"head": 1.0}
        else:
            t = (root_z - co.z) / max(root_z - b2.tail_local.z, 1e-3)  # 0 at the root, 1 at the tip
            t = min(max(t, 0.0), 1.0)
            w2 = max(0.0, (t - 0.45) / 0.55) ** 1.2
            w1 = min(1.0, t * 1.8) * (1 - w2)
            wh = max(0.0, 1.0 - w1 - w2)
            ws = {"head": wh, f"hair_{ch}_01": w1, f"hair_{ch}_02": w2}
        for n, w in ws.items():
            if w > 0.01:
                obj.vertex_groups[n].add([v.index], w, "REPLACE")
    bind(obj, arm)


def build_head(col):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        # egg shaped skull, narrower jaw, slightly flat face
        jaw = 1.0 - 0.22 * max(0.0, -z) ** 1.8
        v.co = Vector((x * 0.099 * jaw, y * 0.108 * (0.93 if y < 0 else 1.0), z * 0.1134))
        if y < -0.5 and -0.2 < z < 0.2 and abs(x) < 0.25:  # tiny nose bridge
            v.co.y -= 0.01 * (1 - abs(x) / 0.25)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0, -0.012, 1.6426)))
    head = mesh_from_bmesh("Head", bm, col)
    shade_smooth(head)
    return head


# --------------------------------------------------------------------------
# Face with expression shape keys
# --------------------------------------------------------------------------
EXPRESSIONS = ["focused", "gentle_smile", "determined", "surprised", "battle_ready", "tired", "worried", "eyes_closed"]


def build_face(col, head=None):
    def surf(x, z, lift=0.004):
        """Point on the front of the head at (x, z), pushed out by `lift`."""
        if head is None:
            return Vector((x, -0.12, z))
        ok, loc, nrm, _ = head.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
        return loc + nrm * lift if ok else Vector((x, -0.12, z))

    bm = bmesh.new()
    part_layer = bm.verts.layers.int.new("part")
    names = []
    mat_of = {"eye": 0, "lash": 1, "brow": 1, "mouth": 2, "nose": 3}

    def add(name, maker, **kw):
        vb, fb = set(bm.verts), set(bm.faces)
        maker(bm, **kw)
        names.append(name)
        for v in bm.verts:
            if v not in vb:
                v[part_layer] = len(names)
        for f in bm.faces:
            if f not in fb:
                f.material_index = mat_of[name.rstrip("LR")]

    for s, x in (("L", 1), ("R", -1)):
        m = Matrix.Translation(surf(0.037 * x, 1.657, 0.001)) @ Matrix.Diagonal((0.011, 0.006, 0.012, 1))
        add(f"eye{s}", bmesh.ops.create_uvsphere, u_segments=10, v_segments=6, radius=1.0, matrix=m)
        m = (Matrix.Translation(surf(0.039 * x, 1.669, 0.003)) @ Matrix.Rotation(math.radians(6 * x), 4, "Y")
             @ Matrix.Diagonal((0.021, 0.005, 0.0028, 1)))
        add(f"lash{s}", bmesh.ops.create_cube, size=2.0, matrix=m)
        m = (Matrix.Translation(surf(0.0405 * x, 1.688, 0.004)) @ Matrix.Rotation(math.radians(-8 * x), 4, "Y")
             @ Matrix.Diagonal((0.024, 0.006, 0.0055, 1)))
        add(f"brow{s}", bmesh.ops.create_cube, size=2.0, matrix=m)
    m = Matrix.Translation(surf(0, 1.628, 0.003)) @ Matrix.Diagonal((0.006, 0.008, 0.012, 1))
    add("nose", bmesh.ops.create_cone, cap_ends=True, segments=4, radius1=1.0, radius2=0.2, depth=1.6, matrix=m @ Matrix.Rotation(math.radians(90), 4, "X"))
    m = Matrix.Translation(surf(0, 1.595, 0.0)) @ Matrix.Diagonal((0.026, 0.006, 0.0035, 1))
    add("mouth", bmesh.ops.create_uvsphere, u_segments=12, v_segments=6, radius=1.0, matrix=m)
    face = mesh_from_bmesh("Face", bm, col)
    for mt in (material("eye", textured=False, ink=True), material("brow", textured=False, ink=True),
               material("mouth", textured=False, ink=True), material("skin")):
        face.data.materials.append(mt)
    ids = face.data.attributes["part"].data
    parts = {n: [i for i, d in enumerate(ids) if d.value == k + 1] for k, n in enumerate(names)}

    face.shape_key_add(name="Basis")
    base = [v.co.copy() for v in face.data.vertices]

    def centre(name):
        return sum((base[i] for i in parts[name]), Vector()) / len(parts[name])

    def key(name, edits):
        for sd in ("L", "R"):
            fn = edits.get(f"eye{sd}")
            if fn is not None and hasattr(fn, "sz"):
                edits[f"lash{sd}"] = (lambda dz: (lambda co, c, d: co + Vector((0, 0, dz))))(-(1 - fn.sz) * 0.012 + getattr(fn, "dz", 0.0))
        sk = face.shape_key_add(name=name, from_mix=False)
        for part, fn in edits.items():
            c = centre(part)
            for i in parts[part]:
                sk.data[i].co = fn(base[i], c, base[i] - c)

    def brow(dz_inner, dz_outer, x_sign):
        # tilt the brow: inner end (towards x=0) moves dz_inner, outer end dz_outer
        return lambda co, c, d: co + Vector((0, 0, dz_inner + (dz_outer - dz_inner) * max(0.0, min(1.0, 0.5 + d.x * x_sign / 0.048))))

    def scale(sx, sz, dz=0.0):
        fn = lambda co, c, d: c + Vector((d.x * sx, d.y, d.z * sz + dz))
        fn.sz, fn.dz = sz, dz
        return fn

    smile = lambda k: (lambda co, c, d: co + Vector((0, 0, k * (abs(d.x) / 0.026) ** 2 - k * 0.3)))
    frown = lambda k: (lambda co, c, d: co + Vector((0, 0, -k * (abs(d.x) / 0.026) ** 2)))
    key("focused", {"browL": brow(-0.005, 0.0, 1), "browR": brow(-0.005, 0.0, -1),
                    "eyeL": scale(1.0, 0.72), "eyeR": scale(1.0, 0.72), "mouth": scale(0.85, 0.8)})
    key("gentle_smile", {"mouth": smile(0.004), "eyeL": scale(1.0, 0.7, -0.001), "eyeR": scale(1.0, 0.7, -0.001),
                         "browL": scale(1, 1, 0.002), "browR": scale(1, 1, 0.002)})
    key("determined", {"browL": brow(-0.007, 0.001, 1), "browR": brow(-0.007, 0.001, -1),
                       "eyeL": scale(1.0, 0.82), "eyeR": scale(1.0, 0.82), "mouth": frown(0.0015)})
    key("surprised", {"browL": scale(1, 1, 0.008), "browR": scale(1, 1, 0.008),
                      "eyeL": scale(1.1, 1.35), "eyeR": scale(1.1, 1.35), "mouth": scale(0.55, 4.0, -0.006)})
    key("battle_ready", {"browL": brow(-0.009, 0.001, 1), "browR": brow(-0.009, 0.001, -1),
                         "eyeL": scale(1.0, 0.65), "eyeR": scale(1.0, 0.65), "mouth": scale(1.1, 3.0, -0.003)})
    key("tired", {"browL": brow(0.002, -0.004, 1), "browR": brow(0.002, -0.004, -1),
                  "eyeL": scale(1.02, 0.4, -0.002), "eyeR": scale(1.02, 0.4, -0.002), "mouth": scale(0.8, 1.0)})
    key("worried", {"browL": brow(0.006, -0.003, 1), "browR": brow(0.006, -0.003, -1),
                    "eyeL": scale(1.0, 1.05), "eyeR": scale(1.0, 1.05), "mouth": frown(0.003)})
    key("eyes_closed", {"eyeL": scale(1.05, 0.1, -0.002), "eyeR": scale(1.05, 0.1, -0.002)})
    return face


# --------------------------------------------------------------------------
# Clothing shells derived from the skinned body (they inherit its weights)
# --------------------------------------------------------------------------
def dominant_groups(obj):
    names = {g.index: g.name for g in obj.vertex_groups}
    out = []
    for v in obj.data.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        out.append(names[best.group] if best else None)
    return out


ARM_DIR = Vector((0.712, -0.019, -0.702))
SHOULDER = Vector((0.19, 0.01, 1.43))


def along_arm(co):
    """Distance along the arm from the shoulder joint, or -1 when not on an arm."""
    if abs(co.x) < 0.14 or co.z < 0.9:
        return -1.0
    d = Vector((abs(co.x), co.y, co.z)) - SHOULDER
    return d.dot(ARM_DIR)


def arm_cuts(s):
    cuts = []
    for x in (1, -1):
        p = SHOULDER + ARM_DIR * s
        cuts.append((Vector((p.x * x, p.y, p.z)), Vector((ARM_DIR.x * x, ARM_DIR.y, ARM_DIR.z))))
    return cuts


def zcut(z):
    return [(Vector((0, 0, z)), Vector((0, 0, 1)))]


def xcut(x):
    return [(Vector((x, 0, 0)), Vector((1, 0, 0))), (Vector((-x, 0, 0)), Vector((1, 0, 0)))]


def shell(body, name, col, offset, keep, cuts=(), mat=None):
    """Copy the body, slice it along `cuts` for clean hems, keep faces whose rest-pose
    centre passes keep(co), and push the rest out along the normals. The copy keeps
    the body's vertex groups, so it deforms exactly like the skin underneath."""
    obj = body.copy()
    obj.data = body.data.copy()
    obj.name = obj.data.name = name
    col.objects.link(obj)
    for m in list(obj.modifiers):
        if m.type != "ARMATURE":  # keep the skin binding, drop anything else
            obj.modifiers.remove(m)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for co, no in cuts:
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, dist=1e-5)
    bm.normal_update()
    kill = [f for f in bm.faces if not keep(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    for v in bm.verts:
        v.co += v.normal * (offset(v.co) if callable(offset) else offset)
    bm.to_mesh(obj.data)
    bm.free()
    shade_smooth(obj)
    if mat:
        set_material(obj, mat)
    return obj


def bind(obj, arm, body=None, bone=None):
    """Parent to armature: rigid to one bone, or transfer weights from the body."""
    if bone:
        bpy.context.view_layer.update()
        mw = obj.matrix_world.copy()
        obj.parent = arm
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        bpy.context.view_layer.update()
        obj.matrix_world = mw  # keep the modelled placement
        return obj
    if body is not None and not obj.vertex_groups:
        for g in body.vertex_groups:
            obj.vertex_groups.new(name=g.name)
        dt = obj.modifiers.new("WeightTransfer", "DATA_TRANSFER")
        dt.object = body
        dt.use_vert_data = True
        dt.data_types_verts = {"VGROUP_WEIGHTS"}
        dt.vert_mapping = "POLYINTERP_NEAREST"
        dt.layers_vgroup_select_src = "ALL"
        dt.layers_vgroup_select_dst = "NAME"
        activate(obj)
        bpy.ops.object.modifier_apply(modifier=dt.name)
    obj.parent = arm
    if not any(m.type == "ARMATURE" for m in obj.modifiers):
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    return obj


def cone_mesh(name, col, rings, segments=16, mat=None, close_top=False):
    """Loft a tube through rings [(z, rx, ry, cx, cy)]."""
    bm = bmesh.new()
    loops = []
    for z, rx, ry, cx, cy in rings:
        loops.append([bm.verts.new((cx + rx * math.cos(a), cy + ry * math.sin(a), z))
                      for a in (2 * math.pi * i / segments for i in range(segments))])
    for a, b in zip(loops, loops[1:]):
        for i in range(segments):
            bm.faces.new((a[i], a[(i + 1) % segments], b[(i + 1) % segments], b[i]))
    if close_top:
        bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_from_bmesh(name, bm, col)
    shade_smooth(obj)
    if mat:
        set_material(obj, mat)
    return obj


def box(name, col, size, loc, mat=None, rot=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector(loc), Euler(rot).to_quaternion(), Vector(size)))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES")
    obj = mesh_from_bmesh(name, bm, col)
    if mat:
        set_material(obj, mat)
    return obj


def ellipsoid(name, col, radius, loc, mat=None, rot=(0, 0, 0), zcut=None, segs=(16, 10)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=1.0)
    if zcut is not None:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < zcut], context="VERTS")
    bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.LocRotScale(Vector(loc), Euler(rot).to_quaternion(), Vector(radius)))
    obj = mesh_from_bmesh(name, bm, col)
    shade_smooth(obj)
    if mat:
        set_material(obj, mat)
    return obj


def upper(zmin, sleeve, zmax=1.485):
    """Torso from zmin up to the collar, plus each arm out to `sleeve` along the arm."""
    def keep(co):
        s = along_arm(co)
        if s > 0.02:
            return s <= sleeve
        return zmin <= co.z <= zmax and abs(co.x) < 0.3
    return keep, zcut(zmin) + zcut(zmax) + arm_cuts(sleeve)


def lower(zmax, zmin=0.0):
    def keep(co):
        return zmin <= co.z <= zmax and abs(co.x) < 0.3 and along_arm(co) < 0
    return keep, zcut(zmax) + (zcut(zmin) if zmin > 0 else [])


def arm_band(s0, s1):
    return (lambda co: s0 <= along_arm(co) <= s1), arm_cuts(s0) + arm_cuts(s1)


def piece(body, name, col, offset, region, mat):
    keep, cuts = region
    return shell(body, name, col, offset, keep, cuts, mat)


def boots(body, col, prefix, top_z, mat, offset=0.014):
    return [piece(body, f"{prefix}_Boots", col, offset, lower(top_z), mat),
            piece(body, f"{prefix}_BootCuffs", col, offset + 0.012, lower(top_z, top_z - 0.05), mat)]


def belt(body, col, prefix, mat, z=(0.96, 1.02), offset=0.022):
    return piece(body, f"{prefix}_Belt", col, offset, lower(z[1], z[0]), mat)


def ring(name, col, z, rx, ry, cy, h, mat, segs=20, flare=0.0):
    """Short tube (scarf wrap, cuffs) centred on the body axis."""
    return cone_mesh(name, col, [(z - h / 2, rx * (1 + flare), ry * (1 + flare), 0, cy), (z + h / 2, rx, ry, 0, cy)], segs, mat)


def strap(name, col, p0, p1, width, thick, mat, lift=0.0):
    """Flat leather strap between two points (harness, satchel strap)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    m = Matrix.LocRotScale((p0 + p1) / 2 + Vector((0, -lift, 0)), Vector((0, 0, 1)).rotation_difference(d.normalized()),
                           Vector((width, thick, d.length)))
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    obj = mesh_from_bmesh(name, bm, col)
    set_material(obj, mat)
    return obj


def ragged(obj, depth=0.05, seed=0):
    """Cut a torn hem into the lowest ring of a cloth mesh."""
    rng = random.Random(seed)
    zs = [v.co.z for v in obj.data.vertices]
    zmin = min(zs)
    for v in obj.data.vertices:
        if v.co.z < zmin + 1e-4:
            v.co.z += rng.choice((0, depth, depth * 0.4, depth * 0.8))


def cross_harness(col, prefix, mat, z_top=1.43, z_bot=1.05, y_front=-0.118):
    return [strap(f"{prefix}_HarnessA", col, (0.13, y_front + 0.01, z_top), (-0.12, y_front - 0.004, z_bot), 0.028, 0.008, mat),
            strap(f"{prefix}_HarnessB", col, (-0.13, y_front + 0.01, z_top), (0.12, y_front - 0.004, z_bot), 0.028, 0.008, mat)]


def build_outfits(body, arm, root_col):
    out = {}
    leather = material("leather")
    dark = material("leather_dark")
    brass = material("brass", metallic=0.6, roughness=0.5)

    def baggy(co):
        """Loose cargo cut: extra cloth over the thigh and bunched above the boot."""
        return 0.015 + 0.024 * math.exp(-((co.z - 0.66) / 0.16) ** 2) + 0.016 * math.exp(-((co.z - 0.42) / 0.05) ** 2)

    def legs(col, prefix, trouser="trouser_grey", boot_top=0.36, knee_pads=True, cargo=True):
        items = [piece(body, f"{prefix}_Trousers", col, baggy, lower(1.0), material(trouser)),
                 belt(body, col, prefix, leather, z=(0.96, 1.03), offset=0.03)]
        items += boots(body, col, prefix, boot_top, material("leather"), offset=0.028)
        for sx, x in (("L", 1), ("R", -1)):
            # chunky soles and toe caps, like the design sheet's work boots
            items.append(bind(box(f"{prefix}_BootSole.{sx}", col, (0.13, 0.27, 0.035), (0.10 * x, -0.05, 0.017), dark, bevel=0.01), arm, bone=f"foot.{sx}"))
            items.append(bind(ellipsoid(f"{prefix}_BootToe.{sx}", col, (0.066, 0.075, 0.05), (0.10 * x, -0.14, 0.05), material("leather"), segs=(12, 8)), arm, bone=f"toe.{sx}"))
            bs = ring(f"{prefix}_BootStrap.{sx}", col, 0.0, 0.078, 0.08, 0, 0.018, dark)
            bs.location = (0.10 * x, 0.02, 0.24)
            items.append(bind(bs, arm, bone=f"shin.{sx}"))
            if knee_pads:
                items.append(ellipsoid(f"{prefix}_KneePad.{sx}", col, (0.064, 0.035, 0.072), (0.10 * x, -0.075, 0.5), dark, segs=(12, 8)))
            if cargo:  # thigh cargo pocket with flap on the outer thigh
                items.append(bind(box(f"{prefix}_ThighPocket.{sx}", col, (0.05, 0.12, 0.13), (0.225 * x, -0.01, 0.68), material(trouser), bevel=0.012), arm, bone=f"thigh.{sx}"))
                items.append(bind(box(f"{prefix}_ThighFlap.{sx}", col, (0.055, 0.125, 0.04), (0.23 * x, -0.01, 0.74), dark, bevel=0.008), arm, bone=f"thigh.{sx}"))
        for sx, x in (("L", 1), ("R", -1)):  # belt pouches
            items.append(bind(box(f"{prefix}_BeltPouch.{sx}", col, (0.08, 0.05, 0.09), (0.13 * x, -0.125, 0.94), leather, bevel=0.012), arm, bone="hips"))
        return items

    # --- 01 pilot jacket (the design-sheet default)
    col = collection("Outfit_Pilot", root_col)
    items = [
        piece(body, "Outfit_Pilot_Undershirt", col, 0.008, upper(0.93, 0.30), material("navy")),
        piece(body, "Outfit_Pilot_Jacket", col, 0.02, upper(0.90, 0.33), material("cream")),
        piece(body, "Outfit_Pilot_SleeveRoll", col, 0.032, arm_band(0.29, 0.34), material("cream")),
        box("Outfit_Pilot_Patch", col, (0.012, 0.05, 0.05), (0.24, 0.0, 1.32), material("canvas_tan"), rot=(0, math.radians(-40), 0)),
    ]
    items += cross_harness(col, "Outfit_Pilot", leather)
    items += legs(col, "Outfit_Pilot")
    out["pilot"] = (col, items)

    # --- 02 travel vest over a light undershirt
    col = collection("Outfit_Vest", root_col)
    items = [
        piece(body, "Outfit_Vest_Shirt", col, 0.01, upper(0.92, 0.36), material("cream")),
        piece(body, "Outfit_Vest_SleeveRoll", col, 0.022, arm_band(0.32, 0.37), material("cream")),
        piece(body, "Outfit_Vest_Vest", col, 0.024, upper(0.90, 0.0, zmax=1.45), material("canvas_tan")),
    ]
    items += cross_harness(col, "Outfit_Vest", dark, y_front=-0.124)
    items += legs(col, "Outfit_Vest", trouser="canvas_tan")
    out["vest"] = (col, items)

    # --- 04 mechanic jacket (slate-navy, long sleeves, tool belt)
    col = collection("Outfit_Mechanic", root_col)
    items = [
        piece(body, "Outfit_Mechanic_Shirt", col, 0.008, upper(0.93, 0.2), material("cream")),
        piece(body, "Outfit_Mechanic_Jacket", col, 0.02, upper(0.86, 0.50), material("slate")),
        piece(body, "Outfit_Mechanic_Cuffs", col, 0.03, arm_band(0.45, 0.50), material("navy")),
        box("Outfit_Mechanic_Wrench", col, (0.02, 0.012, 0.16), (-0.17, -0.06, 0.92), material("steel", metallic=0.7, roughness=0.5)),
    ]
    items += legs(col, "Outfit_Mechanic", trouser="navy")
    out["mechanic"] = (col, items)

    # --- 06 guild coat (long cream coat, rust lining hint)
    col = collection("Outfit_Guild", root_col)
    items = [
        piece(body, "Outfit_Guild_Undershirt", col, 0.008, upper(0.93, 0.3), material("navy")),
        piece(body, "Outfit_Guild_Coat", col, 0.022, upper(0.86, 0.46), material("cream")),
        piece(body, "Outfit_Guild_Cuffs", col, 0.034, arm_band(0.40, 0.46), material("scarf_red")),
    ]
    tail = cone_mesh("Outfit_Guild_CoatTail", col, [
        (0.95, 0.165, 0.12, 0, 0.0), (0.72, 0.22, 0.16, 0, 0.01), (0.48, 0.26, 0.19, 0, 0.02)], segments=24, mat=material("cream"))
    bm = bmesh.new(); bm.from_mesh(tail.data)  # open front
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < -0.08 and abs(f.calc_center_median().x) < 0.1], context="FACES")
    bm.to_mesh(tail.data); bm.free()
    items.append(tail)
    items += cross_harness(col, "Outfit_Guild", leather, y_front=-0.126)
    items += legs(col, "Outfit_Guild", knee_pads=False)
    out["guild"] = (col, items)

    for key, (col, items) in out.items():
        for o in items:
            if o.parent is not None or o.modifiers.get("Armature"):
                continue
            bind(o, arm, body=None if o.vertex_groups else body)
    return out


def build_accessories(body, arm, root_col):
    """Independent toggles: Acc_Scarf, Acc_Cloak, Acc_Satchel, Acc_Goggles, Acc_Gloves."""
    col = collection("Accessories", root_col)
    red = material("scarf_red")
    leather = material("leather")
    acc = {}
    # signature rust-red scarf wrapped high around the neck, with a hanging tail
    scarf = ring("Acc_Scarf", col, 1.48, 0.095, 0.09, -0.005, 0.075, red, flare=0.35)
    tail = cone_mesh("Acc_ScarfTail", col, [(1.44, 0.035, 0.012, 0.05, -0.1), (1.30, 0.04, 0.012, 0.07, -0.13), (1.18, 0.03, 0.01, 0.08, -0.135)], 8, red)
    ragged(tail, 0.03, 3)
    cowl = cone_mesh("Acc_ScarfCowl", col, [(1.52, 0.09, 0.085, 0, -0.005), (1.48, 0.17, 0.13, 0, 0.0),
                                            (1.42, 0.27, 0.165, 0, 0.01), (1.35, 0.30, 0.18, 0, 0.015)], 24, red)
    ragged(cowl, 0.03, 5)
    acc["scarf"] = [bind(scarf, arm, bone="neck"), bind(tail, arm, bone="chest"), bind(cowl, arm, body=body)]
    # short ragged cloak over the back and left shoulder (compass mark lives in the texture work later)
    cloak = cone_mesh("Acc_Cloak", col, [
        (1.47, 0.12, 0.09, 0, 0.0), (1.40, 0.24, 0.15, 0, 0.02), (1.20, 0.27, 0.18, 0, 0.05), (0.95, 0.29, 0.2, 0, 0.08), (0.78, 0.30, 0.21, 0, 0.1)],
        segments=22, mat=red)
    bm = bmesh.new(); bm.from_mesh(cloak.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < 0.02
                               and not (f.calc_center_median().x > 0.13 and f.calc_center_median().z > 1.2)], context="FACES")
    bm.to_mesh(cloak.data); bm.free()
    ragged(cloak, 0.08, 7)
    compass = cone_mesh("Acc_CloakCompass", col, [(1.12, 0.045, 0.001, 0, 0.205), (1.121, 0.001, 0.001, 0, 0.205)], 8, material("cream"))
    compass.rotation_euler = (math.radians(90), 0, 0)
    acc["cloak"] = [bind(cloak, arm, bone="chest"), bind(compass, arm, bone="chest")]
    # field satchel on the right hip with a strap over the left shoulder
    bag = box("Acc_Satchel", col, (0.06, 0.15, 0.13), (-0.19, 0.02, 0.92), leather, bevel=0.012)
    flap = box("Acc_SatchelFlap", col, (0.066, 0.152, 0.06), (-0.195, 0.02, 0.965), material("leather_dark"), bevel=0.008)
    bstrap = strap("Acc_SatchelStrap", col, (0.15, 0.0, 1.44), (-0.18, 0.02, 0.98), 0.024, 0.01, leather, lift=0.0)
    acc["satchel"] = [bind(bag, arm, bone="hips"), bind(flap, arm, bone="hips"), bind(bstrap, arm, body=body)]
    # goggles resting on the forehead
    gog = []
    for sx, x in (("L", 1), ("R", -1)):
        g = cone_mesh(f"Acc_Goggles.{sx}", col, [(0, 0.024, 0.024, 0, 0), (0.02, 0.022, 0.022, 0, 0)], 12, material("brass", metallic=0.6, roughness=0.5), close_top=True)
        g.rotation_euler = (math.radians(-70), 0, 0)
        g.location = (0.036 * x, -0.098, 1.718)
        gog.append(g)
    band = ring("Acc_GogglesBand", col, 0.0, 0.11, 0.121, 0.0, 0.013, material("leather_dark"), segs=24)
    band.location = (0, -0.012, 1.705)
    band.rotation_euler = (math.radians(-14), 0, 0)
    acc["goggles"] = [bind(o, arm, bone="head") for o in gog + [band]]
    # reinforced leather gloves
    acc["gloves"] = [bind(piece(body, "Acc_Gloves", col, 0.012, arm_band(0.49, 0.75), material("leather_dark")), arm)]
    for items in acc.values():
        for o in items:
            if o.parent is None:
                bind(o, arm, body=body)
    return col, acc


# --------------------------------------------------------------------------
# Hair (rigid on the head bone): tapered, flattened clumps that follow the skull
# --------------------------------------------------------------------------
HEAD_C = Vector((0, -0.012, 1.6426))
HEAD_R = Vector((0.101, 0.11, 0.115))   # skull ellipsoid radii (matches build_head)


def skull(theta, phi, lift=1.0):
    """Point on the skull ellipsoid. phi: 0 at crown, 90deg at the ears; theta: 0 = face (-Y)."""
    d = Vector((math.sin(phi) * math.sin(theta), -math.sin(phi) * math.cos(theta), math.cos(phi)))
    return HEAD_C + Vector((d.x * HEAD_R.x, d.y * HEAD_R.y, d.z * HEAD_R.z)) * lift


def clump(bm, pts, width, thick, tip_taper=1.0):
    """Loft a flattened, tapering strand through pts (flat side against the head)."""
    n = len(pts)
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        out = (p - HEAD_C).normalized()
        side = t.cross(out).normalized()
        out = side.cross(t).normalized()
        k = i / (n - 1)
        w = width * (1 - tip_taper * k ** 1.6) + 0.002
        h = thick * (1 - 0.7 * k) + 0.001
        rings.append([bm.verts.new(p + side * (w * math.cos(a)) + out * (h * math.sin(a)))
                      for a in (0, math.pi * 0.5, math.pi, math.pi * 1.5)])
    for a, b in zip(rings, rings[1:]):
        for j in range(4):
            bm.faces.new((a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def flow(theta, phi0, phi1, steps=7, lift0=1.06, lift1=1.12, dtheta=0.0, hang=0.0, curl=0.0):
    """Strand that follows a meridian from phi0 to phi1, then optionally hangs straight down."""
    pts = []
    for i in range(steps):
        k = i / (steps - 1)
        pts.append(skull(theta + dtheta * k, phi0 + (phi1 - phi0) * k, lift0 + (lift1 - lift0) * k))
    if hang > 0:
        last = pts[-1]
        outward = Vector((last.x - HEAD_C.x, last.y - HEAD_C.y, 0)).normalized()
        for j in range(1, 4):
            pts.append(last + Vector((0, 0, -hang * j / 3)) + outward * 0.012 * j)
    if curl:
        out = (pts[-1] - HEAD_C).normalized()
        pts[-1] = pts[-1] + out * curl
    return pts


def hair_cap(bm, phi_front, phi_side, phi_back, lift=1.035):
    """Solid underlayer so no scalp shows between clumps."""
    rings, R = [], 14
    for i in range(R + 1):
        k = i / R
        ring = []
        for j in range(24):
            th = 2 * math.pi * j / 24
            front = math.cos(th)  # 1 at the face, -1 at the back
            lim = phi_side + (phi_front - phi_side) * max(front, 0) + (phi_back - phi_side) * max(-front, 0)
            ring.append(bm.verts.new(skull(th, 0.02 + (lim - 0.02) * k, lift)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for j in range(24):
            bm.faces.new((a[j], a[(j + 1) % 24], b[(j + 1) % 24], b[j]))
    bm.faces.new(list(reversed(rings[0])))


def braid(bm, pts, r):
    for a, b in zip(pts, pts[1:]):
        for t in (0.25, 0.75):
            c = a.lerp(b, t)
            bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=1.0,
                                      matrix=Matrix.Translation(c) @ Matrix.Diagonal((r, r, r * 1.3, 1)))


def build_hair(root_col):
    col = collection("Hair", root_col)
    mat = material("hair_brown")
    styles = {}
    rad = math.radians

    def finish(name, bm):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj = mesh_from_bmesh(f"Hair_{name}", bm, col)
        set_material(obj, mat)
        shade_smooth(obj)
        styles[name] = obj

    def shaggy(bm, seed, sweep=0.0, n=40, front_end=78, length=1.0):
        rng = random.Random(seed)
        hair_cap(bm, rad(front_end - 8), rad(95), rad(115), lift=1.09)
        for i in range(n):
            th = 2 * math.pi * i / n + rng.uniform(-0.1, 0.1)
            front = math.cos(th)
            end = rad(front_end) if front > 0.6 else rad(98 + 18 * max(-front, 0) * length)
            clump(bm, flow(th, rad(rng.uniform(0, 25)), end + rad(rng.uniform(-8, 8)),
                           dtheta=sweep + rng.uniform(-0.3, 0.3), lift0=1.13, lift1=1.3 + rng.uniform(0, 0.1),
                           curl=rng.uniform(0.01, 0.035)),
                  width=rng.uniform(0.04, 0.056), thick=0.02)
        for i in range(14):  # crown tufts for the tousled silhouette
            th = rng.uniform(0, 2 * math.pi)
            clump(bm, flow(th, rad(3), rad(rng.uniform(35, 55)), steps=5, lift0=1.12, lift1=1.36, curl=0.035,
                           dtheta=sweep * 0.5), width=0.03, thick=0.016)

    # 01 tousled (base design)
    bm = bmesh.new(); shaggy(bm, 3)
    finish("tousled", bm)

    # 03 windswept: the same shag pushed to one side
    bm = bmesh.new(); shaggy(bm, 5, sweep=0.55, front_end=74)
    finish("windswept", bm)

    # low ponytail
    bm = bmesh.new(); hair_cap(bm, rad(60), rad(92), rad(115))
    for i in range(22):
        th = 2 * math.pi * i / 22
        front = math.cos(th)
        end = rad(64) if front > 0.6 else rad(100 + 10 * max(-front, 0))
        clump(bm, flow(th, rad(3), end, lift1=1.1), width=0.03, thick=0.01)
    tie = skull(math.pi, rad(118), 1.05)
    for j in range(5):
        a = 2 * math.pi * j / 5
        off = Vector((math.cos(a) * 0.012, math.sin(a) * 0.008, 0))
        clump(bm, [tie + off, tie + off + Vector((0, 0.03, -0.06)), tie + off + Vector((0, 0.035, -0.14)),
                   tie + off * 0.5 + Vector((0, 0.03, -0.22))], width=0.02, thick=0.012)
    finish("tied_low", bm)

    # soldier crop
    bm = bmesh.new(); hair_cap(bm, rad(52), rad(80), rad(100), lift=1.03)
    for i in range(20):
        th = 2 * math.pi * i / 20
        clump(bm, flow(th, rad(2), rad(50 if math.cos(th) > 0.6 else 75), steps=5, lift0=1.04, lift1=1.06), width=0.03, thick=0.008)
    finish("tidy_crop", bm)

    # long shoulder-length hair with a centre part
    bm = bmesh.new(); hair_cap(bm, rad(62), rad(95), rad(115))
    for i in range(30):
        th = 2 * math.pi * i / 30 + 0.05
        front = math.cos(th)
        if front > 0.75:
            continue  # keep the face open
        clump(bm, flow(th, rad(4), rad(100), lift1=1.1, hang=0.17 if front < 0.3 else 0.12), width=0.032, thick=0.012)
    for sgn in (1, -1):
        clump(bm, flow(0.55 * sgn, rad(2), rad(95), lift1=1.1, hang=0.12), width=0.03, thick=0.012)
    finish("messy_long", bm)

    # 09 travel braid: tousled top, braid down the back
    bm = bmesh.new(); shaggy(bm, 9, n=30, length=0.6)
    start = skull(math.pi, rad(95), 1.04)
    braid(bm, [start, start + Vector((0.01, 0.03, -0.09)), start + Vector((0, 0.04, -0.18)), start + Vector((0.01, 0.035, -0.27))], 0.018)
    finish("travel_braid", bm)
    return col, styles



def build_weapons(col, arm):
    """Stun baton (melee capture) and sidearm pistol, both gripped in the right hand."""
    steel = material("steel", metallic=0.6, roughness=0.55)
    brass = material("brass", metallic=0.6, roughness=0.5)
    grip = material("leather_dark")
    hand = Vector((-0.605, -0.03, 1.015))

    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.018, radius2=0.018, depth=0.14, matrix=Matrix.Translation((0, 0, 0)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.026, radius2=0.026, depth=0.03, matrix=Matrix.Translation((0, 0, 0.085)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.016, radius2=0.012, depth=0.36, matrix=Matrix.Translation((0, 0, 0.28)))
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.022, matrix=Matrix.Translation((0, 0, 0.47)))
    baton = mesh_from_bmesh("Weapon_Baton", bm, col)
    for m in (grip, brass, steel):
        baton.data.materials.append(m)
    for p in baton.data.polygons:
        p.material_index = 0 if p.center.z < 0.07 else 1 if p.center.z < 0.1 or p.center.z > 0.44 else 2
    baton.location = hand
    baton.rotation_euler = (math.radians(90), 0, 0)  # points forward out of the fist

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector((0, -0.07, 0.035)), None, Vector((0.03, 0.2, 0.045))))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.012, radius2=0.012, depth=0.08,
                          matrix=Matrix.Translation((0, -0.2, 0.04)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector((0, 0.0, -0.03)), Euler((math.radians(-15), 0, 0)).to_quaternion(), Vector((0.028, 0.04, 0.1))))
    pistol = mesh_from_bmesh("Weapon_Pistol", bm, col)
    for m in (steel, grip):
        pistol.data.materials.append(m)
    for p in pistol.data.polygons:
        p.material_index = 1 if p.center.z < 0.005 else 0
    pistol.location = hand
    # barrel continues the hand bone, so an extended arm aims straight ahead
    hand_dir = Vector((-0.055, -0.005, -0.06)).normalized()
    pistol.rotation_euler = Vector((0, -1, 0)).rotation_difference(hand_dir).to_euler()
    return {"baton": bind(baton, arm, bone="hand.R"), "pistol": bind(pistol, arm, bone="hand.R")}


# --------------------------------------------------------------------------
# Animation helpers (rotations authored in the character's world axes)
#   character faces -Y, +X is its left, +Z up.
#   +X rot: bends the spine/head forward, swings a leg BACK, bends the knee.
# --------------------------------------------------------------------------
def finger_pose(action, frame, frames):
    """Right hand grips the weapon; the left hand relaxes, and makes a fist when guarding or casting."""
    out = {}
    fist_l = action in ("guard", "attack")
    open_l = action in ("gadget", "victory")
    for s, sign in (("L", 1), ("R", -1)):
        if s == "R":
            c1, c2, th = 75, 70, 35
        elif fist_l:
            c1, c2, th = 80, 75, 30
        elif open_l:
            c1, c2, th = 5, 5, 0
        else:
            c1, c2, th = 22, 25, 10
        for f in ("index", "middle", "ring", "pinky"):
            k = 1.0 + 0.08 * ("index", "middle", "ring", "pinky").index(f)  # outer fingers curl a bit more
            out[f"{f}_01.{s}"] = (0, sign * c1 * k, 0)
            out[f"{f}_02.{s}"] = (0, sign * c2 * k, 0)
        out[f"thumb_01.{s}"] = (th * 0.4, sign * th, 0)
        out[f"thumb_02.{s}"] = (0, sign * th * 0.8, 0)
    return out


HAIR_MOTION = {  # action: (swing back deg, wobble deg, cycles per clip)
    "idle": (0, 2.0, 1), "walk": (6, 4.0, 2), "run": (16, 7.0, 2), "attack": (4, 9.0, 1.5),
    "shoot": (0, 4.0, 1), "gadget": (0, 3.0, 1), "guard": (3, 2.5, 1), "hit": (-10, 10.0, 1.5),
    "death": (-6, 8.0, 1), "victory": (4, 5.0, 1.5),
}


def hair_pose(action, frame, frames):
    """Baked secondary motion: chains lag the body with a damped wobble (tips lag more)."""
    swing, wob, cyc = HAIR_MOTION.get(action, (0, 2.0, 1))
    out = {}
    for n in HAIR_BONES:
        ch = n[len("hair_"):-3]
        th = HAIR_CHAINS[ch]
        tip = n.endswith("_02")
        phase = 2 * math.pi * cyc * (frame - 1) / max(frames, 1) - (0.9 if tip else 0.0) - th * 0.15
        a = swing * (0.6 if tip else 0.4) + wob * math.sin(phase) * (1.3 if tip else 0.7)
        # swing about X (front/back); side chains also flare slightly about Y
        out[n] = (a, (a * 0.35 if "L" in ch[-1] else -a * 0.35) if "side" in ch else 0, 0)
    return out


class Animator:
    def __init__(self, arm):
        self.arm = arm
        self.rest = {b.name: b.matrix_local.to_quaternion() for b in arm.data.bones}

    def q(self, bone, rx=0.0, ry=0.0, rz=0.0):
        """Local quaternion for a rotation expressed in armature (rest) axes."""
        world = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_quaternion()
        r = self.rest[bone]
        return r.inverted() @ world @ r

    def pose(self, frame, rots, loc=None):
        """rots: {bone: (rx, ry, rz)}; every animated bone gets a key so poses are absolute.
        Fingers (grip / relaxed) and hair (secondary sway) get automatic keys unless given."""
        rots = dict(finger_pose(self._name, frame, self._frames), **hair_pose(self._name, frame, self._frames), **rots)
        for pb in self.arm.pose.bones:
            rx, ry, rz = rots.get(pb.name, (0, 0, 0))
            pb.rotation_quaternion = self.q(pb.name, rx, ry, rz)
            pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
        hips = self.arm.pose.bones["hips"]
        r = self.rest["hips"]
        hips.location = r.inverted() @ Vector(loc or (0, 0, 0))
        hips.keyframe_insert("location", frame=frame, group="hips")

    def new_action(self, name, frames, loop):
        ad = self.arm.animation_data or self.arm.animation_data_create()
        ad.action = None
        for pb in self.arm.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
        self._name, self._frames, self._loop = name, frames, loop

    def finish(self):
        ad = self.arm.animation_data
        act = ad.action
        act.name = self._name
        act.use_fake_user = True
        act.use_frame_range = True
        act.frame_range = (1, self._frames)
        act.use_cyclic = self._loop
        track = ad.nla_tracks.new()
        track.name = self._name
        strip = track.strips.new(self._name, 1, act)
        strip.name = self._name
        track.mute = True
        ad.action = None
        return act


def mirror(r):
    """Mirror a left-side rotation to the right side (flip Y/Z)."""
    return (r[0], -r[1], -r[2])


def sym(rots_left, prefix_pairs=("shoulder", "upper_arm", "forearm", "hand", "thigh", "shin", "foot", "toe")):
    out = {}
    for k, v in rots_left.items():
        out[k] = v
    return out


ARM_DOWN_L = (0, 22, 0)      # from A-pose toward the body
ARM_DOWN_R = mirror(ARM_DOWN_L)


def base_arms(extra=None):
    d = {"upper_arm.L": ARM_DOWN_L, "upper_arm.R": ARM_DOWN_R,
         "forearm.L": (-12, 0, 0), "forearm.R": (-12, 0, 0)}
    d.update(extra or {})
    return d


def combine(*dicts):
    out = {}
    for d in dicts:
        for k, v in d.items():
            a = out.get(k, (0, 0, 0))
            out[k] = (a[0] + v[0], a[1] + v[1], a[2] + v[2])
    return out


def build_animations(arm):
    A = Animator(arm)
    acts = []

    # idle -------------------------------------------------------------
    A.new_action("idle", 60, True)
    for f in range(1, 62, 10):
        t = math.sin((f - 1) / 60 * 2 * math.pi)
        A.pose(f, combine(base_arms(), {
            "chest": (1.5 * t, 0, 0), "neck": (-1 * t, 0, 0), "head": (2, 0, 1.5 * t),
            "upper_arm.L": (1.5 * t, -1 * t, 0), "upper_arm.R": (1.5 * t, 1 * t, 0),
            "shin.L": (4, 0, 0), "thigh.L": (-2, 0, 2), "foot.L": (-2, 0, 0),
        }), loc=(0, 0, -0.004 * (1 + t)))
    acts.append(A.finish())

    # walk / run ------------------------------------------------------
    def gait(name, frames, stride, knee, arm_swing, elbow, lean, bob):
        A.new_action(name, frames, True)
        steps = 8
        for i in range(steps + 1):
            f = 1 + round(i * frames / steps)
            p = i / steps * 2 * math.pi
            s, c = math.sin(p), math.cos(p)
            A.pose(f, combine(base_arms({"forearm.L": (-elbow, 0, 0), "forearm.R": (-elbow, 0, 0)}), {
                "hips": (0, 0, 6 * s), "spine": (lean * 0.5, 0, -4 * s), "chest": (lean * 0.5, 0, -6 * s),
                "head": (-lean * 0.6, 0, 4 * s),
                "thigh.L": (-stride * s, 0, 0), "thigh.R": (stride * s, 0, 0),
                "shin.L": (knee * max(0, -c) + 5, 0, 0), "shin.R": (knee * max(0, c) + 5, 0, 0),
                "foot.L": (-8 * max(0, s), 0, 0), "foot.R": (-8 * max(0, -s), 0, 0),
                "upper_arm.L": (arm_swing * s, 0, 0), "upper_arm.R": (-arm_swing * s, 0, 0),
            }), loc=(0, 0, -bob * abs(c)))
        acts.append(A.finish())

    gait("walk", 32, 26, 40, 22, 18, 3, 0.02)
    gait("run", 20, 42, 85, 40, 80, 14, 0.045)

    # attack (overhead slash with the right hand) ---------------------
    A.new_action("attack", 36, False)
    ready = base_arms({"forearm.R": (-40, 0, 0), "upper_arm.R": (-20, -10, 0)})
    A.pose(1, combine(ready, {"thigh.L": (-12, 0, 0), "thigh.R": (10, 0, 0), "shin.L": (12, 0, 0), "shin.R": (8, 0, 0)}))
    A.pose(12, combine(base_arms({"upper_arm.R": (-15, 125, 0), "forearm.R": (-75, 0, 0), "upper_arm.L": (-30, 0, 0)}),
                       {"spine": (-8, 0, 12), "chest": (-10, 0, 18), "head": (8, 0, -12),
                        "thigh.L": (-22, 0, 0), "thigh.R": (18, 0, 0), "shin.L": (20, 0, 0), "shin.R": (14, 0, 0)}),
           loc=(0, 0.02, -0.02))
    A.pose(18, combine(base_arms({"upper_arm.R": (-35, 30, 0), "forearm.R": (-10, 0, 0), "upper_arm.L": (10, 0, 0)}),
                       {"spine": (18, 0, -15), "chest": (15, 0, -25), "head": (-12, 0, 18),
                        "thigh.L": (-35, 0, 0), "thigh.R": (25, 0, 0), "shin.L": (35, 0, 0), "shin.R": (10, 0, 0)}),
           loc=(0, -0.08, -0.07))
    A.pose(24, combine(base_arms({"upper_arm.R": (-30, 25, 0), "forearm.R": (-15, 0, 0)}),
                       {"spine": (14, 0, -12), "chest": (12, 0, -20), "head": (-10, 0, 14),
                        "thigh.L": (-32, 0, 0), "thigh.R": (22, 0, 0), "shin.L": (32, 0, 0), "shin.R": (10, 0, 0)}),
           loc=(0, -0.08, -0.07))
    A.pose(36, combine(ready, {"thigh.L": (-12, 0, 0), "thigh.R": (10, 0, 0), "shin.L": (12, 0, 0), "shin.R": (8, 0, 0)}))
    acts.append(A.finish())

    # cast (arcane gesture) -------------------------------------------
    A.new_action("gadget", 48, False)
    A.pose(1, base_arms())
    gather = base_arms({"upper_arm.L": (-45, 10, -30), "upper_arm.R": (-45, -10, 30),
                        "forearm.L": (-80, 0, 0), "forearm.R": (-80, 0, 0)})
    A.pose(16, combine(gather, {"chest": (-8, 0, 0), "head": (6, 0, 0), "shin.L": (10, 0, 0), "shin.R": (10, 0, 0)}), loc=(0, 0, -0.015))
    release = base_arms({"upper_arm.L": (-75, -5, -40), "upper_arm.R": (-75, 5, 40),
                         "forearm.L": (-5, 0, 0), "forearm.R": (-5, 0, 0), "hand.L": (-30, 0, 0), "hand.R": (-30, 0, 0)})
    A.pose(24, combine(release, {"chest": (8, 0, 0), "thigh.L": (-20, 0, 0), "shin.L": (18, 0, 0), "thigh.R": (12, 0, 0)}), loc=(0, -0.05, -0.03))
    A.pose(34, combine(release, {"chest": (8, 0, 0), "thigh.L": (-20, 0, 0), "shin.L": (18, 0, 0), "thigh.R": (12, 0, 0)}), loc=(0, -0.05, -0.03))
    A.pose(48, base_arms())
    acts.append(A.finish())

    # shoot (sidearm: raise, aim, recoil, lower) ----------------------
    A.new_action("shoot", 30, False)
    aim_pose = combine(base_arms({"upper_arm.R": (-78, 12, 28), "forearm.R": (-8, 0, 0), "hand.R": (0, 0, 0),
                                  "upper_arm.L": (-40, -5, -25), "forearm.L": (-60, 0, 0)}),
                       {"spine": (0, 0, 10), "chest": (0, 0, 14), "head": (0, 0, -18),
                        "thigh.L": (-14, 0, 0), "thigh.R": (10, 0, 0), "shin.L": (12, 0, 0), "shin.R": (6, 0, 0)})
    A.pose(1, base_arms())
    A.pose(8, aim_pose)
    A.pose(12, aim_pose)
    A.pose(14, combine(aim_pose, {"upper_arm.R": (-18, 0, 0), "forearm.R": (-10, 0, 0), "chest": (-4, 0, 0)}), loc=(0, 0.015, 0))
    A.pose(20, aim_pose)
    A.pose(30, base_arms())
    acts.append(A.finish())

    # guard (loop) ------------------------------------------------------
    A.new_action("guard", 30, True)
    for f, t in ((1, 0), (16, 1), (31, 0)):
        A.pose(f, combine(base_arms({"upper_arm.L": (-60, 35, -20), "forearm.L": (-95, 0, 0),
                                     "upper_arm.R": (-35, -20, 0), "forearm.R": (-70, 0, 0)}),
                          {"spine": (8, 0, 0), "chest": (6 + t, 0, 10), "head": (-6, 0, -8),
                           "thigh.L": (-25, 0, 4), "thigh.R": (10, 0, -4), "shin.L": (30, 0, 0), "shin.R": (22, 0, 0),
                           "foot.L": (-8, 0, 0)}), loc=(0, 0, -0.06 - 0.005 * t))
    acts.append(A.finish())

    # hit reaction --------------------------------------------------------
    A.new_action("hit", 20, False)
    A.pose(1, base_arms())
    A.pose(4, combine(base_arms({"upper_arm.L": (20, -15, 0), "upper_arm.R": (20, 15, 0), "forearm.L": (-40, 0, 0), "forearm.R": (-40, 0, 0)}),
                      {"spine": (-10, 0, 5), "chest": (-14, 0, 6), "head": (-22, 0, 10), "shin.L": (15, 0, 0), "shin.R": (10, 0, 0)}),
           loc=(0, 0.06, -0.02))
    A.pose(10, combine(base_arms(), {"spine": (6, 0, 0), "chest": (4, 0, 0), "head": (6, 0, 0), "shin.L": (8, 0, 0)}), loc=(0, 0.04, -0.01))
    A.pose(20, base_arms())
    acts.append(A.finish())

    # death ----------------------------------------------------------------
    A.new_action("death", 48, False)
    A.pose(1, base_arms())
    A.pose(10, combine(base_arms({"upper_arm.L": (10, -20, 0), "upper_arm.R": (10, 20, 0)}),
                       {"spine": (-12, 0, 0), "chest": (-15, 0, 0), "head": (-20, 0, 0), "shin.L": (40, 0, 0), "shin.R": (35, 0, 0),
                        "thigh.L": (-30, 0, 0), "thigh.R": (-25, 0, 0)}), loc=(0, 0.05, -0.2))
    A.pose(22, combine(base_arms({"upper_arm.L": (20, -40, 0), "upper_arm.R": (20, 40, 0)}),
                       {"hips": (-60, 0, 0), "spine": (-10, 0, 0), "chest": (-8, 0, 0), "head": (-10, 0, 0),
                        "thigh.L": (-40, 0, 0), "thigh.R": (-30, 0, 0), "shin.L": (70, 0, 0), "shin.R": (60, 0, 0)}), loc=(0, 0.25, -0.55))
    down = combine(base_arms({"upper_arm.L": (30, -60, 0), "upper_arm.R": (30, 60, 0), "forearm.L": (-10, 0, 0)}),
                   {"hips": (-88, 0, 0), "spine": (-2, 0, 0), "head": (5, 0, 20),
                    "thigh.L": (-5, 0, 0), "thigh.R": (-12, 0, 0), "shin.L": (15, 0, 0), "shin.R": (25, 0, 0)})
    A.pose(30, down, loc=(0, 0.72, -0.82))
    A.pose(48, down, loc=(0, 0.72, -0.82))
    acts.append(A.finish())

    # victory -----------------------------------------------------------
    A.new_action("victory", 48, False)
    A.pose(1, base_arms())
    raised = base_arms({"upper_arm.R": (-25, 110, 0), "forearm.R": (-25, 0, 0), "upper_arm.L": (0, 10, 0), "forearm.L": (-50, 0, 0)})
    A.pose(14, combine(raised, {"chest": (-8, 0, -6), "head": (-12, 0, -8), "thigh.L": (-8, 0, 0), "thigh.R": (6, 0, 0)}), loc=(0, 0, 0.01))
    A.pose(48, combine(raised, {"chest": (-6, 0, -6), "head": (-10, 0, -8), "thigh.L": (-8, 0, 0), "thigh.R": (6, 0, 0)}), loc=(0, 0, 0.005))
    acts.append(A.finish())

    for act in acts:
        for fc in act_fcurves(act):
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
    return acts


def act_fcurves(act):
    if hasattr(act, "fcurves") and act.fcurves is not None:
        try:
            return list(act.fcurves)
        except TypeError:
            pass
    curves = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves += list(bag.fcurves)
    return curves


# --------------------------------------------------------------------------
# Customization (Blender side): custom properties + drivers on visibility
# --------------------------------------------------------------------------
ACCESSORY_PROPS = ["scarf", "cloak", "satchel", "goggles", "gloves"]


def add_customization(arm, outfits, hair_styles, face, accessories, weapons):
    """Custom properties on HeroRig drive visibility/shape keys (Blender-side customizer)."""
    outfit_keys, hair_keys = list(outfits), list(hair_styles)
    arm["outfit"], arm["hair"], arm["expression"], arm["weapon"] = 0, 0, 0, 1
    arm.id_properties_ui("outfit").update(min=0, max=len(outfit_keys) - 1, description=", ".join(outfit_keys))
    arm.id_properties_ui("hair").update(min=0, max=len(hair_keys) - 1, description=", ".join(hair_keys))
    arm.id_properties_ui("expression").update(min=0, max=len(EXPRESSIONS),
                                              description="0 neutral, " + ", ".join(f"{i+1} {e}" for i, e in enumerate(EXPRESSIONS)))
    arm.id_properties_ui("weapon").update(min=0, max=2, description="0 none, 1 baton, 2 pistol")
    for k in ACCESSORY_PROPS:
        arm[f"acc_{k}"] = 1
        arm.id_properties_ui(f"acc_{k}").update(min=0, max=1)

    def vis_driver(obj, prop, expr):
        for path in ("hide_viewport", "hide_render"):
            d = obj.driver_add(path).driver
            d.type = "SCRIPTED"
            v = d.variables.new()
            v.name = "v"
            v.targets[0].id = arm
            v.targets[0].data_path = f'["{prop}"]'
            d.expression = expr

    for i, k in enumerate(outfit_keys):
        for o in outfits[k][1]:
            vis_driver(o, "outfit", f"v != {i}")
    for i, k in enumerate(hair_keys):
        vis_driver(hair_styles[k], "hair", f"v != {i}")
    for k, objs in accessories.items():
        for o in objs:
            vis_driver(o, f"acc_{k}", "v == 0")
    for i, (k, o) in enumerate(weapons.items()):
        vis_driver(o, "weapon", f"v != {i + 1}")
    for i, e in enumerate(EXPRESSIONS):
        d = face.data.shape_keys.key_blocks[e].driver_add("value").driver
        d.type = "SCRIPTED"
        v = d.variables.new()
        v.name = "v"
        v.targets[0].id_type = "OBJECT"
        v.targets[0].id = arm
        v.targets[0].data_path = '["expression"]'
        d.expression = f"1.0 if v == {i + 1} else 0.0"


def set_variant(arm, outfit=None, hair=None, expression=None, weapon=None, **acc):
    for k, v in (("outfit", outfit), ("hair", hair), ("expression", expression), ("weapon", weapon)):
        if v is not None:
            arm[k] = v
    for k, v in acc.items():
        arm[f"acc_{k}"] = v
    arm.update_tag()
    bpy.context.view_layer.update()
    bpy.context.scene.frame_set(bpy.context.scene.frame_current)


# --------------------------------------------------------------------------
# Look-dev scene: Rust Harbor daylight (warm sun, cool slate-blue sky fill)
# --------------------------------------------------------------------------
def build_stage(col):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 768, 1024
    scn.render.film_transparent = False
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    world = bpy.data.worlds.new("HarborSky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.50, 0.58, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scn.world = world

    sun_d = bpy.data.lights.new("Sun_Warm", "SUN")
    sun_d.color = (1.0, 0.9, 0.76)
    sun_d.energy = 4.0
    sun_d.angle = math.radians(8)
    sun = bpy.data.objects.new("Sun_Warm", sun_d)
    sun.location = (-2, -3, 4)
    col.objects.link(sun)
    aim(sun, (0, 0, 1.0))

    tile = box("Stage_Dock", col, (3.0, 3.0, 0.1), (0, 0.6, -0.05), material("dock", color=(0.30, 0.22, 0.15)), bevel=0.01)
    me = bpy.data.meshes.new("Stage_Backdrop")
    me.from_pydata([(-3.6, 2.6, -0.3), (3.6, 2.6, -0.3), (3.6, 2.6, 4.5), (-3.6, 2.6, 4.5)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new(name="UVMap")
    for li, c in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
        uv.data[li].uv = c
    backdrop = bpy.data.objects.new("Stage_Backdrop", me)
    col.objects.link(backdrop)
    backdrop.data.materials.append(backdrop_material())
    watercolor_compositor(scn)

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    col.objects.link(cam)
    place_cam(cam, *CAM_FULL)
    scn.camera = cam
    return cam, [tile, backdrop]


def backdrop_material():
    """ima2 Rust Harbor clean plate (generated from the approved master 01) as a backdrop."""
    path = os.path.join(ROOT, "concept", "03_bg_rust_harbor_clean_plate.png")
    if not os.path.exists(path):
        return material("backdrop", color=(0.78, 0.74, 0.66), textured=False, ink=True)
    mat = bpy.data.materials.new("M_backdrop_harbor")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 0.9
    nt.links.new(tex.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    return mat


def watercolor_compositor(scn):
    """Light classic Kuwahara softens the washes into pigment pools without smearing the ink."""
    try:
        tree = bpy.data.node_groups.new("WatercolorWash", "CompositorNodeTree")
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = tree.nodes.new("CompositorNodeRLayers")
        kw = tree.nodes.new("CompositorNodeKuwahara")
        kw.inputs["Type"].default_value = "Classic"
        kw.inputs["Size"].default_value = 3
        out = tree.nodes.new("NodeGroupOutput")
        tree.links.new(rl.outputs["Image"], kw.inputs["Image"])
        tree.links.new(kw.outputs[0], out.inputs[0])
        scn.compositing_node_group = tree
    except Exception as exc:  # compositor API differs between Blender versions
        print("WARN watercolor compositor unavailable:", exc)


CAM_FULL = ((0.95, -2.9, 1.25), (0, 0, 0.93), 50)
CAM_HAIR = ((0.55, -1.25, 1.71), (0, 0, 1.62), 85)
CAM_FACE = ((0.12, -0.95, 1.665), (0, 0, 1.642), 110)


def aim(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def place_cam(cam, loc, target, lens):
    cam.location = loc
    aim(cam, target)
    cam.data.lens = lens


def render(path, frame=None):
    scn = bpy.context.scene
    if frame is not None:
        scn.frame_set(frame)
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


# --------------------------------------------------------------------------
def main():
    reset_scene()
    root = collection("BountyHavenHero")
    rig_col = collection("Rig", root)
    body_col = collection("Body", root)
    arm = build_armature(rig_col)

    body = build_body(body_col)
    activate(arm)
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    smooth_weights(body, iters=4)
    if not body.vertex_groups or all(len(v.groups) == 0 for v in body.data.vertices[:10]):
        print("WARN: automatic weights failed, falling back to envelopes")
        bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
    set_material(body, material("skin"))

    head = build_head(body_col)
    set_material(head, material("skin"))
    bind(head, arm, bone="head")
    face = build_face(body_col, head)
    bind(face, arm, bone="head")

    outfits = build_outfits(body, arm, root)
    acc_col, accessories = build_accessories(body, arm, root)
    hair_col, hair_styles = build_hair(root)
    for o in hair_styles.values():
        skin_hair(o, arm)
    fingers = build_fingers(body_col, arm)
    weapons = build_weapons(collection("Weapon", root), arm)

    accessories["gloves"].append(fingers["Acc_GloveFingers"])
    everything = ([body, head] + list(fingers.values()) + [x for _, items in outfits.values() for x in items] + list(hair_styles.values())
                  + [x for objs in accessories.values() for x in objs] + list(weapons.values()))
    for o in everything:
        smart_uv(o)
        add_outline(o, 0.005 if o is head else 0.003 if o.name.startswith("Hair_") else 0.006)

    acts = build_animations(arm)
    for pb in arm.pose.bones:  # leave the file in rest pose
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    add_customization(arm, outfits, hair_styles, face, accessories, weapons)

    os.makedirs(OUT_DIR, exist_ok=True)
    blend_path = os.path.join(HERE, "bountyhaven_hero.blend")

    # --- previews -------------------------------------------------------
    renders = os.path.join(ROOT, "renders")
    os.makedirs(renders, exist_ok=True)
    stage_col = collection("Stage")
    cam, stage_objs = build_stage(stage_col)
    set_npr(True)
    if DO_RENDER:
        ad = arm.animation_data
        for i, k in enumerate(outfits):
            set_variant(arm, outfit=i, hair=[0, 1, 2, 5][i % 4], expression=0)
            render(os.path.join(renders, f"outfit_{i}_{k}.png"), frame=1)
        # hair lineup (close-up)
        place_cam(cam, *CAM_HAIR)
        set_variant(arm, outfit=0)
        for i, k in enumerate(hair_styles):
            set_variant(arm, hair=i)
            render(os.path.join(renders, f"hair_{i}_{k}.png"), frame=1)
        set_variant(arm, hair=0)
        place_cam(cam, *CAM_FACE)
        for i, e in enumerate(["neutral"] + EXPRESSIONS):
            set_variant(arm, expression=i)
            render(os.path.join(renders, f"expr_{i}_{e}.png"), frame=1)
        set_variant(arm, expression=0)
        place_cam(cam, *CAM_FULL)
        set_variant(arm, outfit=0, hair=0)
        for act in acts:
            set_variant(arm, weapon=2 if act.name == "shoot" else 1)
            ad.action = act
            fr = int(act.frame_range[1])
            for j, f in enumerate(sorted({1, max(1, fr // 3), max(1, 2 * fr // 3), fr})):
                render(os.path.join(renders, f"anim_{act.name}_{j}.png"), frame=f)
        ad.action = None
        set_variant(arm, outfit=0, hair=0, expression=0, weapon=1)
        # accessory lineup: none -> full kit
        for i, kit in enumerate([dict(scarf=0, cloak=0, satchel=0, goggles=0, gloves=0),
                                 dict(scarf=1, cloak=0, satchel=0, goggles=0, gloves=1),
                                 dict(scarf=1, cloak=1, satchel=1, goggles=0, gloves=1),
                                 dict(scarf=1, cloak=1, satchel=1, goggles=1, gloves=1)]):
            set_variant(arm, **kit)
            render(os.path.join(renders, f"acc_{i}.png"), frame=1)

    # --- save + export --------------------------------------------------
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    set_npr(False)  # glTF reads the Principled BSDF branch

    # glTF: exclude the look-dev stage, export every variant (the game toggles them)
    for o in stage_objs + [cam] + [o for o in stage_col.objects if o.type == "LIGHT"]:
        o.select_set(False)
    # drivers hide inactive variants; unhide everything for export
    hidden = []
    for o in bpy.data.objects:
        if o.animation_data:
            for fc in list(o.animation_data.drivers):
                if fc.data_path in ("hide_viewport", "hide_render"):
                    hidden.append(o)
                    o.animation_data.drivers.remove(fc)
            o.hide_viewport = o.hide_render = False
    if face.data.shape_keys.animation_data:
        for fc in list(face.data.shape_keys.animation_data.drivers):
            face.data.shape_keys.animation_data.drivers.remove(fc)
    stage_col.hide_viewport = True
    for o in bpy.data.objects:
        o.select_set(o.name not in {x.name for x in stage_col.objects})
    glb = os.path.join(OUT_DIR, "bountyhaven_hero.glb")
    bpy.ops.export_scene.gltf(
        filepath=glb, export_format="GLB", use_selection=True, export_apply=True,
        export_animations=True, export_animation_mode="ACTIONS", export_morph=True,
        export_skins=True, export_yup=True)
    print("EXPORTED", glb, os.path.getsize(glb))
    print("SAVED", blend_path)


if __name__ == "__main__":
    main()
