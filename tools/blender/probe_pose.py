# blender -b -P probe_pose.py -- <rig.glb> <out_dir>   renders the imported rig at the idle action (as is / frozen)
import bpy, sys, os
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
glb, out = argv[0], argv[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
scene = bpy.context.scene
arm = next(o for o in scene.objects if o.type == 'ARMATURE')
for o in list(scene.objects):
    if o.type == 'MESH' and not any(m and m.name == "arms" for m in o.data.materials):
        bpy.data.objects.remove(o, do_unlink=True)
mesh = next(o for o in scene.objects if o.type == 'MESH')
print("MODS", [(m.type, getattr(m, 'object', None) and m.object.name, getattr(m, 'use_deform_preserve_volume', None)) for m in mesh.modifiers])
ad = arm.animation_data
print("ACTION", ad.action and ad.action.name, "NLA", [t.name for t in ad.nla_tracks])
for t in list(ad.nla_tracks):
    ad.nla_tracks.remove(t)
act = bpy.data.actions.get("Armature|FPS_Pistol_Idle")
ad.action = act
if hasattr(ad, "action_slot") and act.slots:
    ad.action_slot = act.slots[0]
print("SLOT", getattr(ad, "action_slot", None), "range", tuple(act.frame_range))
scene.frame_set(int(act.frame_range[0]))
cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
scene.render.engine = 'BLENDER_WORKBENCH'; scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x, scene.render.resolution_y = 640, 480
hc = next(b for b in arm.pose.bones if b.name.startswith("Head_Cam"))
eye = arm.matrix_world @ hc.head
hand = next(b for b in arm.pose.bones if b.name.startswith("Hand_R"))
tgt = arm.matrix_world @ hand.head
print("EYE", eye, "HAND", tgt)
for tag, pos in (("eye", eye), ("side", tgt + Vector((0.6, 0.0, 0.1))), ("far", tgt + (eye - tgt) * 4 + Vector((0, 0, 0.3)))):
    cam.location = pos
    cam.rotation_mode = 'QUATERNION'
    cam.rotation_quaternion = (tgt - pos).to_track_quat('-Z', 'Y')
    scene.render.filepath = os.path.join(out, "pose_%s.png" % tag)
    bpy.ops.render.render(write_still=True)
