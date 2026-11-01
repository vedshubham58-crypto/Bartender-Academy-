extends Node
## Renders the app icon options (dev tool): godot --path . res://tests/icon_shot.tscn -- <variant> <out.png>

var variant := "a"


func _mat(c: Color, metal := 0.0, rough := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _mesh(mesh: Mesh, m: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	variant = args[0] if args.size() > 0 else "a"
	var out: String = args[1] if args.size() > 1 else "/tmp/shots/icon_%s.png" % variant
	var root := Node3D.new()
	add_child(root)
	var palettes := {
		"a": [Color(0.32, 0.05, 0.28), Color(0.95, 0.42, 0.18), Color(1.0, 0.45, 0.15)],   # sunset magenta/orange, orange drink
		"b": [Color(0.04, 0.08, 0.2), Color(0.1, 0.55, 0.75), Color(0.95, 0.25, 0.45)],     # night blue/teal, pink drink
		"c": [Color(0.12, 0.06, 0.02), Color(0.85, 0.55, 0.15), Color(0.95, 0.6, 0.12)],    # gold & black, amber drink
	}
	var pal: Array = palettes[variant]
	# background: radial gradient card
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 1.0])
	gr.colors = PackedColorArray([pal[1], pal[0]])
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.05, 1.0)
	gt.width = 512
	gt.height = 512
	var bgm := StandardMaterial3D.new()
	bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bgm.albedo_texture = gt
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 3.2)
	_mesh(q, bgm, Vector3(0, 0.12, -1.0), root)
	# sparkles
	var sp := StandardMaterial3D.new()
	sp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp.albedo_color = Color(1, 0.95, 0.85)
	sp.emission_enabled = true
	sp.emission = Color(1, 0.9, 0.7)
	sp.emission_energy_multiplier = 3.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 22:
		var s := SphereMesh.new()
		var r := rng.randf_range(0.006, 0.022)
		s.radius = r
		s.height = r * 2
		var p := Vector3(rng.randf_range(-.75, .75), rng.randf_range(-.5, .85), -0.9)
		if absf(p.x) < .35 and p.y > -.3 and p.y < .5:
			continue
		_mesh(s, sp, p, root)
	# the drink
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.95, 0.98, 1.0, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.02
	glass.metallic_specular = 1.0
	glass.rim_enabled = true
	glass.rim = 1.0
	glass.rim_tint = 0.2
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var g := Node3D.new()
	root.add_child(g)
	g.scale = Vector3.ONE * 5.2
	g.position = Vector3(0, -0.52, 0)
	var kind := "coupe" if variant != "c" else "rocks"
	var prof: Array = Bar.GLASS_PROFILES[kind]
	_mesh(Bar.lathe(Bar.profile(prof), 64), glass, Vector3.ZERO, g)
	var b: Array = Bar.GLASS_BOWL[kind]
	var top: float = lerpf(b[0], b[1], 0.82)
	var rt: float = lerpf(b[2], b[3], 0.82)
	var liq := StandardMaterial3D.new()
	liq.albedo_color = Color(pal[2], 0.88)
	liq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liq.roughness = 0.05
	liq.emission_enabled = true
	liq.emission = pal[2]
	liq.emission_energy_multiplier = 0.35
	liq.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(Bar.lathe(Bar.profile([[0, b[0]], [b[2] * .95, b[0]], [rt * .95, top], [0, top]]), 48), liq, Vector3.ZERO, g)
	if kind == "rocks":
		var ice := StandardMaterial3D.new()
		ice.albedo_color = Color(0.9, 0.95, 1.0, 0.45)
		ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ice.roughness = 0.1
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.05
		var cube := _mesh(bm, ice, Vector3(0, .045, 0), g)
		cube.rotation = Vector3(0.2, 0.5, 0.1)
		# orange twist
		var tw := BoxMesh.new()
		tw.size = Vector3(.07, .005, .016)
		var t := _mesh(tw, _mat(Color(0.98, 0.5, 0.08)), Vector3(.03, .1, .02), g)
		t.rotation = Vector3(0.4, 0.3, 0.7)
	else:
		# lime / orange wheel on the rim
		var wheel := CylinderMesh.new()
		wheel.top_radius = .028
		wheel.bottom_radius = .028
		wheel.height = .006
		wheel.radial_segments = 32
		var wc := Color(0.75, 0.9, 0.3) if variant == "a" else Color(0.98, 0.85, 0.2)
		var w := _mesh(wheel, _mat(wc, 0, 0.35), Vector3(.05, .15, .0), g)
		w.rotation = Vector3(0.0, 0.0, 1.25)
		var inner := CylinderMesh.new()
		inner.top_radius = .024
		inner.bottom_radius = .024
		inner.height = .0065
		_mesh(inner, _mat(wc.lerp(Color.WHITE, 0.6), 0, 0.3), Vector3.ZERO, w)
		# cherry on a pick
		var ch := SphereMesh.new()
		ch.radius = .012
		ch.height = .024
		_mesh(ch, _mat(Color(0.7, 0.02, 0.08), 0, 0.08), Vector3(-.015, .14, .012), g)
	# lights
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = pal[0]
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.55, 0.5)
	e.ambient_light_energy = 0.6
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_hdr_threshold = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.5, 0.6, 0)
	key.light_energy = 1.4
	root.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.6, 0.6, -0.4)
	rim.light_energy = 4.0
	rim.omni_range = 3.0
	rim.light_color = Color(1, 0.85, 0.7)
	root.add_child(rim)
	var rim2 := OmniLight3D.new()
	rim2.position = Vector3(0.7, 0.1, 0.4)
	rim2.light_energy = 2.5
	rim2.omni_range = 3.0
	rim2.light_color = pal[1].lerp(Color.WHITE, 0.5)
	root.add_child(rim2)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.1, 2.3)
	cam.fov = 42
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.05, 0))
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
