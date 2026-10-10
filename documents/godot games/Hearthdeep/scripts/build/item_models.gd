class_name ItemModels
extends RefCounted
## 3D models for items: held tools & weapons, dropped items, crops by growth
## stage, forage plants and placeable objects.

const WOOD := Color("a8774a")
const WOOD_DARK := Color("6b4a32")

# ------------------------------------------------------------------ held

static func held_mesh(id: String) -> Mesh:
	if id == "":
		return null
	var d := Items.def(id)
	if not (d.has("tool") or d.has("weapon")):
		return drop_mesh(id, 0.6)
	return Meshes.cached("held:" + id, func(): return _build_held(id))

static func _tier_col(id: String) -> Color:
	var d := Items.def(id)
	return d["icon"][1]

static func _build_held(id: String) -> Mesh:
	var d := Items.def(id)
	var mb := MeshBuilder.new(id.hash())
	var c := _tier_col(id)
	var kind: String = d["tool"]["kind"] if d.has("tool") else d["weapon"]["kind"]
	match kind:
		"hoe":
			mb.cyl(Vector3(0, -0.15, 0), 0.03, 0.03, 1.0, 5, WOOD)
			mb.box(Vector3(0, 0.85, 0.12), Vector3(0.18, 0.05, 0.28), c)
		"can":
			mb.cyl(Vector3(0, -0.1, 0.1), 0.15, 0.13, 0.28, 8, c, Vector3(PI / 2, 0, 0))
			mb.cyl(Vector3(0, -0.05, 0.25), 0.03, 0.02, 0.3, 5, c.darkened(0.1), Vector3(1.0, 0, 0))
			mb.box(Vector3(0, 0.08, 0.1), Vector3(0.04, 0.04, 0.22), c.darkened(0.2))
		"axe":
			mb.cyl(Vector3(0, -0.15, 0), 0.03, 0.03, 0.85, 5, WOOD)
			mb.box(Vector3(0, 0.6, 0.1), Vector3(0.05, 0.22, 0.2), c)
			mb.box(Vector3(0, 0.6, 0.22), Vector3(0.04, 0.3, 0.06), c.lightened(0.2))
		"pick":
			mb.cyl(Vector3(0, -0.15, 0), 0.03, 0.03, 0.9, 5, WOOD)
			mb.cyl(Vector3(0, 0.72, -0.32), 0.04, 0.0, 0.64, 5, c, Vector3(PI / 2, 0, 0), false)
			mb.cyl(Vector3(0, 0.72, 0.32), 0.04, 0.0, 0.64, 5, c, Vector3(-PI / 2, 0, 0), false)
		"rod":
			mb.cyl(Vector3(0, -0.2, 0), 0.025, 0.012, 1.7, 5, c)
			mb.cyl(Vector3(0, 0.0, 0.04), 0.05, 0.05, 0.08, 6, Color("4a4a4a"), Vector3(PI / 2, 0, 0))
		"sword":
			mb.cyl(Vector3(0, -0.15, 0), 0.03, 0.03, 0.2, 5, WOOD_DARK)
			mb.box(Vector3(0, 0.07, 0), Vector3(0.24, 0.04, 0.06), c.darkened(0.25))
			mb.box(Vector3(0, 0.5, 0), Vector3(0.08, 0.8, 0.02), c.lightened(0.15))
			mb.cone(Vector3(0, 0.9, 0), 0.06, 0.15, 4, c.lightened(0.2), Vector3(0, PI / 4, 0))
		"spear":
			mb.cyl(Vector3(0, -0.5, 0), 0.03, 0.03, 1.9, 5, WOOD)
			mb.cone(Vector3(0, 1.4, 0), 0.07, 0.35, 4, c.lightened(0.15))
		"hammer":
			mb.cyl(Vector3(0, -0.2, 0), 0.035, 0.035, 1.0, 5, WOOD)
			mb.box(Vector3(0, 0.8, 0), Vector3(0.22, 0.24, 0.42), c)
		"dagger":
			mb.cyl(Vector3(0, -0.1, 0), 0.025, 0.025, 0.14, 5, WOOD_DARK)
			mb.box(Vector3(0, 0.05, 0), Vector3(0.14, 0.03, 0.05), c.darkened(0.25))
			mb.cone(Vector3(0, 0.07, 0), 0.04, 0.32, 4, c.lightened(0.2))
		"bow":
			mb.cyl(Vector3.ZERO, 0.028, 0.02, 0.62, 5, c, Vector3(0.38, 0, 0))
			mb.cyl(Vector3.ZERO, 0.028, 0.02, 0.62, 5, c.darkened(0.1), Vector3(PI - 0.38, 0, 0))
			mb.box(Vector3(0, 0, 0.23), Vector3(0.012, 1.16, 0.012), Color("f0ece0"))
	return mb.commit()

# ------------------------------------------------------------------ drops

static func drop_mesh(id: String, scl: float = 1.0) -> Mesh:
	return Meshes.cached("drop:%s:%.2f" % [id, scl], func(): return _build_drop(id, scl))

static func _build_drop(id: String, s: float) -> Mesh:
	var d := Items.def(id)
	var icon: Array = d["icon"]
	var shape: String = icon[0]
	var c: Color = icon[1]
	var c2: Color = icon[2] if icon.size() > 2 else c.lightened(0.3)
	var mb := MeshBuilder.new(id.hash())
	var mat := "vc"
	match shape:
		"round", "egg", "nut":
			mb.sphere(Vector3(0, 0.16 * s, 0), Vector3(0.15, 0.15 if shape != "egg" else 0.19, 0.15) * s, c, 4, 7)
			if shape == "round":
				mb.surface("plant")
				mb.blade(Vector3(0, 0.29 * s, 0), 0.08 * s, 0.1 * s, Vector3(0.05, 0, 0) * s, c2 if c2 != c else Color("4a8a3a"))
				mb.surface(mat)
		"long":
			mb.cone(Vector3(0, 0.06 * s, 0), 0.08 * s, 0.32 * s, 6, c, Vector3(PI / 2.3, 0, 0))
			mb.surface("plant")
			mb.blade(Vector3(0, 0.08 * s, -0.04 * s), 0.1 * s, 0.18 * s, Vector3(0, 0, -0.1) * s, c2)
			mb.surface(mat)
		"berry", "grain":
			for i in 6:
				mb.sphere(Vector3(mb.rng.randf_range(-0.09, 0.09), 0.08 + mb.rng.randf_range(0, 0.12), mb.rng.randf_range(-0.09, 0.09)) * s, Vector3.ONE * 0.065 * s, c, 2, 5)
		"fish":
			mb.sphere(Vector3(0, 0.12 * s, 0), Vector3(0.09, 0.1, 0.28) * s, c, 4, 7, 0.0, Vector3.ZERO, c2)
			mb.cone(Vector3(0, 0.12 * s, -0.24 * s), 0.1 * s, 0.14 * s, 4, c.darkened(0.15), Vector3(-PI / 2, 0, 0))
		"ore", "stone", "clay", "core":
			mb.blob(Vector3(0, 0.14 * s, 0), Vector3(0.18, 0.13, 0.16) * s, c, 0.25, 1)
			if shape == "ore" and c2 != c:
				mb.surface("vc_shiny")
				for i in 4:
					mb.blob(Vector3(mb.rng.randf_range(-0.1, 0.1), 0.2, mb.rng.randf_range(-0.1, 0.1)) * s, Vector3.ONE * 0.05 * s, c2, 0.3, 0)
				mb.surface(mat)
		"bar":
			mb.surface("vc_shiny")
			mb.box(Vector3(0, 0.07 * s, 0), Vector3(0.32, 0.12, 0.16) * s, c)
			mb.surface(mat)
		"gem", "crystal":
			mb.surface("glow_steady" if shape == "crystal" else "vc_shiny")
			mb.cyl(Vector3(0, 0.05 * s, 0), 0.0, 0.12 * s, 0.12 * s, 6, c)
			mb.cyl(Vector3(0, 0.17 * s, 0), 0.12 * s, 0.0, 0.16 * s, 6, c.lightened(0.2))
			mb.surface(mat)
		"bottle", "mug":
			mb.surface("vc_shiny")
			mb.cyl(Vector3.ZERO, 0.1 * s, 0.1 * s, 0.22 * s, 7, c)
			mb.cyl(Vector3(0, 0.22 * s, 0), 0.04 * s, 0.04 * s, 0.1 * s, 5, Color("e8e0d0"))
			mb.surface(mat)
		"log", "fiber", "feather":
			mb.cyl(Vector3(-0.18 * s, 0.08 * s, 0), 0.07 * s, 0.07 * s, 0.36 * s, 6, c, Vector3(0, 0, -PI / 2), true, true, c2)
		"mushroom":
			mb.cyl(Vector3.ZERO, 0.05 * s, 0.04 * s, 0.14 * s, 5, c2 if c2 != c else Color("efe6d8"))
			mb.sphere(Vector3(0, 0.15 * s, 0), Vector3(0.14, 0.08, 0.14) * s, c, 3, 7)
		"herb", "leaf", "flower":
			mb.surface("plant")
			mb.blob(Vector3(0, 0.1 * s, 0), Vector3(0.14, 0.1, 0.14) * s, c, 0.3, 1)
			mb.surface(mat)
		"seed", "bag":
			mb.box(Vector3(0, 0.12 * s, 0), Vector3(0.2, 0.24, 0.05) * s, Color("e9dcb4"))
			mb.box(Vector3(0, 0.12 * s, 0.03 * s), Vector3(0.12, 0.12, 0.01) * s, c)
		"coin", "ring", "amulet":
			mb.surface("vc_shiny")
			mb.cyl(Vector3(0, 0.02, 0), 0.1 * s, 0.1 * s, 0.03 * s, 8, c)
			mb.surface(mat)
		_:
			mb.box(Vector3(0, 0.12 * s, 0), Vector3(0.24, 0.24, 0.24) * s, c)
	return mb.commit()

# ------------------------------------------------------------------ forage plants

static func forage_mesh(id: String) -> Mesh:
	return Meshes.cached("forage:" + id, func(): return _build_forage(id))

static func _build_forage(id: String) -> Mesh:
	var d := Items.def(id)
	var icon: Array = d["icon"]
	var c: Color = icon[1]
	var c2: Color = icon[2] if icon.size() > 2 else c.lightened(0.3)
	var mb := MeshBuilder.new(id.hash())
	var glow := id in ["glowcap", "crystalbloom", "ghostbloom", "emberlily", "starfern", "moonshroom", "glowgrub"]
	match icon[0]:
		"mushroom":
			for i in 3:
				var p := Vector3(mb.rng.randf_range(-0.18, 0.18), 0, mb.rng.randf_range(-0.18, 0.18))
				var s := mb.rng.randf_range(0.8, 1.3)
				mb.cyl(p, 0.05 * s, 0.04 * s, 0.2 * s, 5, c2)
				if glow:
					mb.surface("glow")
				mb.sphere(p + Vector3(0, 0.2 * s, 0), Vector3(0.15, 0.08, 0.15) * s, c, 3, 7)
				mb.surface("vc")
		"flower":
			mb.surface("plant")
			for i in 4:
				var a := TAU * i / 4.0
				mb.blade(Vector3(cos(a) * 0.05, 0, sin(a) * 0.05), 0.07, 0.3, Vector3(cos(a) * 0.1, 0, sin(a) * 0.1), Color("4f8a34"))
			mb.surface("glow" if glow else "vc")
			for i in 3:
				var p2 := Vector3(mb.rng.randf_range(-0.12, 0.12), mb.rng.randf_range(0.3, 0.42), mb.rng.randf_range(-0.12, 0.12))
				mb.blob(p2, Vector3(0.09, 0.05, 0.09), c, 0.15, 0)
			mb.surface("vc")
		"berry":
			mb.surface("plant")
			mb.blob(Vector3(0, 0.15, 0), Vector3(0.3, 0.18, 0.3), Color("4a7a3a"), 0.2, 1)
			mb.surface("vc")
			for i in 8:
				var a := mb.rng.randf() * TAU
				mb.sphere(Vector3(cos(a) * 0.22, mb.rng.randf_range(0.12, 0.3), sin(a) * 0.22), Vector3.ONE * 0.06, c, 2, 5)
		"long":
			mb.sphere(Vector3(0, 0.0, 0), Vector3(0.22, 0.07, 0.22), Color("6a4a32"), 2, 6)
			mb.surface("plant")
			for i in 4:
				var a := TAU * i / 4.0
				mb.blade(Vector3.ZERO, 0.07, 0.35, Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), c2)
			mb.surface("vc")
		"nut", "round":
			for i in 4:
				mb.sphere(Vector3(mb.rng.randf_range(-0.14, 0.14), 0.06, mb.rng.randf_range(-0.14, 0.14)), Vector3.ONE * 0.07, c, 2, 5)
			mb.surface("plant")
			mb.blob(Vector3(0, 0.04, 0), Vector3(0.2, 0.04, 0.2), Color("6a7a3a"), 0.3, 0)
			mb.surface("vc")
		"honey":
			mb.blob(Vector3(0, 0.15, 0), Vector3(0.2, 0.15, 0.12), c, 0.15, 1)
		"feather":
			mb.surface("plant")
			mb.blade(Vector3(0, 0.02, 0), 0.08, 0.35, Vector3(0.1, -0.25, 0.1), c)
			mb.surface("vc")
		"worm":
			mb.surface("glow" if glow else "vc")
			mb.cyl(Vector3(-0.1, 0.04, 0), 0.04, 0.03, 0.22, 5, c, Vector3(0, 0.4, -PI / 2))
			mb.surface("vc")
		_:
			mb.surface("glow" if glow else "plant")
			mb.blob(Vector3(0, 0.14, 0), Vector3(0.22, 0.14, 0.22), c, 0.25, 1)
			mb.surface("vc")
	return mb.commit()

# ------------------------------------------------------------------ crops

## stage 0 = seeded, 1-3 growing, 4 = ready.
static func crop_mesh(crop: String, stage: int) -> Mesh:
	return Meshes.cached("crop:%s:%d" % [crop, stage], func(): return _build_crop(crop, stage))

static func _build_crop(crop: String, stage: int) -> Mesh:
	var cd: Dictionary = Items.crops.get(crop, {})
	var model: String = cd.get("model", "herb")
	var c: Color = cd.get("color", Color.GREEN)
	var mb := MeshBuilder.new(crop.hash() + stage)
	var leaf := Color("5a9a3a")
	if stage == 0:
		mb.surface("vc_nosnow")
		for i in 3:
			mb.sphere(Vector3(mb.rng.randf_range(-0.12, 0.12), 0.03, mb.rng.randf_range(-0.12, 0.12)), Vector3.ONE * 0.03, Color("d8c890"), 2, 4)
		mb.surface("vc")
		return mb.commit()
	var g := float(stage) / 4.0
	mb.surface("plant")
	match model:
		"bulb":
			for i in 3 + stage:
				var a := TAU * i / (3 + stage)
				mb.blade(Vector3.ZERO, 0.08, 0.15 + g * 0.35, Vector3(cos(a), 0, sin(a)) * 0.12 * g, leaf, leaf.lightened(0.2))
			if stage == 4:
				mb.surface("vc")
				if crop in ["carrot", "emberroot", "frostleek"]:
					mb.cyl(Vector3(0, -0.05, 0), 0.07, 0.09, 0.12, 6, c)
				else:
					mb.sphere(Vector3(0, 0.07, 0), Vector3(0.13, 0.11, 0.13), c, 3, 7)
		"bush":
			mb.blob(Vector3(0, 0.1 + 0.2 * g, 0), Vector3(0.12 + 0.22 * g, 0.1 + 0.2 * g, 0.12 + 0.22 * g), leaf.darkened(0.05), 0.2, 1)
			if stage == 4:
				mb.surface("vc")
				for i in 6:
					var a := mb.rng.randf() * TAU
					mb.sphere(Vector3(cos(a) * 0.28, mb.rng.randf_range(0.2, 0.5), sin(a) * 0.28), Vector3.ONE * (0.07 if crop != "potato" else 0.05), c, 2, 5)
		"vine":
			mb.surface("vc")
			mb.cyl(Vector3.ZERO, 0.025, 0.02, 0.4 + 0.9 * g, 4, WOOD)
			mb.surface("plant")
			for i in stage * 2:
				var y := 0.15 + i * 0.12
				var a := i * 2.1
				mb.blob(Vector3(cos(a) * 0.1, y, sin(a) * 0.1), Vector3(0.12, 0.08, 0.12), leaf, 0.2, 0)
			if stage == 4:
				mb.surface("vc")
				for i in 5:
					var a2 := i * 1.3
					mb.sphere(Vector3(cos(a2) * 0.16, 0.3 + i * 0.15, sin(a2) * 0.16), Vector3.ONE * (0.08 if crop != "hops" else 0.06), c, 3, 6)
		"stalk":
			for i in 4:
				var a := TAU * i / 4.0
				mb.blade(Vector3(cos(a) * 0.04, 0, sin(a) * 0.04), 0.07, 0.3 + g * (1.3 if crop == "corn" else 0.7), Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), leaf.lerp(Color("c8b860"), 0.3 * g))
			if stage == 4:
				mb.surface("vc")
				if crop == "corn":
					for s in [-1, 1]:
						mb.cyl(Vector3(s * 0.08, 0.6, 0), 0.05, 0.04, 0.3, 6, c, Vector3(0, 0, s * 0.3))
				else:
					for i in 4:
						var a3 := TAU * i / 4.0
						mb.cyl(Vector3(cos(a3) * 0.1, 0.75, sin(a3) * 0.1), 0.03, 0.02, 0.2, 4, c)
		"gourd":
			for i in 3 + stage:
				var a := TAU * i / (3 + stage)
				mb.blob(Vector3(cos(a) * 0.25 * g, 0.08, sin(a) * 0.25 * g), Vector3(0.15, 0.06, 0.15), leaf, 0.2, 0)
			if stage >= 3:
				mb.surface("vc")
				var gs := 0.12 if stage == 3 else 0.3
				mb.sphere(Vector3(0.1, gs * 0.8, 0.05), Vector3(gs, gs * 0.8, gs), c if stage == 4 else leaf.lightened(0.15), 4, 9)
		"herb":
			mb.blob(Vector3(0, 0.08 + 0.12 * g, 0), Vector3(0.1 + 0.15 * g, 0.08 + 0.13 * g, 0.1 + 0.15 * g), c.lerp(leaf, 0.3), 0.25, 1)
		"reed":
			for i in 5:
				mb.blade(Vector3(mb.rng.randf_range(-0.08, 0.08), 0, mb.rng.randf_range(-0.08, 0.08)), 0.05, 0.25 + 0.6 * g, Vector3(0, 0, 0.05), c.lerp(leaf, 0.4), c)
		"flower":
			for i in 3:
				var a := TAU * i / 3.0
				mb.blade(Vector3.ZERO, 0.06, 0.15 + 0.3 * g, Vector3(cos(a), 0, sin(a)) * 0.08, leaf)
			if stage >= 3:
				mb.surface("glow" if crop in ["crystalbloom", "ghostbloom", "emberlily"] else "vc")
				var fs := 0.06 if stage == 3 else 0.12
				mb.blob(Vector3(0, 0.2 + 0.32 * g, 0), Vector3(fs, fs * 0.6, fs), c, 0.15, 1)
		"glowshroom":
			mb.surface("vc")
			for i in 1 + stage:
				var p := Vector3(mb.rng.randf_range(-0.15, 0.15), 0, mb.rng.randf_range(-0.15, 0.15))
				var s := 0.4 + g * 0.8
				mb.cyl(p, 0.04 * s, 0.03 * s, 0.2 * s, 5, Color("d8e8f0"))
				mb.surface("glow")
				mb.sphere(p + Vector3(0, 0.2 * s, 0), Vector3(0.13, 0.07, 0.13) * s, c, 3, 7)
				mb.surface("vc")
		"crystalflower":
			mb.surface("glow")
			for i in 1 + stage:
				var a := TAU * i / (1 + stage)
				mb.cyl(Vector3(cos(a) * 0.06, 0, sin(a) * 0.06), 0.04, 0.0, 0.15 + 0.35 * g, 5, c, Vector3(cos(a) * 0.3, 0, sin(a) * 0.3))
	mb.surface("vc")
	return mb.commit()

# ------------------------------------------------------------------ placeables

static func placeable_mesh(obj: String, v: int = 0) -> Mesh:
	return Meshes.cached("place:%s#%d" % [obj, v], func(): return _build_placeable(obj, v))

static func _build_placeable(obj: String, v: int) -> Mesh:
	var mb := MeshBuilder.new(obj.hash() + v)
	match obj:
		"chest":
			CaveProps._chest(mb, 0, false)
		"big_chest":
			mb.box(Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 0.75), Color("6b4a8a"))
			mb.cyl(Vector3(-0.71, 0.7, 0), 0.37, 0.37, 1.42, 8, Color("7b5a9a"), Vector3(0, 0, -PI / 2), true, true)
			for x in [-0.5, 0.0, 0.5]:
				mb.box(Vector3(x, 0.4, 0), Vector3(0.08, 0.8, 0.8), Color("c8a85a"))
		"workbench":
			mb.box(Vector3(0, 0.82, 0), Vector3(1.6, 0.12, 0.8), Color("b88a5a"))
			for x in [-0.7, 0.7]:
				for z in [-0.32, 0.32]:
					mb.box(Vector3(x, 0.4, z), Vector3(0.1, 0.8, 0.1), WOOD_DARK)
			mb.box(Vector3(0, 0.25, 0), Vector3(1.4, 0.06, 0.65), WOOD_DARK)
			mb.box(Vector3(0.4, 0.92, 0.1), Vector3(0.3, 0.08, 0.2), Color("8a8a8a"))
			mb.cyl(Vector3(-0.3, 0.88, -0.1), 0.02, 0.02, 0.4, 4, WOOD, Vector3(0, 0, PI / 2))
			mb.box(Vector3(-0.5, 0.9, 0.2), Vector3(0.12, 0.06, 0.25), Color("5a5a5a"))
		"furnace":
			mb.cyl(Vector3.ZERO, 0.6, 0.45, 1.4, 8, Color("8a8580"))
			mb.cyl(Vector3(0, 1.4, 0), 0.2, 0.16, 0.6, 6, Color("6a6560"))
			mb.surface("glow" if v == 1 else "vc")
			mb.box(Vector3(0, 0.45, 0.5), Vector3(0.45, 0.4, 0.12), Color("ff8a2a") if v == 1 else Color("2a2020"))
			mb.surface("vc")
		"kettle":
			for i in 3:
				var a := TAU * i / 3.0
				mb.cyl(Vector3(cos(a) * 0.45, 0, sin(a) * 0.45), 0.04, 0.04, 0.9, 4, Color("3a3a3a"), Vector3(sin(a) * 0.15, 0, -cos(a) * 0.15))
			mb.sphere(Vector3(0, 0.75, 0), Vector3(0.5, 0.42, 0.5), Color("c8743a"), 4, 9)
			mb.cyl(Vector3(0, 1.05, 0), 0.38, 0.4, 0.1, 9, Color("a85a2a"), Vector3.ZERO, false)
			mb.surface("glow_steady" if v >= 1 else "vc")
			mb.disc(Vector3(0, 1.1, 0), 0.36, 9, Color("6ad86a") if v == 1 else (Color("ffd36b") if v == 2 else Color("3a5a6a")))
			mb.surface("vc")
			mb.surface("glow" if v >= 1 else "vc")
			mb.blob(Vector3(0, 0.15, 0), Vector3(0.3, 0.12, 0.3), Color("ff7a2a") if v >= 1 else Color("3a3030"), 0.3, 0)
			mb.surface("vc")
		"stove":
			mb.box(Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 0.7), Color("5a5a5e"))
			mb.box(Vector3(0, 0.92, 0), Vector3(1.05, 0.06, 0.75), Color("3a3a3e"))
			mb.cyl(Vector3(0.3, 0.95, -0.15), 0.18, 0.18, 0.16, 8, Color("2a2a2e"))
			mb.cyl(Vector3(0.3, 0.95, -0.15), 0.19, 0.17, 0.05, 8, Color("8a8a8a"), Vector3.ZERO, false)
			mb.cyl(Vector3(0.35, 0.9, -0.25), 0.1, 0.1, 1.4, 6, Color("4a4a4e"))
			mb.surface("glow")
			mb.box(Vector3(0, 0.35, 0.36), Vector3(0.4, 0.22, 0.02), Color("ff8a3a"))
			mb.surface("vc")
		"campfire":
			Props._fire_ring(mb, 0)
		"torch":
			mb.cyl(Vector3.ZERO, 0.05, 0.04, 1.2, 5, WOOD_DARK)
			mb.surface("glow")
			mb.blob(Vector3(0, 1.28, 0), Vector3(0.1, 0.16, 0.1), Color("ffb040"), 0.2, 0)
			mb.surface("vc")
		"sprinkler", "sprinkler_2":
			var col := Color("c8743a") if obj == "sprinkler" else Color("f2c94c")
			mb.cyl(Vector3.ZERO, 0.18, 0.14, 0.22, 8, Color("6a6a6a"))
			mb.cyl(Vector3(0, 0.22, 0), 0.05, 0.05, 0.25, 5, col)
			for i in (4 if obj == "sprinkler" else 8):
				var a := TAU * i / (4 if obj == "sprinkler" else 8)
				mb.box(Vector3(cos(a) * 0.12, 0.48, sin(a) * 0.12), Vector3(0.18, 0.04, 0.04), col, Vector3(0, -a, 0))
		"scarecrow":
			mb.cyl(Vector3.ZERO, 0.05, 0.05, 1.9, 5, WOOD)
			mb.box(Vector3(0, 1.4, 0), Vector3(1.3, 0.08, 0.08), WOOD)
			mb.sphere(Vector3(0, 1.3, 0), Vector3(0.28, 0.35, 0.2), Color("6a8ac0"), 3, 7)
			mb.sphere(Vector3(0, 1.85, 0), Vector3(0.2, 0.22, 0.2), Color("e8d8a0"), 3, 7)
			mb.cyl(Vector3(0, 2.0, 0), 0.38, 0.38, 0.03, 9, Color("d8c06a"))
			mb.cyl(Vector3(0, 2.0, 0), 0.18, 0.12, 0.2, 8, Color("c8b05a"))
			for s in [-1, 1]:
				mb.sphere(Vector3(s * 0.07, 1.88, 0.18), Vector3.ONE * 0.03, Color("2a2a2a"), 2, 4)
		"fence":
			mb.box(Vector3(0, 0.5, 0), Vector3(0.14, 1.0, 0.14), WOOD_DARK)
			mb.box(Vector3(0, 0.75, 0), Vector3(1.0, 0.08, 0.06), WOOD)
			mb.box(Vector3(0, 0.4, 0), Vector3(1.0, 0.08, 0.06), WOOD)
		"stone_path":
			mb.surface("vc_nosnow")
			for i in 3:
				mb.blob(Vector3(mb.rng.randf_range(-0.2, 0.2), 0.02, mb.rng.randf_range(-0.2, 0.2)), Vector3(0.28, 0.04, 0.24), Color("b8b0a0").darkened(mb.rng.randf() * 0.15), 0.15, 0)
			mb.surface("vc")
		"wood_path":
			mb.surface("vc_nosnow")
			for i in 3:
				mb.box(Vector3(0, 0.03, -0.32 + i * 0.32), Vector3(0.9, 0.06, 0.28), Color("b88a5a").darkened(i * 0.05))
			mb.surface("vc")
		"lamp_post":
			Props._lamp(mb, 0)
		"flower_pot":
			mb.cyl(Vector3.ZERO, 0.18, 0.25, 0.35, 8, Color("c07a52"))
			mb.surface("plant")
			mb.blob(Vector3(0, 0.45, 0), Vector3(0.25, 0.18, 0.25), Color("5a9a3a"), 0.25, 1)
			mb.surface("vc")
			for i in 5:
				var a := TAU * i / 5.0
				mb.sphere(Vector3(cos(a) * 0.16, 0.55, sin(a) * 0.16), Vector3.ONE * 0.06, [Color("e86a8a"), Color("f2d04b"), Color("8a6ad8")][(i + v) % 3], 2, 4)
		"plant_pot":
			mb.cyl(Vector3.ZERO, 0.22, 0.3, 0.45, 8, Color("a86a4a"))
			mb.surface("plant")
			Props._fern(mb, 0)
			mb.surface("vc")
		"beehive":
			mb.box(Vector3(0, 0.2, 0), Vector3(0.8, 0.4, 0.8), WOOD_DARK)
			for i in 3:
				mb.box(Vector3(0, 0.55 + i * 0.3, 0), Vector3(0.7, 0.28, 0.7), Color("e8c06a").darkened(i * 0.05))
			mb.box(Vector3(0, 1.45, 0), Vector3(0.85, 0.08, 0.85), Color("b5523b"))
			mb.box(Vector3(0, 0.45, 0.36), Vector3(0.2, 0.05, 0.02), Color("2a2a2a"))
		"display_stand":
			mb.cyl(Vector3.ZERO, 0.35, 0.3, 0.12, 8, Color("8a8478"))
			mb.cyl(Vector3(0, 0.12, 0), 0.15, 0.15, 0.75, 8, Color("c8b08a"))
			mb.cyl(Vector3(0, 0.87, 0), 0.3, 0.32, 0.1, 8, Color("8a8478"))
		"fish_tank":
			mb.box(Vector3(0, 0.3, 0), Vector3(1.3, 0.6, 0.6), WOOD)
			mb.surface("water")
			mb.box(Vector3(0, 0.95, 0), Vector3(1.2, 0.65, 0.5), Color.WHITE)
			mb.surface("vc")
			mb.box(Vector3(0, 1.3, 0), Vector3(1.3, 0.06, 0.6), WOOD_DARK)
		"table":
			mb.box(Vector3(0, 0.75, 0), Vector3(1.4, 0.08, 0.9), Color("b88a5a"))
			for x in [-0.6, 0.6]:
				for z in [-0.35, 0.35]:
					mb.box(Vector3(x, 0.37, z), Vector3(0.08, 0.74, 0.08), WOOD_DARK)
		"chair":
			mb.box(Vector3(0, 0.45, 0), Vector3(0.5, 0.06, 0.5), Color("b88a5a"))
			mb.box(Vector3(0, 0.8, -0.22), Vector3(0.5, 0.6, 0.06), Color("a87a4a"))
			for x in [-0.2, 0.2]:
				for z in [-0.2, 0.2]:
					mb.box(Vector3(x, 0.22, z), Vector3(0.06, 0.45, 0.06), WOOD_DARK)
		"bench":
			Props._bench(mb)
		"rug":
			mb.surface("vc_nosnow")
			var rc: Color = [Color("c0504a"), Color("4a6ab0"), Color("6a9a4a"), Color("d8a03a")][v % 4]
			mb.box(Vector3(0, 0.01, 0), Vector3(2.0, 0.02, 1.4), rc)
			mb.box(Vector3(0, 0.015, 0), Vector3(1.6, 0.02, 1.0), rc.lightened(0.25))
			mb.box(Vector3(0, 0.02, 0), Vector3(1.2, 0.02, 0.6), rc)
			mb.surface("vc")
		"bed":
			mb.box(Vector3(0, 0.25, 0), Vector3(1.1, 0.5, 2.1), WOOD_DARK)
			mb.box(Vector3(0, 0.52, 0.1), Vector3(1.0, 0.12, 1.9), Color("f0ece0"))
			mb.box(Vector3(0, 0.6, 0.35), Vector3(1.04, 0.1, 1.4), Color("6a8ac0"))
			mb.box(Vector3(0, 0.65, -0.7), Vector3(0.8, 0.14, 0.35), Color("ffffff"))
			mb.box(Vector3(0, 0.75, -1.02), Vector3(1.1, 1.0, 0.1), WOOD)
		"bookshelf":
			mb.box(Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.4), Color("7a4a2a"))
			for i in 4:
				var y := 0.25 + i * 0.47
				mb.box(Vector3(0, y, 0.05), Vector3(1.1, 0.04, 0.36), Color("5a3420"))
				var x := -0.5
				while x < 0.45:
					var w := mb.rng.randf_range(0.06, 0.12)
					mb.box(Vector3(x + w / 2, y + 0.17, 0.08), Vector3(w * 0.9, 0.3, 0.28), [Color("a03a3a"), Color("3a6aa0"), Color("4a8a4a"), Color("d8a03a"), Color("6a4a8a")][mb.rng.randi() % 5])
					x += w
		"barrel":
			Props._barrel(mb, Vector3.ZERO)
		"crate":
			Props._crate(mb, Vector3.ZERO, 0.8, Color("b88a5a"))
		"banner":
			mb.cyl(Vector3.ZERO, 0.04, 0.04, 2.4, 5, WOOD_DARK)
			mb.box(Vector3(0.0, 2.3, 0), Vector3(0.9, 0.05, 0.05), WOOD_DARK)
			var bc: Color = [Color("4a6ab0"), Color("c0504a"), Color("5a9a4a"), Color("d8a03a")][v % 4]
			mb.quad2(Vector3(-0.4, 2.25, 0.05), Vector3(0.4, 2.25, 0.05), Vector3(0.4, 1.2, 0.05), Vector3(-0.4, 1.2, 0.05), bc)
			mb.tri(Vector3(-0.4, 1.2, 0.06), Vector3(0.4, 1.2, 0.06), Vector3(0, 0.95, 0.06), bc)
		"painting":
			mb.box(Vector3(0, 1.5, 0), Vector3(1.2, 0.9, 0.06), Color("8a6a3a"))
			mb.box(Vector3(0, 1.5, 0.03), Vector3(1.05, 0.75, 0.02), Color("8ac0e0"))
			mb.box(Vector3(0, 1.3, 0.04), Vector3(1.05, 0.35, 0.02), Color("6aa84a"))
			mb.sphere(Vector3(0.3, 1.7, 0.05), Vector3.ONE * 0.08, Color("f6d04a"), 2, 6)
			mb.cyl(Vector3(-0.25, 1.15, 0.05), 0.0, 0.0, 0.01, 3, Color.WHITE)
			mb.cone(Vector3(-0.25, 1.45, 0.05), 0.18, 0.35, 4, Color("5a7a8a"))
		"garden_gnome":
			mb.cyl(Vector3.ZERO, 0.15, 0.17, 0.28, 7, Color("4a6ab0"))
			mb.sphere(Vector3(0, 0.38, 0), Vector3(0.12, 0.12, 0.12), Color("f2d0b0"), 3, 6)
			mb.sphere(Vector3(0, 0.3, 0.06), Vector3(0.12, 0.1, 0.1), Color("f4f2ea"), 3, 6)
			mb.cone(Vector3(0, 0.46, 0), 0.13, 0.35, 6, Color("d8402f"))
		"coop":
			mb.box(Vector3(0, 1.1, -0.3), Vector3(3.6, 2.2, 2.2), Color("c8a07a"))
			mb.surface("vc_cut")
			mb.quad_out(Vector3(-2.0, 2.2, 0.9), Vector3(2.0, 2.2, 0.9), Vector3(2.0, 3.0, -0.3), Vector3(-2.0, 3.0, -0.3), Color("b5523b"), Vector3(0, 2.0, -0.3))
			mb.quad_out(Vector3(2.0, 2.2, -1.5), Vector3(-2.0, 2.2, -1.5), Vector3(-2.0, 3.0, -0.3), Vector3(2.0, 3.0, -0.3), Color("a5482f"), Vector3(0, 2.0, -0.3))
			mb.surface("vc")
			mb.box(Vector3(-0.8, 0.6, 0.82), Vector3(0.8, 1.2, 0.06), WOOD_DARK)
			mb.box(Vector3(0.9, 0.2, 1.3), Vector3(1.4, 0.4, 0.5), WOOD)
			mb.box(Vector3(0.9, 0.38, 1.3), Vector3(1.25, 0.05, 0.38), Color("d8c06a") if v == 1 else Color("5a4a3a"))
			mb.surface("window")
			mb.box(Vector3(0.9, 1.4, 0.82), Vector3(0.6, 0.45, 0.04), Color("ffe1a0"))
			mb.surface("vc")
		"shed":
			mb.box(Vector3(0, 1.3, 0), Vector3(3.8, 2.6, 3.6), Color("8a6a4a"))
			mb.surface("vc_cut")
			mb.quad_out(Vector3(-2.2, 2.6, 2.0), Vector3(2.2, 2.6, 2.0), Vector3(2.2, 3.6, 0), Vector3(-2.2, 3.6, 0), Color("4f6a7a"), Vector3(0, 2.5, 0))
			mb.quad_out(Vector3(2.2, 2.6, -2.0), Vector3(-2.2, 2.6, -2.0), Vector3(-2.2, 3.6, 0), Vector3(2.2, 3.6, 0), Color("3f5a6a"), Vector3(0, 2.5, 0))
			mb.surface("vc")
			mb.box(Vector3(0, 1.05, 1.82), Vector3(1.6, 2.1, 0.06), WOOD_DARK)
			mb.box(Vector3(0, 1.05, 1.85), Vector3(0.06, 2.0, 0.04), WOOD)
		"fruit_tree":
			_fruit_tree(mb, v)
		_:
			mb.box(Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), Color("b88a5a"))
	return mb.commit()

## v: 0-3 growth stage, 4 = grown, 5 = grown with fruit (fruit colour from the item).
static func fruit_tree_mesh(fruit: String, stage: int, has_fruit: bool) -> Mesh:
	var key := "ftree:%s:%d:%s" % [fruit, stage, str(has_fruit)]
	return Meshes.cached(key, func():
		var mb := MeshBuilder.new(fruit.hash() + stage)
		_fruit_tree(mb, stage, fruit, has_fruit)
		return mb.commit())

static func _fruit_tree(mb: MeshBuilder, stage: int, fruit: String = "apple", has_fruit: bool = false) -> void:
	var g: float = clamp(float(stage + 1) / 5.0, 0.2, 1.0)
	var bark := Color("6b4a32")
	var leaf := Color("5aa84a") if fruit != "lumenfruit" else Color("8ad8c8")
	mb.cyl(Vector3.ZERO, 0.08 + 0.14 * g, 0.05 + 0.1 * g, 0.4 + 1.6 * g, 6, bark)
	mb.surface("foliage")
	mb.blob(Vector3(0, 0.5 + 2.2 * g, 0), Vector3(0.4 + 1.1 * g, 0.35 + 0.9 * g, 0.4 + 1.1 * g), leaf, 0.18, 1)
	mb.blob(Vector3(0.5 * g, 0.35 + 1.9 * g, 0.3 * g), Vector3(0.3 + 0.6 * g, 0.3 + 0.5 * g, 0.3 + 0.6 * g), leaf.lightened(0.08), 0.18, 1)
	mb.surface("vc")
	if has_fruit:
		var fc: Color = Items.def(fruit)["icon"][1]
		if fruit == "lumenfruit":
			mb.surface("glow")
		for i in 9:
			var a := mb.rng.randf() * TAU
			var y := mb.rng.randf_range(1.6, 3.0)
			mb.sphere(Vector3(cos(a) * 1.1, y, sin(a) * 1.1), Vector3.ONE * 0.11, fc, 3, 6)
		mb.surface("vc")
