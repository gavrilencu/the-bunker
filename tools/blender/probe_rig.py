# Usage: blender -b -P probe_rig.py -- <rig.glb> <out_dir>
# Imports the FPS arms rig, prints bones (head/tail in armature space) and meshes.
import bpy, sys, os
argv = sys.argv[sys.argv.index("--") + 1:]
glb, out = argv[0], argv[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
print("ARMATURE", arm.name, "world scale", tuple(round(v, 4) for v in arm.matrix_world.to_scale()))
for b in arm.data.bones:
    if b.name.startswith(("Bone_R", "Hand_R", "IK_Hand_Cntrl_R", "Forearm_R", "Head_Cam")):
        h = arm.matrix_world @ b.head_local
        t = arm.matrix_world @ b.tail_local
        print("BONE %-22s parent=%-22s head=(%.3f,%.3f,%.3f) tail=(%.3f,%.3f,%.3f) len=%.3f" % (b.name, b.parent.name if b.parent else "-", *h, *t, b.length * arm.matrix_world.to_scale()[0]))
for o in bpy.context.scene.objects:
    if o.type == 'MESH':
        groups = [g.name for g in o.vertex_groups][:6]
        print("MESH", o.name, "verts", len(o.data.vertices), "mats", [m.name for m in o.data.materials if m], "groups", groups)
print("ACTIONS", [a.name for a in bpy.data.actions])
