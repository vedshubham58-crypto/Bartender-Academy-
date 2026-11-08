extends Node
## Bartender: The Cocktail Academy: the bar, the guests, the shift and all the screens.

const SHIFT_SECONDS := 90.0 ## short shifts: one and a half minutes
const PATIENCE := 110.0
const POUR_RATE := 22.0 ## ml per second while holding pour (slow enough to stop on the line)
const TOP_RATE := 70.0
const BARTENDERS := {
	"remy": {"name": "Leo", "about": "Easy smile, quick hands, relaxed style."},
	"louise": {"name": "Mia", "about": "Sharp, precise, smart navy uniform."},
}
const SHAKE_TILT := -0.45 ## the shaker leans so each hand stays on its own side
const SHAKE_SPOT := Vector3(0.05, 1.17, -0.88) ## the tin is held up here while shaking

const VIEWS := {
	"bar": [Vector3(0, 1.6, .5), Vector3(0, 1.08, -1.5), 60.0],
	"station": [Vector3(.04, 1.75, .35), Vector3(0, .7, -.55), 66.0],
	"pour": [Vector3(-.05, 1.42, -.42), Vector3(.14, 1.2, -.92), 52.0],
	"work": [Vector3(0.05, 1.5, -.42), Vector3(0.05, 1.12, -1.0), 58.0],
	"back": [Vector3(.1, 1.6, -.25), Vector3(0, 1.32, 1.0), 58.0],
	"menu": [Vector3(0.25, 1.6, -1.45), Vector3(-0.15, 1.33, 0.15), 52.0], ## guest's seat, looking at your bartender
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
var boost := {} ## shop boosts running this shift

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
# the player's own bartender body and props held in the hands
var me: FirstPerson
var spoon: Node3D
var muddler: Node3D
var dash_bottle: Node3D
var _serving: Node3D
var _straining := false
var _reach_until := 0.0
var _picking := false
var _previews: Array = []
var _reach_pos := Vector3.ZERO
var cam_base := Transform3D() ## where the current view puts the camera; swipes look around from here
var look_yaw := 0.0
var look_pitch := 0.0
var _press_pos := Vector2.ZERO
var _dragged := false
var pointer: Node3D ## glowing arrow over the next thing to grab
var _carry: Node3D ## a glass or scoop the right hand is carrying
var _pour_t0 := 0
var host: Node3D ## the bartender standing behind the bar on the menu screen
var tv_text: Label3D
var _tv_slide := 0
var _tv_next := 0.0
var _tv_reward_at := -999.0
var paused := false
var blender: Node3D
var _float := {} ## a layer being poured over the spoon
var _blend := {}
var _flame := {}
var _flip := {}
var _last_pause_ad := -999.0
var title_font: FontVariation


func _ready() -> void:
	# use the simpler versions of the 3D people sooner (they're most of the triangles)
	get_viewport().mesh_lod_threshold = 6.0
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
	bar.skin_tool(jigger, Save.tool_skin)
	bar.set_light_theme(Save.light_theme)
	jigger.position = Bar.JIGGER_SPOT
	bar.add_child(jigger)
	_spawn_people()
	if Save.bartender == "david":
		Save.bartender = "remy" # Leo got a new look
	set_bartender(Save.bartender if Save.bartender != "" else "remy")
	tv_text = bar.build_tv()
	title_font = FontVariation.new()
	title_font.base_font = load("res://fonts/PlayfairDisplay.ttf")
	title_font.variation_opentype = {2003265652: 800}
	ui = CanvasLayer.new()
	add_child(ui)
	_build_hud()
	Audio.loop("crowd", true, -18.0)
	if Save.birth_year == 0:
		show_age_gate()
	else:
		show_menu()


# =============================================================== people

func _spawn_people() -> void:
	var models := ["kate", "david", "megan", "leonard"]
	for i in Bar.SEATS.size():
		var x: float = Bar.SEATS[i]
		var n := People.spawn(models[i], bar)
		n.rotation.y = [0.12, 0.0, -0.08, -0.15][i]
		People.set_height(n, 1.72)
		People.sit_legs(n)
		People.lean(n)
		People.place_hips(n, Vector3(x, 0.9, Bar.SEAT_Z))
		People.arms_on_bar(n, Bar.BT, Bar.BZ1, x, {"Right": Vector3(x - .12, Bar.BT + .07, Bar.BZ1 + .2)})
		n.set_meta("model", models[i])
		guests.append({"node": n, "x": x, "order": {}, "patience": 0.0, "phase": i * 1.7, "bubble": null, "served": null, "drink_t": 0.0, "waiter": false, "seat_rot": n.rotation.y})
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
	# guests relaxing on the terrace sofas, a drink on the table in front of them
	var spots := [["louise", -2.6, 0.15], ["leonard", 2.6, -0.1], ["megan", 2.95, -0.35]]
	for sp in spots:
		var n := People.spawn(sp[0], bar)
		n.rotation.y = sp[2]
		People.set_height(n, 1.7)
		People.sit_legs(n)
		People.arms_down(n)
		People.place_hips(n, Vector3(sp[1], 0.55, -7.62))
	for x in [-2.6, 2.75]:
		var gl := bar.make_glass("coupe" if x < 0 else "rocks")
		gl.position = Vector3(x + 0.1, 0.77, -6.95)
		bar.add_child(gl)
		bar.set_fill(gl, 0.6, Color(0.9, 0.35, 0.3) if x < 0 else Color(0.8, 0.5, 0.15))


func _head_pos(g: Dictionary) -> Vector3:
	if g.node == null:
		return Vector3(g.x, 1.6, Bar.SEAT_Z)
	return People.world_pos(People.skel(g.node), "HeadTop_End")


# =============================================================== camera

func _set_view(v: String, secs := 0.45) -> void:
	var d: Array = VIEWS[v]
	var target := Transform3D(Basis.looking_at(d[1] - d[0]), d[0])
	if secs <= 0.0:
		cam_base = target
		cam.fov = d[2]
		look_yaw = 0.0
		look_pitch = 0.0
		_apply_cam()
		return
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "cam_base", target, secs)
	tw.tween_property(cam, "fov", d[2], secs)
	tw.tween_property(self, "look_yaw", 0.0, secs)
	tw.tween_property(self, "look_pitch", 0.0, secs)


## Puts the camera at the view, turned by the player's swipes.
func _apply_cam() -> void:
	var b := Basis(Vector3.UP, look_yaw) * cam_base.basis
	b = b * Basis(Vector3.RIGHT, look_pitch)
	cam.global_transform = Transform3D(b.orthonormalized(), cam_base.origin)


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
	var pb := _button("II", pause_shift, 26, Color(0.25, 0.2, 0.3))
	pb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pb.position = Vector2(-330, 18)
	pb.size = Vector2(70, 60)
	hud.add_child(pb)
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
		var ask: String = ("\n" + g.order.request) if g.order.has("request") else ""
		b.text = "%s%s%s\n%s" % [who, Recipes.drink_name(g.order), ask, mood]
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal")
		sb.border_color = Color(1.0, 0.6, 0.15) if making else (Color(0.25, 0.8, 0.45) if g.patience > 40 else C_RED)
		sb.set_border_width_all(4)
		var p := cam.unproject_position(_head_pos(g) + Vector3(0, 0.12, 0))
		var vw := get_viewport().get_visible_rect().size
		var bp := p - Vector2(b.size.x / 2, b.size.y + 6)
		bp.x = clampf(bp.x, 4.0, vw.x - b.size.x - 4.0)
		if bp.x + b.size.x > vw.x - 160.0 and bp.y < 112.0:
			bp.y = 112.0 # keep clear of the timer and coins
		b.position = bp
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
	var s := _label("Bartender: The Cocktail Academy is a bar simulation for learning cocktails.\nWhat year were you born?", 22)
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
		if Save.bartender == "":
			show_bartender_pick()
		else:
			show_menu(), 28))


func show_menu() -> void:
	_end_drink(false)
	in_shift = false
	hud.visible = false
	Ads.show_banner()
	_set_view("menu", 0.8)
	var o := _overlay()
	var fade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gr.colors = PackedColorArray([Color(0.03, 0.015, 0.01, 0.92), Color(0.03, 0.015, 0.01, 0.7), Color(0.03, 0.015, 0.01, 0.0)])
	gt.gradient = gr
	gt.fill_to = Vector2(1, 0)
	fade.texture = gt
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fade.size = Vector2(760, 720)
	fade.custom_minimum_size = Vector2(760, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(fade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(60, -330)
	v.add_theme_constant_override("separation", 9)
	o.add_child(v)
	var t := _label("Bartender", 76, Color(1.0, 0.88, 0.7))
	t.add_theme_font_override("font", title_font)
	t.add_theme_color_override("font_outline_color", Color(0.45, 0.15, 0.03))
	t.add_theme_constant_override("outline_size", 10)
	v.add_child(t)
	var sub := _label("THE COCKTAIL ACADEMY", 26, C_GOLD)
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	v.add_child(sub)
	v.add_child(_label("Work the bar. Learn real cocktails.", 20, Color(1, 1, 1, 0.85)))
	v.add_child(_label("● %d coins   ·   %d of %d drinks unlocked" % [Save.coins, Save.unlocked, Recipes.DRINKS.size()], 20, C_GOLD))
	v.add_child(_label(_next_unlock_text(), 18, Color(1.0, 0.85, 0.55, 0.85)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	v.add_child(sp)
	v.add_child(_button("START SHIFT  ▶", start_shift, 30))
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 12)
	v.add_child(mrow)
	var bb := _button("BAR BOOK", show_book, 20, Color(0.25, 0.2, 0.3))
	bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(bb)
	var shop_b := _button("SHOP  ● %d" % Save.coins, show_shop, 20, Color(0.55, 0.4, 0.1))
	shop_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(shop_b)
	v.add_child(_button("BARTENDER: %s" % BARTENDERS.get(Save.bartender, BARTENDERS["remy"]).name, show_bartender_pick, 20, Color(0.25, 0.2, 0.3)))
	var mt := "MOCKTAIL MODE: %s" % ("ON" if Save.mocktail else "OFF")
	if Save.mocktail_locked():
		mt += " (under 18)"
	v.add_child(_button(mt, func():
		if Save.mocktail_locked():
			return
		Save.mocktail = not Save.mocktail
		Save.save()
		bar.build_rail()
		show_menu(), 20, Color(0.2, 0.35, 0.25)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	row.add_child(_button("SOUND: %s" % ("ON" if Save.sound else "OFF"), func():
		Audio.set_sound(not Save.sound)
		Audio.loop("crowd", Save.sound, -18.0)
		show_menu(), 18, Color(0.25, 0.2, 0.3)))
	row.add_child(_button("MUSIC: %s" % ("ON" if Save.music else "OFF"), func():
		Audio.set_music(not Save.music)
		show_menu(), 18, Color(0.25, 0.2, 0.3)))
	row.add_child(_button("TV  +50 ●", _watch_tv, 18, Color(0.55, 0.4, 0.1)))
	row.add_child(_button("RATE US", func(): OS.shell_open(STORE_URL), 18, Color(0.25, 0.2, 0.3)))
	# Ad consent choices where the law asks for them, otherwise the privacy policy.
	row.add_child(_button("PRIVACY", func():
		if Ads.privacy_options_required():
			Ads.show_privacy_options()
		else:
			OS.shell_open(PRIVACY_URL), 18, Color(0.25, 0.2, 0.3)))
	var note := _label("A simulation for adults. Fictional brands. Please drink responsibly.", 16, Color(1, 1, 1, 0.55))
	v.add_child(note)


const PRIVACY_URL := "https://vedshubham58-crypto.github.io/bartender/privacy.html"
const STORE_URL := "https://play.google.com/store/apps/details?id=com.vedshubham.bartenderacademy"
## Shifts after which Google's rating card is offered (to everyone, whatever their score).
const REVIEW_AFTER_SHIFTS := [3, 8]


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
			cv.add_child(_label("LOCKED  ·  %s" % d.name, 30, Color(1, 1, 1, 0.45)))
			var more: int = (i - Save.unlocked) / 2 + 1
			cv.add_child(_label("Unlocks after %d more shift%s." % [more, "" if more == 1 else "s"], 18, Color(1, 1, 1, 0.45)))
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
		rt.scroll_active = false
		cv.add_child(rt)
	_let_scroll(v)


## Lets a finger drag anywhere in a scroll list scroll it: only buttons keep the touch.
func _let_scroll(root: Control) -> void:
	for c in root.find_children("*", "Control", true, false):
		if not c is BaseButton:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS


# =============================================================== shift

func start_shift() -> void:
	_close_overlay()
	Ads.show_banner(true)
	var go := func():
		in_shift = true
		shift_left = SHIFT_SECONDS
		shift_stats = {"served": 0, "stars": 0.0, "coins": 0, "perfect": 0, "score": 0, "speedy": 0, "memory": 0, "flawless": 0, "streak": 0, "best_streak": 0}
		# boosts bought in the shop last for this one shift
		boost = Save.boosts.duplicate()
		if not Save.boosts.is_empty():
			Save.boosts = {}
			Save.save()
		hud.visible = true
		_update_coins()
		_set_view("bar", 0.6)
		ticket_panel.visible = false
		for i in guests.size():
			var g: Dictionary = guests[i]
			if g.bubble == null:
				_make_bubble(g)
			g.order = {}
			if not g.waiter and i < 3 and g.get("state", "seated") == "seated":
				_new_order(g, 6.0 * i)
		_clear_actions()
		hint_label.text = "Tap a guest's order to start making it"
		var on := []
		if boost.has("patience"):
			on.append("Happy guests")
		if boost.has("tips"):
			on.append("Big tips")
		if not on.is_empty():
			show_toast("Boost on: %s" % " + ".join(on), C_GOLD, 40)
	go.call()


func _new_order(g: Dictionary, delay := 0.0) -> void:
	var pool: Array = Recipes.DRINKS.slice(0, Save.unlocked)
	var d: Dictionary = pool[randi() % pool.size()]
	if Save.made.is_empty() and shift_stats.served == 0 and guests.find(g) == 0:
		d = Recipes.DRINKS[0]
	elif Save.shifts >= 1 and randf() < 0.3:
		d = Recipes.with_request(d, randi())
	g.order = d
	g.patience = PATIENCE * (1.3 if boost.has("patience") else 1.0) + delay
	if g.waiter:
		g.table = randi_range(2, 9)


func _process(delta: float) -> void:
	time += delta
	_update_tv()
	if pointer:
		pointer.get_child(0).position.y = 0.06 + 0.02 * sin(time * 6.0)
		pointer.get_child(0).rotation.y = time * 2.0
	_update_hands(delta)
	for g in guests:
		if not g.waiter:
			_animate_guest(g, delta)
	if not in_shift:
		if overlay and not _picking:
			# slow drift of the camera behind the menus
			var d: Array = VIEWS["menu"]
			var p: Vector3 = d[0] + Vector3(sin(time * 0.15) * 0.08, 0, 0)
			cam_base = Transform3D(Basis.looking_at(d[1] - p), p)
		_apply_cam()
		return
	_apply_cam()
	if paused:
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
				if not g.waiter and guests_leave and randf() < 0.6:
					_guest_leave(g) # finished: someone new will take the seat
				elif shift_left > 15:
					_new_order(g)
		elif shift_left > 15 and g.get("state", "seated") == "seated" and randf() < delta * (0.06 if g.waiter else 0.12):
			_new_order(g)
	_update_bubbles()
	if pouring:
		var rate := TOP_RATE if cur.step.t == "top" else POUR_RATE
		# timed from the press, so a slow frame never adds a jump of extra ml
		var prev := pour_ml
		pour_ml = rate * (Time.get_ticks_msec() - _pour_t0) / 1000.0
		delta = pour_ml - prev
		delta /= rate
		_update_meter()
		if cur.step.t != "top":
			bar.set_jigger(jigger, pour_ml / maxf(pour_target * 1.5, 30.0), Recipes.SOURCES[pour_src].liquid)
		else:
			_add_to_vessel(rate * delta, Recipes.SOURCES[pour_src].liquid, false)
	if not _float.is_empty():
		_float_tick(delta)
	if not _blend.is_empty() and _blend.on:
		_blend_tick(delta)
	if not _flame.is_empty() and not _flame.done:
		_flame_tick()
	if expecting == "flip" and _flip.get("t", 0.0) < 0.0 and time - _flip.offer > 2.6:
		_skip_flip()
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
	if cur.drink.has("request"):
		ticket_steps.add_child(_label("Guest asks: " + cur.drink.req_note, 19, C_GOLD))
	for k in steps.size():
		var s: Dictionary = steps[k]
		var mark := "✓ " if k < cur.i else ("▶ " if k == cur.i else "○ ")
		var col := C_GREEN if k < cur.i else (Color(1, 0.75, 0.35) if k == cur.i else Color(1, 1, 1, 0.6))
		ticket_steps.add_child(_label(mark + Recipes.step_text(s, _hint_on() or k < cur.i), 19, col))


func _next_step() -> void:
	cur.i += 1
	_hide_pointer()
	_clear_props()
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
			# the right garnish plus three others, in random order
			var opts: Array = Recipes.GARNISH.keys().filter(func(k): return k != s.v)
			opts.shuffle()
			opts = opts.slice(0, 3)
			opts.insert(randi() % 4, s.v)
			_show_pointer(bar.garnish_spots[s.v], Recipes.GARNISH[s.v])
			for k in opts:
				actions.add_child(_button(Recipes.GARNISH[k], _choose.bind("garnish", k), 22, Color(0.2, 0.35, 0.2)))
		"pour", "top", "dash", "layer":
			_set_view("station")
			expecting = "pick"
			expect_src = Recipes.src(s.src)
			var where := "speed rail" if Recipes.SOURCES[expect_src].kind == "rail" else "station"
			hint_label.text = "Tap the glowing %s in the %s" % [Recipes.SOURCES[expect_src].name, where]
			_show_pointer(bar.pickables[expect_src], Recipes.SOURCES[expect_src].name)
		"muddle":
			_set_view("work")
			_taps = 0
			hint_label.text = "Muddle gently: tap 6 times"
			_make_muddler()
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
				tin_node.get_node("Lid").visible = true
				var tw := create_tween()
				tw.set_parallel()
				tw.tween_property(tin_node, "position", SHAKE_SPOT, 0.35).set_trans(Tween.TRANS_SINE)
				tw.tween_property(tin_node, "rotation:z", SHAKE_TILT, 0.35).set_trans(Tween.TRANS_SINE)
			Audio.loop("shake", true, -4.0)
		"stir":
			_set_view("work")
			expecting = "stir"
			progress = 0.0
			progress_bar.visible = true
			progress_bar.value = 0
			hint_label.text = "Stir: draw circles on the screen until it's cold"
			_make_spoon()
		"strain":
			_set_view("work")
			hint_label.text = "Strain it into the glass"
			actions.add_child(_button("STRAIN", _strain, 30))
		"blend":
			_set_view("work")
			_start_blend()
		"flame":
			_set_view("work")
			_start_flame()


func _choose(kind: String, value: String) -> void:
	var s: Dictionary = cur.step
	_clear_actions()
	_hide_pointer()
	if kind == "rim":
		_reach(Bar.GLASS_SPOT + Vector3(0, 0.12, 0.03), 0.45)
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
			# the hand takes the glass from the rack under the bar and sets it on the mat
			glass_node = bar.make_glass(right)
			glass_node.position = Bar.GLASS_SPOT + Vector3(0.05, -0.32, 0.42)
			bar.add_child(glass_node)
			_carry = glass_node
			var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(glass_node, "position", Bar.GLASS_SPOT + Vector3(0.02, 0.12, 0.07), 0.21)
			tw.tween_property(glass_node, "position", Bar.GLASS_SPOT, 0.15)
			await tw.finished
			_carry = null
			if cur.is_empty():
				return
			Audio.play("clink")
			if Recipes.uses_tin(cur.drink):
				tin_node = bar.make_tin()
				bar.skin_tool(tin_node, Save.tool_skin)
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
			# scoop from the ice well, carry it over and tip it in
			var into: Node3D = tin_node if tin_node else glass_node
			var scoop := _make_scoop()
			scoop.position = bar.pickables["ice"] + Vector3(-0.05, 0.02, 0)
			_carry = scoop
			var top: float = 0.18 if into == tin_node else _glass_top()
			var over: Vector3 = into.position + Vector3(0.04, top + 0.08, 0.02)
			var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(scoop, "position:y", scoop.position.y - 0.06, 0.09)
			tw.tween_property(scoop, "position", over, 0.24)
			tw.tween_property(scoop, "rotation:z", 1.6, 0.11)
			await tw.finished
			Audio.play("ice")
			if cur.is_empty():
				scoop.queue_free()
				_carry = null
				return
			_put_ice(into, right)
			await get_tree().create_timer(0.1).timeout
			scoop.queue_free()
			_carry = null
		"garnish":
			# pick it from the garnish tray and drop it on the glass
			var g := bar.garnish(right, bar, bar.garnish_spots[right])
			_carry = g
			var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(g, "position", bar.garnish_spots[right] + Vector3(0, 0.12, 0), 0.15)
			tw.tween_property(g, "position", glass_node.position + Vector3(0, _glass_top() + 0.06, 0), 0.21)
			await tw.finished
			g.queue_free()
			_carry = null
			if cur.is_empty():
				return
			bar.garnish(right, glass_node, Vector3(0, _glass_top(), 0))
	if not cur.is_empty():
		_next_step()


## A glowing ring and bobbing arrow with a name tag over [param at].
func _show_pointer(at: Vector3, label: String) -> void:
	_hide_pointer()
	pointer = Node3D.new()
	pointer.position = at
	bar.add_child(pointer)
	var arrow := Node3D.new()
	pointer.add_child(arrow)
	var glow := bar.emissive(Color(0.35, 1.0, 0.55), 4.0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.022
	cone.bottom_radius = 0.0
	cone.height = 0.045
	bar.add_mesh(cone, glow, Vector3(0, 0.02, 0), arrow)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.042
	ring.outer_radius = 0.05
	bar.add_mesh(ring, glow, Vector3(0, -0.07, 0), pointer)
	var tag := Label3D.new()
	tag.text = label
	tag.font_size = 48
	tag.pixel_size = 0.0011
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = Color(0.75, 1.0, 0.8)
	tag.outline_size = 14
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	tag.position = Vector3(0, 0.1, 0)
	arrow.add_child(tag)


func _hide_pointer() -> void:
	if pointer:
		pointer.queue_free()
		pointer = null


## Ice scoop held by the right hand while scooping.
func _make_scoop() -> Node3D:
	var s := Node3D.new()
	bar.add_child(s)
	var steel := bar.mat(Color(0.86, 0.88, 0.9), 1.0, 0.18)
	bar.cyl(.035, .04, .1, steel, Vector3(0, .02, 0), s, 16)
	var h := bar.cyl(.009, .009, .08, bar.mat(Color(0.07, 0.07, 0.07)), Vector3(-.075, .02, 0), s, 8)
	h.rotation.z = PI / 2
	return s


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
	if not in_shift or paused:
		return
	# touches also arrive as fake mouse events on phones; use the touch ones only
	if e is InputEventMouse:
		return
	var press: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
	var release: bool = (e is InputEventScreenTouch and not e.pressed) or (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
	var drag: bool = e is InputEventScreenDrag or (e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT)
	if press:
		_press_pos = e.position
		_dragged = false
	# swipe to look around, except while a swipe shakes or stirs
	if drag and expecting != "shake" and expecting != "stir" and not pouring:
		if e.position.distance_to(_press_pos) > 14.0:
			_dragged = true
		if _dragged:
			look_yaw = clampf(look_yaw - e.relative.x * 0.0035, -0.75, 0.75)
			look_pitch = clampf(look_pitch - e.relative.y * 0.0035, -0.5, 0.45)
		return
	if release and not _dragged:
		if _tv_hit(e.position):
			_watch_tv()
			return
		if expecting == "pick":
			_tap_pick(e.position)
		return
	if cur.is_empty():
		return
	if expecting == "shake" and (e is InputEventScreenDrag or (e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		var dy: float = e.relative.y
		if absf(dy) > 4:
			var dir := 1 if dy > 0 else -1
			if dir != _last_dir:
				_last_dir = dir
				_shake_step(6.0)
	elif expecting == "stir" and (e is InputEventScreenDrag or (e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		progress += e.relative.length() / 30.0
		progress_bar.value = progress
		if spoon:
			spoon.set_meta("a", spoon.get_meta("a") + e.relative.length() * 0.02)
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
		# tilted with the top toward the right shoulder, pumped along its own axis
		var k := sin(progress * 0.5)
		tin_node.rotation.z = SHAKE_TILT + k * 0.12
		tin_node.position = SHAKE_SPOT + Vector3(0.035 * k, 0.04 * k, 0.015 * cos(progress * 0.5))
	if progress >= 100.0:
		expecting = ""
		Audio.loop("shake", false)
		if tin_node:
			tin_node.position = Bar.TIN_SPOT
			tin_node.rotation = Vector3.ZERO
			tin_node.get_node("Lid").visible = false
		Audio.play("good", -6.0)
		show_toast("Ice cold!", C_GREEN, 44)
		_offer_flip()


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
	_hide_pointer()
	pour_src = best
	_reach(bar.pickables[best], 0.3)
	var s: Dictionary = cur.step
	if s.t == "dash":
		_taps = 0
		hint_label.text = "Tap for each dash: %d" % s.n
		_set_view("work")
		_make_dash_bottle()
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
		hint_label.text = ("Measure it first: " if s.t == "layer" else "") + "Hold to pour, let go on the green line" + ("" if _hint_on() else " (how many ml?)")
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
		_pour_t0 = Time.get_ticks_msec()
		pour_ml = 0.0
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
	if pour_bottle:
		pour_bottle.queue_free()
		pour_bottle = null
	if cur.step.t == "layer":
		_start_float(pour_ml, Recipes.SOURCES[pour_src].liquid)
		return
	if cur.step.t != "top":
		# pick up the jigger, tip it into the tin or glass, put it back
		var into: Node3D = tin_node if tin_node else glass_node
		var top: float = 0.18 if into == tin_node else _glass_top()
		_carry = jigger
		var col: Color = Recipes.SOURCES[pour_src].liquid
		var ml := pour_ml
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(jigger, "position", into.position + Vector3(0.05, top + 0.05, 0.00), 0.18)
		tw.tween_property(jigger, "rotation:z", 2.0, 0.11)
		tw.tween_callback(func():
			bar.set_jigger(jigger, 0, Color.WHITE)
			if not cur.is_empty():
				_add_to_vessel(ml, col, true))
		tw.tween_interval(0.15)
		tw.tween_property(jigger, "rotation:z", 0.0, 0.09)
		tw.tween_property(jigger, "position", Bar.JIGGER_SPOT, 0.15)
		await tw.finished
		_carry = null
	else:
		await get_tree().create_timer(0.3).timeout
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
	if tin_node:
		bar.set_fill(tin_node, cur.vol / 450.0, c)
	elif glass_node:
		var cap: float = Recipes.GLASSES[glass_node.get_meta("kind")].ml
		bar.set_fill(glass_node, _fill_look(cur.vol / cap), c)


## Small pours look like nothing in a tall glass, so the level shows a bit higher.
func _fill_look(f: float) -> float:
	return minf(0.92, f * 1.6 + (0.06 if f > 0 else 0.0))


func _muddle() -> void:
	_taps += 1
	if muddler:
		var tw := create_tween()
		tw.tween_property(muddler, "position:y", muddler.get_meta("y0") - 0.03, 0.08)
		tw.tween_property(muddler, "position:y", muddler.get_meta("y0"), 0.12)
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
	if dash_bottle:
		var tw := create_tween()
		tw.tween_property(dash_bottle, "rotation:z", 2.4, 0.07)
		tw.tween_property(dash_bottle, "rotation:z", 1.9, 0.12)
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
	_straining = true
	var tw := create_tween()
	var over := glass_node.position + Vector3(0.09, _glass_top() + 0.12, 0)
	tw.tween_property(tin_node, "position", over, 0.21)
	tw.parallel().tween_property(tin_node, "rotation:z", 1.9, 0.21)
	Audio.play("pour", -8.0)
	tw.tween_callback(func():
		var cap: float = Recipes.GLASSES[glass_node.get_meta("kind")].ml
		var fill_to: float = _fill_look(cur.vol * 1.1 / cap)
		bar.set_fill(tin_node, 0.0, cur.color)
		var t2 := create_tween()
		t2.tween_method(func(f): bar.set_fill(glass_node, f, cur.color), 0.0, fill_to, 0.36))
	tw.tween_interval(0.7)
	tw.tween_property(tin_node, "rotation:z", 0.0, 0.18)
	tw.parallel().tween_property(tin_node, "position", Bar.TIN_SPOT, 0.18)
	tw.tween_callback(func():
		_straining = false
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
	var mood: float = clampf(g.patience / (PATIENCE * (1.3 if boost.has("patience") else 1.0)), 0.0, 1.0)
	var tip: int = int(round(d.price * (0.5 + 0.5 * stars / 3.0) * (0.75 + 0.25 * mood))) + cur.perfect * 5 + (10 if secs < 35 else 0)
	# little wins for this drink, shown under the stars and counted on the score card
	var badges := []
	var score: int = int(stars * 100) + cur.perfect * 25
	if secs < 30.0:
		badges.append("SPEEDY")
		shift_stats.speedy += 1
		score += 50
	if cur.perfect > 0 and cur.perfect == cur.errs.size():
		badges.append("PERFECT POUR" + ("S" if cur.perfect > 1 else ""))
	if not _hint_on() and cur.mistakes == 0:
		badges.append("FROM MEMORY")
		shift_stats.memory += 1
		score += 50
	if stars >= 3.0:
		shift_stats.flawless += 1
		shift_stats.streak += 1
		shift_stats.best_streak = maxi(shift_stats.best_streak, shift_stats.streak)
		if shift_stats.streak >= 2:
			badges.append("x%d STREAK" % shift_stats.streak)
			tip += 5 * shift_stats.streak
			score += 30 * shift_stats.streak
	else:
		shift_stats.streak = 0
	if cur.get("flair", false):
		badges.append("FLAIR")
		tip += 8
		score += 40
	if d.has("request") and stars >= 2.5:
		badges.append("JUST HOW THEY LIKE IT")
		tip += 10
		score += 40
	if boost.has("tips"):
		tip = int(round(tip * 1.5))
	Save.coins += tip
	Save.record(d.id, stars)
	Save.save()
	shift_stats.served += 1
	shift_stats.stars += stars
	shift_stats.coins += tip
	shift_stats.perfect += cur.perfect
	shift_stats.score += score
	_update_coins()
	var dest: Vector3 = g.node.get_meta("tray") if g.waiter else Vector3(g.x - .16, Bar.BT + .008, Bar.BZ1 + .2)
	var gl := glass_node
	glass_node = null
	Audio.play("slide")
	var tw := create_tween()
	_serving = gl
	tw.tween_property(gl, "position", dest, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_serving = null
		Audio.play("tip")
		var line := "%s   +%d" % ["★".repeat(int(floor(stars))) + ("½" if fmod(stars, 1.0) >= 0.5 else ""), tip]
		if not badges.is_empty():
			line += "\n" + "  ·  ".join(badges)
		show_toast(line, C_GOLD, 52 if badges.is_empty() else 44))
	g.order = {}
	g.served = gl
	g.drink_t = 4.0 if g.waiter else randf_range(12.0, 18.0)
	if not g.waiter:
		var cap: float = Recipes.GLASSES[gl.get_meta("kind")].ml
		g.fill = _fill_look(cur.vol / cap)
		g.color = cur.color
		g.react = "cheer" if stars >= 2.5 else ("sip" if stars >= 1.5 else "meh")
		g.react_t = 0.0
		g.sip_next = 3.2
		get_tree().create_timer(0.7).timeout.connect(_guest_says.bind(g, _reaction_line(stars, d)))
	_end_drink(true)


# =============================================================== guests come alive

const LINES_GREAT := ["Wow, perfect!", "Best %s ever!", "Now that's a %s!", "You're a pro!", "Cheers to you!"]
const LINES_GOOD := ["Nice, thanks!", "Mmm, good!", "Thank you!", "Lovely."]
const LINES_MEH := ["Hmm... okay.", "Not quite right.", "Bit off, but thanks."]


func _reaction_line(stars: float, d: Dictionary) -> String:
	var pool: Array = LINES_GREAT if stars >= 2.5 else (LINES_GOOD if stars >= 1.5 else LINES_MEH)
	var l: String = pool[randi() % pool.size()]
	return l % Recipes.drink_name(d) if "%s" in l else l


## A short line floating over a guest's head (what they say when served).
func _guest_says(g: Dictionary, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.pixel_size = 0.0015
	l.outline_size = 14
	l.modulate = Color(1.0, 0.95, 0.8)
	l.outline_modulate = Color(0.12, 0.06, 0.1, 0.9)
	bar.add_child(l)
	l.global_position = _head_pos(g) + Vector3(0, 0.2, 0.05)
	var tw := create_tween()
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 0.12, 0), 2.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.6)
	tw.tween_callback(l.queue_free)


## Guests aren't statues: they watch you make their drink, get restless when it takes too
## long, cheer and sip when it arrives, and glance around the bar the rest of the time.
func _animate_guest(g: Dictionary, delta: float) -> void:
	if g.get("state", "seated") != "seated":
		_animate_walk(g, delta)
		return
	var n: Node3D = g.node
	People.idle(n, time, g.phase)
	var s := People.skel(n)
	var t: float = time + g.phase * 3.0
	var head := _head_pos(g)
	var fwd := People.local_dir(n, Vector3(0, 0, 1))
	var mine: bool = not cur.is_empty() and guests.find(g) == cur.get("guest", -1)
	# --- where to look
	var look: Vector3 = head + fwd * 2.0
	var amount := 0.0
	if mine or not g.order.is_empty():
		look = cam.global_position # watching the bartender
		amount = 0.9 if mine else 0.6
	elif g.served != null and g.get("react", "") != "":
		look = g.served.global_position
		amount = 0.5
	else:
		# glance at the neighbour, the city, then back to the bar
		var k: int = int(t / 4.0) % 4
		var side: float = 1.0 if k == 1 else (-1.0 if k == 3 else 0.0)
		look = head + fwd * 2.0 + fwd.cross(Vector3.UP) * side * 2.5 + Vector3(0, -0.3 if k == 0 else 0.2, 0)
		amount = 0.0 if k == 0 else 0.8
	var cur_look: Vector3 = g.get("look", look)
	cur_look = cur_look.lerp(look, 1.0 - exp(-delta * 4.0))
	g.look = cur_look
	g.look_amt = lerpf(float(g.get("look_amt", 0.0)), amount, 1.0 - exp(-delta * 3.0))
	# --- arms: both rest on the bar, then the right one does something
	var targets := {"Right": Vector3(g.x - .12, Bar.BT + .07, Bar.BZ1 + .2)} # resting by the glass spot
	var react: String = g.get("react", "")
	var gl: Node3D = g.served
	if gl != null and react != "" and gl != _serving:
		if not g.has("rest") or g.get("rest_of") != gl:
			g.rest = gl.global_position
			g.rest_of = gl
		g.react_t = float(g.get("react_t", 0.0)) + delta
		var rest: Vector3 = g.rest
		var mouth := head + fwd * 0.12 + Vector3(0, -0.2, 0)
		var want := rest
		var tilt := 0.0
		if react == "cheer" and g.react_t < 2.2:
			# raise the glass: "cheers!"
			var up: float = sin(clampf(g.react_t / 2.2, 0.0, 1.0) * PI)
			want = rest.lerp(head + fwd * 0.3 + Vector3(0.05, 0.12, 0), up)
		else:
			g.sip_next -= delta
			if g.sip_next < 0.0:
				var k: float = clampf(-g.sip_next / 1.8, 0.0, 1.0) # 1.8 s sip
				var up: float = sin(k * PI)
				want = rest.lerp(mouth, up)
				tilt = -0.7 * up
				if k >= 1.0:
					g.sip_next = randf_range(4.0, 7.0)
					g.fill = maxf(0.1, g.get("fill", 0.6) - 0.15)
					bar.set_fill(gl, g.fill, g.get("color", Color(0.8, 0.5, 0.2)))
					bar.set_layer(gl, 0.0, 0.0, Color.WHITE)
				amount = 0.0
				g.look_amt = lerpf(g.look_amt, 0.0, 0.3)
		gl.global_position = want
		gl.rotation.x = tilt
		# right hand around the glass, on the guest's side of it
		targets["Right"] = want + Vector3(0.02, 0.06, -0.045)
	elif not g.order.is_empty() and g.patience < 40.0:
		# impatient: drum the fingers on the bar
		var tap: float = absf(sin(t * 11.0)) * 0.035 * (1.0 if fmod(t, 3.0) < 1.6 else 0.0)
		targets["Right"] = Vector3(g.x - 0.05, Bar.BT + 0.035 + tap, Bar.BZ1 + 0.24)
	People.arms_on_bar(n, Bar.BT, Bar.BZ1, g.x, targets)
	if targets.has("Right") and gl != null and react != "":
		People.reach(s, "Right", targets["Right"], Vector3(0.5, -1, -0.4))
		People.grip(s, "Right", 0.55)
	People.look_at_point(n, g.look, g.look_amt)


## Who can come in and sit at the bar.
const GUEST_MODELS := ["kate", "david", "megan", "leonard", "louise"]
const WALK_SPEED := 1.05
var guests_leave := true ## tests that need the same four guests switch this off


func _guest_leave(g: Dictionary) -> void:
	g.state = "standing"
	g.walk_t = 0.0
	g.react = ""
	g.order = {}


## Standing up, walking away, the seat staying empty a moment, someone new walking in
## and sitting down. Legs and arms are swung in code like the rest of the poses.
func _animate_walk(g: Dictionary, delta: float) -> void:
	var n: Node3D = g.node
	g.walk_t = float(g.get("walk_t", 0.0)) + delta
	var t: float = g.walk_t
	var seat := Vector3(g.x, 0, Bar.SEAT_Z)
	var away := Vector3(g.x * 1.6 + 0.4, 0, -5.2)
	match g.state:
		"standing": # 0.7 s: stand up, then turn away from the bar
			var k := clampf(t / 0.7, 0.0, 1.0)
			_pose_legs(n, k, 0.0)
			n.rotation.y = lerp_angle(g.get("seat_rot", n.rotation.y), PI, smoothstep(0.3, 1.0, k))
			_place_body(n, seat - Vector3(0, 0, 0.12 * k), k)
			People.arms_down(n)
			if k >= 1.0:
				g.state = "leaving"
				g.walk_t = 0.0
		"leaving":
			var d := seat.distance_to(away)
			var k := clampf(t * WALK_SPEED / d, 0.0, 1.0)
			var p := (seat - Vector3(0, 0, 0.12)).lerp(away, k)
			n.rotation.y = atan2(away.x - seat.x, away.z - seat.z)
			_pose_legs(n, 1.0, t * 7.0)
			_place_body(n, p, 1.0)
			if k >= 1.0:
				g.model = n.get_meta("model", "")
				n.queue_free()
				g.node = null
				g.state = "away"
				g.walk_t = 0.0
				g.wait = randf_range(2.5, 6.0)
		"away":
			if t >= g.get("wait", 3.0) and in_shift:
				var models := GUEST_MODELS.duplicate()
				models.erase(g.get("model", ""))
				var m: String = models[randi() % models.size()]
				var nn := People.spawn(m, bar)
				nn.set_meta("model", m)
				People.set_height(nn, randf_range(1.66, 1.8))
				g.node = nn
				g.erase("look")
				g.look_amt = 0.0
				g.state = "arriving"
				g.walk_t = 0.0
		"arriving":
			var d := away.distance_to(seat)
			var k := clampf(t * WALK_SPEED / d, 0.0, 1.0)
			var p := away.lerp(seat - Vector3(0, 0, 0.12), k)
			n.rotation.y = atan2(seat.x - away.x, seat.z - away.z)
			_pose_legs(n, 1.0, t * 7.0)
			_place_body(n, p, 1.0)
			if k >= 1.0:
				g.state = "sitting"
				g.walk_t = 0.0
		"sitting": # 0.7 s: turn to the bar and sit down
			var k := clampf(t / 0.7, 0.0, 1.0)
			n.rotation.y = lerp_angle(n.rotation.y, 0.0, smoothstep(0.0, 0.6, k))
			_pose_legs(n, 1.0 - k, 0.0)
			_place_body(n, seat - Vector3(0, 0, 0.12 * (1.0 - k)), 1.0 - k)
			People.arms_down(n)
			if k >= 1.0:
				People.sit_legs(n)
				People.lean(n)
				People.place_hips(n, Vector3(g.x, 0.9, Bar.SEAT_Z))
				g.seat_rot = n.rotation.y
				g.state = "seated"
				if in_shift and shift_left > 15:
					_new_order(g, 2.0)
				_animate_guest(g, 0.0)
				return
	if g.state != "away" and g.node != null:
		People.idle(g.node, time, g.phase)


## Legs from sitting (0) to standing (1); [param swing] > 0 swings them in a walk.
func _pose_legs(n: Node3D, stand: float, swing: float) -> void:
	var s := People.skel(n)
	var w := sin(swing) * 0.38 if swing > 0.0 else 0.0
	for side in ["Left", "Right"]:
		var o := 1.0 if side == "Left" else -1.0
		var ws := w * o
		var sit_up := Vector3(.12 * o, -.15, 1)
		var walk_up := Vector3(0.03 * o, -1, ws)
		var sit_low := Vector3(0, -1, .1)
		var walk_low := Vector3(0, -1, minf(ws, 0.0) * 1.3 + 0.05)
		People.aim(s, side + "UpLeg", side + "Leg", People.local_dir(n, sit_up.lerp(walk_up, stand)))
		People.aim(s, side + "Leg", side + "Foot", People.local_dir(n, sit_low.lerp(walk_low, stand)))
		# arms swing the other way to the legs
		if swing > 0.0:
			People.aim(s, side + "Arm", side + "ForeArm", People.local_dir(n, Vector3(.12 * o, -1, -ws * 0.6)))
			People.aim(s, side + "ForeArm", side + "Hand", People.local_dir(n, Vector3(.05 * o, -1, 0.25 - ws * 0.4)))
	People.aim(s, "Spine", "Spine1", People.local_dir(n, Vector3(0, 1, lerpf(0.28, 0.04, stand))))


## Puts the body over [param p] (floor point): seated hips on the stool, standing feet on the floor.
func _place_body(n: Node3D, p: Vector3, stand: float) -> void:
	var s := People.skel(n)
	var hips := People.world_pos(s, "Hips")
	var foot := minf(People.world_pos(s, "LeftToeBase").y, People.world_pos(s, "RightToeBase").y)
	var stand_y := hips.y - foot + 0.01
	var y := lerpf(0.9, stand_y, stand)
	n.global_position += Vector3(p.x, y, p.z) - hips


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
	_clear_props()
	_clear_techniques()
	cur = {}
	if hud:
		ticket_panel.visible = false
		meter.visible = false
		_clear_actions()
		hint_label.text = "Tap a guest's order to start making it" if in_shift else ""


func _end_shift() -> void:
	in_shift = false
	_end_drink(false)
	hud.visible = false
	Ads.show_interstitial(_shift_summary)


func _shift_summary() -> void:
	Ads.show_banner()
	# after the first shift (not at launch) ask once if we may send daily reminders
	if not Save.asked_notify:
		Save.asked_notify = true
		Ads.ask_notifications()
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
		var names := []
		for k in 2:
			if Save.unlocked < Recipes.DRINKS.size():
				Save.unlocked += 1
				names.append(Recipes.drink_name(Recipes.DRINKS[Save.unlocked - 1]))
		unlocked = " & ".join(names)
	var new_best: bool = shift_stats.score > Save.best_score and shift_stats.score > 0
	if new_best:
		Save.best_score = shift_stats.score
	Save.save()
	hud.visible = false
	if unlocked != "":
		_unlock_celebration(unlocked, _score_card.bind(unlocked, new_best))
	else:
		_score_card(unlocked, new_best)


## Shows the shift's score card (after any unlock celebration).
func _score_card(unlocked: String, new_best: bool) -> void:
	var v := _center_box(_overlay(), 760)
	v.add_theme_constant_override("separation", 8)
	var avg: float = shift_stats.stars / maxf(1, shift_stats.served)
	# grade from the average stars and how many drinks went out
	var grade := "C"
	if shift_stats.served >= 3 and avg >= 2.8:
		grade = "S"
	elif shift_stats.served >= 2 and avg >= 2.4:
		grade = "A"
	elif shift_stats.served >= 1 and avg >= 1.8:
		grade = "B"
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 24)
	v.add_child(head)
	var g := _label(grade, 96, {"S": Color(1.0, 0.8, 0.3), "A": C_GREEN, "B": Color(0.6, 0.8, 1.0), "C": Color(1, 1, 1, 0.8)}[grade])
	g.add_theme_font_override("font", title_font)
	g.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	g.add_theme_constant_override("outline_size", 10)
	head.add_child(g)
	var hv := VBoxContainer.new()
	head.add_child(hv)
	hv.add_child(_label("SHIFT SCORE CARD", 26, C_GOLD))
	var score_l := _label("0", 56, Color.WHITE)
	hv.add_child(score_l)
	var tw := create_tween()
	tw.tween_method(func(x: float): if is_instance_valid(score_l): score_l.text = "%d" % int(x), 0.0, float(shift_stats.score), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var best_l := _label("NEW BEST!" if new_best else "Best: %d" % Save.best_score, 22, C_GREEN if new_best else Color(1, 1, 1, 0.6))
	hv.add_child(best_l)
	if new_best:
		best_l.pivot_offset = Vector2(60, 14)
		var pulse := create_tween().set_loops(4)
		pulse.tween_property(best_l, "scale", Vector2(1.2, 1.2), 0.25)
		pulse.tween_property(best_l, "scale", Vector2.ONE, 0.25)
		Audio.play("good", -4.0)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 40)
	v.add_child(stats)
	for pair in [
		["Drinks served", "%d" % shift_stats.served],
		["Average", "%.1f ★" % avg],
		["Perfect pours", "%d" % shift_stats.perfect],
		["Speedy drinks", "%d" % shift_stats.speedy],
		["From memory", "%d" % shift_stats.memory],
		["Best 3-star streak", "%d" % shift_stats.best_streak],
		["Tips", "● %d" % shift_stats.coins],
	]:
		stats.add_child(_label(pair[0], 22, Color(1, 1, 1, 0.75)))
		var val := _label(pair[1], 22, C_GOLD)
		stats.add_child(val)
	if unlocked != "":
		var u := _label("New recipes unlocked: %s" % unlocked, 26, C_GREEN)
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(u)
	var nxt := _next_unlock_text()
	if nxt != "":
		var n := _label(nxt, 22, Color(1.0, 0.85, 0.55))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
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
	# a finished shift is a good moment for Google's rating card, a couple of times only
	if Save.shifts in REVIEW_AFTER_SHIFTS and not Save.review_asked.has(Save.shifts):
		Save.review_asked.append(Save.shifts)
		Save.save()
		get_tree().create_timer(1.6).timeout.connect(Ads.request_review)


## "Next shift unlocks: X & Y", the reason to play one more.
func _next_unlock_text() -> String:
	if Save.unlocked >= Recipes.DRINKS.size():
		return "You've unlocked every cocktail. Master them all!"
	var names := []
	for i in range(Save.unlocked, mini(Save.unlocked + 2, Recipes.DRINKS.size())):
		names.append(Recipes.drink_name(Recipes.DRINKS[i]))
	return "Next shift unlocks: %s" % " & ".join(names)


## A big "NEW COCKTAIL UNLOCKED!" moment with confetti, then [param done].
func _unlock_celebration(names: String, done: Callable) -> void:
	var o := _overlay()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.02, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(bg)
	var vp := get_viewport().get_visible_rect().size
	for side in [0.25, 0.75]:
		var c := CPUParticles2D.new()
		c.position = Vector2(vp.x * side, -20)
		c.amount = 90
		c.lifetime = 3.0
		c.one_shot = false
		c.explosiveness = 0.15
		c.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		c.emission_rect_extents = Vector2(vp.x * 0.25, 10)
		c.direction = Vector2(0, 1)
		c.spread = 25.0
		c.gravity = Vector2(0, 260)
		c.initial_velocity_min = 80.0
		c.initial_velocity_max = 220.0
		c.angular_velocity_min = -300.0
		c.angular_velocity_max = 300.0
		c.scale_amount_min = 6.0
		c.scale_amount_max = 11.0
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
		gr.colors = PackedColorArray([Color(1.0, 0.8, 0.3), Color(1.0, 0.4, 0.6), Color(0.4, 0.85, 1.0), Color(0.5, 1.0, 0.6)])
		c.color_initial_ramp = gr
		o.add_child(c)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(cc)
	cc.add_child(v)
	var badge := _label("★  ACHIEVEMENT  ★", 26, C_GOLD)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(badge)
	var t := _label("NEW COCKTAILS UNLOCKED!" if " & " in names else "NEW COCKTAIL UNLOCKED!", 58, Color.WHITE)
	t.add_theme_font_override("font", title_font)
	t.add_theme_color_override("font_outline_color", Color(0.45, 0.15, 0.03))
	t.add_theme_constant_override("outline_size", 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var n := _label(names, 40, C_GREEN)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var info := _label("%d of %d cocktails in your Bar Book" % [Save.unlocked, Recipes.DRINKS.size()], 22, Color(1, 1, 1, 0.75))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var b := _button("AWESOME!  ▶", done, 30)
	b.custom_minimum_size = Vector2(360, 0)
	var bc := CenterContainer.new()
	bc.add_child(b)
	v.add_child(bc)
	# pop in
	v.pivot_offset = Vector2(400, 150)
	v.scale = Vector2(0.6, 0.6)
	v.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(v, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "modulate:a", 1.0, 0.25)
	Audio.play("good", -2.0)


# =============================================================== shop

const SHOP := [
	["unlock", "Unlock 2 cocktails now", "Skip ahead: the next 2 recipes open right away.", 400],
	["boost_patience", "Happy guests", "Guests wait 30% longer, for your next shift.", 120],
	["boost_tips", "Big tips", "+50% tips, for your next shift.", 150],
	["tools_copper", "Copper tools", "A copper shaker and jigger.", 300],
	["tools_gold", "Gold tools", "A shining gold shaker and jigger.", 900],
	["tools_black", "Black tools", "Matte black, the pro bartender look.", 600],
	["lights_blue", "Blue neon lights", "Cool blue lamps over your bar.", 500],
	["lights_pink", "Pink neon lights", "Party pink lamps over your bar.", 500],
	["lights_gold", "Royal gold lights", "Rich golden lamps over your bar.", 800],
	["tools_steel", "Steel tools", "The classic look.", 0],
	["lights_warm", "Warm lights", "The classic cosy glow.", 0],
]


func show_shop() -> void:
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
	sc.offset_bottom = -60
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	sc.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(_label("SHOP", 48, C_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(_label("● %d   " % Save.coins, 34, C_GOLD))
	top.add_child(_button("Close", show_menu, 22, Color(0.3, 0.25, 0.35)))
	v.add_child(top)
	v.add_child(_label("Spend your tips. Earn more by serving fast, perfect drinks.", 20, Color(1, 1, 1, 0.7)))
	for it in SHOP:
		var id: String = it[0]
		if id == "unlock" and Save.unlocked >= Recipes.DRINKS.size():
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _panel(Color(0.12, 0.08, 0.07, 0.95), 16))
		v.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		card.add_child(h)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(_label(it[1], 28, Color.WHITE))
		tv.add_child(_label(it[2], 18, Color(1, 1, 1, 0.7)))
		var state := _shop_state(id)
		var b: Button
		if state == "using":
			b = _button("IN USE ✓", func(): pass, 22, Color(0.2, 0.45, 0.3))
			b.disabled = true
		elif state == "owned":
			b = _button("USE", _shop_use.bind(id), 22, Color(0.25, 0.4, 0.55))
		elif state == "queued":
			b = _button("READY ✓", func(): pass, 22, Color(0.2, 0.45, 0.3))
			b.disabled = true
		else:
			var price: int = it[3]
			b = _button("● %d" % price, _shop_buy.bind(id, price), 24, Color(1.0, 0.55, 0.25) if Save.coins >= price else Color(0.3, 0.27, 0.3))
		b.custom_minimum_size = Vector2(170, 0)
		h.add_child(b)
	_let_scroll(v)


func _shop_state(id: String) -> String:
	if id.begins_with("tools_"):
		if Save.tool_skin == id.substr(6):
			return "using"
		return "owned" if id in Save.owned else "buy"
	if id.begins_with("lights_"):
		if Save.light_theme == id.substr(7):
			return "using"
		return "owned" if id in Save.owned else "buy"
	if id.begins_with("boost_") and Save.boosts.has(id.substr(6)):
		return "queued"
	return "buy"


func _shop_buy(id: String, price: int) -> void:
	if Save.coins < price:
		show_toast("Not enough coins yet. Play a shift!", Color(1, 1, 1), 34)
		return
	Save.coins -= price
	if id == "unlock":
		var names := []
		for k in 2:
			if Save.unlocked < Recipes.DRINKS.size():
				Save.unlocked += 1
				names.append(Recipes.drink_name(Recipes.DRINKS[Save.unlocked - 1]))
		Save.save()
		_unlock_celebration(" & ".join(names), show_shop)
		return
	if id.begins_with("boost_"):
		Save.boosts[id.substr(6)] = true
		show_toast("Ready for your next shift!", C_GOLD, 40)
	else:
		Save.owned.append(id)
		_shop_use(id)
	Audio.play("good", -6.0)
	Save.save()
	show_shop()


func _shop_use(id: String) -> void:
	if id.begins_with("tools_"):
		Save.tool_skin = id.substr(6)
		bar.skin_tool(jigger, Save.tool_skin)
		if tin_node:
			bar.skin_tool(tin_node, Save.tool_skin)
	elif id.begins_with("lights_"):
		Save.light_theme = id.substr(7)
		bar.set_light_theme(Save.light_theme)
	Save.save()
	show_shop()


func pause_shift() -> void:
	if not in_shift or paused:
		return
	paused = true
	pouring = false
	Audio.loop("pour", false)
	Audio.loop("shake", false)
	hud.visible = false
	var v := _center_box(_overlay(), 520)
	var t := _label("PAUSED", 52, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("RESUME  ▶", _resume_shift, 32))
	v.add_child(_button("Quit to menu", func():
		paused = false
		_end_drink(false)
		for g in guests:
			g.order = {}
			if g.bubble:
				g.bubble.visible = false
		show_menu(), 22, Color(0.25, 0.2, 0.3)))
	# a full-screen ad when pausing, at most every 2 minutes
	if time - _last_pause_ad > 120.0:
		_last_pause_ad = time
		Ads.show_interstitial(func(): pass)


func _resume_shift() -> void:
	_close_overlay()
	paused = false
	hud.visible = true


# =============================================================== TV

## The TV runs a non-stop ad reel: our own promos, tonight's special and the
## tap-for-coins video offer. (AdMob does not allow its real ads inside a 3D scene,
## so paid ads show as the banner, the between-shift ads and the TV reward video.)
const TV_SLIDES := [
	["▶ TAP THE TV ◀\nWatch a short video, get ● 50", Color(0.55, 0.32, 0.02), Color(1.0, 0.95, 0.7)],
	["TONIGHT'S SPECIAL\n%s", Color(0.32, 0.06, 0.12), Color(1.0, 0.85, 0.75)],
	["NEON RUSH\nRide light bikes, grab the city!\nComing soon on Google Play", Color(0.05, 0.12, 0.4), Color(0.6, 0.95, 1.0)],
	["HAPPY HOUR\nServe 3 in a row for a streak bonus", Color(0.45, 0.12, 0.3), Color(1.0, 0.8, 0.95)],
	["SCANMINT\nScan documents to PDF in one tap\nComing soon on Google Play", Color(0.03, 0.3, 0.2), Color(0.75, 1.0, 0.85)],
	["DID YOU KNOW?\nShake drinks with juice, stir drinks that are all spirits", Color(0.1, 0.1, 0.2), Color(1.0, 0.92, 0.75)],
	["BARTENDER\nThe Cocktail Academy", Color(0.25, 0.12, 0.04), Color(1.0, 0.85, 0.5)],
]
var _tv_screen_mat: StandardMaterial3D


func _update_tv() -> void:
	if tv_text == null or time < _tv_next:
		return
	_tv_next = time + 4.0
	_tv_slide = (_tv_slide + 1) % TV_SLIDES.size()
	var sl: Array = TV_SLIDES[_tv_slide]
	var t: String = sl[0]
	if "%s" in t:
		var pool: Array = Recipes.DRINKS.slice(0, maxi(1, Save.unlocked))
		t = t % Recipes.drink_name(pool[int(time / 60.0) % pool.size()])
	tv_text.text = t
	tv_text.modulate = sl[2]
	if _tv_screen_mat == null:
		var scr: MeshInstance3D = tv_text.get_parent().get_node_or_null("Screen")
		if scr:
			_tv_screen_mat = scr.material_override
	if _tv_screen_mat:
		_tv_screen_mat.emission = sl[1]
	# a quick flash so the change catches the eye
	tv_text.scale = Vector3(0.9, 0.9, 0.9)
	create_tween().tween_property(tv_text, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tv_hit(p: Vector2) -> bool:
	if tv_text == null:
		return false
	var c := tv_text.global_position
	if cam.is_position_behind(c):
		return false
	var a := cam.unproject_position(c + Vector3(-0.64, 0.36, 0))
	var b := cam.unproject_position(c + Vector3(0.64, -0.36, 0))
	return Rect2(a, b - a).abs().has_point(p)


func _watch_tv() -> void:
	if time - _tv_reward_at < 60.0:
		show_toast("The TV has a new video in a minute", Color(1, 1, 1), 34)
		return
	if not Ads.rewarded_ready():
		show_toast("No video right now, try again soon", Color(1, 1, 1), 34)
		return
	_tv_reward_at = time
	Ads.show_rewarded(func():
		Save.coins += 50
		Save.save()
		_update_coins()
		show_toast("+50 coins from the TV!", C_GOLD))


func _double_tips(btn: Button) -> void:
	btn.disabled = true
	Ads.show_rewarded(func():
		Save.coins += shift_stats.coins
		shift_stats.coins *= 2
		Save.save()
		show_toast("Tips doubled!", C_GOLD)
		btn.text = "Tips doubled: ● %d" % shift_stats.coins)


# =============================================================== bartender body + hands

func set_bartender(model: String) -> void:
	if me:
		me.free_body()
	me = FirstPerson.new(model, bar)
	if host:
		host.queue_free()
	# on the menu you see your bartender behind the bar, turned toward you
	host = People.spawn(model, bar)
	People.self_lit(host, 1.25)
	People.set_height(host, 1.76 if model == "remy" else 1.68)
	People.arms_down(host)
	# the camera looks toward +z, so screen-right is -x: stand right of the menu
	host.rotation.y = PI - 0.4
	People.place_standing(host, -0.6, 0.1)
	# a soft key light so your bartender reads well on the menu (only on while not in a shift)
	var key := SpotLight3D.new()
	key.name = "HostLight"
	key.light_color = Color(1.0, 0.85, 0.7)
	key.light_energy = 3.0
	key.spot_range = 3.0
	key.spot_angle = 22.0
	host.add_child(key)
	key.look_at_from_position(Vector3(0.1, 2.3, -0.9), Vector3(-0.6, 1.45, 0.1))
	host.visible = not in_shift


func _reach(p: Vector3, secs := 0.4) -> void:
	_reach_pos = p
	_reach_until = time + secs


func _clear_props() -> void:
	for n in [spoon, muddler, dash_bottle]:
		if n:
			n.queue_free()
	spoon = null
	muddler = null
	dash_bottle = null
	_straining = false


func _make_spoon() -> void:
	if glass_node == null:
		return
	var vessel: Node3D = tin_node if tin_node else glass_node
	spoon = Node3D.new()
	bar.add_child(spoon)
	spoon.set_meta("a", 0.0)
	spoon.set_meta("c", vessel.position)
	var steel := bar.mat(Color(0.85, 0.86, 0.88), 1.0, 0.2)
	var shaft := bar.cyl(.0025, .0025, .24, steel, Vector3(0, .12, 0), spoon, 8)
	shaft.rotation.z = 0
	var bowl := bar.sphere(.009, steel, Vector3(0, .004, 0), spoon)
	bowl.scale = Vector3(1, .4, 1.6)
	bar.sphere(.006, steel, Vector3(0, .24, 0), spoon)


func _make_muddler() -> void:
	if glass_node == null:
		return
	muddler = Node3D.new()
	bar.add_child(muddler)
	var wood := bar.mat(Color(0.62, 0.45, 0.28), 0.0, 0.6)
	bar.cyl(.012, .016, .22, wood, Vector3(0, .11, 0), muddler, 12)
	muddler.position = glass_node.position + Vector3(0, .02, 0)
	muddler.rotation.z = 0.12
	muddler.set_meta("y0", muddler.position.y)


func _make_dash_bottle() -> void:
	if glass_node == null:
		return
	dash_bottle = bar.bottle(pour_src, Vector3.ZERO, bar, false, .022, .13)
	dash_bottle.position = glass_node.position + Vector3(.1, _glass_top() + .1, 0)
	dash_bottle.rotation.z = 1.9


func _update_hands(delta: float) -> void:
	if me == null:
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var r := Vector3.INF
	var l := Vector3.INF
	var rg := 0.25
	var lg := 0.25
	var rd := Vector3.ZERO
	var ld := Vector3.ZERO
	var rt := Vector3.UP
	var lt := Vector3.UP
	# hidden while picking a bottle, so the body never covers the speed rail
	me.node.visible = in_shift and expecting != "pick"
	if host:
		host.visible = not in_shift and not _picking
	if in_shift and not cur.is_empty():
		if _carry:
			r = _carry.global_position + Vector3(0, 0.05, 0) - fwd * 0.045
			rg = 0.8
			rd = fwd
			rt = Vector3.UP
		elif _serving:
			r = _serving.position + Vector3(0.02, 0.07, 0.05)
			rg = 0.45
			rd = fwd
			rt = -right
		elif pour_bottle:
			var axis: Vector3 = pour_bottle.global_transform.basis.y
			r = pour_bottle.to_global(Vector3(0, .23, 0)) - fwd * 0.035
			rg = 0.8
			rd = (fwd - axis * fwd.dot(axis)).normalized()
			rt = axis
			if cur.step.t != "top":
				l = jigger.global_position + Vector3(-0.13, 0.03, 0.04)
				lg = 0.3
				ld = (fwd + right * 0.3 + Vector3.DOWN * 0.15).normalized()
				lt = right
		elif dash_bottle:
			r = dash_bottle.to_global(Vector3(0, .06, 0))
			rg = 0.85
			rd = fwd
			rt = dash_bottle.global_transform.basis.y
		elif spoon and _float.is_empty():
			var a: float = spoon.get_meta("a")
			var c: Vector3 = spoon.get_meta("c")
			spoon.position = c + Vector3(cos(a) * .012, .01, sin(a) * .012)
			r = spoon.to_global(Vector3(0, .19, 0))
			rg = 0.6
			rd = Vector3.DOWN
			rt = fwd
			if glass_node:
				l = glass_node.position + Vector3(-0.05, 0.06, 0.01)
				lg = 0.6
				ld = right
		elif muddler:
			r = muddler.to_global(Vector3(0, .2, 0))
			rg = 0.9
			rd = fwd
			rt = Vector3.UP
			if glass_node:
				l = glass_node.position + Vector3(-0.05, 0.05, 0.01)
				lg = 0.6
				ld = right
		elif tin_node and (expecting == "shake" or _straining):
			var up := tin_node.global_transform.basis.y.normalized()
			if expecting == "shake":
				# one hand grips the cap end from the right, the other the base from the left,
				# far enough apart that the hands never meet
				var side := tin_node.global_transform.basis.x.normalized()
				r = tin_node.to_global(Vector3(0, .21, 0)) + side * 0.075 - fwd * 0.03
				l = tin_node.to_global(Vector3(0, .03, 0)) - side * 0.075 - fwd * 0.03
				rg = 0.8
				lg = 0.8
				rd = -side
				ld = side
				rt = up
				lt = up
			else:
				# straining: the right hand holds the tin from the side, the left steadies it
				r = tin_node.to_global(Vector3(0, .1, 0)) + right * 0.06 - fwd * 0.02
				l = tin_node.to_global(Vector3(0, .16, 0)) - right * 0.06 - fwd * 0.02
				rg = 0.85
				lg = 0.6
				rd = -right
				ld = right
				rt = up
				lt = up
	if time < _reach_until:
		r = _reach_pos + Vector3(0.02, 0.0, 0.06)
		rg = 0.55
		rd = (fwd + Vector3.DOWN * 0.6).normalized()
		rt = -right
	me.target["Right"] = r
	me.target["Left"] = l
	me.grip["Right"] = rg
	me.grip["Left"] = lg
	me.hand_dir["Right"] = rd
	me.hand_dir["Left"] = ld
	me.thumb_dir["Right"] = rt
	me.thumb_dir["Left"] = lt
	me.update(cam, delta)


## Pick the bartender you play as (male or female). Both stand behind the bar.
func show_bartender_pick() -> void:
	_end_drink(false)
	in_shift = false
	hud.visible = false
	_picking = true
	if me:
		me.node.visible = false
	for pv in _previews:
		pv.queue_free()
	_previews.clear()
	var ids := BARTENDERS.keys()
	for i in ids.size():
		var n := People.spawn(ids[i], bar)
		People.self_lit(n, 1.25)
		n.rotation.y = PI + (0.2 if i == 0 else -0.2)
		People.set_height(n, 1.76 if i == 0 else 1.68)
		People.arms_down(n)
		# camera looks toward +z, so screen-left is +x
		People.place_standing(n, 0.42 - i * 0.84, 0.15)
		_previews.append(n)
	# soft front light on both bartenders (the back bar lights them from behind only)
	var key := SpotLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.75)
	key.light_energy = 3.5
	key.spot_range = 4.0
	key.spot_angle = 40.0
	bar.add_child(key)
	key.look_at_from_position(Vector3(0, 2.4, -1.1), Vector3(0, 1.3, 0.15))
	_previews.append(key)
	var cam_pos := Vector3(0, 1.6, -1.55)
	cam_base = Transform3D(Basis.looking_at(Vector3(0, 1.3, 0.15) - cam_pos), cam_pos)
	cam.global_transform = cam_base
	cam.fov = 50
	var o := _overlay()
	var t := _label("Choose your bartender", 44, C_GOLD)
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(-400, 24)
	t.size = Vector2(800, 60)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	t.add_theme_constant_override("outline_size", 10)
	o.add_child(t)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.position = Vector2(-560, -150)
	row.size = Vector2(1120, 120)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 260)
	o.add_child(row)
	for id in ids:
		var b := _button("%s  ✓" % BARTENDERS[id].name if Save.bartender == id else BARTENDERS[id].name, _pick_bartender.bind(id), 34, Color(0.85, 0.45, 0.15) if Save.bartender == id else Color(0.3, 0.22, 0.35))
		b.custom_minimum_size = Vector2(240, 0)
		row.add_child(b)


func _pick_bartender(id: String) -> void:
	Audio.play("good", -6.0)
	Save.bartender = id
	Save.save()
	for pv in _previews:
		pv.queue_free()
	_previews.clear()
	set_bartender(id)
	_picking = false
	show_menu()


# =============================================================== techniques

func _clear_techniques() -> void:
	_float = {}
	_blend = {}
	_flip = {}
	if blender:
		blender.queue_free()
		blender = null
	for k in ["peel", "fire"]:
		var n: Node3D = _flame.get(k)
		if is_instance_valid(n):
			n.queue_free()
	_flame = {}
	if jigger:
		jigger.position = Bar.JIGGER_SPOT
		jigger.rotation = Vector3.ZERO
		bar.set_jigger(jigger, 0, Color.WHITE)


## Fill of the glass, 0..1 of its bowl, as it looks right now.
func _glass_fill() -> float:
	var cap: float = Recipes.GLASSES[glass_node.get_meta("kind")].ml
	return _fill_look(cur.vol / cap)


## A meter on the right with a green zone from [param lo] to [param hi] (0..1 of its height).
func _zone_meter(v: float, lo: float, hi: float, text: String, good: bool) -> void:
	meter.visible = true
	var h := meter.size.y
	v = clampf(v, 0.0, 1.0)
	meter_fill.position = Vector2(0, h * (1 - v))
	meter_fill.size = Vector2(meter.size.x, h * v)
	meter_fill.color = Color(1.0, 0.62, 0.2) if good else C_RED
	meter_band.visible = true
	meter_band.position = Vector2(0, h * (1 - hi))
	meter_band.size = Vector2(meter.size.x, h * (hi - lo))
	meter_label.text = text


## --- Layering: the measured jigger is poured slowly over the back of a bar spoon (or down
## the side, to sink). Holding speeds the flow up; too fast and the layer mixes in.
const FLOAT_LO := 0.2
const FLOAT_HI := 0.72

func _start_float(ml: float, col: Color) -> void:
	_set_view("work")
	var sink: bool = cur.step.get("sink", false)
	hint_label.text = ("Pour slowly down the side so it sinks" if sink else "Pour slowly over the spoon so it floats") + ". Keep the flow in the green"
	_float = {"left": ml, "ml": ml, "flow": 0.0, "col": col, "broke": false, "holding": false, "sink": sink, "base": _glass_fill()}
	var top := _glass_top()
	jigger.position = glass_node.position + Vector3(0.06, top + 0.05, 0)
	jigger.rotation.z = 0.5
	if not sink:
		_make_spoon()
		var bw: Array = Bar.GLASS_BOWL[glass_node.get_meta("kind")]
		spoon.set_meta("c", glass_node.position + Vector3(0, lerpf(bw[0], bw[1], _float.base) + 0.004, 0))
		spoon.position = spoon.get_meta("c")
		spoon.rotation.z = 0.25
	var hold := _button("HOLD TO POUR GENTLY", func(): pass, 30)
	hold.button_down.connect(func():
		if not _float.is_empty():
			_float.holding = true
			Audio.loop("pour", true, -10.0))
	hold.button_up.connect(func():
		if not _float.is_empty():
			_float.holding = false
			Audio.loop("pour", false))
	actions.add_child(hold)
	_zone_meter(0.0, FLOAT_LO, FLOAT_HI, "flow", true)


func _float_tick(delta: float) -> void:
	var f := _float
	f.flow = clampf(f.flow + (0.9 if f.holding else -1.6) * delta, 0.0, 1.0)
	var ml := minf(f.flow * 32.0 * delta, f.left)
	f.left -= ml
	if f.flow > FLOAT_HI + 0.08 and not f.broke:
		f.broke = true
		cur.mistakes += 1
		Audio.play("bad", -6.0)
		show_toast("Too fast, it mixed in!", C_RED, 44)
		bar.set_layer(glass_node, 0.0, 0.0, Color.WHITE)
		_add_to_vessel(f.ml - f.left - ml, f.col, false)
	if ml > 0.0:
		if f.broke:
			_add_to_vessel(ml, f.col, false)
		else:
			cur.vol += ml
			var cap: float = Recipes.GLASSES[glass_node.get_meta("kind")].ml
			var thick: float = (f.ml - f.left) / cap * 1.6
			if f.sink:
				bar.set_layer(glass_node, 0.0, minf(thick * 2.5, f.base * 0.45), f.col)
			else:
				bar.set_layer(glass_node, f.base, f.base + thick, f.col)
	jigger.rotation.z = lerpf(0.5, 2.1, f.flow * 0.6 + (1.0 - f.left / f.ml) * 0.4)
	bar.set_jigger(jigger, f.left / maxf(f.ml * 1.5, 30.0), f.col)
	var calm: bool = f.flow <= FLOAT_HI
	_zone_meter(f.flow, FLOAT_LO, FLOAT_HI, "%d ml" % int(f.ml - f.left), calm)
	if f.left <= 0.05:
		_finish_float()


func _finish_float() -> void:
	var f := _float
	_float = {}
	Audio.loop("pour", false)
	_clear_actions()
	meter.visible = false
	if not f.broke:
		Audio.play("good", -6.0)
		show_toast("Beautiful layer!" if not f.sink else "Perfect sunrise!", C_GREEN, 48)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(jigger, "rotation:z", 0.0, 0.12)
	tw.tween_property(jigger, "position", Bar.JIGGER_SPOT, 0.18)
	await tw.finished
	bar.set_jigger(jigger, 0, Color.WHITE)
	if not cur.is_empty():
		_next_step()


## --- Blending: hold the button, let go when it's smooth. Too short is icy, too long is watery.
const BLEND_LO := 70.0
const BLEND_HI := 95.0

func _start_blend() -> void:
	hint_label.text = "Hold to blend, let go when it's smooth (green)"
	if blender == null:
		blender = bar.make_blender()
		bar.add_child(blender)
	blender.position = Bar.TIN_SPOT + Vector3(0.08, 0, -0.05)
	if tin_node:
		tin_node.visible = false
	var jar: Node3D = blender.get_node("Jar")
	_blend = {"p": 0.0, "on": false, "base": cur.color, "fill": clampf(cur.vol / 450.0 + 0.3, 0.3, 0.85)}
	bar.set_fill(jar, _blend.fill, cur.color)
	var hold := _button("HOLD TO BLEND", func(): pass, 30)
	hold.button_down.connect(_blend_hold.bind(true))
	hold.button_up.connect(_blend_hold.bind(false))
	actions.add_child(hold)
	_zone_meter(0.0, BLEND_LO / 120.0, BLEND_HI / 120.0, "", true)


func _blend_hold(on: bool) -> void:
	if _blend.is_empty():
		return
	if on:
		_blend.on = true
		Audio.loop("shake", true, -8.0)
		return
	if not _blend.on:
		return
	_blend.on = false
	Audio.loop("shake", false)
	_finish_blend()


func _blend_tick(delta: float) -> void:
	_blend.p += 42.0 * delta
	var p: float = _blend.p
	var jar: Node3D = blender.get_node("Jar")
	jar.position = Vector3(sin(time * 70.0) * 0.0018, .09, cos(time * 55.0) * 0.0015)
	var smooth := clampf(p / 100.0, 0.0, 1.0)
	bar.set_fill(jar, _blend.fill + 0.04 * sin(time * 30.0), (_blend.base as Color).lerp(Color(1, 1, 1), 0.3 * smooth))
	var word := "icy" if p < BLEND_LO else ("smooth" if p <= BLEND_HI else "watery")
	_zone_meter(p / 120.0, BLEND_LO / 120.0, BLEND_HI / 120.0, word, p <= BLEND_HI)
	if p >= 120.0:
		_blend_hold(false)


func _finish_blend() -> void:
	var p: float = _blend.p
	_clear_actions()
	meter.visible = false
	if p >= BLEND_LO and p <= BLEND_HI:
		cur.perfect += 1
		cur.errs.append(0.0)
		Audio.play("good", -6.0)
		show_toast("Silky smooth!", C_GREEN, 48)
	else:
		cur.errs.append(8.0)
		Audio.play("bad", -8.0)
		show_toast("Still a bit icy" if p < BLEND_LO else "Blended too long, a bit watery", C_RED, 40)
	cur.color = (_blend.base as Color).lerp(Color(1, 1, 1), 0.3 * clampf(p / 100.0, 0.0, 1.0))
	# lift the jar off and pour it into the glass
	var jar: Node3D = blender.get_node("Jar")
	jar.position = Vector3(0, .09, 0)
	var home := jar.global_position
	_carry = jar
	var over := glass_node.global_position + Vector3(0.1, _glass_top() + 0.13, 0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(jar, "global_position", over, 0.3)
	tw.parallel().tween_property(jar, "rotation:z", 1.9, 0.3)
	tw.tween_callback(func():
		Audio.play("pour", -8.0)
		bar.set_fill(jar, 0.0, cur.color)
		var t2 := create_tween()
		t2.tween_method(func(f): if glass_node: bar.set_fill(glass_node, f, cur.color), 0.0, _fill_look(cur.vol * 1.2 / Recipes.GLASSES[glass_node.get_meta("kind")].ml), 0.45))
	tw.tween_interval(0.65)
	tw.tween_property(jar, "rotation:z", 0.0, 0.2)
	tw.parallel().tween_property(jar, "global_position", home, 0.2)
	await tw.finished
	_carry = null
	_blend = {}
	if not cur.is_empty():
		_next_step()


## --- Flamed orange peel: a match between peel and drink, squeeze when the flame is biggest.
func _start_flame() -> void:
	hint_label.text = "Squeeze the peel through the flame when it's at its biggest"
	var top := glass_node.position + Vector3(0, _glass_top(), 0)
	var peel := bar.garnish("orange_twist", bar, top + Vector3(0.0, 0.13, 0.05))
	peel.rotation.x = 1.2
	var fire := Node3D.new()
	fire.position = top + Vector3(0, 0.07, 0.03)
	bar.add_child(fire)
	bar.cyl(.0018, .0018, .07, bar.mat(Color(0.75, 0.6, 0.4)), Vector3(0.03, -0.02, 0.0), fire, 6).rotation.z = 1.0
	var core := bar.sphere(.009, bar.emissive(Color(1.0, 0.6, 0.15), 5.0), Vector3.ZERO, fire)
	core.name = "Core"
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 0.6
	light.light_energy = 0.4
	fire.add_child(light)
	_flame = {"t0": time, "peel": peel, "fire": fire, "light": light, "done": false}
	actions.add_child(_button("SQUEEZE", _squeeze, 30, Color(0.85, 0.45, 0.15)))
	_zone_meter(0.0, 0.8, 1.0, "", true)


func _flame_level() -> float:
	if _flame.is_empty():
		return 0.0
	return (sin((time - _flame.t0) * 3.0 - PI / 2.0) + 1.0) / 2.0


func _flame_tick() -> void:
	var v := _flame_level()
	var core: Node3D = _flame.fire.get_node("Core")
	core.scale = Vector3(0.6 + v * 0.6, 0.9 + v * 1.8, 0.6 + v * 0.6) * (1.0 + 0.08 * sin(time * 40.0))
	_flame.light.light_energy = 0.3 + v * 1.2
	_zone_meter(v, 0.8, 1.0, "", true)


func _squeeze() -> void:
	if _flame.is_empty() or _flame.done:
		return
	_flame.done = true
	_clear_actions()
	meter.visible = false
	var good := _flame_level() >= 0.78
	var core: Node3D = _flame.fire.get_node("Core")
	var tw := create_tween()
	if good:
		cur.perfect += 1
		cur.errs.append(0.0)
		Audio.play("good", -4.0)
		show_toast("Flamed! Smell that orange", C_GOLD, 48)
		_flame.light.light_energy = 7.0
		tw.tween_property(core, "scale", Vector3(5, 7, 5), 0.12)
		tw.parallel().tween_property(_flame.light, "light_energy", 0.0, 0.5)
		tw.tween_property(core, "scale", Vector3.ZERO, 0.25)
	else:
		cur.errs.append(8.0)
		Audio.play("bad", -8.0)
		show_toast("Missed the flame", C_RED, 44)
		tw.tween_property(core, "scale", Vector3.ZERO, 0.3)
		tw.parallel().tween_property(_flame.light, "light_energy", 0.0, 0.3)
	await tw.finished
	await get_tree().create_timer(0.3).timeout
	for k in ["peel", "fire"]:
		var n: Node3D = _flame.get(k)
		if is_instance_valid(n):
			n.queue_free()
	_flame = {}
	if not cur.is_empty():
		_next_step()


## --- Flair: after a shake, flip the tin and catch it for bonus tips. Optional.
func _offer_flip() -> void:
	if tin_node == null:
		_next_step()
		return
	expecting = "flip"
	tin_node.get_node("Lid").visible = true
	hint_label.text = "Flair time! FLIP the shaker for bonus tips"
	_flip = {"t": -1.0, "offer": time}
	actions.add_child(_button("FLIP IT", _do_flip, 30, Color(0.55, 0.3, 0.75)))
	actions.add_child(_button("SKIP", _skip_flip, 24, Color(0.25, 0.2, 0.3)))


func _skip_flip() -> void:
	if expecting != "flip" or _flip.get("t", 0.0) >= 0.0:
		return
	expecting = ""
	_flip = {}
	_clear_actions()
	if tin_node:
		tin_node.get_node("Lid").visible = false
	_next_step()


func _do_flip() -> void:
	if expecting != "flip" or _flip.get("t", 0.0) >= 0.0:
		return
	_clear_actions()
	_flip.t = time
	hint_label.text = "CATCH it as it comes down!"
	Audio.play("click")
	# up for 0.45 s and back down for 0.45 s, spinning end over end the whole time
	var tw := create_tween().set_parallel()
	tw.tween_property(tin_node, "position", Bar.TIN_SPOT + Vector3(-0.06, 0.24, 0.03), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(tin_node, "rotation:x", TAU, 0.9)
	tw.tween_property(tin_node, "position", Bar.TIN_SPOT, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.45)
	actions.add_child(_button("CATCH", _catch, 34, Color(0.2, 0.6, 0.35)))
	await tw.finished
	if cur.is_empty() or tin_node == null:
		return
	if not _flip.get("caught", false):
		_catch()
	tin_node.rotation = Vector3.ZERO
	tin_node.position = Bar.TIN_SPOT
	tin_node.get_node("Lid").visible = false
	await get_tree().create_timer(0.25).timeout
	expecting = ""
	_flip = {}
	if not cur.is_empty():
		_next_step()


func _catch() -> void:
	if _flip.is_empty() or _flip.get("caught", false) or _flip.t < 0.0:
		return
	_flip.caught = true
	_clear_actions()
	var dt: float = time - _flip.t
	if dt >= 0.6 and dt <= 1.0:
		cur.flair = true
		Audio.play("good", -4.0)
		show_toast("Smooth flair!", C_GOLD, 52)
	else:
		Audio.play("bad", -10.0)
		show_toast("Whoa, nearly dropped it!" if dt < 0.6 else "Caught it, just about", Color(1, 1, 1), 40)
