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
