class_name Bar
extends Node3D
## Builds the whole 3D bar in code: the bartender's work station with speed rail
## and ice well, the bar top, the back bar, the lounge and the lights.
## Units are metres. The bartender stands at z = 0 and faces -z (the guests).

const TOP := 0.86 ## station worktop height
const BT := 1.12 ## bar top height
const BZ0 := -0.82 ## bar top, bartender edge
const BZ1 := -1.42 ## bar top, guest edge
const RAIL_Y := 0.62
const ZF := -0.3 ## station front (bartender side)
const WX := 0.42 ## ice well half width
const WZ0 := -0.36
const WZ1 := -0.74
const SEAT_Z := -1.72
const SEATS := [-1.3, -0.45, 0.45, 1.3]

const GLASS_SPOT := Vector3(-0.12, BT + 0.008, -0.89)
const TIN_SPOT := Vector3(0.3, BT + 0.008, -0.89)
const JIGGER_SPOT := Vector3(0.1, BT + 0.008, -0.88)
const ICE_SPOT := Vector3(0.0, TOP, -0.55)

## Things the player can tap: id -> world position (rail bottles, station items, ice well).
var pickables := {}
var theme_lights: Array[Light3D] = [] ## the lights a bar light theme recolours
var _theme_base := {} ## light -> its normal colour
var garnish_spots := {} ## garnish kind -> its compartment in the garnish tray
var rail_nodes := {}

var _rng := RandomNumberGenerator.new()
var _labels := {}

# shared materials
var steel: StandardMaterial3D
var steel_dark: StandardMaterial3D
var wood: StandardMaterial3D
var glass: StandardMaterial3D
var ice_mat: StandardMaterial3D
var rubber: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 7
	_make_materials()
	_build_floor()
	_build_station()
	_build_bar_top()
	_build_back_bar()
	_build_lounge()
	_build_lights()
	bake_static()


# ---------------------------------------------------------------- helpers

func mat(color: Color, metal := 0.0, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func emissive(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func liquid_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic_specular = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func add_mesh(mesh: Mesh, m: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func box(size: Vector3, m: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return add_mesh(b, m, pos, parent)


func cyl(rt: float, rb: float, h: float, m: Material, pos: Vector3, parent: Node3D = self, segs := 24) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return add_mesh(c, m, pos, parent)


func sphere(r: float, m: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 20
	s.rings = 12
	return add_mesh(s, m, pos, parent)


## A turned shape (bottle, glass, tin) from a radius/height profile, bottom to top.
static func lathe(pts: PackedVector2Array, segs := 32) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := pts.size()
	for i in n:
		var t := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var nn := Vector2(t.y, -t.x).normalized()
		for j in segs + 1:
			var a := TAU * j / segs
			var c := cos(a)
			var s := sin(a)
			verts.append(Vector3(pts[i].x * c, pts[i].y, pts[i].x * s))
			norms.append(Vector3(nn.x * c, nn.y, nn.x * s).normalized())
			uvs.append(Vector2(float(j) / segs, 1.0 - float(i) / (n - 1)))
	for i in n - 1:
		for j in segs:
			var a := i * (segs + 1) + j
			var b := a + segs + 1
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func profile(a: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in a:
		p.append(Vector2(v[0], v[1]))
	return p


func _noise_tex(freq: float, ramp: Gradient, w := 512, h := 512, seamless := true) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.seed = _rng.randi()
	fn.frequency = freq
	fn.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = w
	t.height = h
	t.seamless = seamless
	t.noise = fn
	t.color_ramp = ramp
	return t


func _grad(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in cols.size():
		offs.append(float(i) / (cols.size() - 1))
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	return g


func _make_materials() -> void:
	steel = mat(Color(0.72, 0.74, 0.77), 0.8, 0.32)
	steel.roughness_texture = _noise_tex(0.02, null, 256, 256)
	steel.uv1_scale = Vector3(1, 20, 1)
	steel_dark = mat(Color(0.42, 0.44, 0.47), 0.75, 0.42)
	wood = mat(Color.WHITE, 0.0, 0.35)
	wood.albedo_texture = _noise_tex(0.008, _grad([Color(0.24, 0.12, 0.06), Color(0.42, 0.22, 0.11), Color(0.3, 0.15, 0.07), Color(0.48, 0.27, 0.14)]))
	wood.uv1_scale = Vector3(1, 14, 1)
	wood.clearcoat_enabled = true
	wood.clearcoat = 0.8
	wood.clearcoat_roughness = 0.1
	glass = StandardMaterial3D.new()
	glass.albedo_color = Color(0.92, 0.97, 1.0, 0.14)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.02
	glass.metallic_specular = 1.0
	glass.rim_enabled = true
	glass.rim = 0.6
	glass.rim_tint = 0.2
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	ice_mat = StandardMaterial3D.new()
	ice_mat.albedo_color = Color(0.66, 0.76, 0.86, 0.5)
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.roughness = 0.12
	ice_mat.rim_enabled = true
	ice_mat.rim = 0.5
	ice_mat.metallic_specular = 0.9
	rubber = mat(Color(0.07, 0.07, 0.07), 0.0, 0.85)
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.09, 0.09, 0.09))
	for x in 8:
		for y in 8:
			img.fill_rect(Rect2i(x * 8 + 2, y * 8 + 2, 5, 5), Color(0.03, 0.03, 0.03))
	rubber.albedo_texture = ImageTexture.create_from_image(img)
	rubber.uv1_scale = Vector3(12, 4, 1)


# ---------------------------------------------------------------- bottles & glassware

## A bottle with label, liquid and (in the rail) a pour spout. Returns the bottle node.
func bottle(id: String, pos: Vector3, parent: Node3D = self, spout := true, r := 0.036, h := 0.29, label := true) -> Node3D:
	var src: Dictionary = Recipes.SOURCES[id]
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	var kind := id.hash() % 3
	var neck: float = [0.72, 0.62, 0.8][kind]
	var pts := profile([[0, 0], [r * .95, 0], [r, .006], [r, h * neck], [r * .85, h * (neck + .06)], [r * .32, h * (neck + .15)], [r * .3, h * .97], [r * .34, h]])
	var lc: Color = src.liquid
	var clear := lc.get_luminance() > 0.8
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.9, 0.95, 0.97, 0.35) if clear else Color(lc.darkened(0.25), 0.9)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.roughness = 0.04
	bm.metallic_specular = 1.0
	bm.rim_enabled = true
	bm.rim = 0.4
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_mesh(lathe(pts, 28), bm, Vector3.ZERO, g)
	if clear:
		var fill: float = h * neck * 0.75
		add_mesh(lathe(profile([[0, .004], [r * .9, .004], [r * .9, fill], [0, fill]]), 20), liquid_mat(lc), Vector3.ZERO, g)
	# label: a coloured band on the front with the brand printed on it
	var lab_col: Color = src.get("label", Color(0.95, 0.93, 0.88))
	var band := CylinderMesh.new()
	band.top_radius = r * 1.015
	band.bottom_radius = r * 1.015
	band.height = h * 0.26
	band.cap_top = false
	band.cap_bottom = false
	band.radial_segments = 28
	add_mesh(band, mat(lab_col, 0.0, 0.6), Vector3(0, h * 0.33, 0), g)
	if not label:
		if not spout:
			cyl(r * .36, r * .36, .02, mat(Color(0.1, 0.1, 0.1), 0.2, 0.4), Vector3(0, h + .01, 0), g, 12)
		return g
	var l := Label3D.new()
	l.text = (src.brand + "\n" if src.brand != "" else "") + src.name.to_upper()
	l.font_size = 40
	l.outline_size = 0
	l.pixel_size = 0.0005
	l.modulate = Color(1.0, 0.86, 0.55) if lab_col.get_luminance() < 0.5 else Color(0.12, 0.08, 0.05)
	l.position = Vector3(0, h * 0.33, r * 1.03)
	l.width = 160
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.double_sided = false
	g.add_child(l)
	if spout:
		cyl(r * .36, r * .36, .018, steel, Vector3(0, h + .009, 0), g, 16)
		var t := cyl(.003, .004, .03, steel, Vector3(0, h + .022, .01), g, 8)
		t.rotation.x = 1.1
	else:
		cyl(r * .36, r * .36, .02, mat(Color(0.1, 0.1, 0.1), 0.2, 0.4), Vector3(0, h + .01, 0), g, 16)
	return g


func squeeze_bottle(id: String, pos: Vector3) -> Node3D:
	var src: Dictionary = Recipes.SOURCES[id]
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	var m := mat(src.liquid.lerp(Color.WHITE, 0.1), 0.0, 0.35)
	add_mesh(lathe(profile([[0, 0], [.028, 0], [.03, .006], [.03, .14], [.024, .155], [.009, .16], [0, .16]]), 20), m, Vector3.ZERO, g)
	cyl(.004, .01, .05, mat(Color(0.95, 0.95, 0.95), 0, 0.4), Vector3(0, .185, 0), g, 10)
	var l := Label3D.new()
	l.text = src.name.to_upper()
	l.font_size = 36
	l.pixel_size = 0.0004
	l.modulate = Color(0.1, 0.1, 0.1)
	l.outline_size = 0
	l.position = Vector3(0, .08, .031)
	l.width = 140
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	g.add_child(l)
	box(Vector3(.05, .035, .002), mat(Color(0.97, 0.97, 0.95)), Vector3(0, .08, .0305), g)
	return g


const GLASS_PROFILES := {
	"highball": [[0, 0], [.03, 0], [.031, .012], [.033, .15], [.0335, .152]],
	"rocks": [[0, 0], [.041, 0], [.042, .015], [.044, .09], [.0445, .092]],
	"coupe": [[0, 0], [.04, 0], [.042, .004], [.006, .012], [.004, .1], [.012, .11], [.045, .125], [.056, .15], [.057, .155]],
	"martini": [[0, 0], [.04, 0], [.042, .004], [.005, .012], [.004, .1], [.006, .104], [.065, .165], [.066, .168]],
	"flute": [[0, 0], [.035, 0], [.036, .004], [.004, .012], [.0035, .09], [.012, .1], [.024, .13], [.027, .2], [.0275, .203]],
	"mug": [[0, 0], [.042, 0], [.043, .005], [.045, .1], [.046, .102]],
}
## Inside of each glass as [bottom y, top y, radius at bottom, radius at top] for the liquid.
const GLASS_BOWL := {
	"highball": [.012, .145, .028, .031],
	"rocks": [.015, .085, .039, .041],
	"coupe": [.11, .148, .012, .053],
	"martini": [.104, .16, .006, .06],
	"flute": [.1, .198, .012, .026],
	"mug": [.006, .096, .04, .043],
	"tin": [.005, .165, .035, .045],
}


## A glass with a liquid inside whose level and colour can change. See [method set_fill].
func make_glass(kind: String) -> Node3D:
	var g := Node3D.new()
	g.name = "Glass"
	g.set_meta("kind", kind)
	if kind == "mug":
		var copper := mat(Color(0.85, 0.48, 0.3), 0.9, 0.3)
		add_mesh(lathe(profile(GLASS_PROFILES[kind]), 32), copper, Vector3.ZERO, g)
		var handle := TorusMesh.new()
		handle.inner_radius = .022
		handle.outer_radius = .03
		var h := add_mesh(handle, copper, Vector3(-.05, .055, 0), g)
		h.rotation.x = PI / 2
	else:
		add_mesh(lathe(profile(GLASS_PROFILES[kind]), 40), glass, Vector3.ZERO, g)
	var liq := MeshInstance3D.new()
	liq.name = "Liquid"
	liq.material_override = liquid_mat(Color.WHITE)
	liq.visible = false
	g.add_child(liq)
	return g


## Sets the drink level (0..1) and colour in a glass made by [method make_glass].
func set_fill(g: Node3D, fill: float, color: Color) -> void:
	var liq: MeshInstance3D = g.get_node("Liquid")
	var b: Array = GLASS_BOWL[g.get_meta("kind")]
	fill = clampf(fill, 0.0, 1.0)
	liq.visible = fill > 0.01
	if not liq.visible:
		return
	var top: float = lerpf(b[0], b[1], fill)
	var rt: float = lerpf(b[2], b[3], fill)
	liq.mesh = lathe(profile([[0, b[0]], [b[2] * .96, b[0]], [rt * .96, top], [0, top]]), 28)
	# clear spirits get a warm tint and a soft glow so you can see the level in the glass
	var lm := liq.material_override as StandardMaterial3D
	# (strongly coloured drinks keep their own colour: a Negroni stays deep red)
	var clear: float = 1.0 - clampf((maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))) * 1.8, 0.0, 1.0)
	lm.albedo_color = Color(color.lerp(Color(1.0, 0.85, 0.55), 0.25 * clear), 0.85 + 0.1 * (1.0 - clear))
	lm.emission_enabled = true
	lm.emission = color.lerp(Color(1.0, 0.8, 0.5), 0.4 * clear)
	lm.emission_energy_multiplier = 0.35


## A floated (or sunk) layer in a glass from [method make_glass], between fill levels
## [param a] and [param b] (0..1 of the bowl). A layer is drawn a hair wider than the
## drink so a sunk one shows through it. Pass b <= a to remove it.
func set_layer(g: Node3D, a: float, b: float, color: Color) -> void:
	var ly: MeshInstance3D = g.get_node_or_null("Layer")
	if b - a < 0.005:
		if ly:
			ly.queue_free()
		return
	if ly == null:
		ly = MeshInstance3D.new()
		ly.name = "Layer"
		ly.material_override = liquid_mat(color)
		g.add_child(ly)
	var bw: Array = GLASS_BOWL[g.get_meta("kind")]
	a = clampf(a, 0.0, 1.0)
	b = clampf(b, 0.0, 1.0)
	var y0: float = lerpf(bw[0], bw[1], a)
	var y1: float = lerpf(bw[0], bw[1], b)
	var r0: float = lerpf(bw[2], bw[3], a) * .975
	var r1: float = lerpf(bw[2], bw[3], b) * .975
	ly.mesh = lathe(profile([[0, y0], [r0, y0], [r1, y1], [0, y1]]), 28)
	var lm := ly.material_override as StandardMaterial3D
	lm.albedo_color = Color(color, 0.95)
	lm.emission_enabled = true
	lm.emission = color
	lm.emission_energy_multiplier = 0.25


## Blender on the back bar: a base and a jar ("Jar", fill it with [method set_fill]).
func make_blender() -> Node3D:
	var b := Node3D.new()
	b.name = "Blender"
	var dark := mat(Color(0.08, 0.08, 0.09), 0.3, 0.35)
	box(Vector3(.12, .09, .12), dark, Vector3(0, .045, 0), b)
	box(Vector3(.03, .012, .01), emissive(Color(0.3, 1.0, 0.55), 2.0), Vector3(0, .05, .061), b)
	var jar := Node3D.new()
	jar.name = "Jar"
	jar.set_meta("kind", "tin")
	jar.position = Vector3(0, .09, 0)
	b.add_child(jar)
	add_mesh(lathe(profile([[0, 0], [.04, 0], [.041, .004], [.048, .168], [.049, .172]]), 28), glass, Vector3.ZERO, jar)
	cyl(.051, .051, .016, dark, Vector3(0, .178, 0), jar, 20)
	var liq := MeshInstance3D.new()
	liq.name = "Liquid"
	liq.material_override = liquid_mat(Color.WHITE)
	liq.visible = false
	jar.add_child(liq)
	return b


## Shaker tin (big tin of a Boston shaker) with a liquid level like a glass.
func make_tin() -> Node3D:
	var g := Node3D.new()
	g.set_meta("kind", "tin")
	var steel := mat(Color(0.82, 0.84, 0.86), 0.8, 0.2)
	add_mesh(lathe(profile([[0, 0], [.035, 0], [.036, .003], [.045, .17], [.0455, .173]]), 32), steel, Vector3.ZERO, g)
	# the small tin that caps it while shaking (upside down, sealed in the big one)
	var lid := add_mesh(lathe(profile([[0, 0], [.03, 0], [.031, .003], [.041, .12], [.0415, .122]]), 24), steel, Vector3(0, .25, 0), g)
	lid.name = "Lid"
	lid.rotation.x = PI
	lid.visible = false
	var liq := MeshInstance3D.new()
	liq.name = "Liquid"
	liq.material_override = liquid_mat(Color.WHITE)
	liq.visible = false
	g.add_child(liq)
	return g


func make_jigger() -> Node3D:
	var g := Node3D.new()
	var m := mat(Color(0.85, 0.86, 0.88), 0.8, 0.18)
	add_mesh(lathe(profile([[0, 0], [.024, 0], [.012, .045], [.011, .05]]), 24), m, Vector3.ZERO, g)
	add_mesh(lathe(profile([[.009, 0], [.022, .03], [.0225, .032]]), 24), m, Vector3(0, .05, 0), g)
	var liq := MeshInstance3D.new()
	liq.name = "Liquid"
	liq.material_override = liquid_mat(Color.WHITE)
	g.add_child(liq)
	return g


## Bar tools look (shop item): "steel", "copper", "gold" or "black".
const TOOL_SKINS := {
	"steel": [Color(0.82, 0.84, 0.86), 0.8, 0.2],
	"copper": [Color(0.86, 0.5, 0.32), 0.9, 0.25],
	"gold": [Color(1.0, 0.78, 0.36), 1.0, 0.18],
	"black": [Color(0.09, 0.09, 0.1), 0.7, 0.3],
}


func skin_tool(node: Node3D, skin: String) -> void:
	var d: Array = TOOL_SKINS.get(skin, TOOL_SKINS["steel"])
	var m := mat(d[0], d[1], d[2])
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if mi.name != "Liquid":
			mi.material_override = m


## Bar light theme (shop item): tints the bar's lamps.
const LIGHT_THEMES := {
	"warm": Color(1, 1, 1),
	"blue": Color(0.45, 0.7, 1.25),
	"pink": Color(1.2, 0.5, 0.95),
	"gold": Color(1.25, 1.0, 0.55),
}


func set_light_theme(theme: String) -> void:
	var tint: Color = LIGHT_THEMES.get(theme, LIGHT_THEMES["warm"])
	for l in theme_lights:
		if not _theme_base.has(l):
			_theme_base[l] = [l.light_color, l.light_energy]
		var base: Array = _theme_base[l]
		var c: Color = base[0]
		l.light_color = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b).clamp(Color(0, 0, 0), Color(1, 1, 1))
		l.light_energy = base[1] * (1.15 if theme != "warm" else 1.0)


## Jigger fill 0..1 of its 30 ml cup... we show up to 60 ml by scaling the cup.
func set_jigger(j: Node3D, fill: float, color: Color) -> void:
	var liq: MeshInstance3D = j.get_node("Liquid")
	fill = clampf(fill, 0.0, 1.0)
	liq.visible = fill > 0.01
	if liq.visible:
		var top := 0.05 + 0.002 + 0.028 * fill
		liq.mesh = lathe(profile([[0, .052], [.0095, .052], [lerpf(.0095, .021, fill), top], [0, top]]), 20)
		(liq.material_override as StandardMaterial3D).albedo_color = Color(color, 0.85)


func ice_cubes(parent: Node3D, center: Vector3, half: Vector3, n: int, size := 0.026) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size * .9, size)
	mm.mesh = bm
	mm.instance_count = n
	for i in n:
		var b := Basis.from_euler(Vector3(_rng.randf() * 3, _rng.randf() * 3, _rng.randf() * 3)).scaled(Vector3.ONE * _rng.randf_range(.8, 1.15))
		var p := center + Vector3(_rng.randf_range(-half.x, half.x), _rng.randf_range(-half.y, half.y), _rng.randf_range(-half.z, half.z))
		mm.set_instance_transform(i, Transform3D(b, p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = ice_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func lime_wheel(parent: Node3D, pos: Vector3, r := 0.024, rind := Color(0.82, 0.9, 0.45), flesh := Color(0.93, 0.96, 0.75)) -> MeshInstance3D:
	var c := cyl(r, r, .006, mat(rind, 0.0, 0.35), pos, parent, 20)
	cyl(r * .86, r * .86, .0065, mat(flesh, 0.0, 0.3), Vector3.ZERO, c, 20)
	return c


func garnish(kind: String, parent: Node3D, pos: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	match kind:
		"lime_wheel":
			var w := lime_wheel(g, Vector3(0.03, 0, 0))
			w.rotation.z = 1.3
		"mint_sprig":
			var mm := mat(Color(0.18, 0.5, 0.15), 0.0, 0.5)
			for i in 9:
				var l := sphere(.014, mm, Vector3(_rng.randf_range(-.015, .015), _rng.randf_range(0, .035), _rng.randf_range(-.015, .015)), g)
				l.scale = Vector3(1, .25, 1.7)
				l.rotation = Vector3(_rng.randf_range(-.8, .8), _rng.randf() * 6, _rng.randf_range(-.6, .6))
		"lemon_wheel":
			var w := lime_wheel(g, Vector3(0.03, 0, 0), .026, Color(0.98, 0.85, 0.2), Color(1.0, 0.95, 0.6))
			w.rotation.z = 1.3
		"orange_wheel":
			var w := lime_wheel(g, Vector3(0.032, 0, 0), .03, Color(0.98, 0.5, 0.08), Color(1.0, 0.7, 0.3))
			w.rotation.z = 1.3
		"orange_twist", "lemon_twist":
			var col := Color(0.95, 0.5, 0.08) if kind == "orange_twist" else Color(0.98, 0.86, 0.2)
			var o := box(Vector3(.06, .004, .014), mat(col, 0.0, 0.4), Vector3(.02, .005, 0), g)
			o.rotation = Vector3(0.3, 0.4, 0.5)
		"olive":
			var pick := cyl(.0012, .0012, .09, mat(Color(0.75, 0.6, 0.4)), Vector3(0, -.02, 0), g, 6)
			pick.rotation.z = 0.35
			var ol := sphere(.009, mat(Color(0.42, 0.5, 0.15), 0.0, 0.25), Vector3(.005, -.035, 0), g)
			ol.scale = Vector3(1, 1.3, 1)
		"pineapple_wedge":
			var wd := box(Vector3(.05, .03, .012), mat(Color(1.0, 0.86, 0.3), 0.0, 0.5), Vector3(.03, .01, 0), g)
			wd.rotation.z = 0.3
			var lf := box(Vector3(.008, .05, .003), mat(Color(0.2, 0.5, 0.15), 0.0, 0.5), Vector3(.05, .045, 0), g)
			lf.rotation.z = -0.3
		"cherry":
			sphere(.012, mat(Color(0.55, 0.02, 0.06), 0.0, 0.1), Vector3.ZERO, g)
			var st := cyl(.0012, .0012, .04, mat(Color(0.3, 0.15, 0.05)), Vector3(0, .025, 0), g, 6)
			st.rotation.z = 0.3
		"coffee_beans":
			for i in 3:
				var b := sphere(.006, mat(Color(0.18, 0.09, 0.04), 0.0, 0.3), Vector3((i - 1) * .014, 0, 0), g)
				b.scale = Vector3(1, .6, 1.4)
	return g


# ---------------------------------------------------------------- the bar

func _build_floor() -> void:
	box(Vector3(6, .02, 2.2), mat(Color(0.09, 0.08, 0.07), 0, 0.9), Vector3(0, -.01, 0.5))
	var f := mat(Color.WHITE, 0.0, 0.5)
	f.albedo_texture = _noise_tex(0.01, _grad([Color(0.12, 0.07, 0.04), Color(0.2, 0.12, 0.07), Color(0.15, 0.09, 0.05)]))
	f.uv1_scale = Vector3(3, 30, 1)
	box(Vector3(24, .02, 9.2), f, Vector3(0, -.01, -5.5))


func _build_station() -> void:
	box(Vector3(2.1, TOP, .02), steel_dark, Vector3(0, TOP / 2, ZF - .01))
	# worktop around the ice well
	box(Vector3(2.1, .012, WZ0 - ZF), steel, Vector3(0, TOP, (ZF + WZ0) / 2))
	box(Vector3(2.1, .012, -0.8 - WZ1), steel, Vector3(0, TOP, (WZ1 - 0.8) / 2))
	box(Vector3(1.05 - WX, .012, .4), steel, Vector3(-(1.05 + WX) / 2, TOP, (WZ0 + WZ1) / 2))
	box(Vector3(1.05 - WX, .012, .4), steel, Vector3((1.05 + WX) / 2, TOP, (WZ0 + WZ1) / 2))
	# ice well
	var d := 0.26
	box(Vector3(WX * 2, d, .006), steel, Vector3(0, TOP - d / 2, WZ0))
	box(Vector3(WX * 2, d, .006), steel, Vector3(0, TOP - d / 2, WZ1))
	box(Vector3(.006, d, WZ0 - WZ1), steel, Vector3(-WX, TOP - d / 2, (WZ0 + WZ1) / 2))
	box(Vector3(.006, d, WZ0 - WZ1), steel, Vector3(WX, TOP - d / 2, (WZ0 + WZ1) / 2))
	box(Vector3(WX * 2, .006, WZ0 - WZ1), steel, Vector3(0, TOP - d, (WZ0 + WZ1) / 2))
	box(Vector3(.012, .04, WZ0 - WZ1), steel, Vector3(0, TOP - .02, (WZ0 + WZ1) / 2))
	var c := Vector3(0, TOP - .06, (WZ0 + WZ1) / 2)
	# the well is full, so its ice can be opaque: see-through ice here was hundreds of
	# overlapping layers to draw on every frame, a big part of the lag on tablets
	var well := ice_cubes(self, c, Vector3(WX - .03, .03, (WZ0 - WZ1) / 2 - .03), 380, 0.03)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.68, 0.78, 0.88)
	wm.roughness = 0.15
	wm.metallic_specular = 0.9
	wm.rim_enabled = true
	wm.rim = 0.4
	well.material_override = wm
	pickables["ice"] = Vector3(0, TOP, (WZ0 + WZ1) / 2)
	# scoop
	var s := Node3D.new()
	s.position = Vector3(-.18, TOP - .01, -.52)
	s.rotation = Vector3(-.35, .5, .15)
	add_child(s)
	var sc := cyl(.045, .05, .14, mat(Color(0.86, 0.88, 0.9), 1.0, 0.18), Vector3.ZERO, s, 20)
	sc.rotation.z = PI / 2
	var hd := cyl(.012, .012, .1, mat(Color(0.07, 0.07, 0.07), 0, 0.5), Vector3(-.12, 0, 0), s, 12)
	hd.rotation.z = PI / 2
	# speed rail
	box(Vector3(1.9, .006, .12), steel, Vector3(0, RAIL_Y, ZF + .06))
	box(Vector3(1.9, .09, .006), steel, Vector3(0, RAIL_Y + .045, ZF + .12))
	build_rail()
	# cutting board with limes
	var bm := mat(Color(0.55, 0.4, 0.25), 0.0, 0.7)
	box(Vector3(.4, .025, .3), bm, Vector3(-.72, TOP + .018, -.55))
	var skin := mat(Color(0.35, 0.62, 0.11), 0.0, 0.45)
	for i in 4:
		var l := sphere(.028, skin, Vector3(-.84 + i * .045, TOP + .055, -.47))
		l.scale = Vector3(1.2, .9, .9)
	for p in [Vector3(-.66, TOP + .034, -.6), Vector3(-.61, TOP + .036, -.57), Vector3(-.6, TOP + .034, -.64)]:
		lime_wheel(self, p)
	var k := Node3D.new()
	k.position = Vector3(-.7, TOP + .036, -.68)
	k.rotation.y = .4
	add_child(k)
	box(Vector3(.16, .003, .03), mat(Color(0.9, 0.92, 0.94), 1.0, 0.15), Vector3.ZERO, k)
	box(Vector3(.1, .016, .022), mat(Color(0.08, 0.08, 0.08)), Vector3(-.13, .004, 0), k)
	# right board: juices, syrups, soda, tonic, bitters, espresso
	box(Vector3(.62, .01, .44), rubber, Vector3(.74, TOP + .008, -.57))
	for i in Recipes.STATION.size():
		var id: String = Recipes.STATION[i]
		var x := 0.48 + (i % 6) * 0.1
		var z := -0.43 - (i / 6) * 0.135
		var pos := Vector3(x, TOP + .013, z)
		match id:
			"soda", "tonic", "ginger_beer", "cola":
				bottle(id, pos, self, false, .028, .2)
			"sparkling":
				bottle(id, pos, self, false, .033, .3)
			"bitters":
				bottle(id, pos, self, false, .022, .13)
			"espresso":
				cyl(.035, .028, .05, mat(Color(0.95, 0.94, 0.92), 0, 0.2), pos + Vector3(0, .025, 0))
				cyl(.032, .032, .004, mat(Color(0.22, 0.11, 0.05), 0, 0.15), pos + Vector3(0, .046, 0))
			_:
				squeeze_bottle(id, pos)
		pickables[id] = pos + Vector3(0, .09, 0)


## A steel tray of garnishes on the bar top, 2 rows of 5 compartments.
func build_garnish_tray() -> void:
	var c := Vector3(-0.5, BT, -1.08)
	box(Vector3(.36, .012, .17), steel_dark, c + Vector3(0, .006, 0))
	var kinds := Recipes.GARNISH.keys()
	for i in kinds.size():
		var p := c + Vector3(-.14 + (i % 5) * .07, .012, -.04 + (i / 5) * .08)
		box(Vector3(.064, .03, .074), steel, p + Vector3(0, .015, 0))
		box(Vector3(.056, .002, .066), mat(Color(0.12, 0.12, 0.12), 0.5, 0.4), p + Vector3(0, .031, 0))
		garnish_spots[kinds[i]] = p + Vector3(0, .035, 0)
		for k in 2:
			var g := garnish(kinds[i], self, p + Vector3((k - 0.5) * .018, .034, (k - 0.5) * .012))
			g.rotation.y = _rng.randf() * TAU
			if kinds[i] in ["olive", "cherry"]:
				g.rotation = Vector3(PI / 2, g.rotation.y, 0)


## A TV hanging over the guests, facing the bartender. Its text is set from main.gd.
func build_tv() -> Label3D:
	var tv := Node3D.new()
	tv.set_meta("dyn", true)
	tv.position = Vector3(0, 2.15, -2.55)
	add_child(tv)
	box(Vector3(1.36, .8, .05), mat(Color(0.03, 0.03, 0.03), 0.3, 0.3), Vector3.ZERO, tv)
	var screen := box(Vector3(1.28, .72, .01), emissive(Color(0.08, 0.1, 0.16), 1.0), Vector3(0, 0, .027), tv)
	screen.name = "Screen"
	for x in [-.4, .4]:
		cyl(.008, .008, .6, steel_dark, Vector3(x, .7, 0), tv, 6)
	var t := Label3D.new()
	t.font_size = 40
	t.pixel_size = 0.0018
	t.width = 640
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.shaded = false
	t.outline_size = 0
	t.position = Vector3(0, 0, .034)
	t.modulate = Color(1.0, 0.92, 0.75)
	tv.add_child(t)
	tv.rotation.y = 0.0
	return t


## (Re)builds the speed rail bottles, so mocktail mode can swap them.
func build_rail() -> void:
	for n in rail_nodes.values():
		n.queue_free()
	rail_nodes.clear()
	var ids := Recipes.rail()
	for k in ids.size():
		var p := Vector3(-0.825 + k * 0.15, RAIL_Y + .003, ZF + .06)
		rail_nodes[ids[k]] = bottle(ids[k], p, self, true, .036, .29)
		rail_nodes[ids[k]].set_meta("dyn", true)
		pickables[ids[k]] = p + Vector3(0, .15, 0)
		var tag := Label3D.new()
		tag.text = Recipes.SOURCES[ids[k]].name
		tag.font_size = 30
		tag.pixel_size = 0.0009
		tag.width = 150
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag.modulate = Color(1.0, 0.95, 0.85)
		tag.outline_size = 8
		tag.outline_modulate = Color(0, 0, 0, 0.9)
		tag.shaded = false
		tag.position = Vector3(0, .07, .065)
		tag.rotation.x = -0.6
		rail_nodes[ids[k]].add_child(tag)


func _build_bar_top() -> void:
	box(Vector3(3.8, .05, BZ0 - BZ1), wood, Vector3(0, BT - .025, (BZ0 + BZ1) / 2))
	box(Vector3(3.8, BT - TOP + .1, .03), wood, Vector3(0, (BT + TOP) / 2 - .05, BZ0 - .03))
	box(Vector3(3.8, BT, .04), wood, Vector3(0, BT / 2, BZ1 - .04))
	var rail := cyl(.02, .02, 3.8, mat(Color(0.79, 0.64, 0.35), 1.0, 0.25), Vector3(0, .22, BZ1 - .2), self, 12)
	rail.rotation.z = PI / 2
	box(Vector3(3.6, .01, .01), emissive(Color(1.0, 0.69, 0.35), 5.0), Vector3(0, 1.075, -.84))
	build_garnish_tray()
	# bar mat and tools
	box(Vector3(1.15, .008, .14), rubber, Vector3(.05, BT + .004, -.89))
	var tin := make_tin()
	tin.position = Vector3(-.42, BT + .008, -.93)
	add_child(tin)
	var mg := add_mesh(lathe(profile([[0, 0], [.045, 0], [.046, .012], [.047, .14], [.049, .145], [.049, .148]]), 32), glass, Vector3(.55, BT + .008, -.94))
	mg.name = "MixingGlass"
	# garnish caddy
	var cx := -1.0
	var cz := -0.95
	box(Vector3(.36, .05, .13), mat(Color(0.1, 0.1, 0.1), 0, 0.4), Vector3(cx + .05, BT + .025, cz))
	for i in 4:
		box(Vector3(.08, .03, .11), steel, Vector3(cx - .07 + i * .085, BT + .04, cz))
	for i in 5:
		var w := lime_wheel(self, Vector3(cx - .08 + _rng.randf_range(-.02, .02), BT + .06 + i * .004, cz + _rng.randf_range(-.03, .03)), .02)
		w.rotation = Vector3(_rng.randf_range(-.4, .4), 0, _rng.randf_range(-.5, .5))
	for i in 7:
		sphere(.011, mat(Color(0.55, 0.02, 0.06), 0.0, 0.1), Vector3(cx + .005 + _rng.randf_range(-.025, .025), BT + .065, cz + _rng.randf_range(-.035, .035)))
	for i in 4:
		var o := box(Vector3(.05, .004, .014), mat(Color(0.95, 0.5, 0.08), 0, 0.4), Vector3(cx + .09, BT + .06 + i * .005, cz + _rng.randf_range(-.03, .03)))
		o.rotation.y = _rng.randf() * 3
	garnish("mint_sprig", self, Vector3(cx + .17, BT + .06, cz))
	# stools
	var leather := mat(Color(0.35, 0.12, 0.08), 0.0, 0.45)
	var brass := mat(Color(0.79, 0.64, 0.35), 1.0, 0.3)
	for x in SEATS:
		cyl(.19, .19, .07, leather, Vector3(x, .78, SEAT_Z))
		cyl(.02, .02, .74, brass, Vector3(x, .4, SEAT_Z), self, 10)
		cyl(.2, .22, .02, brass, Vector3(x, .01, SEAT_Z))


func _build_back_bar() -> void:
	var z := 1.0
	box(Vector3(3.2, .9, .6), mat(Color(0.1, 0.07, 0.05), 0, 0.6), Vector3(0, .45, z + .3))
	box(Vector3(3.2, .04, .62), wood, Vector3(0, .92, z + .3))
	for x in [-1.05, 0.0, 1.05]:
		box(Vector3(.95, .62, .01), emissive(Color(0.8, 0.9, 1.0), 0.5), Vector3(x, .45, z - .005))
		box(Vector3(.02, .3, .02), steel, Vector3(x + .4, .45, z - .03))
	var panel := box(Vector3(3.2, 1.6, .02), null, Vector3(0, 1.8, z + .6))
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var gt := GradientTexture2D.new()
	gt.gradient = _grad([Color(1.0, 0.8, 0.5), Color(0.78, 0.41, 0.12), Color(0.23, 0.09, 0.02)])
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.55)
	gt.fill_to = Vector2(1.1, 0.55)
	pm.albedo_texture = gt
	panel.material_override = pm
	var ids := Recipes.SOURCES.keys().filter(func(k): return Recipes.SOURCES[k].get("brand", "") != "")
	var shelf_glass := mat(Color(0.9, 0.95, 1.0), 0.0, 0.05)
	for row in 3:
		var y := 1.0 + row * 0.42
		box(Vector3(3.0, .015, .3), shelf_glass, Vector3(0, y, z + .38))
		box(Vector3(3.0, .006, .006), emissive(Color(1.0, 0.88, 0.69), 5.0), Vector3(0, y - .01, z + .24))
		for i in 12:
			var b := bottle(ids[(i * 5 + row * 3) % ids.size()], Vector3(-1.38 + i * 0.25, y + .008, z + .38), self, false, _rng.randf_range(.034, .042), _rng.randf_range(.26, .33), false)
			b.rotation.y = PI


## The open-air terrace on top of the tower: booths, a glass railing and the city below.
func _build_lounge() -> void:
	var edge := -10.0
	# the terrace floor carries on round the sides and behind the back bar
	var deck := mat(Color(0.2, 0.16, 0.13), 0.0, 0.7)
	box(Vector3(24, .02, 4.4), deck, Vector3(0, -.01, 3.8))
	for sx in [-1, 1]:
		box(Vector3(9, .02, 3.0), deck, Vector3(sx * 7.5, -.01, 0.1))
	# the tower's top slab and a glass railing all the way round
	var slab := mat(Color(0.12, 0.11, 0.11), 0.2, 0.6)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.75, 0.85, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rail := mat(Color(0.75, 0.72, 0.68), 0.9, 0.25)
	var strip := emissive(Color(1.0, 0.7, 0.4), 2.5)
	# [centre, length, along x?]
	for side in [[Vector3(0, 0, edge), 24.0, true], [Vector3(0, 0, 6.0), 24.0, true],
			[Vector3(-12, 0, -2), 16.0, false], [Vector3(12, 0, -2), 16.0, false]]:
		var c: Vector3 = side[0]
		var n: float = side[1]
		var sz := func(t: float, h: float) -> Vector3: return Vector3(n, h, t) if side[2] else Vector3(t, h, n)
		box(sz.call(.4, .5), slab, c + Vector3(0, -.25, 0))
		box(sz.call(.02, 1.05), glass, c + Vector3(0, .55, 0))
		box(sz.call(.07, .05), rail, c + Vector3(0, 1.1, 0))
		box(sz.call(.02, .02), strip, c + Vector3(0, .03, 0))
		for i in int(n / 2.0) + 1:
			var o := -n * .5 + i * 2.0
			box(Vector3(.05, 1.1, .05), rail, c + (Vector3(o, .55, 0) if side[2] else Vector3(0, .55, o)))
	# string lights between two tall posts
	var post := mat(Color(0.06, 0.06, 0.07), 0.6, 0.4)
	for x in [-7.2, 7.2]:
		cyl(.05, .06, 3.4, post, Vector3(x, 1.7, edge + .5), self, 10)
	var bulb := emissive(Color(1.0, 0.69, 0.35), 6.0)
	for i in 36:
		var x := -7.0 + i * 0.4
		sphere(.03, bulb, Vector3(x, 3.2 - 0.25 * sin(PI * fposmod(x, 2.0) / 2.0), edge + .5))
	# low lounge sofas facing the bar, so the guests have the view behind them
	var booth := mat(Color(0.23, 0.1, 0.07), 0.0, 0.6)
	for i in 5:
		var x := -5.2 + i * 2.6
		box(Vector3(1.4, .45, .55), booth, Vector3(x, .225, -7.65))
		box(Vector3(1.4, .5, .14), booth, Vector3(x, .7, -7.95))
		cyl(.35, .35, .04, wood, Vector3(x, .75, -7))
		cyl(.03, .03, .75, steel_dark, Vector3(x, .37, -7), self, 8)
		sphere(.05, emissive(Color(1.0, 0.63, 0.25), 4.0), Vector3(x, .8, -7))
	var sign := Label3D.new()
	sign.text = "The Cocktail Academy"
	sign.font_size = 100
	sign.pixel_size = 0.004
	sign.modulate = Color(2.4, 1.4, 1.9)
	sign.outline_modulate = Color(1.0, 0.3, 0.55, 0.8)
	sign.outline_size = 18
	sign.position = Vector3(-7.2, 3.75, edge + .5)
	sign.shaded = false
	add_child(sign)
	_build_skyline()


## A night-time desert city far below: lit office towers, a glowing street grid and one
## record-tall spire tower on the horizon. Made-up buildings, no real landmark copied.
func _build_skyline() -> void:
	var ground := -150.0 # the city's streets, far below the terrace
	var win := StandardMaterial3D.new()
	win.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	win.albedo_texture = _window_tex()
	win.uv1_triplanar = true
	win.uv1_world_triplanar = true
	win.uv1_scale = Vector3.ONE / 48.0
	win.albedo_color = Color(1.5, 1.5, 1.5)
	win.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var dark := mat(Color(0.03, 0.035, 0.06), 0.0, 1.0)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var streets := StandardMaterial3D.new()
	streets.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streets.albedo_texture = _street_tex()
	streets.uv1_triplanar = true
	streets.uv1_world_triplanar = true
	streets.uv1_scale = Vector3.ONE / 160.0
	streets.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	box(Vector3(6000, 1, 6000), streets, Vector3(0, ground, -1000))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# three window looks so the towers don't all match: warm offices, blue glass, mixed
	var wins: Array[StandardMaterial3D] = [win]
	for tint in [Color(0.8, 1.15, 1.6), Color(1.6, 1.25, 0.9)]:
		var m: StandardMaterial3D = win.duplicate()
		m.albedo_color = tint
		wins.append(m)
	var low: StandardMaterial3D = win.duplicate()
	low.albedo_color = Color(0.9, 0.8, 0.75)
	var crowns: Array[StandardMaterial3D] = []
	for c in [Color(0.2, 0.8, 1.0), Color(1.0, 0.25, 0.7), Color(1.0, 0.65, 0.2), Color(0.6, 0.35, 1.0)]:
		crowns.append(emissive(c, 1.3))
	var beacon := emissive(Color(1, .1, .05), 6.0)
	# office towers all around the terrace, thickest in front where the guests look
	for i in 260:
		var ang := rng.randf_range(-1.4, 1.4) if i < 200 else rng.randf_range(1.4, TAU - 1.4)
		var dist := rng.randf_range(520.0, 2300.0)
		var p := Vector3(sin(ang) * dist, 0, -cos(ang) * dist - 10.0)
		if p.x > 900.0 and p.z < -900.0:
			continue # that's the sea
		# a downtown cluster near the big spire is taller
		var downtown := p.distance_to(Vector3(-650, 0, -1700)) < 600.0
		if absf(ang - atan2(-650.0, 1690.0)) < 0.06 and dist < 1650.0:
			continue # keep the view of the big spire clear
		var near := dist < 1100.0 and absf(ang) < 0.9 # right in front of the bar: keep the sky open
		var h := rng.randf_range(60.0, 150.0 if near else 200.0) * (1.8 if rng.randf() < (0.4 if downtown else (0.0 if near else 0.12)) else 1.0)
		var w := rng.randf_range(30.0, 60.0)
		var d := rng.randf_range(30.0, 60.0)
		var wm: StandardMaterial3D = wins[rng.randi() % wins.size()]
		var top := ground + h
		if rng.randf() < 0.25:
			cyl(w * .5, w * .5, h, wm, Vector3(p.x, ground + h * .5, p.z), self, 12)
		else:
			box(Vector3(w, h, d), wm, Vector3(p.x, ground + h * .5, p.z))
			if rng.randf() < 0.35:
				# a stepped top
				var h2 := h * rng.randf_range(0.15, 0.3)
				box(Vector3(w * .65, h2, d * .65), wm, Vector3(p.x, top + h2 * .5, p.z))
				top += h2
		if h > 140.0 and rng.randf() < 0.55:
			# a glowing crown band, like the lit tops of real towers at night
			box(Vector3(w * 1.02, 4.0, d * 1.02), crowns[rng.randi() % crowns.size()], Vector3(p.x, top - 6.0, p.z))
		box(Vector3(w * .7, 2, d * .7), dark, Vector3(p.x, top + 1, p.z))
		if h > 150.0:
			sphere(2.0, beacon, Vector3(p.x, top + 3, p.z))
		if h > 250.0:
			cyl(.8, 1.5, 40, dark, Vector3(p.x, top + 20, p.z), self, 6)
			sphere(3.0, beacon, Vector3(p.x, top + 41, p.z))
	# low-rise blocks fill the ground between the towers
	for i in 420:
		var ang := rng.randf_range(-PI, PI)
		var dist := rng.randf_range(300.0, 2600.0)
		var p := Vector3(sin(ang) * dist, 0, -cos(ang) * dist - 10.0)
		if p.x > 900.0 and p.z < -900.0:
			continue
		var h := rng.randf_range(8.0, 35.0)
		box(Vector3(rng.randf_range(25, 70), h, rng.randf_range(25, 70)), low, Vector3(p.x, ground + h * .5, p.z))
	# a wide boulevard of street lights running to the downtown spire
	var road := emissive(Color(1.0, 0.55, 0.2), 1.0)
	var to := Vector3(-650, 0, -1700)
	var seg := box(Vector3(10, 1.2, to.length()), road, Vector3(to.x * .5, ground + 1, to.z * .5))
	seg.rotation.y = atan2(to.x, to.z)
	var tail := emissive(Color(1.0, 0.2, 0.15), 1.0)
	var seg2 := box(Vector3(5, 1.2, to.length()), tail, Vector3(to.x * .5 + 14, ground + 1, to.z * .5))
	seg2.rotation.y = seg.rotation.y
	# the sea off to the right, with the moon's path shining on it
	var sea := mat(Color(0.02, 0.03, 0.07), 0.0, 1.0)
	sea.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box(Vector3(3000, 1, 3000), sea, Vector3(2400, ground + 1.0, -2400))
	var glint := emissive(Color(1.0, 0.9, 0.75), 1.2)
	for k in 40:
		var t := 0.15 + k * 0.021
		var q := Vector3(900, 0, -2600) * t + Vector3(rng.randf_range(-30, 30), 0, 0)
		if q.x > 900.0 and q.z < -900.0:
			box(Vector3(rng.randf_range(20, 70) * t * 1.5, .5, 3.0 + 6.0 * t), glint, Vector3(q.x, ground + 2.0, q.z))
	_build_spire(Vector3(-650, ground, -1700), win, dark)
	# a big pale moon and a scatter of stars
	var moon := emissive(Color(1.0, 0.92, 0.8), 1.4)
	moon.disable_fog = true
	sphere(40.0, moon, Vector3(900, 520, -2600))
	var star := emissive(Color(1, 1, 1), 1.5)
	star.disable_fog = true
	for k in 160:
		var az := rng.randf_range(-PI, PI)
		var el := rng.randf_range(0.18, 1.2)
		var dir := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
		var sz := rng.randf_range(3.0, 6.0)
		box(Vector3(sz, sz, sz), star, dir * 3200.0)


## One supertall tower that steps in as it rises, ending in a long needle.
func _build_spire(base: Vector3, win: Material, dark: Material) -> void:
	var edge := emissive(Color(0.8, 0.9, 1.0), 4.0)
	var y := 0.0
	var tiers := [[150.0, 70.0], [130.0, 58.0], [110.0, 47.0], [95.0, 37.0], [80.0, 28.0], [60.0, 20.0], [45.0, 13.0]]
	for ti in tiers.size():
		var h: float = tiers[ti][0]
		var r: float = tiers[ti][1]
		# three wings around a round core, each tier a little slimmer
		for k in 3:
			var a := k * TAU / 3.0 + ti * 0.0
			var wing := box(Vector3(r * .55, h, r), win, base + Vector3(sin(a) * r * .5, y + h * .5, cos(a) * r * .5))
			wing.rotation.y = a
			box(Vector3(1.2, h, 1.2), edge, base + Vector3(sin(a) * r, y + h * .5, cos(a) * r))
		cyl(r * .42, r * .45, h, win, base + Vector3(0, y + h * .5, 0), self, 16)
		y += h
	cyl(5, 10, 90, win, base + Vector3(0, y + 45, 0), self, 12)
	y += 90
	cyl(.8, 5, 170, edge, base + Vector3(0, y + 85, 0), self, 8)
	sphere(4.0, emissive(Color(1, .15, .1), 8.0), base + Vector3(0, y + 172, 0))


## Office windows: a grid of lit and dark panes on a dark facade.
func _window_tex() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.055, 0.09))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lit := [Color(1.0, 0.82, 0.5), Color(1.0, 0.9, 0.7), Color(0.75, 0.85, 1.0), Color(1.0, 0.7, 0.4)]
	for cy in 16:
		for cx in 16:
			var c := Color(0.08, 0.09, 0.14)
			if rng.randf() < 0.55:
				c = lit[rng.randi() % lit.size()] * rng.randf_range(0.6, 1.0)
			img.fill_rect(Rect2i(cx * 8 + 1, cy * 8 + 2, 6, 5), c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The street grid seen from far above: dark blocks with orange roads and car lights.
func _street_tex() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color(0.025, 0.025, 0.045))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 900:
		img.set_pixel(rng.randi() % 256, rng.randi() % 256, Color(0.9, 0.7, 0.45) * rng.randf_range(0.3, 0.9))
	for k in 4:
		img.fill_rect(Rect2i(k * 64 + rng.randi() % 9, 0, 2, 256), Color(0.6, 0.36, 0.16))
		img.fill_rect(Rect2i(0, k * 64 + rng.randi() % 9, 256, 2), Color(0.6, 0.36, 0.16))
	img.fill_rect(Rect2i(126, 0, 4, 256), Color(0.85, 0.65, 0.4))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_lights() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.25, 0.18)
	e.ambient_light_energy = 0.55
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# just after sunset: deep blue overhead, a warm glow on the horizon
	sm.sky_top_color = Color(0.03, 0.05, 0.16)
	sm.sky_horizon_color = Color(0.85, 0.42, 0.32)
	sm.sky_curve = 0.12
	sm.ground_bottom_color = Color(0.02, 0.02, 0.04)
	sm.ground_horizon_color = Color(0.5, 0.28, 0.3)
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	e.sky = sky
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.glow_enabled = false # glow costs several full-screen passes on tablets
	e.glow_intensity = 0.45
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.4, 0.26, 0.32) # city haze
	e.fog_density = 0.0006
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)
	# Few lights and no shadows: the OpenGL renderer draws every object once per light,
	# so this keeps tablets smooth. Glowing bulbs fake the rest.
	var station := SpotLight3D.new()
	station.light_color = Color(1.0, 0.89, 0.72)
	station.light_energy = 1.5
	station.spot_range = 3.6
	station.spot_angle = 50
	station.spot_angle_attenuation = 0.8
	add_child(station)
	theme_lights.append(station)
	station.look_at_from_position(Vector3(.1, 2.5, .3), Vector3(0, .8, -.6))
	for x in [-1.1, 0.0, 1.1]:
		cyl(.003, .003, 1.0, mat(Color(0.05, 0.05, 0.05)), Vector3(x, 2.75, -1.12), self, 6)
		cyl(.05, .13, .14, mat(Color(0.1, 0.1, 0.1), 0.6, 0.4), Vector3(x, 2.2, -1.12))
		sphere(.04, emissive(Color(1.0, 0.76, 0.48), 3.0), Vector3(x, 2.15, -1.12))
	for x in [-1.1, 0.0, 1.1]:
		var p := SpotLight3D.new()
		p.light_color = Color(1.0, 0.78, 0.54)
		p.light_energy = 2.8
		p.spot_range = 4.0
		p.spot_angle = 55
		add_child(p)
		theme_lights.append(p)
		p.look_at_from_position(Vector3(x, 2.14, -1.12), Vector3(x, 0, -1.1), Vector3.FORWARD)
	var led := OmniLight3D.new()
	led.light_color = Color(1.0, 0.72, 0.42)
	led.light_energy = 0.5
	led.omni_range = 1.6
	led.position = Vector3(0, 1.04, -.82)
	add_child(led)
	theme_lights.append(led)
	var lounge := OmniLight3D.new()
	lounge.light_color = Color(1.0, 0.6, 0.31)
	lounge.light_energy = 3.6
	lounge.omni_range = 7.0
	lounge.position = Vector3(0, 2.6, -6.5)
	add_child(lounge)
	var back := OmniLight3D.new()
	back.light_color = Color(1.0, 0.7, 0.42)
	back.light_energy = 1.8
	back.omni_range = 2.8
	back.position = Vector3(0, 1.7, .9)
	add_child(back)
	theme_lights.append(back)
	var rp := ReflectionProbe.new()
	rp.size = Vector3(5, 3, 4)
	rp.position = Vector3(0, 1.3, -0.6)
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(rp)


# ---------------------------------------------------------------- speed

static func _mat_key(m: Material) -> String:
	if not m is StandardMaterial3D:
		return str(m.get_instance_id())
	var b: StandardMaterial3D = m
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [b.albedo_color, b.metallic, b.roughness, b.emission_enabled, b.emission,
		b.emission_energy_multiplier, b.transparency, b.albedo_texture.get_rid() if b.albedo_texture else 0,
		b.roughness_texture.get_rid() if b.roughness_texture else 0, b.uv1_scale, b.clearcoat_enabled, b.cull_mode,
		b.rim_enabled, b.metallic_specular, b.shading_mode]


## Merges every fixed object of the bar into a few big meshes (one per look), so the
## tablet draws ~40 things instead of ~900.
func bake_static() -> void:
	var groups := {}
	var mats := {}
	var inv := global_transform.affine_inverse()
	var todo := []
	for mi in find_children("*", "MeshInstance3D", true, false):
		var n: Node = mi
		var dyn := false
		while n != self and n != null:
			if n.has_meta("dyn"):
				dyn = true
				break
			n = n.get_parent()
		if dyn or mi.mesh == null:
			continue
		todo.append([mi, inv * mi.global_transform])
	for item in todo:
		var mi: MeshInstance3D = item[0]
		var xf: Transform3D = item[1]
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(si)
			if m == null:
				continue
			var z := xf.origin.z
			var k := ("back" if z > 0.5 else ("city" if z < -20.0 else ("lounge" if z < -3.0 else "bar"))) + _mat_key(m)
			if not groups.has(k):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[k] = st
				mats[k] = m
			groups[k].append_from(mi.mesh, si, xf)
		mi.visible = false
		mi.queue_free()
	var am := ArrayMesh.new()
	for k in groups:
		groups[k].commit(am)
		am.surface_set_material(am.get_surface_count() - 1, mats[k])
	var out := MeshInstance3D.new()
	out.name = "Baked"
	out.mesh = am
	add_child(out)
