extends Node
## Bartender Academy: the bar, the guests, the shift and all the screens.

const SHIFT_SECONDS := 180.0
const PATIENCE := 110.0
const POUR_RATE := 28.0 ## ml per second while holding pour
const TOP_RATE := 70.0

const VIEWS := {
	"bar": [Vector3(0, 1.6, .5), Vector3(0, 1.08, -1.5), 60.0],
	"station": [Vector3(.04, 1.6, .16), Vector3(0, .78, -.85), 60.0],
	"pour": [Vector3(-.05, 1.42, -.42), Vector3(.14, 1.2, -.92), 52.0],
	"work": [Vector3(0, 1.52, -.28), Vector3(0, 1.12, -1.0), 56.0],
	"back": [Vector3(.1, 1.6, -.25), Vector3(0, 1.32, 1.0), 58.0],
}

const C_PANEL := Color(0.06, 0.04, 0.05, 0.78)
const C_GOLD := Color(1.0, 0.75, 0.35)
const C_GREEN := Color(0.4, 1.0, 0.65)
const C_RED := Color(1.0, 0.42, 0.38)

var bar: Bar
var cam: Camera3D
var ui: CanvasLayer
var hud: Control
var overlay: Control

# guests: {node, x, order (drink dict or {}), patience, phase, bubble, served_glass, drink_t, waiter}
var guests: Array = []
var waiter: Node3D
var time := 0.0

# shift
var in_shift := false
var shift_left := 0.0
var shift_stats := {}

# the drink being made
var cur := {}
var glass_node: Node3D
var tin_node: Node3D
var jigger: Node3D
var pour_bottle: Node3D
var stream: MeshInstance3D
var pouring := false
var pour_ml := 0.0
var pour_target := 0.0
var pour_src := ""
var expecting := "" ## what a tap on the bar means right now: "", "pick", "shake", "stir"
var expect_src := ""
var progress := 0.0
var _last_dir := 0
var _taps := 0

# hud widgets
var ticket_title: Label
var ticket_steps: VBoxContainer
var ticket_panel: PanelContainer
var timer_label: Label
var coin_label: Label
var hint_label: Label
var actions: HBoxContainer
var toast: Label
var meter: Control
var meter_fill: ColorRect
var meter_band: ColorRect
var meter_label: Label
var progress_bar: ProgressBar


func _ready() -> void:
	bar = Bar.new()
	add_child(bar)
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = 2.6
	ca.dof_blur_far_transition = 2.5
	ca.dof_blur_amount = 0.06
	cam.attributes = ca
	_set_view("bar", 0.0)
	jigger = bar.make_jigger()
	jigger.position = Bar.JIGGER_SPOT
	bar.add_child(jigger)
	_spawn_people()
	ui = CanvasLayer.new()
	add_child(ui)
	_build_hud()
	Audio.loop("crowd", true, -14.0)
	if Save.birth_year == 0:
		show_age_gate()
	else:
		show_menu()


# =============================================================== people

func _spawn_people() -> void:
	var models := ["kate", "remy", "megan", "leonard"]
	for i in Bar.SEATS.size():
		var x: float = Bar.SEATS[i]
		var n := People.spawn(models[i], bar)
		n.rotation.y = [0.12, 0.0, -0.08, -0.15][i]
		People.set_height(n, 1.72)
		People.sit_legs(n)
		People.lean(n)
		People.place_hips(n, Vector3(x, 0.9, Bar.SEAT_Z))
		People.arms_on_bar(n, Bar.BT, Bar.BZ1, x, {"Right": Vector3(x - .12, Bar.BT + .07, Bar.BZ1 + .2)})
		guests.append({"node": n, "x": x, "order": {}, "patience": 0.0, "phase": i * 1.7, "bubble": null, "served": null, "drink_t": 0.0, "waiter": false})
	# the waiter waits at the service end of the bar with a tray
	waiter = People.spawn("josh", bar)
	waiter.rotation.y = -0.55
	People.set_height(waiter, 1.78)
	People.arms_down(waiter)
	People.hold_tray(waiter)
	People.place_standing(waiter, 1.86, -1.78)
	var h := People.hand_pos(waiter, "Left")
	bar.cyl(.2, .2, .012, bar.mat(Color(0.15, 0.15, 0.15), 0.8, 0.3), h + Vector3(0, .04, 0))
	waiter.set_meta("tray", h + Vector3(0, .047, 0))
	guests.append({"node": waiter, "x": 1.86, "order": {}, "patience": 0.0, "phase": 0.0, "bubble": null, "served": null, "drink_t": 0.0, "waiter": true})
	# people in the lounge behind
	var spots := [["megan", -4.2, -6.6, 0.0], ["remy", -3.4, -6.7, -.4], ["kate", 3.2, -6.5, .3], ["leonard", 4.0, -6.6, -.2]]
	for sp in spots:
		var n := People.spawn(sp[0], bar)
		n.rotation.y = sp[3]
		People.set_height(n, 1.72)
		People.sit_legs(n)
		People.arms_down(n)
		People.place_hips(n, Vector3(sp[1], 0.55, sp[2]))


func _head_pos(g: Dictionary) -> Vector3:
	return People.world_pos(People.skel(g.node), "HeadTop_End")


# =============================================================== camera

func _set_view(v: String, secs := 0.45) -> void:
	var d: Array = VIEWS[v]
	var target := Transform3D(Basis.looking_at(d[1] - d[0]), d[0])
	if secs <= 0.0:
		cam.global_transform = target
		cam.fov = d[2]
		return
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "global_transform", target, secs)
	tw.tween_property(cam, "fov", d[2], secs)


# =============================================================== HUD

func _panel(color := C_PANEL, radius := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	s.border_color = Color(1, 1, 1, 0.12)
	s.set_border_width_all(1)
	return s


func _label(text: String, size := 22, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable, size := 24, color := Color(1.0, 0.55, 0.25)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := _panel(color if st != "pressed" else color.darkened(0.25), 22)
		sb.set_content_margin_all(16)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.pressed.connect(func():
		Audio.play("click", -6.0)
		cb.call())
	return b


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	# ticket
	ticket_panel = PanelContainer.new()
	ticket_panel.add_theme_stylebox_override("panel", _panel())
	ticket_panel.position = Vector2(24, 22)
	ticket_panel.custom_minimum_size = Vector2(330, 0)
	hud.add_child(ticket_panel)
	var tv := VBoxContainer.new()
	ticket_panel.add_child(tv)
	ticket_title = _label("", 30, Color.WHITE)
	tv.add_child(ticket_title)
	ticket_steps = VBoxContainer.new()
	tv.add_child(ticket_steps)
	# timer + coins
	timer_label = _label("3:00", 44, C_GREEN)
	timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer_label.position = Vector2(-200, 14)
	timer_label.size = Vector2(176, 60)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	timer_label.add_theme_constant_override("outline_size", 10)
	hud.add_child(timer_label)
	coin_label = _label("", 28, C_GOLD)
	coin_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coin_label.position = Vector2(-260, 76)
	coin_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	coin_label.add_theme_constant_override("outline_size", 8)
	coin_label.size = Vector2(236, 40)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(coin_label)
	# instruction + actions at the bottom
	hint_label = _label("", 26, Color.WHITE)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-500, -170)
	hint_label.size = Vector2(1000, 50)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 8)
	hud.add_child(hint_label)
	actions = HBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	actions.position = Vector2(-700, -110)
	actions.size = Vector2(1400, 90)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	hud.add_child(actions)
	progress_bar = ProgressBar.new()
	progress_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	progress_bar.position = Vector2(-300, -120)
	progress_bar.size = Vector2(600, 26)
	progress_bar.show_percentage = false
	var fill := _panel(Color(1.0, 0.6, 0.2), 12)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_stylebox_override("background", _panel(Color(1, 1, 1, 0.15), 12))
	progress_bar.visible = false
	hud.add_child(progress_bar)
	# pour meter on the right
	meter = Control.new()
	meter.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	meter.position = Vector2(-120, -260)
	meter.size = Vector2(80, 520)
	meter.visible = false
	hud.add_child(meter)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.size = meter.size
	meter.add_child(back)
	meter_fill = ColorRect.new()
	meter_fill.color = Color(1.0, 0.62, 0.2)
	meter.add_child(meter_fill)
	meter_band = ColorRect.new()
	meter_band.color = Color(0.3, 1.0, 0.6, 0.55)
	meter.add_child(meter_band)
	meter_label = _label("", 40, C_GREEN)
	meter_label.position = Vector2(-190, 220)
	meter_label.size = Vector2(170, 60)
	meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meter.add_child(meter_label)
	# toast
	toast = _label("", 64, Color(1.0, 0.95, 0.75))
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-600, 130)
	toast.size = Vector2(1200, 90)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_outline_color", Color(0.9, 0.35, 0.05))
	toast.add_theme_constant_override("outline_size", 14)
	toast.modulate.a = 0.0
	hud.add_child(toast)
	hud.visible = false
	_update_coins()


func _update_coins() -> void:
	coin_label.text = "● %d" % Save.coins


func show_toast(text: String, color := Color(1.0, 0.95, 0.75), size := 64) -> void:
	toast.text = text
	toast.add_theme_font_size_override("font_size", size)
	toast.add_theme_color_override("font_color", color)
	toast.modulate.a = 1.0
	toast.scale = Vector2(0.85, 0.85)
	toast.pivot_offset = toast.size / 2
	var tw := create_tween()
	tw.tween_property(toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.1)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)


func _clear_actions() -> void:
	for c in actions.get_children():
		c.queue_free()
	progress_bar.visible = false


func _make_bubble(g: Dictionary) -> void:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 20)
	var sb := _panel(Color(1, 1, 1, 0.93), 14)
	sb.set_content_margin_all(10)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, Color(0.16, 0.09, 0.19))
	b.pressed.connect(func(): _pick_guest(guests.find(g)))
	hud.add_child(b)
	g.bubble = b


func _update_bubbles() -> void:
	for g in guests:
		var b: Button = g.bubble
		if b == null:
			continue
		var has: bool = not g.order.is_empty() and in_shift
		b.visible = has
		if not has:
			continue
		var making: bool = not cur.is_empty() and cur.guest == guests.find(g)
		var who := "Waiter: table %d\n" % g.table if g.waiter else ""
		var mood := "making now" if making else ("waiting" if g.patience > 40 else "hurry!")
		b.text = "%s%s\n%s" % [who, Recipes.drink_name(g.order), mood]
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal")
		sb.border_color = Color(1.0, 0.6, 0.15) if making else (Color(0.25, 0.8, 0.45) if g.patience > 40 else C_RED)
		sb.set_border_width_all(4)
		var p := cam.unproject_position(_head_pos(g) + Vector3(0, 0.12, 0))
		b.position = p - Vector2(b.size.x / 2, b.size.y + 6)
		b.visible = not cam.is_position_behind(_head_pos(g))


# =============================================================== menus

func _overlay() -> Control:
	if overlay:
		overlay.queue_free()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	return overlay


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _center_box(parent: Control, width := 640) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel(Color(0.05, 0.03, 0.04, 0.86), 26))
	p.custom_minimum_size = Vector2(width, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


func show_age_gate() -> void:
	hud.visible = false
	_set_view("back", 0.0)
	var v := _center_box(_overlay(), 620)
	var t := _label("Welcome behind the bar", 40, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label("Bartender Academy is a bar simulation for learning cocktails.\nWhat year were you born?", 22)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(s)
	var year := [2000]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var yl := _label("2000", 54)
	var minus := _button("−", func():
		year[0] = maxi(1930, year[0] - 1)
		yl.text = str(year[0]), 34, Color(0.3, 0.25, 0.35))
	var plus := _button("+", func():
		year[0] = mini(Time.get_date_dict_from_system().year, year[0] + 1)
		yl.text = str(year[0]), 34, Color(0.3, 0.25, 0.35))
	var minus10 := _button("−10", func():
		year[0] = maxi(1930, year[0] - 10)
		yl.text = str(year[0]), 24, Color(0.3, 0.25, 0.35))
	var plus10 := _button("+10", func():
		year[0] = mini(Time.get_date_dict_from_system().year, year[0] + 10)
		yl.text = str(year[0]), 24, Color(0.3, 0.25, 0.35))
	for n in [minus10, minus, yl, plus, plus10]:
		row.add_child(n)
	v.add_child(_button("Continue", func():
		Save.birth_year = year[0]
		if Save.mocktail_locked():
			Save.mocktail = true
		Save.save()
		bar.build_rail()
		show_menu(), 28))


func show_menu() -> void:
	_end_drink(false)
	in_shift = false
	hud.visible = false
	_set_view("bar", 0.8)
	var o := _overlay()
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(80, -260)
	v.add_theme_constant_override("separation", 16)
	o.add_child(v)
	var t := _label("BARTENDER\nACADEMY", 78, Color(1.0, 0.88, 0.7))
	t.add_theme_color_override("font_outline_color", Color(0.7, 0.25, 0.05))
	t.add_theme_constant_override("outline_size", 10)
	v.add_child(t)
	v.add_child(_label("Work the bar. Learn real cocktails.", 24, Color(1, 1, 1, 0.85)))
	v.add_child(_label("● %d coins   ·   %d of %d drinks unlocked" % [Save.coins, Save.unlocked, Recipes.DRINKS.size()], 20, C_GOLD))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	v.add_child(sp)
	v.add_child(_button("START SHIFT  ▶", start_shift, 32))
	v.add_child(_button("BAR BOOK  ·  recipes", show_book, 24, Color(0.25, 0.2, 0.3)))
	var mt := "MOCKTAIL MODE: %s" % ("ON" if Save.mocktail else "OFF")
	if Save.mocktail_locked():
		mt += " (under 18)"
	v.add_child(_button(mt, func():
		if Save.mocktail_locked():
			return
		Save.mocktail = not Save.mocktail
		Save.save()
		bar.build_rail()
		show_menu(), 22, Color(0.2, 0.35, 0.25)))
	v.add_child(_button("SOUND: %s" % ("ON" if Save.sound else "OFF"), func():
		Audio.set_sound(not Save.sound)
		Audio.loop("crowd", Save.sound, -14.0)
		show_menu(), 22, Color(0.25, 0.2, 0.3)))
	var note := _label("A simulation for adults. Fictional brands. Please drink responsibly.", 16, Color(1, 1, 1, 0.55))
	v.add_child(note)


func show_book() -> void:
	var o := _overlay()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.02, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(bg)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 120
	sc.offset_right = -120
	sc.offset_top = 30
	sc.offset_bottom = -30
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 18)
	sc.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(_label("BAR BOOK", 48, C_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(_button("Close", show_menu, 22, Color(0.3, 0.25, 0.35)))
	v.add_child(top)
	v.add_child(_label("Real recipes in ml. Every drink here is one you can make for real.", 20, Color(1, 1, 1, 0.7)))
	for i in Recipes.DRINKS.size():
		var d: Dictionary = Recipes.DRINKS[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _panel(Color(0.12, 0.08, 0.07, 0.95), 18))
		v.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		if i >= Save.unlocked:
			cv.add_child(_label("🔒  %s" % d.name, 30, Color(1, 1, 1, 0.45)))
			cv.add_child(_label("Unlocks after %d more shift%s." % [i - Save.unlocked + 1, "" if i - Save.unlocked == 0 else "s"], 18, Color(1, 1, 1, 0.45)))
			continue
		var name_line := "%s   ·   %s glass · %s" % [Recipes.drink_name(d), Recipes.GLASSES[d.glass].name, d.method]
		cv.add_child(_label(name_line, 30, Color.WHITE))
		var made: int = Save.made.get(d.id, 0)
		cv.add_child(_label("Made %d times · best %s" % [made, "★".repeat(int(Save.best.get(d.id, 0.0)))], 16, C_GOLD))
		var about := _label(d.about, 18, Color(1, 1, 1, 0.75))
		about.autowrap_mode = TextServer.AUTOWRAP_WORD
		cv.add_child(about)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.add_theme_font_size_override("normal_font_size", 19)
		rt.add_theme_font_size_override("bold_font_size", 19)
		var txt := "[b]Behind the bar[/b]\n"
		var k := 1
		for s in d.steps:
			txt += "%d. %s\n" % [k, Recipes.step_text(s, true)]
			k += 1
		txt += "\n[b]Make it for real (at home)[/b]\n"
		for h in d.home:
			txt += "• %s\n" % h
		if not Save.mocktail:
			txt += "\n[b]Mocktail twin:[/b] %s — swap the spirits for juices in mocktail mode." % d.mocktail
		rt.text = txt
		cv.add_child(rt)


# =============================================================== shift

func start_shift() -> void:
	_close_overlay()
	var go := func():
		in_shift = true
		shift_left = SHIFT_SECONDS
		shift_stats = {"served": 0, "stars": 0.0, "coins": 0, "perfect": 0}
		hud.visible = true
		_update_coins()
		_set_view("bar", 0.6)
		ticket_panel.visible = false
		for i in guests.size():
			var g: Dictionary = guests[i]
			if g.bubble == null:
				_make_bubble(g)
			g.order = {}
			if not g.waiter and i < 3:
				_new_order(g, 6.0 * i)
		_clear_actions()
		hint_label.text = "Tap a guest's order to start making it"
	if Save.shifts >= 1:
		Ads.show_interstitial(go)
	else:
		go.call()


func _new_order(g: Dictionary, delay := 0.0) -> void:
	var pool: Array = Recipes.DRINKS.slice(0, Save.unlocked)
	var d: Dictionary = pool[randi() % pool.size()]
	if Save.made.is_empty() and shift_stats.served == 0 and guests.find(g) == 0:
		d = Recipes.DRINKS[0]
	g.order = d
	g.patience = PATIENCE + delay
	if g.waiter:
		g.table = randi_range(2, 9)


func _process(delta: float) -> void:
	time += delta
	for g in guests:
		if not g.waiter:
			People.idle(g.node, time, g.phase)
	if not in_shift:
		if overlay:
			# slow drift of the camera behind the menus
			var d: Array = VIEWS["bar"]
			var p: Vector3 = d[0] + Vector3(sin(time * 0.15) * 0.25, 0, 0)
			cam.global_transform = Transform3D(Basis.looking_at(d[1] - p), p)
		return
	shift_left = maxf(0.0, shift_left - delta)
	timer_label.text = "%d:%02d" % [int(shift_left) / 60, int(shift_left) % 60]
	timer_label.add_theme_color_override("font_color", C_RED if shift_left < 20 else C_GREEN)
	for g in guests:
		if not g.order.is_empty():
			g.patience -= delta
		elif g.served != null:
			g.drink_t -= delta
			if g.drink_t <= 0:
				g.served.queue_free()
				g.served = null
				if shift_left > 15:
					_new_order(g)
		elif shift_left > 15 and randf() < delta * (0.06 if g.waiter else 0.12):
			_new_order(g)
	_update_bubbles()
	if pouring:
		var rate := TOP_RATE if cur.step.t == "top" else POUR_RATE
		pour_ml += rate * delta
		_update_meter()
		if cur.step.t != "top":
			bar.set_jigger(jigger, pour_ml / maxf(pour_target * 1.5, 30.0), Recipes.SOURCES[pour_src].liquid)
		else:
			_add_to_vessel(rate * delta, Recipes.SOURCES[pour_src].liquid, false)
	if shift_left <= 0.0 and cur.is_empty():
		_end_shift()


func _pick_guest(i: int) -> void:
	if not cur.is_empty() or not in_shift:
		return
	var g: Dictionary = guests[i]
	if g.order.is_empty():
		return
	Audio.play("click")
	var d: Dictionary = g.order
	cur = {"drink": d, "guest": i, "i": -1, "mistakes": 0, "errs": [], "start": time, "vol": 0.0, "color": Color(0, 0, 0, 0), "perfect": 0, "in_tin": false}
	glass_node = null
	tin_node = null
	ticket_panel.visible = true
	ticket_title.text = Recipes.drink_name(d)
	_next_step()


func _hint_on() -> bool:
	return not Save.learned(cur.drink.id)


func _refresh_ticket() -> void:
	for c in ticket_steps.get_children():
		c.queue_free()
	var steps: Array = cur.drink.steps
	for k in steps.size():
		var s: Dictionary = steps[k]
		var mark := "✓ " if k < cur.i else ("▶ " if k == cur.i else "○ ")
		var col := C_GREEN if k < cur.i else (Color(1, 0.75, 0.35) if k == cur.i else Color(1, 1, 1, 0.6))
		ticket_steps.add_child(_label(mark + Recipes.step_text(s, _hint_on() or k < cur.i), 19, col))


func _next_step() -> void:
	cur.i += 1
	_clear_actions()
	meter.visible = false
	expecting = ""
	var steps: Array = cur.drink.steps
	if cur.i >= steps.size():
		_ready_to_serve()
		return
	cur.step = steps[cur.i]
	_refresh_ticket()
	var s: Dictionary = cur.step
	match s.t:
		"glass":
			_set_view("bar")
			hint_label.text = "Pick the right glass" + ("" if _hint_on() else " (from memory!)")
			for k in Recipes.GLASSES:
				actions.add_child(_button(Recipes.GLASSES[k].name, _choose.bind("glass", k), 24, Color(0.25, 0.2, 0.3)))
		"rim":
			hint_label.text = "Rim the glass?"
			for k in Recipes.RIMS:
				actions.add_child(_button(Recipes.RIMS[k], _choose.bind("rim", k), 24, Color(0.25, 0.2, 0.3)))
		"ice":
			_set_view("station")
			hint_label.text = "Scoop the ice: which kind?"
			for k in Recipes.ICE:
				actions.add_child(_button(Recipes.ICE[k], _choose.bind("ice", k), 24, Color(0.2, 0.3, 0.4)))
		"garnish":
			_set_view("work")
			hint_label.text = "Finish with the garnish"
			for k in Recipes.GARNISH:
				actions.add_child(_button(Recipes.GARNISH[k], _choose.bind("garnish", k), 22, Color(0.2, 0.35, 0.2)))
		"pour", "top", "dash":
			_set_view("station")
			expecting = "pick"
			expect_src = Recipes.src(s.src)
			var where := "speed rail" if Recipes.SOURCES[expect_src].kind == "rail" else "station"
			hint_label.text = "Tap the %s in the %s" % [Recipes.SOURCES[expect_src].name, where]
		"muddle":
			_set_view("work")
			_taps = 0
			hint_label.text = "Muddle gently: tap 6 times"
			actions.add_child(_button("MUDDLE", _muddle, 30))
		"shake":
			_set_view("work")
			expecting = "shake"
			progress = 0.0
			_last_dir = 0
			progress_bar.visible = true
			progress_bar.value = 0
			hint_label.text = "Shake hard! Swipe up and down fast (or shake your phone)"
			if tin_node:
				tin_node.position = Bar.TIN_SPOT
			Audio.loop("shake", true, -4.0)
		"stir":
			_set_view("work")
			expecting = "stir"
			progress = 0.0
			progress_bar.visible = true
			progress_bar.value = 0
			hint_label.text = "Stir: draw circles on the screen until it's cold"
		"strain":
			_set_view("work")
			hint_label.text = "Strain it into the glass"
			actions.add_child(_button("STRAIN", _strain, 30))


func _choose(kind: String, value: String) -> void:
	var s: Dictionary = cur.step
	var right: String = s.v
	var names := {"glass": Recipes.GLASSES, "rim": Recipes.RIMS, "ice": Recipes.ICE, "garnish": Recipes.GARNISH}
	if value != right:
		cur.mistakes += 1
		Audio.play("bad", -4.0)
		var rn = names[kind][right]
		show_toast("%s needs: %s" % [Recipes.drink_name(cur.drink), rn.name if rn is Dictionary else rn], C_RED, 40)
	else:
		Audio.play("good", -8.0)
	match kind:
		"glass":
			glass_node = bar.make_glass(right)
			glass_node.position = Bar.GLASS_SPOT
			bar.add_child(glass_node)
			Audio.play("clink")
			if Recipes.uses_tin(cur.drink):
				tin_node = bar.make_tin()
				tin_node.position = Bar.TIN_SPOT
				bar.add_child(tin_node)
		"rim":
			if right != "none":
				var r: Array = Bar.GLASS_PROFILES[glass_node.get_meta("kind")]
				var top: Array = r[r.size() - 1]
				var ring := TorusMesh.new()
				ring.inner_radius = top[0] - .003
				ring.outer_radius = top[0] + .003
				bar.add_mesh(ring, bar.mat(Color(0.97, 0.97, 0.95), 0, 0.9), Vector3(0, top[1], 0), glass_node)
		"ice":
			Audio.play("ice")
			var into: Node3D = tin_node if tin_node else glass_node
			_put_ice(into, right)
		"garnish":
			bar.garnish(right, glass_node, Vector3(0, _glass_top(), 0))
	_next_step()


func _glass_top() -> float:
	var r: Array = Bar.GLASS_PROFILES[glass_node.get_meta("kind")]
	return r[r.size() - 1][1]


func _put_ice(into: Node3D, kind: String) -> void:
	if into.get_meta("kind") == "tin":
		return
	var b: Array = Bar.GLASS_BOWL[into.get_meta("kind")]
	var r: float = b[2] * 0.75
	if kind == "big":
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * r * 1.6
		c.mesh = bm
		c.material_override = bar.ice_mat
		c.position = Vector3(0, b[0] + r * 0.85, 0)
		c.rotation.y = 0.3
		into.add_child(c)
	else:
		var n := 14 if kind == "cubes" else 40
		var size := 0.024 if kind == "cubes" else 0.011
		bar.ice_cubes(into, Vector3(0, (b[0] + b[1]) / 2, 0), Vector3(r * .7, (b[1] - b[0]) * .4, r * .7), n, size)


func _unhandled_input(e: InputEvent) -> void:
	if not in_shift or cur.is_empty():
		return
	var tap: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
	if expecting == "pick" and tap:
		_tap_pick(e.position)
	elif expecting == "shake" and (e is InputEventScreenDrag or (e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		var dy: float = e.relative.y
		if absf(dy) > 4:
			var dir := 1 if dy > 0 else -1
			if dir != _last_dir:
				_last_dir = dir
				_shake_step(6.0)
	elif expecting == "stir" and (e is InputEventScreenDrag or (e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		progress += e.relative.length() / 30.0
		progress_bar.value = progress
		if glass_node:
			glass_node.rotation.y += e.relative.length() * 0.01
		if progress >= 100.0:
			expecting = ""
			Audio.play("good", -6.0)
			show_toast("Nice and cold", C_GREEN, 44)
			_next_step()


func _physics_process(_d: float) -> void:
	if expecting == "shake":
		var a := Input.get_accelerometer()
		if a.length() > 17.0:
			_shake_step(0.9)


func _shake_step(amount: float) -> void:
	progress += amount
	progress_bar.value = progress
	if tin_node:
		tin_node.position = Bar.TIN_SPOT + Vector3(0, 0.05 + 0.04 * sin(progress * 0.5), 0)
		tin_node.rotation.z = sin(progress * 0.5) * 0.25
	if progress >= 100.0:
		expecting = ""
		Audio.loop("shake", false)
		if tin_node:
			tin_node.position = Bar.TIN_SPOT
			tin_node.rotation = Vector3.ZERO
		Audio.play("good", -6.0)
		show_toast("Ice cold!", C_GREEN, 44)
		_next_step()


func _tap_pick(p: Vector2) -> void:
	var best := ""
	var best_d := 90.0
	for id in bar.pickables:
		var wp: Vector3 = bar.pickables[id]
		if cam.is_position_behind(wp):
			continue
		var d := cam.unproject_position(wp).distance_to(p)
		if d < best_d:
			best_d = d
			best = id
	if best == "" or best == "ice":
		return
	if best != expect_src:
		cur.mistakes += 1
		Audio.play("bad", -4.0)
		show_toast("That's %s. You need %s." % [Recipes.SOURCES[best].name, Recipes.SOURCES[expect_src].name], C_RED, 34)
		return
	Audio.play("clink", -6.0)
	expecting = ""
	pour_src = best
	var s: Dictionary = cur.step
	if s.t == "dash":
		_taps = 0
		hint_label.text = "Tap for each dash: %d" % s.n
		_set_view("work")
		actions.add_child(_button("DASH", _dash, 30))
		return
	_start_pour_view()


func _start_pour_view() -> void:
	var s: Dictionary = cur.step
	_set_view("pour")
	pour_ml = 0.0
	if s.t == "top":
		var cap: float = Recipes.GLASSES[glass_node.get_meta("kind")].ml
		pour_target = maxf(30.0, cap * 0.85 - cur.vol)
		hint_label.text = "Hold to top up to the line"
	else:
		pour_target = s.ml
		hint_label.text = "Hold to pour, let go on the green line" + ("" if _hint_on() else " (how many ml?)")
	# the bottle, tipped over the jigger (or over the glass when topping up)
	if pour_bottle:
		pour_bottle.queue_free()
	var over: Vector3 = Bar.JIGGER_SPOT + Vector3(0, .1, 0) if s.t != "top" else glass_node.position + Vector3(0, _glass_top() + .05, 0)
	pour_bottle = bar.bottle(pour_src, Vector3.ZERO, bar, true, .036, .29)
	pour_bottle.rotation.z = 2.2
	pour_bottle.position = over + Vector3(.259, .19, 0)
	stream = bar.cyl(.0032, .0036, .09, bar.liquid_mat(Recipes.SOURCES[pour_src].liquid), over + Vector3(0, -.04, 0))
	stream.visible = false
	meter.visible = true
	_update_meter()
	var hold := _button("HOLD TO POUR", func(): pass, 32)
	hold.button_down.connect(func():
		pouring = true
		stream.visible = true
		Audio.loop("pour", true, -4.0))
	hold.button_up.connect(_pour_release)
	actions.add_child(hold)


func _update_meter() -> void:
	var full := pour_target * 1.6
	var h := meter.size.y
	var f := clampf(pour_ml / full, 0, 1)
	meter_fill.position = Vector2(0, h * (1 - f))
	meter_fill.size = Vector2(meter.size.x, h * f)
	var band := 3.0 / full
	meter_band.position = Vector2(0, h * (1 - pour_target / full - band))
	meter_band.size = Vector2(meter.size.x, h * band * 2)
	meter_band.visible = _hint_on() or cur.step.t == "top"
	meter_label.text = "%d ml" % int(pour_ml)


func _pour_release() -> void:
	if not pouring:
		return
	pouring = false
	Audio.loop("pour", false)
	if stream:
		stream.queue_free()
		stream = null
	var err := pour_ml - pour_target
	if cur.step.t == "top":
		err = clampf(err, -15.0, 15.0) * 0.5
	cur.errs.append(err)
	if Recipes.is_perfect(err):
		cur.perfect += 1
		Audio.play("good", -6.0)
		show_toast("PERFECT POUR")
	elif absf(err) <= 6.0:
		show_toast("Good pour  (%+d ml)" % int(err), Color(1, 1, 1), 44)
	else:
		Audio.play("bad", -8.0)
		show_toast("%s by %d ml" % ["Over" if err > 0 else "Under", absi(int(err))], C_RED, 44)
	if cur.step.t != "top":
		_add_to_vessel(pour_ml, Recipes.SOURCES[pour_src].liquid, true)
		bar.set_jigger(jigger, 0, Color.WHITE)
	if pour_bottle:
		pour_bottle.queue_free()
		pour_bottle = null
	await get_tree().create_timer(0.7).timeout
	if not cur.is_empty():
		_next_step()


## Adds liquid to the tin (if this drink is shaken) or straight to the glass.
func _add_to_vessel(ml: float, color: Color, splash: bool) -> void:
	var total: float = cur.vol + ml
	var c: Color = color if cur.vol <= 0 else cur.color.lerp(color, ml / total)
	cur.vol = total
	cur.color = c
	if splash:
		Audio.play("clink", -14.0, 1.3)
	if tin_node == null and glass_node:
		var cap: float = Recipes.GLASSES[glass_node.get_meta("kind")].ml
		bar.set_fill(glass_node, cur.vol / cap, c)


func _muddle() -> void:
	_taps += 1
	Audio.play("muddle")
	if _taps == 1 and glass_node:
		bar.garnish("mint_sprig", glass_node, Vector3(0, 0.02, 0))
		var w := bar.lime_wheel(glass_node, Vector3(0.008, 0.02, 0), .02)
		w.rotation.x = 1.2
	hint_label.text = "Muddle gently: %d more" % (6 - _taps)
	if _taps >= 6:
		_next_step()


func _dash() -> void:
	_taps += 1
	Audio.play("muddle", -6.0, 1.6)
	_add_to_vessel(1.0, Recipes.SOURCES[pour_src].liquid, false)
	hint_label.text = "Dashes: %d / %d" % [_taps, cur.step.n]
	if _taps == cur.step.n:
		_next_step()
	elif _taps > cur.step.n:
		pass


func _strain() -> void:
	_clear_actions()
	if tin_node == null or glass_node == null:
		_next_step()
		return
	var tw := create_tween()
	var over := glass_node.position + Vector3(0.09, _glass_top() + 0.12, 0)
	tw.tween_property(tin_node, "position", over, 0.35)
	tw.parallel().tween_property(tin_node, "rotation:z", 1.9, 0.35)
	Audio.play("pour", -8.0)
	tw.tween_callback(func():
		var cap: float = Recipes.GLASSES[glass_node.get_meta("kind")].ml
		var fill_to: float = minf(0.9, cur.vol * 1.2 / cap)
		var t2 := create_tween()
		t2.tween_method(func(f): bar.set_fill(glass_node, f, cur.color), 0.0, fill_to, 0.6))
	tw.tween_interval(0.7)
	tw.tween_property(tin_node, "rotation:z", 0.0, 0.3)
	tw.parallel().tween_property(tin_node, "position", Bar.TIN_SPOT, 0.3)
	tw.tween_callback(func():
		if glass_node.get_meta("kind") == "rocks":
			_put_ice(glass_node, "cubes")
		_next_step())


func _ready_to_serve() -> void:
	_refresh_ticket()
	_set_view("bar")
	var g: Dictionary = guests[cur.guest]
	hint_label.text = "Slide it to %s" % ("the waiter" if g.waiter else "your guest")
	actions.add_child(_button("SERVE  ➜", _serve, 34, Color(0.2, 0.6, 0.35)))


func _serve() -> void:
	_clear_actions()
	var g: Dictionary = guests[cur.guest]
	var d: Dictionary = cur.drink
	var stars := Recipes.stars_for(cur.mistakes, cur.errs)
	var secs: float = time - cur.start
	var mood: float = clampf(g.patience / PATIENCE, 0.0, 1.0)
	var tip: int = int(round(d.price * (0.5 + 0.5 * stars / 3.0) * (0.75 + 0.25 * mood))) + cur.perfect * 5 + (10 if secs < 35 else 0)
	Save.coins += tip
	Save.record(d.id, stars)
	Save.save()
	shift_stats.served += 1
	shift_stats.stars += stars
	shift_stats.coins += tip
	shift_stats.perfect += cur.perfect
	_update_coins()
	var dest: Vector3 = g.node.get_meta("tray") if g.waiter else Vector3(g.x - .16, Bar.BT + .008, Bar.BZ1 + .2)
	var gl := glass_node
	glass_node = null
	Audio.play("slide")
	var tw := create_tween()
	tw.tween_property(gl, "position", dest, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		Audio.play("tip")
		show_toast("%s   +%d" % ["★".repeat(int(floor(stars))) + ("½" if fmod(stars, 1.0) >= 0.5 else ""), tip], C_GOLD, 60))
	g.order = {}
	g.served = gl
	g.drink_t = 4.0 if g.waiter else randf_range(12.0, 18.0)
	_end_drink(true)


## Clears the work area. [param keep_glass] keeps the served glass alive.
func _end_drink(keep_glass: bool) -> void:
	expecting = ""
	pouring = false
	Audio.loop("pour", false)
	Audio.loop("shake", false)
	if tin_node:
		tin_node.queue_free()
		tin_node = null
	if glass_node and not keep_glass:
		glass_node.queue_free()
	glass_node = null
	if pour_bottle:
		pour_bottle.queue_free()
		pour_bottle = null
	if stream:
		stream.queue_free()
		stream = null
	cur = {}
	if hud:
		ticket_panel.visible = false
		meter.visible = false
		_clear_actions()
		hint_label.text = "Tap a guest's order to start making it" if in_shift else ""


func _end_shift() -> void:
	in_shift = false
	_end_drink(false)
	for g in guests:
		g.order = {}
		if g.served:
			g.served.queue_free()
			g.served = null
		if g.bubble:
			g.bubble.visible = false
	Save.shifts += 1
	var unlocked := ""
	if Save.unlocked < Recipes.DRINKS.size() and shift_stats.served > 0:
		Save.unlocked += 1
		unlocked = Recipes.drink_name(Recipes.DRINKS[Save.unlocked - 1])
	Save.save()
	hud.visible = false
	var v := _center_box(_overlay(), 680)
	var t := _label("SHIFT OVER", 52, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var avg: float = shift_stats.stars / maxf(1, shift_stats.served)
	for line in [
		"Drinks served: %d" % shift_stats.served,
		"Average: %.1f ★" % avg,
		"Perfect pours: %d" % shift_stats.perfect,
		"Tips: ● %d" % shift_stats.coins,
	]:
		var l := _label(line, 28)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	if unlocked != "":
		var u := _label("New recipe unlocked: %s" % unlocked, 26, C_GREEN)
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(u)
	if shift_stats.coins > 0:
		var dbl := _button("▶  Watch a video: double tips", func(): pass, 24, Color(0.55, 0.4, 0.1))
		dbl.pressed.connect(_double_tips.bind(dbl))
		v.add_child(dbl)
	v.add_child(_button("NEXT SHIFT  ▶", start_shift, 30))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(_button("Bar Book", show_book, 22, Color(0.25, 0.2, 0.3)))
	row.add_child(_button("Menu", show_menu, 22, Color(0.25, 0.2, 0.3)))
	v.add_child(row)


func _double_tips(btn: Button) -> void:
	btn.disabled = true
	Ads.show_rewarded(func():
		Save.coins += shift_stats.coins
		shift_stats.coins *= 2
		Save.save()
		show_toast("Tips doubled!", C_GOLD)
		btn.text = "Tips doubled: ● %d" % shift_stats.coins)
