class_name CaveProps
extends RefCounted
## Models for the underground: ore veins, crystals, chests, ladders, waystones...

const ORE_COLORS := [Color("d8843a"), Color("c8c0b8"), Color("eef4fa"), Color("f6d04a"), Color("9a8aff"), Color("1e1e22"), Color("e05a8a"), Color("4a2a6a")]
const BIOME_ROCK := [Color("7a6650"), Color("5f6a58"), Color("5a5f78"), Color("6a5a6a"), Color("4a3a36"), Color("5a5a62")]

static func get_mesh(key: String, v: int = 0) -> Mesh:
	return Meshes.cached("cave:%s#%d" % [key, v], func(): return build(key, v))

static func build(key: String, v: int) -> Mesh:
	var mb := MeshBuilder.new(key.hash() + v * 131)
	match key:
		"cave_rock": _cave_rock(mb, v)
		"ore_rock": _ore_rock(mb, v)
		"crystal_cluster": _crystal_cluster(mb, v, Color("9fe3ff"))
		"crystal_big": _crystal_big(mb, v)
		"cracked_wall": _cracked_wall(mb, v)
		"chest": _chest(mb, v, false)
		"chest_open": _chest(mb, v, true)
		"ladder": _ladder(mb)
		"hole": _hole(mb)
		"waystone": _waystone(mb, v)
		"bones": _bones(mb)
		"stalagmite": _stalagmite(mb, v)
		"support": _support(mb)
		"rail": _rail(mb)
		"glow_shrooms": _glow_shrooms(mb, v)
		"giant_mushroom": _giant_mushroom(mb, v)
		"bedroll": _bedroll(mb)
		"lantern_post": _lantern_post(mb)
		"pillar": _pillar(mb, v)
		"statue": _statue(mb, v)
		"lava_rock": _lava_rock(mb, v)
		"moss_patch": _moss_patch(mb, v)
		"bridge_plank": _bridge_plank(mb, v)
		"quest_marker": _quest_marker(mb, v)
		_:
			mb.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	return mb.commit()

static func _cave_rock(mb: MeshBuilder, v: int) -> void:
	var biome := v / 4
	var col: Color = BIOME_ROCK[biome % BIOME_ROCK.size()].lightened(0.15)
	var s := 0.5 + (v % 4) * 0.08
	mb.blob(Vector3(0, s * 0.4, 0), Vector3(s, s * 0.75, s * 0.9), col, 0.25, 1, Vector3(0, v * 1.1, 0))
	mb.blob(Vector3(s * 0.5, s * 0.2, s * 0.3), Vector3(s * 0.45, s * 0.38, s * 0.4), col.darkened(0.08), 0.25, 0)

static func _ore_rock(mb: MeshBuilder, v: int) -> void:
	var rock := Color("6e665e")
	if v == 7:
		rock = Color("3a2a36")
	mb.blob(Vector3(0, 0.42, 0), Vector3(0.62, 0.55, 0.58), rock, 0.22, 1, Vector3(0, v, 0))
	mb.blob(Vector3(0.35, 0.22, -0.25), Vector3(0.36, 0.3, 0.34), rock.darkened(0.1), 0.25, 0)
	var oc: Color = ORE_COLORS[v % ORE_COLORS.size()]
	var glow := v in [3, 4, 6]
	if glow:
		mb.surface("glow_steady")
	else:
		mb.surface("vc_shiny")
	for i in 7:
		var a := mb.rng.randf() * TAU
		var y := mb.rng.randf_range(0.2, 0.8)
		var r := 0.55 * sqrt(max(0.05, 1.0 - pow((y - 0.42) / 0.6, 2.0)))
		var p := Vector3(cos(a) * r, y, sin(a) * r)
		if v == 6:
			mb.cyl(p, 0.07, 0.0, 0.22, 5, oc, Vector3(cos(a) * 0.9, 0, sin(a) * 0.9))
		else:
			mb.blob(p, Vector3(0.1, 0.08, 0.1) * mb.rng.randf_range(0.8, 1.4), oc, 0.3, 0)
	mb.surface("vc")

static func _crystal_cluster(mb: MeshBuilder, v: int, col: Color) -> void:
	var cols := [Color("9fe3ff"), Color("c8a0ff"), Color("a0ffd8")]
	col = cols[v % cols.size()]
	mb.blob(Vector3(0, 0.15, 0), Vector3(0.5, 0.25, 0.45), Color("5a5f78"), 0.2, 0)
	mb.surface("glow")
	for i in 6:
		var a := TAU * i / 6.0 + mb.rng.randf() * 0.5
		var tilt := mb.rng.randf_range(0.2, 0.6)
		var h := mb.rng.randf_range(0.5, 1.1)
		var base := Vector3(cos(a) * 0.18, 0.15, sin(a) * 0.18)
		var rot := Vector3(sin(a) * tilt, 0, -cos(a) * tilt)
		mb.cyl(base, 0.09, 0.09, h * 0.75, 6, col, rot, false)
		var tipb := MeshBuilder.T(base, rot) * Vector3(0, h * 0.75, 0)
		mb.cyl(tipb, 0.09, 0.0, h * 0.3, 6, col.lightened(0.2), rot, false)
	mb.cyl(Vector3(0, 0.1, 0), 0.12, 0.12, 1.2, 6, col.lightened(0.1), Vector3.ZERO, false)
	mb.cyl(Vector3(0, 1.3, 0), 0.12, 0.0, 0.4, 6, col.lightened(0.3), Vector3.ZERO, false)
	mb.surface("vc")

static func _crystal_big(mb: MeshBuilder, v: int) -> void:
	var col: Color = [Color("8fd8ff"), Color("b890ff"), Color("90ffd0"), Color("ff9ac8")][v % 4]
	mb.surface("glow")
	for i in 5:
		var a := TAU * i / 5.0 + mb.rng.randf()
		var tilt := mb.rng.randf_range(0.1, 0.45)
		var h := mb.rng.randf_range(1.8, 3.6)
		var r := mb.rng.randf_range(0.2, 0.38)
		var base := Vector3(cos(a) * 0.4, 0, sin(a) * 0.4)
		var rot := Vector3(sin(a) * tilt, 0, -cos(a) * tilt)
		mb.cyl(base, r, r * 0.9, h, 6, col, rot, false)
		mb.cyl(MeshBuilder.T(base, rot) * Vector3(0, h, 0), r * 0.9, 0.0, r * 2.2, 6, col.lightened(0.25), rot, false)
	mb.surface("vc")

static func _cracked_wall(mb: MeshBuilder, v: int) -> void:
	var col: Color = BIOME_ROCK[v % BIOME_ROCK.size()]
	mb.blob(Vector3(0, 1.4, 0), Vector3(1.8, 1.6, 1.0), col, 0.12, 1)
	mb.blob(Vector3(-1.1, 0.6, 0.2), Vector3(0.9, 0.8, 0.8), col.lightened(0.05), 0.2, 0)
	mb.blob(Vector3(1.0, 0.7, 0.2), Vector3(1.0, 0.9, 0.8), col.darkened(0.05), 0.2, 0)
	# cracks
	var dark := Color(0.06, 0.05, 0.05)
	var p := Vector3(-0.2, 2.4, 0.95)
	for i in 6:
		var q := p + Vector3(mb.rng.randf_range(-0.35, 0.35), -0.38, 0.02)
		mb.box((p + q) / 2.0, Vector3(0.07, p.distance_to(q), 0.04), dark, Vector3(0, 0, atan2(q.x - p.x, p.y - q.y)))
		p = q

static func _chest(mb: MeshBuilder, v: int, open: bool) -> void:
	var wood: Color = [Color("8a5a32"), Color("5a5a62"), Color("7a4a2a")][v % 3]
	var band: Color = [Color("4a4a4a"), Color("2a2a30"), Color("f2c94c")][v % 3]
	mb.box(Vector3(0, 0.28, 0), Vector3(0.9, 0.55, 0.6), wood)
	if open:
		mb.box(Vector3(0, 0.75, -0.35), Vector3(0.92, 0.45, 0.12), wood.lightened(0.05), Vector3(-0.4, 0, 0))
		mb.surface("glow_steady")
		mb.box(Vector3(0, 0.52, 0), Vector3(0.75, 0.06, 0.45), Color("ffe08a").darkened(0.3))
		mb.surface("vc")
	else:
		mb.cyl(Vector3(-0.46, 0.55, 0), 0.3, 0.3, 0.92, 8, wood.lightened(0.05), Vector3(0, 0, -PI / 2), true, true)
		mb.box(Vector3(0, 0.6, 0.3), Vector3(0.16, 0.2, 0.06), band)
	for x in [-0.32, 0.32]:
		mb.box(Vector3(x, 0.3, 0), Vector3(0.08, 0.6, 0.64), band)

static func _ladder(mb: MeshBuilder) -> void:
	for s in [-1, 1]:
		mb.box(Vector3(s * 0.32, 1.6, 0), Vector3(0.08, 3.6, 0.08), Color("8a6a42"))
	for i in 9:
		mb.box(Vector3(0, 0.2 + i * 0.38, 0), Vector3(0.64, 0.06, 0.08), Color("a07a4a"))
	mb.surface("glow_steady")
	mb.disc(Vector3(0, 3.42, 0), 0.6, 8, Color(0.55, 0.6, 0.5))
	mb.surface("vc")

static func _hole(mb: MeshBuilder) -> void:
	for i in 10:
		var a := TAU * i / 10.0
		mb.blob(Vector3(cos(a) * 1.15, 0.1, sin(a) * 1.15), Vector3(0.38, 0.22, 0.3), Color("5a5048"), 0.25, 0)
	mb.surface("cave_cap")
	mb.disc(Vector3(0, 0.03, 0), 1.0, 12, Color(0.01, 0.01, 0.015))
	mb.surface("vc")
	# rope and stake
	mb.cyl(Vector3(1.3, 0, 0.4), 0.06, 0.05, 0.7, 5, Color("8a6a42"))
	mb.cyl(Vector3(1.3, 0.55, 0.4), 0.025, 0.025, 1.4, 4, Color("c8a86a"), Vector3(0, 0, 1.1))

static func _waystone(mb: MeshBuilder, v: int) -> void:
	mb.cyl(Vector3.ZERO, 0.9, 0.8, 0.3, 8, Color("6a6a70"))
	mb.box(Vector3(0, 1.3, 0), Vector3(0.6, 2.2, 0.45), Color("7a7a84"))
	mb.cone(Vector3(0, 2.4, 0), 0.42, 0.5, 4, Color("7a7a84"), Vector3(0, PI / 4, 0))
	mb.surface("glow")
	var c := Color("7fe3ff") if v == 1 else Color("4a5a6a")
	mb.box(Vector3(0, 1.5, 0.24), Vector3(0.22, 0.9, 0.04), c)
	mb.box(Vector3(0, 1.5, -0.24), Vector3(0.22, 0.9, 0.04), c)
	mb.surface("vc")

static func _bones(mb: MeshBuilder) -> void:
	var b := Color("e9e2cf")
	mb.sphere(Vector3(0.3, 0.12, 0.1), Vector3(0.13, 0.12, 0.15), b, 3, 6)
	for i in 4:
		mb.cyl(Vector3(-0.3 + i * 0.12, 0.05, -0.2), 0.03, 0.03, 0.5, 4, b, Vector3(PI / 2, mb.rng.randf_range(-0.6, 0.6), 0))
	mb.box(Vector3(-0.1, 0.06, 0.25), Vector3(0.35, 0.05, 0.25), Color("d8cfb0"), Vector3(0, 0.4, 0))
	mb.cyl(Vector3(0.1, 0.0, 0.5), 0.03, 0.02, 0.8, 4, Color("6a5a48"), Vector3(PI / 2, 0.8, 0))

static func _stalagmite(mb: MeshBuilder, v: int) -> void:
	var col: Color = BIOME_ROCK[(v / 3) % BIOME_ROCK.size()].lightened(0.1)
	var h := 0.8 + (v % 3) * 0.7
	mb.cyl(Vector3.ZERO, 0.38 + (v % 3) * 0.1, 0.0, h, 6, col)
	mb.cyl(Vector3(0.35, 0, 0.2), 0.2, 0.0, h * 0.5, 5, col.darkened(0.1))

static func _support(mb: MeshBuilder) -> void:
	var w := Color("7a5a3a")
	for s in [-1, 1]:
		mb.box(Vector3(s * 1.6, 1.5, 0), Vector3(0.24, 3.0, 0.24), w)
	mb.box(Vector3(0, 3.0, 0), Vector3(3.6, 0.26, 0.3), w)

static func _rail(mb: MeshBuilder) -> void:
	for i in 3:
		mb.box(Vector3(0, 0.04, -0.66 + i * 0.66), Vector3(1.3, 0.08, 0.18), Color("5a4a36"))
	for s in [-1, 1]:
		mb.box(Vector3(s * 0.45, 0.1, 0), Vector3(0.06, 0.06, 2.0), Color("6a6a72"))

static func _glow_shrooms(mb: MeshBuilder, v: int) -> void:
	var cols := [Color("7fe3ff"), Color("b07fff"), Color("7fffb0"), Color("ffb07f")]
	for i in 4:
		var p := Vector3(mb.rng.randf_range(-0.4, 0.4), 0, mb.rng.randf_range(-0.4, 0.4))
		var s := mb.rng.randf_range(0.7, 1.5)
		mb.cyl(p, 0.05 * s, 0.04 * s, 0.25 * s, 5, Color("d8e0e8"))
		mb.surface("glow")
		mb.sphere(p + Vector3(0, 0.25 * s, 0), Vector3(0.16, 0.08, 0.16) * s, cols[v % cols.size()], 3, 7)
		mb.surface("vc")

static func _giant_mushroom(mb: MeshBuilder, v: int) -> void:
	var cap: Color = [Color("c85a7a"), Color("8a5ac8"), Color("5ac88a")][v % 3]
	var h := 2.5 + (v % 3) * 0.8
	mb.cyl(Vector3.ZERO, 0.35, 0.25, h, 7, Color("e8dcc8"))
	mb.sphere(Vector3(0, h, 0), Vector3(1.6, 0.6, 1.6), cap, 3, 10, 0.0, Vector3.ZERO, cap.darkened(0.4))
	mb.surface("glow")
	for i in 6:
		var a := TAU * i / 6.0
		mb.sphere(Vector3(cos(a) * 1.0, h + 0.38, sin(a) * 1.0), Vector3.ONE * 0.14, Color("fff0c0"), 2, 5)
	mb.surface("vc")

static func _bedroll(mb: MeshBuilder) -> void:
	mb.box(Vector3(0, 0.06, 0), Vector3(0.8, 0.12, 1.9), Color("6a5a8a"))
	mb.cyl(Vector3(-0.42, 0.18, -0.8), 0.15, 0.15, 0.84, 7, Color("8a7aa8"), Vector3(0, 0, -PI / 2), true, true)
	mb.box(Vector3(0.7, 0.2, 0.4), Vector3(0.4, 0.4, 0.3), Color("8a6a4a"))

static func _lantern_post(mb: MeshBuilder) -> void:
	mb.box(Vector3(0, 1.0, 0), Vector3(0.12, 2.0, 0.12), Color("6a4a32"))
	mb.box(Vector3(0.25, 1.9, 0), Vector3(0.5, 0.08, 0.08), Color("6a4a32"))
	mb.surface("window")
	mb.box(Vector3(0.45, 1.65, 0), Vector3(0.2, 0.28, 0.2), Color("ffc860"))
	mb.surface("vc")

static func _pillar(mb: MeshBuilder, v: int) -> void:
	var c := Color("8a8a96")
	mb.box(Vector3(0, 0.2, 0), Vector3(1.2, 0.4, 1.2), c.darkened(0.1))
	var h := 3.5 if v == 0 else 1.2 + (v % 3) * 0.7
	mb.cyl(Vector3(0, 0.4, 0), 0.42, 0.38, h, 8, c)
	if v == 0:
		mb.box(Vector3(0, 0.4 + h + 0.15, 0), Vector3(1.1, 0.3, 1.1), c.darkened(0.1))
	mb.surface("glow_steady")
	mb.box(Vector3(0, 0.4 + h * 0.5, 0.4), Vector3(0.1, 0.4, 0.02), Color("7fe3ff").darkened(0.2))
	mb.surface("vc")

static func _statue(mb: MeshBuilder, v: int) -> void:
	var c := Color("8a8a96")
	mb.box(Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.2), c.darkened(0.1))
	mb.sphere(Vector3(0, 1.6, 0), Vector3(0.45, 0.8, 0.35), c, 4, 8)
	mb.sphere(Vector3(0, 2.6, 0), Vector3(0.28, 0.3, 0.28), c, 4, 8)
	mb.cyl(Vector3(0.45, 1.6, 0.2), 0.1, 0.1, 0.9, 5, c, Vector3(-0.8, 0, 0))
	mb.surface("glow")
	mb.sphere(Vector3(0.45, 2.3, 0.85), Vector3.ONE * 0.16, Color("ffd36b"), 2, 6)
	mb.surface("vc")

static func _lava_rock(mb: MeshBuilder, v: int) -> void:
	mb.blob(Vector3(0, 0.4, 0), Vector3(0.7, 0.55, 0.6), Color("2a1e1e"), 0.25, 1)
	mb.surface("glow")
	for i in 3:
		var a := mb.rng.randf() * TAU
		mb.box(Vector3(cos(a) * 0.45, 0.4, sin(a) * 0.45), Vector3(0.05, 0.5, 0.05), Color("ff6a1a"), Vector3(0.4, a, 0.3))
	mb.surface("vc")

static func _moss_patch(mb: MeshBuilder, v: int) -> void:
	mb.surface("vc_soft_glow")
	for i in 5:
		mb.blob(Vector3(mb.rng.randf_range(-0.6, 0.6), 0.02, mb.rng.randf_range(-0.6, 0.6)), Vector3(0.4, 0.06, 0.35), Color("3f8a5a").lerp(Color("5aaa6a"), mb.rng.randf()), 0.3, 0)
	mb.surface("vc")

static func _bridge_plank(mb: MeshBuilder, v: int) -> void:
	# A rope-and-plank crossing along Z, length 2*v + 4
	var l := 4.0 + v * 2.0
	var n := int(l / 0.4)
	for i in n:
		var z := -l / 2 + i * 0.4 + 0.2
		mb.box(Vector3(0, 0, z), Vector3(1.8, 0.1, 0.34), Color("9a7048").lerp(Color("7a5232"), fmod(i * 0.37, 1.0)))
	for s in [-1, 1]:
		for i in 3:
			mb.box(Vector3(s * 0.95, 0.4, -l / 2 + i * l / 2), Vector3(0.12, 1.0, 0.12), Color("6a4a32"))
		mb.cyl(Vector3(s * 0.95, 0.85, -l / 2), 0.03, 0.03, l, 4, Color("c8a86a"), Vector3(PI / 2, 0, 0))

static func _quest_marker(mb: MeshBuilder, v: int) -> void:
	mb.surface("glow")
	mb.cone(Vector3(0, 0.0, 0), 0.25, 0.5, 4, Color("ffd36b"), Vector3(PI, 0, 0))
	mb.surface("vc")
