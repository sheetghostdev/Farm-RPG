class_name OverworldGen
extends RefCounted
## Generates the finite overworld from a seed: terrain, river, lakes, farm and town
## sites, roads, bridges, named points of interest and vegetation placements.
## Pure data; Overworld turns it into nodes. Deterministic for a given seed.

const S := 320                 # map size in meters (1 m grid)
const N := S + 1               # height samples per side
const EXPLORE_CELL := 4
const EX_W := S / EXPLORE_CELL

enum B { MEADOW, FOREST, PINE, BIRCH, MARSH, ROCKY, FARM, TOWN, ROAD, WATER, SAND }

var seed_value := 0
var rng := RandomNumberGenerator.new()
var heights := PackedFloat32Array()
var biome := PackedByteArray()        # per cell (S*S)
var road := PackedByteArray()         # per cell 0..255 road strength
var water_idx := PackedByteArray()    # per cell: 0 none, 1 river, 2+ pond index
var water_lvl := PackedFloat32Array() # per cell water surface height
var bridge_cells := {}                # Vector2i -> true where a walkable bridge deck is
var river: Array = []                 # [{p: Vector2, w: float, lvl: float}]
var ponds: Array = []                 # [{c, r, lvl, kind, name, id, noise_off}]
var farm_rect := Rect2()
var farm_h := 0.0
var town_rect := Rect2()
var town_h := 0.0
var town_center := Vector2()
var cave_pos := Vector2()
var cave_h := 0.0
var roads: Array = []                 # Array of PackedVector2Array
var bridges: Array = []               # [{p: Vector2, dir: Vector2, len: float, lvl: float, broken: bool, id}]
var pois: Array = []                  # [{id, type, pos: Vector2, name, r}]
var spawns: Array = []                # resource node placements
var decor: Array = []                 # decorative instance placements [{k, p: Vector3, r, s, v}]
var forage_spots: Array = []          # [{p: Vector2, b: biome, poi: id}]
var names := {}
var nz_h := FastNoiseLite.new()
var nz_d := FastNoiseLite.new()
var nz_hill := FastNoiseLite.new()
var nz_moist := FastNoiseLite.new()
var nz_forest := FastNoiseLite.new()
var nz_meander := FastNoiseLite.new()

func generate(seed_in: int) -> void:
	seed_value = seed_in
	rng.seed = Game.hash_ints(seed_in, 1001)
	_setup_noise()
	_base_heights()
	_choose_sites()
	_make_river()
	_make_ponds()
	_flatten_sites()
	_carve_water()
	_make_roads()
	_assign_biomes()
	_place_pois()
	_place_vegetation()
	_place_farm_debris()
	_place_forage_spots()
	_make_names()

# ------------------------------------------------------------------ noise & heights

func _setup_noise() -> void:
	var i := 0
	for nz in [nz_h, nz_d, nz_hill, nz_moist, nz_forest, nz_meander]:
		nz.seed = Game.hash_ints(seed_value, 77 + i)
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.fractal_type = FastNoiseLite.FRACTAL_FBM
		i += 1
	nz_h.frequency = 0.0075
	nz_h.fractal_octaves = 4
	nz_d.frequency = 0.03
	nz_d.fractal_octaves = 2
	nz_hill.frequency = 0.012
	nz_hill.fractal_octaves = 3
	nz_moist.frequency = 0.009
	nz_moist.fractal_octaves = 3
	nz_forest.frequency = 0.022
	nz_forest.fractal_octaves = 3
	nz_meander.frequency = 0.02
	nz_meander.fractal_octaves = 2

func _base_heights() -> void:
	heights.resize(N * N)
	for z in N:
		for x in N:
			heights[z * N + x] = _raw_h(float(x), float(z))

func _raw_h(x: float, z: float) -> float:
	var h := 4.0 + 5.0 * nz_h.get_noise_2d(x, z) + 1.2 * nz_d.get_noise_2d(x, z)
	var hill := nz_hill.get_noise_2d(x, z)
	if hill > 0.0:
		h += hill * hill * 22.0
	var e: float = min(min(x, z), min(S - x, S - z))
	if e < 38.0:
		var t := 1.0 - e / 38.0
		h += t * t * 26.0 + t * 7.0 * abs(nz_d.get_noise_2d(x * 2.0, z * 2.0))
	return h

func h_at(x: float, z: float) -> float:
	x = clamp(x, 0.0, S - 0.001)
	z = clamp(z, 0.0, S - 0.001)
	var ix := int(x)
	var iz := int(z)
	var fx := x - ix
	var fz := z - iz
	var a := heights[iz * N + ix]
	var b := heights[iz * N + ix + 1]
	var c := heights[(iz + 1) * N + ix]
	var d := heights[(iz + 1) * N + ix + 1]
	return lerp(lerp(a, b, fx), lerp(c, d, fx), fz)

func _hv(x: int, z: int) -> float:
	return heights[clamp(z, 0, N - 1) * N + clamp(x, 0, N - 1)]

func _set_hv(x: int, z: int, v: float) -> void:
	if x < 0 or z < 0 or x >= N or z >= N:
		return
	heights[z * N + x] = v

func cell(x: float, z: float) -> int:
	var ix: int = clamp(int(x), 0, S - 1)
	var iz: int = clamp(int(z), 0, S - 1)
	return iz * S + ix

# ------------------------------------------------------------------ sites

func _choose_sites() -> void:
	var fc := Vector2(rng.randf_range(135, 185), rng.randf_range(195, 228))
	farm_rect = Rect2(fc - Vector2(28, 22), Vector2(56, 44))
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	town_center = fc + Vector2(side * rng.randf_range(100, 118), rng.randf_range(-30, 10))
	town_center.x = clamp(town_center.x, 80.0, S - 80.0)
	town_center.y = clamp(town_center.y, 80.0, S - 70.0)
	town_rect = Rect2(town_center - Vector2(42, 42), Vector2(84, 84))
	var cx := clamp(fc.x + rng.randf_range(-60, 60) - side * 30.0, 70.0, S - 70.0)
	cave_pos = Vector2(cx, rng.randf_range(58, 78))

func _flatten_rect(r: Rect2, target: float, margin: float) -> void:
	var x0 := int(r.position.x - margin)
	var z0 := int(r.position.y - margin)
	var x1 := int(r.end.x + margin)
	var z1 := int(r.end.y + margin)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or z < 0 or x >= N or z >= N:
				continue
			var dx: float = max(max(r.position.x - x, x - r.end.x), 0.0)
			var dz: float = max(max(r.position.y - z, z - r.end.y), 0.0)
			var d := sqrt(dx * dx + dz * dz)
			var t: float = clamp(d / margin, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			var cur := _hv(x, z)
			var micro := 0.12 * nz_d.get_noise_2d(x * 3.0, z * 3.0)
			_set_hv(x, z, lerp(target + micro, cur, t))

func _flatten_circle(c: Vector2, r: float, target: float, margin: float) -> void:
	for z in range(int(c.y - r - margin), int(c.y + r + margin) + 1):
		for x in range(int(c.x - r - margin), int(c.x + r + margin) + 1):
			if x < 0 or z < 0 or x >= N or z >= N:
				continue
			var d: float = max(0.0, Vector2(x, z).distance_to(c) - r)
			var t: float = clamp(d / margin, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			_set_hv(x, z, lerp(target, _hv(x, z), t))

func _flatten_sites() -> void:
	farm_h = max(3.0, h_at(farm_rect.get_center().x, farm_rect.get_center().y))
	farm_h = min(farm_h, 8.0)
	_flatten_rect(farm_rect, farm_h, 14.0)
	town_h = clamp(h_at(town_center.x, town_center.y), 3.0, 8.5)
	_flatten_rect(town_rect, town_h, 14.0)
	cave_h = clamp(h_at(cave_pos.x, cave_pos.y + 6.0), 4.0, 14.0)
	# raise a hill behind the cave mouth, then keep the approach flat
	for z in range(int(cave_pos.y - 44), int(cave_pos.y + 8)):
		for x in range(int(cave_pos.x - 26), int(cave_pos.x + 26)):
			var d := Vector2(x, z).distance_to(cave_pos + Vector2(0, -19))
			if d < 25.0:
				var t := 1.0 - d / 25.0
				_set_hv(x, z, max(_hv(x, z), cave_h + t * t * 18.0))
	_flatten_circle(cave_pos + Vector2(0, 7), 7.0, cave_h, 7.0)

# ------------------------------------------------------------------ water

func _river_conflicts(pts: Array) -> int:
	var bad := 0
	for p in pts:
		if farm_rect.grow(18).has_point(p) or town_rect.grow(18).has_point(p):
			bad += 1
		if p.distance_to(cave_pos) < 30.0:
			bad += 1
	return bad

func _make_river() -> void:
	var best: Array = []
	var best_bad := 1 << 30
	for attempt in 14:
		var r0 := rng.randf_range(45, S - 45)
		var lake := Vector2(rng.randf_range(55, S - 55), rng.randf_range(250, 278))
		if lake.distance_to(farm_rect.get_center()) < 75.0 or lake.distance_to(town_center) < 65.0:
			continue
		var pts: Array = []
		var z := 6.0
		var off := rng.randf_range(0, 1000)
		while z < lake.y - 18.0:
			var t := z / (lake.y - 18.0)
			var bx: float = lerp(r0, lake.x, t * t * (3.0 - 2.0 * t))
			var mx := bx + nz_meander.get_noise_2d(off, z) * 32.0
			pts.append(Vector2(clamp(mx, 30.0, S - 30.0), z))
			z += 2.0
		var bad := _river_conflicts(pts)
		if bad < best_bad:
			best_bad = bad
			best = pts
			ponds = [{"c": lake, "r": rng.randf_range(22.0, 28.0), "kind": "lake", "id": "lake"}]
		if bad == 0:
			break
	# widths & levels: levels never rise downstream
	var run_min := 1e9
	river.clear()
	for i in best.size():
		var p: Vector2 = best[i]
		var local := h_at(p.x, p.y)
		for o in [-4.0, 4.0]:
			local = min(local, h_at(p.x + o, p.y))
		run_min = min(run_min, local)
		var w := 6.0 + 2.5 * (0.5 + 0.5 * nz_meander.get_noise_2d(p.x * 3.0, p.y))
		river.append({"p": p, "w": w, "lvl": run_min - 0.55})
	# connect the end into the lake
	var lk: Dictionary = ponds[0]
	var last: Vector2 = river[river.size() - 1]["p"]
	var lvl_end: float = river[river.size() - 1]["lvl"]
	var steps := int(last.distance_to(lk["c"]) / 2.0)
	for i in range(1, steps):
		var p := last.lerp(lk["c"], float(i) / steps)
		river.append({"p": p, "w": 7.0, "lvl": lvl_end})
	lk["lvl"] = lvl_end

func _make_ponds() -> void:
	# Farm pond in a farm corner
	var fc := farm_rect.position + Vector2(farm_rect.size.x * (0.12 if rng.randf() < 0.5 else 0.88), farm_rect.size.y * 0.8)
	ponds.append({"c": fc, "r": 4.6, "kind": "pond", "id": "farm_pond", "lvl": farm_h - 0.35})
	# Hidden pond: tucked into the high ground near the boundary, ringed by a ridge
	var hp := Vector2.ZERO
	var best_h := -1e9
	for i in 50:
		var c := Vector2(rng.randf_range(48, S - 48), rng.randf_range(48, S - 48))
		var e: float = min(min(c.x, c.y), min(S - c.x, S - c.y))
		if e > 70.0 or e < 44.0:
			continue
		if c.distance_to(cave_pos) < 40.0 or c.distance_to(town_center) < 60.0 or c.distance_to(farm_rect.get_center()) < 60.0:
			continue
		if _near_river(c, 30.0):
			continue
		var hh := h_at(c.x, c.y) + rng.randf() * 4.0
		if hh > best_h:
			best_h = hh
			hp = c
	if hp != Vector2.ZERO:
		var lvl := h_at(hp.x, hp.y) - 0.4
		ponds.append({"c": hp, "r": 5.5, "kind": "hidden", "id": "hidden_pond", "lvl": lvl, "ridge": true})
	# Hot spring in the rocky highlands
	for i in 40:
		var c2 := Vector2(rng.randf_range(42, S - 42), rng.randf_range(42, S - 42))
		var e2: float = min(min(c2.x, c2.y), min(S - c2.x, S - c2.y))
		if e2 > 60.0 or e2 < 40.0 or c2.distance_to(hp) < 70.0 or c2.distance_to(cave_pos) < 40.0 or _near_river(c2, 25.0):
			continue
		ponds.append({"c": c2, "r": 3.0, "kind": "hot", "id": "hot_spring", "lvl": h_at(c2.x, c2.y) - 0.3})
		break
	# A couple of forest ponds
	var made := 0
	for i in 60:
		if made >= 2:
			break
		var c3 := Vector2(rng.randf_range(50, S - 50), rng.randf_range(50, S - 50))
		if farm_rect.grow(25).has_point(c3) or town_rect.grow(25).has_point(c3) or _near_river(c3, 22.0) or c3.distance_to(cave_pos) < 35.0:
			continue
		var ok := true
		for p in ponds:
			if c3.distance_to(p["c"]) < 50.0:
				ok = false
		if not ok:
			continue
		ponds.append({"c": c3, "r": rng.randf_range(4.0, 6.5), "kind": "pond", "id": "pond_%d" % made, "lvl": h_at(c3.x, c3.y) - 0.45})
		made += 1
	for i in ponds.size():
		ponds[i]["noise_off"] = rng.randf_range(0, 100)

func _near_river(p: Vector2, d: float) -> bool:
	for r in river:
		if p.distance_to(r["p"]) < d:
			return true
	return false

func pond_radius(pd: Dictionary, ang: float) -> float:
	return float(pd["r"]) * (1.0 + 0.22 * nz_meander.get_noise_2d(cos(ang) * 30.0 + pd["noise_off"], sin(ang) * 30.0))

func _carve_water() -> void:
	water_idx.resize(S * S)
	water_lvl.resize(S * S)
	water_idx.fill(0)
	# river
	for i in river.size():
		var r: Dictionary = river[i]
		var p: Vector2 = r["p"]
		var w: float = r["w"]
		var lvl: float = r["lvl"]
		var reach := int(w / 2.0 + 6.0)
		for z in range(int(p.y) - reach, int(p.y) + reach + 1):
			for x in range(int(p.x) - reach, int(p.x) + reach + 1):
				if x < 0 or z < 0 or x >= N or z >= N:
					continue
				var d := Vector2(x, z).distance_to(p)
				var bed: float
				if d < w / 2.0:
					var t := d / (w / 2.0)
					bed = lvl - 1.7 * (1.0 - t * t) - 0.25
				elif d < w / 2.0 + 5.0:
					var t2 := (d - w / 2.0) / 5.0
					bed = lerp(lvl - 0.25, max(_hv(x, z), lvl + 0.5), t2 * t2 * (3.0 - 2.0 * t2))
				else:
					continue
				if bed < _hv(x, z):
					_set_hv(x, z, bed)
				if d < w / 2.0 + 0.8 and x < S and z < S:
					water_idx[z * S + x] = 1
					water_lvl[z * S + x] = lvl
	# ponds & lake
	for pi in ponds.size():
		var pd: Dictionary = ponds[pi]
		var c: Vector2 = pd["c"]
		var lvl: float = pd["lvl"]
		var rmax := float(pd["r"]) * 1.35 + 6.0
		for z in range(int(c.y - rmax), int(c.y + rmax) + 1):
			for x in range(int(c.x - rmax), int(c.x + rmax) + 1):
				if x < 0 or z < 0 or x >= N or z >= N:
					continue
				var v := Vector2(x, z) - c
				var rr := pond_radius(pd, atan2(v.y, v.x))
				var d := v.length()
				var bed: float
				if d < rr:
					var t := d / rr
					bed = lvl - (2.2 if pd["kind"] == "lake" else 1.4) * (1.0 - t * t) - 0.3
				elif d < rr + 4.0:
					var t2 := (d - rr) / 4.0
					var rim := lvl + 0.45
					if pd.get("ridge", false):
						rim = lvl + 0.4
					bed = lerp(lvl - 0.3, max(_hv(x, z), rim), t2 * t2 * (3.0 - 2.0 * t2))
				else:
					if pd.get("ridge", false) and d < rr + 11.0:
						var t3 := (d - rr - 4.0) / 7.0
						var ang := atan2(v.y, v.x)
						var gap: bool = abs(wrapf(ang - float(pd["noise_off"]), -PI, PI)) < 0.32
						if not gap:
							var ridge_h := lvl + 4.5 * sin(t3 * PI)
							if ridge_h > _hv(x, z):
								_set_hv(x, z, ridge_h)
					continue
				if d < rr:
					_set_hv(x, z, min(bed, _hv(x, z)))
				elif x < S and z < S and water_idx[z * S + x] == 1:
					_set_hv(x, z, min(bed, _hv(x, z)))
				else:
					_set_hv(x, z, bed)
				if d < rr + 0.6 and x < S and z < S:
					water_idx[z * S + x] = pi + 2
					water_lvl[z * S + x] = lvl

func water_at(x: float, z: float) -> Dictionary:
	if x < 0 or z < 0 or x >= S or z >= S:
		return {}
	var c := cell(x, z)
	var wi := int(water_idx[c])
	if wi == 0:
		return {}
	var lvl := water_lvl[c]
	if h_at(x, z) > lvl - 0.05:
		return {}
	if wi == 1:
		return {"kind": "river", "lvl": lvl, "name": names.get("river", "the river"), "id": "river"}
	var pd: Dictionary = ponds[wi - 2]
	return {"kind": pd["kind"], "lvl": lvl, "name": pd.get("name", "the pond"), "id": pd["id"]}

## Deep water (or anything else that should stop walking).
func is_deep(x: float, z: float, y: float) -> bool:
	var w := water_at(x, z)
	if w.is_empty():
		return false
	if bridge_cells.has(Vector2i(int(x), int(z))) and y > float(w["lvl"]) - 0.3:
		return false
	return float(w["lvl"]) - h_at(x, z) > 0.75

# ------------------------------------------------------------------ roads & bridges

func _road_line(a: Vector2, b: Vector2, wiggle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := int(a.distance_to(b) / 2.0) + 1
	var off := rng.randf_range(0, 500)
	var nrm := (b - a).normalized().orthogonal()
	for i in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var env := sin(t * PI)
		p += nrm * nz_meander.get_noise_2d(off + t * 40.0, 3.0) * wiggle * env
		pts.append(p)
	return pts

func _make_roads() -> void:
	var farm_gate := Vector2(farm_rect.get_center().x, farm_rect.position.y)
	var farm_side_gate := Vector2(farm_rect.position.x if town_center.x < farm_rect.get_center().x else farm_rect.end.x, farm_rect.get_center().y)
	roads.append(_road_line(farm_side_gate, town_center, 14.0))
	roads.append(_road_line(farm_gate, cave_pos + Vector2(0, 8), 18.0))
	roads.append(_road_line(town_center, cave_pos + Vector2(0, 9), 16.0))
	var lake: Dictionary = ponds[0]
	var dock_dir: Vector2 = (farm_rect.get_center() - lake["c"]).normalized()
	var dock_p: Vector2 = lake["c"] + dock_dir * (pond_radius(lake, atan2(dock_dir.y, dock_dir.x)) + 5.0)
	roads.append(_road_line(Vector2(farm_rect.get_center().x, farm_rect.end.y), dock_p, 10.0))
	pois.append({"id": "dock", "type": "dock", "pos": dock_p - dock_dir * 4.0, "dir": -dock_dir, "r": 9.0})
	# flatten & mark roads
	road.resize(S * S)
	road.fill(0)
	for line in roads:
		for i in line.size():
			var p: Vector2 = line[i]
			var target := h_at(p.x, p.y)
			# average along the road to smooth bumps
			var acc := 0.0
			var cnt := 0
			for j in range(max(0, i - 3), min(line.size(), i + 4)):
				acc += h_at(line[j].x, line[j].y)
				cnt += 1
			target = acc / cnt
			for z in range(int(p.y) - 3, int(p.y) + 4):
				for x in range(int(p.x) - 3, int(p.x) + 4):
					if x < 0 or z < 0 or x >= S or z >= S:
						continue
					var d := Vector2(x, z).distance_to(p)
					if d > 3.2:
						continue
					var strength := int(clamp((1.0 - d / 3.2) * 400.0, 0.0, 255.0))
					if strength > road[z * S + x]:
						road[z * S + x] = strength
					if water_idx[z * S + x] == 0 and d < 2.4:
						var cur := _hv(x, z)
						_set_hv(x, z, lerp(cur, target, 0.55))
	# the town plaza and its ring street
	for z in range(int(town_center.y) - 17, int(town_center.y) + 18):
		for x in range(int(town_center.x) - 17, int(town_center.x) + 18):
			if x < 0 or z < 0 or x >= S or z >= S:
				continue
			var dd := Vector2(x, z).distance_to(town_center)
			if dd < 15.5:
				road[z * S + x] = max(road[z * S + x], 255 if dd < 13.5 else int((15.5 - dd) * 127.0))
	# bridges where roads meet the river
	for line in roads:
		var in_water := false
		var start := Vector2.ZERO
		for i in line.size():
			var p: Vector2 = line[i]
			var w := water_idx[cell(p.x, p.y)] == 1
			if w and not in_water:
				in_water = true
				start = line[max(0, i - 1)]
			elif not w and in_water:
				in_water = false
				_add_bridge(start, line[i], false)
	# the broken Old Bridge, somewhere else on the river
	var cand: Array = []
	for i in range(10, river.size() - 30, 3):
		var p2: Vector2 = river[i]["p"]
		var ok := true
		for b in bridges:
			if p2.distance_to(b["p"]) < 70.0:
				ok = false
		if ok and p2.distance_to(cave_pos) > 30.0:
			cand.append(i)
	if not cand.is_empty():
		var ri: int = cand[rng.randi() % cand.size()]
		var rp: Vector2 = river[ri]["p"]
		var dir: Vector2 = (river[min(ri + 2, river.size() - 1)]["p"] - river[max(ri - 2, 0)]["p"]).normalized().orthogonal()
		var half: float = river[ri]["w"] / 2.0 + 3.5
		_add_bridge(rp - dir * half, rp + dir * half, true)
		var bp: Vector2 = rp
		# trails toward the bridge from both banks
		var a := rp - dir * (half + 1.0)
		var b2 := rp + dir * (half + 1.0)
		for end in [[a, -dir], [b2, dir]]:
			var e: Vector2 = end[0] + end[1] * 18.0
			var line2 := _road_line(end[0], e, 4.0)
			roads.append(line2)
			for p3 in line2:
				for z in range(int(p3.y) - 2, int(p3.y) + 3):
					for x in range(int(p3.x) - 2, int(p3.x) + 3):
						if x >= 0 and z >= 0 and x < S and z < S and water_idx[z * S + x] == 0:
							road[z * S + x] = max(road[z * S + x], 150)
		pois.append({"id": "old_bridge", "type": "old_bridge", "pos": bp, "r": 12.0})
	# a shallow ford so the far bank is always reachable on foot
	var ford_i := -1
	var best := -1.0
	for i in range(8, river.size() - 25, 4):
		var p4: Vector2 = river[i]["p"]
		var dmin := 1e9
		for b in bridges:
			dmin = min(dmin, p4.distance_to(b["p"]))
		if dmin > best and p4.distance_to(cave_pos) > 25.0:
			best = dmin
			ford_i = i
	if ford_i >= 0 and best > 60.0:
		var fp: Vector2 = river[ford_i]["p"]
		var lvl: float = river[ford_i]["lvl"]
		for z in range(int(fp.y) - 5, int(fp.y) + 6):
			for x in range(int(fp.x) - 6, int(fp.x) + 7):
				if x < 0 or z < 0 or x >= N or z >= N:
					continue
				if Vector2(x, z).distance_to(fp) < 4.5:
					_set_hv(x, z, max(_hv(x, z), lvl - 0.45))
		pois.append({"id": "ford", "type": "ford", "pos": fp, "r": 8.0})

func _add_bridge(a: Vector2, b: Vector2, broken: bool) -> void:
	var c := (a + b) / 2.0
	var dir := (b - a).normalized()
	var l := a.distance_to(b) + 3.0
	var lvl := 0.0
	var wi := water_idx[cell(c.x, c.y)]
	lvl = water_lvl[cell(c.x, c.y)] if wi != 0 else h_at(c.x, c.y)
	var deck := max(max(h_at(a.x - dir.x * 2.0, a.y - dir.y * 2.0), h_at(b.x + dir.x * 2.0, b.y + dir.y * 2.0)), lvl + 0.6)
	for end in [a - dir * 1.5, b + dir * 1.5]:
		if water_idx[cell(end.x, end.y)] == 0:
			_flatten_circle(end, 1.6, deck, 2.5)
	var br := {"p": c, "dir": dir, "len": l, "lvl": lvl, "deck": deck, "broken": broken, "id": "bridge_%d" % bridges.size()}
	bridges.append(br)
	if not broken:
		mark_bridge(br)

func mark_bridge(br: Dictionary) -> void:
	var c: Vector2 = br["p"]
	var dir: Vector2 = br["dir"]
	var l: float = br["len"]
	var nrm := dir.orthogonal()
	var steps := int(l * 2.0)
	for i in steps + 1:
		var t := -l / 2.0 + l * float(i) / steps
		for k in range(-3, 4):
			var p := c + dir * t + nrm * (k * 0.45)
			bridge_cells[Vector2i(int(p.x), int(p.y))] = true

# ------------------------------------------------------------------ biomes

func _assign_biomes() -> void:
	biome.resize(S * S)
	for z in S:
		for x in S:
			var i := z * S + x
			var b := B.MEADOW
			var h := heights[z * N + x]
			var moist := nz_moist.get_noise_2d(x, z)
			var fo := nz_forest.get_noise_2d(x, z)
			var e: float = min(min(x, z), min(S - x, S - z))
			var slope := _slope(x, z)
			if water_idx[i] != 0 and h < water_lvl[i]:
				b = B.WATER
			elif farm_rect.has_point(Vector2(x, z)):
				b = B.FARM
			elif town_rect.has_point(Vector2(x, z)):
				b = B.TOWN
			elif road[i] > 120:
				b = B.ROAD
			elif e < 26.0 or slope > 1.0 or h > 17.0:
				b = B.ROCKY
			elif _near_water_cell(x, z, 3):
				b = B.SAND
			elif moist > 0.25 and h < 6.0 and _near_water_cell(x, z, 9):
				b = B.MARSH
			elif h > 11.0:
				b = B.PINE
			elif fo > 0.08:
				b = B.BIRCH if moist < -0.15 else B.FOREST
			biome[i] = b

func _slope(x: int, z: int) -> float:
	return max(abs(_hv(x + 1, z) - _hv(x - 1, z)), abs(_hv(x, z + 1) - _hv(x, z - 1))) * 0.5

func _near_water_cell(x: int, z: int, r: int) -> bool:
	for dz in range(-r, r + 1, max(1, r / 2)):
		for dx in range(-r, r + 1, max(1, r / 2)):
			var xx := x + dx
			var zz := z + dz
			if xx >= 0 and zz >= 0 and xx < S and zz < S and water_idx[zz * S + xx] != 0:
				return true
	return false

func biome_at(x: float, z: float) -> int:
	if x < 0 or z < 0 or x >= S or z >= S:
		return B.ROCKY
	return biome[cell(x, z)]

func color_at(x: int, z: int) -> Color:
	var cx: int = clamp(x, 0, S - 1)
	var cz: int = clamp(z, 0, S - 1)
	var i := cz * S + cx
	var b := biome[i]
	var moist := nz_moist.get_noise_2d(x, z) * 0.5 + 0.5
	var grass := Color("4f9a3a").lerp(Color("78a83e"), 1.0 - moist).lerp(Color("3f8a40"), 0.3 * nz_forest.get_noise_2d(x * 2.0, z * 2.0) + 0.3)
	var c := grass
	var grassy := 1.0
	match b:
		B.FOREST:
			c = Color("3f6a2e").lerp(Color("5a6a30"), 0.3)
		B.BIRCH:
			c = Color("6a9a3e")
		B.PINE:
			c = Color("4a6a3a").lerp(Color("6a6a4a"), 0.3)
		B.MARSH:
			c = Color("4a7a46")
		B.ROCKY:
			c = Color("8a8a7e").lerp(Color("7a8a5e"), clamp(1.0 - _slope(cx, cz), 0.0, 0.5))
			grassy = 0.2
		B.SAND:
			c = Color("b8a476").lerp(grass, 0.3)
			grassy = 0.3
		B.WATER:
			c = Color("8a7a5a")
			grassy = 0.0
		B.FARM:
			c = Color("5f9e42")
		B.TOWN:
			c = Color("64a044")
	var rd := road[i] / 255.0
	if b == B.TOWN and Vector2(cx, cz).distance_to(town_center) < 9.6:
		return Color(0.62, 0.6, 0.55, 0.0)
	if rd > 0.0:
		c = c.lerp(Color("9a7a50"), clamp(rd * 1.4, 0.0, 1.0))
		grassy *= 1.0 - clamp(rd * 1.4, 0.0, 1.0)
	var h := heights[cz * N + cx]
	if b != B.WATER and h > 18.0:
		c = c.lerp(Color("9a948a"), clamp((h - 18.0) / 10.0, 0.0, 0.8))
		grassy *= 0.5
	c.a = grassy
	return c

# ------------------------------------------------------------------ points of interest

func _free_spot(min_d: float, pred: Callable, tries: int = 80) -> Vector2:
	for i in tries:
		var p := Vector2(rng.randf_range(45, S - 45), rng.randf_range(45, S - 45))
		if farm_rect.grow(14).has_point(p) or town_rect.grow(14).has_point(p):
			continue
		if p.distance_to(cave_pos) < 24.0:
			continue
		if water_idx[cell(p.x, p.y)] != 0 or _near_water_cell(int(p.x), int(p.y), 4):
			continue
		if road[cell(p.x, p.y)] > 30:
			continue
		var ok := true
		for q in pois:
			if p.distance_to(q["pos"]) < min_d:
				ok = false
				break
		if not ok:
			continue
		if not pred.call(p):
			continue
		return p
	return Vector2(-1, -1)

func _poi(type: String, pred: Callable, r: float = 10.0, min_d: float = 34.0) -> Dictionary:
	var p := _free_spot(min_d, pred)
	if p.x < 0:
		p = _free_spot(min_d * 0.6, func(_q): return true)
	if p.x < 0:
		return {}
	var d := {"id": "%s_%d" % [type, pois.size()], "type": type, "pos": p, "r": r}
	pois.append(d)
	return d

func _place_pois() -> void:
	var forest := func(p): var b := biome_at(p.x, p.y); return b == B.FOREST or b == B.BIRCH
	var meadow := func(p): return biome_at(p.x, p.y) == B.MEADOW
	var high := func(p): return h_at(p.x, p.y) > 9.0 and biome_at(p.x, p.y) != B.ROCKY
	var rocky := func(p): var b := biome_at(p.x, p.y); return b == B.ROCKY or b == B.PINE
	var any := func(_p): return true
	for i in 2:
		_flat_poi(_poi("camp", forest, 10.0), 5.0)
	for i in 2:
		_poi("berry_thicket", any, 9.0)
	for i in 2:
		_poi("mushroom_ring", forest, 8.0)
	_flat_poi(_poi("standing_stones", meadow, 10.0), 7.0)
	_poi("fallen_giant", forest, 9.0)
	_flat_poi(_poi("watchtower", high, 12.0), 4.0)
	_poi("lookout", high, 12.0)
	_flat_poi(_poi("hollow_oak", forest, 10.0), 5.0)
	_poi("wildflowers", meadow, 12.0)
	for i in 2:
		_poi("copper_outcrop", rocky, 9.0)
	_flat_poi(_poi("ruins", any, 10.0), 6.0)
	# clay bank near a river bend
	var best_i := -1
	for i in range(15, river.size() - 30, 5):
		var p: Vector2 = river[i]["p"]
		var ok := true
		for q in pois:
			if p.distance_to(q["pos"]) < 30.0:
				ok = false
		if ok and not farm_rect.grow(20).has_point(p) and not town_rect.grow(20).has_point(p):
			best_i = i
			break
	if best_i >= 0:
		var rp: Vector2 = river[best_i]["p"]
		var dir: Vector2 = (river[best_i + 1]["p"] - rp).normalized().orthogonal()
		var cp: Vector2 = rp + dir * (river[best_i]["w"] / 2.0 + 4.0)
		pois.append({"id": "clay_bank", "type": "clay_bank", "pos": cp, "r": 8.0})
	for pd in ponds:
		if pd["kind"] in ["hidden", "hot"]:
			pois.append({"id": pd["id"], "type": pd["kind"] + "_poi", "pos": pd["c"], "r": float(pd["r"]) + 8.0})

func _flat_poi(p: Dictionary, r: float) -> void:
	if p.is_empty():
		return
	var c: Vector2 = p["pos"]
	_flatten_circle(c, r, h_at(c.x, c.y), 4.0)

# ------------------------------------------------------------------ vegetation

func _blocked_for_spawn(p: Vector2, clear: float) -> bool:
	var c := cell(p.x, p.y)
	if water_idx[c] != 0:
		return true
	if road[c] > 20:
		return true
	if farm_rect.grow(3).has_point(p) or town_rect.grow(2).has_point(p):
		return true
	if p.distance_to(cave_pos + Vector2(0, 4)) < 14.0:
		return true
	for q in pois:
		if p.distance_to(q["pos"]) < float(q["r"]) * clear:
			return true
	for b in bridges:
		if p.distance_to(b["p"]) < float(b["len"]) * 0.6 + 2.0:
			return true
	return false

func _place_vegetation() -> void:
	var idx := 0
	var step := 3.2
	var gz := 2.0
	while gz < S - 2:
		var gx := 2.0
		while gx < S - 2:
			var p := Vector2(gx + rng.randf_range(0, step), gz + rng.randf_range(0, step))
			gx += step
			if _blocked_for_spawn(p, 0.8):
				continue
			var b := biome_at(p.x, p.y)
			var r := rng.randf()
			var y := h_at(p.x, p.y)
			var kind := ""
			var v := rng.randi() % 6
			match b:
				B.FOREST:
					if r < 0.32: kind = "oak"
					elif r < 0.38: kind = "birch"
					elif r < 0.46: kind = "bush"
					elif r < 0.49: kind = "berry_bush"
					elif r < 0.53: kind = "rock"
					elif r < 0.555: kind = "stump"
					elif r < 0.57: kind = "twig"
				B.BIRCH:
					if r < 0.3: kind = "birch"
					elif r < 0.36: kind = "oak"
					elif r < 0.42: kind = "bush"
					elif r < 0.45: kind = "rock"
				B.PINE:
					if r < 0.34: kind = "pine"
					elif r < 0.4: kind = "rock"
					elif r < 0.43: kind = "rock_med"
					elif r < 0.46: kind = "bush"
				B.MEADOW:
					if r < 0.035: kind = "oak"
					elif r < 0.05: kind = "birch"
					elif r < 0.08: kind = "bush"
					elif r < 0.1: kind = "rock"
					elif r < 0.11: kind = "berry_bush"
					elif r < 0.125: kind = "weed"
				B.MARSH:
					if r < 0.12: kind = "willow"
					elif r < 0.2: kind = "bush"
					elif r < 0.22: kind = "rock"
				B.ROCKY:
					if r < 0.12: kind = "pine"
					elif r < 0.24: kind = "rock"
					elif r < 0.3: kind = "rock_med"
					elif r < 0.33: kind = "boulder"
					elif r < 0.345: kind = "dead_tree"
				B.SAND:
					if r < 0.06: kind = "rock"
					elif r < 0.09: kind = "willow"
			if kind != "":
				if kind in ["oak", "pine", "birch", "willow"] and _slope(int(p.x), int(p.y)) > 0.9:
					kind = "rock"
				spawns.append({"id": "n%d" % idx, "k": kind, "p": Vector3(p.x, y, p.y), "r": rng.randf() * TAU, "v": v, "s": rng.randf_range(0.85, 1.2)})
				idx += 1
		gz += step
	# decor: grass, flowers, ferns, reeds, pebbles, lilies
	var dz := 1.0
	while dz < S - 1:
		var dx := 1.0
		while dx < S - 1:
			var p := Vector2(dx + rng.randf_range(0, 1.6), dz + rng.randf_range(0, 1.6))
			dx += 1.6
			var c := cell(p.x, p.y)
			var b := biome[c]
			var y := h_at(p.x, p.y)
			var r := rng.randf()
			if water_idx[c] != 0:
				var wl := water_lvl[c]
				if wl - y < 0.35 and r < 0.35:
					decor.append({"k": "reeds", "p": Vector3(p.x, y, p.y), "r": rng.randf() * TAU, "s": rng.randf_range(0.8, 1.2), "v": 0})
				elif wl - y > 0.6 and r < 0.025:
					decor.append({"k": "lily", "p": Vector3(p.x, wl + 0.01, p.y), "r": rng.randf() * TAU, "s": rng.randf_range(0.8, 1.4), "v": rng.randi() % 2})
				continue
			if road[c] > 60 or b == B.TOWN:
				continue
			var k := ""
			match b:
				B.MEADOW, B.FARM:
					if r < 0.42: k = "grass"
					elif r < 0.5 and b == B.MEADOW: k = "flower"
				B.FOREST, B.BIRCH:
					if r < 0.25: k = "grass"
					elif r < 0.33: k = "fern"
					elif r < 0.345: k = "flower"
				B.PINE:
					if r < 0.18: k = "grass"
					elif r < 0.24: k = "fern"
					elif r < 0.27: k = "pebble"
				B.MARSH:
					if r < 0.4: k = "grass"
					elif r < 0.5: k = "reeds"
				B.ROCKY:
					if r < 0.08: k = "pebble"
					elif r < 0.16: k = "grass"
				B.SAND:
					if r < 0.08: k = "pebble"
					elif r < 0.14: k = "grass"
				B.ROAD:
					if r < 0.05: k = "pebble"
			if k != "":
				decor.append({"k": k, "p": Vector3(p.x, y, p.y), "r": rng.randf() * TAU, "s": rng.randf_range(0.7, 1.3), "v": rng.randi() % 6})
		dz += 1.6

func _place_farm_debris() -> void:
	var r := farm_rect.grow(-1.5)
	var house_zone := Rect2(farm_rect.get_center().x - 9, farm_rect.position.y + 1, 18, 11)
	var i := 0
	var counts := {"weed": 70, "twig": 30, "rock": 30, "stump": 6, "log": 1, "boulder": 2}
	for k in counts:
		var made := 0
		var guard := 0
		while made < counts[k] and guard < 2000:
			guard += 1
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			if house_zone.has_point(p) or water_idx[cell(p.x, p.y)] != 0 or _near_water_cell(int(p.x), int(p.y), 2):
				continue
			if p.distance_to(farm_rect.get_center() + Vector2(0, 4)) < 6.0:
				continue
			spawns.append({"id": "f%d" % i, "k": k, "p": Vector3(p.x, h_at(p.x, p.y), p.y), "r": rng.randf() * TAU, "v": rng.randi() % 6, "s": rng.randf_range(0.9, 1.1), "farm": true})
			i += 1
			made += 1

func _place_forage_spots() -> void:
	var i := 0
	for t in 900:
		if forage_spots.size() >= 170:
			break
		var p := Vector2(rng.randf_range(30, S - 30), rng.randf_range(30, S - 30))
		var b := biome_at(p.x, p.y)
		if b in [B.WATER, B.FARM, B.TOWN, B.ROAD]:
			continue
		if _blocked_for_spawn(p, 0.6):
			continue
		forage_spots.append({"p": p, "b": b, "i": i})
		i += 1
	# POI forage spots get special items
	for q in pois:
		var c: Vector2 = q["pos"]
		match q["type"]:
			"mushroom_ring":
				for k in 7:
					var a := TAU * k / 7.0
					forage_spots.append({"p": c + Vector2(cos(a), sin(a)) * 3.2, "b": B.FOREST, "i": i, "poi": "mushroom_ring"})
					i += 1
			"wildflowers":
				for k in 6:
					forage_spots.append({"p": c + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)), "b": B.MEADOW, "i": i, "poi": "wildflowers"})
					i += 1
			"hollow_oak":
				forage_spots.append({"p": c + Vector2(0, -2.6), "b": B.FOREST, "i": i, "poi": "hollow_oak"})
				i += 1

# ------------------------------------------------------------------ names

const ADJ := ["Mossy", "Quiet", "Amber", "Silver", "Hollow", "Bramble", "Willow", "Thistle", "Copper", "Misty", "Old", "Bright", "Crooked", "Lantern", "Fox", "Heron", "Wren", "Clover", "Rook", "Elder", "Sorrel", "Juniper", "Tumble", "Dapple"]
const WATER_N := ["Creek", "Run", "Brook", "Water", "Stream"]

func _pick(arr: Array) -> String:
	return arr[rng.randi() % arr.size()]

func _make_names() -> void:
	names["river"] = "%s %s" % [_pick(ADJ), _pick(WATER_N)]
	names["lake"] = "%s Lake" % _pick(["Glass", "Heron", "Long", "Still", "Moon", "Reed", "Blue", "Sunken"])
	for pd in ponds:
		match pd["kind"]:
			"lake":
				pd["name"] = names["lake"]
			"hidden":
				pd["name"] = "%s Pool" % _pick(["Secret", "Hidden", "Ridge", "Lantern", "Whisper", "Fern"])
			"hot":
				pd["name"] = "%s Springs" % _pick(["Steam", "Ember", "Warm", "Mist"])
			_:
				pd["name"] = "%s Pond" % _pick(ADJ) if pd["id"] != "farm_pond" else "the farm pond"
	var fmt := {
		"camp": ["Abandoned Camp", "%s's Old Camp", "Forgotten Camp"],
		"berry_thicket": ["%s Thicket", "Bramble Patch", "%s Berry Brake"],
		"mushroom_ring": ["Fairy Ring", "%s Mushroom Ring", "The Toadstool Circle"],
		"standing_stones": ["The %s Stones", "Standing Stones", "The Old Circle"],
		"fallen_giant": ["The Fallen Giant", "%s Log", "Old Timber"],
		"watchtower": ["Ruined Watchtower", "%s Tower", "The Old Lookout Tower"],
		"lookout": ["%s Lookout", "Windy Rock", "Eagle's Perch"],
		"hollow_oak": ["The Hollow Oak", "%s Oak", "The Honey Tree"],
		"wildflowers": ["%s Meadow", "Wildflower Field", "%s Blooms"],
		"copper_outcrop": ["%s Outcrop", "Copper Rocks", "Rusty Ledge"],
		"ruins": ["Old Foundations", "%s Ruins", "The Broken Walls"],
		"clay_bank": ["Clay Bank", "%s Clay Bend", "Red Bank"],
		"old_bridge": ["The Old Bridge", "The Broken Bridge"],
		"ford": ["The Ford", "%s Crossing", "Shallow Crossing"],
		"dock": ["Old Dock", "%s Pier"],
		"hidden_poi": [""], "hot_poi": [""],
	}
	var people := ["Tamsin", "Orrin", "Bryn", "Hazel", "Corwin", "Maud", "Pip", "Ottilie", "Edric", "Nell"]
	for q in pois:
		var opts: Array = fmt.get(q["type"], ["%s Place"])
		var f: String = opts[rng.randi() % opts.size()]
		if q["type"] == "hidden_poi" or q["type"] == "hot_poi":
			for pd in ponds:
				if pd["id"] == q["id"]:
					q["name"] = pd["name"]
			continue
		if f.contains("%s"):
			var word := _pick(people) if f.begins_with("%s's") else _pick(ADJ)
			f = f % word
		q["name"] = f
	pois.append({"id": "river_area", "type": "river", "pos": river[int(river.size() * 0.4)]["p"], "r": 14.0, "name": names["river"]})
	pois.append({"id": "lake_area", "type": "lake", "pos": ponds[0]["c"], "r": float(ponds[0]["r"]) + 10.0, "name": names["lake"]})

func farm_spawn() -> Vector3:
	var c := farm_rect.get_center() + Vector2(0, 2)
	return Vector3(c.x, h_at(c.x, c.y) + 0.5, c.y)
