extends "res://tests/app_test.gd"
## Plays drinks by itself so Movie Maker can record them as a Short or Reel.
## tools/make_shorts.py runs it, for example:
##   godot --path godot --rendering-method gl_compatibility --write-movie clip.avi --fixed-fps 30 \
##     --resolution 1280x720 res://tests/promo.tscn -- --format=guest --drinks=mojito,margarita --stats=clip.json
## Formats, so the feed isn't the same video every time:
##   pov        the classic: your own view behind the bar, with the game screen
##   guest      a guest at the bar orders, you make it, it slides to them ("One Mojito, please!")
##   cinematic  no game screen, film-style angles: wide rooftop, side of the bar, close-ups of the pour
##   learn      one drink, each step written out as it happens, the home recipe at the end
## It writes what was made and a timeline of lines to show (who says what, which step) to the
## stats file, and quits.

var opts := {"drinks": "mojito,margarita", "theme": "warm", "skin": "steel", "bartender": "remy",
	"stats": "", "format": "pov"}
var pcam: Camera3D
var events: Array = [] ## {"at": seconds into the video, "end": seconds, "kind": "say"/"step", "text": ...}
var _frame0 := 0
var _last_step := -2
var _shot := ""
var _shot_t := 0.0
var _shot_len := 3.0
var _alt := 0
var _serving_to := -1

## Camera spots around the bar: [from, to, look at, fov]. The camera drifts from "from" to "to"
## over the shot, so nothing is ever a dead still.
const SHOTS := {
	"wide": [Vector3(0.9, 1.65, -4.6), Vector3(0.35, 1.45, -2.9), Vector3(0.0, 1.25, -0.4), 50.0],
	"side": [Vector3(2.05, 1.5, -1.2), Vector3(1.75, 1.42, -1.1), Vector3(0.0, 1.2, -0.85), 42.0],
	"side_l": [Vector3(-2.0, 1.48, -1.15), Vector3(-1.7, 1.4, -1.05), Vector3(0.1, 1.22, -0.85), 42.0],
	"top": [Vector3(-0.05, 1.8, -1.3), Vector3(-0.05, 1.68, -1.22), Vector3(0.0, 1.12, -0.89), 40.0],
	"low": [Vector3(-0.8, 1.27, -1.22), Vector3(-0.7, 1.26, -1.15), Vector3(0.0, 1.18, -0.88), 36.0],
	"guest1": [Vector3(-0.15, 1.58, -2.15), Vector3(-0.12, 1.54, -2.0), Vector3(0.05, 1.35, 0.0), 48.0],
	"guest2": [Vector3(0.75, 1.58, -2.15), Vector3(0.72, 1.54, -2.0), Vector3(-0.05, 1.35, 0.0), 48.0],
	"slide1": [Vector3(-1.95, 1.3, -1.0), Vector3(-1.8, 1.28, -1.02), Vector3(-0.45, 1.15, -1.15), 38.0],
	"slide2": [Vector3(1.95, 1.3, -1.0), Vector3(1.8, 1.28, -1.02), Vector3(0.45, 1.15, -1.15), 38.0],
}
const ORDER_LINES := ["Can I get %s, please?", "I'll have %s.", "I'd love %s!", "Could you make me %s?"]
const THANKS := ["Perfect, thank you!", "Wow, that looks amazing!", "Now that's a %s!", "Cheers!"]


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
	main.guests_leave = false # the clip serves the same seats
	add_child(main)
	pcam = Camera3D.new()
	add_child(pcam)
	await _frames(10)
	_frame0 = 0 # the movie starts on the very first frame
	main.start_shift()
	Ads.hide_banner()
	var f: String = opts.format
	var film := f != "pov"
	var ids: PackedStringArray = opts.drinks.split(",")
	if f == "learn":
		ids = ids.slice(0, 1)
	var made := []
	var coins0: int = Save.coins
	if f == "cinematic":
		_cut("wide", 3.2)
	await _secs(1.2 if not film else 0.4)
	for k in ids.size():
		var gi := 1 if k % 2 == 0 else 2
		var g: Dictionary = main.guests[gi]
		if g.served:
			g.served.queue_free()
			g.served = null
		var d := Recipes.drink(ids[k])
		g.order = d
		g.patience = 100.0
		if f == "guest":
			_cut("guest%d" % gi, 2.6)
			_say(ORDER_LINES[(k + ids.size()) % ORDER_LINES.size()] % _a(d.name), 2.6)
			await _secs(2.6)
		elif f == "cinematic" and k > 0:
			_cut("guest%d" % gi, 1.6)
			await _secs(1.6)
		else:
			await _secs(0.6)
		_last_step = -2
		_serving_to = -1
		await make(gi, false)
		if f == "guest":
			_say(THANKS[k % THANKS.size()].replace("%s", d.name), 2.0, 0.6)
		elif f == "learn":
			_say("Make it at home: full recipe in the caption", 2.6, 0.2)
		made.append({"id": ids[k], "name": d.name, "method": d.get("method", ""), "home": d.get("home", [])})
		# the last line needs to be read before the end card comes up
		await _secs((5.4 if k == ids.size() - 1 else 2.4) if film else 1.4)
	var stats := {"drinks": made, "coins": Save.coins - coins0, "served": main.shift_stats.served,
		"stars": main.shift_stats.stars, "perfect": main.shift_stats.perfect, "fails": fails,
		"format": f, "events": events, "length": _now()}
	if opts.stats != "":
		var fl := FileAccess.open(opts.stats, FileAccess.WRITE)
		fl.store_string(JSON.stringify(stats))
		fl.close()
	print("PROMO DONE ", stats)
	get_tree().quit(1 if fails > 0 else 0)


## "a Mojito", "an Espresso Martini"
func _a(name: String) -> String:
	return ("an " if name.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + name


func _now() -> float:
	return (Engine.get_process_frames() - _frame0) / 30.0


func _say(text: String, secs: float, delay := 0.0) -> void:
	var at := _now() + delay
	for e in events:
		at = maxf(at, e.end + 0.15) # one line at a time
	events.append({"at": at, "end": at + secs, "kind": "say", "text": text})


## Picks the camera for this moment. Runs before main's own _process each frame.
func _process(delta: float) -> void:
	if main == null or pcam == null:
		return
	var f: String = opts.format
	_shot_t += delta
	var cur: Dictionary = main.cur
	if not cur.is_empty() and cur.i != _last_step and cur.i >= 0 and cur.i < cur.drink.steps.size():
		_last_step = cur.i
		_on_step(cur)
	if not cur.is_empty() and cur.i >= cur.drink.steps.size() and _serving_to != cur.guest:
		# the drink is ready: watch it slide to the guest
		_serving_to = cur.guest
		if f == "learn":
			var st := events.filter(func(e): return e.kind == "step")
			if not st.is_empty():
				st[-1].end = _now()
			_cut("slide%d" % _serving_to, 3.0)
		elif f != "pov":
			_cut("slide%d" % _serving_to if f == "cinematic" else "guest%d" % _serving_to, 3.2)
	# your bartender has no head in your own view; outside views need it back
	var sk: Skeleton3D = main.me.s
	sk.set_bone_pose_scale(People.bone(sk, "Neck"), Vector3.ONE * (0.001 if _shot == "" else 1.0))
	if _shot == "":
		main.cam.make_current()
		main.hud.visible = f == "pov" or f == "guest"
		return
	var d: Array = SHOTS[_shot]
	var k := clampf(_shot_t / _shot_len, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var p: Vector3 = (d[0] as Vector3).lerp(d[1], k)
	pcam.global_transform = Transform3D(Basis.looking_at(d[2] - p), p)
	pcam.fov = d[3]
	pcam.make_current()
	main.hud.visible = false


func _between_steps() -> void:
	match opts.format:
		"learn":
			await _secs(1.3)
		"cinematic", "guest":
			await _secs(0.4)


func _cut(shot: String, secs: float) -> void:
	_shot = shot
	_shot_t = 0.0
	_shot_len = secs


func _pov() -> void:
	_shot = ""


## A new step started: say what it is (learn) and choose the angle for it.
func _on_step(cur: Dictionary) -> void:
	var f: String = opts.format
	var s: Dictionary = cur.step if cur.has("step") else {}
	if s.is_empty():
		return
	if f == "learn":
		var n := events.filter(func(e): return e.kind == "step").size() + 1
		if n > 1:
			events[-1].end = _now()
		events.append({"at": _now(), "end": _now() + 6.0, "kind": "step",
			"text": "Step %d: %s" % [n, Recipes.step_text(s, true)]})
	_alt += 1
	match f:
		"pov":
			_pov()
		"guest":
			# mostly your own view, one outside angle for the showy steps
			if s.t in ["shake", "muddle"]:
				_cut("side" if _alt % 2 == 0 else "side_l", 3.0)
			else:
				_pov()
		"learn":
			# close on the glass so every step is easy to see
			if s.t in ["pour", "top", "dash"]:
				_pov()
			elif s.t in ["shake", "stir"]:
				_cut("side", 3.0)
			else:
				_cut("top", 2.5)
		"cinematic":
			match s.t:
				"glass", "rim":
					_cut("side_l" if _alt % 2 == 0 else "side", 2.5)
				"pour", "top", "dash":
					_cut("low" if _alt % 2 == 0 else "top", 2.5)
				"shake":
					_cut("side", 3.0)
				"stir", "strain":
					_cut("low", 3.0)
				_:
					_cut("top", 2.5)
