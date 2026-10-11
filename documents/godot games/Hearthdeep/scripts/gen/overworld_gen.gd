class_name OverworldGen
extends RefCounted
## Builds the overworld data. The valley at its heart (farm, town, cave mouth,
## river, lake) is hand-designed in ValleyLayout and identical in every world.
## The wilds beyond its borders (highlands, woods, marsh, meadows) are generated
## from the world seed, so each world has its own places to discover out there.
## Pure data; Overworld turns it into nodes.

const S := 320                 # map size in meters (1 m grid)
const N := S + 1               # height samples per side
const EXPLORE_CELL := 4
const EX_W := S / EXPLORE_CELL
const CORE_SEED := 20261011    # the valley never changes

enum B { MEADOW, FOREST, PINE, BIRCH, MARSH, ROCKY, FARM, TOWN, ROAD, WATER, SAND }

var seed_value := 0
var rng := RandomNumberGenerator.new()      # the wilds (world seed)
var crng := RandomNumberGenerator.new()     # the valley (fixed)
var heights := PackedFloat32Array()
var biome := PackedByteArray()        # per cell (S*S)
var road := PackedByteArray()         # per cell 0..255 road strength
var water_idx := PackedByteArray()    # per cell: 0 none, 1 river, 2+ pond index
var water_lvl := PackedFloat32Array() # per cell water surface height
var core := PackedByteArray()         # per cell: 1 inside the hand-made valley
var wild_t := PackedFloat32Array()    # per cell: 0 in the valley, 1 well into the wilds
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
var bridges: Array = []               # [{p, dir, len, lvl, deck, broken, id}]
var pois: Array = []                  # [{id, type, pos: Vector2, name, r}]
var spawns: Array = []                # resource node placements
var decor: Array = []                 # decorative instance placements [{k, p: Vector3, r, s, v}]
var forage_spots: Array = []          # [{p: Vector2, b: biome, i}]
var walls: Array = []                 # [{a, b, kind}]
var gates: Array = []                 # [{id, p, out, region, arch}]
var names := {}
var nz_core := FastNoiseLite.new()    # fixed: gentle valley relief
var nz_d := FastNoiseLite.new()       # fixed: fine detail
var nz_moist := FastNoiseLite.new()   # fixed: grass color
var nz_forest := FastNoiseLite.new()  # fixed: grass color
var nz_meander := FastNoiseLite.new() # fixed: shorelines and paths
var nz_wh := FastNoiseLite.new()      # world seed: wild terrain
var nz_whill := FastNoiseLite.new()   # world seed: wild hills
var nz_wf := FastNoiseLite.new()      # world seed: wild woods
var nz_wm := FastNoiseLite.new()      # world seed: wild wetness

func generate(seed_in: int) -> void:
	seed_value = seed_in
	rng.seed = Game.hash_ints(seed_in, 1001)
	crng.seed = CORE_SEED
	_setup_noise()
	_set_sites()
	_build_core_mask()
	_base_heights()
	_make_river()
	_make_ponds()
	_flatten_sites()
	_carve_water()
	_make_roads()
	_assign_biomes()
	_place_core_pois()
	_place_pois()
	_make_wild_trails()
	_place_vegetation()
	_place_farm_debris()
	_place_forage_spots()
	_make_names()

# ------------------------------------------------------------------ noise

func _setup_noise() -> void:
	var fixed := [nz_core, nz_d, nz_moist, nz_forest, nz_meander]
	var wild := [nz_wh, nz_whill, nz_wf, nz_wm]
	for i in fixed.size():
		var nz: FastNoiseLite = fixed[i]
		nz.seed = Game.hash_ints(CORE_SEED, 77 + i)
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	for i in wild.size():
		var nz2: FastNoiseLite = wild[i]
		nz2.seed = Game.hash_ints(seed_value, 177 + i)
		nz2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz2.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz_core.frequency = 0.012
	nz_core.fractal_octaves = 3
	nz_d.frequency = 0.03
	nz_d.fractal_octaves = 2
	nz_moist.frequency = 0.009
	nz_moist.fractal_octaves = 3
	nz_forest.frequency = 0.022
	nz_forest.fractal_octaves = 3
	nz_meander.frequency = 0.02
	nz_meander.fractal_octaves = 2
	nz_wh.frequency = 0.011
	nz_wh.fractal_octaves = 4
	nz_whill.frequency = 0.018
	nz_whill.fractal_octaves = 3
	nz_wf.frequency = 0.03
	nz_wf.fractal_octaves = 3
	nz_wm.frequency = 0.012
	nz_wm.fractal_octaves = 3

# ------------------------------------------------------------------ the valley and its borders

func _set_sites() -> void:
	farm_rect = ValleyLayout.FARM_RECT
	town_center = ValleyLayout.TOWN_CENTER
	town_rect = Rect2(136, 96, 112, 130)
	cave_pos = ValleyLayout.CAVE_POS
	farm_h = ValleyLayout.CORE_H
	town_h = ValleyLayout.CORE_H
	cave_h = ValleyLayout.CORE_H + 0.6
	for w in ValleyLayout.WALLS:
		walls.append(w.duplicate())
	for g in ValleyLayout.GATES:
		gates.append(g.duplicate())

func _cidx(x: int, z: int) -> int:
	return clamp(z, 0, S - 1) * S + clamp(x, 0, S - 1)

func is_core(x: float, z: float) -> bool:
	if x < 0 or z < 0 or x >= S or z >= S:
		return false
	return core[_cidx(int(x), int(z))] == 1

## Which wild region a point belongs to (or "core").
func region_at(x: float, z: float) -> String:
	if is_core(x, z):
		return "core"
	if z < ValleyLayout.CLIFF_Z:
		return "north"
	if x < ValleyLayout.WEST_WALL_X:
		return "west"
	if z > 232.0 and x < 262.0:
		return "south"
	if z > 250.0:
		return "south"
	return "east"

## The valley is everything you can reach from the plaza without crossing the
## cliffs, the west wall, the river or the lake. Everything else is wild.
func _build_core_mask() -> void:
	var barrier := PackedByteArray()
	barrier.resize(S * S)
	barrier.fill(0)
	for x in range(0, S):
		for z in range(0, int(ValleyLayout.CLIFF_Z) + 1):
			barrier[z * S + x] = 1
	# the border line itself is continuous (gates are only gaps in the physical wall)
	_raster_line(barrier, Vector2(ValleyLayout.WEST_WALL_X, ValleyLayout.CLIFF_Z - 2.0), Vector2(ValleyLayout.WEST_WALL_X, 258), 1.5)
	for w in walls:
		_raster_line(barrier, w["a"], w["b"], 1.5)
	var rpts := ValleyLayout.smooth_polyline(ValleyLayout.RIVER, 1.0)
	for i in range(1, rpts.size()):
		_raster_line(barrier, rpts[i - 1], rpts[i], 3.2)
	var lc: Vector2 = ValleyLayout.LAKE["c"]
	var lr: float = ValleyLayout.LAKE["r"] - 1.0
	for z in range(int(lc.y - lr), int(lc.y + lr) + 1):
		for x in range(int(lc.x - lr), int(lc.x + lr) + 1):
			if Vector2(x, z).distance_to(lc) < lr:
				barrier[_cidx(x, z)] = 1
	core.resize(S * S)
	core.fill(0)
	var stack: Array[int] = [_cidx(int(town_center.x), int(town_center.y))]
	core[stack[0]] = 1
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % S
		var z := i / S
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var nz: int = z + d.y
			if nx < 1 or nz < 1 or nx >= S - 1 or nz >= S - 1:
				continue
			var j := nz * S + nx
			if core[j] == 0 and barrier[j] == 0:
				core[j] = 1
				stack.append(j)
	# the river and the lake belong to the valley too (their near banks are its border)
	# distance into the wilds, for blending the terrain
	var dist := PackedFloat32Array()
	dist.resize(S * S)
	for i in S * S:
		dist[i] = 0.0 if core[i] == 1 else 1e6
	for z in S:
		for x in S:
			var i := z * S + x
			if x > 0:
				dist[i] = min(dist[i], dist[i - 1] + 1.0)
			if z > 0:
				dist[i] = min(dist[i], dist[i - S] + 1.0)
			if x > 0 and z > 0:
				dist[i] = min(dist[i], dist[i - S - 1] + 1.414)
			if x < S - 1 and z > 0:
				dist[i] = min(dist[i], dist[i - S + 1] + 1.414)
	for z in range(S - 1, -1, -1):
		for x in range(S - 1, -1, -1):
			var i := z * S + x
			if x < S - 1:
				dist[i] = min(dist[i], dist[i + 1] + 1.0)
			if z < S - 1:
				dist[i] = min(dist[i], dist[i + S] + 1.0)
			if x < S - 1 and z < S - 1:
				dist[i] = min(dist[i], dist[i + S + 1] + 1.414)
			if x > 0 and z < S - 1:
				dist[i] = min(dist[i], dist[i + S - 1] + 1.414)
	wild_t.resize(S * S)
	for i in S * S:
		var z := i / S
		var width := 5.0 if z < ValleyLayout.CLIFF_Z + 2 else 16.0
		var t: float = clamp(dist[i] / width, 0.0, 1.0)
		wild_t[i] = t * t * (3.0 - 2.0 * t)

func _raster_line(buf: PackedByteArray, a: Vector2, b: Vector2, r: float) -> void:
	var steps := int(a.distance_to(b) / 0.5) + 1
	for k in steps + 1:
		var p := a.lerp(b, float(k) / steps)
		for z in range(int(p.y - r), int(p.y + r) + 1):
			for x in range(int(p.x - r), int(p.x + r) + 1):
				if x >= 0 and z >= 0 and x < S and z < S and Vector2(x, z).distance_to(p) <= r:
					buf[z * S + x] = 1

# ------------------------------------------------------------------ heights

func _base_heights() -> void:
	heights.resize(N * N)
	for z in N:
		for x in N:
			heights[z * N + x] = _raw_h(float(x), float(z))
	_carve_ramp()

func _valley_h(x: float, z: float) -> float:
	var h := ValleyLayout.CORE_H + 0.45 * nz_core.get_noise_2d(x, z)
	# the ground rises a little toward the cliffs
	h += clamp((96.0 - z) / 20.0, 0.0, 1.0) * 1.1
	return h

func _wild_h(x: float, z: float) -> float:
	var n := nz_wh.get_noise_2d(x, z)
	var hill := nz_whill.get_noise_2d(x, z)
	var low := 6.2 + 2.6 * n + (hill * hill * 9.0 if hill > 0.0 else 0.0)
	# the marsh to the south sits lower and flatter
	var marsh := clamp((z - 244.0) / 24.0, 0.0, 1.0)
	low = lerp(low, 4.6 + 0.9 * n, marsh * 0.85)
	# the highlands to the north are high and rugged
	var high := 19.0 + 4.5 * n + (hill * hill * 14.0 if hill > 0.0 else 0.0) + 1.5 * nz_d.get_noise_2d(x * 2.0, z * 2.0)
	var north := clamp((ValleyLayout.CLIFF_Z + 1.0 - z) / 7.0, 0.0, 1.0)
	return lerp(low, high, north * north * (3.0 - 2.0 * north))

func _raw_h(x: float, z: float) -> float:
	var t := wild_t[_cidx(int(x), int(z))]
	var h: float = lerp(_valley_h(x, z), _wild_h(x, z), t)
	var e: float = min(min(x, z), min(S - x, S - z))
	if e < 16.0:
		var k := 1.0 - e / 16.0
		h += k * k * 22.0 + k * 5.0 * abs(nz_d.get_noise_2d(x * 2.0, z * 2.0))
	return h

## The trail up through the gap in the cliffs: an even ramp with steep sides.
func _carve_ramp() -> void:
	var a: Vector2 = ValleyLayout.HIGHLAND_RAMP[0]
	var b: Vector2 = ValleyLayout.HIGHLAND_RAMP[1]
	var ha := _hv(int(a.x), int(a.y))
	var hb := _hv(int(b.x), int(b.y))
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	for z in range(int(min(a.y, b.y)) - 6, int(max(a.y, b.y)) + 7):
		for x in range(int(min(a.x, b.x)) - 6, int(max(a.x, b.x)) + 7):
			var v := Vector2(x, z) - a
			var along: float = clamp(v.dot(dir), 0.0, length)
			var side: float = abs(v.dot(dir.orthogonal()))
			if side > 5.0:
				continue
			var t := along / length
			var target: float = lerp(ha, hb, t)
			var k: float = clamp((side - 2.8) / 2.2, 0.0, 1.0)
			_set_hv(x, z, lerp(target, max(_hv(x, z), target), k))

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

func _flatten_rect(r: Rect2, target: float, margin: float) -> void:
	var x0 := int(r.position.x - margin)
	var z0 := int(r.position.y - margin)
	var x1 := int(r.end.x + margin)
	var z1 := int(r.end.y + margin)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or z < 0 or x >= N or z >= N:
				continue
			if not is_core(x, z) and wild_t[_cidx(x, z)] > 0.3:
				continue
			var dx: float = max(max(r.position.x - x, x - r.end.x), 0.0)
			var dz: float = max(max(r.position.y - z, z - r.end.y), 0.0)
			var d := sqrt(dx * dx + dz * dz)
			var t: float = clamp(d / margin, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			var cur := _hv(x, z)
			var micro := 0.1 * nz_d.get_noise_2d(x * 3.0, z * 3.0)
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
	_flatten_rect(farm_rect, farm_h, 10.0)
	_flatten_rect(town_rect, town_h, 10.0)
	# Delver's Yard and the cave mouth against the cliffs
	_flatten_circle(Vector2(190, 88), 10.0, cave_h, 5.0)
	_flatten_circle(cave_pos + Vector2(0, 7), 6.0, cave_h, 4.0)
	for z in range(int(cave_pos.y - 16), int(cave_pos.y + 2)):
		for x in range(int(cave_pos.x - 12), int(cave_pos.x + 12)):
			var d := Vector2(x, z).distance_to(cave_pos + Vector2(0, -8))
			if d < 11.0:
				var t := 1.0 - d / 11.0
				_set_hv(x, z, max(_hv(x, z), cave_h + t * 10.0))

# ------------------------------------------------------------------ water

func _make_river() -> void:
	var pts := ValleyLayout.smooth_polyline(ValleyLayout.RIVER, 2.0)
	var ctrl: Array = ValleyLayout.RIVER
	var widths: Array = ValleyLayout.RIVER_W
	river.clear()
	var run_min := 1e9
	for i in pts.size():
		var p: Vector2 = pts[i]
		if p.y < cave_pos.y + 2.0:
			continue
		# width from the nearest control point
		var best := 0
		var bd := 1e9
		for k in ctrl.size():
			var d: float = p.distance_to(ctrl[k])
			if d < bd:
				bd = d
				best = k
		var w: float = float(widths[best]) + 0.6 * nz_meander.get_noise_2d(p.x * 3.0, p.y)
		var local := h_at(p.x, p.y)
		for o in [-4.0, 4.0]:
			local = min(local, h_at(p.x + o, p.y), h_at(p.x, p.y + o))
		run_min = min(run_min, local)
		river.append({"p": p, "w": w, "lvl": run_min - 0.6})
	var lvl_end: float = river[river.size() - 1]["lvl"]
	ponds = [{"c": ValleyLayout.LAKE["c"], "r": ValleyLayout.LAKE["r"], "kind": "lake", "id": "lake", "lvl": lvl_end}]

func _make_ponds() -> void:
	var fp: Dictionary = ValleyLayout.FARM_POND
	ponds.append({"c": fp["c"], "r": fp["r"], "kind": "pond", "id": "farm_pond", "lvl": farm_h - 0.35})
	# out in the wilds: a hidden pool in the woods, a hot spring in the highlands, a few ponds
	var hp := _wild_spot("west", 30.0, 12.0)
	if hp.x >= 0:
		ponds.append({"c": hp, "r": 5.5, "kind": "hidden", "id": "hidden_pond", "lvl": h_at(hp.x, hp.y) - 0.4, "ridge": true})
	var hs := _wild_spot("north", 24.0, 10.0)
	if hs.x >= 0:
		ponds.append({"c": hs, "r": 3.0, "kind": "hot", "id": "hot_spring", "lvl": h_at(hs.x, hs.y) - 0.3})
	var made := 0
	for region in ["south", "west", "east"]:
		var c3 := _wild_spot(region, 22.0, 10.0)
		if c3.x < 0:
			continue
		ponds.append({"c": c3, "r": rng.randf_range(4.0, 6.5), "kind": "pond", "id": "pond_%d" % made, "lvl": h_at(c3.x, c3.y) - 0.45})
		made += 1
	for i in ponds.size():
		ponds[i]["noise_off"] = float(i) * 17.3 if i < 2 else rng.randf_range(0, 100)

## A random spot well inside a wild region, away from water, gates and other ponds.
func _wild_spot(region: String, edge: float, inset: float) -> Vector2:
	for i in 200:
		var c := Vector2(rng.randf_range(edge, S - edge), rng.randf_range(edge, S - edge))
		if region_at(c.x, c.y) != region:
			continue
		if wild_t[_cidx(int(c.x), int(c.y))] < 0.99:
			continue
		var e: float = min(min(c.x, c.y), min(S - c.x, S - c.y))
		if e < edge:
			continue
		if _near_river(c, 16.0) or _dist_to_core(c) < inset:
			continue
		var ok := true
		for p in ponds:
			if c.distance_to(p["c"]) < 30.0:
				ok = false
		for g in gates:
			if c.distance_to(g["p"]) < 18.0:
				ok = false
		if ok:
			return c
	return Vector2(-1, -1)

func _dist_to_core(p: Vector2) -> float:
	var t := wild_t[_cidx(int(p.x), int(p.y))]
	return 16.0 * t

func _near_river(p: Vector2, d: float) -> bool:
	for r in river:
		if p.distance_to(r["p"]) < d:
			return true
	return false

func pond_radius(pd: Dictionary, ang: float) -> float:
	var wob := 0.12 if pd["id"] == "lake" else 0.22
	return float(pd["r"]) * (1.0 + wob * nz_meander.get_noise_2d(cos(ang) * 30.0 + pd["noise_off"], sin(ang) * 30.0))

func _carve_water() -> void:
	water_idx.resize(S * S)
	water_lvl.resize(S * S)
	water_idx.fill(0)
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

func _road_line(a: Vector2, b: Vector2, wiggle: float, r: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := int(a.distance_to(b) / 2.0) + 1
	var off := r.randf_range(0, 500)
	var nrm := (b - a).normalized().orthogonal()
	for i in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var env := sin(t * PI)
		p += nrm * nz_meander.get_noise_2d(off + t * 40.0, 3.0) * wiggle * env
		pts.append(p)
	return pts

## Paints a road onto the ground and evens out the terrain under it.
func _paint_road(line: PackedVector2Array, width: float, strength: int, flatten: float) -> void:
	for i in line.size():
		var p: Vector2 = line[i]
		var acc := 0.0
		var cnt := 0
		for j in range(max(0, i - 3), min(line.size(), i + 4)):
			acc += h_at(line[j].x, line[j].y)
			cnt += 1
		var target := acc / cnt
		var reach := int(width) + 1
		for z in range(int(p.y) - reach, int(p.y) + reach + 1):
			for x in range(int(p.x) - reach, int(p.x) + reach + 1):
				if x < 0 or z < 0 or x >= S or z >= S:
					continue
				var d := Vector2(x, z).distance_to(p)
				if d > width:
					continue
				var st := int(clamp((1.0 - d / width) * float(strength) * 1.6, 0.0, float(strength)))
				if st > road[z * S + x]:
					road[z * S + x] = st
				if water_idx[z * S + x] == 0 and d < width * 0.75 and flatten > 0.0:
					_set_hv(x, z, lerp(_hv(x, z), target, flatten))

func _make_roads() -> void:
	road.resize(S * S)
	road.fill(0)
	for key in ValleyLayout.ROADS:
		var line := ValleyLayout.smooth_polyline(ValleyLayout.ROADS[key], 2.0)
		roads.append(line)
		_paint_road(line, 3.2, 255, 0.55)
	# the plaza
	for z in range(int(town_center.y) - 17, int(town_center.y) + 18):
		for x in range(int(town_center.x) - 17, int(town_center.x) + 18):
			var dd := Vector2(x, z).distance_to(town_center)
			if dd < 15.5:
				road[z * S + x] = max(road[z * S + x], 255 if dd < 13.5 else int((15.5 - dd) * 127.0))
	# Delver's Yard, paved in front of the cave mouth
	for z in range(76, 100):
		for x in range(176, 206):
			var dy := Vector2(x, z).distance_to(Vector2(190, 87))
			if dy < 10.0:
				road[z * S + x] = max(road[z * S + x], 230 if dy < 8.5 else int((10.0 - dy) * 150.0))
	# bridges where the streets meet the river
	for bd in ValleyLayout.BRIDGES:
		_bridge_near(bd[0], bd[1])
	# the dock on Heron Lake, at the end of the dock lane
	var lake: Dictionary = ponds[0]
	var end: Vector2 = ValleyLayout.ROADS["dock_lane"][-1]
	var dock_dir: Vector2 = (end - lake["c"]).normalized()
	var dock_p: Vector2 = lake["c"] + dock_dir * (pond_radius(lake, atan2(dock_dir.y, dock_dir.x)) + 5.0)
	pois.append({"id": "dock", "type": "dock", "pos": dock_p - dock_dir * 4.0, "dir": -dock_dir, "r": 9.0, "name": "Heron Pier"})

func _bridge_near(near: Vector2, broken: bool) -> void:
	var ri := 0
	var bd := 1e9
	for i in river.size():
		var d: float = river[i]["p"].distance_to(near)
		if d < bd:
			bd = d
			ri = i
	var rp: Vector2 = river[ri]["p"]
	var dir: Vector2 = (river[min(ri + 2, river.size() - 1)]["p"] - river[max(ri - 2, 0)]["p"]).normalized().orthogonal()
	var half: float = river[ri]["w"] / 2.0 + 3.5
	_add_bridge(rp - dir * half, rp + dir * half, broken)
	if broken:
		pois.append({"id": "old_bridge", "type": "old_bridge", "pos": rp, "r": 12.0, "name": "The Old Bridge"})

func _add_bridge(a: Vector2, b: Vector2, broken: bool) -> void:
	var c := (a + b) / 2.0
	var dir := (b - a).normalized()
	var l := a.distance_to(b) + 3.0
	var wi := water_idx[cell(c.x, c.y)]
	var lvl: float = water_lvl[cell(c.x, c.y)] if wi != 0 else h_at(c.x, c.y)
	var deck: float = max(max(h_at(a.x - dir.x * 2.0, a.y - dir.y * 2.0), h_at(b.x + dir.x * 2.0, b.y + dir.y * 2.0)), lvl + 0.6)
	for e in [a - dir * 1.5, b + dir * 1.5]:
		if water_idx[cell(e.x, e.y)] == 0:
			_flatten_circle(e, 1.6, deck, 2.5)
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

## Trails from each gate out to the places in that stretch of wild.
func _make_wild_trails() -> void:
	for g in gates:
		var start: Vector2 = g["p"] + Vector2(g["out"]) * 3.0
		var region: String = g["region"]
		var targets: Array = []
		for q in pois:
			if q.get("wild", false) and region_at(q["pos"].x, q["pos"].y) == region:
				targets.append(q)
		targets.sort_custom(func(a, b): return start.distance_to(a["pos"]) < start.distance_to(b["pos"]))
		if Game.autotest.begins_with("mapdump"):
			print("[autotest] trail from %s: %d targets" % [g["id"], targets.size()])
		var from := start
		for k in min(2, targets.size()):
			var to: Vector2 = targets[k]["pos"]
			var line := _road_line(from, to, 10.0, rng)
			var keep := PackedVector2Array()
			for p in line:
				if not is_core(p.x, p.y) and water_idx[cell(p.x, p.y)] == 0:
					keep.append(p)
			roads.append(keep)
			_paint_road(keep, 2.6, 190, 0.25)
			from = to

# ------------------------------------------------------------------ biomes

func _assign_biomes() -> void:
	biome.resize(S * S)
	for z in S:
		for x in S:
			var i := z * S + x
			var b := B.MEADOW
			var h := heights[z * N + x]
			var slope := _slope(x, z)
			var p := Vector2(x, z)
			if water_idx[i] != 0 and h < water_lvl[i]:
				b = B.WATER
			elif farm_rect.has_point(p):
				b = B.FARM
			elif core[i] == 1 and town_rect.has_point(p) and road[i] < 120:
				b = B.TOWN
			elif road[i] > 120:
				b = B.ROAD
			elif core[i] == 1:
				if slope > 1.1:
					b = B.ROCKY
				elif _near_water_cell(x, z, 3):
					b = B.SAND
				else:
					var g := _grove_at(p)
					if not g.is_empty():
						b = B.BIRCH if g["kind"] == "birch" else (B.MARSH if g["kind"] == "willow" else B.FOREST)
			else:
				var e: float = min(min(x, z), min(S - x, S - z))
				var fo := nz_wf.get_noise_2d(x, z)
				var moist := nz_wm.get_noise_2d(x, z)
				if e < 14.0 or slope > 1.0 or h > 25.0:
					b = B.ROCKY
				elif _near_water_cell(x, z, 3):
					b = B.SAND
				else:
					match region_at(x, z):
						"north":
							b = B.PINE if fo > -0.35 else B.ROCKY
							if h < 12.0:
								b = B.FOREST if fo > 0.0 else B.MEADOW
						"west":
							b = B.FOREST if fo > -0.3 else B.MEADOW
							if b == B.FOREST and moist < -0.2:
								b = B.BIRCH
						"south":
							if moist > -0.15 and _near_water_cell(x, z, 10):
								b = B.MARSH
							elif fo > 0.15:
								b = B.FOREST
							else:
								b = B.MARSH if moist > 0.2 else B.MEADOW
						_:
							b = B.BIRCH if fo > 0.32 else B.MEADOW
			biome[i] = b

func _grove_at(p: Vector2) -> Dictionary:
	for g in ValleyLayout.GROVES:
		var r: float = g["r"] * (1.0 + 0.2 * nz_meander.get_noise_2d(p.x * 2.0, p.y * 2.0))
		if p.distance_to(g["c"]) < r:
			return g
	return {}

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
	# the wilds read a little deeper and wilder than the tended valley
	var wt := wild_t[i]
	grass = grass.lerp(Color("467a36"), wt * 0.35)
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
			var sl := _slope(cx, cz)
			if sl > 0.9:
				# cliff faces: dark layered stone with moss in the cracks
				var streak := 0.5 + 0.5 * nz_d.get_noise_2d(x * 0.6, z * 3.0)
				c = Color("5a4f45").lerp(Color("3c3530"), streak * 0.8)
				var hh := heights[cz * N + cx]
				if fmod(hh, 2.4) < 0.6:
					c = c.darkened(0.18)
				if nz_forest.get_noise_2d(x * 3.0, z * 3.0) > 0.3:
					c = c.lerp(Color("3e5a2e"), 0.55)
				grassy = 0.05
			else:
				c = Color("8a8478").lerp(Color("7a8a5e"), clamp(1.0 - sl, 0.0, 0.5))
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
			c = grass.lerp(Color("64a044"), 0.25)
	var rd := road[i] / 255.0
	if Vector2(cx, cz).distance_to(town_center) < 9.6:
		return Color(0.62, 0.6, 0.55, 0.0)
	if Vector2(cx, cz).distance_to(Vector2(190, 87)) < 8.0:
		return Color(0.56, 0.54, 0.5, 0.0)
	if rd > 0.0:
		var road_col := Color("9a7a50") if core[i] == 1 else Color("8a7454")
		c = c.lerp(road_col, clamp(rd * 1.4, 0.0, 1.0))
		grassy *= 1.0 - clamp(rd * 1.4, 0.0, 1.0)
	var h := heights[cz * N + cx]
	if b != B.WATER and h > 22.0:
		c = c.lerp(Color("9a948a"), clamp((h - 22.0) / 10.0, 0.0, 0.8))
		grassy *= 0.5
	c.a = grassy
	return c

# ------------------------------------------------------------------ points of interest

func _place_core_pois() -> void:
	for q in ValleyLayout.CORE_POIS:
		pois.append(q.duplicate())

func _free_spot(min_d: float, pred: Callable, tries: int = 120) -> Vector2:
	for i in tries:
		var p := Vector2(rng.randf_range(22, S - 22), rng.randf_range(22, S - 22))
		if wild_t[_cidx(int(p.x), int(p.y))] < 0.95:
			continue
		var e: float = min(min(p.x, p.y), min(S - p.x, S - p.y))
		if e < 20.0:
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
		for pd in ponds:
			if p.distance_to(pd["c"]) < float(pd["r"]) + 10.0:
				ok = false
		for g in gates:
			if p.distance_to(g["p"]) < 14.0:
				ok = false
		if not ok:
			continue
		if not pred.call(p):
			continue
		return p
	return Vector2(-1, -1)

func _poi(type: String, region: String, pred: Callable, r: float = 10.0, min_d: float = 30.0) -> Dictionary:
	var full := func(q): return region_at(q.x, q.y) == region and pred.call(q)
	var p := _free_spot(min_d, full)
	if p.x < 0:
		p = _free_spot(min_d * 0.6, func(q): return region_at(q.x, q.y) == region)
	if p.x < 0:
		return {}
	var d := {"id": "%s_%d" % [type, pois.size()], "type": type, "pos": p, "r": r, "wild": true}
	pois.append(d)
	return d

func _place_pois() -> void:
	var forest := func(p): var b := biome_at(p.x, p.y); return b == B.FOREST or b == B.BIRCH
	var open := func(p): var b := biome_at(p.x, p.y); return b == B.MEADOW or b == B.BIRCH
	var high := func(p): return h_at(p.x, p.y) > 16.0 and biome_at(p.x, p.y) != B.ROCKY
	var rocky := func(p): var b := biome_at(p.x, p.y); return b == B.ROCKY or b == B.PINE
	var any := func(_p): return true
	# the highlands
	_flat_poi(_poi("watchtower", "north", high, 12.0), 4.0)
	_poi("lookout", "north", high, 12.0)
	_poi("copper_outcrop", "north", rocky, 9.0)
	_poi("copper_outcrop", "north", rocky, 9.0)
	_flat_poi(_poi("camp", "north", any, 10.0), 5.0)
	# Whisperwood
	_flat_poi(_poi("hollow_oak", "west", forest, 10.0), 5.0)
	_poi("mushroom_ring", "west", forest, 8.0)
	_poi("mushroom_ring", "west", forest, 8.0)
	_poi("fallen_giant", "west", forest, 9.0)
	_flat_poi(_poi("camp", "west", forest, 10.0), 5.0)
	# Fenmarsh
	_flat_poi(_poi("ruins", "south", any, 10.0), 6.0)
	_poi("berry_thicket", "south", any, 9.0)
	_poi("mushroom_ring", "south", forest, 8.0)
	# Eastmeadow
	_flat_poi(_poi("standing_stones", "east", open, 10.0), 7.0)
	_poi("wildflowers", "east", open, 12.0)
	_poi("berry_thicket", "east", any, 9.0)
	_poi("copper_outcrop", "east", any, 9.0)
	for pd in ponds:
		if pd["kind"] in ["hidden", "hot"]:
			pois.append({"id": pd["id"], "type": pd["kind"] + "_poi", "pos": pd["c"], "r": float(pd["r"]) + 8.0, "wild": true})

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
	if p.distance_to(cave_pos + Vector2(0, 8)) < 16.0:
		return true
	for q in pois:
		if p.distance_to(q["pos"]) < float(q["r"]) * clear:
			return true
	for b in bridges:
		if p.distance_to(b["p"]) < float(b["len"]) * 0.6 + 2.0:
			return true
	for g in gates:
		if p.distance_to(g["p"]) < 5.0:
			return true
	for w in walls:
		if Geometry2D.get_closest_point_to_segment(p, w["a"], w["b"]).distance_to(p) < 2.2:
			return true
	if _near_ramp(p, 4.5):
		return true
	return false

func _near_ramp(p: Vector2, d: float) -> bool:
	var a: Vector2 = ValleyLayout.HIGHLAND_RAMP[0]
	var b: Vector2 = ValleyLayout.HIGHLAND_RAMP[1]
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < d

func _place_vegetation() -> void:
	var idx := 0
	var step := 3.2
	var gz := 2.0
	while gz < S - 2:
		var gx := 2.0
		while gx < S - 2:
			var in_core := is_core(gx + 1.6, gz + 1.6)
			var r0: RandomNumberGenerator = crng if in_core else rng
			var p := Vector2(gx + r0.randf_range(0, step), gz + r0.randf_range(0, step))
			gx += step
			var r := r0.randf()
			var v := r0.randi() % 6
			var rot := r0.randf() * TAU
			var scl := r0.randf_range(0.85, 1.2)
			if _blocked_for_spawn(p, 0.8):
				continue
			var b := biome_at(p.x, p.y)
			var y := h_at(p.x, p.y)
			var kind := ""
			if in_core:
				kind = _core_plant(p, b, r)
			else:
				kind = _wild_plant(b, r)
			if kind != "":
				if kind in ["oak", "pine", "birch", "willow"] and _slope(int(p.x), int(p.y)) > 0.9:
					kind = "rock"
				spawns.append({"id": "n%d" % idx, "k": kind, "p": Vector3(p.x, y, p.y), "r": rot, "v": v, "s": scl})
				idx += 1
		gz += step
	# tumbled boulders at the foot of the north cliffs
	var bx := 62.0
	while bx < 250.0:
		bx += crng.randf_range(4.0, 9.0)
		var bp := Vector2(bx, ValleyLayout.CLIFF_Z + crng.randf_range(0.5, 2.5))
		var bs := crng.randf_range(0.7, 1.5)
		var bk := "boulder" if crng.randf() < 0.45 else "rock_med"
		var brot := crng.randf() * TAU
		if abs(bx - cave_pos.x) < 11.0 or abs(bx - ValleyLayout.FALLS.x) < 8.0 or _near_ramp(bp, 6.0):
			continue
		decor.append({"k": bk, "p": Vector3(bp.x, h_at(bp.x, bp.y) - 0.3, bp.y), "r": brot, "s": bs, "v": 0})
	# decor: grass, flowers, ferns, reeds, pebbles, lilies
	var dz := 1.0
	while dz < S - 1:
		var dx := 1.0
		while dx < S - 1:
			var r1: RandomNumberGenerator = crng if is_core(dx + 0.8, dz + 0.8) else rng
			var p := Vector2(dx + r1.randf_range(0, 1.6), dz + r1.randf_range(0, 1.6))
			dx += 1.6
			var r := r1.randf()
			var rot2 := r1.randf() * TAU
			var sc := r1.randf_range(0.7, 1.3)
			var vv := r1.randi() % 6
			var c := cell(p.x, p.y)
			var b := biome[c]
			var y := h_at(p.x, p.y)
			if water_idx[c] != 0:
				var wl := water_lvl[c]
				if wl - y < 0.35 and r < 0.35:
					decor.append({"k": "reeds", "p": Vector3(p.x, y, p.y), "r": rot2, "s": sc, "v": 0})
				elif wl - y > 0.6 and r < 0.025:
					decor.append({"k": "lily", "p": Vector3(p.x, wl + 0.01, p.y), "r": rot2, "s": sc, "v": vv % 2})
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
				decor.append({"k": k, "p": Vector3(p.x, y, p.y), "r": rot2, "s": sc, "v": vv})
		dz += 1.6

## The tended valley: trees in the groves, a scatter of bushes and stones elsewhere.
func _core_plant(p: Vector2, b: int, r: float) -> String:
	var g := _grove_at(p)
	if not g.is_empty():
		match g["kind"]:
			"birch":
				if r < 0.34: return "birch"
				if r < 0.42: return "bush"
				if r < 0.46: return "berry_bush"
			"willow":
				if r < 0.3: return "willow"
				if r < 0.4: return "bush"
			"orchard":
				if r < 0.3: return "oak"
				if r < 0.42: return "berry_bush"
				if r < 0.5: return "bush"
			_:
				if r < 0.36: return "oak"
				if r < 0.42: return "birch"
				if r < 0.5: return "bush"
				if r < 0.53: return "stump"
		return ""
	if b == B.ROCKY:
		if r < 0.16: return "rock"
		if r < 0.2: return "rock_med"
		return ""
	if b == B.SAND:
		return "rock" if r < 0.03 else ""
	if r < 0.012: return "oak"
	if r < 0.02: return "birch"
	if r < 0.045: return "bush"
	if r < 0.06: return "rock"
	if r < 0.07: return "weed"
	return ""

func _wild_plant(b: int, r: float) -> String:
	match b:
		B.FOREST:
			if r < 0.34: return "oak"
			if r < 0.4: return "birch"
			if r < 0.48: return "bush"
			if r < 0.51: return "berry_bush"
			if r < 0.55: return "rock"
			if r < 0.575: return "stump"
			if r < 0.59: return "twig"
		B.BIRCH:
			if r < 0.3: return "birch"
			if r < 0.36: return "oak"
			if r < 0.42: return "bush"
			if r < 0.45: return "rock"
		B.PINE:
			if r < 0.36: return "pine"
			if r < 0.42: return "rock"
			if r < 0.45: return "rock_med"
			if r < 0.48: return "bush"
		B.MEADOW:
			if r < 0.04: return "oak"
			if r < 0.055: return "birch"
			if r < 0.09: return "bush"
			if r < 0.11: return "rock"
			if r < 0.12: return "berry_bush"
			if r < 0.135: return "weed"
		B.MARSH:
			if r < 0.13: return "willow"
			if r < 0.21: return "bush"
			if r < 0.23: return "rock"
		B.ROCKY:
			if r < 0.12: return "pine"
			if r < 0.24: return "rock"
			if r < 0.3: return "rock_med"
			if r < 0.33: return "boulder"
			if r < 0.345: return "dead_tree"
		B.SAND:
			if r < 0.06: return "rock"
			if r < 0.09: return "willow"
	return ""

func _place_farm_debris() -> void:
	var r := farm_rect.grow(-1.5)
	var house_zone := Rect2(farm_rect.get_center().x - 9, farm_rect.position.y + 1, 18, 11)
	var i := 0
	var counts := {"weed": 80, "twig": 34, "rock": 34, "stump": 7, "log": 1, "boulder": 2}
	for k in counts:
		var made := 0
		var guard := 0
		while made < counts[k] and guard < 2000:
			guard += 1
			var p := Vector2(crng.randf_range(r.position.x, r.end.x), crng.randf_range(r.position.y, r.end.y))
			var rot := crng.randf() * TAU
			var v := crng.randi() % 6
			var s := crng.randf_range(0.9, 1.1)
			if house_zone.has_point(p) or water_idx[cell(p.x, p.y)] != 0 or _near_water_cell(int(p.x), int(p.y), 2):
				continue
			if p.distance_to(farm_rect.get_center() + Vector2(0, 4)) < 6.0:
				continue
			spawns.append({"id": "f%d" % i, "k": k, "p": Vector3(p.x, h_at(p.x, p.y), p.y), "r": rot, "v": v, "s": s, "farm": true})
			i += 1
			made += 1

func _place_forage_spots() -> void:
	var i := 0
	# the valley: a modest, familiar scatter
	var made := 0
	for t in 600:
		if made >= 45:
			break
		var p := Vector2(crng.randf_range(60, 260), crng.randf_range(76, 250))
		if not is_core(p.x, p.y):
			continue
		var b := biome_at(p.x, p.y)
		if b in [B.WATER, B.FARM, B.TOWN, B.ROAD] or _blocked_for_spawn(p, 0.6):
			continue
		forage_spots.append({"p": p, "b": b, "i": i})
		i += 1
		made += 1
	# the wilds: plenty, and different in every world
	for t in 1200:
		if forage_spots.size() >= 220:
			break
		var p2 := Vector2(rng.randf_range(20, S - 20), rng.randf_range(20, S - 20))
		if is_core(p2.x, p2.y):
			continue
		var b2 := biome_at(p2.x, p2.y)
		if b2 in [B.WATER, B.FARM, B.TOWN, B.ROAD] or _blocked_for_spawn(p2, 0.6):
			continue
		forage_spots.append({"p": p2, "b": b2, "i": i})
		i += 1
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

func _pick(arr: Array) -> String:
	return arr[rng.randi() % arr.size()]

func _make_names() -> void:
	names = ValleyLayout.NAMES.duplicate()
	for pd in ponds:
		match pd["id"]:
			"lake":
				pd["name"] = names["lake"]
			"farm_pond":
				pd["name"] = names["farm_pond"]
			_:
				match pd["kind"]:
					"hidden":
						pd["name"] = "%s Pool" % _pick(["Secret", "Hidden", "Ridge", "Lantern", "Whisper", "Fern"])
					"hot":
						pd["name"] = "%s Springs" % _pick(["Steam", "Ember", "Warm", "Mist"])
					_:
						pd["name"] = "%s Pond" % _pick(ADJ)
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
	}
	var people := ["Tamsin", "Orrin", "Bryn", "Hazel", "Corwin", "Maud", "Pip", "Ottilie", "Edric", "Nell"]
	for q in pois:
		if q.has("name"):
			continue
		if q["type"] == "hidden_poi" or q["type"] == "hot_poi":
			for pd in ponds:
				if pd["id"] == q["id"]:
					q["name"] = pd["name"]
			continue
		var opts: Array = fmt.get(q["type"], ["%s Place"])
		var f: String = opts[rng.randi() % opts.size()]
		if f.contains("%s"):
			var word := _pick(people) if f.begins_with("%s's") else _pick(ADJ)
			f = f % word
		q["name"] = f
	pois.append({"id": "river_area", "type": "river", "pos": river[int(river.size() * 0.3)]["p"], "r": 14.0, "name": names["river"]})
	pois.append({"id": "lake_area", "type": "lake", "pos": ponds[0]["c"], "r": float(ponds[0]["r"]) + 10.0, "name": names["lake"]})

func farm_spawn() -> Vector3:
	var c := farm_rect.get_center() + Vector2(0, 2)
	return Vector3(c.x, h_at(c.x, c.y) + 0.5, c.y)

## Pre-explored on the map: the whole valley (you live here, after all).
func core_explored_cells() -> PackedInt32Array:
	var out := PackedInt32Array()
	for ez in EX_W:
		for ex in EX_W:
			var x := ex * EXPLORE_CELL + EXPLORE_CELL / 2
			var z := ez * EXPLORE_CELL + EXPLORE_CELL / 2
			if core[z * S + x] == 1 or wild_t[z * S + x] < 0.3:
				out.append(ez * EX_W + ex)
	return out
