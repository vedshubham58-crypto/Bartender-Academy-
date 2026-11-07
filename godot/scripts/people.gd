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
	matte(n)
	return n


## Soft cloth and skin instead of the shiny default Mixamo materials.
static var _matte := {}


static func matte(n: Node3D, keep_normal := true) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		for si in m.mesh.get_surface_count():
			var mat = m.get_active_material(si)
			if mat is StandardMaterial3D:
				var key := [mat, keep_normal]
				if not _matte.has(key):
					var c: StandardMaterial3D = mat.duplicate()
					c.roughness = 0.82
					c.roughness_texture = null
					c.metallic = 0.0
					c.metallic_texture = null
					c.metallic_specular = 0.12
					c.normal_enabled = keep_normal and c.normal_enabled
					_matte[key] = c
				m.set_surface_override_material(si, _matte[key])


## Brightens a character's own colours so it reads clearly on any screen, whatever
## the bar lights do (used for the bartender shown on the menus).
static func self_lit(n: Node3D, amount := 1.6) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		for si in m.mesh.get_surface_count():
			var mat = m.get_active_material(si)
			if mat is StandardMaterial3D:
				var c: StandardMaterial3D = mat.duplicate()
				c.albedo_color = Color(amount, amount * 0.97, amount * 0.94)
				m.set_surface_override_material(si, c)


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


## Two-bone reach: puts the hand of [param side] at [param target], with the elbow bending
## towards [param pole] (a world direction). Returns how far the target was out of reach.
static func reach(s: Skeleton3D, side: String, target: Vector3, pole: Vector3) -> float:
	var sp := world_pos(s, side + "Arm")
	var a := sp.distance_to(world_pos(s, side + "ForeArm"))
	var b := world_pos(s, side + "ForeArm").distance_to(world_pos(s, side + "Hand"))
	var to := target - sp
	var dist := to.length()
	var d := clampf(dist, absf(a - b) + 0.01, a + b - 0.002)
	var dir := to.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.001:
		perp = Vector3.DOWN
	var elbow := sp + dir * (a * cos_a) + perp.normalized() * (a * sin_a)
	aim_at(s, side + "Arm", side + "ForeArm", elbow)
	aim_at(s, side + "ForeArm", side + "Hand", sp + dir * d)
	return maxf(0.0, dist - d)


## Points the hand along [param dir] and turns it so the thumb side faces [param thumb].
static func orient_hand(s: Skeleton3D, side: String, dir: Vector3, thumb: Vector3) -> void:
	aim(s, side + "Hand", side + "HandMiddle1", dir)
	var hb := bone(s, side + "Hand")
	var hp := world_pos(s, side + "Hand")
	var axis := (world_pos(s, side + "HandMiddle1") - hp).normalized()
	var cur := world_pos(s, side + "HandIndex1") - world_pos(s, side + "HandPinky1")
	cur -= axis * cur.dot(axis)
	var want := thumb - axis * thumb.dot(axis)
	if cur.length() < 0.0001 or want.length() < 0.0001:
		return
	var ang := cur.normalized().signed_angle_to(want.normalized(), axis)
	var sg := s.global_transform.basis
	var g := gpose(s, hb)
	var new_g := sg.inverse() * (Basis(axis, ang) * (sg * g.basis))
	var p := s.get_bone_parent(hb)
	var pb := gpose(s, p).basis if p >= 0 else Basis()
	s.set_bone_pose_rotation(hb, (pb.inverse() * new_g).get_rotation_quaternion())


## Curls the fingers: 0 = open hand, 1 = tight fist.
static func grip(s: Skeleton3D, side: String, amount: float, axis := Vector3.RIGHT) -> void:
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		for j in [1, 2, 3]:
			var b := bone(s, side + "Hand" + f + str(j))
			if b < 0:
				continue
			var rest := s.get_bone_rest(b).basis.get_rotation_quaternion()
			s.set_bone_pose_rotation(b, rest * Quaternion(axis, amount * [0.0, 1.1, 1.3, 0.9][j]))
	for j in [1, 2, 3]:
		var b := bone(s, side + "HandThumb" + str(j))
		if b < 0:
			continue
		var rest := s.get_bone_rest(b).basis.get_rotation_quaternion()
		s.set_bone_pose_rotation(b, rest * Quaternion(axis, amount * 0.45))


## Shrinks the head away, for the player's own first-person body.
static func hide_head(s: Skeleton3D) -> void:
	var b := bone(s, "Neck")
	if b >= 0:
		s.set_bone_pose_scale(b, Vector3.ONE * 0.001)


## Turns the head toward [param point] (world). [param amount] 0..1 blends from looking
## straight ahead. Call every frame after the body pose; it starts from the head's own pose.
static func look_at_point(n: Node3D, point: Vector3, amount := 1.0) -> void:
	var s := skel(n)
	var hb := bone(s, "Head")
	if hb < 0:
		return
	if not n.has_meta("head_base"):
		n.set_meta("head_base", s.get_bone_pose_rotation(hb))
	s.set_bone_pose_rotation(hb, n.get_meta("head_base"))
	if amount <= 0.001:
		return
	var head := world_pos(s, "Head")
	var fwd := local_dir(n, Vector3(0, 0, 1))
	var to := (point - head).normalized()
	# keep it natural: no more than ~70 degrees sideways, ~35 up or down
	var flat := Vector3(to.x, 0, to.z).normalized()
	var yaw := clampf(fwd.signed_angle_to(flat, Vector3.UP), -1.2, 1.2) * amount
	var pitch := clampf(asin(clampf(to.y, -1.0, 1.0)), -0.6, 0.45) * amount
	var sg := s.global_transform.basis
	var g := gpose(s, hb)
	var right := fwd.cross(Vector3.UP).normalized()
	var turn := Basis(Vector3.UP, yaw) * Basis(right, -pitch)
	var new_g := sg.inverse() * (turn * (sg * g.basis))
	var p := s.get_bone_parent(hb)
	var pb := gpose(s, p).basis if p >= 0 else Basis()
	s.set_bone_pose_rotation(hb, (pb.inverse() * new_g.orthonormalized()).get_rotation_quaternion())
