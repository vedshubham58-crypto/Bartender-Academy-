extends Node
## Plays whole drinks automatically through the real game code and saves screenshots.
## Run: godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/app_test.tscn -- /tmp/shots/a

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
	Save.unlocked = Recipes.DRINKS.size() if "--drinks=" in " ".join(args) else 8
	Save.mocktail = "--mocktail" in args
	main = load("res://scenes/main.tscn").instantiate()
	main.guests_leave = false # the test serves the same four seats
	add_child(main)
	await _frames(20)
	await shot("menu")
	if "--picker" in args:
		main.show_bartender_pick()
		await _secs(1.5)
		await shot("picker")
		main._pick_bartender("louise" if "--mia" in args else "remy")
		await _frames(10)
	main.start_shift()
	await _secs(1.0)
	await shot("shift")
	var order := ["gin_tonic", "mojito", "margarita", "old_fashioned", "espresso_martini", "whisky_sour", "cosmopolitan", "daiquiri"]
	var first := 0
	var count := 99
	for a in args:
		if a.begins_with("--from="):
			first = int(a.substr(7))
		if a.begins_with("--count="):
			count = int(a.substr(8))
		if a.begins_with("--drinks="):
			order = Array(a.substr(9).split(","))
	var all_shots := "--shots" in args
	for k in range(first, mini(order.size(), first + count)):
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
		await make(gi, k < 2 or all_shots)
	main.shift_left = 0.0
	await _secs(1.0)
	await shot("summary")
	main._score_card("", false)
	await _secs(1.5)
	await shot("scorecard")
	Save.coins = maxi(Save.coins, 1000)
	main.show_shop()
	await _frames(10)
	await shot("shop")
	main._shop_buy("tools_gold", 900)
	main._shop_buy("lights_pink", 500)
	main.show_menu()
	await _secs(1.2)
	await shot("menu2")
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
		await _between_steps()
		match s.t:
			"glass", "rim", "ice", "garnish":
				if shots and s.t == "glass":
					await _secs(0.5)
					await shot(id + "_glass")
				await main._choose(s.t, s.v)
			"pour", "top", "dash", "layer":
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
					main._pour_t0 = Time.get_ticks_msec()
					main.pouring = true
					main.stream.visible = true
					while main.pour_ml < main.pour_target - 0.5:
						await get_tree().process_frame
					# slow test frames run the real-time pour past the line, so stop where a good player would
					main.pour_ml = main.pour_target + randf_range(-1.5, 1.5)
					main._pour_t0 = Time.get_ticks_msec() - int(main.pour_ml / (main.TOP_RATE if s.t == "top" else main.POUR_RATE) * 1000.0)
					if shots:
						await shot("%s_%d_pour" % [id, i])
					if s.t == "layer":
						main._pour_release()
						await _frames(2)
						# pulse the pour so the flow stays gentle
						var g2 := 0
						var shot_done := false
						while not main._float.is_empty() and g2 < 900:
							g2 += 1
							main._float.holding = main._float.flow < 0.5
							if shots and not shot_done and main._float.left < main._float.ml * 0.5:
								shot_done = true
								await shot("%s_%d_layer" % [id, i])
							await get_tree().process_frame
						await _secs(0.5)
					else:
						await main._pour_release()
					await _frames(2)
			"muddle":
				for n in 6:
					main._muddle()
					if shots and n == 2:
						await _secs(0.6)
						await shot(id + "_muddle")
			"shake":
				await _secs(0.5)
				for n in 17:
					main._shake_step(6.0)
					await _frames(2)
					if shots and n == 8:
						await shot(id + "_shake")
				await _frames(2)
				if main.expecting == "flip":
					await _secs(0.3)
					main._do_flip()
					await _secs(0.35)
					if shots:
						await shot(id + "_flip")
					await _secs(0.35)
					main._catch()
					var g4 := 0
					while main.expecting == "flip" and g4 < 200:
						g4 += 1
						await get_tree().process_frame
					await _frames(2)
			"stir":
				var ev := InputEventScreenDrag.new()
				ev.relative = Vector2(80, 60)
				ev.position = Vector2(640, 400)
				await _secs(0.6)
				for n in 40:
					if main.expecting != "stir":
						break
					main._unhandled_input(ev)
					if shots and n == 15:
						await _frames(3)
						await shot(id + "_stir")
			"strain":
				main._strain()
				await _secs(1.8)
			"blend":
				await _secs(0.4)
				main._blend_hold(true)
				while main._blend.get("p", 999.0) < 82.0:
					await get_tree().process_frame
				if shots:
					await shot(id + "_blend")
				main._blend_hold(false)
				await _secs(1.6)
			"flame":
				await _secs(0.3)
				var g3 := 0
				while main._flame_level() < 0.9 and g3 < 300:
					g3 += 1
					await get_tree().process_frame
				if shots:
					await shot(id + "_flame")
				main._squeeze()
				await _frames(4)
				await _secs(0.9)
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


## A breath between steps (the promo recorder slows down here so each step can be seen).
func _between_steps() -> void:
	pass


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _secs(t: float) -> void:
	await get_tree().create_timer(t).timeout
