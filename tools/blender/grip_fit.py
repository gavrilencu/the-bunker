# Grip solver for the first-person arms (Cransh FPS rig) and the props held in the hands.
#
# Usage:
#   blender -b -P tools/blender/grip_fit.py -- <rig.glb> <grips_dump.json> <models_dir> <out.json> <render_dir> [grip ...]
#
# <grips_dump.json> comes from the game (--dumpgrips=...): every bone's global pose at the
# rig's authored frame (skeleton space, Godot) and where each prop sits in that space.
# For every prop the solver
#   1. maps Godot skeleton space onto Blender world space (similarity from the joint
#      positions of both programs: bone orientation conventions differ, joints don't),
#   2. opens the fingers of that hand, pushes the object out of the palm until the palm
#      skin only touches it,
#   3. closes every finger joint by joint (proximal -> distal, thumb last) until the skin
#      of that finger touches the object (skinned mesh, BVH contact),
#   4. renders the result from the player's eye and from the side,
#   5. writes, in Godot terms, each finger bone's transform relative to the hand bone and
#      the prop's transform relative to the hand bone (out.json, read by the game).
import bpy, bmesh, sys, os, json, math
import numpy as np
from mathutils import Matrix, Vector, Quaternion
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
RIG, DUMP, MODELS, OUT, RENDERS = argv[:5]
ONLY = set(argv[5:])
os.makedirs(RENDERS, exist_ok=True)

SIDE_CHAINS = {
    "r": [["Bone_R.004", "Bone_R.005", "Bone_R.006", "Bone_R.007"], ["Bone_R.008", "Bone_R.009", "Bone_R.010", "Bone_R.011"],
          ["Bone_R.012", "Bone_R.013", "Bone_R.014", "Bone_R.015"], ["Bone_R.016", "Bone_R.017", "Bone_R.018", "Bone_R.019"],
          ["Bone_R.020", "Bone_R.021", "Bone_R.022"]],
    "l": [["Bone_L.004", "Bone_L.005", "Bone_L.006", "Bone_L.007"], ["Bone_L.008", "Bone_L.009", "Bone_L.010", "Bone_L.011"],
          ["Bone_L.012", "Bone_L.013", "Bone_L.014", "Bone_L.015"], ["Bone_L.016", "Bone_L.017", "Bone_L.018", "Bone_L.019"],
          ["Bone_L.020", "Bone_L.021", "Bone_L.022"]],
}
HAND = {"r": "Hand_R", "l": "Hand_L"}
# glTF (Y up) local -> Blender (Z up) local
C4 = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

dump = json.load(open(DUMP))


def full_name(prefix, names):
    for n in names:
        if n.startswith(prefix) and "end" not in n.lower():
            return n
    return None


def g_xf(arr):
    """Godot Transform3D array (basis columns x, y, z, origin) -> 4x4."""
    m = Matrix.Identity(4)
    for c in range(3):
        for r in range(3):
            m[r][c] = arr[c * 3 + r]
    m[0][3], m[1][3], m[2][3] = arr[9], arr[10], arr[11]
    return m


def xf_arr(m):
    return [m[0][0], m[1][0], m[2][0], m[0][1], m[1][1], m[2][1], m[0][2], m[1][2], m[2][2], m[0][3], m[1][3], m[2][3]]


# --- scene ------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
# the rig's bind pose is not its rest pose: guessing it breaks the skinning in Blender
bpy.ops.import_scene.gltf(filepath=RIG, guess_original_bind_pose=False, bone_heuristic='TEMPERANCE')
scene = bpy.context.scene
arm = next(o for o in scene.objects if o.type == 'ARMATURE')
arms_mesh = None
for o in list(scene.objects):
    if o.type == 'MESH':
        if any(m and m.name == "arms" for m in o.data.materials):
            arms_mesh = o
        else:
            bpy.data.objects.remove(o, do_unlink=True)
# the authored frame (same as the game's rig at build)
ad = arm.animation_data
for t in list(ad.nla_tracks):
    ad.nla_tracks.remove(t)
act = bpy.data.actions.get("Armature|FPS_Pistol_Idle")
ad.action = act
if hasattr(ad, "action_slot") and act.slots:
    ad.action_slot = act.slots[0]
scene.frame_set(int(act.frame_range[0]))
bpy.context.view_layer.update()
# freeze that pose, drop the action (pose bones keep their values)
for pb in arm.pose.bones:
    pb.rotation_mode = 'QUATERNION'
frozen = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in arm.pose.bones}
ad.action = None
for pb in arm.pose.bones:
    pb.location, pb.rotation_quaternion, pb.scale = frozen[pb.name]
bpy.context.view_layer.update()
bone_names = [b.name for b in arm.data.bones]

# --- Godot skeleton space -> Blender world (similarity, Umeyama) --------------
src, dst = [], []
for name, b in dump["bones"].items():
    if "end" in name.lower() or name not in arm.pose.bones:
        continue
    gp = b["pose"][9:12]
    bp = arm.matrix_world @ arm.pose.bones[name].head
    src.append(gp)
    dst.append(list(bp))
src, dst = np.array(src), np.array(dst)
mu_s, mu_d = src.mean(0), dst.mean(0)
xs, xd = src - mu_s, dst - mu_d
U, D, Vt = np.linalg.svd(xd.T @ xs / len(src))
Sg = np.eye(3)
if np.linalg.det(U) * np.linalg.det(Vt) < 0:
    Sg[2, 2] = -1
R = U @ Sg @ Vt
scale = np.trace(np.diag(D) @ Sg) / (xs ** 2).sum(1).mean()
t = mu_d - scale * R @ mu_s
S = Matrix.Identity(4)
for i in range(3):
    for j in range(3):
        S[i][j] = scale * R[i, j]
    S[i][3] = t[i]
S_inv = S.inverted()
err = np.sqrt((((scale * (R @ src.T)).T + t - dst) ** 2).sum(1)).max()
print("[grip] similarity scale=%.4f max joint error=%.5f (Blender units, %d joints)" % (scale, err, len(src)))
U_M = scale  # Blender units per Godot skeleton unit (metres)


def g_pose(name):
    return g_xf(dump["bones"][name]["pose"])


# --- mesh helpers ---------------------------------------------------------------
vg_names = {g.index: g.name for g in arms_mesh.vertex_groups}
dominant = []
for v in arms_mesh.data.vertices:
    best, bw = None, 0.0
    for g in v.groups:
        if g.weight > bw:
            best, bw = vg_names.get(g.group), g.weight
    dominant.append(best)


def skinned_world():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = arms_mesh.evaluated_get(dg)
    me = ev.to_mesh()
    mw = arms_mesh.matrix_world
    pts = [mw @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    return pts


def verts_of(groups):
    gs = set(groups)
    return [i for i, d in enumerate(dominant) if d in gs]


def prop_bvh(root):
    """BVH of the prop's convex hull (closed, outward normals: a reliable inside test
    even for models with inner walls / open necks)."""
    dg = bpy.context.evaluated_depsgraph_get()
    verts = []
    for o in [root] + list(root.children_recursive):
        if o.type != 'MESH':
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = o.matrix_world
        verts += [mw @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    bm = bmesh.new()
    for v in verts:
        bm.verts.new(v)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bm.normal_update()
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    return bvh, verts


def depth(bvh, p):
    """Signed distance to the prop surface (negative = inside)."""
    loc, nrm, idx, d = bvh.find_nearest(p)
    if loc is None:
        return 1e9
    return d if (p - loc).dot(nrm) >= 0.0 else -d


def worst(bvh, pts, idxs):
    return min((depth(bvh, pts[i]) for i in idxs), default=1e9)


# --- props ----------------------------------------------------------------------
def load_prop(key, spec):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, spec["model"], spec["model"] + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new("PROP_" + key, None)
    scene.collection.objects.link(root)
    for o in new:
        if o.parent is None:
            o.parent = root
    root.matrix_world = S @ g_xf(spec["xf"]) @ C4.inverted()
    bpy.context.view_layer.update()
    return root


def set_rot(pb, base, axis, ang):
    pb.rotation_quaternion = base @ Quaternion(axis, ang)


def solve(key, spec):
    side = spec["side"]
    hand = full_name(HAND[side], bone_names)
    chains = [[full_name(p, bone_names) for p in ch] for ch in SIDE_CHAINS[side]]
    # palm frame from the joints (authored grip, fingers curled): fingers' direction,
    # across the knuckles, and the normal on the side the fingers close toward
    W = arm.matrix_world
    wrist = W @ arm.pose.bones[hand].head
    knuckles = [W @ arm.pose.bones[ch[1]].head for ch in chains[:4]]
    tips = [W @ arm.pose.bones[ch[-1]].head for ch in chains[:4]]
    kmean = sum(knuckles, Vector()) / 4.0
    fdir = (kmean - wrist).normalized()
    lat = (knuckles[0] - knuckles[3]).normalized()
    n = fdir.cross(lat).normalized()
    palm_c = wrist.lerp(kmean, 0.55)
    if (sum(tips, Vector()) / 4.0 - palm_c).dot(n) < 0.0:
        n = -n
    if os.environ.get("GRIP_DEBUG"):
        for nm, pos, rad in (("dbg_palm", palm_c, 0.006), ("dbg_n", palm_c + n * 0.05, 0.008), ("dbg_tips", sum(tips, Vector()) / 4.0, 0.005), ("dbg_wrist", wrist, 0.005)):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=rad * U_M, location=pos)
            bpy.context.object.name = nm
        print("[grip] palm_c", tuple(round(v, 3) for v in palm_c), "n", tuple(round(v, 3) for v in n), "fdir", tuple(round(v, 3) for v in fdir), "tips", tuple(round(v, 3) for v in sum(tips, Vector()) / 4.0))
    # start from the authored grip (a fist round a pistol grip)
    root = load_prop(key, spec)
    bvh, pverts = prop_bvh(root)
    lo = Vector((min(v.x for v in pverts), min(v.y for v in pverts), min(v.z for v in pverts)))
    hi = Vector((max(v.x for v in pverts), max(v.y for v in pverts), max(v.z for v in pverts)))
    print("[grip] %s: prop objects %s, size %s mm" % (key, [(o.name, o.type, len(o.data.vertices) if o.type == 'MESH' else 0) for o in root.children_recursive], tuple(round(v / U_M * 1000) for v in (hi - lo))))
    axis = (root.matrix_world.to_3x3() @ Vector((0, 0, 1))).normalized()
    center = sum(pverts, Vector()) / len(pverts)
    palm_groups = [hand] + [ch[0] for ch in chains[:4]]
    palm = verts_of(palm_groups)
    pts = skinned_world()
    print("[grip] %s: palm verts %d, deepest %.1f mm" % (key, len(palm), worst(bvh, pts, palm) / U_M * 1000.0))
    pc = sum((pts[i] for i in palm), Vector()) / len(palm)
    away = n
    eps = 0.0015 * U_M
    step = 0.001 * U_M
    # how far each joint opens from the authored (pistol) grip, by object thickness:
    # [knuckle, middle, tip, thumb 1, thumb 2 (deg), object pushed off the palm (mm)]
    table = {"bottle": [22, 14, 8, 12, 6, 14], "pills": [10, 6, 3, 6, 3, 6], "roll": [28, 16, 8, 14, 6, 18],
             "spoon": [0, 0, 0, 0, 0, 0], "bite_tomato": [24, 14, 8, 12, 6, 14], "bite_potato": [16, 10, 6, 10, 5, 10],
             "bite_crackers": [20, 12, 6, 10, 5, 12], "can": [32, 18, 10, 14, 8, 22]}
    env = os.environ.get("GRIP_PARAMS")
    params = [float(x) for x in env.split(",")] if env else table.get(key, table["bottle"])
    o_prox, o_mid, o_dist, o_t1, o_t2, off_mm = params
    root.matrix_world.translation += n * (off_mm / 1000.0 * U_M)
    bpy.context.view_layer.update()
    bvh, pverts = prop_bvh(root)
    center = sum(pverts, Vector()) / len(pverts)

    def curl_axis(pb, ch):
        base = pb.rotation_quaternion.copy()
        ids = verts_of([ch[-1]])
        pts = skinned_world()
        tip0 = sum((pts[i] for i in ids), Vector()) / max(len(ids), 1)
        to_axis = (center - tip0)
        to_axis -= axis * to_axis.dot(axis)
        best, gain = None, 0.0
        for ax in (Vector((1, 0, 0)), Vector((-1, 0, 0))):
            set_rot(pb, base, ax, math.radians(8))
            bpy.context.view_layer.update()
            pts = skinned_world()
            tip1 = sum((pts[i] for i in ids), Vector()) / max(len(ids), 1)
            g = (tip1 - tip0).dot(to_axis.normalized())
            if g > gain:
                best, gain = ax, g
        pb.rotation_quaternion = base
        bpy.context.view_layer.update()
        return best or Vector((-1, 0, 0))

    for ci, ch in enumerate(chains):
        joints = ch[1:]
        opens = [o_t1, o_t2] if ci == 4 else [o_prox, o_mid, o_dist]
        for bn, o in zip(joints, opens):
            pb = arm.pose.bones[bn]
            ax = curl_axis(pb, ch) if ci < 4 else Vector((0, 0, -1))
            set_rot(pb, pb.rotation_quaternion.copy(), ax, -math.radians(o))
            bpy.context.view_layer.update()
    pts = skinned_world()
    allf = verts_of([bn for ch in chains for bn in ch[1:]])
    print("[grip] %s: params %s -> palm %.1f mm, fingers deepest %.1f mm" % (key, params, worst(bvh, pts, palm) / U_M * 1000, worst(bvh, pts, allf) / U_M * 1000))
    return root, hand, chains


def render_mask(side):
    sfx = "_R" if side == "r" else "_L"
    keep = [n for n in vg_names.values() if (sfx in n or (".R" in n if side == "r" else ".L" in n)) and not n.startswith(("Arm_", "UpArm", "IK_PoleTrgt"))]
    vg = arms_mesh.vertex_groups.get("render_mask") or arms_mesh.vertex_groups.new(name="render_mask")
    vg.remove(list(range(len(arms_mesh.data.vertices))))
    vg.add(verts_of(keep), 1.0, 'REPLACE')
    mod = arms_mesh.modifiers.get("mask") or arms_mesh.modifiers.new("mask", 'MASK')
    mod.vertex_group = "render_mask"
    return mod


def render(key, root, hand_name):
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 35
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.render.resolution_x, scene.render.resolution_y = 640, 480
    _, pverts = prop_bvh(root)
    tgt = sum(pverts, Vector()) / len(pverts)
    eye = arm.matrix_world @ arm.pose.bones[full_name("Head_Cam", bone_names)].head
    span = max(max((v - tgt).length for v in pverts), 0.07 * U_M)
    for tag, pos in (("eye", tgt + (eye - tgt).normalized() * span * 4.5),
                     ("side", tgt + (Vector((0, 0, 1)).cross(eye - tgt)).normalized() * span * 4.5 + Vector((0, 0, span)))):
        cam.location = pos
        cam.rotation_mode = 'QUATERNION'
        cam.rotation_quaternion = (tgt - pos).to_track_quat('-Z', 'Y')
        scene.render.filepath = os.path.join(RENDERS, "%s_%s.png" % (key, tag))
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)


# --- run ------------------------------------------------------------------------
results = json.load(open(OUT)) if os.path.exists(OUT) else {}
base_world = {pb.name: (arm.matrix_world @ pb.matrix).copy() for pb in arm.pose.bones}
SKIP = {"pills"}   # tiny, and its file carries its own armature: keeps the authored grip
for key, spec in dump["props"].items():
    if (ONLY and key not in ONLY) or (not ONLY and key in SKIP):
        continue
    root, hand, chains = solve(key, spec)
    mask = render_mask(spec["side"])
    render(key, root, hand)
    arms_mesh.modifiers.remove(mask)
    H0 = g_pose(hand)
    H0i = H0.inverted()
    fingers = {}
    for ch in chains:
        for bn in ch:
            F1b = arm.matrix_world @ arm.pose.bones[bn].matrix
            Xb = F1b @ base_world[bn].inverted()
            Xg = S_inv @ Xb @ S
            fingers[bn] = xf_arr(H0i @ Xg @ g_pose(bn))
    Pg = S_inv @ root.matrix_world @ C4
    results[key] = {"side": spec["side"], "model": spec["model"], "hand": hand, "fingers": fingers, "prop": xf_arr(H0i @ Pg)}
    # reset for the next prop
    for o in [root] + list(root.children_recursive):
        bpy.data.objects.remove(o, do_unlink=True)
    for pb in arm.pose.bones:
        pb.location, pb.rotation_quaternion, pb.scale = frozen[pb.name]
    bpy.context.view_layer.update()
json.dump(results, open(OUT, "w"), indent=1)
print("[grip] wrote", OUT, sorted(results))
