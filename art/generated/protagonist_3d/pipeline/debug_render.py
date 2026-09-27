import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import build_character as bc
arm = bpy.data.objects["HeroRig"]
cam = bpy.data.objects["Cam"]
out = os.path.join(bc.ROOT, "renders", "debug")
args = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
# args: outfit hair expression action frame view
outfit, hair, expr = (int(a) for a in args[:3])
act = args[3] if len(args) > 3 and args[3] != "-" else None
frame = int(args[4]) if len(args) > 4 else 1
view = args[5] if len(args) > 5 else "full"
bc.place_cam(cam, *{"full": bc.CAM_FULL, "hair": bc.CAM_HAIR, "face": bc.CAM_FACE, "front": ((0, -1.2, 1.66), (0, 0, 1.66), 85), "back": ((0.3, 1.2, 1.7), (0, 0, 1.66), 85)}[view])
bc.set_variant(arm, outfit=outfit, hair=hair, expression=expr, weapon=2 if act == "shoot" else 1)
arm.animation_data.action = bpy.data.actions[act] if act else None
if not act:
    from mathutils import Quaternion, Vector
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion(); pb.location = Vector()
bc.render(os.path.join(out, f"o{outfit}h{hair}e{expr}_{act}_{frame}_{view}.png"), frame=frame)
