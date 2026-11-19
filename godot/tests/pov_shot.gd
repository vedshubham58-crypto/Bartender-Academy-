extends SceneTree
## First-person views during a shift: is any of your own neck or collar in the picture?
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/pov"
	await process_frame
	var save = root.get_node("/root/Save")
	save.birth_year = 1995
	save.trained = "--training" not in OS.get_cmdline_user_args()
	save.gift_day = save.day_key()
	save.light_theme = "warm"
	save.tool_skin = "steel"
	var who: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "remy"
	save.bartender = who
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	main._close_overlay()
	main.set_bartender(who)
	main.shift_stats = {"served": 0, "stars": 0.0, "coins": 0, "perfect": 0, "score": 0, "speedy": 0, "memory": 0, "flawless": 0, "streak": 0, "best_streak": 0}
	main.shift_left = 9999.0
	main.in_shift = true
	for v in ["station", "work", "pour", "bar", "reach"]:
		if v == "reach":
			main._set_view("station", 0.0)
			main.me.target["Right"] = Vector3(0.15, 0.95, -0.55)
			main.me.target["Left"] = Vector3(-0.25, 0.95, -0.5)
		else:
			main._set_view(v, 0.0)
		for i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%s_%s.png" % [out, who, v])
	quit()
