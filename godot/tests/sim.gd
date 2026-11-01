extends SceneTree
## Checks every recipe can be made with what is on the bar, in both normal and mocktail mode.
## Run: godot --headless --path godot -s tests/sim.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var R: Node = root.get_node_or_null("Recipes")
	var S: Node = root.get_node_or_null("Save")
	check(R != null and S != null, "autoloads Recipes and Save are loaded")
	if R == null or S == null:
		quit(1)
		return
	var types := ["glass", "rim", "muddle", "pour", "dash", "top", "ice", "shake", "stir", "strain", "garnish"]
	for mock in [false, true]:
		S.mocktail = mock
		var rail: Array = R.rail()
		var ids := {}
		for d in R.DRINKS:
			check(not ids.has(d.id), "drink id %s is unique" % d.id)
			ids[d.id] = true
			check(d.has("name") and d.has("mocktail") and d.has("price") and d.has("home"), "%s has name, mocktail, price, home steps" % d.id)
			check(R.drink(d.id) == d, "drink(%s) finds it" % d.id)
			var seen_glass := false
			var tin: bool = R.uses_tin(d)
			for s in d.steps:
				check(s.t in types, "%s step type %s is known" % [d.id, s.t])
				var txt: String = R.step_text(s, true)
				check(txt != "", "%s step %s has text" % [d.id, s.t])
				match s.t:
					"glass":
						seen_glass = true
						check(R.GLASSES.has(s.v), "%s glass %s exists" % [d.id, s.v])
					"rim":
						check(R.RIMS.has(s.v), "%s rim %s exists" % [d.id, s.v])
					"ice":
						check(R.ICE.has(s.v), "%s ice %s exists" % [d.id, s.v])
					"garnish":
						check(R.GARNISH.has(s.v), "%s garnish %s exists" % [d.id, s.v])
					"pour", "top", "dash":
						var src: String = R.src(s.src)
						check(R.SOURCES.has(src), "%s source %s exists (mocktail=%s)" % [d.id, src, mock])
						if R.SOURCES.has(src) and R.SOURCES[src].kind == "rail":
							check(src in rail, "%s: %s is on the speed rail (mocktail=%s)" % [d.id, src, mock])
						if s.t == "pour":
							check(s.ml > 0 and s.ml <= 90, "%s pour of %s is a sensible amount" % [d.id, s.src])
						if s.t == "dash":
							check(s.n >= 1, "%s has a dash count" % d.id)
					"shake", "strain":
						check(tin, "%s %s needs a tin" % [d.id, s.t])
			check(seen_glass and d.steps[0].t == "glass", "%s starts by picking a glass" % d.id)
			if mock:
				for s in d.steps:
					if s.has("src"):
						var src2: String = R.src(s.src)
						check(not R.MOCKTAIL_SWAP.has(src2), "%s mocktail has no alcohol (%s)" % [d.id, src2])
	S.mocktail = false
	for id in R.rail():
		check(R.MOCKTAIL_SWAP.has(id), "spirit %s has an alcohol-free swap" % id)
	# scoring
	check(R.stars_for(0, [0.0, 1.0]) == 3.0, "clean drink = 3 stars")
	check(R.stars_for(1, []) == 2.0, "one mistake = 2 stars")
	check(R.stars_for(0, [20.0]) == 2.0, "big over-pour costs a star")
	check(R.stars_for(0, [8.0]) == 2.5, "small miss costs half a star")
	check(R.stars_for(9, [30.0]) == 1.0, "never below 1 star")
	check(R.is_perfect(2.0) and not R.is_perfect(4.0), "perfect pour window")
	print("recipe tests: %d drinks, %d failures" % [R.DRINKS.size(), failures])
	quit(1 if failures > 0 else 0)
