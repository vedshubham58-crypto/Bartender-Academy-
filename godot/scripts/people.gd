class_name People
extends RefCounted
## Loads the 3D people (Mixamo characters) and poses them by aiming their bones,
## so they can sit at the bar with their arms on the counter, carry trays and so on.

const MODELS := ["kate", "remy", "megan", "leonard", "josh"]

static var _scenes := {}


static func spawn(model: String, parent: Node3D) -> Node3D:
	if not _scenes.has(model):
		_scenes[model] = load("res://models/%s.glb" % model)
	var n: Node3D = _scenes[model].instantiate()
	parent.add_child(n)
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		ap.stop()
	return n


static func skel(n: Node3D) -> Skeleton3D:
	var s := n.find_children("*", "Skeleton3D", true, false)
	return s[0] if s.size() > 0 else null


static func bone(s: Skeleton3D, suffix: String) -> int:
	for i in s.get_bone_count():
		if s.get_bone_name(i).ends_with(suffix):
			return i
	return -1


## Bone transform in skeleton space, worked out from the local poses.
static func gpose(s: Skeleton3D, b: int) -> Transform3D:
	var t := s.get_bone_pose(b)
	var p := s.get_bone_parent(b)
	while p >= 0:
		t = s.get_bone_pose(p) * t
		p = s.get_bone_parent(p)
	return t


static func world_pos(s: Skeleton3D, suffix: String) -> Vector3:
	var b := bone(s, suffix)
	return s.global_transform * gpose(s, b).origin if b >= 0 else s.global_position


## Turns a bone so the line to its child bone points along [param dir] (world space).
static func aim(s: Skeleton3D, suffix: String, child_suffix: String, dir: Vector3) -> void:
	var b := bone(s, suffix)
	var c := bone(s, child_suffix)
	if b < 0 or c < 0 or dir.length() < 0.0001:
		return
	var sg := s.global_transform.basis
	var gb := gpose(s, b)
	var gc := gpose(s, c)
	var cur := (sg * (gc.origin - gb.origin)).normalized()
	var to := dir.normalized()
	if cur.dot(to) > 0.9999:
		return
	var q := Quaternion(cur, to)
	var new_g := sg.inverse() * (Basis(q) * (sg * gb.basis))
	var p := s.get_bone_parent(b)
	var pb := gpose(s, p).basis if p >= 0 else Basis()
	s.set_bone_pose_rotation(b, (pb.inverse() * new_g).get_rotation_quaternion())


static func aim_at(s: Skeleton3D, suffix: String, child_suffix: String, point: Vector3) -> void:
	aim(s, suffix, child_suffix, point - world_pos(s, suffix))


## Scales the character to [param height] metres tall (feet to top of head).
static func set_height(n: Node3D, height: float) -> void:
	var s := skel(n)
	var top := world_pos(s, "HeadTop_End")
	var foot := world_pos(s, "LeftToeBase")
	var h := top.y - foot.y
	if h > 0.01:
		n.scale *= height / h


## Moves the character so its hips are at [param p].
static func place_hips(n: Node3D, p: Vector3) -> void:
	n.global_position += p - world_pos(skel(n), "Hips")


## Moves the character so its feet stand on the floor with hips over (x, z).
static func place_standing(n: Node3D, x: float, z: float) -> void:
	var s := skel(n)
	var h := world_pos(s, "Hips")
	var foot := minf(world_pos(s, "LeftToeBase").y, world_pos(s, "RightToeBase").y)
	n.global_position += Vector3(x - h.x, -foot + 0.01, z - h.z)


## dir in the character's own frame (it faces +z, its left is +x) -> world.
static func local_dir(n: Node3D, d: Vector3) -> Vector3:
	return Basis(Vector3.UP, n.rotation.y) * d


static func arms_down(n: Node3D) -> void:
	var s := skel(n)
	aim(s, "LeftArm", "LeftForeArm", local_dir(n, Vector3(.12, -1, .05)))
	aim(s, "RightArm", "RightForeArm", local_dir(n, Vector3(-.12, -1, .05)))
	aim(s, "LeftForeArm", "LeftHand", local_dir(n, Vector3(.05, -1, .3)))
	aim(s, "RightForeArm", "RightHand", local_dir(n, Vector3(-.05, -1, .3)))


static func sit_legs(n: Node3D) -> void:
	var s := skel(n)
	aim(s, "LeftUpLeg", "LeftLeg", local_dir(n, Vector3(.12, -.15, 1)))
	aim(s, "RightUpLeg", "RightLeg", local_dir(n, Vector3(-.12, -.15, 1)))
	aim(s, "LeftLeg", "LeftFoot", local_dir(n, Vector3(0, -1, .1)))
	aim(s, "RightLeg", "RightFoot", local_dir(n, Vector3(0, -1, .1)))


static func lean(n: Node3D, amount := 0.28) -> void:
	var s := skel(n)
	aim(s, "Spine", "Spine1", local_dir(n, Vector3(0, 1, amount)))
	aim(s, "Neck", "Head", local_dir(n, Vector3(0, 1, .12)))


static func walk_legs(n: Node3D) -> void:
	var s := skel(n)
	aim(s, "LeftUpLeg", "LeftLeg", local_dir(n, Vector3(0, -1, .35)))
	aim(s, "RightUpLeg", "RightLeg", local_dir(n, Vector3(0, -1, -.3)))
	aim(s, "LeftLeg", "LeftFoot", local_dir(n, Vector3(0, -1, .15)))
	aim(s, "RightLeg", "RightFoot", local_dir(n, Vector3(0, -1, -.5)))


## Rests both forearms on a counter whose near edge (to the guest) is at z = edge_z.
## A hand can be given its own target (e.g. next to a glass).
static func arms_on_bar(n: Node3D, bar_y: float, edge_z: float, cx: float, targets := {}) -> void:
	var s := skel(n)
	for side in ["Left", "Right"]:
		var sp := world_pos(s, side + "Arm")
		var dx := sp.x - cx
		var out := 1.0 if side == "Left" else -1.0
		aim_at(s, side + "Arm", side + "ForeArm", Vector3(sp.x + signf(dx if absf(dx) > 0.001 else out) * .04, bar_y + .05, edge_z - .03))
		var hand: Vector3 = targets.get(side, Vector3(cx + dx * .25, bar_y + .035, edge_z + .22))
		aim_at(s, side + "ForeArm", side + "Hand", hand)
		aim_at(s, side + "Hand", side + "HandMiddle1", hand + Vector3(-dx * .3, -.02, .12))


## One forearm forward holding a tray at chest height.
static func hold_tray(n: Node3D, side := "Left") -> void:
	var s := skel(n)
	var o := 1.0 if side == "Left" else -1.0
	aim(s, side + "Arm", side + "ForeArm", local_dir(n, Vector3(.25 * o, -.95, .1)))
	aim(s, side + "ForeArm", side + "Hand", local_dir(n, Vector3(.05 * o, .15, 1)))
	aim(s, side + "Hand", side + "HandMiddle1", local_dir(n, Vector3(0, 0, 1)))


static func hand_pos(n: Node3D, side: String) -> Vector3:
	return world_pos(skel(n), side + "Hand")


## Small breathing / looking movement on top of the pose. Call every frame with the time.
static func idle(n: Node3D, t: float, phase: float) -> void:
	var s := skel(n)
	var b := bone(s, "Spine2")
	if b < 0:
		return
	if not n.has_meta("spine_base"):
		n.set_meta("spine_base", s.get_bone_pose_rotation(b))
	var base: Quaternion = n.get_meta("spine_base")
	var wob := Quaternion(Vector3.RIGHT, sin(t * 1.3 + phase) * 0.025) * Quaternion(Vector3.UP, sin(t * 0.4 + phase * 2) * 0.06)
	s.set_bone_pose_rotation(b, base * wob)
