class_name TownBuilder
extends Node3D
## Turns TownGen data into the living town: buildings, plaza, residents, shop
## counters, the request board, and everything that appears as the town grows.

var over: Overworld
var gen: TownGen
var npcs := {}
var build_root: Node3D
var extras_root: Node3D
var _built_flags := {}

func build(o: Overworld) -> void:
	over = o
	gen = TownGen.new()
	gen.generate(o.gen)
	Zones.town = gen
	build_root = Node3D.new()
	add_child(build_root)
	extras_root = Node3D.new()
	add_child(extras_root)
	for b in gen.buildings:
		_place_building(b)
	_build_plaza()
	_build_decor()
	for p in gen.residents:
		_spawn_npc(p)
	refresh_growth()

func _place_building(b: Dictionary) -> void:
	if b["role"] == "lot":
		var f := Feature.new().setup("lot_" + b["id"], "sign", "Read sign", b["front"], 0.8, {"text": "LOT AVAILABLE. Inquire at the Town Hall about Welcome Cottages."})
		over.add_child(f)
		f.set_mesh(Props.get_mesh("signpost", 0), 0.0, b["yaw"])
		over.register(f)
		return
	if b["role"] == "curio_hall" and not bool(Game.world["flags"].get("project_curio_hall", false)):
		var f2 := Feature.new().setup("lot_" + b["id"], "sign", "Read sign", b["front"], 0.8, {"text": "Future site of the Curio Hall, should anyone ever find enough curiosities to fill it."})
		over.add_child(f2)
		f2.set_mesh(Props.get_mesh("signpost", 0), 0.0, b["yaw"])
		over.register(f2)
		return
	var role: String = b["role"]
	var params := {"seed": b["seed"], "w": b["w"], "d": b["d"], "floors": b["floors"], "wall": b["wall"], "roof": b["roof"],
		"style": b["style"], "timber": b["timber"], "door_x": b["door_x"], "chimney": role != "curio_hall"}
	if role in TownGen.SHOP_ROLES and role != "mayor":
		params["sign"] = true
		params["sign_col"] = b.get("sign_col", Color.WHITE)
		params["counter"] = true
		params["awning"] = role in ["merchant", "herbalist", "angler"]
		params["awning_col"] = b.get("sign_col", Color("c0504a")).darkened(0.1)
	if role in ["mayor", "curio_hall"]:
		params["wall"] = Color("e8dcc8")
		params["roof"] = Color("6a4a5a") if role == "mayor" else Color("4a5a6a")
		params["flowers"] = true
	if role == "house":
		params["flowers"] = (b["seed"] % 3) == 0
	var mesh := Meshes.cached("bld_" + b["id"] + "_" + str(int(Game.world.get("seed", 0))), func(): return Props.building(params))
	var mi := Meshes.inst(mesh, build_root, b["pos"], b["yaw"])
	var bh := 2.9 + (int(b["floors"]) - 1) * 2.4 + float(b["w"]) * 0.42
	Zones.register_occluder(mi, "over", b["pos"] + Vector3(0, bh / 2.0, 0), Vector3(b["w"] / 2.0 + 0.6, bh / 2.0 + 0.3, b["d"] / 2.0 + 0.6), b["yaw"])
	var body := StaticBody3D.new()
	build_root.add_child(body)
	body.position = b["pos"]
	body.rotation.y = b["yaw"]
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(b["w"] + 0.3, 6.0, b["d"] + 0.3)
	cs.shape = bs
	cs.position = Vector3(0, 3.0, 0)
	body.add_child(cs)
	if params.get("counter", false):
		var cc := CollisionShape3D.new()
		var cb := BoxShape3D.new()
		cb.size = Vector3(1.9, 1.0, 0.7)
		cc.shape = cb
		cc.position = Vector3(b["door_x"] - 1.6, 0.5, b["d"] / 2.0 + 1.6)
		body.add_child(cc)
	var shop: String = TownGen.ROLE_INFO.get(role, {}).get("shop", "")
	if shop != "":
		var fpos: Vector3 = b["pos"] + Basis(Vector3.UP, b["yaw"]) * Vector3(b["door_x"] - 1.6, 0, b["d"] / 2.0 + 0.9 + 1.6)
		fpos.y = over.ground_y(fpos.x, fpos.z)
		var f3 := Feature.new().setup("shop_" + shop, "shop", "Browse the %s" % b["name"], fpos, 1.2, {"shop": shop, "role": role, "bname": b["name"]})
		over.add_child(f3)
		over.register(f3)
	if role == "mayor":
		var f4 := Feature.new().setup("hall_projects", "projects", "Community projects ledger", b["front"] + b["fwd"] * 0.4, 1.2)
		over.add_child(f4)
		over.register(f4)
	if role == "curio_hall":
		var f5 := Feature.new().setup("curio_hall", "curio", "Visit the Curio Hall", b["front"], 1.2)
		over.add_child(f5)
		over.register(f5)
	# windows light up at night
	if role != "lot":
		var l := OmniLight3D.new()
		l.light_color = Color("ffc878")
		l.light_energy = 0.8
		l.omni_range = 5.0
		l.position = b["front"] + Vector3(0, 1.8, 0)
		build_root.add_child(l)
		Zones.register_night_light(l)

func _build_plaza() -> void:
	var c := gen.center
	var lvl := 1 if Game.world["flags"].get("project_fountain", false) else 0
	var fountain := Meshes.inst(Props.get_mesh("fountain", lvl), extras_root, Vector3(c.x, over.ground_y(c.x, c.z) - 0.05, c.z))
	fountain.name = "Fountain"
	var body := StaticBody3D.new()
	extras_root.add_child(body)
	body.position = c
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 2.4 + lvl * 0.6
	cy.height = 1.4
	cs.shape = cy
	cs.position = Vector3(0, 0.7, 0)
	body.add_child(cs)
	var farm_ang: float = gen.road_angles[0]
	var bp := c + Vector3(cos(farm_ang), 0, sin(farm_ang)) * (TownGen.PLAZA_R + 1.5)
	bp.y = over.ground_y(bp.x, bp.z)
	var board := Feature.new().setup("request_board", "board", "Read the request board", bp, 1.2)
	over.add_child(board)
	board.set_mesh(Props.get_mesh("notice_board", 0), 0.0, -farm_ang + PI / 2.0)
	board.add_box_blocker(Vector3(2.0, 2.0, 0.4), Vector3.ZERO, -farm_ang + PI / 2.0)
	over.register(board)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var lp := c + Vector3(cos(a), 0, sin(a)) * (TownGen.PLAZA_R + 3.6)
		lp.y = over.ground_y(lp.x, lp.z)
		_lamp(lp)

func _lamp(p: Vector3) -> void:
	Meshes.inst(Props.get_mesh("lamp", 0), extras_root, p)
	var l := OmniLight3D.new()
	l.light_color = Color("ffd38a")
	l.light_energy = 1.4
	l.omni_range = 9.0
	l.position = p + Vector3(0, 2.3, 0)
	extras_root.add_child(l)
	Zones.register_night_light(l)

func _build_decor() -> void:
	for d in gen.decor:
		var p: Vector3 = d["p"]
		p.y = over.ground_y(p.x, p.z)
		match d["k"]:
			"tree":
				var t = ["oak", "birch", "oak", "willow"][int(d["v"]) % 4]
				Meshes.inst(Props.get_mesh(t, int(d["v"])), extras_root, p, d["r"])
				var b := StaticBody3D.new()
				var cs := CollisionShape3D.new()
				var sh := CylinderShape3D.new()
				sh.radius = 0.4
				sh.height = 3.0
				cs.shape = sh
				cs.position = Vector3(0, 1.5, 0)
				b.add_child(cs)
				extras_root.add_child(b)
				b.position = p
			"bench":
				Meshes.inst(Props.get_mesh("bench_prop", 0), extras_root, p, d["r"])
			"crate":
				Meshes.inst(Props.get_mesh("crate_prop" if int(abs(p.x * 7.0 + p.z * 13.0)) % 2 == 0 else "barrel_prop", 0), extras_root, p, d["r"], 0.8)

func _spawn_npc(p: Dictionary) -> void:
	if npcs.has(p["id"]):
		return
	var n := NPC.new()
	add_child(n)
	n.setup(p, gen)
	npcs[p["id"]] = n

func npc(id: String) -> NPC:
	return npcs.get(id)

# ------------------------------------------------------------------ growth

func refresh_growth() -> void:
	var f: Dictionary = Game.world["flags"]
	if f.get("project_market", false) and not _built_flags.has("market"):
		_built_flags["market"] = true
		var c := gen.center
		for i in 3:
			var a = TAU * i / 3.0 + gen.road_angles[0] + PI / 3.0
			var p := c + Vector3(cos(a), 0, sin(a)) * 6.0
			p.y = over.ground_y(p.x, p.z)
			Meshes.inst(Props.get_mesh("market_stall", i), extras_root, p, -a - PI / 2.0)
		var mp := c + Vector3(cos(gen.road_angles[0] + PI), 0, sin(gen.road_angles[0] + PI)) * 6.0
		mp.y = over.ground_y(mp.x, mp.z)
		var ms := Feature.new().setup("shop_market", "shop", "Browse the traveling market", mp, 1.6, {"shop": "market", "role": "", "bname": "Traveling Market"})
		over.add_child(ms)
		over.register(ms)
	if f.get("project_lamps", false) and not _built_flags.has("lamps"):
		_built_flags["lamps"] = true
		for line in over.gen.roads:
			var acc := 0.0
			for i in range(1, line.size()):
				acc += line[i - 1].distance_to(line[i])
				if acc > 14.0:
					acc = 0.0
					var q: Vector2 = line[i]
					var nrm: Vector2 = (line[i] - line[i - 1]).normalized().orthogonal() * 2.6
					var lp := Vector3(q.x + nrm.x, 0, q.y + nrm.y)
					if not over.gen.water_at(lp.x, lp.z).is_empty():
						continue
					lp.y = over.ground_y(lp.x, lp.z)
					_lamp(lp)
	if f.get("project_fountain", false) and not _built_flags.has("fountain"):
		_built_flags["fountain"] = true
		var old := extras_root.get_node_or_null("Fountain")
		if old:
			old.mesh = Props.get_mesh("fountain", 1)
		for i in 6:
			var a2 := TAU * i / 6.0 + 0.2
			var fp := gen.center + Vector3(cos(a2), 0, sin(a2)) * (TownGen.PLAZA_R - 1.2)
			fp.y = over.ground_y(fp.x, fp.z)
			Meshes.inst(Props.get_mesh("flower_bed", i), extras_root, fp, -a2 + PI / 2.0)
	if int(Game.world["town"].get("level", 0)) >= 3 and not _built_flags.has("bunting"):
		_built_flags["bunting"] = true
		for i in 3:
			var a3 := TAU * i / 3.0
			var bp := gen.center + Vector3(cos(a3), 0, sin(a3)) * 2.0
			var bm := Meshes.inst(Props.get_mesh("bunting", 0), extras_root, bp + Vector3(0, 4.2, 0), a3)
			bm.scale = Vector3(1.6, 1, 1)
	if f.get("project_curio_hall", false) and not _built_flags.has("curio"):
		_built_flags["curio"] = true
		var b := gen.building_for_role("curio_hall")
		if not b.is_empty():
			if over.objs.has("lot_" + b["id"]):
				over.remove_obj("lot_" + b["id"], false)
			b["reserved"] = false
			_place_building(b)
	if f.get("project_lodge", false) and not _built_flags.has("lodge"):
		_built_flags["lodge"] = true
		var cp := over.gen.cave_pos + Vector2(12, 12)
		var lpos := Vector3(cp.x, over.ground_y(cp.x, cp.y), cp.y)
		var lmi := Meshes.inst(Props.get_mesh("lodge", 0), extras_root, lpos, 0.0)
		Zones.register_occluder(lmi, "over", lpos + Vector3(0, 3.0, 0), Vector3(4.6, 3.2, 3.6), 0.0)
		var body := StaticBody3D.new()
		extras_root.add_child(body)
		body.position = lpos
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(8.3, 6, 6.3)
		cs.shape = bs
		cs.position = Vector3(0, 3, 0)
		body.add_child(cs)
		var ls := Feature.new().setup("shop_lodge", "shop", "Browse the Expedition Lodge", lpos + Vector3(-2.0, 0, 4.2), 1.4, {"shop": "lodge", "role": "", "bname": "Expedition Lodge"})
		over.add_child(ls)
		over.register(ls)
	# newcomers moving into their new cottages
	for p in gen.residents:
		if not npcs.has(p["id"]):
			_spawn_npc(p)
	for b2 in gen.buildings:
		if b2["role"] == "house" and over.objs.has("lot_" + b2["id"]):
			over.remove_obj("lot_" + b2["id"], false)
			_place_building(b2)

func on_new_day() -> void:
	var want := int(Game.world["town"].get("newcomers", 0))
	var have := 0
	for p in gen.residents:
		if int(p.get("arrived", 0)) > 0:
			have += 1
	while have < want:
		gen.add_newcomer(have)
		have += 1
	refresh_growth()

func on_change(k: String, ch: Dictionary) -> void:
	if k == "flag" and String(ch["k"]).begins_with("project_"):
		refresh_growth()
	if k == "town" and ch["k"] == "newcomers":
		on_new_day()
