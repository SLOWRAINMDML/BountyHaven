# VRoid-style face parts (exec'd from ww_build.py when face_spec "eye_mode" == "layered").
# Front layers (decals ray-projected onto the face, slightly in front): eyeline, brows, mouth line, mouth interior.
# Back layers (behind the alpha-cut eye opening): eyelid patch (blink), highlight, iris (on eye bones), eye white.
# Expression shape keys use the VRM 1.0 preset names so they map 1:1 to VRMC_vrm expressions.
from mathutils.bvhtree import BVHTree

FPJ = json.load(open(os.path.join(TEX, "face_parts.json")))
FACE_PARTS = []          # objects
FP_UV = {}               # object name -> list of (u, v) per vertex (grid params for shape keys)

_dg = bpy.context.evaluated_depsgraph_get()
_hm = head.modifiers.get("Outline")
if _hm:
    _hm.show_viewport = False
_dg.update()
_he = head.evaluated_get(_dg)
_hme = _he.to_mesh()
_bm = bmesh.new()
_bm.from_mesh(_hme)
_bm.transform(head.matrix_world)
_bm.normal_update()
HEAD_BVH = BVHTree.FromBMesh(_bm)
_bm.free()
_he.to_mesh_clear()
if _hm:
    _hm.show_viewport = True


def surf_pt(x, z, off):
    hit = HEAD_BVH.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
    if hit[0] is None:
        return Vector((x, -0.08 - off, z))
    n = hit[1].normalized()
    if n.y > 0:
        n = -n
    return hit[0] + n * off


def fp_mat(name, tex, lit=(255, 255, 255), shade=(222, 190, 182), emit=None, alpha=True):
    m = toon(name, lit, shade, tex=os.path.join(TEX, tex) if tex else None, rim=0.0, emit=emit,
             step=tuple(FS.get("face_ramp", (0.22, 0.34))))
    if alpha and tex:
        nt = m.node_tree
        img = nt.nodes[m["tex_node"]]
        out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
        last = out.inputs[0].links[0].from_socket
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mx = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(img.outputs["Alpha"], mx.inputs[0])
        nt.links.new(tr.outputs[0], mx.inputs[1])
        nt.links.new(last, mx.inputs[2])
        nt.links.new(mx.outputs[0], out.inputs[0])
        m.surface_render_method = "DITHERED"
        m["alpha"] = 1
    return m


def decal(name, rect, mat, off, nu=24, nv=10, flip_u=False):
    x0, z0, x1, z1 = rect
    rows, uvs = [], []
    for j in range(nv + 1):
        v = j / nv
        rows.append([surf_pt(x0 + (x1 - x0) * i / nu, z0 + (z1 - z0) * v, off) for i in range(nu + 1)])
    ob = mesh_from_grid(name, rows, closed=False)
    uvl = ob.data.uv_layers[0]
    for lp in ob.data.loops:
        u, v = uvl.data[lp.index].uv
        uvl.data[lp.index].uv = ((1 - u) if flip_u else u, v)
    FP_UV[name] = [None] * len(ob.data.vertices)
    for i, vtx in enumerate(ob.data.vertices):
        FP_UV[name][i] = ((vtx.co.x - x0) / (x1 - x0), (vtx.co.z - z0) / (z1 - z0))
    finish(ob, mat, subsurf=0, outline=0.0)
    FACE_PARTS.append(ob)
    return ob


def fp_disc(name, cx, cz, r, mat, off, segs=32):
    c = surf_pt(cx, cz, off)
    pts = [[c]]
    ring_ = [Vector((cx + r * math.cos(2 * math.pi * i / segs), c.y, cz + r * math.sin(2 * math.pi * i / segs)))
             for i in range(segs)]
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    vc = bm.verts.new(c)
    vr = [bm.verts.new(p) for p in ring_]
    for i in range(segs):
        f = bm.faces.new((vc, vr[i], vr[(i + 1) % segs]))
        for lp in f.loops:
            q = lp.vert.co
            lp[uvl].uv = (0.5 + (q.x - cx) / (2 * r), 0.5 + (q.z - cz) / (2 * r))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    COLL.objects.link(ob)
    finish(ob, mat, subsurf=0, outline=0.0)
    FACE_PARTS.append(ob)
    return ob


def add_key(ob, key, fn):
    """fn(u, v, co) -> new co for every vertex (u, v = grid params)."""
    if not ob.data.shape_keys:
        ob.shape_key_add(name="Basis")
    sk = ob.shape_key_add(name=key, from_mix=False)
    sk.value = 0.0                                   # Blender 5.2 creates new keys at 1.0
    for i, vtx in enumerate(ob.data.vertices):
        u, v = FP_UV[ob.name][i]
        sk.data[i].co = fn(u, v, vtx.co.copy())


M_EYELINE = {S: fp_mat("FPEyeline" + S, f"fp_eyeline_{S}.png", shade=(235, 225, 225)) for S in ("R", "L")}
M_WHITE = {S: fp_mat("FPEyeWhite" + S, f"fp_eyewhite_{S}.png", shade=(225, 220, 225), alpha=False) for S in ("R", "L")}
M_IRIS = fp_mat("FPIris", "fp_iris.png", shade=(225, 215, 215))
M_HL = fp_mat("FPHighlight", "fp_highlight.png", emit=((255, 255, 255), 0.6))
M_BROW = {S: fp_mat("FPBrow" + S, f"fp_brow_{S}.png", shade=(225, 215, 215)) for S in ("R", "L")}
M_MOUTH = fp_mat("FPMouth", "fp_mouth.png", shade=(225, 215, 215))
M_INNER = fp_mat("FPMouthInner", "fp_mouth_inner.png", shade=(200, 190, 190), alpha=False)
M_LID = toon("FPLid", tuple(FS.get("skin_lit", (240, 196, 160))), tuple(FS.get("skin_shade", (205, 140, 115))), rim=0.0,
             step=tuple(FS.get("face_ramp", (0.22, 0.34))))
FACE_MAT_ALPHA = True

EYE_CENTERS = {}
for S, sx in (("R", -1), ("L", 1)):
    E = FPJ["eyes"][S]
    x0, z0, x1, z1 = E["rect"]
    ot, ob_ = E["open_top"], E["open_bot"]
    ix, iz, ir = E["iris"]
    hx, hz, hr = E["highlight"]
    # back layers (behind the face surface, seen through the alpha-cut opening)
    white = decal("FPEyeWhite" + S, [x0, ob_ - 0.003, x1, ot + 0.003], M_WHITE[S], -0.0022, nu=20, nv=8)
    iris = fp_disc("FPIris" + S, ix, iz, ir, M_IRIS, -0.0014)
    hl = fp_disc("FPHighlight" + S, hx, hz, hr * 1.4, M_HL, -0.0009, segs=16)
    EYE_CENTERS[S] = surf_pt(ix, iz, -0.012)
    lid = decal("FPLid" + S, [x0, ot + 0.0005, x1, ot + 0.004], M_LID, -0.0004, nu=20, nv=6)
    # front layer: eyeline (lash lines)
    line = decal("FPEyeline" + S, [x0, z0, x1, z1], M_EYELINE[S], 0.0004, nu=28, nv=12)
    mid = (ot + ob_) / 2

    def closed_z(u, ot=ot, ob_=ob_):
        return ob_ + (ot - ob_) * 0.18 + 0.0025 * (1 - (2 * u - 1) ** 2)       # gentle downward-open arc

    def lid_fn(amount):
        def fn(u, v, co, x0=x0, x1=x1, ot=ot):
            uu = (co.x - x0) / (x1 - x0)
            closed = closed_z(min(max(uu, 0.0), 1.0)) - 0.001
            target = closed * (1 - v) + (ot + 0.004) * v       # the lid's lower edge drops to the closed line
            z_new = co.z + (target - co.z) * amount
            p = surf_pt(co.x, z_new, -0.0004)
            return p
        return fn

    def line_fn(amount, mid=mid, z0=z0, z1=z1):
        def fn(u, v, co):
            zz = co.z
            if zz > mid:                                  # upper lash line follows the lid down
                target = closed_z(u) + (zz - ot) * 0.4
                zz = zz + (target - zz) * amount
            return surf_pt(co.x, zz, 0.0004)
        return fn

    for key, amt, sides in (("blink", 1.0, "RL"), ("blinkLeft", 1.0, "L"), ("blinkRight", 1.0, "R"),
                            ("happy", 0.62, "RL"), ("relaxed", 0.4, "RL"), ("angry", 0.18, "RL"), ("sad", 0.3, "RL")):
        if S in sides:
            add_key(lid, key, lid_fn(amt))
            add_key(line, key, line_fn(amt))
        else:
            add_key(lid, key, lambda u, v, co: co)
            add_key(line, key, lambda u, v, co: co)
    # brows
    B = FPJ["brows"][S]
    brow = decal("FPBrow" + S, B["rect"], M_BROW[S], 0.0006, nu=20, nv=6)
    inner = (lambda u: u) if S == "R" else (lambda u: 1 - u)      # 1 at the end nearest the nose

    def brow_fn(dz_in, dz_out, dx_in=0.0):
        def fn(u, v, co):
            w = inner(u)
            return surf_pt(co.x - math.copysign(dx_in * w, co.x), co.z + dz_out + (dz_in - dz_out) * w, 0.0006)
        return fn

    for key, args in (("happy", (0.002, 0.003)), ("angry", (-0.005, 0.0015, 0.003)), ("sad", (0.0045, -0.0015)),
                      ("surprised", (0.006, 0.0055)), ("relaxed", (0.0, 0.0)), ("blink", (0, 0)), ("blinkLeft", (0, 0)),
                      ("blinkRight", (0, 0))):
        add_key(brow, key, brow_fn(*args))

# mouth: line decal + interior that opens for lip sync
MR = FPJ["mouth"]["rect"]
mx0, mz0, mx1, mz1 = MR
mcz = mz1 - 0.25 * (mz1 - mz0)          # the drawn mouth line sits in the upper quarter of the mouth element
mouth = decal("FPMouth", MR, M_MOUTH, 0.0005, nu=20, nv=6)
inner_m = decal("FPMouthInner", [mx0 + 0.006, mcz - 0.0001, mx1 - 0.006, mcz + 0.0001], M_INNER, 0.0003, nu=16, nv=6)
MOUTH_SHAPES = {"aa": (0.8, 0.017), "ih": (1.05, 0.006), "ou": (0.45, 0.011), "ee": (1.0, 0.009), "oh": (0.65, 0.015),
                "surprised": (0.55, 0.013)}
mw = (mx1 - mx0) / 2 - 0.006


def inner_fn(sw, h):
    def fn(u, v, co):
        x = (u - 0.5) * 2 * mw * sw
        lens = max(0.0, 1 - (2 * u - 1) ** 2) ** 0.5
        z = mcz + 0.0001 - (1 - v) * h * lens          # lower edge (v = 0) drops, upper edge stays on the lip line
        return surf_pt(x, z, 0.0003)
    return fn


def mouth_line_fn(corner_dz, open_dz=0.0, sw=1.0):
    def fn(u, v, co):
        k = (2 * u - 1) ** 2
        x = co.x * sw
        return surf_pt(x, co.z + corner_dz * k + open_dz * (1 - k) * 0, 0.0005)
    return fn


for key in ("blink", "blinkLeft", "blinkRight", "aa", "ih", "ou", "ee", "oh", "happy", "angry", "sad", "relaxed", "surprised"):
    if key in MOUTH_SHAPES:
        add_key(inner_m, key, inner_fn(*MOUTH_SHAPES[key]))
        add_key(mouth, key, mouth_line_fn(0.0005, sw=MOUTH_SHAPES[key][0] ** 0.3))
    else:
        add_key(inner_m, key, lambda u, v, co: co)
        add_key(mouth, key, mouth_line_fn({"happy": 0.004, "relaxed": 0.0018, "angry": -0.002, "sad": -0.0028}.get(key, 0.0)))

# hide the decal-free face (alpha holes) only when layered parts exist
FACE["alpha"] = 1
_fn = FACE.node_tree
_img = _fn.nodes[FACE["tex_node"]]
_out = [n for n in _fn.nodes if n.type == "OUTPUT_MATERIAL"][0]
_last = _out.inputs[0].links[0].from_socket
_tr = _fn.nodes.new("ShaderNodeBsdfTransparent")
_mx = _fn.nodes.new("ShaderNodeMixShader")
_fn.links.new(_img.outputs["Alpha"], _mx.inputs[0])
_fn.links.new(_tr.outputs[0], _mx.inputs[1])
_fn.links.new(_last, _mx.inputs[2])
_fn.links.new(_mx.outputs[0], _out.inputs[0])
FACE.surface_render_method = "DITHERED"
EXPRESSIONS = ["blink", "blinkLeft", "blinkRight", "aa", "ih", "ou", "ee", "oh", "happy", "angry", "sad", "relaxed", "surprised"]


def set_expression(name, w=1.0):
    for ob in FACE_PARTS:
        ks = ob.data.shape_keys
        if not ks:
            continue
        for kb in ks.key_blocks[1:]:
            kb.value = w if kb.name == name else 0.0
