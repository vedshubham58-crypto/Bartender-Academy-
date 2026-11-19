extends SceneTree
## Close-ups of a seated guest holding, raising and sipping a served drink, to check
## the hand grips the glass from the outside.
## godot --path . --rendering-method gl_compatibility --resolution 1280x720 -s tests/guest_glass_shot.gd -- /tmp/out highball sip
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/gg"
	var kind: String = args[1] if args.size() > 1 else "highball"
	var react: String = args[2] if args.size() > 2 else "sip"
	await process_frame
	var save = root.get_node("/root/Save")
	save.birth_year = 1995
	save.trained = "--training" not in OS.get_cmdline_user_args()
	save.venue = "rooftop"
	save.light_theme = "warm"
	save.gift_day = save.day_key()
	var main = load("res://scenes/main.tscn").instantiate()
	main.guests_leave = false
	root.add_child(main)
	for i in 20:
		await process_frame
	main._close_overlay()
	main.start_shift()
	for i in 10:
		await process_frame
	var g: Dictionary = main.guests[int(args[3]) if args.size() > 3 else 2]
	g.order = {}
	var gl: Node3D = main.bar.make_glass(kind)
	main.bar.add_child(gl)
	gl.position = Vector3(g.x - .16, 1.12 + .008, -1.42 + .2)
	main.bar.set_fill(gl, 0.7, Color(0.9, 0.5, 0.2))
	g.served = gl
	g.drink_t = 99.0
	g.fill = 0.7
	g.color = Color(0.9, 0.5, 0.2)
	g.react = react
	g.react_t = 0.0
	g.sip_next = 0.3
	g.fx = ""
	g.fx_done = true
	var views := {
		"side": [Vector3(g.x + 0.5, 1.32, -0.75), Vector3(g.x - 0.1, 1.22, -1.4)],
		"top": [Vector3(g.x - 0.18, 1.55, -1.18), Vector3(g.x - 0.17, 1.12, -1.25)],
		"front": [Vector3(g.x - 0.1, 1.36, -0.55), Vector3(g.x - 0.1, 1.2, -1.45)],
		"face": [Vector3(g.x - 0.05, 1.5, -0.5), Vector3(g.x - 0.08, 1.38, -1.45)],
		"face_side": [Vector3(g.x + 0.55, 1.5, -0.8), Vector3(g.x - 0.08, 1.4, -1.45)],
	}
	main.ui.visible = false
	var c := Camera3D.new()
	root.add_child(c)
	c.fov = 30
	for k in 22:
		for i in 6:
			if "--peak" in args:
				g.sip_next = -0.9 # hold the sip at its top
			await process_frame
		if "--peak" in args:
			var hd: Vector3 = main._head_pos(g)
			print("peak glass ", gl.global_position, " rot ", gl.rotation.x, " head ", hd, " hand ", People.world_pos(People.skel(g.node), "RightHand"))
		for v in views:
			var from: Vector3 = views[v][0]
			c.global_transform = Transform3D(Basis.looking_at(views[v][1] - from), from)
			c.make_current()
			if "--peak" in args:
				g.sip_next = -0.9
			await process_frame
			var img := root.get_texture().get_image()
			img.save_jpg("%s/%s_%02d.jpg" % [out, v, k], 0.8)
		# and what the player sees from behind the bar
		main.cam.make_current()
		await process_frame
		root.get_texture().get_image().save_jpg("%s/game_%02d.jpg" % [out, k], 0.85)
	quit()
