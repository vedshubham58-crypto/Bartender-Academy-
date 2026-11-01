extends Node
## Plays whole drinks automatically through the real game code and saves screenshots.
## Run: godot --path . --rendering-method gl_compatibility --resolution 1600x900 res://tests/app_test.tscn -- /tmp/shots/a

var main: Node
var out := "/tmp/shots/a"
var fails := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Save.birth_year = 1995
	Save.shifts = 0
	Save.made = {}
	Save.best = {}
	Save.unlocked = 8
	Save.mocktail = "--mocktail" in args
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(20)
	await shot("menu")
	main.start_shift()
	await _secs(1.0)
	await shot("shift")
	var order := ["gin_tonic", "mojito", "margarita", "old_fashioned", "espresso_martini", "whisky_sour", "cosmopolitan", "daiquiri"]
	var first := 0
	for a in args:
		if a.begins_with("--from="):
			first = int(a.substr(7))
	for k in range(first, order.size()):
		var gi := k % 4
		var g: Dictionary = main.guests[gi]
		if not g.order.is_empty() or g.served == null:
			pass
		if g.served:
			g.served.queue_free()
			g.served = null
		g.order = Recipes.drink(order[k])
		g.patience = 100.0
		await _frames(2)
		await make(gi, k < 2)
	main.shift_left = 0.0
	await _secs(1.0)
	await shot("summary")
	print("APP TEST DONE, fails=%d coins=%d" % [fails, Save.coins])
	get_tree().quit(1 if fails > 0 else 0)


func make(gi: int, shots: bool) -> void:
	var id: String = main.guests[gi].order.id
	main._pick_guest(gi)
	await _frames(3)
	var guard := 0
	while not main.cur.is_empty() and main.cur.i < main.cur.drink.steps.size() and guard < 40:
		guard += 1
		var s: Dictionary = main.cur.step
		var i: int = main.cur.i
		match s.t:
			"glass", "rim", "ice", "garnish":
				if shots and s.t == "glass":
					await _secs(0.5)
					await shot(id + "_glass")
				main._choose(s.t, s.v)
			"pour", "top", "dash":
				await _secs(0.5)
				var src: String = main.expect_src
				var wp: Vector3 = main.bar.pickables[src]
				var p: Vector2 = main.cam.unproject_position(wp)
				if shots:
					await shot("%s_%d_pick" % [id, i])
				main._tap_pick(p)
				if main.expecting == "pick":
					printerr("FAIL: tap on %s at %s did not pick it (%s)" % [src, p, id])
					fails += 1
					main.expecting = ""
					main.pour_src = src
					if s.t == "dash":
						main._taps = 0
					else:
						main._start_pour_view()
				if s.t == "dash":
					for n in s.n:
						main._dash()
				else:
					main.pouring = true
					main.stream.visible = true
					while main.pour_ml < main.pour_target - 0.5:
						await get_tree().process_frame
					if shots:
						await shot("%s_%d_pour" % [id, i])
					main._pour_release()
					await _secs(0.9)
			"muddle":
				for n in 6:
					main._muddle()
			"shake":
				await _secs(0.5)
				for n in 17:
					main._shake_step(6.0)
					await _frames(2)
					if shots and n == 8:
						await shot(id + "_shake")
			"stir":
				var ev := InputEventMouseMotion.new()
				ev.relative = Vector2(80, 60)
				ev.button_mask = MOUSE_BUTTON_MASK_LEFT
				for n in 40:
					if main.expecting != "stir":
						break
					main._unhandled_input(ev)
			"strain":
				main._strain()
				await _secs(1.8)
		await _frames(2)
		if main.cur.is_empty() or main.cur.i == i:
			if not main.cur.is_empty():
				printerr("FAIL: stuck at step %d (%s) of %s" % [i, s.t, id])
				fails += 1
				return
	await _secs(0.5)
	if shots:
		await shot(id + "_ready")
	main._serve()
	await _secs(0.9)
	if shots:
		await shot(id + "_served")
	print("served %s, coins %d" % [id, Save.coins])


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _secs(t: float) -> void:
	await get_tree().create_timer(t).timeout
