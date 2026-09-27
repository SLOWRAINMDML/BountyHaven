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
    y = -4.0 if side == "front" else 4.0
    cam.location = (cx, y, cz)
    bc.aim(cam, (cx, 0, cz))
    scn.camera = cam
    return cam


def project_uv(obj, frame, half_of=None):
    """UV 'Paint': front-facing faces -> left half (front image), others -> right half (back image)."""
    cx, cz, s = frame
    me = obj.data
    uv = me.uv_layers.get("Paint") or me.uv_layers.new(name="Paint")
    mw = obj.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    for p in me.polygons:
        n = (nm @ p.normal)
        back = half_of == "back" or (half_of is None and n.y > 0.0)
        for li in p.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            u = ((co.x - cx) / s + 0.5) if not back else ((-(co.x - cx)) / s + 0.5)
            v = (co.z - cz) / s + 0.5
            u = min(max(u, 0.001), 0.999)
            uv.data[li].uv = (u * 0.5 + (0.5 if back else 0.0), min(max(v, 0.001), 0.999))
    me.uv_layers.active = uv
    uv.active_render = True
    # drop the old box-projection UVs so glTF carries a single TEXCOORD_0
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
        for side in ("front", "back"):
            shot(f"body_{o}", BODY_FRAME, side)
    bc.set_variant(arm, outfit=0)
    for i, h in enumerate(HAIRS):
        bc.set_variant(arm, hair=i)
        for side in ("front", "back"):
            shot(f"hair_{h}", HEAD_FRAME, side)
    bc.set_variant(arm, hair=-1)  # bare head for the face paint
    for side in ("front", "back"):
        shot("head_bare", HEAD_FRAME, side)
    print("RENDERED", os.path.join(PAINT, "renders"))


# --------------------------------------------------------------------------
def atlas(front, back, out):
    """Side-by-side [front | back] atlas image, built inside Blender (no PIL needed)."""
    import numpy as np
    imgs = []
    for p in (front, back):
        im = bpy.data.images.load(p, check_existing=False)  # always read the current file
        im.scale(RES, RES)
        imgs.append(np.array(im.pixels[:], dtype=np.float32).reshape(RES, RES, 4))
        bpy.data.images.remove(im)
    a = np.concatenate(imgs, axis=1)
    a[..., 3] = 1.0
    stale = bpy.data.images.get(os.path.basename(out)[:-4])
    if stale:
        bpy.data.images.remove(stale)
    img = bpy.data.images.new(os.path.basename(out)[:-4], RES * 2, RES, alpha=False)
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

    def have(name):
        return all(os.path.exists(os.path.join(painted, f"{name}_{s}.png")) for s in ("front", "back"))

    for kind, keys, frame in (("body", OUTFITS, BODY_FRAME), ("hair", HAIRS, HEAD_FRAME)):
        for k in keys:
            name = f"{kind}_{k}"
            if not have(name):
                print("SKIP (not painted yet)", name)
                continue
            img = atlas(os.path.join(painted, f"{name}_front.png"), os.path.join(painted, f"{name}_back.png"),
                        os.path.join(PAINT, "atlas", f"{name}.png"))
            mat = paint_material(f"paint_{name}", img)
            for o in objects_for_pass(kind, k):
                project_uv(o, frame)
                assign(o, mat)
            print("PAINTED", name)

    # head: neutral + expression textures (front changes, back is shared)
    head = bpy.data.objects["Head"]
    back = os.path.join(painted, "head_bare_back.png")
    face_imgs = {}
    for e in EXPR:
        front = os.path.join(painted, f"face_{e}.png")
        if os.path.exists(front) and os.path.exists(back):
            face_imgs[e] = atlas(front, back, os.path.join(tex_dir, f"head_{e}.jpg"))
            face_imgs[e].use_fake_user = True  # keep unused expressions in the .blend
    if "neutral" in face_imgs:
        project_uv(head, HEAD_FRAME)
        mat = paint_material("paint_head", face_imgs["neutral"])
        assign(head, mat)
        bpy.data.objects["Face"].hide_render = bpy.data.objects["Face"].hide_viewport = True
        head["expression_textures"] = ",".join(face_imgs)
        # Blender-side expression swap: a driver can't swap images, so a handler does it on frame change
        txt = bpy.data.texts.get("expression_swap.py") or bpy.data.texts.new("expression_swap.py")
        txt.from_string(EXPR_HANDLER)
        txt.use_module = True
        print("PAINTED head", list(face_imgs))

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
    ad = arm.animation_data
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
