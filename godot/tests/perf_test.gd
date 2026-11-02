extends Node
## Measures frame time in the bar view during a shift.
## Run: godot --path . --rendering-method gl_compatibility --resolution 2000x1200 res://tests/perf_test.tscn

func _ready() -> void:
	Save.birth_year = 1995
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	main.start_shift()
	await get_tree().create_timer(1.0).timeout
	for v in ["bar", "station", "work"]:
		main._set_view(v, 0.0)
		for i in 5:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		var n := 0
		while Time.get_ticks_usec() - t0 < 4000000:
			await RenderingServer.frame_post_draw
			n += 1
		var info := "%s: %.1f ms/frame, draw calls %d, objects %d, primitives %d" % [v, (Time.get_ticks_usec() - t0) / 1000.0 / n,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]
		print(info)
		get_viewport().get_texture().get_image().save_png("/tmp/shots/perf_%s.png" % v)
	get_tree().quit()
