class_name CaveGen
extends RefCounted
## Generates one cave floor: caverns joined by winding tunnels, underground lakes
## with narrow crossings, chasms spanned by plank bridges, old mining passages,
## sealed hidden chambers, ore (sometimes a huge vein), plants, camps and lore.
## Floors are persistent: the same seed and floor number always give the same cave.

const CELL := 2.0
enum T { FLOOR, WALL, WATER, PIT, BRIDGE, LAVA }

const BIOMES := [
	{"id": "earth", "name": "Earthen Tunnels", "floor": Color("8a7058"), "wall": Color("9a8066"), "cap": Color("2a2018"), "fog": Color(0.07, 0.05, 0.04), "amb": Color(0.62, 0.5, 0.4), "amb_e": 0.32, "motes": Color(1.0, 0.85, 0.6, 0.5), "light": Color("ffb870"),
		"ores": [["ore_copper", 6], ["coal_node", 3], ["ore_iron", 1], ["cave_rock", 0]], "plants": ["cave_mushroom", "cave_mushroom", "glowcap"], "enemies": [["bat", 4], ["burrower", 3], ["beetle", 2]], "water": "cave_earth"},
	{"id": "moss", "name": "Mossy Grotto", "floor": Color("5e7058"), "wall": Color("75826a"), "cap": Color("1a2418"), "fog": Color(0.03, 0.07, 0.05), "amb": Color(0.45, 0.65, 0.5), "amb_e": 0.35, "motes": Color(0.6, 1.0, 0.7, 0.6), "light": Color("8affb0"),
		"ores": [["ore_iron", 5], ["ore_copper", 2], ["coal_node", 2], ["crystal_node", 1]], "plants": ["glowcap", "deepmoss", "cave_mushroom", "inkcap"], "enemies": [["slime", 4], ["bat", 3], ["beetle", 2]], "water": "cave_moss"},
	{"id": "crystal", "name": "Crystal Hollows", "floor": Color("5c6080"), "wall": Color("707596"), "cap": Color("181a28"), "fog": Color(0.04, 0.04, 0.09), "amb": Color(0.5, 0.55, 0.85), "amb_e": 0.4, "motes": Color(0.7, 0.85, 1.0, 0.7), "light": Color("8fd8ff"),
		"ores": [["crystal_node", 5], ["ore_silver", 4], ["ore_iron", 2], ["gem_node", 1]], "plants": ["crystalbloom", "glowcap", "ghostbloom"], "enemies": [["golem", 3], ["bat", 3], ["slime", 2]], "water": "cave_crystal"},
	{"id": "fungal", "name": "Fungal Depths", "floor": Color("70586e"), "wall": Color("846f84"), "cap": Color("201622"), "fog": Color(0.07, 0.04, 0.08), "amb": Color(0.7, 0.5, 0.75), "amb_e": 0.38, "motes": Color(1.0, 0.75, 1.0, 0.6), "light": Color("e07fff"),
		"ores": [["ore_gold", 4], ["ore_silver", 3], ["gem_node", 1], ["coal_node", 2]], "plants": ["inkcap", "glowcap", "deepmoss", "ghostbloom"], "enemies": [["spitter", 4], ["slime", 3], ["burrower", 2]], "water": "cave_fungal"},
	{"id": "ember", "name": "Ember Rift", "floor": Color("564040"), "wall": Color("644c46"), "cap": Color("140c0a"), "fog": Color(0.09, 0.03, 0.02), "amb": Color(0.85, 0.45, 0.3), "amb_e": 0.35, "motes": Color(1.0, 0.55, 0.2, 0.8), "light": Color("ff7a30"),
		"ores": [["ore_gold", 4], ["obsidian_node", 3], ["ore_starmetal", 1], ["gem_node", 1]], "plants": ["emberlily", "inkcap"], "enemies": [["salamander", 4], ["beetle", 2], ["bat", 2]], "water": "cave_ember"},
	{"id": "ancient", "name": "Ancient Halls", "floor": Color("5e5e6a"), "wall": Color("72727e"), "cap": Color("14141a"), "fog": Color(0.03, 0.03, 0.05), "amb": Color(0.55, 0.6, 0.75), "amb_e": 0.38, "motes": Color(0.8, 0.9, 1.0, 0.6), "light": Color("bfe3ff"),
		"ores": [["ore_starmetal", 4], ["gem_node", 2], ["ore_gold", 2], ["crystal_node", 2]], "plants": ["starfern", "ghostbloom", "crystalbloom"], "enemies": [["sentinel", 4], ["golem", 2], ["salamander", 1]], "water": "cave_ancient"},
]

var floor_n := 1
var biome_i := 0
var biome := {}
var W := 48
var H := 48
var grid := PackedByteArray()
var rooms: Array = []
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var waystone_cell := Vector2i(-1, -1)
var spawns: Array = []      # resource nodes
var decor: Array = []       # props {k, p (cell-space Vector2), r, v}
var lights: Array = []      # {p: Vector2 cell-space, c: Color, e: energy, h: height}
var enemies: Array = []     # {type, p: Vector2 cell-space, elite}
var bridges: Array = []     # {a: Vector2i, b: Vector2i}
var hidden_wall := Vector2i(-1, -1)
var rng := RandomNumberGenerator.new()
var nid := 0

static func biome_index(f: int) -> int:
	if f > 30:
		return 5
	return clamp((f - 1) / 5, 0, 5)

## Grid size of a floor (deeper floors are bigger).
static func dims(f: int) -> Vector2i:
	return Vector2i(44 + min(f, 24), 44 + min(f, 24))

func generate(seed_value: int, f: int) -> void:
	floor_n = f
	biome_i = biome_index(f)
	biome = BIOMES[biome_i]
	rng.seed = Game.hash_ints(seed_value, 5150, f)
	W = dims(f).x
	H = dims(f).y
	grid.resize(W * H)
	grid.fill(T.WALL)
	_rooms()
	_tunnels()
	_smooth()
	_connectivity()
	_lakes_and_chasms()
	_hidden_chamber()
	_place_things()
	_place_enemies()

# ------------------------------------------------------------------ grid helpers

func idx(c: Vector2i) -> int:
	return c.y * W + c.x

func inb(c: Vector2i) -> bool:
	return c.x >= 1 and c.y >= 1 and c.x < W - 1 and c.y < H - 1

func get_t(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return T.WALL
	return grid[idx(c)]

func set_t(c: Vector2i, t: int) -> void:
	if inb(c):
		grid[idx(c)] = t

func walkable(c: Vector2i) -> bool:
	var t := get_t(c)
	return t == T.FLOOR or t == T.BRIDGE

func _carve_circle(c: Vector2, r: float, noise: float = 0.25) -> void:
	for y in range(int(c.y - r - 2), int(c.y + r + 3)):
		for x in range(int(c.x - r - 2), int(c.x + r + 3)):
			var d := Vector2(x, y).distance_to(c)
			var ang := atan2(y - c.y, x - c.x)
			var rr := r * (1.0 + noise * sin(ang * 3.0 + c.x) * cos(ang * 2.0 + c.y))
			if d <= rr:
				set_t(Vector2i(x, y), T.FLOOR)

# ------------------------------------------------------------------ layout

func _rooms() -> void:
	var count: int = 7 + rng.randi_range(0, 3) + min(4, floor_n / 5)
	var tries := 0
	while rooms.size() < count and tries < 400:
		tries += 1
		var r := rng.randf_range(3.0, 6.5)
		if rooms.is_empty():
			r = 4.0
		var c := Vector2(rng.randf_range(r + 3, W - r - 3), rng.randf_range(r + 3, H - r - 3))
		var ok := true
		for o in rooms:
			if c.distance_to(o["c"]) < r + o["r"] + 3.0:
				ok = false
				break
		if ok:
			rooms.append({"c": c, "r": r, "kind": "plain"})
	rooms[0]["kind"] = "start"
	var far := 0
	var fd := 0.0
	for i in rooms.size():
		var d: float = rooms[i]["c"].distance_to(rooms[0]["c"])
		if d > fd:
			fd = d
			far = i
	rooms[far]["kind"] = "exit"
	var specials: Array = []
	if biome["id"] in ["moss", "crystal", "ancient"] or rng.randf() < 0.65:
		specials.append("lake")
	if rng.randf() < 0.45:
		specials.append("camp")
	if biome["id"] == "crystal" or rng.randf() < 0.22:
		specials.append("crystal")
	if biome["id"] == "fungal":
		specials.append("grove")
	if rng.randf() < 0.5 and floor_n >= 2:
		specials.append("mine")
	if rng.randf() < 0.3:
		specials.append("treasure")
	if biome["id"] == "ember":
		specials.append("lava")
	if biome["id"] == "ancient":
		specials.append("hall")
	var plain: Array = []
	for i in rooms.size():
		if rooms[i]["kind"] == "plain":
			plain.append(i)
	for s in specials:
		if plain.is_empty():
			break
		var k: int = plain[rng.randi() % plain.size()]
		plain.erase(k)
		rooms[k]["kind"] = s
		if s in ["lake", "crystal", "hall", "lava"]:
			rooms[k]["r"] = max(float(rooms[k]["r"]), 5.5)
	for r in rooms:
		_carve_circle(r["c"], r["r"], 0.28 if r["kind"] != "hall" else 0.05)
	start_cell = Vector2i(rooms[0]["c"])
	exit_cell = Vector2i(rooms[far]["c"])

func _tunnels() -> void:
	# minimum spanning tree over room centres, plus a couple of loops
	var n := rooms.size()
	var in_tree := {0: true}
	var edges: Array = []
	while in_tree.size() < n:
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for a in in_tree:
			for b in n:
				if in_tree.has(b):
					continue
				var d: float = rooms[a]["c"].distance_to(rooms[b]["c"])
				if d < bd:
					bd = d
					best = Vector2i(a, b)
		in_tree[best.y] = true
		edges.append(best)
	for i in 2 + rng.randi() % 2:
		var a2 := rng.randi() % n
		var b2 := rng.randi() % n
		if a2 != b2:
			edges.append(Vector2i(a2, b2))
	for e in edges:
		var ra: Dictionary = rooms[e.x]
		var rb: Dictionary = rooms[e.y]
		if ra["kind"] == "mine" or rb["kind"] == "mine":
			_mine_passage(ra["c"], rb["c"])
		else:
			_wiggle_tunnel(ra["c"], rb["c"])

func _wiggle_tunnel(a: Vector2, b: Vector2) -> void:
	var p := a
	var width := rng.randf_range(1.0, 1.8)
	var steps := 0
	while p.distance_to(b) > 1.0 and steps < 400:
		steps += 1
		var dir := (b - p).normalized()
		dir = dir.rotated(rng.randf_range(-0.7, 0.7))
		p += dir * 0.8
		_carve_circle(p, width, 0.0)
		if rng.randf() < 0.04:
			width = clamp(width + rng.randf_range(-0.4, 0.5), 0.9, 2.2)

func _mine_passage(a: Vector2, b: Vector2) -> void:
	var corner := Vector2(b.x, a.y) if rng.randf() < 0.5 else Vector2(a.x, b.y)
	for seg in [[a, corner], [corner, b]]:
		var s: Vector2 = seg[0]
		var e: Vector2 = seg[1]
		var len := s.distance_to(e)
		var dir := (e - s).normalized() if len > 0.01 else Vector2.RIGHT
		var t := 0.0
		var k := 0
		while t <= len:
			var p := s + dir * t
			_carve_circle(p, 1.1, 0.0)
			if k % 3 == 0:
				decor.append({"k": "rail", "p": p, "r": atan2(dir.x, dir.y), "v": 0})
			if k % 5 == 2:
				decor.append({"k": "support", "p": p, "r": atan2(dir.x, dir.y), "v": 0})
			t += 1.0
			k += 1

func _smooth() -> void:
	var out := grid.duplicate()
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var open := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and grid[(y + dy) * W + x + dx] != T.WALL:
						open += 1
			if grid[y * W + x] == T.WALL and open >= 6:
				out[y * W + x] = T.FLOOR
			elif grid[y * W + x] != T.WALL and open <= 1:
				out[y * W + x] = T.WALL
	grid = out
	for x in W:
		grid[x] = T.WALL
		grid[(H - 1) * W + x] = T.WALL
	for y in H:
		grid[y * W] = T.WALL
		grid[y * W + W - 1] = T.WALL

func _flood(from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var q: Array = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and walkable(n):
				seen[n] = true
				q.append(n)
	return seen

func _connectivity() -> void:
	var seen := _flood(start_cell)
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if walkable(c) and not seen.has(c):
				set_t(c, T.WALL)

func _lakes_and_chasms() -> void:
	for r in rooms:
		if r["kind"] in ["lake", "lava"]:
			var c: Vector2 = r["c"]
			var rr: float = float(r["r"]) - 1.6
			var t := T.WATER if r["kind"] == "lake" else T.LAVA
			# a lake bed off to one side so you can walk around it
			var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 1.0
			for y in range(int(c.y - rr - 1), int(c.y + rr + 2)):
				for x in range(int(c.x - rr - 1), int(c.x + rr + 2)):
					var cc := Vector2i(x, y)
					if Vector2(x, y).distance_to(c + off) <= rr and get_t(cc) == T.FLOOR:
						set_t(cc, t)
			# make sure we didn't cut the cave in two: add a bridge or land crossing if needed
			var seen := _flood(start_cell)
			if not seen.has(exit_cell) or _unreached_floor(seen):
				var a := Vector2i(c - Vector2(rr + 1.5, 0))
				var b := Vector2i(c + Vector2(rr + 1.5, 0))
				var land := rng.randf() < 0.5 and t == T.WATER
				for x in range(a.x, b.x + 1):
					var cc2 := Vector2i(x, int(c.y))
					if get_t(cc2) in [T.WATER, T.LAVA]:
						set_t(cc2, T.FLOOR if land else T.BRIDGE)
				if not land:
					bridges.append({"a": a, "b": b})
	# a chasm across one tunnel on deeper floors
	if floor_n >= 3 and rng.randf() < 0.55:
		for attempt in 30:
			var cx := rng.randi_range(4, W - 5)
			var cy := rng.randi_range(4, H - 5)
			var c3 := Vector2i(cx, cy)
			if not walkable(c3):
				continue
			var horiz := walkable(c3 + Vector2i(1, 0)) and walkable(c3 + Vector2i(-1, 0)) and not walkable(c3 + Vector2i(0, 2)) and not walkable(c3 + Vector2i(0, -2))
			var vert := walkable(c3 + Vector2i(0, 1)) and walkable(c3 + Vector2i(0, -1)) and not walkable(c3 + Vector2i(2, 0)) and not walkable(c3 + Vector2i(-2, 0))
			if not (horiz or vert):
				continue
			var near_room := false
			for r2 in rooms:
				if Vector2(c3).distance_to(r2["c"]) < float(r2["r"]) + 2.0:
					near_room = true
			if near_room:
				continue
			var along := Vector2i(1, 0) if horiz else Vector2i(0, 1)
			var across := Vector2i(0, 1) if horiz else Vector2i(1, 0)
			for k in range(-3, 4):
				for j in range(-1, 2):
					var cc3: Vector2i = c3 + across * k + along * j
					if walkable(cc3):
						set_t(cc3, T.PIT)
			for j in range(-1, 2):
				set_t(c3 + along * j, T.BRIDGE)
			bridges.append({"a": c3 - along * 2, "b": c3 + along * 2})
			break

func _unreached_floor(seen: Dictionary) -> bool:
	for r in rooms:
		var c := Vector2i(r["c"])
		if walkable(c) and not seen.has(c):
			return true
	return false

func _hidden_chamber() -> void:
	if rng.randf() > 0.55:
		return
	for attempt in 60:
		var host: Dictionary = rooms[rng.randi() % rooms.size()]
		if host["kind"] in ["start", "lake", "lava"]:
			continue
		var ang := rng.randf() * TAU
		var dir := Vector2(cos(ang), sin(ang))
		var hc: Vector2 = host["c"]
		var cc: Vector2 = hc + dir * (float(host["r"]) + 6.0)
		if cc.x < 6 or cc.y < 6 or cc.x > W - 7 or cc.y > H - 7:
			continue
		var clear := true
		for y in range(int(cc.y) - 4, int(cc.y) + 5):
			for x in range(int(cc.x) - 4, int(cc.x) + 5):
				if get_t(Vector2i(x, y)) != T.WALL:
					clear = false
		if not clear:
			continue
		_carve_circle(cc, 2.8, 0.15)
		# a narrow passage toward the host room; the final wall cell becomes cracked rock
		var p := cc
		var last := Vector2i(-1, -1)
		for i in 20:
			p -= dir * 0.5
			var c := Vector2i(p.round())
			if get_t(c) == T.FLOOR and Vector2(c).distance_to(cc) > 3.0:
				hidden_wall = last
				break
			set_t(c, T.FLOOR)
			last = c
		if hidden_wall.x < 0:
			continue
		rooms.append({"c": cc, "r": 2.8, "kind": "hidden"})
		return

func _wall_neighbors(c: Vector2i) -> int:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if get_t(c + d) == T.WALL:
			n += 1
	return n

func _free_cell(near: Vector2, radius: float, need_wall: bool = false, tries: int = 40) -> Vector2i:
	for i in tries:
		var c := Vector2i(near + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius)))
		if get_t(c) != T.FLOOR:
			continue
		if need_wall and _wall_neighbors(c) == 0:
			continue
		if Vector2(c).distance_to(Vector2(start_cell)) < 3.5 or Vector2(c).distance_to(Vector2(exit_cell)) < 2.5:
			continue
		if _occupied.has(c):
			continue
		_occupied[c] = true
		return c
	return Vector2i(-1, -1)

var _occupied := {}

func _add(k: String, c: Vector2i, extra: Dictionary = {}) -> void:
	if c.x < 0:
		return
	var jitter := Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
	spawns.append({"id": "c%d" % nid, "k": k, "p": Vector2(c) + Vector2(0.5, 0.5) + jitter, "r": rng.randf() * TAU, "v": rng.randi() % 6, "x": extra})
	nid += 1

func _weighted(table: Array) -> String:
	var tot := 0
	for e in table:
		tot += int(e[1])
	if tot <= 0:
		return table[0][0]
	var r := rng.randi() % tot
	for e in table:
		r -= int(e[1])
		if r < 0:
			return e[0]
	return table[0][0]

func _place_things() -> void:
	_occupied[start_cell] = true
	_occupied[exit_cell] = true
	if floor_n % 5 == 0:
		var r0: Dictionary = rooms[rng.randi_range(1, rooms.size() - 1)]
		waystone_cell = _free_cell(r0["c"], 2.0)
		if waystone_cell.x < 0:
			waystone_cell = start_cell + Vector2i(2, 0)
	var ex := {"biome": biome_i, "depth": floor_n}
	# scattered rock and ore along the walls
	var cells_near_walls: Array = []
	for y in range(2, H - 2):
		for x in range(2, W - 2):
			var c := Vector2i(x, y)
			if get_t(c) == T.FLOOR and _wall_neighbors(c) >= 1:
				cells_near_walls.append(c)
	var n_ore: int = 12 + floor_n / 2
	var n_rock := 22
	for i in n_ore + n_rock:
		if cells_near_walls.is_empty():
			break
		var c2: Vector2i = cells_near_walls[rng.randi() % cells_near_walls.size()]
		if _occupied.has(c2) or Vector2(c2).distance_to(Vector2(start_cell)) < 3.0:
			continue
		_occupied[c2] = true
		var k := "cave_rock" if i >= n_ore else _weighted(biome["ores"])
		_add(k, c2, ex)
	# the huge vein: the kind of find that derails an expedition
	if rng.randf() < 0.28:
		var r1: Dictionary = rooms[rng.randi_range(1, rooms.size() - 1)]
		var best: String = biome["ores"][0][0]
		for i in rng.randi_range(6, 10):
			_add(best, _free_cell(r1["c"], float(r1["r"]) * 0.8, false, 20), ex)
		decor.append({"k": "vein_marker", "p": r1["c"], "r": 0.0, "v": 0})
	for r in rooms:
		var c3: Vector2 = r["c"]
		var rr: float = r["r"]
		match r["kind"]:
			"camp":
				var cc := _free_cell(c3, 1.0)
				if cc.x >= 0:
					decor.append({"k": "bedroll", "p": Vector2(cc) + Vector2(0.5, 0.5), "r": rng.randf() * TAU, "v": 0})
					decor.append({"k": "fire_ring", "p": Vector2(cc) + Vector2(1.6, 0.5), "r": 0.0, "v": 0})
					lights.append({"p": Vector2(cc) + Vector2(1.6, 0.5), "c": Color("ff9a4a"), "e": 0.6, "h": 0.8})
				_add("chest_wood" if floor_n < 12 else "chest_iron", _free_cell(c3, rr * 0.6), ex)
				_add("barrel", _free_cell(c3, rr * 0.7), ex)
				_add("bones", _free_cell(c3, rr * 0.7), {"note": rng.randi()})
			"crystal":
				for i in 5:
					var cc4 := _free_cell(c3, rr * 0.8)
					if cc4.x >= 0:
						decor.append({"k": "crystal_big", "p": Vector2(cc4) + Vector2(0.5, 0.5), "r": rng.randf() * TAU, "v": rng.randi() % 4})
						if i < 2:
							lights.append({"p": Vector2(cc4) + Vector2(0.5, 0.5), "c": Color("8fd8ff"), "e": 1.1, "h": 2.0})
				for i in 3:
					_add("crystal_node", _free_cell(c3, rr * 0.8, true), ex)
				_add("gem_node", _free_cell(c3, rr * 0.8, true), ex)
			"grove":
				for i in 4:
					var cc5 := _free_cell(c3, rr * 0.8)
					if cc5.x >= 0:
						decor.append({"k": "giant_mushroom", "p": Vector2(cc5) + Vector2(0.5, 0.5), "r": rng.randf() * TAU, "v": rng.randi() % 3})
						if i < 2:
							lights.append({"p": Vector2(cc5) + Vector2(0.5, 0.5), "c": Color("e07fff"), "e": 0.8, "h": 3.0})
			"mine":
				_add("minecart", _free_cell(c3, rr * 0.5), ex)
				_add("crate", _free_cell(c3, rr * 0.7), ex)
				_add("barrel", _free_cell(c3, rr * 0.7), ex)
				var cl := _free_cell(c3, rr * 0.6)
				if cl.x >= 0:
					decor.append({"k": "lantern_post", "p": Vector2(cl) + Vector2(0.5, 0.5), "r": rng.randf() * TAU, "v": 0})
					lights.append({"p": Vector2(cl) + Vector2(0.5, 0.5), "c": Color("ffc860"), "e": 0.9, "h": 1.8})
			"treasure":
				_add("chest_iron" if floor_n >= 6 else "chest_wood", _free_cell(c3, rr * 0.4), ex)
			"hidden":
				_add("chest_hidden", Vector2i(c3), ex)
				_occupied[Vector2i(c3)] = true
				lights.append({"p": c3, "c": Color("ffd36b"), "e": 0.8, "h": 1.5})
			"hall":
				for i in 6:
					var a := TAU * i / 6.0
					var pc := c3 + Vector2(cos(a), sin(a)) * (rr - 1.8)
					if walkable(Vector2i(pc)):
						decor.append({"k": "pillar", "p": pc, "r": 0.0, "v": 0})
						_occupied[Vector2i(pc)] = true
				decor.append({"k": "statue", "p": c3, "r": rng.randf() * TAU, "v": 0})
				_occupied[Vector2i(c3)] = true
				lights.append({"p": c3, "c": Color("ffd36b"), "e": 1.0, "h": 3.0})
		# plants & glow
		for i in rng.randi_range(0, 2):
			var cp := _free_cell(c3, rr * 0.8)
			if cp.x >= 0:
				var plant: String = biome["plants"][rng.randi() % biome["plants"].size()]
				if plant == "starfern" and rng.randf() < 0.7:
					plant = "ghostbloom"
				_add("cave_plant", cp, {"item": plant, "depth": floor_n})
		if biome["id"] in ["moss", "fungal"] or rng.randf() < 0.35:
			var cg := _free_cell(c3, rr * 0.9)
			if cg.x >= 0:
				decor.append({"k": "glow_shrooms", "p": Vector2(cg) + Vector2(0.5, 0.5), "r": rng.randf() * TAU, "v": biome_i % 4})
	# stalagmites and moss for texture
	for i in 26:
		var cs := _free_cell(Vector2(W / 2.0, H / 2.0), W / 2.0, true, 6)
		if cs.x >= 0:
			var k2 := "stalagmite"
			if biome["id"] == "moss" and rng.randf() < 0.5:
				k2 = "moss_patch"
			elif biome["id"] == "ember" and rng.randf() < 0.5:
				k2 = "lava_rock"
			decor.append({"k": k2, "p": Vector2(cs) + Vector2(0.5, 0.5), "r": rng.randf() * TAU, "v": rng.randi() % 6})
	# a lone chest, the odd barrel, remains with a story
	_add("chest_wood" if rng.randf() < 0.7 or floor_n < 8 else "chest_iron", _free_cell(Vector2(W / 2.0, H / 2.0), W / 2.5), ex)
	if rng.randf() < 0.12 and floor_n >= 8:
		_add("chest_gold", _free_cell(Vector2(W / 2.0, H / 2.0), W / 2.5), ex)
	if rng.randf() < 0.6:
		_add("bones", _free_cell(Vector2(W / 2.0, H / 2.0), W / 2.5), {"note": rng.randi()})
	for i in rng.randi_range(1, 3):
		_add("barrel", _free_cell(Vector2(W / 2.0, H / 2.0), W / 2.5, true), ex)
	# biome light sources so the floor isn't pitch black away from your lantern
	for i in 6:
		var cl2 := _free_cell(Vector2(W / 2.0, H / 2.0), W / 2.2, true, 8)
		if cl2.x >= 0:
			decor.append({"k": "glow_shrooms" if biome["id"] != "crystal" else "crystal_cluster", "p": Vector2(cl2) + Vector2(0.5, 0.5), "r": 0.0, "v": i})
			lights.append({"p": Vector2(cl2) + Vector2(0.5, 0.5), "c": biome["light"], "e": 0.7, "h": 1.2})

## Fixed spot for a quest keepsake (deterministic per floor & quest id).
func keepsake_cell(qid: int) -> Vector2i:
	var r := RandomNumberGenerator.new()
	r.seed = Game.hash_ints(floor_n, qid, 77)
	for i in 80:
		var room: Dictionary = rooms[r.randi() % rooms.size()]
		if room["kind"] == "start":
			continue
		var c := Vector2i(room["c"] + Vector2(r.randf_range(-2, 2), r.randf_range(-2, 2)))
		if get_t(c) == T.FLOOR:
			return c
	return exit_cell + Vector2i(1, 1)

func _place_enemies() -> void:
	var count: int = min(24, 5 + int(floor_n * 0.7))
	var tbl: Array = biome["enemies"]
	for i in count:
		var room: Dictionary = rooms[rng.randi_range(1, rooms.size() - 1)]
		if room["kind"] == "hidden":
			continue
		var c := _free_cell(room["c"], float(room["r"]) * 0.8, false, 10)
		if c.x < 0:
			continue
		_occupied.erase(c)
		var t := _weighted(tbl)
		enemies.append({"type": t, "p": Vector2(c) + Vector2(0.5, 0.5), "elite": floor_n >= 5 and rng.randf() < 0.07})
	if floor_n % 10 == 0:
		var ex_room: Dictionary = rooms[0]
		for r in rooms:
			if r["kind"] == "exit":
				ex_room = r
		enemies.append({"type": "golem" if floor_n < 25 else "sentinel", "p": ex_room["c"] + Vector2(1.5, 0), "elite": true, "guardian": true})
