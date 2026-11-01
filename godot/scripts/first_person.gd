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
	var want := cam.global_position + fwd * 0.1 + Vector3.DOWN * 0.3
	node.global_position += want - People.world_pos(s, "Neck")
	var k := 1.0 - exp(-dt * 12.0)
	for side in ["Right", "Left"]:
		var t: Vector3 = target[side]
		if t == Vector3.INF:
			t = _rest(side, cam, fwd, right)
		_cur[side] = t if not _started else _cur[side].lerp(t, k)
		_grip[side] = lerpf(_grip[side], grip[side], k)
		var o := 1.0 if side == "Right" else -1.0
		var pole := right * (0.8 * o) + Vector3.DOWN - fwd * 0.3
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
