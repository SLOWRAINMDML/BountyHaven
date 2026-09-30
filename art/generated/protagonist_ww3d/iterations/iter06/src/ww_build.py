"""BountyHaven protagonist, anime action-RPG (toon) 3D build from scratch.

blender -b --factory-startup -P ww_build.py -- --out <dir> [--views] [--vfx] [--glb path] [--blend path]

Every proportion comes from measure/landmarks.json (canonical design sheet, crop pixels).
World: metres, +Z up, character faces -Y, character's left = +X, soles at z=0.
"""
import bpy, bmesh, json, math, os, random, sys
from mathutils import Vector, Matrix, noise

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


LM = json.load(open(os.path.join(ROOT, "measure", "landmarks.json")))
FY, FX, SD = LM["front_y"], LM["front_x"], LM["side_depth"]
HEIGHT = 1.78
PX = HEIGHT / (FY["sole"] - FY["hair_top"])          # metres per crop pixel


def Z(key):
    return (FY["sole"] - FY[key]) * PX


def W(px):
    return px * PX


random.seed(7)
CONCEPTS = os.path.join(ROOT, "concepts")
TEX = os.path.join(ROOT, "exports", "textures")
os.makedirs(TEX, exist_ok=True)

# ----------------------------------------------------------------------------- scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.render.film_transparent = True
world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.82, 0.86, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.0

sun_data = bpy.data.lights.new("Key", "SUN")
sun_data.energy = 3.0
sun_data.use_shadow = False
sun = bpy.data.objects.new("Key", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))   # from front-left-top
KEY_DIR = (sun.matrix_world.to_3x3() @ Vector((0, 0, 1))).normalized()

COLL = bpy.data.collections.new("Hero")
scene.collection.children.link(COLL)


def srgb(c):
    return tuple(((v / 255.0) if v > 1 else v) ** 2.2 for v in c)


# ----------------------------------------------------------------------------- materials
MATS = {}


def toon(name, lit, shade, tex=None, tex_mix=1.0, rim=0.18, rim_col=(0.75, 0.85, 1.0), emit=None,
         alpha_tex=None, step=(0.42, 0.52), outline=None):
    """Cel material: lit/shade colours switched by a soft Diffuse ramp, plus rim light.

    tex multiplies both lit and shade colours (tex_mix blends it toward white)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    dif = N.new("ShaderNodeBsdfDiffuse")
    s2r = N.new("ShaderNodeShaderToRGB")
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "EASE"
    ramp.color_ramp.elements[0].position = step[0]
    ramp.color_ramp.elements[1].position = step[1]
    L.new(dif.outputs[0], s2r.inputs[0])
    L.new(s2r.outputs[0], ramp.inputs[0])
    e_lit = N.new("ShaderNodeEmission")
    e_sh = N.new("ShaderNodeEmission")
    lit_c, sh_c = srgb(lit), srgb(shade)
    if tex:
        img = N.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(tex, check_existing=True)
        img.interpolation = "Linear"
        base = img.outputs[0]
        if tex_mix < 1.0:
            mix = N.new("ShaderNodeVectorMath")
            mix.operation = "MULTIPLY_ADD"          # tex*k + (1-k)
            mix.inputs[1].default_value = (tex_mix,) * 3
            mix.inputs[2].default_value = (1 - tex_mix,) * 3
            L.new(base, mix.inputs[0])
            base = mix.outputs[0]
        for e, c in ((e_lit, lit_c), (e_sh, sh_c)):
            mul = N.new("ShaderNodeVectorMath")
            mul.operation = "MULTIPLY"
            mul.inputs[1].default_value = c
            L.new(base, mul.inputs[0])
            L.new(mul.outputs[0], e.inputs[0])
        m["tex_node"] = img.name
    else:
        e_lit.inputs[0].default_value = (*lit_c, 1)
        e_sh.inputs[0].default_value = (*sh_c, 1)
    mixs = N.new("ShaderNodeMixShader")
    L.new(ramp.outputs[0], mixs.inputs[0])
    L.new(e_sh.outputs[0], mixs.inputs[1])
    L.new(e_lit.outputs[0], mixs.inputs[2])
    shader = mixs.outputs[0]
    if rim > 0:
        lw = N.new("ShaderNodeLayerWeight")
        lw.inputs[0].default_value = 0.35
        rr = N.new("ShaderNodeValToRGB")
        rr.color_ramp.elements[0].position = 0.55
        rr.color_ramp.elements[1].position = 0.8
        L.new(lw.outputs[1], rr.inputs[0])
        rmul = N.new("ShaderNodeMath")
        rmul.operation = "MULTIPLY"
        rmul.inputs[1].default_value = rim
        L.new(rr.outputs[0], rmul.inputs[0])
        er = N.new("ShaderNodeEmission")
        er.inputs[0].default_value = (*srgb(rim_col), 1)
        L.new(rmul.outputs[0], er.inputs[1])
        add = N.new("ShaderNodeAddShader")
        L.new(shader, add.inputs[0])
        L.new(er.outputs[0], add.inputs[1])
        shader = add.outputs[0]
    if emit:
        ee = N.new("ShaderNodeEmission")
        ee.inputs[0].default_value = (*srgb(emit[0]), 1)
        ee.inputs[1].default_value = emit[1]
        add = N.new("ShaderNodeAddShader")
        L.new(shader, add.inputs[0])
        L.new(ee.outputs[0], add.inputs[1])
        shader = add.outputs[0]
    if alpha_tex:
        at = N.new("ShaderNodeTexImage")
        at.image = bpy.data.images.load(alpha_tex, check_existing=True)
        at.image.colorspace_settings.name = "Non-Color"
        tr = N.new("ShaderNodeBsdfTransparent")
        mx = N.new("ShaderNodeMixShader")
        # geometry UV used by default
        L.new(at.outputs[0], mx.inputs[0])
        L.new(tr.outputs[0], mx.inputs[1])
        L.new(shader, mx.inputs[2])
        shader = mx.outputs[0]
        m.surface_render_method = "DITHERED"
    L.new(shader, out.inputs[0])
    m["lit"], m["shade"] = list(lit), list(shade)
    m["outline"] = list(outline or [c * 0.35 for c in (srgb(shade))])
    MATS[name] = m
    return m


def outline_mat(col):
    key = "OL_%.3f_%.3f_%.3f" % tuple(col)
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    N = m.node_tree.nodes
    N.clear()
    e = N.new("ShaderNodeEmission")
    e.inputs[0].default_value = (*col, 1)
    o = N.new("ShaderNodeOutputMaterial")
    m.node_tree.links.new(e.outputs[0], o.inputs[0])
    m.use_backface_culling = True
    MATS[key] = m
    return m


# ----------------------------------------------------------------------------- geometry
def ring(n, rx, ryf, ryb, power=2.0, flat_front=None):
    """Superellipse cross-section, local 2D (x, y), y<0 is the front."""
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        c, s = math.cos(t), math.sin(t)
        pw = flat_front if (flat_front and s < 0) else power
        x = rx * math.copysign(abs(c) ** (2 / pw), c)
        y = math.copysign(abs(s) ** (2 / pw), s) * (ryf if s < 0 else ryb)
        pts.append((x, y))
    return pts


def mesh_from_grid(name, rows, closed=True, cap0=True, cap1=True):
    """rows: list of lists of Vector (same length). Returns object with UVs (u around, v along)."""
    n = len(rows[0])
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in r] for r in rows]
    uvl = bm.loops.layers.uv.new("UVMap")
    cols = n if closed else n - 1
    for k in range(len(rows) - 1):
        for i in range(cols):
            j = (i + 1) % n
            f = bm.faces.new((vs[k][i], vs[k][j], vs[k + 1][j], vs[k + 1][i]))
            uv = [(i / cols, k / (len(rows) - 1)), ((i + 1) / cols, k / (len(rows) - 1)),
                  ((i + 1) / cols, (k + 1) / (len(rows) - 1)), (i / cols, (k + 1) / (len(rows) - 1))]
            for lp, u in zip(f.loops, uv):
                lp[uvl].uv = u
    if closed:
        for idx, flag in ((0, cap0), (len(rows) - 1, cap1)):
            if not flag:
                continue
            c = bm.verts.new(sum((v.co for v in vs[idx]), Vector()) / n)
            for i in range(n):
                j = (i + 1) % n
                f = bm.faces.new((vs[idx][i], vs[idx][j], c) if idx else (vs[idx][j], vs[idx][i], c))
                for lp in f.loops:
                    lp[uvl].uv = (0.5, 1.0 if idx else 0.0)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    COLL.objects.link(ob)
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    return ob


def frames(path, up=Vector((0, -1, 0))):
    """Parallel-transport frames (x, y axes) along a polyline."""
    out = []
    t_prev = None
    x = None
    for i, p in enumerate(path):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, len(path) - 1)]
        t = (b - a).normalized()
        if x is None:
            x = t.cross(up).normalized()
            if x.length < 1e-4:
                x = t.orthogonal().normalized()
        else:
            x = (x - t * x.dot(t)).normalized()
        y = t.cross(x).normalized()
        out.append((x, y, t))
    return out


def tube(name, path, rx, ry, n=16, up=Vector((0, -1, 0)), power=2.0, twist=None, caps=(True, True), ryf=None):
    path = [Vector(p) for p in path]
    fr = frames(path, up)
    rows = []
    for k, (p, (x, y, t)) in enumerate(zip(path, fr)):
        a = twist[k] if twist else 0.0
        if a:
            q = Matrix.Rotation(a, 3, t)
            x, y = q @ x, q @ y
        yf = ryf[k] if ryf else ry[k]
        rows.append([p + x * px + y * py for px, py in ring(n, rx[k], yf, ry[k], power)])
    return mesh_from_grid(name, rows, cap0=caps[0], cap1=caps[1])


def lerp_profile(keys, samples):
    """keys: list of (t, value...) sorted; returns list of interpolated tuples at samples (smoothstep)."""
    out = []
    for s in samples:
        for a, b in zip(keys, keys[1:]):
            if a[0] <= s <= b[0]:
                u = (s - a[0]) / (b[0] - a[0] + 1e-9)
                u = u * u * (3 - 2 * u)
                out.append(tuple(av + (bv - av) * u for av, bv in zip(a[1:], b[1:])))
                break
        else:
            out.append(tuple(keys[0][1:] if s < keys[0][0] else keys[-1][1:]))
    return out


def loft_z(name, keys, n=24, steps=24, power=2.0, flat_front=None, cx=0.0, caps=(True, True), gap=None):
    """Vertical loft. keys: (z, half_width, y_center, depth_front, depth_back)."""
    zs = [keys[0][0] + (keys[-1][0] - keys[0][0]) * i / steps for i in range(steps + 1)]
    prof = lerp_profile(keys, zs)
    rows = []
    for z, (w, yc, df, db) in zip(zs, prof):
        rows.append([Vector((cx + x, yc + y, z)) for x, y in ring(n, w, df, db, power, flat_front)])
    if gap:
        # open front: drop the ring columns whose angle lies inside the gap (for jackets)
        keep = [i for i in range(n) if abs(((2 * math.pi * i / n) - 1.5 * math.pi)) > gap]
        start = keep.index(max(keep, key=lambda i: (i - int(n * 0.75)) % n))
        order = [keep[(start + 1 + j) % len(keep)] for j in range(len(keep))]
        rows = [[r[i] for i in order] for r in rows]
        return mesh_from_grid(name, rows, closed=False)
    return mesh_from_grid(name, rows, cap0=caps[0], cap1=caps[1])


def finish(ob, mat, subsurf=1, outline=0.0035, extra_mats=()):
    ob.data.materials.append(mat)
    for m in extra_mats:
        ob.data.materials.append(m)
    if subsurf:
        sm = ob.modifiers.new("Sub", "SUBSURF")
        sm.levels = subsurf
        sm.render_levels = subsurf
    if outline:
        olm = outline_mat(tuple(mat["outline"]))
        ob.data.materials.append(olm)
        so = ob.modifiers.new("Outline", "SOLIDIFY")
        so.thickness = outline
        so.offset = 1.0
        so.use_flip_normals = True
        so.use_rim = False
        so.material_offset = len(ob.data.materials) - 1
    return ob


def box(name, center, size, mat, bevel=0.3, subsurf=2, outline=0.0025, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    COLL.objects.link(ob)
    ob.location = center
    ob.rotation_euler = rot
    if bevel:
        b = ob.modifiers.new("Bevel", "BEVEL")
        b.width = min(size) * bevel
        b.segments = 2
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    return finish(ob, mat, subsurf=subsurf, outline=outline)


def shrink(ob, target, offset):
    sw = ob.modifiers.new("Wrap", "SHRINKWRAP")
    sw.target = target
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "OUTSIDE_SURFACE"
    sw.offset = offset
    ob.modifiers.move(len(ob.modifiers) - 1, 0)


def strip(name, pts, width, mat, target=None, offset=0.006, thick=0.006, normal_hint=None, outline=0.002):
    """Flat ribbon along points (straps/belts). Ribbon plane faces away from the body axis."""
    pts = [Vector(p) for p in pts]
    rows = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        out = Vector((p.x, p.y, 0)).normalized() if normal_hint is None else Vector(normal_hint)
        side = t.cross(out).normalized()
        rows.append([p - side * width / 2, p + side * width / 2])
    ob = mesh_from_grid(name, rows, closed=False)
    sol = ob.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    if target:
        shrink(ob, target, offset)
    return finish(ob, mat, subsurf=0, outline=outline)


def wrap_points(pts, objs, offset):
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    trees = []
    for ob in objs:
        e = ob.evaluated_get(dg)
        me = e.to_mesh()
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.transform(ob.matrix_world)
        trees.append(BVHTree.FromBMesh(bm))
        bm.free()
        e.to_mesh_clear()
    out = []
    for p in pts:
        o = Vector((0, 0.01, p.z))
        d = Vector((p.x, p.y - 0.01, 0))
        d = d.normalized() if d.length > 1e-5 else Vector((0, -1, 0))
        far = None
        for t in trees:
            q = o + d * 0.6
            hit = t.ray_cast(q, -d)          # cast inward from outside: first hit is the outermost layer
            if hit[0] is not None and (far is None or (hit[0] - o).length > (far - o).length):
                far = hit[0]
        out.append(far + d * offset if far is not None else p)
    return out


# ----------------------------------------------------------------------------- palette
SKIN = toon("Skin", (240, 196, 160), (205, 140, 115), rim=0.12, rim_col=(1, 0.85, 0.75))
HAIR = toon("Hair", (128, 78, 44), (74, 42, 26), rim=0.2, rim_col=(1.0, 0.8, 0.6))
def dtl(name):
    p = os.path.join(TEX, f"detail_{name}.png")
    return p if os.path.exists(p) else None


SCARF = toon("Scarf", (192, 70, 44), (124, 38, 30), tex=dtl("red"), tex_mix=0.45, rim=0.22, rim_col=(1, 0.7, 0.55))
CREAM = toon("Jacket", (238, 226, 202), (172, 160, 150), tex=dtl("cream"), tex_mix=0.6, rim=0.15)
NAVY = toon("Shirt", (50, 56, 76), (28, 30, 44), tex=dtl("twill"), tex_mix=0.3, rim=0.12)
PANTS = toon("Pants", (92, 92, 94), (52, 52, 60), tex=dtl("twill"), tex_mix=0.5, rim=0.12)
LEATHER = toon("Leather", (130, 80, 44), (72, 44, 26), tex=dtl("leather"), tex_mix=0.5, rim=0.15)
BOOT = toon("Boots", (120, 72, 42), (64, 38, 24), tex=dtl("leather"), tex_mix=0.55, rim=0.15)
GLOVE = toon("Gloves", (84, 58, 42), (44, 30, 24), tex=dtl("leather"), tex_mix=0.4, rim=0.15)
BRASS = toon("Brass", (214, 170, 96), (140, 100, 50), rim=0.3, rim_col=(1, 0.9, 0.7))
STEEL = toon("Steel", (205, 205, 200), (120, 124, 130), rim=0.35)
PAD = toon("KneePad", (70, 72, 78), (40, 42, 50), rim=0.2)
GLOW = toon("Glow", (255, 190, 110), (255, 160, 80), rim=0.0, emit=((255, 170, 80), 3.0))
EYE_WHITE = toon("EyeWhite", (250, 246, 240), (215, 205, 200), rim=0.0)

# ----------------------------------------------------------------------------- body
z_crotch, z_waist, z_armpit, z_shoulder, z_neck = Z("crotch"), Z("waist"), Z("armpit"), Z("shoulder"), Z("neck_base")
z_chin, z_eye, z_skull = Z("chin"), Z("eye"), Z("skull_top")
half_sh = W(FX["shoulder_w"]) / 2          # includes puffy sleeves
chest_d = W(SD["chest"]) / 2

torso = loft_z("Torso", [
    (z_crotch - 0.03, 0.150, 0.00, 0.095, 0.095),
    (z_crotch + 0.08, 0.158, 0.00, 0.098, 0.102),
    (z_waist, 0.138, 0.00, 0.090, 0.090),
    (z_waist + 0.13, 0.150, -0.005, chest_d, chest_d * 0.95),
    (z_armpit, 0.160, 0.00, chest_d * 0.97, chest_d),
    (z_shoulder - 0.04, 0.152, 0.005, 0.082, 0.087),
    (z_shoulder + 0.01, 0.110, 0.008, 0.068, 0.072),
    (z_neck - 0.01, 0.070, 0.010, 0.055, 0.055),
    (z_neck + 0.01, 0.050, 0.012, 0.045, 0.045)], n=28, steps=26, power=2.3)
finish(torso, NAVY)

neck = tube("Neck", [(0, 0.012, z_neck - 0.02), (0, 0.010, z_chin + 0.03)], [0.047, 0.043], [0.045, 0.042], n=16)
finish(neck, SKIN, outline=0.002)

# ----------------------------------------------------------------------------- head
HEAD_KEYS = [
    (z_chin, 0.020, -0.062, 0.016, 0.016),
    (z_chin + 0.012, 0.036, -0.052, 0.026, 0.030),
    (Z("mouth"), 0.052, -0.035, 0.046, 0.058),
    (Z("nose"), 0.066, -0.018, 0.070, 0.082),
    (z_eye, 0.076, -0.006, 0.083, 0.098),
    (Z("brow"), 0.080, 0.000, 0.086, 0.104),
    ((Z("brow") + z_skull) / 2 + 0.01, 0.078, 0.006, 0.078, 0.104),
    (z_skull - 0.018, 0.060, 0.010, 0.056, 0.080),
    (z_skull - 0.004, 0.030, 0.012, 0.028, 0.040),
    (z_skull, 0.004, 0.012, 0.004, 0.006)]
head = loft_z("Head", HEAD_KEYS, n=32, steps=30, power=2.0, flat_front=2.6)
# face texture: front projection UV (u from x, v from z) so eyes land where measured
FACE_BOX = (-0.10, z_chin - 0.02, 0.20)     # x0, z0, size
uv = head.data.uv_layers[0]
for lp in head.data.loops:
    co = head.data.vertices[lp.vertex_index].co
    uv.data[lp.index].uv = ((co.x - FACE_BOX[0]) / FACE_BOX[2], (co.z - FACE_BOX[1]) / FACE_BOX[2])

# nose: small soft wedge on the face front
nose = tube("Nose", [(0, -0.083, Z("brow") - 0.012), (0, -0.090, Z("nose") + 0.004), (0, -0.087, Z("nose") - 0.004)],
            [0.006, 0.010, 0.006], [0.004, 0.010, 0.004], n=10)

# ears
for sx in (-1, 1):
    ear = tube("Ear" + ("L" if sx > 0 else "R"),
               [(sx * 0.074, 0.012, z_eye - 0.03), (sx * 0.080, 0.016, z_eye - 0.005), (sx * 0.078, 0.018, z_eye + 0.012)],
               [0.008, 0.012, 0.008], [0.014, 0.020, 0.012], n=10, up=Vector((1, 0, 0)))
    finish(ear, SKIN, outline=0.0015)


def face_texture(path, size=1024):
    """Paint eyes/brows/mouth at measured positions (front projection)."""
    from_atlas = os.path.join(CONCEPTS, "03_ww_face_parts.png")
    # Deferred to the helper script (run with system python + PIL); here we only reference the file.
    return path


FACE_TEX = os.path.join(TEX, "face_base.png")
FACE = toon("Face", (255, 255, 255), (222, 182, 180), tex=FACE_TEX if os.path.exists(FACE_TEX) else None,
            rim=0.1, rim_col=(1, 0.85, 0.75), step=(0.22, 0.34))
finish(head, FACE, outline=0.0025)
finish(nose, SKIN, outline=0.0)

# smooth anime face shading: copy normals from a clean ellipsoid (custom split normals)
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0)
proxy = bpy.context.active_object
proxy.name = "FaceNormalProxy"
proxy.scale = (0.08, 0.09, 0.11)
proxy.location = (0, 0.004, z_eye - 0.02)
proxy.hide_render = True
proxy.hide_viewport = True
for ob in (head, nose):
    dt = ob.modifiers.new("FaceNormals", "DATA_TRANSFER")
    dt.object = proxy
    dt.use_loop_data = True
    dt.data_types_loops = {"CUSTOM_NORMAL"}
    dt.loop_mapping = "POLYINTERP_NEAREST"
    dt.mix_factor = 0.85
    ob.modifiers.move(len(ob.modifiers) - 1, 1 if ob.modifiers[0].type == "SUBSURF" else 0)

# ----------------------------------------------------------------------------- hair
HAIR_C = Vector((0, 0.012, z_eye + 0.035))
HAIR_R = Vector((0.094, 0.114, 0.1))
HAIR_RF = 0.1                 # tighter in front so the fringe lies on the forehead
hair_objs = []


def scalp(theta, phi, lift=1.0):
    """theta: azimuth (0 = front), phi: polar from top."""
    d = Vector((math.sin(phi) * math.sin(theta), -math.sin(phi) * math.cos(theta), math.cos(phi)))
    ry = HAIR_RF if d.y < 0 else HAIR_R.y
    return HAIR_C + Vector((d.x * HAIR_R.x, d.y * ry, d.z * HAIR_R.z)) * lift, d


def clump(name, root, ctrl, width, thick, n=8, flick=None):
    """Tapered, slightly flattened lock from root through quadratic bezier controls."""
    p0, p1, p2 = root, ctrl[0], ctrl[1]
    steps = 9
    path = []
    for i in range(steps + 1):
        t = i / steps
        path.append(p0 * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + p2 * t * t)
    if flick:
        path[-1] = path[-1] + Vector(flick)
    rx = [width * (1 - (i / steps)) ** 0.85 + 0.0008 for i in range(steps + 1)]
    ry = [thick * (1 - (i / steps)) ** 0.9 + 0.0006 for i in range(steps + 1)]
    out = (root - HAIR_C).normalized()
    ob = tube(name, path, rx, ry, n=n, up=out, caps=(True, False))
    finish(ob, HAIR, outline=0.0022)
    hair_objs.append(ob)
    return ob


# cap that fills the skull under the clumps
cap = loft_z("HairCap", [(z_chin + 0.015, 0.068, 0.062, 0.02, 0.074), (z_eye - 0.03, 0.09, 0.042, 0.045, 0.112),
                         (z_eye, 0.096, 0.03, 0.06, 0.118), (Z("brow") + 0.012, 0.097, 0.014, 0.07, 0.12), (Z("brow") + 0.03, 0.097, 0.013, 0.09, 0.12),
                         (Z("brow") + 0.045, 0.094, 0.012, 0.108, 0.118), (z_skull, 0.07, 0.012, 0.08, 0.09),
                         (z_skull + 0.024, 0.012, 0.012, 0.012, 0.014)], n=32, steps=18)
finish(cap, HAIR, outline=0.002)
hair_objs.append(cap)

hi = 0
half_hair = W(FX["hair_w"]) / 2
CROWN = HAIR_C + Vector((0, 0.045, HAIR_R.z * 0.95))        # whorl slightly behind the top


def ell_push(p, scale):
    """Push p out to the hair ellipsoid scaled by `scale` (keeps its direction from HAIR_C)."""
    q = p - HAIR_C
    ry = HAIR_RF if q.y < 0 else HAIR_R.y
    k = math.sqrt((q.x / HAIR_R.x) ** 2 + (q.y / ry) ** 2 + (q.z / HAIR_R.z) ** 2) + 1e-9
    return HAIR_C + q * (scale / k) if k < scale else p


def flow_lock(name, theta, phi, length, width, lift0=1.02, lift1=1.35, grav=0.4, flick=0.02, curl=0.0, fwd=None):
    """Lock that starts at the scalp, flows away from the crown along the surface, lifts off and flicks."""
    r, d = scalp(theta, phi, lift0)
    f = (r - CROWN)
    f = (f - d * f.dot(d)).normalized() if fwd is None else Vector(fwd).normalized()
    pts = [r]
    p = r
    steps = 10
    ds = length / steps
    for i in range(1, steps + 1):
        t = i / steps
        f = (f + Vector((0, 0, -grav * ds * 12))).normalized()
        if curl:
            f = (Matrix.Rotation(curl * ds * 10, 3, d) @ f).normalized()
        p = p + f * ds
        p = ell_push(p, lift0 + (lift1 - lift0) * t)
        pts.append(p.copy())
    out = (pts[-1] - HAIR_C)
    out.z *= 0.3
    pts[-1] = pts[-1] + out.normalized() * flick
    pts[-2] = pts[-2] + out.normalized() * flick * 0.35
    rx = [width * (1 - t / steps) ** 0.8 + 0.0008 for t in range(steps + 1)]
    ry = [width * 0.3 * (1 - t / steps) ** 0.9 + 0.0006 for t in range(steps + 1)]
    ob = tube(name, pts, rx, ry, n=8, up=d, caps=(True, False))
    finish(ob, HAIR, outline=0.0022)
    hair_objs.append(ob)


# top layer: lies down away from the crown (rounded mass), a few tufts stand up for the messy read
for k in range(28):
    th = -math.pi + (k + random.uniform(-0.3, 0.3)) * (2 * math.pi / 28)
    flow_lock(f"HairTop{hi}", th, random.uniform(0.25, 0.6), random.uniform(0.1, 0.14), random.uniform(0.05, 0.06),
              lift0=1.0, lift1=random.uniform(1.1, 1.22), grav=0.75, flick=random.uniform(0.012, 0.025),
              curl=random.uniform(-0.5, 0.5)); hi += 1
for k in range(7):
    th = random.uniform(-2.2, 2.2)
    flow_lock(f"HairTuft{hi}", th, random.uniform(0.15, 0.35), random.uniform(0.06, 0.085), 0.04,
              lift0=1.0, lift1=1.4, grav=0.1, flick=0.02, curl=random.uniform(-1, 1)); hi += 1
for k in range(16):
    th = math.pi + (k - 7.5) * 0.3
    flow_lock(f"HairMid{hi}", th, random.uniform(0.55, 0.75), random.uniform(0.1, 0.13), 0.055, lift0=1.02,
              lift1=1.18, grav=1.0, flick=0.018, curl=random.uniform(-0.4, 0.4)); hi += 1
# fringe: rooted along the front hairline, hanging down over the forehead to the brows
for k, th in enumerate([-1.05, -0.82, -0.6, -0.4, -0.2, -0.02, 0.16, 0.36, 0.56, 0.78, 1.0]):
    ln = 0.1 if abs(th + 0.02) < 0.05 else random.uniform(0.07, 0.085)
    flow_lock(f"HairBang{hi}", th, 0.62, ln, 0.04, lift0=1.0, lift1=1.07, grav=1.4, flick=0.008,
              curl=-th * 0.5, fwd=(math.sin(th) * 0.35, -0.3, -1.0)); hi += 1
# sides: down over the temples to below the ear, flicking outward to the measured hair width
for sx in (-1, 1):
    for k, (th, ph, ln) in enumerate([(1.05, 0.7, 0.12), (1.35, 0.8, 0.12), (1.7, 0.85, 0.11), (2.1, 0.8, 0.11),
                                       (1.2, 0.5, 0.13), (1.55, 0.55, 0.12)]):
        flow_lock(f"HairSide{hi}", sx * th, ph, ln, 0.05, lift0=1.0, lift1=1.26, grav=1.3,
                  flick=0.03, curl=sx * random.uniform(0.2, 0.6)); hi += 1
# back: down to the nape with outward flicks
for k in range(14):
    th = math.pi + (k - 6.5) * 0.24
    flow_lock(f"HairBack{hi}", th, random.uniform(0.7, 1.0), random.uniform(0.12, 0.16), 0.056, lift0=1.0,
              lift1=1.3, grav=0.9, flick=0.025, curl=random.uniform(-0.4, 0.4)); hi += 1

# ----------------------------------------------------------------------------- arms / hands
arm_sets = {}
for sx in (-1, 1):
    S = "L" if sx > 0 else "R"
    sh = Vector((sx * 0.16, 0.005, z_shoulder - 0.03))
    el = Vector((sx * 0.2, 0.015, Z("elbow")))
    wr = Vector((sx * 0.222, -0.005, Z("wrist")))
    arm_sets[S] = (sh, el, wr)
    # puffy cream sleeve shoulder -> elbow
    up_path = [sh + (el - sh) * t for t in (0.0, 0.2, 0.5, 0.8, 0.95, 1.0)]
    up_path[0] = up_path[0] + Vector((-sx * 0.02, 0, 0.03))
    sl = tube("Sleeve" + S, up_path, [0.055, 0.068, 0.072, 0.066, 0.058, 0.052], [0.055, 0.066, 0.068, 0.062, 0.054, 0.05], n=18)
    finish(sl, CREAM)
    cuff = tube("SleeveCuff" + S, [el + Vector((0, 0, 0.02)), el - Vector((0, 0, 0.018))], [0.056, 0.05], [0.054, 0.048], n=16)
    finish(cuff, NAVY)
    fa = tube("Forearm" + S, [el, el + (wr - el) * 0.5, wr], [0.040, 0.037, 0.030], [0.038, 0.034, 0.027], n=14)
    finish(fa, SKIN, outline=0.0022)
    # glove: cuff + hand + fingers
    gc = tube("GloveCuff" + S, [wr + Vector((0, 0, 0.025)), wr - Vector((0, 0, 0.02))], [0.043, 0.040], [0.040, 0.037], n=16)
    finish(gc, GLOVE)
    band = tube("GloveBand" + S, [wr + Vector((0, 0, 0.012)), wr + Vector((0, 0, -0.004))], [0.046, 0.046], [0.043, 0.043], n=16)
    finish(band, LEATHER, subsurf=1, outline=0.0015)
    palm_top = wr - Vector((0, 0, 0.03))
    palm_bot = wr - Vector((sx * -0.004, 0, 0.12))
    palm = tube("Palm" + S, [palm_top, palm_top + (palm_bot - palm_top) * 0.5, palm_bot],
                [0.022, 0.028, 0.026], [0.036, 0.042, 0.038], n=14, up=Vector((sx, 0, 0)))
    finish(palm, GLOVE, outline=0.002)
    for f in range(4):
        fy = -0.03 + f * 0.02
        base = palm_bot + Vector((sx * 0.004, fy, 0.012))
        ln = [0.082, 0.09, 0.086, 0.07][f]
        mid = base + Vector((sx * 0.006, -0.012, -ln * 0.55))
        tip = base + Vector((-sx * 0.002, -0.028, -ln))
        fg = tube(f"Finger{S}{f}", [base, mid, tip], [0.0095, 0.009, 0.007], [0.0095, 0.009, 0.007], n=8)
        finish(fg, GLOVE, outline=0.0015)
    th0 = palm_top + Vector((-sx * 0.008, -0.03, -0.035))
    thumb = tube("Thumb" + S, [th0, th0 + Vector((-sx * 0.01, -0.03, -0.035)), th0 + Vector((-sx * 0.004, -0.045, -0.065))],
                 [0.012, 0.01, 0.008], [0.012, 0.01, 0.008], n=8)
    finish(thumb, GLOVE, outline=0.0015)

# ----------------------------------------------------------------------------- jacket (open front, cropped)
jacket = loft_z("Jacket", [
    (z_waist - 0.01, 0.158, 0.00, 0.104, 0.104),
    (z_waist + 0.13, 0.162, -0.005, chest_d + 0.018, chest_d + 0.012),
    (z_armpit, 0.160, 0.00, chest_d + 0.016, chest_d + 0.018),
    (z_shoulder - 0.045, 0.150, 0.004, 0.096, 0.100),
    (z_shoulder - 0.01, 0.128, 0.008, 0.086, 0.092),
    (z_shoulder + 0.02, 0.102, 0.010, 0.073, 0.076),
    (z_neck - 0.005, 0.080, 0.012, 0.066, 0.066)], n=32, steps=24, power=2.3, gap=0.36)
sol = jacket.modifiers.new("Thick", "SOLIDIFY")
sol.thickness = 0.008
finish(jacket, CREAM)
collar = loft_z("Collar", [(z_neck - 0.01, 0.068, 0.014, 0.058, 0.058), (z_neck + 0.035, 0.060, 0.016, 0.052, 0.054)],
                n=24, steps=3, gap=0.25)
sol = collar.modifiers.new("Thick", "SOLIDIFY")
sol.thickness = 0.006
finish(collar, NAVY)

# ----------------------------------------------------------------------------- legs / pants / boots
leg_sets = {}
for sx in (-1, 1):
    S = "L" if sx > 0 else "R"
    hip = Vector((sx * 0.085, 0.0, z_crotch + 0.06))
    kn = Vector((sx * 0.128, -0.012, Z("knee")))
    an = Vector((sx * 0.168, 0.02, Z("ankle")))
    leg_sets[S] = (hip, kn, an)
    bt = Vector((sx * 0.158, 0.012, Z("boot_top")))
    pth = [hip + Vector((0, 0, 0.12)), hip, hip + (kn - hip) * 0.5, kn, kn + (bt - kn) * 0.45, bt + Vector((0, 0, 0.035)), bt]
    pr = [0.098, 0.096, 0.090, 0.080, 0.080, 0.084, 0.062]
    pants = tube("PantsLeg" + S, pth, pr, [0.10, 0.098, 0.092, 0.082, 0.08, 0.082, 0.06], n=20)
    finish(pants, PANTS)
    # knee pad
    pad = tube("KneePad" + S, [kn + Vector((0, -0.07, 0.05)), kn + Vector((0, -0.088, 0.0)), kn + Vector((0, -0.075, -0.055))],
               [0.045, 0.052, 0.042], [0.022, 0.026, 0.02], n=12, up=Vector((0, -1, 0)), power=3.0)
    finish(pad, PAD, subsurf=2)
    # boot shaft and foot
    shaft = tube("BootShaft" + S, [bt + Vector((0, 0, 0.01)), an + Vector((0, 0.0, 0.05)), an], [0.066, 0.058, 0.06],
                 [0.064, 0.056, 0.064], n=18)
    finish(shaft, BOOT)
    foot_keys = [(0.0, 0.050, 0.062), (0.35, 0.055, 0.075), (0.7, 0.056, 0.055), (1.0, 0.045, 0.035)]
    heel = Vector((an.x, an.y + 0.06, 0.058))
    toe = Vector((an.x + sx * 0.02, an.y - 0.21, 0.042))
    samples = [i / 10 for i in range(11)]
    fk = lerp_profile(foot_keys, samples)
    path = [heel + (toe - heel) * s + Vector((0, 0, 0.05 * math.sin(math.pi * min(s * 1.4, 1.0)) * (1 - s)))
            for s in samples]
    foot = tube("BootFoot" + S, path, [k[0] for k in fk], [k[1] * 0.75 for k in fk], n=16, up=Vector((0, 0, 1)), power=2.6)
    finish(foot, BOOT)
    sole = box("BootSole" + S, ((heel.x + toe.x) / 2, (heel.y + toe.y) / 2 - 0.005, 0.014), (0.115, 0.30, 0.028), LEATHER,
               bevel=0.35, rot=(0, 0, math.atan2(toe.x - heel.x, heel.y - toe.y) * -1))
    for i, zz in enumerate((0.25, 0.19, 0.13)):
        s_ = tube(f"BootStrap{S}{i}", [Vector((an.x, an.y, zz + 0.012)), Vector((an.x, an.y, zz - 0.012))],
                  [0.07 - i * 0.002] * 2, [0.068 - i * 0.002] * 2, n=18)
        finish(s_, LEATHER, subsurf=1, outline=0.0015)
        box(f"BootBuckle{S}{i}", (an.x + sx * 0.05, an.y - 0.035, zz), (0.022, 0.012, 0.02), BRASS, bevel=0.2, subsurf=1,
            outline=0.0012)

# ----------------------------------------------------------------------------- belt, straps, pouches
hips = loft_z("PantsHip", [(z_crotch - 0.06, 0.176, 0.0, 0.1, 0.108), (z_crotch + 0.06, 0.178, 0.0, 0.104, 0.112),
                          (z_waist - 0.04, 0.162, 0.0, 0.096, 0.1), (z_waist + 0.015, 0.148, 0.0, 0.092, 0.094)],
              n=28, steps=10, power=2.3, caps=(False, True))
finish(hips, PANTS)
belt = tube("Belt", [(0, 0, z_waist + 0.022), (0, 0, z_waist - 0.022)], [0.158, 0.158], [0.104, 0.104], n=32, power=2.3)
finish(belt, LEATHER, subsurf=1, outline=0.002)
box("Buckle", (0, -0.108, z_waist), (0.06, 0.012, 0.046), STEEL, bevel=0.2, subsurf=1)
box("BuckleCore", (0, -0.115, z_waist), (0.034, 0.006, 0.022), LEATHER, bevel=0.2, subsurf=1)
hipbelt = tube("HipBelt", [(0, 0, z_waist - 0.06), (0, 0, z_waist - 0.088)], [0.182, 0.182], [0.114, 0.114], n=32, power=2.3,
               twist=None)
hipbelt.rotation_euler = (0, math.radians(5), 0)
hipbelt.location = (0, 0, -0.012)
finish(hipbelt, LEATHER, subsurf=1, outline=0.002)
for sx, yy, zz, sz in ((-1, -0.03, z_waist - 0.1, (0.05, 0.07, 0.1)), (1, -0.03, z_waist - 0.095, (0.05, 0.07, 0.105)),
                       (-1, 0.07, z_waist - 0.08, (0.05, 0.06, 0.08))):
    box(f"Pouch{sx}{yy}", (sx * 0.19, yy, zz), sz, LEATHER, bevel=0.2)
    box(f"PouchFlap{sx}{yy}", (sx * 0.19, yy, zz + sz[2] * 0.3), (sz[0] + 0.006, sz[1] + 0.006, sz[2] * 0.45), LEATHER,
        bevel=0.2)
    box(f"PouchStud{sx}{yy}", (sx * (0.19 + sz[0] * 0.55), yy, zz + sz[2] * 0.15), (0.006, 0.014, 0.014), BRASS, bevel=0.3,
        subsurf=1, outline=0.001)
# thigh holster on the character's right leg + thigh straps
hR, kR, _ = leg_sets["R"]
box("ThighHolster", (hR.x - 0.08, hR.y - 0.02, Z("crotch") - 0.07), (0.035, 0.07, 0.16), LEATHER, bevel=0.25)
for S in ("L", "R"):
    hp, kn, _ = leg_sets[S]
    c = hp + (kn - hp) * 0.42
    st = tube("ThighStrap" + S, [c + Vector((0, 0, 0.015)), c - Vector((0, 0, 0.015))], [0.1, 0.1], [0.1, 0.1], n=20)
    finish(st, LEATHER, subsurf=1, outline=0.0015)
# compass pendant hanging from the belt
box("CompassBody", (-0.075, -0.118, z_waist - 0.09), (0.045, 0.012, 0.045), BRASS, bevel=0.5, subsurf=2)
box("CompassGlass", (-0.075, -0.125, z_waist - 0.09), (0.032, 0.004, 0.032), GLOW, bevel=0.5, subsurf=2, outline=0.0)

# X harness straps across the chest, wrapped on the jacket/shirt surface
for sx in (-1, 1):
    pts = [Vector((sx * 0.12, -0.02, z_shoulder + 0.01)), Vector((sx * 0.1, -0.1, z_armpit)),
           Vector((0.0, -0.115, (z_armpit + z_waist) / 2)), Vector((-sx * 0.1, -0.1, z_waist + 0.04)),
           Vector((-sx * 0.15, -0.06, z_waist + 0.02))]
    fine = []
    for a, b in zip(pts, pts[1:]):
        for i in range(6):
            fine.append(a + (b - a) * (i / 6))
    fine.append(pts[-1])
    fine = wrap_points(fine, [torso, jacket], 0.004)
    strip("Harness" + str(sx), fine, 0.03, LEATHER, thick=0.006)
box("HarnessRing", (0, -0.112, (z_armpit + z_waist) / 2), (0.03, 0.008, 0.03), BRASS, bevel=0.5, subsurf=2)
box("HarnessLamp", (0.07, -0.125, z_armpit - 0.03), (0.018, 0.01, 0.018), GLOW, bevel=0.5, subsurf=2, outline=0.0012)

# ----------------------------------------------------------------------------- scarf + cloak
def roll(name, zc, rad, tube_r, tilt=0.0, yc=0.014, wob=0.12, seed=0.0):
    pts, rx, ry = [], [], []
    for i in range(33):
        t = 2 * math.pi * i / 32
        wv = 1 + wob * noise.noise(Vector((math.cos(t) * 2, math.sin(t) * 2, seed)))
        pts.append(Vector((math.cos(t) * rad * wv, yc + math.sin(t) * rad * 0.92 * wv,
                           zc + tilt * math.sin(t) + 0.006 * math.sin(3 * t + seed))))
        rx.append(tube_r * (1 + 0.25 * noise.noise(Vector((t, seed, 1.0)))))
        ry.append(tube_r * 0.8)
    ob = tube(name, pts, rx, ry, n=12, up=Vector((0, 0, 1)), caps=(False, False))
    finish(ob, SCARF, outline=0.003)
    return ob


# under-cone keeps the shoulders covered between the rolls
sc_rows = []
for k, (z, w, d, yc) in enumerate([(z_neck - 0.08, 0.17, 0.128, 0.012), (z_neck - 0.04, 0.14, 0.115, 0.014),
                                    (z_neck - 0.005, 0.1, 0.09, 0.018)]):
    sc_rows.append([Vector((math.cos(2 * math.pi * i / 28) * w, yc + math.sin(2 * math.pi * i / 28) * d, z))
                    for i in range(28)])
scarf = mesh_from_grid("Scarf", sc_rows, cap0=False, cap1=False)
finish(scarf, SCARF, outline=0.002)
roll("ScarfRoll0", z_neck + 0.008, 0.07, 0.026, tilt=0.008, seed=1.0)
roll("ScarfRoll1", z_neck - 0.03, 0.098, 0.032, tilt=0.018, seed=2.0)
roll("ScarfRoll2", z_neck - 0.065, 0.13, 0.03, tilt=0.025, seed=3.0)
# knot and front fall onto the chest (illustration: bunched on the character's left)
drape = tube("ScarfDrape", [(0.04, -0.12, z_neck - 0.05), (0.06, -0.14, z_neck - 0.1), (0.05, -0.14, z_neck - 0.15),
                            (0.055, -0.135, z_neck - 0.18)],
             [0.05, 0.045, 0.038, 0.02], [0.02, 0.018, 0.015, 0.01], n=12, up=Vector((0, -1, 0)))
finish(drape, SCARF)

CLOAK_ALPHA = os.path.join(TEX, "cloak_alpha.png")
CLOAK_TEX = os.path.join(TEX, "cloak_color.png")
CLOAK = toon("Cloak", (255, 255, 255), (172, 132, 150), tex=CLOAK_TEX if os.path.exists(CLOAK_TEX) else None,
             rim=0.2, rim_col=(1, 0.7, 0.55))


def cloak_point(u, v):
    """u: 0 = right shoulder blade .. 1 = over the left shoulder; v: 0 = top .. 1 = hem."""
    ang = math.radians(-35 + 185 * u)            # -35: behind right shoulder, 150: over the left shoulder front
    top = Vector((-math.cos(math.radians(90) + 0) * 0, 0, 0))
    rt = 0.13 + 0.03 * math.sin(math.pi * u)
    tx = math.sin(ang - math.radians(90)) * -rt if False else -math.cos(math.radians(90) + ang) * 0
    # top edge sits on the shoulders under the scarf
    x0 = math.sin(math.radians(90) - ang) * -rt
    y0 = math.cos(math.radians(90) - ang) * rt * 0.75 + 0.03
    z0 = z_shoulder + 0.035 - 0.02 * abs(x0) / 0.15
    length = 0.42 + 0.58 * u ** 1.5
    z = z0 - v * length
    billow = 0.10 * v ** 0.8
    fold = 0.016 * math.sin(u * 23 + v * 1.5) * min(1.0, v * 3)
    x = x0 * (1 + 0.5 * v)
    y = y0 + billow + fold
    if u > 0.72:                                   # the left side falls outside the arm and flares
        k = min(1.0, (u - 0.72) / 0.2)
        x = max(x, (0.2 + 0.07 * min(1, v * 4) + 0.13 * v) * k + x * (1 - k))
        y = y0 * (1 - k) + (0.02 + 0.08 * v) * k + fold
    return Vector((x, y, z))


cu, cv = 96, 64
rows = [[cloak_point(i / cu, j / cv) for i in range(cu + 1)] for j in range(cv + 1)]
cloak = mesh_from_grid("Cloak", rows, closed=False)
if os.path.exists(CLOAK_ALPHA):
    import numpy as np
    aimg = bpy.data.images.load(CLOAK_ALPHA)
    aw, ah = aimg.size
    px = np.empty(aw * ah * 4, np.float32)
    aimg.pixels.foreach_get(px)
    px = px.reshape(ah, aw, 4)[..., 0]
    bm = bmesh.new()
    bm.from_mesh(cloak.data)
    uvl = bm.loops.layers.uv.active
    dead = []
    for f in bm.faces:
        uc = sum((lp[uvl].uv for lp in f.loops), Vector((0, 0))) / len(f.loops)
        # Blender pixel rows start at the bottom: UV v maps directly
        if px[min(int(uc.y * ah), ah - 1), min(int(uc.x * aw), aw - 1)] < 0.5:
            dead.append(f)
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(cloak.data)
    bm.free()
    cloak.data.polygons.foreach_set("use_smooth", [True] * len(cloak.data.polygons))
sol = cloak.modifiers.new("Thick", "SOLIDIFY")
sol.thickness = 0.006
finish(cloak, CLOAK, subsurf=0, outline=0.003)

# ----------------------------------------------------------------------------- landmark readout (evaluated geometry)
def eval_bounds(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    zs, xs = [], []
    for ob in objs:
        e = ob.evaluated_get(dg)
        me = e.to_mesh()
        mw = ob.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            zs.append(w.z); xs.append(w.x)
        e.to_mesh_clear()
    return min(zs), max(zs), min(xs), max(xs)


def section_width(ob, z, tol=0.004):
    dg = bpy.context.evaluated_depsgraph_get()
    e = ob.evaluated_get(dg)
    me = e.to_mesh()
    xs = [(ob.matrix_world @ v.co).x for v in me.vertices if abs((ob.matrix_world @ v.co).z - z) < tol]
    e.to_mesh_clear()
    return (max(xs) - min(xs)) if xs else 0.0


def measure():
    out = {}
    hz0, hz1, hx0, hx1 = eval_bounds([o for o in hair_objs])
    out["hair_top"] = hz1
    out["hair_w"] = hx1 - hx0
    z0, z1, _, _ = eval_bounds([head])
    out["chin"] = z0
    out["skull_top"] = z1
    out["eye"] = z_eye
    out["face_w"] = section_width(head, z_eye)
    sl = [o for o in COLL.objects if o.name.startswith("Sleeve") and "Cuff" not in o.name]
    _, sz1, sx0, sx1 = eval_bounds(sl)
    out["shoulder_w"] = sx1 - sx0
    fz0, _, _, _ = eval_bounds([o for o in COLL.objects if o.name.startswith("Finger")])
    out["fingertip"] = fz0
    out["waist"] = z_waist
    out["crotch"] = z_crotch
    out["knee"] = Z("knee")
    out["sole"] = eval_bounds([o for o in COLL.objects if o.name.startswith("BootSole")])[0]
    _, _, bx0, bx1 = eval_bounds([o for o in COLL.objects if o.name.startswith("BootFoot")])
    out["feet_span"] = bx1 - bx0 - 0.11
    return out


# ----------------------------------------------------------------------------- export helpers
OUT = arg("--out", os.path.join(ROOT, "previews", "tmp"))
os.makedirs(OUT, exist_ok=True)
meas = measure()
target = {k: Z(k) for k in ("hair_top", "skull_top", "eye", "chin", "fingertip", "waist", "crotch", "knee", "sole")}
target.update(face_w=W(FX["face_w"]), hair_w=W(FX["hair_w"]), shoulder_w=W(FX["shoulder_w"]), feet_span=W(FX["feet_span"]))
json.dump({"model": meas, "target": target, "px_per_m": 1 / PX}, open(os.path.join(OUT, "landmarks_3d.json"), "w"), indent=1)

exec(open(os.path.join(HERE, "ww_rig.py")).read())

if arg("--blend"):
    bpy.ops.wm.save_as_mainfile(filepath=arg("--blend"))

exec(open(os.path.join(HERE, "ww_render.py")).read())
