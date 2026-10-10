class_name CaveFloor
extends Zone
## One floor of the caves, built from CaveGen data: smooth marching-squares
## walls, a floor that slopes into lakes and chasms, water and lava, lights,
## gatherables, features, and (on the host) the creatures that live here.

const WALL_H := 4.2
const CELL := CaveGen.CELL

var floor_n := 1
var gen: CaveGen
var astar: AStarGrid2D
var map_tex: ImageTexture
var waystone_feature: Feature
var _wander_t := 60.0
var _seen_t := 0.0
var _seen_send_t := 0.0
var _seen_pending := PackedInt32Array()
var _map_dirty := true
var _initial_enemies := 0

func _init() -> void:
	super._init()
	kind = "cave"

func underground() -> bool:
	return true

func env_profile() -> String:
	return "cave"

func display_name() -> String:
	return "Floor %d · %s" % [floor_n, gen.biome["name"] if gen else ""]

func cave_palette() -> Dictionary:
	var b: Dictionary = gen.biome
	var depth_dim: float = clamp(1.0 - (floor_n % 5) * 0.03, 0.8, 1.0)
	return {"ambient": b["amb"], "fog": b["fog"], "amb": float(b["amb_e"]) * depth_dim, "motes": b["motes"]}

# ------------------------------------------------------------------ coordinates

func cell_center(c: Vector2) -> Vector3:
	return origin + Vector3(c.x * CELL, 0, c.y * CELL)

func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.z - origin.z) / CELL))

func cell_type(p: Vector3) -> int:
	return gen.get_t(world_to_cell(p))

func ground_y(_x: float, _z: float) -> float:
	return origin.y

func is_blocked(p: Vector3) -> bool:
	var c := world_to_cell(p)
	var t := gen.get_t(c)
	if c == gen.hidden_wall and objs.has("cracked"):
		return true
	return t == CaveGen.T.WATER or t == CaveGen.T.PIT or t == CaveGen.T.LAVA or t == CaveGen.T.WALL

func can_stand(p: Vector3, flying: bool) -> bool:
	var c := world_to_cell(p)
	var t := gen.get_t(c)
	if t == CaveGen.T.WALL:
		return false
	if c == gen.hidden_wall and objs.has("cracked"):
		return false
	if flying:
		return true
	return t == CaveGen.T.FLOOR or t == CaveGen.T.BRIDGE

func water_at(p: Vector3) -> Dictionary:
	var t := cell_type(p)
	if t == CaveGen.T.WATER:
		return {"kind": gen.biome["water"], "lvl": origin.y - 0.25, "name": "an underground pool", "id": "cave_%d_pool" % floor_n}
	if t == CaveGen.T.LAVA:
		return {"kind": "cave_ember", "lvl": origin.y - 0.45, "name": "a lava pool", "id": "cave_%d_lava" % floor_n, "lava": true}
	return {}

func spawn_point(tag: String = "") -> Vector3:
	match tag:
		"down":
			return cell_center(Vector2(gen.exit_cell) + Vector2(0.5, 0.5)) + Vector3(2.0, 0.2, 0.5)
		"waystone":
			if gen.waystone_cell.x >= 0:
				return cell_center(Vector2(gen.waystone_cell) + Vector2(0.5, 0.5)) + Vector3(1.6, 0.2, 0)
	return cell_center(Vector2(gen.start_cell) + Vector2(0.5, 0.5)) + Vector3(1.4, 0.2, 1.4)

# ------------------------------------------------------------------ build

func build() -> void:
	gen = CaveGen.new()
	gen.generate(int(Game.world.get("seed", 1)), floor_n)
	_build_floor_mesh()
	_build_walls()
	_build_liquids()
	_build_bridges()
	_build_decor()
	_build_lights()
	_build_features()
	_build_nodes()
	_build_astar()
	_build_map()
	for oid in Game.world.get("objects", {}):
		var o: Dictionary = Game.world["objects"][oid]
		if o.get("z", "") == zone_id and not objs.has(oid):
			var po := PlacedObj.new()
			objects_root.add_child(po)
			po.setup(oid, o)
			register(po)
	built = true

func _corner_h(x: int, y: int) -> float:
	var h := 0.0
	var any_open := false
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var t := gen.get_t(Vector2i(x, y) + d)
		match t:
			CaveGen.T.PIT:
				h = min(h, -7.0)
			CaveGen.T.WATER:
				h = min(h, -1.3)
			CaveGen.T.LAVA:
				h = min(h, -1.0)
		if t != CaveGen.T.WALL:
			any_open = true
	return h if any_open else -0.2

func _build_floor_mesh() -> void:
	var b: Dictionary = gen.biome
	var fcol: Color = b["floor"]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var W := gen.W
	var H := gen.H
	var nz := FastNoiseLite.new()
	nz.seed = floor_n * 31
	nz.frequency = 0.15
	for y in H + 1:
		for x in W + 1:
			var h := _corner_h(x, y)
			verts.append(origin + Vector3(x * CELL, h + nz.get_noise_2d(x * 3.0, y * 3.0) * 0.06, y * CELL))
			var c := fcol.lerp(fcol.lightened(0.15), nz.get_noise_2d(x, y) * 0.5 + 0.5)
			if h < -5.0:
				c = Color(0.02, 0.02, 0.025)
			elif h < -0.5:
				c = fcol.darkened(0.35) if gen.biome["id"] != "ember" else Color("2a1410")
			cols.append(c)
	for y in H:
		for x in W:
			var i := y * (W + 1) + x
			idx.append_array([i, i + 1, i + W + 1, i + 1, i + W + 2, i + W + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, Meshes.mat("vc_nosnow"))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.layers = 2
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(W * CELL + 10, 1.0, H * CELL + 10)
	cs.shape = bs
	cs.position = origin + Vector3(W * CELL / 2.0, -0.5, H * CELL / 2.0)
	body.add_child(cs)
	add_child(body)

func _density(x: int, y: int) -> float:
	var n := 0.0
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		if gen.get_t(Vector2i(x, y) + d) == CaveGen.T.WALL:
			n += 1.0
	return n / 4.0

func _build_walls() -> void:
	var b: Dictionary = gen.biome
	var wall_col: Color = b["wall"]
	var cap_col: Color = b["cap"]
	var mb := MeshBuilder.new(floor_n)
	mb.surface("cave_wall")
	var cap := MeshBuilder.new(floor_n + 1)
	cap.surface("cave_cap")
	var faces := PackedVector3Array()
	var W := gen.W
	var H := gen.H
	var dens := PackedFloat32Array()
	dens.resize((W + 1) * (H + 1))
	for y in H + 1:
		for x in W + 1:
			dens[y * (W + 1) + x] = _density(x, y)
	var nz := FastNoiseLite.new()
	nz.seed = floor_n * 97
	nz.frequency = 0.35
	for y in H:
		for x in W:
			var cv := [dens[y * (W + 1) + x], dens[y * (W + 1) + x + 1], dens[(y + 1) * (W + 1) + x + 1], dens[(y + 1) * (W + 1) + x]]
			var cp := [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]
			var solid := 0
			for v in cv:
				if v >= 0.5:
					solid += 1
			if solid == 0:
				continue
			# polygon of the solid part of this square, and the contour segments
			var poly: Array = []
			var cuts: Array = []
			for i in 4:
				var j := (i + 1) % 4
				var a: float = cv[i]
				var bb: float = cv[j]
				if a >= 0.5:
					poly.append(cp[i])
				if (a >= 0.5) != (bb >= 0.5):
					var t := (0.5 - a) / (bb - a)
					var e: Vector2 = cp[i].lerp(cp[j], t)
					poly.append(e)
					cuts.append(e)
			var inner := Vector2.ZERO
			for i in 4:
				if cv[i] >= 0.5:
					inner += cp[i]
			inner /= float(solid)
			if poly.size() >= 3:
				var c0: Vector2 = poly[0]
				for i in range(1, poly.size() - 1):
					var p1: Vector2 = poly[i]
					var p2: Vector2 = poly[i + 1]
					cap.tri_out(_w(c0, WALL_H + _jit(nz, c0)), _w(p1, WALL_H + _jit(nz, p1)), _w(p2, WALL_H + _jit(nz, p2)), cap_col.lerp(wall_col, 0.45), _w(inner, -10.0))
			if cuts.size() >= 2:
				for k in range(0, cuts.size() - 1, 2):
					var e0: Vector2 = cuts[k]
					var e1: Vector2 = cuts[k + 1]
					var top0 := WALL_H + _jit(nz, e0)
					var top1 := WALL_H + _jit(nz, e1)
					var lean0 := _lean(nz, e0, inner)
					var lean1 := _lean(nz, e1, inner)
					var q0 := _w(e0, -0.4)
					var q1 := _w(e1, -0.4)
					var q2 := _w(e1 + lean1, top1)
					var q3 := _w(e0 + lean0, top0)
					var mid := _w(inner, 1.5)
					var shade := wall_col.lightened(nz.get_noise_2d(e0.x * 2.0, e0.y * 2.0) * 0.12)
					mb.quad_out(q0, q1, q2, q3, shade, mid)
					faces.append_array([q0, q1, q2, q0, q2, q3])
	var wm := MeshInstance3D.new()
	wm.mesh = mb.commit()
	wm.layers = 2
	add_child(wm)
	var cm := MeshInstance3D.new()
	cm.mesh = cap.commit()
	cm.layers = 2
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cm)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

func _jit(nz: FastNoiseLite, p: Vector2) -> float:
	return nz.get_noise_2d(p.x * 2.0, p.y * 2.0) * 0.9

func _lean(nz: FastNoiseLite, p: Vector2, inner: Vector2) -> Vector2:
	var dir := (inner - p).normalized()
	return dir * (0.25 + 0.2 * nz.get_noise_2d(p.y * 3.0, p.x * 3.0))

func _w(p: Vector2, y: float) -> Vector3:
	return origin + Vector3(p.x * CELL, y, p.y * CELL)

func _build_liquids() -> void:
	var mbw := MeshBuilder.new(1)
	mbw.surface("water_cave")
	var mbl := MeshBuilder.new(2)
	mbl.surface("lava")
	var any_lava := false
	for y in gen.H:
		for x in gen.W:
			var t := gen.get_t(Vector2i(x, y))
			if t != CaveGen.T.WATER and t != CaveGen.T.LAVA:
				continue
			var lvl := -0.25 if t == CaveGen.T.WATER else -0.45
			var e := 0.35
			var a := _w(Vector2(x - e / CELL, y - e / CELL), lvl)
			var bb := _w(Vector2(x + 1 + e / CELL, y - e / CELL), lvl)
			var c := _w(Vector2(x + 1 + e / CELL, y + 1 + e / CELL), lvl)
			var d := _w(Vector2(x - e / CELL, y + 1 + e / CELL), lvl)
			var target := mbw if t == CaveGen.T.WATER else mbl
			if t == CaveGen.T.LAVA:
				any_lava = true
			target.quad_out(a, bb, c, d, Color.WHITE, a - Vector3(0, 1, 0) + (c - a) * 0.5)
	if not mbw.is_empty():
		var wm := MeshInstance3D.new()
		wm.mesh = mbw.commit()
		wm.layers = 2
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wm)
	if any_lava:
		var lm := MeshInstance3D.new()
		lm.mesh = mbl.commit()
		lm.layers = 2
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lm)

func _build_bridges() -> void:
	for br in gen.bridges:
		var a := Vector2(br["a"]) + Vector2(0.5, 0.5)
		var b := Vector2(br["b"]) + Vector2(0.5, 0.5)
		var mid := (a + b) / 2.0
		var dir := (b - a)
		var length := dir.length() * CELL
		var yaw := atan2(dir.x, dir.y)
		var mi := Meshes.inst(CaveProps.get_mesh("bridge_plank", int(round(max(0.0, (length - 4.0) / 2.0)))), self, cell_center(mid) + Vector3(0, 0.02, 0), yaw)
		mi.layers = 2

func _build_decor() -> void:
	for d in gen.decor:
		var p := cell_center(d["p"])
		var k: String = d["k"]
		if k == "vein_marker":
			continue
		var mesh: Mesh
		var block := 0.0
		match k:
			"rail", "support", "bedroll", "glow_shrooms", "giant_mushroom", "lantern_post", "pillar", "statue", "lava_rock", "moss_patch", "crystal_big", "crystal_cluster":
				mesh = CaveProps.get_mesh(k, int(d.get("v", 0)))
			"stalagmite":
				mesh = CaveProps.get_mesh(k, int(d.get("v", 0)) % 3 + gen.biome_i * 3)
				block = 0.45
			"fire_ring":
				mesh = Props.get_mesh("fire_ring", 0)
			_:
				mesh = CaveProps.get_mesh(k, 0)
		if k in ["pillar", "statue", "giant_mushroom", "crystal_big"]:
			block = 0.6
		var mi := Meshes.inst(mesh, self, p, d["r"])
		mi.layers = 2
		if k == "support":
			mi.position.y = 0.0
		if block > 0.0:
			var b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = block
			sh.height = 3.0
			cs.shape = sh
			cs.position = Vector3(0, 1.5, 0)
			b.add_child(cs)
			add_child(b)
			b.position = p

func _build_lights() -> void:
	var n := 0
	for l in gen.lights:
		if n >= 18:
			break
		var o := OmniLight3D.new()
		o.light_color = l["c"]
		o.light_energy = float(l["e"]) * 1.4
		o.omni_range = 7.5
		o.omni_attenuation = 1.4
		o.position = cell_center(l["p"]) + Vector3(0, l.get("h", 1.2), 0)
		o.shadow_enabled = false
		add_child(o)
		n += 1
	# lava glows on its own
	var lava_seen := 0
	for y in range(0, gen.H, 4):
		for x in range(0, gen.W, 4):
			if gen.get_t(Vector2i(x, y)) == CaveGen.T.LAVA and lava_seen < 8:
				var o2 := OmniLight3D.new()
				o2.light_color = Color("ff6a20")
				o2.light_energy = 1.6
				o2.omni_range = 8.0
				o2.position = cell_center(Vector2(x + 0.5, y + 0.5)) + Vector3(0, 0.6, 0)
				add_child(o2)
				lava_seen += 1

func _build_features() -> void:
	var up := Feature.new().setup("ladder_up", "ladder_up", "Climb up" if floor_n > 1 else "Climb back to the surface", cell_center(Vector2(gen.start_cell) + Vector2(0.5, 0.5)), 1.2)
	add_child(up)
	up.set_mesh(CaveProps.get_mesh("ladder"))
	up.mesh_inst.layers = 2
	register(up)
	var ul := OmniLight3D.new()
	ul.light_color = Color("dfe8c8")
	ul.light_energy = 1.2
	ul.omni_range = 6.0
	ul.position = up.position + Vector3(0, 3.0, 0)
	add_child(ul)
	var down := Feature.new().setup("hole_down", "stairs_down", "Climb down to floor %d" % (floor_n + 1), cell_center(Vector2(gen.exit_cell) + Vector2(0.5, 0.5)), 1.4)
	add_child(down)
	down.set_mesh(CaveProps.get_mesh("hole"))
	down.mesh_inst.layers = 2
	register(down)
	var dl := OmniLight3D.new()
	dl.light_color = Color("9ab0ff")
	dl.light_energy = 0.7
	dl.omni_range = 5.0
	dl.position = down.position + Vector3(0, 1.0, 0)
	add_child(dl)
	if gen.waystone_cell.x >= 0:
		var lit: bool = Game.world["know"]["waystones"].has(floor_n)
		waystone_feature = Feature.new().setup("waystone", "waystone", "Touch the waystone", cell_center(Vector2(gen.waystone_cell) + Vector2(0.5, 0.5)), 1.2)
		add_child(waystone_feature)
		waystone_feature.set_mesh(CaveProps.get_mesh("waystone", 1 if lit else 0))
		waystone_feature.add_box_blocker(Vector3(0.7, 2.6, 0.6))
		register(waystone_feature)
		var wl := OmniLight3D.new()
		wl.light_color = Color("7fe3ff")
		wl.light_energy = 1.2 if lit else 0.3
		wl.omni_range = 6.0
		wl.position = waystone_feature.position + Vector3(0, 1.6, 0)
		wl.name = "WaystoneLight"
		add_child(wl)

func _build_nodes() -> void:
	for s in gen.spawns:
		var info := ResourceNode.info(s["k"])
		var resp: int = info.get("respawn", -1)
		if not node_present(s["id"], resp):
			continue
		var n := ResourceNode.new()
		nodes_root.add_child(n)
		var x: Dictionary = s.get("x", {}).duplicate()
		x["depth"] = floor_n
		x["biome"] = gen.biome_i
		n.setup(s["id"], s["k"], cell_center(s["p"]), s["r"], s["v"], 1.0, x)
		if n.mesh_inst:
			n.mesh_inst.layers = 2
		register(n)
	if gen.hidden_wall.x >= 0 and node_present("cracked", -1):
		var cw := ResourceNode.new()
		nodes_root.add_child(cw)
		var center := cell_center(Vector2(gen.hidden_wall) + Vector2(0.5, 0.5))
		cw.setup("cracked", "cracked_wall", center, 0.0, 0, 1.0, {"biome": gen.biome_i, "depth": floor_n})
		register(cw)
	_spawn_keepsakes()

func _spawn_keepsakes() -> void:
	for r in QuestLogic.fetch_items_for_floor(floor_n):
		var id := "q%d" % int(r["qid"])
		if objs.has(id) or not node_present(id, -1):
			continue
		var c := gen.keepsake_cell(int(r["qid"]))
		var n := ResourceNode.new()
		nodes_root.add_child(n)
		n.setup(id, "quest_item", cell_center(Vector2(c) + Vector2(0.5, 0.5)), 0.0, 0, 1.0, {"item": r["item"], "depth": floor_n})
		register(n)

func note_for(oid: String) -> int:
	return Lore.cave_note_for_floor(floor_n, abs(oid.hash()))

func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, gen.W, gen.H)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in gen.H:
		for x in gen.W:
			var c := Vector2i(x, y)
			if not gen.walkable(c) or c == gen.hidden_wall:
				astar.set_point_solid(c, true)

func path_to(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b) or astar.is_point_solid(a) or astar.is_point_solid(b):
		return out
	var ids := astar.get_id_path(a, b)
	for c in ids:
		out.append(cell_center(Vector2(c) + Vector2(0.5, 0.5)))
	return out

func _build_map() -> void:
	var img := Image.create(gen.W, gen.H, false, Image.FORMAT_RGBA8)
	var fc: Color = gen.biome["floor"].lightened(0.25)
	var seen := seen_bytes()
	for y in gen.H:
		for x in gen.W:
			var c := Color(0.06, 0.05, 0.05)
			if seen[y * gen.W + x] == 0:
				img.set_pixel(x, y, Color(0.03, 0.025, 0.025, 0.0))
				continue
			match gen.get_t(Vector2i(x, y)):
				CaveGen.T.FLOOR:
					c = fc
				CaveGen.T.BRIDGE:
					c = Color("a07a4a")
				CaveGen.T.WATER:
					c = Color("3f7aa8")
				CaveGen.T.LAVA:
					c = Color("e0602a")
				CaveGen.T.PIT:
					c = Color(0.0, 0.0, 0.0)
			img.set_pixel(x, y, c)
	if map_tex:
		map_tex.update(img)
	else:
		map_tex = ImageTexture.create_from_image(img)
	_map_dirty = false

func map_texture() -> Texture2D:
	if _map_dirty:
		_build_map()
	return map_tex

## Which cells of this floor the household has seen (shared, saved with the world).
func seen_bytes() -> PackedByteArray:
	var know: Dictionary = Game.world["know"]
	if not know.has("cave_seen"):
		know["cave_seen"] = {}
	var b = know["cave_seen"].get(floor_n, null)
	if b == null or (b as PackedByteArray).size() != gen.W * gen.H:
		b = PackedByteArray()
		b.resize(gen.W * gen.H)
		b.fill(0)
		know["cave_seen"][floor_n] = b
	return b

func is_seen_at(p: Vector3) -> bool:
	var c := world_to_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= gen.W or c.y >= gen.H:
		return false
	return seen_bytes()[c.y * gen.W + c.x] != 0

func _reveal_around(p: Vector3) -> void:
	var seen := seen_bytes()
	var c0 := world_to_cell(p)
	var r := 7
	var changed := false
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var c := c0 + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= gen.W or c.y >= gen.H:
				continue
			var i := c.y * gen.W + c.x
			if seen[i] == 0:
				seen[i] = 1
				_seen_pending.append(i)
				changed = true
	if changed:
		Game.world["know"]["cave_seen"][floor_n] = seen
		_map_dirty = true

func map_rect() -> Rect2:
	return Rect2(origin.x, origin.z, gen.W * CELL, gen.H * CELL)

func map_markers() -> Array:
	var out: Array = [
		{"p": cell_center(Vector2(gen.start_cell) + Vector2(0.5, 0.5)), "c": Color("9ae68a"), "label": "Ladder up"},
		{"p": cell_center(Vector2(gen.exit_cell) + Vector2(0.5, 0.5)), "c": Color("9ab0ff"), "label": "Way down"},
	]
	if gen.waystone_cell.x >= 0:
		out.append({"p": cell_center(Vector2(gen.waystone_cell) + Vector2(0.5, 0.5)), "c": Color("7fe3ff"), "label": "Waystone"})
	for o in objs.values():
		if o is ResourceNode and o.sub == "quest_item":
			out.append({"p": o.global_position, "c": Color("ffd36b"), "label": "Keepsake"})
	var seen_only: Array = []
	for m in out:
		if is_seen_at(m["p"]):
			seen_only.append(m)
	return seen_only

# ------------------------------------------------------------------ server-side life

func server_populate() -> void:
	for e in gen.enemies:
		var pos := cell_center(e["p"])
		Zones.server_spawn_enemy(zone_id, e["type"], pos, floor_n, e.get("elite", false))
	_initial_enemies = gen.enemies.size()

func on_player_entered_server(peer: int) -> void:
	var deepest := int(Game.world["know"].get("deepest", 0))
	if floor_n > deepest:
		Net.broadcast({"t": "deepest", "v": floor_n})
		var who := Net.name_of(peer)
		if floor_n % 5 == 0 or floor_n <= 1 or floor_n > deepest + 0:
			Net.server.chronicle("%s led the way down to floor %d — %s." % [who, floor_n, gen.biome["name"]], "cave")
		Net.broadcast({"t": "toast", "text": "New depth: floor %d!" % floor_n, "color": Color("bfe3ff")})
		Net.tell(peer, "stat", {"k": "floors_descended", "n": 1})

func _process(delta: float) -> void:
	if not built:
		return
	var lp = Game.local_player
	if lp and lp.zone_id == zone_id:
		_seen_t -= delta
		if _seen_t <= 0.0:
			_seen_t = 0.4
			_reveal_around(lp.global_position)
		_seen_send_t -= delta
		if _seen_send_t <= 0.0 and not _seen_pending.is_empty():
			_seen_send_t = 1.5
			Net.request("cave_explore", {"f": floor_n, "cells": _seen_pending})
			_seen_pending = PackedInt32Array()
	if not Net.is_server():
		return
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(70.0, 120.0)
		var alive := 0
		for e in Zones.enemies.values():
			if is_instance_valid(e) and e.zone_id == zone_id:
				alive += 1
		if alive < _initial_enemies / 2 and not Zones.players_in_zone(zone_id).is_empty():
			var room: Dictionary = gen.rooms[randi() % gen.rooms.size()]
			var c := Vector2i(room["c"])
			if gen.walkable(c):
				var tbl: Array = gen.biome["enemies"]
				Zones.server_spawn_enemy(zone_id, tbl[randi() % tbl.size()][0], cell_center(Vector2(c) + Vector2(0.5, 0.5)), floor_n, false)

func _on_change(k: String, ch: Dictionary) -> void:
	match k:
		"removed":
			if ch["z"] == zone_id and objs.has(ch["id"]):
				var o = objs[ch["id"]]
				unregister(o)
				if o is ResourceNode:
					o.on_removed()
					if o.sub == "cracked_wall":
						Fx.burst(fx_root, o.global_position + Vector3(0, 1.5, 0), gen.biome["wall"], 24, 6.0, 0.18)
						Sfx.play_at("slam", o.global_position)
						if astar:
							astar.set_point_solid(gen.hidden_wall, false)
				else:
					o.vanish()
		"waystone":
			if int(ch["v"]) == floor_n and waystone_feature:
				waystone_feature.set_mesh(CaveProps.get_mesh("waystone", 1))
				var wl := get_node_or_null("WaystoneLight")
				if wl:
					wl.light_energy = 1.2
				Fx.sparkle(fx_root, waystone_feature.global_position + Vector3(0, 1.5, 0), Color("7fe3ff"), 30, 1.0)
		"obj_add":
			if ch["v"].get("z", "") == zone_id:
				var po := PlacedObj.new()
				objects_root.add_child(po)
				po.setup(ch["id"], ch["v"])
				register(po)
		"obj_del":
			if objs.has(ch["id"]):
				remove_obj(ch["id"])
		"obj_data":
			if objs.has(ch["id"]) and objs[ch["id"]] is PlacedObj:
				objs[ch["id"]].on_data(ch["v"])
		"quests":
			_spawn_keepsakes()
		"cave_seen":
			if int(ch["f"]) == floor_n:
				_map_dirty = true

func on_new_day() -> void:
	pass
