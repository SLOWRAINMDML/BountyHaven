# Executed inside ww_build.py after measuring (shares its globals).
# Armature from the measured joints, proximity skin weights, a short blade, cloak wind shape key,
# and pose helpers (analytic two-bone IK) used by the action/VFX shots and the GLB animations.

arm_data = bpy.data.armatures.new("HeroRig")
rig = bpy.data.objects.new("HeroRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
EB = arm_data.edit_bones


def bone(name, head, tail, parent=None, connect=False):
    b = EB.new(name)
    b.head, b.tail = Vector(head), Vector(tail)
    b.roll = 0.0
    if parent:
        b.parent = EB[parent]
        b.use_connect = connect
    return b


z_hip = z_crotch + 0.06
bone("root", (0, 0, 0), (0, 0.15, 0))
bone("hips", (0, 0, z_hip), (0, 0, z_waist + 0.05), "root")
bone("spine", (0, 0, z_waist + 0.05), (0, 0, z_armpit - 0.03), "hips", True)
bone("chest", (0, 0, z_armpit - 0.03), (0, 0.005, z_neck - 0.02), "spine", True)
bone("neck", (0, 0.005, z_neck - 0.02), (0, 0.01, z_chin + 0.02), "chest", True)
bone("head", (0, 0.01, z_chin + 0.02), (0, 0.01, z_skull), "neck", True)
for S, sx in (("L", 1), ("R", -1)):
    sh, el, wr = arm_sets[S]
    bone(f"shoulder.{S}", (sx * 0.03, 0.005, z_neck - 0.035), sh, "chest")
    bone(f"upperarm.{S}", sh, el, f"shoulder.{S}", True)
    bone(f"forearm.{S}", el, wr, f"upperarm.{S}", True)
    bone(f"hand.{S}", wr, wr + Vector((0, -0.005, -0.1)), f"forearm.{S}", True)
    hp, kn, an = leg_sets[S]
    bone(f"thigh.{S}", hp, kn, "hips")
    bone(f"shin.{S}", kn, an, f"thigh.{S}", True)
    bone(f"foot.{S}", an, Vector((an.x + sx * 0.015, an.y - 0.16, 0.035)), f"shin.{S}", True)
bpy.ops.object.mode_set(mode="OBJECT")
BONES = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm_data.bones}

# ----------------------------------------------------------------------------- weapon (short blade, hand.R)
hR0, hR1 = BONES["hand.R"]
hand_dir = (hR1 - hR0).normalized()
grip = hR0 + hand_dir * 0.07 + Vector((0, -0.018, 0))
WEAPON = []


def wpart(name, off0, off1, rx, ry, mat, n=10, outline=0.0015, power=2.0):
    p0 = grip + hand_dir * off0
    p1 = grip + hand_dir * off1
    ob = tube(name, [p0, p0 + (p1 - p0) * 0.5, p1], rx, ry, n=n, up=Vector((0, -1, 0)), power=power)
    finish(ob, mat, subsurf=1, outline=outline)
    WEAPON.append(ob)
    return ob


STEEL_B = toon("Blade", (222, 228, 232), (120, 132, 150), rim=0.45, rim_col=(0.7, 0.9, 1.0))
EDGE = toon("BladeEdge", (190, 240, 255), (150, 220, 255), rim=0.0, emit=((120, 220, 255), 4.0))
wpart("WeaponGrip", -0.05, 0.06, [0.014, 0.015, 0.014], [0.014, 0.015, 0.014], LEATHER)
wpart("WeaponGuard", 0.06, 0.075, [0.045, 0.05, 0.045], [0.016, 0.017, 0.016], BRASS, power=3.0)
wpart("WeaponBlade", 0.075, 0.62, [0.026, 0.022, 0.004], [0.004, 0.0035, 0.001], STEEL_B, n=8, power=1.3)
wpart("WeaponEdge", 0.1, 0.6, [0.028, 0.024, 0.004], [0.0012, 0.001, 0.0005], EDGE, n=6, outline=0.0, power=1.3)
wpart("WeaponCore", -0.055, -0.07, [0.012, 0.013, 0.01], [0.012, 0.013, 0.01], GLOW, outline=0.0)

# ----------------------------------------------------------------------------- binding
def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


TORSO_B = ["hips", "spine", "chest", "neck", "shoulder.L", "shoulder.R"]
RIGID = [("Head", "head"), ("Nose", "head"), ("Ear", "head"), ("Hair", "head"), ("FaceNormalProxy", "head"),
         ("WeaponGrip", "hand.R"), ("WeaponGuard", "hand.R"), ("WeaponBlade", "hand.R"), ("WeaponEdge", "hand.R"),
         ("WeaponCore", "hand.R"),
         ("Buckle", "hips"), ("Pouch", "hips"), ("Compass", "hips"), ("ThighHolster", "thigh.R"),
         ("HarnessRing", "chest"), ("HarnessLamp", "chest"), ("PocketFlap", "chest"), ("PocketStud", "chest")]
for S in ("L", "R"):
    RIGID += [(f"Palm{S}", f"hand.{S}"), (f"Finger{S}", f"hand.{S}"), (f"Thumb{S}", f"hand.{S}"),
              (f"GloveCuff{S}", f"forearm.{S}"), (f"GloveBand{S}", f"forearm.{S}"),
              (f"BootFoot{S}", f"foot.{S}"), (f"BootSole{S}", f"foot.{S}"), (f"BootShaft{S}", f"shin.{S}"),
              (f"BootStrap{S}", f"shin.{S}"), (f"BootBuckle{S}", f"shin.{S}"), (f"ThighStrap{S}", f"thigh.{S}"),
              (f"KneePad{S}", f"shin.{S}"), (f"SleevePatch{S}", f"upperarm.{S}"),
              (f"SleeveRoll{S}", f"forearm.{S}")]


def candidates(name):
    for S in ("L", "R"):
        if name.startswith(("Sleeve", "Forearm")) and name.endswith(S):
            return [f"shoulder.{S}", f"upperarm.{S}", f"forearm.{S}", f"hand.{S}"]
        if name == f"PantsLeg{S}":
            return ["hips", f"thigh.{S}", f"shin.{S}"]
    if name == "PantsHip":
        return ["hips", "spine", "thigh.L", "thigh.R"]
    if name.startswith(("Jacket", "Harness")):
        return TORSO_B
    if name.startswith("Cloak"):
        return ["spine", "chest", "shoulder.L", "shoulder.R", "hips"]
    if name.startswith(("Belt", "HipBelt")):
        return ["hips"]
    return TORSO_B


def rigid_bone(name):
    for pre, b in RIGID:
        if name.startswith(pre):
            return b
    return None


for ob in list(COLL.objects) + WEAPON:
    if ob.type != "MESH" or ob.parent is not None:
        continue
    rb = rigid_bone(ob.name)
    mw = ob.matrix_world.copy()
    if rb:
        ob.parent = rig
        ob.parent_type = "BONE"
        ob.parent_bone = rb
        ob.matrix_world = mw
        continue
    cands = candidates(ob.name)
    groups = {b: ob.vertex_groups.new(name=b) for b in cands}
    for v in ob.data.vertices:
        p = mw @ v.co
        ds = sorted(((seg_dist(p, *BONES[b]), b) for b in cands))[:2]
        w = [1.0 / (d ** 4 + 1e-7) for d, _ in ds]
        tot = sum(w)
        for (d, b), wi in zip(ds, w):
            groups[b].add([v.index], wi / tot, "REPLACE")
    ob.parent = rig
    ob.matrix_world = mw
    am = ob.modifiers.new("Rig", "ARMATURE")
    am.object = rig
    ob.modifiers.move(len(ob.modifiers) - 1, 0)

# cloak wind (shape key): billows back and out to the left, grows toward the hem
cl = bpy.data.objects["Cloak"]
cl.shape_key_add(name="Basis")
wind = cl.shape_key_add(name="Wind")
top_z = max(v.co.z for v in cl.data.vertices)
for i, v in enumerate(cl.data.vertices):
    k = max(0.0, (top_z - v.co.z) / 0.9) ** 1.3
    wind.data[i].co = v.co + Vector((0.34 * k + 0.05 * math.sin(v.co.z * 18) * k, 0.38 * k, 0.26 * k))


# ----------------------------------------------------------------------------- pose helpers
def pb_update():
    bpy.context.view_layer.update()


def aim(name, target_dir):
    pb = rig.pose.bones[name]
    M = pb.matrix.copy()
    y = M.to_3x3().col[1].normalized()
    q = y.rotation_difference(Vector(target_dir).normalized())
    R = q.to_matrix().to_4x4()
    head = M.translation.copy()
    pb.matrix = Matrix.Translation(head) @ R @ Matrix.Translation(-head) @ M
    pb_update()


def turn(name, axis, deg):
    pb = rig.pose.bones[name]
    M = pb.matrix.copy()
    head = M.translation.copy()
    pb.matrix = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, Vector(axis)) @ Matrix.Translation(-head) @ M
    pb_update()


def ik2(upper, lower, target, pole):
    """Aim a two-bone chain so the lower bone's tail lands on target; the joint bends toward pole."""
    a = rig.pose.bones[upper].matrix.translation.copy()
    l1 = (BONES[upper][1] - BONES[upper][0]).length
    l2 = (BONES[lower][1] - BONES[lower][0]).length
    t = Vector(target)
    d = t - a
    dist = min(d.length, (l1 + l2) * 0.999)
    d.normalize()
    cos_a = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    ang = math.acos(max(-1.0, min(1.0, cos_a)))
    pv = Vector(pole) - d * Vector(pole).dot(d)
    pv.normalize()
    joint = a + (d * math.cos(ang) + pv * math.sin(ang)) * l1
    aim(upper, joint - a)
    aim(lower, t - joint)


def reset_pose():
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    pb_update()


def pose_slash():
    """Lunge-slash: right foot forward, blade arm sweeping out, cloak blown back (see concepts/06)."""
    reset_pose()
    rb = rig.pose.bones["root"]
    rb.location = (0, 0, 0)
    hips = rig.pose.bones["hips"]
    hips.location = Vector((0.0, 0.0, 0.0))
    pb_update()
    turn("hips", (0, 0, 1), -22)
    M = hips.matrix.copy()
    M.translation += Vector((0.02, 0.05, -0.16))
    hips.matrix = M
    pb_update()
    turn("spine", (1, 0, 0), 10)
    turn("spine", (0, 0, 1), 12)
    turn("chest", (0, 0, 1), 14)
    turn("chest", (0, 1, 0), 6)
    ik2("thigh.R", "shin.R", (-0.26, -0.42, 0.12), (0, -1, 0.2))
    aim("foot.R", (-0.15, -1, -0.05))
    ik2("thigh.L", "shin.L", (0.24, 0.42, 0.2), (0.1, -1, -0.2))
    aim("foot.L", (0.05, -0.2, -1))
    ik2("upperarm.R", "forearm.R", (-0.72, -0.42, 1.28), (0, 0.4, -1))
    aim("hand.R", (-0.8, -0.45, 0.3))
    ik2("upperarm.L", "forearm.L", (0.62, 0.3, 1.02), (0.2, 1, -0.3))
    aim("hand.L", (0.6, 0.2, -0.5))
    turn("neck", (0, 0, 1), 14)
    turn("head", (0, 0, 1), 10)
    turn("head", (1, 0, 0), -6)
    cl.data.shape_keys.key_blocks["Wind"].value = 1.0


def pose_rest():
    reset_pose()
    cl.data.shape_keys.key_blocks["Wind"].value = 0.0
