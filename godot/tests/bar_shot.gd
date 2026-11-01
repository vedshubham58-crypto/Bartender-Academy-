extends SceneTree
## Renders the bar from a few camera spots. Args: <out prefix>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var bar: Node3D = load("res://scripts/bar.gd").new()
	root.add_child(bar)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var views := {
		"bar": [Vector3(0, 1.62, .25), Vector3(0, 1.05, -1.5), 62.0],
		"station": [Vector3(.04, 1.6, .16), Vector3(0, .78, -.85), 60.0],
		"back": [Vector3(.1, 1.6, -.25), Vector3(0, 1.32, 1.0), 58.0],
	}
	for k in views:
		cam.fov = views[k][2]
		cam.look_at_from_position(views[k][0], views[k][1])
		for i in 8:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, k])
		print("saved ", k)
	quit()
