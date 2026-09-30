# Executed inside ww_build.py (shares its globals). Renders comparison views + optional VFX/beauty shots.
VIEWS = {  # name: (azimuth deg of camera around +Z; 0 = in front), crop size px (from measure crops)
    "front": (0, (275, 636)), "q34": (40, (248, 636)), "side": (90, (156, 636)), "back": (180, (240, 636))}
SCALE = 2


def cam_obj(name, loc, look, ortho=None, lens=50):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    co = bpy.data.objects.new(name, cd)
    scene.collection.objects.link(co)
    co.location = loc
    d = (Vector(look) - Vector(loc)).normalized()
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return co


def render_to(path, cam, res):
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    bpy.ops.render.render(write_still=True)


if "--views" in ARGS:
    pose_rest()
    for w in WEAPON:
        w.hide_render = True           # the sheet shows him unarmed
    zc = (FY["sole"] - 318) * PX            # crop vertical centre
    for name, (az, (cw, ch)) in VIEWS.items():
        a = math.radians(az)
        pos = Vector((math.sin(a) * 6, -math.cos(a) * 6, zc))
        cam = cam_obj("Cam_" + name, pos, (0, 0, zc), ortho=ch * PX)
        # key light follows the camera so every view is lit from its front-left like the sheet
        sun.rotation_euler = (math.radians(50), 0, math.radians(-35 + az))
        render_to(os.path.join(OUT, f"view_{name}.png"), cam, (cw * SCALE, ch * SCALE))
    # face close-up (front + 3/4)
    for name, az in (("face_front", 0), ("face_q34", 35)):
        a = math.radians(az)
        pos = Vector((math.sin(a) * 3, -math.cos(a) * 3, z_eye - 0.01))
        cam = cam_obj("Cam_" + name, pos, (0, 0, z_eye - 0.01), ortho=0.36)
        sun.rotation_euler = (math.radians(50), 0, math.radians(-35 + az))
        render_to(os.path.join(OUT, f"{name}.png"), cam, (720, 720))
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))


# ----------------------------------------------------------------------------- VFX shot
def emit_mat(name, col, strength, tex=None, alpha_from_tex=False, grad=None):
    """Additive-looking emissive material; optional texture mask and U-gradient alpha."""
    m = bpy.data.materials.new(name)
    nt = m.node_tree if m.node_tree else None
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    em = N.new("ShaderNodeEmission")
    em.inputs[0].default_value = (*col, 1)
    em.inputs[1].default_value = strength
    tr = N.new("ShaderNodeBsdfTransparent")
    mix = N.new("ShaderNodeMixShader")
    fac = None
    if tex:
        it = N.new("ShaderNodeTexImage")
        it.image = bpy.data.images.load(tex, check_existing=True)
        fac = it.outputs[0]
    if grad:
        uvn = N.new("ShaderNodeUVMap")
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(uvn.outputs[0], sep.inputs[0])
        ramp = N.new("ShaderNodeValToRGB")
        cr = ramp.color_ramp
        cr.elements[0].position, cr.elements[0].color = 0.0, (0, 0, 0, 1)
        cr.elements[1].position, cr.elements[1].color = 1.0, (0, 0, 0, 1)
        for pos, val in grad:
            e = cr.elements.new(pos)
            e.color = (val, val, val, 1)
        L.new(sep.outputs[0], ramp.inputs[0])
        # across the ribbon (v): bright core, soft edges
        vr = N.new("ShaderNodeValToRGB")
        vc = vr.color_ramp
        vc.elements[0].color = (0, 0, 0, 1)
        vc.elements[1].position, vc.elements[1].color = 1.0, (0, 0, 0, 1)
        e = vc.elements.new(0.55); e.color = (1, 1, 1, 1)
        e = vc.elements.new(0.8); e.color = (0.6, 0.6, 0.6, 1)
        L.new(sep.outputs[1], vr.inputs[0])
        mul = N.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
        L.new(ramp.outputs[0], mul.inputs[0]); L.new(vr.outputs[0], mul.inputs[1])
        fac = mul.outputs[0]
    if fac is not None:
        L.new(fac, mix.inputs[0])
        L.new(tr.outputs[0], mix.inputs[1])
        L.new(em.outputs[0], mix.inputs[2])
        L.new(mix.outputs[0], out.inputs[0])
    else:
        L.new(em.outputs[0], out.inputs[0])
    m.surface_render_method = "BLENDED"
    m.use_backface_culling = False
    return m


def arc(name, center, radius, width, a0, a1, tilt, mat, twist=0.0, segs=96):
    rows = []
    for j, off in enumerate((-1, 1)):
        row = []
        for i in range(segs + 1):
            t = i / segs
            a = a0 + (a1 - a0) * t
            w = width * math.sin(math.pi * t) ** 0.6
            rr = radius + off * w / 2
            p = Vector((math.cos(a) * rr, math.sin(a) * rr, off * w * twist))
            row.append(p)
        rows.append(row)
    ob = mesh_from_grid(name, rows, closed=False)
    COLL.objects.unlink(ob)
    scene.collection.objects.link(ob)
    ob.location = center
    ob.rotation_euler = tilt
    ob.data.materials.append(mat)
    return ob


if "--vfx" in ARGS:
    pose_slash()
    for w in WEAPON:
        w.hide_render = False
    scene.render.film_transparent = False
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.03, 0.05, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    gold, ember, cyan = srgb((255, 196, 96)), srgb((255, 110, 40)), srgb((110, 220, 255))
    # backdrop: the project's night-port concept, dimmed, far behind
    bg_img = os.path.join(ROOT, "..", "protagonist_3d", "concepts", "07_bg_night_port.jpg")
    if os.path.exists(bg_img):
        bpy.ops.mesh.primitive_plane_add(size=1)
        bgp = bpy.context.active_object
        bgp.scale = (14.0, 8.0, 1)
        bgp.rotation_euler = (math.radians(90), 0, math.radians(25))
        bgp.location = (-2.2, 4.8, 1.6)
        mb = emit_mat("Backdrop", (1, 1, 1), 0.55, tex=bg_img)
        tn = [n for n in mb.node_tree.nodes if n.type == "TEX_IMAGE"][0]
        em = [n for n in mb.node_tree.nodes if n.type == "EMISSION"][0]
        mb.node_tree.links.new(tn.outputs[0], em.inputs[0])
        mix = [n for n in mb.node_tree.nodes if n.type == "MIX_SHADER"][0]
        mix.inputs[0].default_value = 1.0
        for l in list(mb.node_tree.links):
            if l.to_node == mix and l.to_socket == mix.inputs[0]:
                mb.node_tree.links.remove(l)
        bgp.data.materials.append(mb)
    # ground
    bpy.ops.mesh.primitive_plane_add(size=60)
    gp = bpy.context.active_object
    gp.data.materials.append(toon("Ground", (58, 62, 70), (30, 32, 40), rim=0.0))
    # sigil
    sig = os.path.join(CONCEPTS, "05_ww_sigil.png")
    if os.path.exists(sig):
        bpy.ops.mesh.primitive_plane_add(size=2.6)
        sp = bpy.context.active_object
        sp.location.z = 0.004
        sp.data.materials.append(emit_mat("Sigil", gold, 6.0, tex=sig))
        bpy.ops.mesh.primitive_plane_add(size=3.4)
        sp2 = bpy.context.active_object
        sp2.location.z = 0.003
        sp2.rotation_euler.z = 0.4
        sp2.data.materials.append(emit_mat("SigilOuter", cyan, 2.5, tex=sig))
    # crescent slash arcs
    g = [(0.08, 0.2), (0.35, 1.0), (0.7, 0.9), (0.97, 0.0)]
    # blade trail: a wide crescent sweeping from behind the left shoulder to the extended blade
    arc("SlashA", (-0.05, -0.05, 1.2), 1.0, 0.26, math.radians(-10), math.radians(215),
        (math.radians(78), math.radians(-14), math.radians(-18)), emit_mat("SlashA", gold, 9.0, grad=g), twist=0.2)
    arc("SlashA2", (-0.05, -0.05, 1.2), 1.08, 0.07, math.radians(0), math.radians(205),
        (math.radians(78), math.radians(-14), math.radians(-18)), emit_mat("SlashA2", cyan, 7.0, grad=g))
    # low ember sweep around the legs
    arc("SlashB", (0.05, 0.0, 0.35), 0.85, 0.16, math.radians(150), math.radians(390),
        (math.radians(12), math.radians(-8), 0.0), emit_mat("SlashB", ember, 7.0, grad=g), twist=-0.2)
    arc("Ring", (0, 0, 0.05), 0.7, 0.06, 0, math.radians(340), (0, 0, 0), emit_mat("RingM", gold, 5.0, grad=g))
    # sparks / embers: stretched shards flying outward and upward
    random.seed(11)
    bm = bmesh.new()
    for i in range(220):
        a = random.uniform(0, 2 * math.pi)
        rr = random.uniform(0.3, 1.5)
        p = Vector((math.cos(a) * rr, math.sin(a) * rr, random.uniform(0.05, 2.0)))
        vel = Vector((math.cos(a), math.sin(a), random.uniform(0.3, 1.6))).normalized()
        ln = random.uniform(0.02, 0.09)
        wd = random.uniform(0.003, 0.008)
        side = vel.cross(Vector((0, 0, 1))).normalized() if abs(vel.z) < 0.99 else Vector((1, 0, 0))
        up2 = vel.cross(side).normalized()
        vs = [bm.verts.new(p + vel * ln), bm.verts.new(p + side * wd), bm.verts.new(p - vel * ln * 0.4),
              bm.verts.new(p - side * wd), bm.verts.new(p + up2 * wd)]
        bm.faces.new((vs[0], vs[1], vs[2], vs[3]))
        bm.faces.new((vs[0], vs[4], vs[2], vs[1]))
    me = bpy.data.meshes.new("Sparks")
    bm.to_mesh(me)
    bm.free()
    so = bpy.data.objects.new("Sparks", me)
    scene.collection.objects.link(so)
    me.materials.append(emit_mat("SparkM", srgb((255, 170, 90)), 6.0))
    # warm under-glow + cool rim so the toon ramp reacts to the effect
    for nm, typ, col, en, loc in (("Glow", "POINT", (1.0, 0.62, 0.3), 180, (0.3, -0.6, 0.3)),
                                  ("RimC", "POINT", (0.45, 0.8, 1.0), 220, (-0.9, 1.2, 1.9))):
        ld = bpy.data.lights.new(nm, typ)
        ld.color = col
        ld.energy = en
        lo = bpy.data.objects.new(nm, ld)
        lo.location = loc
        scene.collection.objects.link(lo)
    sun.rotation_euler = (math.radians(55), 0, math.radians(-50))
    cam = cam_obj("Cam_vfx", (1.5, -3.0, 0.8), (-0.15, 0.0, 0.95), lens=32)
    render_to(os.path.join(OUT, "vfx_raw.png"), cam, (1600, 1000))
