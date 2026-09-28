"""Paint-over projection: lift the procedural hero to illustration level.

  1. render : orthographic front/back renders of every outfit, hair style and the bare head
              -> paint/renders/<pass>_<side>.png (transparent background)
  2. (ima2) : paint/run_paint.py repaints each render in the BountyHaven ink & watercolor style
              -> paint/painted/<pass>_<side>.png, registered back onto the render silhouette
  3. apply  : each mesh gets a "Paint" UV (front half / back half of an atlas, chosen per face
              by its facing) and a material using that atlas; head expressions are texture swaps.
              Saves blender/bountyhaven_hero.blend, exports the GLB and textures.

  blender -b blender/bountyhaven_hero.blend -P blender/paint_project.py -- render
  blender -b blender/bountyhaven_hero.blend -P blender/paint_project.py -- apply
"""
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.dirname(__file__))
import build_character as bc  # noqa: E402

ROOT = bc.ROOT
PAINT = os.path.join(ROOT, "paint")
MODE = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "render"
RES = 1024

OUTFITS = ["pilot", "vest", "mechanic", "guild"]
HAIRS = ["tousled", "windswept", "tied_low", "tidy_crop", "messy_long", "travel_braid"]
EXPR = ["neutral"] + bc.EXPRESSIONS

SIDES = ("front", "back", "left", "right")  # atlas quadrants: top row front|back, bottom row left|right
# frame = (centre x, centre z, ortho scale)
BODY_FRAME = (0.0, 0.94, 2.0)
HEAD_FRAME = (0.0, 1.64, 0.62)

arm = bpy.data.objects["HeroRig"]
scn = bpy.context.scene


def rest_pose():
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    bpy.context.view_layer.update()


def ortho_cam(frame, side):
    cx, cz, s = frame
    cam = bpy.data.objects.get("PaintCam") or bpy.data.objects.new("PaintCam", bpy.data.cameras.new("PaintCam"))
    if cam.name not in scn.collection.objects:
        scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = s
    cam.location = {"front": (cx, -4.0, cz), "back": (cx, 4.0, cz), "left": (4.0, 0, cz), "right": (-4.0, 0, cz)}[side]
    bc.aim(cam, (cx if side in ("front", "back") else 0, 0, cz))
    scn.camera = cam
    return cam


def image_uv(co, frame, side):
    """Where a world point lands in the orthographic image of `side` (0..1, 0..1)."""
    cx, cz, s = frame
    h = {"front": co.x - cx, "back": -(co.x - cx), "left": co.y, "right": -co.y}[side]
    return h / s + 0.5, (co.z - cz) / s + 0.5


VIEW_DIR = {"front": Vector((0, -1, 0)), "back": Vector((0, 1, 0)), "left": Vector((1, 0, 0)), "right": Vector((-1, 0, 0))}


def occluded(origin, direction, own):
    """True when something (e.g. the A-pose arm) sits between this point and the side camera."""
    dg = bpy.context.evaluated_depsgraph_get()
    hit, loc, _, _, ob, _ = scn.ray_cast(dg, origin, direction, distance=3.0)
    return bool(hit) and (loc - origin).length > 0.01


def project_uv(obj, frame, bias=None):
    """UV 'Paint': each face samples the view that sees it most squarely (4-quadrant atlas)."""
    me = obj.data
    uv = me.uv_layers.get("Paint") or me.uv_layers.new(name="Paint")
    mw = obj.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    for p in me.polygons:
        n = (nm @ p.normal).normalized()
        score = {"front": -n.y, "back": n.y, "left": n.x, "right": -n.x}
        for k, b in (bias or {}).items():
            score[k] = score[k] * b if score[k] > 0 else score[k]
        centre = mw @ p.center
        side = max(score, key=score.get)
        for cand in sorted(score, key=score.get, reverse=True):
            if score[cand] < 0.15:
                break
            if not occluded(centre + n * 0.004, VIEW_DIR[cand], obj):
                side = cand
                break
        q = SIDES.index(side)
        u0, v0 = (q % 2) * 0.5, (0.5 if q < 2 else 0.0)
        for li in p.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            u, v = image_uv(co, frame, side)
            uv.data[li].uv = (u0 + 0.5 * min(max(u, 0.002), 0.998), v0 + 0.5 * min(max(v, 0.002), 0.998))
    me.uv_layers.active = uv
    uv.active_render = True
    # drop the old box-projection UVs so glTF carries a single TEXCOORD_0
    for layer in list(me.uv_layers):
        if layer.name != "Paint":
            me.uv_layers.remove(layer)


def skin_patch_uv(obj, frame):
    """Map every vertex into a small forehead window of the front quadrant: painted skin with
    the same pigment grain as the face, and the knuckle shading from the toon washes."""
    me = obj.data
    uv = me.uv_layers.get("Paint") or me.uv_layers.new(name="Paint")
    cx, cz, s = frame
    u0, v0 = image_uv(Vector((0.0, 0, 1.672)), frame, "front")  # mid forehead, under the fringe
    for p in me.polygons:
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            du = (co.y * 0.6 + co.x * 0.2) % 0.02 - 0.01
            dv = (co.z * 0.6) % 0.02 - 0.01
            uv.data[li].uv = (0.5 * (u0 + du), 0.5 + 0.5 * (v0 + dv))
    me.uv_layers.active = uv
    uv.active_render = True
    for layer in list(me.uv_layers):
        if layer.name != "Paint":
            me.uv_layers.remove(layer)


def objects_for_pass(kind, key):
    objs = bpy.data.objects
    if kind == "body":
        prefix = f"Outfit_{key.capitalize()}_"
        sel = [o for o in objs if o.type == "MESH" and o.name.startswith(prefix)]
        if key == "pilot":  # shared skin + accessories take their paint from the default outfit
            # goggles are hidden in the paint renders, so they keep their palette material
            sel += [objs["Body"]] + [o for o in objs if o.type == "MESH" and o.name.startswith("Acc_")
                                     and not o.name.startswith("Acc_Goggles")]
        return sel
    if kind == "hair":
        return [objs[f"Hair_{key}"]]
    if kind == "head":
        return [objs["Head"]]
    return []


# --------------------------------------------------------------------------
def do_render():
    os.makedirs(os.path.join(PAINT, "renders"), exist_ok=True)
    rest_pose()
    bc.set_npr(True)
    scn.render.resolution_x = scn.render.resolution_y = RES
    scn.render.film_transparent = True
    scn.compositing_node_group = None
    for o in bpy.data.collections["Stage"].objects:
        o.hide_render = True
    bc.set_variant(arm, weapon=0, expression=0, scarf=1, cloak=1, satchel=1, goggles=0, gloves=1)

    def shot(name, frame, side):
        ortho_cam(frame, side)
        scn.render.filepath = os.path.join(PAINT, "renders", f"{name}_{side}.png")
        bpy.ops.render.render(write_still=True)

    for i, o in enumerate(OUTFITS):
        bc.set_variant(arm, outfit=i, hair=0)
        for side in SIDES:
            shot(f"body_{o}", BODY_FRAME, side)
    bc.set_variant(arm, outfit=0)
    for i, h in enumerate(HAIRS):
        bc.set_variant(arm, hair=i)
        for side in SIDES:
            shot(f"hair_{h}", HEAD_FRAME, side)
    bc.set_variant(arm, hair=-1)  # bare head for the face paint
    for side in SIDES:
        shot("head_bare", HEAD_FRAME, side)
    print("RENDERED", os.path.join(PAINT, "renders"))


# --------------------------------------------------------------------------
def atlas(paths, out):
    """2x2 atlas [front | back] over [left | right] (Blender pixel rows start at the bottom)."""
    import numpy as np
    q = []
    for p in paths:
        im = bpy.data.images.load(p, check_existing=False)  # always read the current file
        im.scale(RES, RES)
        q.append(np.array(im.pixels[:], dtype=np.float32).reshape(RES, RES, 4))
        bpy.data.images.remove(im)
    a = np.concatenate([np.concatenate(q[2:4], axis=1), np.concatenate(q[0:2], axis=1)], axis=0)
    a[..., 3] = 1.0
    stale = bpy.data.images.get(os.path.basename(out)[:-4])
    if stale:
        bpy.data.images.remove(stale)
    img = bpy.data.images.new(os.path.basename(out)[:-4], RES * 2, RES * 2, alpha=False)
    img.pixels = a.ravel()
    img.filepath_raw = out
    img.file_format = "JPEG" if out.endswith(".jpg") else "PNG"
    scn.render.image_settings.quality = 92
    img.save()
    return img


def paint_material(name, img):
    bc._materials.pop(f"M_{name}", None)
    return bc.material(name, color=(1.0, 1.0, 1.0), image=img, soft=True)


def assign(obj, mat):
    """Replace every non-outline slot with the painted material."""
    slots = obj.data.materials
    for i, m in enumerate(slots):
        if m is None or m.name != "M_outline":
            slots[i] = mat
    # merge duplicate slots: point all faces that are not outline at slot 0
    out_idx = [i for i, m in enumerate(slots) if m and m.name == "M_outline"]
    for p in obj.data.polygons:
        if p.material_index not in out_idx:
            p.material_index = 0


def do_apply():
    rest_pose()
    for im in list(bpy.data.images):  # previous atlases: rebuilt below from the current paint
        if im.name.split(".")[0].startswith(("head_", "body_", "hair_", "face_")):
            bpy.data.images.remove(im)
    for m in list(bpy.data.materials):  # stale painted materials would shadow the new names
        if m.name.startswith("M_paint_"):
            bpy.data.materials.remove(m)
    tex_dir = os.path.join(ROOT, "exports", "textures")
    os.makedirs(tex_dir, exist_ok=True)
    os.makedirs(os.path.join(PAINT, "atlas"), exist_ok=True)
    painted = os.path.join(PAINT, "painted")
    stage = list(bpy.data.collections["Stage"].objects)
    for o in stage:  # the backdrop would block every back-view ray
        o.hide_viewport = True
    bc.set_variant(arm, weapon=0, goggles=0)  # occlusion as in the paint renders

    def have(name):
        return all(os.path.exists(os.path.join(painted, f"{name}_{s}.png")) for s in SIDES)

    for kind, keys, frame in (("body", OUTFITS, BODY_FRAME), ("hair", HAIRS, HEAD_FRAME)):
        for k in keys:
            name = f"{kind}_{k}"
            if not have(name):
                print("SKIP (not painted yet)", name)
                continue
            img = atlas([os.path.join(painted, f"{name}_{sd}.png") for sd in SIDES],
                        os.path.join(PAINT, "atlas", f"{name}.jpg"))
            mat = paint_material(f"paint_{name}", img)
            for o in objects_for_pass(kind, k):
                project_uv(o, frame)
                assign(o, mat)
            print("PAINTED", name)

    # head: neutral + expression textures (front changes, back is shared)
    head = bpy.data.objects["Head"]
    shared = [os.path.join(painted, f"head_bare_{sd}.png") for sd in SIDES[1:]]
    face_imgs = {}
    for e in EXPR:
        front = os.path.join(PAINT, "painted_remap", f"face_{e}.png")  # features moved to the illustration's heights
        if not os.path.exists(front):
            front = os.path.join(painted, f"face_{e}.png")
        if os.path.exists(front) and all(os.path.exists(p) for p in shared):
            face_imgs[e] = atlas([front] + shared, os.path.join(tex_dir, f"head_{e}.jpg"))
            face_imgs[e].use_fake_user = True  # keep unused expressions in the .blend
    if "neutral" in face_imgs:
        project_uv(head, HEAD_FRAME, bias={"front": 1.3, "back": 1.1})
        mat = paint_material("paint_head", face_imgs["neutral"])
        assign(head, mat)
        bpy.data.objects["Face"].hide_render = bpy.data.objects["Face"].hide_viewport = True
        head["expression_textures"] = ",".join(face_imgs)
        # Blender-side expression swap: a driver can't swap images, so a handler does it on frame change
        txt = bpy.data.texts.get("expression_swap.py") or bpy.data.texts.new("expression_swap.py")
        txt.from_string(EXPR_HANDLER)
        txt.use_module = True
        print("PAINTED head", list(face_imgs))
        fingers = bpy.data.objects.get("Fingers")
        if fingers:
            skin_patch_uv(fingers, HEAD_FRAME)
            fmat = paint_material("paint_fingers", face_imgs["neutral"])
            assign(fingers, fmat)
            bc.add_outline(fingers, 0.002) if not any(m.type == "SOLIDIFY" for m in fingers.modifiers) else None

    for o in stage:
        o.hide_viewport = False
    bc.set_variant(arm, weapon=1, goggles=1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bc.HERE, "bountyhaven_hero.blend"))
    export()
    if "--no-render" not in sys.argv:
        preview()


EXPR_HANDLER = '''import bpy

def _swap(scene, *_):
    arm = bpy.data.objects.get("HeroRig")
    mat = bpy.data.materials.get("M_paint_head")
    if not arm or not mat:
        return
    names = ["neutral", "focused", "gentle_smile", "determined", "surprised", "battle_ready", "tired", "worried", "eyes_closed"]
    e = names[int(arm.get("expression", 0)) % len(names)]
    img = bpy.data.images.get(f"head_{e}")
    node = mat.node_tree.nodes.get("PaintTex")
    if img and node and node.image != img:
        node.image = img

bpy.app.handlers.frame_change_pre.append(_swap)
bpy.app.handlers.depsgraph_update_post.append(_swap)
'''


def set_expression_texture(e):
    img = bpy.data.images.get(f"head_{e}")
    mat = bpy.data.materials.get("M_paint_head")
    if img and mat:
        mat.node_tree.nodes["PaintTex"].image = img


def export():
    """glTF export of every variant (drivers stripped, everything visible, stage excluded)."""
    bc.set_npr(False)
    for o in bpy.data.objects:
        if o.animation_data:
            for fc in list(o.animation_data.drivers):
                if fc.data_path in ("hide_viewport", "hide_render"):
                    o.animation_data.drivers.remove(fc)
        o.hide_viewport = o.hide_render = False
    face = bpy.data.objects["Face"]
    stage = {o.name for o in bpy.data.collections["Stage"].objects} | {"PaintCam"}
    for o in bpy.data.objects:
        o.select_set(o.name not in stage and o is not face)
    glb = os.path.join(ROOT, "exports", "bountyhaven_hero.glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_morph=True,
                              export_skins=True, export_yup=True,
                              export_image_format="JPEG", export_jpeg_quality=90)
    print("EXPORTED", glb, os.path.getsize(glb))


def preview():
    """Reload the saved (driver-intact) file state and render the review sheets."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(bc.HERE, "bountyhaven_hero.blend"))
    global arm, scn
    arm, scn = bpy.data.objects["HeroRig"], bpy.context.scene
    bc.set_npr(True)
    rest_pose()
    cam = bpy.data.objects["Cam"]
    out = os.path.join(ROOT, "renders")
    scn.render.resolution_x, scn.render.resolution_y = 768, 1024
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = bpy.data.actions["idle"]  # show the look in a natural stance, not the bind A-pose
    for i, k in enumerate(OUTFITS):
        bc.set_variant(arm, outfit=i, hair=[0, 1, 2, 5][i], expression=0, weapon=1)
        bc.place_cam(cam, *bc.CAM_FULL)
        bc.render(os.path.join(out, f"outfit_{i}_{k}.png"), frame=1)
    bc.set_variant(arm, outfit=0)
    bc.place_cam(cam, *bc.CAM_HAIR)
    for i, h in enumerate(HAIRS):
        bc.set_variant(arm, hair=i)
        bc.render(os.path.join(out, f"hair_{i}_{h}.png"), frame=1)
    bc.set_variant(arm, hair=0)
    bc.place_cam(cam, *bc.CAM_FACE)
    for i, e in enumerate(EXPR):
        bc.set_variant(arm, expression=i)
        set_expression_texture(e)
        bc.render(os.path.join(out, f"expr_{i}_{e}.png"), frame=1)
    set_expression_texture("neutral")
    bc.set_variant(arm, expression=0)
    bc.place_cam(cam, *bc.CAM_FULL)
    for act in [a for a in bpy.data.actions if a.use_fake_user]:
        bc.set_variant(arm, weapon=2 if act.name == "shoot" else 1)
        ad.action = act
        fr = int(act.frame_range[1])
        for j, f in enumerate(sorted({1, max(1, fr // 3), max(1, 2 * fr // 3), fr})):
            bc.render(os.path.join(out, f"anim_{act.name}_{j}.png"), frame=f)
    ad.action = None


if MODE == "render":
    do_render()
elif MODE == "apply":
    do_apply()
