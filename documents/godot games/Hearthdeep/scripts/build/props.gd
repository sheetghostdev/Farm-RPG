class_name Props
extends RefCounted
## Procedural models for nature, structures and points of interest.
## Every builder returns an ArrayMesh made with MeshBuilder; Meshes caches them.

const BARK := Color("6b4a32")
const BARK_DARK := Color("4e3424")
const LEAF := Color("4f9a3c")
const LEAF_LIGHT := Color("7cc04f")
const PINE := Color("2f6b45")
const STONE := Color("8f8d88")
const STONE_DARK := Color("6d6a66")
const WOOD := Color("a8774a")
const WOOD_DARK := Color("7a5232")
const PLANK := Color("c09060")
const ROOF_COLORS := [Color("b5523b"), Color("6a7fa8"), Color("5f8a4f"), Color("8a5a8a"), Color("a8743f"), Color("4f6a7a"), Color("c07a3a")]
const WALL_COLORS := [Color("f1dfb8"), Color("e8d0b0"), Color("d8c8a8"), Color("f0e6d6"), Color("c8d0c0"), Color("e0c8b8"), Color("d0b898")]

static func get_mesh(key: String, variant: int = 0) -> Mesh:
	var k := "%s#%d" % [key, variant]
	return Meshes.cached(k, func(): return build(key, variant))

static func build(key: String, v: int) -> Mesh:
	var mb := MeshBuilder.new(key.hash() + v * 7919)
	match key:
		"oak": _oak(mb, v)
		"pine": _pine(mb, v)
		"birch": _birch(mb, v)
		"willow": _willow(mb, v)
		"dead_tree": _dead_tree(mb, v)
		"giant_oak": _giant_oak(mb, v)
		"stump": _stump(mb, v)
		"big_stump": _stump(mb, v, 1.6)
		"log": _log(mb, v)
		"bush": _bush(mb, v, false)
		"berry_bush": _bush(mb, v, true)
		"rock": _rock(mb, v, 0.45)
		"rock_med": _rock(mb, v, 0.8)
		"boulder": _rock(mb, v, 1.8)
		"pebble": _rock(mb, v, 0.18)
		"weed": _weed(mb, v)
		"twig": _twig(mb, v)
		"grass": _grass_tuft(mb, v)
		"flower": _flower(mb, v)
		"fern": _fern(mb, v)
		"reeds": _reeds(mb, v)
		"lily": _lily(mb, v)
		"mushroom_patch": _mushroom_patch(mb, v)
		"forage": _forage(mb, v)
		"clay_mound": _clay_mound(mb, v)
		"dig_spot": _dig_spot(mb, v)
		"standing_stone": _standing_stone(mb, v)
		"ruin_wall": _ruin_wall(mb, v)
		"watchtower": _watchtower(mb, v)
		"tent": _tent(mb, v)
		"fire_ring": _fire_ring(mb, v)
		"crate_prop": _crate(mb, Vector3.ZERO, 0.8, WOOD)
		"barrel_prop": _barrel(mb, Vector3.ZERO)
		"signpost": _signpost(mb, v)
		"bridge": _bridge(mb, v)
		"broken_bridge": _bridge(mb, v, true)
		"dock": _dock(mb, v)
		"well": _well(mb, v)
		"shipping_bin": _shipping_bin(mb, v)
		"lamp": _lamp(mb, v)
		"notice_board": _notice_board(mb, v)
		"fountain": _fountain(mb, v)
		"market_stall": _market_stall(mb, v)
		"cave_entrance": _cave_entrance(mb, v)
		"farmhouse": _farmhouse(mb, v)
		"bench_prop": _bench(mb)
		"hot_spring_rocks": _hot_spring(mb, v)
		"lookout": _lookout(mb, v)
		"lodge": _lodge(mb, v)
		"cart": _cart(mb, v)
		"scaffold": _scaffold(mb, v)
		"flower_bed": _flower_bed(mb, v)
		"bunting": _bunting(mb, v)
		"soil_bed": _soil_bed(mb, v)
		"stone_wall": _stone_wall(mb, v)
		"hedge": _hedge(mb, v)
		"gate_arch": _gate_arch(mb, v)
		"wayboard": _wayboard(mb, v)
		_:
			mb.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	return mb.commit()

# ------------------------------------------------------------------ trees

static func _canopy(mb: MeshBuilder, center: Vector3, size: float, col: Color, n: int) -> void:
	mb.surface("foliage")
	mb.blob(center, Vector3(size, size * 0.82, size), col, 0.16, 1)
	for i in n:
		var a := mb.rng.randf() * TAU
		var d := size * mb.rng.randf_range(0.45, 0.8)
		var s := size * mb.rng.randf_range(0.5, 0.72)
		var c := col.lightened(mb.rng.randf_range(-0.08, 0.12))
		mb.blob(center + Vector3(cos(a) * d, mb.rng.randf_range(-0.3, 0.5) * size, sin(a) * d), Vector3(s, s * 0.85, s), c, 0.18, 1)
	mb.surface("vc")

static func _oak(mb: MeshBuilder, v: int) -> void:
	var h := 2.4 + (v % 3) * 0.35
	mb.cyl(Vector3.ZERO, 0.32, 0.22, h, 7, BARK)
	mb.cyl(Vector3(0, -0.05, 0), 0.5, 0.32, 0.35, 7, BARK_DARK, Vector3.ZERO, false)
	# branches
	for i in 2:
		var a := mb.rng.randf() * TAU
		mb.cyl(Vector3(0, h * 0.7, 0), 0.12, 0.06, 1.3, 5, BARK, Vector3(cos(a) * 0.8, a, sin(a) * 0.8))
	var leaf := LEAF.lerp(LEAF_LIGHT, (v % 4) / 4.0)
	_canopy(mb, Vector3(0, h + 1.1, 0), 1.6 + (v % 2) * 0.3, leaf, 4)

static func _pine(mb: MeshBuilder, v: int) -> void:
	var h := 1.0 + (v % 3) * 0.3
	mb.cyl(Vector3.ZERO, 0.24, 0.16, h + 2.5, 6, BARK_DARK)
	mb.surface("foliage_ever")
	var col := PINE.lerp(Color("3f7a4a"), (v % 3) / 3.0)
	var y := h
	var r := 1.65 + (v % 2) * 0.2
	for i in 4:
		mb.cyl(Vector3(0, y, 0), r, 0.0, 1.7, 8, col.lightened(i * 0.04), Vector3(0, mb.rng.randf() * TAU, 0), false, true)
		y += 1.05
		r *= 0.74
	mb.surface("vc")

static func _birch(mb: MeshBuilder, v: int) -> void:
	var h := 3.0 + (v % 3) * 0.4
	mb.cyl(Vector3.ZERO, 0.2, 0.14, h, 6, Color("e8e4dc"))
	for i in 6:
		var y := mb.rng.randf_range(0.3, h - 0.2)
		var a := mb.rng.randf() * TAU
		mb.box(Vector3(cos(a) * 0.17, y, sin(a) * 0.17), Vector3(0.12, 0.05, 0.12), Color("3a3a3a"), Vector3(0, a, 0))
	_canopy(mb, Vector3(0, h + 0.6, 0), 1.15, Color("8ac05a").lerp(Color("a8c84a"), (v % 3) / 3.0), 3)

static func _willow(mb: MeshBuilder, v: int) -> void:
	var h := 2.6
	mb.cyl(Vector3.ZERO, 0.4, 0.26, h, 7, BARK)
	var col := Color("7aae4a")
	_canopy(mb, Vector3(0, h + 0.8, 0), 1.8, col, 3)
	mb.surface("foliage")
	for i in 22:
		var a := TAU * i / 22.0 + mb.rng.randf() * 0.2
		var r := mb.rng.randf_range(1.3, 2.0)
		var base := Vector3(cos(a) * r, h + 0.6, sin(a) * r)
		var len := mb.rng.randf_range(1.6, 2.5)
		mb.tri(base + Vector3(-0.18, 0, 0), base + Vector3(0.18, 0, 0), base + Vector3(cos(a) * 0.2, -len, sin(a) * 0.2), col.darkened(0.05))
		mb.tri(base + Vector3(0.18, 0, 0), base + Vector3(-0.18, 0, 0), base + Vector3(cos(a) * 0.2, -len, sin(a) * 0.2), col.darkened(0.05))
	mb.surface("vc")

static func _dead_tree(mb: MeshBuilder, v: int) -> void:
	var h := 3.0
	mb.cyl(Vector3.ZERO, 0.3, 0.12, h, 6, Color("6a5a4a"))
	for i in 4:
		var a := mb.rng.randf() * TAU
		var y := mb.rng.randf_range(1.2, h - 0.3)
		mb.cyl(Vector3(0, y, 0), 0.09, 0.03, 1.2, 4, Color("6a5a4a"), Vector3(cos(a) * 0.9, a, sin(a) * 0.9))

static func _giant_oak(mb: MeshBuilder, v: int) -> void:
	var h := 5.0
	mb.cyl(Vector3.ZERO, 1.3, 0.8, h, 9, BARK)
	mb.cyl(Vector3(0, -0.1, 0), 1.9, 1.2, 0.8, 9, BARK_DARK, Vector3.ZERO, false)
	# hollow
	mb.box(Vector3(0, 1.0, -1.05), Vector3(0.9, 1.3, 0.3), Color("1c1410"))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		mb.cyl(Vector3(0, h * 0.75, 0), 0.35, 0.15, 3.0, 6, BARK, Vector3(cos(a) * 0.9, a, sin(a) * 0.9))
	_canopy(mb, Vector3(0, h + 2.2, 0), 3.6, Color("4a8a3a"), 6)

static func _stump(mb: MeshBuilder, v: int, s: float = 1.0) -> void:
	mb.cyl(Vector3.ZERO, 0.45 * s, 0.38 * s, 0.5 * s, 7, BARK, Vector3.ZERO, true, false, Color("c8a070"))
	mb.cyl(Vector3(0, 0.5 * s, 0), 0.25 * s, 0.25 * s, 0.01, 7, Color("a88050"))
	for i in 3:
		var a := mb.rng.randf() * TAU
		mb.cyl(Vector3(cos(a) * 0.3 * s, 0.05, sin(a) * 0.3 * s), 0.12 * s, 0.05 * s, 0.6 * s, 4, BARK_DARK, Vector3(cos(a) * 1.2, 0, sin(a) * 1.2))

static func _log(mb: MeshBuilder, v: int) -> void:
	var l := 3.0 + v * 0.8
	mb.cyl(Vector3(-l * 0.5, 0.35, 0), 0.38, 0.34, l, 7, BARK, Vector3(0, 0, -PI / 2), true, true, Color("c8a070"))
	mb.surface("plant")
	for i in 5:
		mb.blob(Vector3(mb.rng.randf_range(-l * 0.4, l * 0.4), 0.7, mb.rng.randf_range(-0.2, 0.2)), Vector3(0.22, 0.12, 0.22), Color("5f9a4a"), 0.2, 0)
	mb.surface("vc")

static func _bush(mb: MeshBuilder, v: int, berries: bool) -> void:
	mb.surface("foliage_still")
	var col := Color("3f7f3a").lerp(Color("5a9a42"), (v % 3) / 3.0)
	mb.blob(Vector3(0, 0.45, 0), Vector3(0.75, 0.55, 0.75), col, 0.2, 1)
	mb.blob(Vector3(0.45, 0.35, 0.2), Vector3(0.5, 0.4, 0.5), col.lightened(0.06), 0.2, 1)
	mb.blob(Vector3(-0.35, 0.3, -0.25), Vector3(0.5, 0.38, 0.5), col.darkened(0.04), 0.2, 1)
	mb.surface("vc")
	if berries:
		var bc: Color = [Color("3a2a6a"), Color("c0203a"), Color("4a5fd0")][v % 3]
		for i in 14:
			var a := mb.rng.randf() * TAU
			var y := mb.rng.randf_range(0.3, 0.85)
			var r := 0.62 * sqrt(1.0 - pow((y - 0.45) / 0.6, 2.0)) + 0.08
			mb.sphere(Vector3(cos(a) * r, y, sin(a) * r), Vector3.ONE * 0.07, bc, 2, 5)

static func _rock(mb: MeshBuilder, v: int, s: float) -> void:
	var col := STONE.lerp(STONE_DARK, (v % 3) / 3.0)
	mb.blob(Vector3(0, s * 0.35, 0), Vector3(s, s * 0.72, s * 0.9), col, 0.22, 1, Vector3(0, v * 1.3, 0))
	if s > 0.6:
		mb.blob(Vector3(s * 0.6, s * 0.2, s * 0.3), Vector3(s * 0.5, s * 0.4, s * 0.45), col.darkened(0.05), 0.25, 1)
	if s >= 1.5:
		mb.surface("plant")
		mb.blob(Vector3(0, s * 0.95, 0), Vector3(s * 0.55, s * 0.12, s * 0.5), Color("5f8f4a"), 0.25, 1)
		mb.surface("vc")

static func _weed(mb: MeshBuilder, v: int) -> void:
	mb.surface("plant")
	var col := Color("4f8a34").lerp(Color("6a9a3a"), (v % 3) / 3.0)
	for i in 7:
		var a := TAU * i / 7.0 + mb.rng.randf() * 0.4
		mb.blade(Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), 0.14, mb.rng.randf_range(0.35, 0.6), Vector3(cos(a) * 0.2, 0, sin(a) * 0.2), col, col.lightened(0.25))
	mb.surface("vc")

static func _twig(mb: MeshBuilder, v: int) -> void:
	mb.cyl(Vector3(-0.35, 0.06, 0), 0.05, 0.035, 0.75, 4, BARK, Vector3(0, v * 0.7, -PI / 2))
	mb.cyl(Vector3(0.0, 0.06, 0), 0.03, 0.02, 0.3, 4, BARK, Vector3(0.5, v * 0.7 + 0.8, -PI / 2.6))

static func _grass_tuft(mb: MeshBuilder, v: int) -> void:
	mb.surface("grass")
	var base := Color("5a9a3e")
	for i in 5 + v:
		var a := mb.rng.randf() * TAU
		var r := mb.rng.randf_range(0.0, 0.18)
		var h := mb.rng.randf_range(0.25, 0.5)
		var lean := Vector3(cos(a), 0, sin(a)) * mb.rng.randf_range(0.05, 0.15)
		var c := base.lerp(Color("7ab84a"), mb.rng.randf())
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var side := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)) * 0.06
		mb.tri(p - side, p + side, p + Vector3(0, h, 0) + lean, c.darkened(0.25), c.darkened(0.25), c.lightened(0.15))
		mb.tri(p + side, p - side, p + Vector3(0, h, 0) + lean, c.darkened(0.25), c.darkened(0.25), c.lightened(0.15))

static func _flower(mb: MeshBuilder, v: int) -> void:
	var cols := [Color("f2d04b"), Color("e86a8a"), Color("f4f2ea"), Color("8a6ad8"), Color("e8702a"), Color("6ab0e8")]
	mb.surface("grass")
	for i in 3:
		var p := Vector3(mb.rng.randf_range(-0.15, 0.15), 0, mb.rng.randf_range(-0.15, 0.15))
		var h := mb.rng.randf_range(0.25, 0.4)
		mb.blade(p, 0.04, h, Vector3.ZERO, Color("4f8a34"))
		mb.surface("plant")
		mb.blob(p + Vector3(0, h, 0), Vector3(0.07, 0.04, 0.07), cols[(v + i) % cols.size()], 0.1, 0)
		mb.surface("grass")
	mb.surface("vc")

static func _fern(mb: MeshBuilder, v: int) -> void:
	mb.surface("plant")
	var col := Color("3f8a3a")
	for i in 7:
		var a := TAU * i / 7.0 + mb.rng.randf() * 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		var tip := dir * 0.7 + Vector3(0, 0.35, 0)
		var side := Vector3(-dir.z, 0, dir.x) * 0.12
		mb.tri(Vector3(0, 0.05, 0), tip * 0.5 + side + Vector3(0, 0.15, 0), tip, col)
		mb.tri(Vector3(0, 0.05, 0), tip, tip * 0.5 - side + Vector3(0, 0.15, 0), col.lightened(0.08))
		mb.tri(Vector3(0, 0.05, 0), tip, tip * 0.5 + side + Vector3(0, 0.15, 0), col)
		mb.tri(Vector3(0, 0.05, 0), tip * 0.5 - side + Vector3(0, 0.15, 0), tip, col.lightened(0.08))
	mb.surface("vc")

static func _reeds(mb: MeshBuilder, v: int) -> void:
	mb.surface("plant")
	for i in 9:
		var p := Vector3(mb.rng.randf_range(-0.35, 0.35), -0.3, mb.rng.randf_range(-0.35, 0.35))
		var h := mb.rng.randf_range(0.9, 1.5)
		mb.blade(p, 0.06, h, Vector3(mb.rng.randf_range(-0.1, 0.1), 0, 0), Color("7a9a4a"), Color("a8b86a"))
		if i % 3 == 0:
			mb.surface("vc")
			mb.cyl(p + Vector3(0, h * 0.8, 0), 0.04, 0.04, 0.2, 4, Color("6a4a2a"))
			mb.surface("plant")
	mb.surface("vc")

static func _lily(mb: MeshBuilder, v: int) -> void:
	mb.surface("vc_nosnow")
	mb.disc(Vector3(0, 0.02, 0), 0.32, 7, Color("4a8a3a"))
	if v % 2 == 0:
		mb.blob(Vector3(0.05, 0.08, 0.05), Vector3(0.09, 0.06, 0.09), Color("f0d0e0"), 0.1, 0)
	mb.surface("vc")

static func _mushroom_at(mb: MeshBuilder, p: Vector3, s: float, cap: Color, stem: Color, glow: bool = false) -> void:
	mb.cyl(p, 0.06 * s, 0.05 * s, 0.22 * s, 5, stem)
	if glow:
		mb.surface("glow")
	mb.sphere(p + Vector3(0, 0.22 * s, 0), Vector3(0.16, 0.09, 0.16) * s, cap, 3, 7, 0.0, Vector3.ZERO, cap.darkened(0.3))
	if glow:
		mb.surface("vc")

static func _mushroom_patch(mb: MeshBuilder, v: int) -> void:
	var caps := [Color("d8c8b0"), Color("f2a93b"), Color("a8865a"), Color("c8d0ff"), Color("8a7a6a"), Color("3a3a4a")]
	for i in 3:
		_mushroom_at(mb, Vector3(mb.rng.randf_range(-0.2, 0.2), 0, mb.rng.randf_range(-0.2, 0.2)), mb.rng.randf_range(0.8, 1.3), caps[v % caps.size()], Color("efe6d8"), v == 3)

## Generic forage plant; variant picks the look.
static func _forage(mb: MeshBuilder, v: int) -> void:
	match v:
		0: # leafy plant with white bulb (leek)
			mb.surface("plant")
			for i in 5:
				var a := TAU * i / 5.0
				mb.blade(Vector3.ZERO, 0.06, 0.45, Vector3(cos(a) * 0.12, 0, sin(a) * 0.12), Color("5aa83a"))
			mb.surface("vc")
			mb.sphere(Vector3(0, 0.04, 0), Vector3(0.08, 0.06, 0.08), Color("f0f0e0"), 2, 5)
		1: # flower
			_flower(mb, mb.rng.randi() % 6)
		2: # herb clump
			mb.surface("plant")
			mb.blob(Vector3(0, 0.15, 0), Vector3(0.22, 0.16, 0.22), Color("6aa84a"), 0.2, 1)
			mb.surface("vc")
		3: # nuts / fruit on ground
			for i in 4:
				mb.sphere(Vector3(mb.rng.randf_range(-0.15, 0.15), 0.06, mb.rng.randf_range(-0.15, 0.15)), Vector3.ONE * 0.07, Color("a8743f"), 2, 5)
		4: # winter root (dirt mound + root)
			mb.sphere(Vector3(0, 0.0, 0), Vector3(0.25, 0.08, 0.25), Color("6a4a32"), 2, 6)
			mb.cyl(Vector3(0, 0.02, 0), 0.06, 0.02, 0.25, 4, Color("c8a07a"), Vector3(0.4, 0, 0.3))
		5: # feather
			mb.surface("plant")
			mb.blade(Vector3(0, 0.02, 0), 0.08, 0.35, Vector3(0.1, -0.25, 0.1), Color("e8e0d0"))
			mb.surface("vc")
		6: # crystal sprout (cave)
			mb.surface("glow")
			for i in 3:
				var a := TAU * i / 3.0
				mb.cyl(Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), 0.05, 0.0, 0.3, 4, Color("b4e8ff"), Vector3(cos(a) * 0.4, 0, sin(a) * 0.4))
			mb.surface("vc")
		_:
			mb.surface("plant")
			mb.blob(Vector3(0, 0.12, 0), Vector3(0.2, 0.12, 0.2), Color("6aa84a"), 0.2, 1)
			mb.surface("vc")

static func _clay_mound(mb: MeshBuilder, v: int) -> void:
	mb.surface("vc_nosnow")
	mb.sphere(Vector3(0, 0.0, 0), Vector3(0.6, 0.18, 0.55), Color("b8704a"), 2, 7, 0.1)
	mb.sphere(Vector3(0.3, 0.0, 0.2), Vector3(0.35, 0.12, 0.3), Color("c88058"), 2, 6, 0.1)
	mb.surface("vc")

static func _dig_spot(mb: MeshBuilder, v: int) -> void:
	# wiggling worm-like tips in the dirt: a classic "dig here" sign
	mb.surface("vc_nosnow")
	mb.disc(Vector3(0, 0.02, 0), 0.3, 6, Color("5a3e28"))
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		mb.cyl(Vector3(cos(a) * 0.12, 0, sin(a) * 0.12), 0.03, 0.02, 0.14, 4, Color("8a5a3a"), Vector3(cos(a) * 0.5, 0, sin(a) * 0.5))
	mb.surface("vc")

# ------------------------------------------------------------------ structures

static func _standing_stone(mb: MeshBuilder, v: int) -> void:
	var h := 2.4 + (v % 3) * 0.5
	mb.blob(Vector3(0, h * 0.5, 0), Vector3(0.5, h * 0.55, 0.32), Color("8a8a90").lerp(Color("6a7068"), (v % 2) * 0.5), 0.1, 1, Vector3(0, v * 0.6, mb.rng.randf_range(-0.08, 0.08)))
	mb.surface("glow_steady")
	mb.box(Vector3(0, h * 0.62, -0.3), Vector3(0.14, 0.3, 0.02), Color("7fe3ff").darkened(0.3))
	mb.surface("vc")

static func _ruin_wall(mb: MeshBuilder, v: int) -> void:
	var l := 3.0
	for i in 6:
		var x := -l / 2 + i * 0.55
		var h := mb.rng.randf_range(0.4, 1.9)
		mb.box(Vector3(x, h / 2, 0), Vector3(0.5, h, 0.6), STONE.lerp(Color("a8a090"), mb.rng.randf()))
	mb.surface("plant")
	mb.blob(Vector3(0.4, 0.4, 0.35), Vector3(0.5, 0.3, 0.2), Color("4f8a3a"), 0.3, 1)
	mb.surface("vc")

static func _watchtower(mb: MeshBuilder, v: int) -> void:
	var r := 2.2
	var segs := 10
	for i in segs:
		if i == 7:
			continue
		var a0 := TAU * i / segs
		var h = 2.0 + 3.5 * abs(sin(i * 1.7)) + (2.0 if i < 4 else 0.0)
		var p := Vector3(cos(a0) * r, h * 0.5, sin(a0) * r)
		mb.box(p, Vector3(1.45, h, 0.7), STONE.lerp(Color("a8a090"), (i % 3) / 3.0), Vector3(0, -a0 + PI / 2, 0))
	mb.disc(Vector3(0, 0.05, 0), r, segs, Color("6a6458"))
	mb.box(Vector3(0.5, 0.3, 0.6), Vector3(0.8, 0.6, 0.8), WOOD_DARK)

static func _tent(mb: MeshBuilder, v: int) -> void:
	var cloth = [Color("c8b08a"), Color("8a6a4a"), Color("6a8a6a")][v % 3]
	var w := 1.4
	var l := 2.2
	var h := 1.5
	mb.quad2(Vector3(-w, 0, -l / 2), Vector3(-w, 0, l / 2), Vector3(0, h, l / 2), Vector3(0, h, -l / 2), cloth)
	mb.quad2(Vector3(w, 0, l / 2), Vector3(w, 0, -l / 2), Vector3(0, h, -l / 2), Vector3(0, h, l / 2), cloth.darkened(0.1))
	mb.tri(Vector3(-w, 0, -l / 2), Vector3(0, h, -l / 2), Vector3(w, 0, -l / 2), cloth.darkened(0.15))
	mb.cyl(Vector3(0, 0, l / 2 + 0.05), 0.04, 0.04, h + 0.15, 4, WOOD_DARK)
	mb.cyl(Vector3(0, 0, -l / 2 - 0.05), 0.04, 0.04, h + 0.15, 4, WOOD_DARK)
	mb.box(Vector3(0, 0.03, l / 2 + 0.6), Vector3(0.8, 0.06, 1.4), Color("6a5a8a"))

static func _fire_ring(mb: MeshBuilder, v: int) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		mb.blob(Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), Vector3(0.18, 0.13, 0.16), STONE.darkened(0.1 * (i % 2)), 0.2, 0)
	mb.cyl(Vector3(-0.3, 0.1, 0), 0.07, 0.07, 0.6, 5, Color("3a2a1a"), Vector3(0, 0.5, -PI / 2))
	mb.cyl(Vector3(0, 0.1, -0.3), 0.07, 0.07, 0.6, 5, Color("2a2018"), Vector3(PI / 2, 0, 0))

static func _crate(mb: MeshBuilder, p: Vector3, s: float, col: Color) -> void:
	mb.box(p + Vector3(0, s / 2, 0), Vector3(s, s, s), col)
	for y in [0.08, 0.92]:
		mb.box(p + Vector3(0, s * y, 0), Vector3(s + 0.04, s * 0.1, s + 0.04), col.darkened(0.25))

static func _barrel(mb: MeshBuilder, p: Vector3) -> void:
	mb.cyl(p, 0.35, 0.4, 0.45, 8, WOOD)
	mb.cyl(p + Vector3(0, 0.45, 0), 0.4, 0.35, 0.45, 8, WOOD, Vector3.ZERO, true, false, WOOD.lightened(0.1))
	mb.cyl(p + Vector3(0, 0.15, 0), 0.39, 0.4, 0.06, 8, Color("4a4a4a"), Vector3.ZERO, false)
	mb.cyl(p + Vector3(0, 0.72, 0), 0.4, 0.38, 0.06, 8, Color("4a4a4a"), Vector3.ZERO, false)

static func _signpost(mb: MeshBuilder, v: int) -> void:
	mb.cyl(Vector3.ZERO, 0.07, 0.06, 1.7, 5, WOOD_DARK)
	mb.box(Vector3(0.35, 1.45, 0), Vector3(0.8, 0.22, 0.06), PLANK, Vector3(0, 0, 0.05))
	mb.box(Vector3(-0.3, 1.15, 0), Vector3(0.7, 0.2, 0.06), PLANK.darkened(0.1), Vector3(0, 0.4, -0.05))

static func _bridge(mb: MeshBuilder, v: int, broken: bool = false) -> void:
	# Spans along local Z. v encodes length in meters.
	var l := float(max(6, v))
	var w := 2.6
	var n := int(l / 0.42)
	for i in n:
		var z := -l / 2 + i * 0.42 + 0.21
		if broken and abs(z) < l * 0.18:
			continue
		var c := PLANK.lerp(WOOD_DARK, fmod(i * 0.37, 1.0) * 0.5)
		mb.box(Vector3(0, 0.0, z), Vector3(w, 0.12, 0.38), c, Vector3(0, 0, mb.rng.randf_range(-0.02, 0.02)))
	for side in [-1, 1]:
		mb.box(Vector3(side * (w / 2 - 0.1), -0.15, 0), Vector3(0.18, 0.18, l), WOOD_DARK)
		var posts := int(l / 2.0) + 1
		for i in posts:
			var z := -l / 2 + i * (l / (posts - 1))
			if broken and abs(z) < l * 0.2:
				continue
			mb.box(Vector3(side * (w / 2 - 0.05), 0.45, z), Vector3(0.14, 0.9, 0.14), WOOD_DARK)
			mb.box(Vector3(side * (w / 2 - 0.05), -1.0, z), Vector3(0.2, 2.0, 0.2), WOOD_DARK.darkened(0.2))
		if not broken:
			mb.box(Vector3(side * (w / 2 - 0.05), 0.85, 0), Vector3(0.1, 0.1, l), WOOD)
		else:
			mb.box(Vector3(side * (w / 2 - 0.05), 0.85, -l * 0.35), Vector3(0.1, 0.1, l * 0.3), WOOD)
			mb.box(Vector3(side * (w / 2 - 0.05), 0.85, l * 0.35), Vector3(0.1, 0.1, l * 0.3), WOOD)

static func _dock(mb: MeshBuilder, v: int) -> void:
	var l := 7.0
	for i in 16:
		mb.box(Vector3(0, 0, i * 0.44), Vector3(2.0, 0.1, 0.4), PLANK.lerp(WOOD_DARK, fmod(i * 0.31, 1.0) * 0.4))
	for i in 4:
		for s in [-1, 1]:
			mb.cyl(Vector3(s * 0.95, -1.5, i * 2.2), 0.1, 0.1, 2.0, 5, WOOD_DARK)
	_barrel(mb, Vector3(0.6, 0.05, 6.2))

static func _well(mb: MeshBuilder, v: int) -> void:
	mb.cyl(Vector3.ZERO, 0.85, 0.85, 0.8, 10, STONE, Vector3.ZERO, false)
	mb.cyl(Vector3(0, 0.0, 0), 0.65, 0.65, 0.81, 10, STONE_DARK, Vector3.ZERO, false)
	mb.surface("water")
	mb.disc(Vector3(0, 0.55, 0), 0.65, 10, Color(1, 1, 1))
	mb.surface("vc")
	mb.cyl(Vector3(0, 0.8, 0), 0.84, 0.84, 0.08, 10, STONE.lightened(0.1), Vector3.ZERO, false)
	for s in [-1, 1]:
		mb.box(Vector3(s * 0.75, 1.4, 0), Vector3(0.12, 1.4, 0.12), WOOD_DARK)
	mb.box(Vector3(0, 2.0, 0), Vector3(1.6, 0.08, 0.08), WOOD_DARK)
	mb.quad_out(Vector3(-1.0, 2.0, -0.7), Vector3(1.0, 2.0, -0.7), Vector3(1.0, 2.5, 0), Vector3(-1.0, 2.5, 0), Color("b5523b"), Vector3(0, 0, 0))
	mb.quad_out(Vector3(-1.0, 2.0, 0.7), Vector3(1.0, 2.0, 0.7), Vector3(1.0, 2.5, 0), Vector3(-1.0, 2.5, 0), Color("a5482f"), Vector3(0, 0, 0))
	mb.cyl(Vector3(0.1, 1.5, 0), 0.12, 0.12, 0.3, 6, WOOD)

static func _shipping_bin(mb: MeshBuilder, v: int) -> void:
	mb.box(Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 0.9), WOOD)
	mb.box(Vector3(0, 0.84, -0.05), Vector3(1.5, 0.1, 1.0), WOOD_DARK, Vector3(-0.1, 0, 0))
	for x in [-0.6, 0.6]:
		mb.box(Vector3(x, 0.4, 0.46), Vector3(0.1, 0.8, 0.04), WOOD_DARK)
	mb.box(Vector3(0, 0.55, 0.47), Vector3(0.3, 0.22, 0.02), Color("f2c94c"))

static func _lamp(mb: MeshBuilder, v: int) -> void:
	mb.cyl(Vector3.ZERO, 0.12, 0.08, 0.2, 6, Color("3a3a3a"))
	mb.cyl(Vector3(0, 0.2, 0), 0.05, 0.05, 2.3, 5, Color("3a3a3a"))
	mb.box(Vector3(0, 2.5, 0), Vector3(0.36, 0.06, 0.36), Color("2a2a2a"))
	mb.surface("window")
	mb.box(Vector3(0, 2.3, 0), Vector3(0.26, 0.34, 0.26), Color("ffd27a"))
	mb.surface("vc")
	mb.cyl(Vector3(0, 2.53, 0), 0.2, 0.0, 0.2, 4, Color("2a2a2a"), Vector3(0, PI / 4, 0))

static func _notice_board(mb: MeshBuilder, v: int) -> void:
	for s in [-1, 1]:
		mb.cyl(Vector3(s * 0.9, 0, 0), 0.07, 0.07, 2.1, 5, WOOD_DARK)
	mb.box(Vector3(0, 1.35, 0), Vector3(1.9, 1.1, 0.08), WOOD)
	mb.box(Vector3(0, 2.05, 0), Vector3(2.2, 0.08, 0.5), Color("8a4a32"), Vector3(0.25, 0, 0))
	var paper := [Color("f4ead0"), Color("e8e0c8"), Color("f0e0d0")]
	for i in 5:
		mb.box(Vector3(-0.65 + i * 0.32, 1.35 + (0.15 if i % 2 == 0 else -0.12), 0.05), Vector3(0.24, 0.32, 0.01), paper[i % 3], Vector3(0, 0, mb.rng.randf_range(-0.12, 0.12)))

static func _fountain(mb: MeshBuilder, v: int) -> void:
	var r := 2.2 + v * 0.6
	mb.cyl(Vector3.ZERO, r, r, 0.6, 14, Color("b8b0a0"), Vector3.ZERO, false)
	mb.cyl(Vector3.ZERO, r - 0.25, r - 0.25, 0.61, 14, Color("8a8478"), Vector3.ZERO, false)
	mb.cyl(Vector3(0, 0.58, 0), r + 0.05, r + 0.05, 0.1, 14, Color("c8c0b0"), Vector3.ZERO, false)
	mb.surface("water")
	mb.disc(Vector3(0, 0.45, 0), r - 0.25, 14, Color.WHITE)
	mb.surface("vc")
	mb.cyl(Vector3.ZERO, 0.3, 0.22, 1.6, 8, Color("c8c0b0"))
	mb.cyl(Vector3(0, 1.6, 0), 0.7, 0.5, 0.2, 10, Color("c8c0b0"))
	if v >= 1:
		mb.cyl(Vector3(0, 1.8, 0), 0.15, 0.1, 0.8, 6, Color("c8c0b0"))
		mb.sphere(Vector3(0, 2.7, 0), Vector3.ONE * 0.25, Color("d8c070"), 3, 7)

static func _market_stall(mb: MeshBuilder, v: int) -> void:
	var cols := [Color("c0504a"), Color("4a7ab0"), Color("5a9a4a"), Color("d8a03a")]
	var c: Color = cols[v % cols.size()]
	mb.box(Vector3(0, 0.5, 0.4), Vector3(2.4, 1.0, 0.8), WOOD)
	mb.box(Vector3(0, 1.02, 0.4), Vector3(2.5, 0.06, 0.9), PLANK)
	for x in [-1.15, 1.15]:
		for z in [0.0, 0.8]:
			mb.box(Vector3(x, 1.25, z - 0.4), Vector3(0.1, 2.5, 0.1), WOOD_DARK)
	for i in 6:
		var x0 := -1.3 + i * 0.433
		var col := c if i % 2 == 0 else Color("f4ead0")
		mb.quad2(Vector3(x0, 2.5, -0.6), Vector3(x0 + 0.433, 2.5, -0.6), Vector3(x0 + 0.433, 2.2, 1.0), Vector3(x0, 2.2, 1.0), col)
	for i in 5:
		mb.sphere(Vector3(-0.8 + i * 0.4, 1.12, 0.45), Vector3.ONE * 0.1, [Color("e0442f"), Color("f2d24a"), Color("7fc25a"), Color("ef8a2c")][i % 4], 2, 5)

static func _cave_entrance(mb: MeshBuilder, v: int) -> void:
	# A rocky hillside mound with a dark mouth facing +Z
	var rock := Color("7a746c")
	mb.blob(Vector3(0, 1.6, -4.2), Vector3(7.0, 5.2, 5.2), rock, 0.12, 1)
	mb.blob(Vector3(-4.6, 0.6, -1.6), Vector3(3.0, 2.8, 2.8), rock.darkened(0.05), 0.15, 1)
	mb.blob(Vector3(4.8, 0.5, -1.9), Vector3(3.2, 2.6, 2.9), rock.lightened(0.04), 0.15, 1)
	mb.surface("plant")
	mb.blob(Vector3(-1.5, 6.4, -4.5), Vector3(3.5, 0.8, 2.5), Color("5f8f4a"), 0.25, 1)
	mb.blob(Vector3(3.0, 5.6, -3.5), Vector3(2.0, 0.6, 1.6), Color("4f7f3a"), 0.25, 1)
	mb.surface("vc")
	# mouth
	mb.surface("cave_cap")
	var mouth_w := 2.0
	var mouth_h := 2.6
	var z := 1.8
	for i in 10:
		var a0 := PI * i / 10.0
		var a1 := PI * (i + 1) / 10.0
		mb.tri(Vector3(0, 0.0, z), Vector3(cos(a0) * mouth_w, sin(a0) * mouth_h, z), Vector3(cos(a1) * mouth_w, sin(a1) * mouth_h, z), Color(0.02, 0.02, 0.03))
		mb.tri(Vector3(0, 0.0, z), Vector3(cos(a1) * mouth_w, sin(a1) * mouth_h, z), Vector3(cos(a0) * mouth_w, sin(a0) * mouth_h, z), Color(0.02, 0.02, 0.03))
	mb.surface("vc")
	for i in 9:
		var a := PI * i / 8.0
		mb.blob(Vector3(cos(a) * (mouth_w + 0.35), sin(a) * (mouth_h + 0.3), z - 0.1), Vector3(0.55, 0.5, 0.45), rock.darkened(0.12), 0.2, 0)
	# timber frame
	for s in [-1, 1]:
		mb.box(Vector3(s * 1.9, 1.3, z + 0.4), Vector3(0.3, 2.6, 0.3), WOOD_DARK)
	mb.box(Vector3(0, 2.65, z + 0.4), Vector3(4.4, 0.3, 0.35), WOOD_DARK)
	mb.surface("window")
	mb.box(Vector3(1.9, 2.0, z + 0.62), Vector3(0.2, 0.26, 0.2), Color("ffc860"))
	mb.surface("vc")
	# rail tracks leading in
	for i in 6:
		mb.box(Vector3(0, 0.05, z + 0.6 + i * 0.6), Vector3(1.4, 0.08, 0.16), WOOD_DARK)
	for s in [-1, 1]:
		mb.box(Vector3(s * 0.5, 0.1, z + 2.1), Vector3(0.06, 0.06, 3.6), Color("5a5a60"))

static func _house_body(mb: MeshBuilder, w: float, d: float, h: float, wall: Color, roof: Color, style: int, timber: bool) -> void:
	# walls
	mb.box(Vector3(0, h / 2, 0), Vector3(w, h, d), wall)
	mb.box(Vector3(0, 0.15, 0), Vector3(w + 0.15, 0.3, d + 0.15), STONE)
	if timber:
		var beam := WOOD_DARK
		for x in [-w / 2, w / 2]:
			for z in [-d / 2, d / 2]:
				mb.box(Vector3(x, h / 2, z), Vector3(0.22, h, 0.22), beam)
		mb.box(Vector3(0, h - 0.1, d / 2 + 0.02), Vector3(w, 0.18, 0.06), beam)
		mb.box(Vector3(0, h - 0.1, -d / 2 - 0.02), Vector3(w, 0.18, 0.06), beam)
		mb.box(Vector3(0, h * 0.5, d / 2 + 0.02), Vector3(w, 0.12, 0.06), beam)
	# roof
	var oh := 0.45
	var rh := w * 0.42 if style != 2 else 0.5
	var y := h
	var hw := w / 2 + oh
	var hd := d / 2 + oh
	mb.surface("vc_cut")
	if style == 1:
		# hip roof
		mb.quad_out(Vector3(-hw, y, hd), Vector3(hw, y, hd), Vector3(w * 0.15, y + rh, 0), Vector3(-w * 0.15, y + rh, 0), roof, Vector3(0, y, 0))
		mb.quad_out(Vector3(hw, y, -hd), Vector3(-hw, y, -hd), Vector3(-w * 0.15, y + rh, 0), Vector3(w * 0.15, y + rh, 0), roof.darkened(0.08), Vector3(0, y, 0))
		mb.tri_out(Vector3(-hw, y, -hd), Vector3(-hw, y, hd), Vector3(-w * 0.15, y + rh, 0), roof.darkened(0.04), Vector3(0, y, 0))
		mb.tri_out(Vector3(hw, y, hd), Vector3(hw, y, -hd), Vector3(w * 0.15, y + rh, 0), roof.darkened(0.12), Vector3(0, y, 0))
	elif style == 2:
		mb.box(Vector3(0, y + 0.2, 0), Vector3(w + oh * 2, 0.4, d + oh * 2), roof)
	else:
		# gable roof, ridge along X
		var t := 0.12
		mb.quad_out(Vector3(-hw, y - t, hd), Vector3(hw, y - t, hd), Vector3(hw, y + rh, 0), Vector3(-hw, y + rh, 0), roof, Vector3(0, y, 0))
		mb.quad_out(Vector3(hw, y - t, -hd), Vector3(-hw, y - t, -hd), Vector3(-hw, y + rh, 0), Vector3(hw, y + rh, 0), roof.darkened(0.1), Vector3(0, y, 0))
		mb.surface("vc")
		mb.tri_out(Vector3(-w / 2, y, d / 2), Vector3(-w / 2, y, -d / 2), Vector3(-w / 2, y + rh * 0.92, 0), wall.darkened(0.05), Vector3(0, y, 0))
		mb.tri_out(Vector3(w / 2, y, -d / 2), Vector3(w / 2, y, d / 2), Vector3(w / 2, y + rh * 0.92, 0), wall.darkened(0.05), Vector3(0, y, 0))
		mb.surface("vc_cut")
		# ridge beam
		mb.box(Vector3(0, y + rh + 0.03, 0), Vector3(w + oh * 2 + 0.1, 0.14, 0.18), roof.darkened(0.3))
	mb.surface("vc")

static func _windows(mb: MeshBuilder, w: float, d: float, h: float, floors: int, door_x: float) -> void:
	for f in floors:
		var y := 1.45 + f * 2.4
		var count := int(w / 2.2)
		for i in count:
			var x := -w / 2 + (i + 0.5) * (w / count)
			if f == 0 and abs(x - door_x) < 1.0:
				continue
			mb.box(Vector3(x, y, d / 2 + 0.04), Vector3(0.9, 0.95, 0.08), WOOD_DARK)
			mb.surface("window")
			mb.box(Vector3(x, y, d / 2 + 0.07), Vector3(0.7, 0.75, 0.04), Color("ffe1a0"))
			mb.surface("vc")
			mb.box(Vector3(x, y, d / 2 + 0.1), Vector3(0.06, 0.75, 0.03), WOOD_DARK)
			mb.box(Vector3(x, y - 0.5, d / 2 + 0.12), Vector3(1.0, 0.08, 0.2), WOOD_DARK)
		# side windows
		for s in [-1, 1]:
			mb.box(Vector3(s * (w / 2 + 0.04), y, 0), Vector3(0.08, 0.9, 0.9), WOOD_DARK)
			mb.surface("window")
			mb.box(Vector3(s * (w / 2 + 0.07), y, 0), Vector3(0.04, 0.72, 0.72), Color("ffe1a0"))
			mb.surface("vc")

static func _door(mb: MeshBuilder, x: float, d: float, col: Color) -> void:
	mb.box(Vector3(x, 1.05, d / 2 + 0.04), Vector3(1.15, 2.15, 0.1), WOOD_DARK)
	mb.box(Vector3(x, 1.0, d / 2 + 0.08), Vector3(0.95, 2.0, 0.06), col)
	mb.sphere(Vector3(x + 0.32, 1.0, d / 2 + 0.13), Vector3.ONE * 0.05, Color("d8b04a"), 2, 4)
	mb.box(Vector3(x, 0.08, d / 2 + 0.5), Vector3(1.5, 0.16, 0.8), STONE)

## Town building. Params packed into a dictionary for variety.
static func building(p: Dictionary) -> Mesh:
	var mb := MeshBuilder.new(int(p.get("seed", 1)))
	var w: float = p.get("w", 6.0)
	var d: float = p.get("d", 5.0)
	var floors: int = p.get("floors", 1)
	var h := 2.9 + (floors - 1) * 2.4
	var wall: Color = p.get("wall", WALL_COLORS[0])
	var roof: Color = p.get("roof", ROOF_COLORS[0])
	var style: int = p.get("style", 0)
	_house_body(mb, w, d, h, wall, roof, style, p.get("timber", false))
	var door_x: float = p.get("door_x", 0.0)
	_door(mb, door_x, d, p.get("door", Color("8a4a2a")))
	_windows(mb, w, d, h, floors, door_x)
	if p.get("chimney", true):
		mb.surface("vc_cut")
		mb.box(Vector3(w * 0.28, h + w * 0.3, -d * 0.15), Vector3(0.6, w * 0.5, 0.6), Color("8a5a4a"))
		mb.surface("vc")
	if p.get("awning", false):
		var ac: Color = p.get("awning_col", Color("c0504a"))
		for i in 6:
			var x0 := -w / 2 + i * (w / 6.0)
			mb.quad2(Vector3(x0, 2.6, d / 2), Vector3(x0 + w / 6.0, 2.6, d / 2), Vector3(x0 + w / 6.0, 2.25, d / 2 + 1.3), Vector3(x0, 2.25, d / 2 + 1.3), ac if i % 2 == 0 else Color("f4ead0"))
	if p.get("sign", false):
		var sc: Color = p.get("sign_col", Color("f2c94c"))
		mb.box(Vector3(door_x + 1.1, 2.55, d / 2 + 0.6), Vector3(0.06, 0.06, 0.9), Color("3a3a3a"))
		mb.box(Vector3(door_x + 1.1, 2.15, d / 2 + 0.9), Vector3(0.08, 0.7, 0.7), WOOD)
		mb.box(Vector3(door_x + 1.16, 2.15, d / 2 + 0.9), Vector3(0.04, 0.42, 0.42), sc)
	if p.get("counter", false):
		mb.box(Vector3(door_x - 1.6, 0.5, d / 2 + 1.6), Vector3(1.8, 1.0, 0.6), WOOD)
		mb.box(Vector3(door_x - 1.6, 1.03, d / 2 + 1.6), Vector3(1.9, 0.07, 0.7), PLANK)
	if p.get("flowers", false):
		mb.surface("plant")
		for s in [-1, 1]:
			mb.blob(Vector3(door_x + s * 1.3, 0.35, d / 2 + 0.3), Vector3(0.35, 0.25, 0.25), Color("4f8a3a"), 0.2, 1)
		mb.surface("vc")
		for i in 6:
			mb.sphere(Vector3(door_x + (-1 if i < 3 else 1) * 1.3 + mb.rng.randf_range(-0.25, 0.25), 0.55, d / 2 + 0.3 + mb.rng.randf_range(-0.1, 0.1)), Vector3.ONE * 0.07, [Color("e86a8a"), Color("f2d04b"), Color("f4f2ea")][i % 3], 2, 4)
	return mb.commit()

static func _farmhouse(mb: MeshBuilder, v: int) -> void:
	# v = upgrade level 0..2
	var w := 7.0 + v * 2.5
	var d := 5.5 + v * 1.5
	var floors := 1 if v < 2 else 2
	var h := 2.9 + (floors - 1) * 2.4
	var wall := Color("e9d6b0") if v == 0 else Color("f1e2c4")
	_house_body(mb, w, d, h, wall, Color("b5523b"), 0, v >= 1)
	_door(mb, -0.8, d, Color("7a3a24"))
	_windows(mb, w, d, h, floors, -0.8)
	mb.surface("vc_cut")
	mb.box(Vector3(w * 0.3, h + w * 0.32, -d * 0.1), Vector3(0.7, w * 0.5, 0.7), Color("9a6a5a"))
	mb.surface("vc")
	# porch
	mb.box(Vector3(-0.8, 0.12, d / 2 + 1.0), Vector3(3.6 + v, 0.24, 1.8), PLANK)
	for s in [-1, 1]:
		mb.box(Vector3(-0.8 + s * (1.7 + v * 0.5), 1.25, d / 2 + 1.8), Vector3(0.14, 2.3, 0.14), WOOD_DARK)
	mb.box(Vector3(-0.8, 2.45, d / 2 + 1.1), Vector3(3.9 + v, 0.1, 2.0), Color("a5482f"), Vector3(0.18, 0, 0))
	if v >= 1:
		mb.surface("plant")
		for i in 3:
			mb.blob(Vector3(w / 2 - 0.8 - i * 1.1, 0.3, d / 2 + 0.35), Vector3(0.4, 0.28, 0.26), Color("4f8a3a"), 0.2, 1)
		mb.surface("vc")
		for i in 8:
			mb.sphere(Vector3(w / 2 - 0.5 - i * 0.4, 0.55, d / 2 + 0.4), Vector3.ONE * 0.07, [Color("e86a8a"), Color("f2d04b"), Color("8a6ad8")][i % 3], 2, 4)
	if v >= 2:
		# side workshop wing
		mb.box(Vector3(-w / 2 - 2.0, 1.4, 0), Vector3(4.0, 2.8, d - 1.0), Color("c8a880"))
		mb.surface("vc_cut")
		mb.box(Vector3(-w / 2 - 2.0, 2.95, 0), Vector3(4.6, 0.3, d - 0.4), Color("8a4a32"))
		mb.surface("vc")

static func _bench(mb: MeshBuilder) -> void:
	mb.box(Vector3(0, 0.45, 0), Vector3(1.6, 0.08, 0.5), WOOD)
	mb.box(Vector3(0, 0.8, -0.22), Vector3(1.6, 0.4, 0.06), WOOD)
	for x in [-0.7, 0.7]:
		mb.box(Vector3(x, 0.22, 0), Vector3(0.08, 0.45, 0.45), WOOD_DARK)

static func _hot_spring(mb: MeshBuilder, v: int) -> void:
	for i in 14:
		var a := TAU * i / 14.0
		var r := 3.2 + mb.rng.randf_range(-0.2, 0.3)
		mb.blob(Vector3(cos(a) * r, 0.1, sin(a) * r), Vector3(0.7, 0.45, 0.6), Color("8a8580").lerp(Color("a89a88"), mb.rng.randf()), 0.2, 0)

static func _lookout(mb: MeshBuilder, v: int) -> void:
	mb.blob(Vector3(0, 1.4, 0), Vector3(3.0, 2.4, 2.6), Color("8a8478"), 0.15, 1)
	mb.blob(Vector3(2.2, 0.8, 1.0), Vector3(1.8, 1.6, 1.6), Color("7a7468"), 0.18, 1)
	mb.blob(Vector3(-1.8, 2.8, -0.4), Vector3(1.6, 1.4, 1.5), Color("948e84"), 0.15, 1)
	mb.surface("plant")
	mb.blob(Vector3(0.2, 3.5, 0.2), Vector3(1.6, 0.4, 1.4), Color("5f8f4a"), 0.25, 1)
	mb.surface("vc")

static func _lodge(mb: MeshBuilder, v: int) -> void:
	_house_body(mb, 8.0, 6.0, 3.0, Color("b89a78"), Color("4f6a7a"), 0, true)
	_door(mb, 0.0, 6.0, Color("5a3a24"))
	_windows(mb, 8.0, 6.0, 3.0, 1, 0.0)
	mb.box(Vector3(0, 3.6, 3.3), Vector3(3.0, 0.7, 0.12), PLANK)
	mb.surface("window")
	mb.box(Vector3(0, 3.6, 3.38), Vector3(1.0, 0.3, 0.04), Color("ffd27a"))
	mb.surface("vc")

static func _cart(mb: MeshBuilder, v: int) -> void:
	mb.box(Vector3(0, 0.7, 0), Vector3(1.2, 0.6, 1.6), Color("6a6a70"))
	mb.box(Vector3(0, 1.0, 0), Vector3(1.0, 0.1, 1.4), Color("3a3a3a"))
	for x in [-0.62, 0.62]:
		for z in [-0.5, 0.5]:
			mb.cyl(Vector3(x, 0.3, z), 0.28, 0.28, 0.1, 8, Color("3a3a3a"), Vector3(0, 0, PI / 2), true, true)
	if v == 1:
		for i in 6:
			mb.blob(Vector3(mb.rng.randf_range(-0.35, 0.35), 1.1, mb.rng.randf_range(-0.5, 0.5)), Vector3.ONE * 0.2, Color("c8743a"), 0.3, 0)

static func _scaffold(mb: MeshBuilder, v: int) -> void:
	var w := 6.0
	var d := 5.0
	for x in [-w / 2, 0.0, w / 2]:
		for z in [-d / 2, d / 2]:
			mb.box(Vector3(x, 1.8, z), Vector3(0.14, 3.6, 0.14), WOOD)
	for y in [1.2, 2.6]:
		mb.box(Vector3(0, y, d / 2), Vector3(w, 0.1, 0.3), PLANK)
		mb.box(Vector3(0, y, -d / 2), Vector3(w, 0.1, 0.3), PLANK)
	mb.box(Vector3(0, 0.3, 0), Vector3(w - 0.5, 0.6, d - 0.5), STONE)
	_crate(mb, Vector3(w / 2 + 0.8, 0, 0.5), 0.7, WOOD)
	for i in 5:
		mb.cyl(Vector3(-w / 2 - 0.6, 0.1 + i * 0.16, -0.5 + (i % 2) * 0.1), 0.08, 0.08, 1.8, 5, WOOD, Vector3(PI / 2, 0, 0))

static func _flower_bed(mb: MeshBuilder, v: int) -> void:
	mb.box(Vector3(0, 0.15, 0), Vector3(2.0, 0.3, 0.8), Color("8a6a4a"))
	mb.box(Vector3(0, 0.3, 0), Vector3(1.85, 0.04, 0.65), Color("4a3424"))
	mb.surface("plant")
	mb.blob(Vector3(0, 0.45, 0), Vector3(0.9, 0.2, 0.3), Color("4f8a3a"), 0.25, 1)
	mb.surface("vc")
	for i in 10:
		mb.sphere(Vector3(-0.8 + i * 0.18, 0.62, mb.rng.randf_range(-0.2, 0.2)), Vector3.ONE * 0.08, [Color("e86a8a"), Color("f2d04b"), Color("f4f2ea"), Color("8a6ad8")][(i + v) % 4], 2, 4)

static func _bunting(mb: MeshBuilder, v: int) -> void:
	var l := 8.0
	var cols := [Color("e0524a"), Color("f2d04b"), Color("4a7ab0"), Color("5cbf4a"), Color("f4f2ea")]
	for i in 12:
		var x := -l / 2 + i * (l / 12.0)
		var sag := sin(PI * i / 12.0) * 0.6
		mb.tri(Vector3(x, -sag, 0), Vector3(x + 0.6, -sag, 0), Vector3(x + 0.3, -sag - 0.5, 0), cols[i % cols.size()])
		mb.tri(Vector3(x + 0.6, -sag, 0), Vector3(x, -sag, 0), Vector3(x + 0.3, -sag - 0.5, 0), cols[i % cols.size()])

static func _soil_bed(mb: MeshBuilder, v: int) -> void:
	mb.box(Vector3(0, 0.1, 0), Vector3(2.0, 0.2, 0.9), WOOD_DARK)
	mb.box(Vector3(0, 0.19, 0), Vector3(1.85, 0.04, 0.78), Color("5a3e26"))

## A 4 m run of dry-stone wall (variants vary the stones), running along X.
static func _stone_wall(mb: MeshBuilder, v: int) -> void:
	var x := -2.0
	while x < 2.0:
		var w := mb.rng.randf_range(0.45, 0.8)
		var h := mb.rng.randf_range(1.0, 1.3)
		var c: Color = STONE.lerp(Color("a8a090"), mb.rng.randf()).lerp(Color("7a766e"), mb.rng.randf() * 0.4)
		mb.box(Vector3(x + w / 2.0, h / 2.0, mb.rng.randf_range(-0.05, 0.05)), Vector3(w - 0.04, h, 0.75), c)
		x += w
	mb.box(Vector3(0, 1.32, 0), Vector3(4.0, 0.14, 0.85), STONE_DARK)
	if v % 2 == 0:
		mb.surface("plant")
		mb.blob(Vector3(mb.rng.randf_range(-1.4, 1.4), 1.35, 0.1), Vector3(0.5, 0.2, 0.35), Color("4f8a3a"), 0.3, 1)
		mb.surface("vc")

## A 4 m run of hedgerow along X.
static func _hedge(mb: MeshBuilder, v: int) -> void:
	mb.surface("plant")
	for i in 4:
		mb.blob(Vector3(-1.5 + i, 0.75, mb.rng.randf_range(-0.1, 0.1)), Vector3(0.75, 0.8, 0.55), LEAF.darkened(mb.rng.randf_range(0.0, 0.2)), 0.2, 1)
	mb.surface("vc")
	for i in 3:
		mb.sphere(Vector3(mb.rng.randf_range(-1.8, 1.8), mb.rng.randf_range(0.8, 1.4), 0.5), Vector3.ONE * 0.07, Color("f4f2ea"), 2, 4)

## A timber arch over a path, crossbeam along X.
static func _gate_arch(mb: MeshBuilder, v: int) -> void:
	for s in [-1.0, 1.0]:
		mb.box(Vector3(s * 1.8, 1.4, 0), Vector3(0.28, 2.8, 0.28), WOOD_DARK)
		mb.box(Vector3(s * 1.8, 0.1, 0), Vector3(0.6, 0.2, 0.6), STONE)
	mb.box(Vector3(0, 2.85, 0), Vector3(4.3, 0.26, 0.36), WOOD_DARK)
	mb.box(Vector3(0, 2.5, 0), Vector3(2.4, 0.42, 0.08), PLANK)
	mb.surface("plant")
	for s in [-1.0, 1.0]:
		mb.blob(Vector3(s * 1.8, 2.7, 0.2), Vector3(0.45, 0.35, 0.3), LEAF, 0.3, 1)
	mb.surface("vc")

## A signboard on two posts naming the place beyond.
static func _wayboard(mb: MeshBuilder, v: int) -> void:
	for s in [-1.0, 1.0]:
		mb.cyl(Vector3(s * 0.55, 0, 0), 0.06, 0.05, 1.6, 5, WOOD_DARK)
	mb.box(Vector3(0, 1.25, 0), Vector3(1.4, 0.5, 0.07), PLANK)
	mb.box(Vector3(0, 1.25, 0.04), Vector3(1.2, 0.34, 0.02), PLANK.darkened(0.2))
	mb.box(Vector3(0.75, 1.25, 0.0), Vector3(0.25, 0.25, 0.07), PLANK, Vector3(0, 0, PI / 4))
