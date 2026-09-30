# Executed inside ww_build.py (after the rig) with --face: face close-ups + projected 3D landmarks per view.
from bpy_extras.object_utils import world_to_camera_view
from mathutils.bvhtree import BVHTree

FACE_VIEWS = {"front": (0, 0), "q34": (48, -8), "side": (90, 0)}   # starting azimuth, elevation (deg)
FREF = json.load(open(os.path.join(ROOT, "measure", "face", "face_landmarks.json")))
FPAIRS = {"front": {"eye_r": "eye_r", "eye_l": "eye_l", "brow_r": "brow_r", "brow_l": "brow_l", "nose": "nose",
                    "mouth": "mouth", "mouth_rc": "mouth_rc", "mouth_lc": "mouth_lc", "chin": "chin"},
          "q34": {"eye_far": "eye_r", "eye_near": "eye_l", "nose": "nose", "mouth": "mouth", "chin": "chin", "ear": "ear"},
          "side": {"eye": "eye_l", "nose": "nose", "mouth": "mouth", "chin": "chin", "ear": "ear"}}
FALIGN = {"front": ("eye_r", "eye_l"), "q34": ("eye_far", "eye_near"), "side": ("eye", "chin")}


def view_error(view, proj):
    ref = FREF[view]
    a1, a2 = FALIGN[view]
    r1, r2 = complex(*ref[a1]), complex(*ref[a2])
    m1, m2 = complex(*proj[FPAIRS[view][a1]]), complex(*proj[FPAIRS[view][a2]])
    if abs(m2 - m1) < 1e-6:
        return 1e9
    a = (r2 - r1) / (m2 - m1)
    b = r1 - a * m1
    sc = abs(r2 - r1)
    errs = [abs(a * complex(*proj[mn]) + b - complex(*ref[rn])) / sc
            for rn, mn in FPAIRS[view].items() if rn not in FALIGN[view]]
    return sum(errs) / len(errs)


def _bvh(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    e = ob.evaluated_get(dg)
    me = e.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(ob.matrix_world)
    t = BVHTree.FromBMesh(bm)
    verts = [v.co.copy() for v in bm.verts]
    bm.free()
    e.to_mesh_clear()
    return t, verts


def face_points():
    ht, hv = _bvh(bpy.data.objects["Head"])
    nt, nv = _bvh(bpy.data.objects["Nose"])

    def surf(x, z):
        hit = ht.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
        return hit[0] if hit[0] is not None else Vector((x, -0.08, z))

    ex = FS["iod"] / 2
    ze = z_eye + FS["eye_dz"]
    zm = z_eye + FS["mouth_dz"]
    pts = {"eye_r": surf(-ex, ze), "eye_l": surf(ex, ze),
           "brow_r": surf(-(ex + FS["brow_dx"]), z_eye + FS["brow_dz"]),
           "brow_l": surf(ex + FS["brow_dx"], z_eye + FS["brow_dz"]),
           "nose": min(nv, key=lambda v: v.y), "mouth": surf(0, zm),
           "mouth_rc": surf(-FS["mouth_w"] * 0.42, zm), "mouth_lc": surf(FS["mouth_w"] * 0.42, zm)}
    front = [v for v in hv if v.y < -0.02 and abs(v.x) < 0.02]
    pts["chin"] = min(front, key=lambda v: v.z)
    ear = bpy.data.objects["EarL"]
    et, ev = _bvh(ear)
    pts["ear"] = sum(ev, Vector()) / len(ev)
    return pts


if "--face" in ARGS:
    pose_rest()
    for w in WEAPON:
        w.hide_render = True
    scene.render.film_transparent = True
    pts = face_points()
    out = {}
    zc = z_eye - 0.03
    def place(cam, az, el):
        a, e = math.radians(az), math.radians(el)
        d = 2.2
        cam.location = Vector((math.sin(a) * math.cos(e) * d, -math.cos(a) * math.cos(e) * d, zc + math.sin(e) * d))
        cam.rotation_euler = (Vector((0, 0, zc)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        bpy.context.view_layer.update()

    def project(cam, res):
        return {k: [world_to_camera_view(scene, cam, p).x * res, (1 - world_to_camera_view(scene, cam, p).y) * res]
                for k, p in pts.items()}

    fitted = {}
    for name, (az0, el0) in FACE_VIEWS.items():
        cam = cam_obj("CamFace_" + name, (0, -2, zc), (0, 0, zc), lens=200)
        scene.render.resolution_x = scene.render.resolution_y = 800
        best = None
        # the illustration's head pose is unknown: fit camera azimuth/elevation to its landmarks
        # allowed pose ranges keep each view what it claims to be (front stays frontal, side stays a profile)
        az_rng, el_rng = {"front": ((-6, 6), (-12, 12)), "q34": ((30, 66), (-24, 24)), "side": ((80, 100), (-12, 12))}[name]
        for az in range(az_rng[0], az_rng[1] + 1, 2):
            for el in range(el_rng[0], el_rng[1] + 1, 3):
                place(cam, az, el)
                err = view_error(name, project(cam, 800))
                if best is None or err < best[0]:
                    best = (err, az, el)
        place(cam, best[1], best[2])
        fitted[name] = [best[1], best[2]]
        az = best[1]
        sun.rotation_euler = (math.radians(50), 0, math.radians(-35 + az))
        res = 800
        render_to(os.path.join(OUT, f"fface_{name}.png"), cam, (res, res))
        proj = {}
        for k, p in pts.items():
            c = world_to_camera_view(scene, cam, p)
            proj[k] = [c.x * res, (1 - c.y) * res]
        out[name] = proj
    out["camera_fit"] = fitted
    out["mesh"] = {"chin_z": pts["chin"].z, "eye_z": z_eye + FS["eye_dz"], "iod": FS["iod"],
                   "face_w_eye": section_width(bpy.data.objects["Head"], z_eye + FS["eye_dz"])}
    json.dump(out, open(os.path.join(OUT, "face_landmarks_3d.json"), "w"), indent=1)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
