class_name Overworld
extends Zone
## The surface: terrain, water, forests, landmarks, the farm and the town.

const CHUNK := 32

var gen: OverworldGen
var terrain_root: Node3D
var water_root: Node3D
var decor_root: Node3D
var struct_root: Node3D
var farm: FarmLayer
var town: TownBuilder
var forage_ids: Array = []
var _discover_t := 0.0
var _explore_t := 0.0
var _explore_pending := PackedInt32Array()
var bridge_nodes := {}

func _init() -> void:
	super._init()
	zone_id = "over"
	kind = "over"

func build() -> void:
	gen = Zones.overworld_gen()
	terrain_root = Node3D.new()
	terrain_root.name = "Terrain"
	add_child(terrain_root)
	water_root = Node3D.new()
	water_root.name = "Water"
	add_child(water_root)
	decor_root = Node3D.new()
	decor_root.name = "Decor"
	add_child(decor_root)
	struct_root = Node3D.new()
	struct_root.name = "Structures"
	add_child(struct_root)
	_build_terrain()
	_build_collision()
	_build_water()
	_build_bridges()
	_build_decor()
	_build_nodes()
	_build_pois()
	_build_farm()
	_build_cave_entrance()
	town = TownBuilder.new()
	town.name = "Town"
	add_child(town)
	town.build(self)
	_spawn_forage()
	farm = FarmLayer.new()
	farm.name = "Farm"
	add_child(farm)
	farm.setup(self)
	for oid in Game.world.get("objects", {}):
		var o: Dictionary = Game.world["objects"][oid]
		if o.get("z", "") == zone_id:
			_spawn_placed(oid, o)
	built = true

func display_name() -> String:
	return "The Valley"

## A friendly name for wherever this point is: the farm, town, or a known landmark.
func area_name(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	if gen.farm_rect.grow(2.0).has_point(q):
		return "Home Farm"
	if gen.town_rect.grow(4.0).has_point(q):
		return TownGen.town_name()
	if q.distance_to(gen.cave_pos) < 14.0:
		return "The Cave Mouth"
	var best := ""
	var bd := 1e9
	for poi in gen.pois:
		var nm: String = poi.get("name", "")
		if nm == "" or not Game.world["know"]["places"].has(poi["id"]):
			continue
		var d: float = q.distance_to(poi["pos"])
		if d < float(poi["r"]) and d < bd:
			bd = d
			best = nm
	if best != "":
		return best[0].to_upper() + best.substr(1)
	return "The Valley"

func ground_y(x: float, z: float) -> float:
	return gen.h_at(x, z)

func water_at(p: Vector3) -> Dictionary:
	return gen.water_at(p.x, p.z)

func is_blocked(p: Vector3) -> bool:
	if p.x < 1.0 or p.z < 1.0 or p.x > OverworldGen.S - 1.0 or p.z > OverworldGen.S - 1.0:
		return true
	return gen.is_deep(p.x, p.z, p.y)

func spawn_point(tag: String = "") -> Vector3:
	match tag:
		"cave":
			var c := gen.cave_pos + Vector2(0, 9)
			return Vector3(c.x, gen.h_at(c.x, c.y) + 0.3, c.y)
		"door":
			var f := farmhouse_door()
			return f + Vector3(0, 0.3, 1.5)
		"town":
			return Vector3(gen.town_center.x, gen.town_h + 0.3, gen.town_center.y + 8)
	return gen.farm_spawn()

func farmhouse_pos() -> Vector3:
	var c := Vector2(gen.farm_rect.get_center().x, gen.farm_rect.position.y + 6.5)
	return Vector3(c.x, gen.farm_h, c.y)

func farmhouse_door() -> Vector3:
	var lvl := int(Game.world.get("farm", {}).get("level", 0))
	var d := 5.5 + lvl * 1.5
	return farmhouse_pos() + Vector3(-0.8, 0, d / 2.0 + 0.6)

# ------------------------------------------------------------------ terrain

func _build_terrain() -> void:
	var N := OverworldGen.N
	var S := OverworldGen.S
	var mat := Meshes.mat("terrain")
	for cz in range(0, S, CHUNK):
		for cx in range(0, S, CHUNK):
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var w := CHUNK + 1
			for z in range(cz, cz + CHUNK + 1):
				for x in range(cx, cx + CHUNK + 1):
					var h := gen.heights[min(z, N - 1) * N + min(x, N - 1)]
					verts.append(Vector3(x, h, z))
					var hl := gen._hv(x - 1, z)
					var hr := gen._hv(x + 1, z)
					var hd := gen._hv(x, z - 1)
					var hu := gen._hv(x, z + 1)
					norms.append(Vector3(hl - hr, 2.0, hd - hu).normalized())
					var c := gen.color_at(x, z)
					var c2 := gen.color_at(x - 1, z - 1)
					var cc := c.lerp(c2, 0.35)
					cc.a = c.a
					cols.append(cc)
			for z in CHUNK:
				for x in CHUNK:
					var i := z * w + x
					idx.append_array([i, i + 1, i + w, i + 1, i + w + 1, i + w])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = norms
			arrays[Mesh.ARRAY_COLOR] = cols
			arrays[Mesh.ARRAY_INDEX] = idx
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			m.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.name = "T_%d_%d" % [cx, cz]
			terrain_root.add_child(mi)
	# a skirt of distant mountains beyond the edge so the world feels bounded, not cut off
	var mb := MeshBuilder.new(gen.seed_value)
	for i in 40:
		var a := TAU * i / 40.0
		var r := 260.0 + mb.rng.randf_range(0, 30)
		var p := Vector3(160 + cos(a) * r, -4, 160 + sin(a) * r)
		var s := mb.rng.randf_range(40, 70)
		mb.blob(p, Vector3(s, s * mb.rng.randf_range(0.6, 0.95), s), Color("6a7a68").lerp(Color("8a9488"), mb.rng.randf()), 0.12, 1)
	var far := MeshInstance3D.new()
	far.mesh = mb.commit()
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_root.add_child(far)

func _build_collision() -> void:
	var N := OverworldGen.N
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = N
	hm.map_depth = N
	hm.map_data = gen.heights
	cs.shape = hm
	cs.position = Vector3((N - 1) / 2.0, 0, (N - 1) / 2.0)
	body.add_child(cs)
	add_child(body)
	# invisible walls at the world's edge
	var S := float(OverworldGen.S)
	for w in [[Vector3(S / 2, 20, -1), Vector3(S + 4, 80, 2)], [Vector3(S / 2, 20, S + 1), Vector3(S + 4, 80, 2)],
			[Vector3(-1, 20, S / 2), Vector3(2, 80, S + 4)], [Vector3(S + 1, 20, S / 2), Vector3(2, 80, S + 4)]]:
		var wc := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = w[1]
		wc.shape = bs
		wc.position = w[0]
		body.add_child(wc)

# ------------------------------------------------------------------ water

func _build_water() -> void:
	# river ribbon
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var rv: Array = gen.river
	for i in rv.size():
		var p: Vector2 = rv[i]["p"]
		var prev: Vector2 = rv[max(0, i - 1)]["p"]
		var next: Vector2 = rv[min(rv.size() - 1, i + 1)]["p"]
		var dir := (next - prev).normalized()
		var n := dir.orthogonal()
		var hw: float = rv[i]["w"] / 2.0 + 1.6
		var lvl: float = rv[i]["lvl"]
		var a := p + n * hw
		var b := p - n * hw
		verts.append(Vector3(a.x, lvl, a.y))
		verts.append(Vector3(b.x, lvl, b.y))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		cols.append(Color.WHITE)
		cols.append(Color.WHITE)
		if i > 0:
			var k := i * 2
			idx.append_array([k - 2, k, k - 1, k - 1, k, k + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, Meshes.mat("water"))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_root.add_child(mi)
	# ponds and the lake
	for pd in gen.ponds:
		var mb := MeshBuilder.new(1)
		mb.surface("water_hot" if pd["kind"] == "hot" else "water")
		var c: Vector2 = pd["c"]
		var lvl: float = pd["lvl"]
		var segs := 40
		var center := Vector3(c.x, lvl, c.y)
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var r0 := gen.pond_radius(pd, a0) + 1.2
			var r1 := gen.pond_radius(pd, a1) + 1.2
			var p0 := Vector3(c.x + cos(a0) * r0, lvl, c.y + sin(a0) * r0)
			var p1 := Vector3(c.x + cos(a1) * r1, lvl, c.y + sin(a1) * r1)
			mb.tri_out(center, p0, p1, Color.WHITE, center - Vector3(0, 1, 0))
		var pm := MeshInstance3D.new()
		pm.mesh = mb.commit()
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water_root.add_child(pm)
		if pd["kind"] == "hot":
			_steam(Vector3(c.x, lvl + 0.2, c.y), float(pd["r"]))
			var hs := Meshes.inst(Props.get_mesh("hot_spring_rocks", 0), struct_root, Vector3(c.x, lvl, c.y))
			hs.scale = Vector3.ONE * (float(pd["r"]) / 3.2)

func _steam(pos: Vector3, r: float) -> void:
	var p := CPUParticles3D.new()
	p.mesh = Meshes.particle_mesh(1.2)
	p.amount = 24
	p.lifetime = 3.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(r, 0.1, r)
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.15, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.3, Color(1, 1, 1, 0.22))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	p.position = pos
	p.visibility_range_end = 80.0
	struct_root.add_child(p)

func _build_bridges() -> void:
	for b in gen.bridges:
		_place_bridge(b, b["broken"] and not bool(Game.world["flags"].get("bridge_fixed", false)))

func _place_bridge(b: Dictionary, broken: bool) -> void:
	var id: String = b["id"]
	if bridge_nodes.has(id):
		bridge_nodes[id].queue_free()
	var root := Node3D.new()
	struct_root.add_child(root)
	bridge_nodes[id] = root
	var c: Vector2 = b["p"]
	var dir: Vector2 = b["dir"]
	var l: float = b["len"]
	var deck: float = b["deck"]
	var yaw := atan2(dir.x, dir.y)
	var mi := Meshes.inst(Props.get_mesh("broken_bridge" if broken else "bridge", int(round(l))), root, Vector3(c.x, deck - 0.06, c.y), yaw)
	var body := StaticBody3D.new()
	root.add_child(body)
	body.position = Vector3(c.x, deck - 0.12, c.y)
	body.rotation.y = yaw
	var segs := [[0.0, l]] if not broken else [[-l * 0.34, l * 0.32], [l * 0.34, l * 0.32]]
	for sg in segs:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.4, 0.2, sg[1])
		cs.shape = bs
		cs.position = Vector3(0, 0, sg[0])
		body.add_child(cs)
	# gentle ramps at both ends so you can always step on
	for s in [-1.0, 1.0]:
		var rc := CollisionShape3D.new()
		var rs := BoxShape3D.new()
		rs.size = Vector3(2.4, 0.2, 2.2)
		rc.shape = rs
		rc.position = Vector3(0, -0.3, s * (l / 2.0 + 0.6))
		rc.rotation.x = s * 0.28
		body.add_child(rc)
	# side rails block falls
	for side in [-1.0, 1.0]:
		var sc := CollisionShape3D.new()
		var ss := BoxShape3D.new()
		ss.size = Vector3(0.2, 1.2, l)
		sc.shape = ss
		sc.position = Vector3(side * 1.25, 0.6, 0)
		body.add_child(sc)
	if not broken:
		gen.mark_bridge(b)

func fix_old_bridge() -> void:
	for b in gen.bridges:
		if b["broken"]:
			_place_bridge(b, false)

# ------------------------------------------------------------------ decor

func _build_decor() -> void:
	var S := OverworldGen.S
	var per_chunk := {}
	for d in gen.decor:
		var p: Vector3 = d["p"]
		var key := Vector2i(int(p.x) / CHUNK, int(p.z) / CHUNK)
		var mk: String = d["k"] + ("#%d" % (int(d["v"]) % 3) if d["k"] == "flower" else "")
		if not per_chunk.has(key):
			per_chunk[key] = {}
		if not per_chunk[key].has(mk):
			per_chunk[key][mk] = []
		per_chunk[key][mk].append(d)
	for s in gen.spawns:
		if s["k"] == "bush":
			var p2: Vector3 = s["p"]
			var key2 := Vector2i(int(p2.x) / CHUNK, int(p2.z) / CHUNK)
			var mk2 := "bush#%d" % (int(s["v"]) % 3)
			if not per_chunk.has(key2):
				per_chunk[key2] = {}
			if not per_chunk[key2].has(mk2):
				per_chunk[key2][mk2] = []
			per_chunk[key2][mk2].append(s)
	for key in per_chunk:
		for mk in per_chunk[key]:
			var arr: Array = per_chunk[key][mk]
			var parts: PackedStringArray = mk.split("#")
			var mesh := Props.get_mesh(parts[0], int(parts[1]) if parts.size() > 1 else 0)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = arr.size()
			for i in arr.size():
				var d: Dictionary = arr[i]
				var t := Transform3D(Basis(Vector3.UP, d["r"]).scaled(Vector3.ONE * d["s"]), d["p"])
				mm.set_instance_transform(i, t)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if parts[0] != "bush" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mmi.visibility_range_end = 75.0 if parts[0] in ["grass", "pebble", "flower", "lily"] else 120.0
			decor_root.add_child(mmi)

# ------------------------------------------------------------------ resource nodes

func _build_nodes() -> void:
	for s in gen.spawns:
		if s["k"] == "bush":
			continue
		_spawn_node(s)

func _spawn_node(s: Dictionary) -> void:
	var k: String = s["k"]
	var info := ResourceNode.info(k)
	var resp: int = info.get("respawn", -1)
	if s.get("farm", false):
		resp = -1
	if resp == -2:
		resp = 99999
	if not node_present(s["id"], resp):
		return
	if objs.has(s["id"]):
		return
	var n := ResourceNode.new()
	nodes_root.add_child(n)
	n.setup(s["id"], k, s["p"], s["r"], s["v"], s.get("s", 1.0), s.get("x", {}))
	if k == "berry_bush":
		n.data["berry"] = "bramble_berry"
	register(n)

func add_node_spec(id: String, k: String, pos: Vector3, rot: float = 0.0, v: int = 0, extra: Dictionary = {}) -> void:
	var s := {"id": id, "k": k, "p": pos, "r": rot, "v": v, "s": 1.0, "x": extra}
	_spawn_node(s)

func _gy(p: Vector2) -> float:
	return gen.h_at(p.x, p.y)

func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, gen.h_at(p.x, p.y), p.y)

# ------------------------------------------------------------------ points of interest

func _build_pois() -> void:
	var rng := RandomNumberGenerator.new()
	for q in gen.pois:
		rng.seed = Game.hash_ints(gen.seed_value, String(q["id"]).hash())
		var c: Vector2 = q["pos"]
		var pid: String = q["id"]
		match q["type"]:
			"camp":
				var tent := Meshes.inst(Props.get_mesh("tent", rng.randi() % 3), struct_root, _v3(c + Vector2(-2.5, -1)), rng.randf() * TAU)
				_box_body(_v3(c + Vector2(-2.5, -1)), Vector3(2.6, 1.4, 2.2), tent.rotation.y)
				Meshes.inst(Props.get_mesh("fire_ring", 0), struct_root, _v3(c + Vector2(1.5, 1.0)))
				Meshes.inst(CaveProps.get_mesh("bedroll"), struct_root, _v3(c + Vector2(0.5, -2.5)), rng.randf() * TAU)
				add_node_spec(pid + "_crate", "crate_loot", _v3(c + Vector2(2.5, -1.5)), rng.randf() * TAU)
			"berry_thicket":
				for i in 6:
					var a := TAU * i / 6.0 + rng.randf() * 0.4
					var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(1.5, 4.5)
					add_node_spec(pid + "_b%d" % i, "berry_bush", _v3(p), rng.randf() * TAU)
			"mushroom_ring":
				for i in 10:
					var a2 := TAU * i / 10.0
					Meshes.inst(Props.get_mesh("mushroom_patch", 0), struct_root, _v3(c + Vector2(cos(a2), sin(a2)) * 4.0), rng.randf() * TAU, 0.8, 60.0)
			"standing_stones":
				for i in 7:
					var a3 := TAU * i / 7.0
					var p3 := c + Vector2(cos(a3), sin(a3)) * 5.5
					Meshes.inst(Props.get_mesh("standing_stone", i % 4), struct_root, _v3(p3) - Vector3(0, 0.2, 0), -a3 + PI / 2)
					_cyl_body(_v3(p3), 0.5, 3.0)
				Meshes.inst(Props.get_mesh("standing_stone", 2), struct_root, _v3(c) - Vector3(0, 1.4, 0), 0.3, 0.6)
			"fallen_giant":
				var lg := Meshes.inst(Props.get_mesh("log", 4), struct_root, _v3(c), rng.randf() * TAU, 1.6)
				_box_body(_v3(c), Vector3(10.0, 1.2, 1.3), lg.rotation.y + PI / 2)
			"watchtower":
				Meshes.inst(Props.get_mesh("watchtower", 0), struct_root, _v3(c) - Vector3(0, 0.1, 0))
				for i in 10:
					if i == 7:
						continue
					var a4 := TAU * i / 10.0
					_box_body(_v3(c + Vector2(cos(a4), sin(a4)) * 2.2), Vector3(1.45, 4.0, 0.7), -a4 + PI / 2)
				add_node_spec(pid + "_chest", "tower_chest", _v3(c + Vector2(0.6, -0.6)), 0.4)
			"lookout":
				Meshes.inst(Props.get_mesh("lookout", 0), struct_root, _v3(c) - Vector3(0, 0.3, 0), rng.randf() * TAU)
				_cyl_body(_v3(c), 2.8, 4.0)
			"hollow_oak":
				Meshes.inst(Props.get_mesh("giant_oak", 0), struct_root, _v3(c) - Vector3(0, 0.2, 0))
				_cyl_body(_v3(c), 1.4, 6.0)
			"wildflowers":
				for i in 40:
					var p4 := c + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
					Meshes.inst(Props.get_mesh("flower", i % 6), struct_root, _v3(p4), rng.randf() * TAU, rng.randf_range(0.9, 1.4), 70.0)
			"copper_outcrop":
				for i in 5:
					var a5 := TAU * i / 5.0 + rng.randf()
					var p5 := c + Vector2(cos(a5), sin(a5)) * rng.randf_range(1.5, 4.0)
					add_node_spec(pid + "_o%d" % i, "copper_node" if i < 3 else "rock_med", _v3(p5), rng.randf() * TAU, i)
				Meshes.inst(Props.get_mesh("boulder", 1), struct_root, _v3(c + Vector2(0, -5)), rng.randf() * TAU, 1.2)
				_cyl_body(_v3(c + Vector2(0, -5)), 2.0, 3.0)
			"ruins":
				for i in 4:
					var a6 := TAU * i / 4.0 + 0.3
					var p6 := c + Vector2(cos(a6), sin(a6)) * 4.0
					Meshes.inst(Props.get_mesh("ruin_wall", i), struct_root, _v3(p6) - Vector3(0, 0.1, 0), -a6)
					_box_body(_v3(p6), Vector3(3.2, 1.6, 0.6), -a6)
				for i in 3:
					add_node_spec(pid + "_cache%d" % i, "ruin_cache", _v3(c + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))))
			"clay_bank":
				for i in 4:
					add_node_spec(pid + "_clay%d" % i, "clay", _v3(c + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))), rng.randf() * TAU)
			"dock":
				var dir: Vector2 = q["dir"]
				var yaw := atan2(dir.x, dir.y)
				var lake: Dictionary = gen.ponds[0]
				var deck: float = float(lake["lvl"]) + 0.55
				var dock_base := Vector3(c.x, deck, c.y)
				Meshes.inst(Props.get_mesh("dock", 0), struct_root, dock_base, yaw)
				var body := StaticBody3D.new()
				struct_root.add_child(body)
				body.position = dock_base
				body.rotation.y = yaw
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(2.0, 0.3, 7.2)
				cs.shape = bs
				cs.position = Vector3(0, -0.12, 3.3)
				body.add_child(cs)
				var ramp := CollisionShape3D.new()
				var rs := BoxShape3D.new()
				rs.size = Vector3(2.0, 0.2, 2.5)
				ramp.shape = rs
				ramp.position = Vector3(0, -0.4, -0.8)
				ramp.rotation.x = 0.3
				body.add_child(ramp)
				for i in 16:
					var p7 := c + dir * (i * 0.45)
					for k in range(-2, 3):
						var pp := p7 + dir.orthogonal() * (k * 0.4)
						gen.bridge_cells[Vector2i(int(pp.x), int(pp.y))] = true
				add_child(Feature.new().setup("dock_sign", "sign", "Read sign", _v3(c - dir * 1.2), 0.8, {"text": "%s — fishing welcome. Mind the pike." % gen.names.get("lake", "The Lake")}))
				register(get_child(get_child_count() - 1))
			"ford":
				for i in 7:
					var p8 := c + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
					Meshes.inst(Props.get_mesh("rock", i % 3), struct_root, _v3(p8) - Vector3(0, 0.15, 0), rng.randf() * TAU, 0.7)
			"hot_poi":
				var f := Feature.new().setup("hot_spring_soak", "soak", "Soak in the springs", _v3(c + Vector2(3.6, 0)), 1.5)
				add_child(f)
				register(f)
			"old_bridge":
				var sign := Feature.new().setup("old_bridge_sign", "sign", "Read sign", _v3(c) + Vector3(0, 0, 0), 0.1, {"text": "BRIDGE OUT. Ask at the town hall."})
				pass

func _box_body(pos: Vector3, size: Vector3, yaw: float) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0, size.y / 2.0, 0)
	b.add_child(cs)
	struct_root.add_child(b)
	b.position = pos
	b.rotation.y = yaw

func _cyl_body(pos: Vector3, r: float, h: float) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shp := CylinderShape3D.new()
	shp.radius = r
	shp.height = h
	cs.shape = shp
	cs.position = Vector3(0, h / 2.0, 0)
	b.add_child(cs)
	struct_root.add_child(b)
	b.position = pos

# ------------------------------------------------------------------ farm

var farmhouse_mi: MeshInstance3D
var farmhouse_body: StaticBody3D
var _house_level := 0

func _build_farm() -> void:
	_build_farmhouse()
	var fr := gen.farm_rect
	var hp := farmhouse_pos()
	_build_ship_bin()
	var well_p := Vector3(fr.position.x + 6, gen.farm_h, fr.position.y + 9)
	var well := Feature.new().setup("farm_well", "well", "Draw water", well_p, 1.1)
	add_child(well)
	well.set_mesh(Props.get_mesh("well", 0))
	well.add_blocker(0.9, 1.0)
	register(well)
	var board := Feature.new().setup("chronicle_board", "chronicle", "Read the chronicle board", hp + Vector3(-5.5, 0, 4.5), 1.0)
	add_child(board)
	board.set_mesh(Props.get_mesh("notice_board", 1), 0.0, 0.0, 0.8)
	board.add_box_blocker(Vector3(1.8, 1.8, 0.3))
	register(board)
	# a mailbox-style sign at the farm gate and a few fence remnants
	var gate := Vector3(fr.get_center().x + 3, gen.farm_h, fr.end.y - 0.5)
	Meshes.inst(Props.get_mesh("signpost", 0), struct_root, Vector3(gate.x, gen.h_at(gate.x, gate.z), gate.z), 0.4)
	var rng := Game.rng_for("fence")
	for i in 14:
		var t := rng.randf()
		var fp := Vector3(lerp(fr.position.x, fr.end.x, t), 0, fr.end.y + 0.6 if i % 2 == 0 else fr.position.y - 0.6)
		fp.y = gen.h_at(fp.x, fp.z)
		Meshes.inst(ItemModels.placeable_mesh("fence"), struct_root, fp, 0.0)

func _build_farmhouse() -> void:
	if farmhouse_mi:
		farmhouse_mi.queue_free()
	if farmhouse_body:
		farmhouse_body.queue_free()
	var lvl := int(Game.world.get("farm", {}).get("level", 0))
	_house_level = lvl
	var hp := farmhouse_pos()
	farmhouse_mi = Meshes.inst(Props.get_mesh("farmhouse", lvl), struct_root, hp)
	var w := 7.0 + lvl * 2.5
	var d := 5.5 + lvl * 1.5
	var fh := 2.9 + (2.4 if lvl >= 2 else 0.0) + w * 0.42
	Zones.register_occluder(farmhouse_mi, "over", hp + Vector3(-2.0 if lvl >= 2 else 0.0, fh / 2.0, 0), Vector3(w / 2.0 + (2.5 if lvl >= 2 else 0.6), fh / 2.0 + 0.3, d / 2.0 + 0.8), 0.0)
	farmhouse_body = StaticBody3D.new()
	struct_root.add_child(farmhouse_body)
	farmhouse_body.position = hp
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w + (4.0 if lvl >= 2 else 0.0), 6.0, d)
	cs.shape = bs
	cs.position = Vector3(-2.0 if lvl >= 2 else 0.0, 3.0, 0)
	farmhouse_body.add_child(cs)
	if objs.has("farm_door"):
		remove_obj("farm_door", false)
	var door := Feature.new().setup("farm_door", "enter_home", "Go inside", farmhouse_door(), 1.2)
	add_child(door)
	register(door)

func upgrade_farmhouse() -> void:
	if int(Game.world.get("farm", {}).get("level", 0)) == _house_level:
		return
	_build_farmhouse()
	_build_ship_bin()
	Fx.sparkle(fx_root, farmhouse_pos() + Vector3(0, 3, 0), Color("ffe08a"), 40, 4.0)

func _build_ship_bin() -> void:
	if objs.has("ship_bin"):
		remove_obj("ship_bin", false)
	var bin_p := farmhouse_pos() + Vector3(5.5 + _house_level * 1.3, 0, 4.2)
	var bin := Feature.new().setup("ship_bin", "ship_bin", "Shipping bin", bin_p, 1.0)
	add_child(bin)
	bin.set_mesh(Props.get_mesh("shipping_bin", 0))
	bin.add_box_blocker(Vector3(1.4, 0.9, 0.9))
	register(bin)

func _spawn_placed(oid: String, o: Dictionary) -> void:
	if objs.has(oid):
		return
	var po := PlacedObj.new()
	objects_root.add_child(po)
	po.setup(oid, o)
	register(po)
	if po.obj_type in ["coop", "shed"] and po.mesh_inst:
		Zones.register_occluder(po.mesh_inst, zone_id, po.global_position + Vector3(0, 1.8, 0), Vector3(2.4, 2.0, 2.2), po.rotation.y)

# ------------------------------------------------------------------ cave entrance

func _build_cave_entrance() -> void:
	var c := gen.cave_pos
	var pos := Vector3(c.x, gen.cave_h, c.y)
	Meshes.inst(Props.get_mesh("cave_entrance", 0), struct_root, pos)
	_box_body(pos + Vector3(0, 0, -3), Vector3(16, 6, 6), 0.0)
	_box_body(pos + Vector3(-3.4, 0, 0.6), Vector3(2.2, 4, 2.0), 0.0)
	_box_body(pos + Vector3(3.4, 0, 0.6), Vector3(2.2, 4, 2.0), 0.0)
	var f := Feature.new().setup("cave_mouth", "enter_cave", "Descend into the caves", pos + Vector3(0, 0, 1.4), 1.6)
	add_child(f)
	register(f)
	var light := OmniLight3D.new()
	light.light_color = Color("ffc070")
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = pos + Vector3(1.9, 2.0, 1.8)
	struct_root.add_child(light)
	Zones.register_night_light(light)

# ------------------------------------------------------------------ forage & daily things

func _forage_item(spot: Dictionary, rng: RandomNumberGenerator) -> String:
	var s := Game.season()
	var b: int = spot["b"]
	var poi: String = spot.get("poi", "")
	if poi == "mushroom_ring":
		if s == 3:
			return ""
		return ["common_mushroom", "chanterelle" if s == 2 else "morel", "common_mushroom", "moonshroom" if rng.randf() < 0.15 else "common_mushroom"][rng.randi() % 4]
	if poi == "wildflowers":
		var herbs = [["mint", "sageleaf", "mossbloom", "dandelion", "silverreed"], ["mint", "sunpetal", "silverreed", "sweet_pea", "emberroot"], ["sageleaf", "mossbloom", "emberroot", "stonewort"], ["frost_crocus", "holly"]][s]
		return herbs[rng.randi() % herbs.size()]
	if poi == "hollow_oak":
		return "honeycomb" if Game.day() % 3 == 0 and s != 3 else ""
	var table: Array
	var B := OverworldGen.B
	match s:
		0:
			table = ["wild_leek", "dandelion", "wild_herbs", "common_mushroom"] if b in [B.FOREST, B.BIRCH] else ["dandelion", "wild_leek", "wild_herbs", "feather"]
			if b in [B.FOREST, B.BIRCH] and rng.randf() < 0.2:
				table = ["morel", "fiddlehead"]
			if b == B.MARSH or b == B.SAND:
				table = ["fiddlehead", "wild_herbs", "feather"]
		1:
			table = ["common_mushroom", "sweet_pea", "wild_herbs", "fiddlehead"] if b in [B.FOREST, B.BIRCH] else ["sweet_pea", "wild_herbs", "feather", "dandelion"]
		2:
			table = ["chanterelle", "hazelnut", "common_mushroom", "wild_plum"] if b in [B.FOREST, B.BIRCH, B.PINE] else ["wild_plum", "hazelnut", "feather", "wild_herbs"]
		_:
			table = ["winter_root", "holly", "frost_crocus", "feather"]
	if b == B.ROCKY or b == B.PINE:
		if s != 3 and rng.randf() < 0.4:
			table = ["stonewort", "common_mushroom", "wild_herbs"]
	return table[rng.randi() % table.size()]

func _spawn_forage() -> void:
	for id in forage_ids:
		if objs.has(id):
			remove_obj(id, false)
	forage_ids.clear()
	var d := Game.day()
	for spot in gen.forage_spots:
		var rng := Game.rng_for("forage", d, spot["i"])
		var chance := 0.22
		if spot.has("poi"):
			chance = 0.7
		if rng.randf() > chance:
			continue
		var item := _forage_item(spot, rng)
		if item == "":
			continue
		var id := "fg%d_%d" % [spot["i"], d]
		if not node_present(id, -1):
			continue
		var p: Vector2 = spot["p"]
		var n := ResourceNode.new()
		nodes_root.add_child(n)
		n.setup(id, "forage", _v3(p), rng.randf() * TAU, 0, 1.0, {"item": item})
		register(n)
		forage_ids.append(id)
	# buried things: a few dig spots each day
	var rng2 := Game.rng_for("dig", d)
	for i in 7:
		var spot2: Dictionary = gen.forage_spots[rng2.randi() % gen.forage_spots.size()]
		if spot2["b"] in [OverworldGen.B.ROCKY]:
			continue
		var id2 := "dg%d_%d" % [i, d]
		if not node_present(id2, -1):
			continue
		var p2: Vector2 = spot2["p"] + Vector2(1.5, 1.0)
		var n2 := ResourceNode.new()
		nodes_root.add_child(n2)
		n2.setup(id2, "dig", _v3(p2), 0.0, 0)
		register(n2)
		forage_ids.append(id2)

func on_new_day() -> void:
	upgrade_farmhouse()
	_spawn_forage()
	for s in gen.spawns:
		if s["k"] != "bush" and not objs.has(s["id"]):
			_spawn_node(s)
	for q in gen.pois:
		pass
	_build_pois_respawn()
	for o in objs.values():
		if o is ResourceNode and o.sub == "berry_bush":
			o.refresh()
	if farm:
		farm.refresh_all()
	if town:
		town.on_new_day()

func _build_pois_respawn() -> void:
	# POI nodes with respawn timers are recreated by re-running their spec when absent
	var rng := RandomNumberGenerator.new()
	for q in gen.pois:
		var c: Vector2 = q["pos"]
		var pid: String = q["id"]
		rng.seed = Game.hash_ints(gen.seed_value, pid.hash())
		match q["type"]:
			"copper_outcrop":
				for i in 5:
					var a5 := TAU * i / 5.0 + rng.randf()
					var p5 := c + Vector2(cos(a5), sin(a5)) * rng.randf_range(1.5, 4.0)
					var r := rng.randf() * TAU
					add_node_spec(pid + "_o%d" % i, "copper_node" if i < 3 else "rock_med", _v3(p5), r, i)
			"clay_bank":
				for i in 4:
					var p := c + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
					add_node_spec(pid + "_clay%d" % i, "clay", _v3(p), rng.randf() * TAU)
			"ruins":
				for i in 4:
					rng.randf()
				for i in 3:
					add_node_spec(pid + "_cache%d" % i, "ruin_cache", _v3(c + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))))

# ------------------------------------------------------------------ changes from the server

func _on_change(k: String, ch: Dictionary) -> void:
	match k:
		"removed":
			if ch["z"] == zone_id:
				var id: String = ch["id"]
				if id.begins_with("b:"):
					var bush = objs.get(id.substr(2))
					if bush:
						bush.refresh()
				elif objs.has(id):
					var o = objs[id]
					unregister(o)
					if o is ResourceNode:
						o.on_removed()
					else:
						o.vanish()
		"obj_add":
			if ch["v"].get("z", "") == zone_id:
				_spawn_placed(ch["id"], ch["v"])
		"obj_del":
			if objs.has(ch["id"]):
				remove_obj(ch["id"])
		"obj_data":
			if objs.has(ch["id"]) and objs[ch["id"]] is PlacedObj:
				objs[ch["id"]].on_data(ch["v"])
		"farm_level":
			upgrade_farmhouse()
		"flag":
			if ch["k"] == "bridge_fixed" and ch["v"]:
				fix_old_bridge()
	if farm:
		farm.on_change(k, ch)
	if town:
		town.on_change(k, ch)

# ------------------------------------------------------------------ discovery & exploration

func _process(delta: float) -> void:
	var lp = Game.local_player
	if lp == null or lp.zone_id != zone_id:
		return
	_discover_t += delta
	if _discover_t > 0.5:
		_discover_t = 0.0
		var p := Vector2(lp.global_position.x, lp.global_position.z)
		for q in gen.pois:
			if p.distance_to(q["pos"]) < float(q["r"]) and not Game.world["know"]["places"].has(q["id"]) and q.get("name", "") != "":
				Net.request("discover_place", {"id": q["id"], "name": q["name"]})
	_explore_t += delta
	if _explore_t > 1.0:
		_explore_t = 0.0
		_mark_explored(lp.global_position)

func _mark_explored(pos: Vector3) -> void:
	var ex: PackedByteArray = Game.world.get("explored", PackedByteArray())
	var W := OverworldGen.EX_W
	if ex.size() != W * W:
		return
	var cells := PackedInt32Array()
	var cx := int(pos.x / OverworldGen.EXPLORE_CELL)
	var cz := int(pos.z / OverworldGen.EXPLORE_CELL)
	var r := 6
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r:
				continue
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= W or z >= W:
				continue
			var i := z * W + x
			if ex[i] == 0:
				cells.append(i)
	if cells.size() > 0:
		for i in cells:
			ex[i] = 1
		Game.world["explored"] = ex
		Net.request("explore", {"cells": cells})
