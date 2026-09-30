# Executed inside ww_build.py when --glb <path> is given: animations + palette + GLB for Godot.

def key_pose(action_name, frames):
    """frames: list of (frame, pose_fn, wind)."""
    rig.animation_data_create()
    act = bpy.data.actions.new(action_name)
    rig.animation_data.action = act
    for f, fn, w in frames:
        fn()
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    act.use_fake_user = True
    tr = rig.animation_data.nla_tracks.new()
    tr.name = action_name
    tr.strips.new(action_name, 1, act)
    rig.animation_data.action = None
    return act


def breathe(k):
    def fn():
        pose_rest()
        turn("chest", (1, 0, 0), -1.5 * k)
        turn("head", (1, 0, 0), 1.0 * k)
        turn("upperarm.L", (0, 1, 0), 2.0 * k)
        turn("upperarm.R", (0, 1, 0), -2.0 * k)
    return fn


def ready_pose():
    pose_slash()
    turn("chest", (0, 0, 1), 30)
    ik2("upperarm.R", "forearm.R", (0.1, -0.35, 1.2), (0, 1, -0.5))
    aim("hand.R", (0.8, -0.2, 0.4))


key_pose("Idle", [(1, breathe(0), 0), (30, breathe(1), 0), (60, breathe(0), 0)])
key_pose("Slash", [(1, breathe(0), 0), (8, ready_pose, 1), (14, pose_slash, 1), (30, pose_slash, 1), (44, breathe(0), 0)])
pose_rest()

# palette for the Godot toon shader (materials are rebuilt in Godot by name)
pal = {}
for m in bpy.data.materials:
    if "lit" in m.keys():
        pal[m.name] = {"lit": list(m["lit"]), "shade": list(m["shade"]), "tex": m.get("tex", ""),
                       "tex_mix": m.get("tex_mix", 1.0), "rim": m.get("rim", 0.15), "emit": list(m.get("emit", [])),
                       "outline": list(m["outline"])}
json.dump(pal, open(os.path.join(ROOT, "exports", "palette.json"), "w"), indent=1)

# outlines are drawn in Godot by a grow pass; keep them out of the GLB
for ob in bpy.data.objects:
    for md in ob.modifiers:
        if md.name == "Outline":
            md.show_viewport = False
            md.show_render = False
for ob in bpy.data.objects:
    ob.select_set(ob.name in COLL.objects or ob == rig or ob in WEAPON)
for ob in ("Key", "FaceNormalProxy"):
    if ob in bpy.data.objects:
        bpy.data.objects[ob].select_set(False)
bpy.ops.export_scene.gltf(filepath=arg("--glb"), export_format="GLB", use_selection=True, export_apply=True,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True,
                          export_morph=True, export_yup=True)
for ob in bpy.data.objects:
    for md in ob.modifiers:
        if md.name == "Outline":
            md.show_viewport = True
            md.show_render = True
print("GLB_OK", arg("--glb"))
