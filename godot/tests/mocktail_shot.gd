extends SceneTree
## Station view in mocktail mode, after switching modes like a player does from the menu.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/mock"
	await process_frame
	var save = root.get_node("/root/Save")
	save.birth_year = 1995
	save.mocktail = false
	save.gift_day = save.day_key()
	save.light_theme = "warm"
	save.tool_skin = "steel"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	main._close_overlay()
	save.mocktail = true
	main.bar.build_rail()
	main._set_view("station", 0.0)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "_station.png")
	var keys := []
	for k in main.bar.pickables:
		keys.append(k)
	print("PICKABLES ", keys)
	quit()
