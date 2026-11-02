extends Node
## Saves views of the terrace and skyline (for checking the scenery).
## Run: godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/sky_shot.tscn -- /tmp/shots/sky

func _ready() -> void:
	Save.birth_year = 1995
	var out := "/tmp/shots/sky"
	for a in OS.get_cmdline_user_args():
		out = a
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	main.start_shift()
	await get_tree().create_timer(0.5).timeout
	var shots := {
		"lounge": [Vector3(4.5, 1.6, -5.0), Vector3(-6, 1.0, -40), 62.0], # a guest's view over the railing
		"left": [Vector3(0, 1.7, -6), Vector3(-30, 6, -40), 62.0],
	}
	for k in shots:
		var d: Array = shots[k]
		main.cam_base = Transform3D(Basis.looking_at(d[1] - d[0]), d[0])
		main.look_yaw = 0.0
		main.look_pitch = 0.0
		main.cam.global_transform = main.cam_base
		main.cam.fov = d[2]
		main.hud.visible = false
		for i in 6:
			await RenderingServer.frame_post_draw
		main.cam.global_transform = main.cam_base
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, k])
	get_tree().quit()
