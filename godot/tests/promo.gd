extends "res://tests/app_test.gd"
## Plays a few drinks by itself so Movie Maker can record them as a Short or Reel.
## tools/make_shorts.py runs it, for example:
##   godot --path godot --rendering-method gl_compatibility --write-movie clip.avi --fixed-fps 30 \
##     --resolution 1280x720 res://tests/promo.tscn -- --drinks=mojito,margarita --theme=pink --skin=gold --stats=clip.json
## It writes what was made (names, stars, tips) to the stats file and quits.

var opts := {"drinks": "mojito,margarita", "theme": "warm", "skin": "steel", "bartender": "remy", "stats": ""}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var k := a.substr(2, a.find("=") - 2)
			if opts.has(k):
				opts[k] = a.substr(a.find("=") + 1)
	Save.birth_year = 1995
	Save.shifts = 3
	Save.unlocked = Recipes.DRINKS.size()
	Save.mocktail = false
	Save.sound = true
	Save.bartender = opts.bartender
	Save.light_theme = opts.theme
	Save.tool_skin = opts.skin
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	main.start_shift()
	Ads.hide_banner()
	await _secs(1.2)
	var made := []
	var coins0: int = Save.coins
	var ids: PackedStringArray = opts.drinks.split(",")
	for k in ids.size():
		var gi := (k + 1) % 4
		var g: Dictionary = main.guests[gi]
		if g.served:
			g.served.queue_free()
			g.served = null
		g.order = Recipes.drink(ids[k])
		g.patience = 100.0
		await _secs(0.6)
		await make(gi, false)
		var d := Recipes.drink(ids[k])
		made.append({"id": ids[k], "name": d.name, "method": d.get("method", ""), "home": d.get("home", [])})
		await _secs(1.4)
	var stats := {"drinks": made, "coins": Save.coins - coins0, "served": main.shift_stats.served,
		"stars": main.shift_stats.stars, "perfect": main.shift_stats.perfect, "fails": fails}
	if opts.stats != "":
		var f := FileAccess.open(opts.stats, FileAccess.WRITE)
		f.store_string(JSON.stringify(stats))
		f.close()
	print("PROMO DONE ", stats)
	get_tree().quit(1 if fails > 0 else 0)
