extends SceneTree
## Screenshots of one venue from the menu, the bartender's view and a wide shot.
## godot --path . --rendering-method gl_compatibility --resolution 1280x720 -s tests/venue_shot.gd -- beach /tmp/out
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var v: String = args[0] if args.size() > 0 else "rooftop"
	var out: String = args[1] if args.size() > 1 else "/tmp/venue"
	await process_frame
	var save = root.get_node("/root/Save")
	save.birth_year = 1995
	save.venue = v
	save.gift_day = save.day_key() # no tips jar over the picture
	var ui: bool = args.size() > 2 and args[2] == "ui"
	if ui:
		save.shifts = 9 # beach and hotel open, speakeasy still locked
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	main._close_overlay()
	for view in ["menu", "bar", "wide"]:
		if view == "wide":
			main.cam.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, 1.25, -0.4) - Vector3(0.6, 1.6, -4.2)), Vector3(0.6, 1.6, -4.2))
			main.cam.fov = 55
			main.set_process(false)
		else:
			main._set_view(view, 0.0)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%s_%s.png" % [out, v, view])
	if ui:
		main.set_process(true)
		main.show_menu()
		for i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%s_menuui.png" % [out, v])
		main.show_bars()
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%s_picker.png" % [out, v])
	quit()
