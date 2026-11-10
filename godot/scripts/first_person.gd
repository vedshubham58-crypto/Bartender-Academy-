class_name FirstPerson
extends RefCounted
## The player's own bartender body: a real 3D character standing under the camera with its
## head hidden, so you see your arms and hands reach, pour, shake and stir.

var node: Node3D
var s: Skeleton3D
var model := ""
## Where each hand should be (world space). Vector3.INF = rest out of view.
var target := {"Right": Vector3.INF, "Left": Vector3.INF}
## How closed each hand is (0 open, 1 fist).
var grip := {"Right": 0.2, "Left": 0.2}
## Optional world direction the fingers point and where the thumb faces.
var hand_dir := {"Right": Vector3.ZERO, "Left": Vector3.ZERO}
var thumb_dir := {"Right": Vector3.UP, "Left": Vector3.UP}
var _cur := {"Right": Vector3.ZERO, "Left": Vector3.ZERO}
var _grip := {"Right": 0.2, "Left": 0.2}
var _started := false
## How far the neck sits under your eyes. Close to a real body's, so the arms reach down into
## the station instead of lying flat across the screen.
const NECK_DROP := 0.19
## The body leans toward the hand that is working so the arm stays nearly straight and
## points away from the camera: you see a hand and a short wrist, not a long forearm.
const REACH := 0.9 ## fraction of the arm's length the shoulder keeps from the hand
const MAX_LEAN := 0.18
const DIP := 1.9
var _lean := Vector3.ZERO


func _init(model_name: String, parent: Node3D) -> void:
	model = model_name
	node = People.spawn(model_name, parent)
	People.set_height(node, 1.74)
	s = People.skel(node)
	People.hide_head(s)
	# slightly longer arms so the hands reach across the station (hands kept normal size)
	for side in ["Left", "Right"]:
		var ab := People.bone(s, side + "Arm")
		var hb := People.bone(s, side + "Hand")
		s.set_bone_pose_scale(ab, Vector3.ONE * 1.1)
		s.set_bone_pose_scale(hb, Vector3.ONE / 1.1)
	People.arms_down(node)
	People.matte(node, false)
	# the bar lamps sit right above your own arms, so tone them down a little
	People.self_lit(node, 0.72)
	for m in node.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func free_body() -> void:
	if node:
		node.queue_free()
		node = null


func _rest(side: String, cam: Camera3D, fwd: Vector3, right: Vector3) -> Vector3:
	var o := 1.0 if side == "Right" else -1.0
	return cam.global_position + fwd * 0.22 + right * (0.26 * o) + Vector3.DOWN * 0.72


func update(cam: Camera3D, dt: float) -> void:
	if node == null:
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	node.rotation = Vector3(0, atan2(fwd.x, fwd.z), 0)
	# neck just under the camera, a little in front, so the shoulders can reach the station
	var want := cam.global_position + fwd * 0.06 + Vector3.DOWN * NECK_DROP
	node.global_position += want - People.world_pos(s, "Neck")
	# eased, so a hand glides to the next tool instead of jumping
	var k := 1.0 - exp(-minf(dt, 0.05) * 12.0)
	var lean := Vector3.ZERO
	var low := 0.0 ## how far below the shoulders the work is (0..1): only then do you bend over
	var n := 0
	for side in ["Right", "Left"]:
		var t: Vector3 = target[side]
		if t == Vector3.INF:
			continue
		var sp := People.world_pos(s, side + "Arm")
		var fa := People.world_pos(s, side + "ForeArm")
		var arm := sp.distance_to(fa) + fa.distance_to(People.world_pos(s, side + "Hand"))
		var to := t - sp
		var need := to.length() - arm * REACH
		to.y = 0.0
		if need > 0.0 and to.length() > 0.001:
			lean += to.normalized() * need
		low = maxf(low, clampf((sp.y - t.y - 0.12) / 0.2, 0.0, 1.0))
		n += 1
	if n > 0:
		lean /= n
	lean = lean.limit_length(MAX_LEAN)
	var lv := Vector3(lean.x, -lean.length() * DIP * (0.7 + 0.3 * low), lean.z)
	_lean = lv if not _started else _lean.lerp(lv, k * 0.6)
	# dip as you lean in, like bending over the station, so your shoulders stay out of view
	node.global_position += _lean
	for side in ["Right", "Left"]:
		var t: Vector3 = target[side]
		if t == Vector3.INF:
			t = _rest(side, cam, fwd, right)
		_cur[side] = t if not _started else _cur[side].lerp(t, k)
		_grip[side] = lerpf(_grip[side], grip[side], k)
		var o := 1.0 if side == "Right" else -1.0
		# elbow kept low and tucked, so the forearm points into the scene, not across it
		var pole := right * (0.3 * o) + Vector3.DOWN - fwd * 0.4
		People.reach(s, side, _cur[side], pole)
		var hd: Vector3 = hand_dir[side]
		if hd == Vector3.ZERO:
			hd = (fwd + Vector3.DOWN * 0.25 - right * (0.35 * o)).normalized()
		People.orient_hand(s, side, hd, thumb_dir[side])
		People.grip(s, side, _grip[side])
	_started = true


## A hand's world position (for things held in it).
func hand(side: String) -> Vector3:
	return People.world_pos(s, side + "Hand")
