class_name TownGen
extends RefCounted
## The town of Brindlewick: its buildings around the plaza and along its four
## streets (from ValleyLayout), the people who live there (from TownCast), the
## street network they walk along, and the newcomers who arrive as it grows.
## The same in every world.

const PLAZA_R := 9.0

const SHOP_ROLES := ["merchant", "smith", "innkeeper", "herbalist", "carpenter", "angler", "mayor"]
const ROLE_INFO := {
	"merchant": {"title": "Shopkeeper", "building": "General Store", "shop": "general", "interest": "trading", "sign": Color("f2c94c")},
	"smith": {"title": "Blacksmith", "building": "Smithy", "shop": "blacksmith", "interest": "metals", "sign": Color("8a8a8a")},
	"innkeeper": {"title": "Innkeeper", "building": "The Tavern", "shop": "tavern", "interest": "cooking", "sign": Color("c8743a")},
	"herbalist": {"title": "Apothecary", "building": "Apothecary", "shop": "herbalist", "interest": "brewing", "sign": Color("5cbf4a")},
	"carpenter": {"title": "Carpenter", "building": "Carpenter's Workshop", "shop": "carpenter", "interest": "crafting", "sign": Color("a8774a")},
	"angler": {"title": "Fishmonger", "building": "Bait & Tackle", "shop": "angler", "interest": "fishing", "sign": Color("4a7ab0")},
	"mayor": {"title": "Mayor", "building": "Town Hall", "shop": "", "interest": "history", "sign": Color("c0504a")},
	"farmer": {"title": "Farmer", "interest": "gardening"},
	"miner": {"title": "Retired Miner", "interest": "caves"},
	"teacher": {"title": "Schoolteacher", "interest": "books"},
	"musician": {"title": "Musician", "interest": "music"},
	"scholar": {"title": "Scholar", "interest": "history"},
	"tailor": {"title": "Tailor", "interest": "crafting"},
	"beekeeper": {"title": "Beekeeper", "interest": "animals"},
	"baker": {"title": "Baker", "interest": "baking"},
	"courier": {"title": "Courier", "interest": "exploring"},
	"painter": {"title": "Painter", "interest": "flowers"},
	"guard": {"title": "Watchkeeper", "interest": "caves"},
	"child": {"title": "Kid", "interest": "exploring"},
	"elder": {"title": "Retired", "interest": "gardening"},
	"explorer": {"title": "Old Explorer", "interest": "caves"},
	"glassblower": {"title": "Glassblower", "interest": "gems"},
	"historian": {"title": "Historian", "interest": "history"},
	"chef": {"title": "Traveling Chef", "interest": "cooking"},
	"stargazer": {"title": "Stargazer", "interest": "stars"},
	"herder": {"title": "Herder", "interest": "animals"},
}
const TRAITS := ["cheerful", "gruff", "shy", "curious", "meticulous", "adventurous", "dreamy", "practical", "nosy", "kind", "proud", "anxious", "witty", "gentle", "stubborn"]
const INTERESTS := ["fishing", "gardening", "metals", "cooking", "brewing", "history", "animals", "crafting", "caves", "music", "stars", "gems", "baking", "books", "flowers", "exploring"]
const INTEREST_ITEMS := {
	"fishing": ["river_trout", "bass", "salmon", "pike", "carp", "glowfin", "moonfin", "blind_cavefish", "worm"],
	"gardening": ["turnip", "potato", "carrot", "tomato", "pumpkin", "melon", "strawberry", "blueberry", "mint", "sunpetal"],
	"metals": ["copper_bar", "iron_bar", "silver_bar", "gold_bar", "iron_ore", "silver_ore", "coal"],
	"cooking": ["fish_stew", "veggie_soup", "pumpkin_soup", "miners_pasty", "omelette", "egg", "wild_leek", "chanterelle"],
	"brewing": ["mint", "sageleaf", "emberroot", "sunpetal", "brew_vigor_1", "cider", "ale", "honeycomb"],
	"history": ["ancient_coin", "fossil_shell", "old_locket", "carved_figure", "rusty_key", "miners_tag", "star_map"],
	"animals": ["egg", "honeycomb", "feather", "hay", "feed", "bramble_berry"],
	"crafting": ["hardwood", "wood", "clay", "sap", "fiber", "iron_bar", "carved_figure"],
	"caves": ["crystal_shard", "glowcap", "cave_mushroom", "beetle_shell", "golem_core", "quartz", "blind_cavefish"],
	"music": ["clockwork_bird", "carved_figure", "honeycomb", "mead", "berry_wine", "feather"],
	"stars": ["moonshroom", "star_map", "quartz", "lumenfruit", "frost_crocus", "moonfin"],
	"gems": ["quartz", "amethyst", "topaz", "aquamarine", "ruby", "emerald", "crystal_shard"],
	"baking": ["wheat", "berry_pie", "fruit_tart", "honey_cake", "apple", "cherry", "campfire_bread", "egg"],
	"books": ["star_map", "soggy_letter", "old_locket", "herbal_tea", "carved_figure"],
	"flowers": ["sunpetal", "sweet_pea", "dandelion", "mossbloom", "frost_crocus", "crystalbloom", "ghostbloom"],
	"exploring": ["feather", "hazelnut", "wild_plum", "fossil_shell", "trail_mix", "ancient_coin", "glowcap"],
	"trading": ["honeycomb", "ruby", "gold_bar", "cider", "pumpkin", "melon"],
}
const WISHES := {
	"fishing": "ridge_koi", "gardening": "starfern", "metals": "starmetal_bar", "cooking": "abyssal_broth", "brewing": "brew_prospector",
	"history": "strange_idol", "animals": "honey_cake", "crafting": "ancient_cog", "caves": "heartstone", "music": "clockwork_bird",
	"stars": "lumenfruit", "gems": "emerald", "baking": "honey_cake", "books": "star_map", "flowers": "crystalbloom",
	"exploring": "dragon_tooth", "trading": "heartstone",
}
var name := ""
var center := Vector3.ZERO
var buildings: Array = []
var residents: Array = []
var by_id := {}
var decor: Array = []
var lamps: Array = []
var rng := RandomNumberGenerator.new()
var road_angles: Array = []
var _nodes := {}            # node name -> Vector3
var _links := {}            # node name -> Array of node names
var _paths := {}            # "a>b" -> Array of node names (cached shortest paths)
var _key_to_id := {}

static func town_name() -> String:
	return ValleyLayout.TOWN_NAME

func generate(g: OverworldGen) -> void:
	name = town_name()
	rng.seed = 4242
	center = Vector3(g.town_center.x, g.town_h, g.town_center.y)
	var farm_entry: Vector2 = ValleyLayout.STREET_NODES["w2"]
	road_angles = [_angle_to(g.town_center, farm_entry), _angle_to(g.town_center, g.cave_pos)]
	for spec in ValleyLayout.BUILDINGS:
		buildings.append(_building(spec, g))
	for d in ValleyLayout.TOWN_DECOR:
		var e: Dictionary = d.duplicate()
		if e.has("p"):
			var p2: Vector2 = e["p"]
			e["p"] = Vector3(p2.x, g.h_at(p2.x, p2.y), p2.y)
		decor.append(e)
	for lp in ValleyLayout.TOWN_LAMPS:
		lamps.append(Vector3(lp.x, g.h_at(lp.x, lp.y), lp.y))
	_build_streets(g)
	_people()
	var extra := int(Game.world.get("town", {}).get("newcomers", 0))
	for i in extra:
		add_newcomer(i)

func _angle_to(a: Vector2, b: Vector2) -> float:
	return atan2(b.y - a.y, b.x - a.x)

func _building(spec: Dictionary, g: OverworldGen) -> Dictionary:
	var p2: Vector2 = spec["pos"]
	var face: Vector2 = spec["face"]
	var to_face := (face - p2).normalized()
	var yaw := atan2(to_face.x, to_face.y)
	var pos := Vector3(p2.x, g.h_at(p2.x, p2.y), p2.y)
	var w: float = spec["w"]
	var d: float = spec["d"]
	var role: String = spec["role"]
	var b := {
		"id": spec["id"], "role": role, "pos": pos, "yaw": yaw, "w": w, "d": d, "floors": int(spec["floors"]),
		"wall": spec["wall"], "roof": spec["roof"], "style": int(spec["style"]), "timber": spec["timber"],
		"door_x": 0.0 if role != "house" and role != "lot" else -0.8, "seed": String(spec["id"]).hash() & 0xffff,
		"fwd": Vector3(to_face.x, 0, to_face.y), "reserved": role == "curio_hall", "residents": [],
	}
	var basis := Basis(Vector3.UP, yaw)
	b["door"] = pos + basis * Vector3(b["door_x"], 0, d / 2.0)
	b["front"] = pos + basis * Vector3(b["door_x"], 0, d / 2.0 + 1.6)
	b["counter"] = pos + basis * Vector3(b["door_x"] - 1.6, 0, d / 2.0 + 2.3)
	for k in ["door", "front", "counter"]:
		var v: Vector3 = b[k]
		v.y = g.h_at(v.x, v.z)
		b[k] = v
	if role == "lot":
		b["role"] = "lot"
		b["reserved"] = true
	if ROLE_INFO.has(role):
		b["name"] = ROLE_INFO[role].get("building", "House")
		b["sign_col"] = ROLE_INFO[role].get("sign", Color.WHITE)
	elif role == "curio_hall":
		b["name"] = "Curio Hall"
	else:
		b["name"] = "House"
	return b

func building(id: String) -> Dictionary:
	for b in buildings:
		if b["id"] == id:
			return b
	return {}

func building_for_role(role: String) -> Dictionary:
	for b in buildings:
		if b["role"] == role:
			return b
	return {}

## A named spot where townsfolk spend part of their day.
func spot(key: String) -> Vector3:
	var p: Vector2 = ValleyLayout.SPOTS.get(key, Vector2(center.x, center.z))
	return Vector3(p.x, center.y, p.y)

# ------------------------------------------------------------------ the street network

func _build_streets(g: OverworldGen) -> void:
	for k in ValleyLayout.STREET_NODES:
		var p: Vector2 = ValleyLayout.STREET_NODES[k]
		_nodes[k] = Vector3(p.x, g.h_at(p.x, p.y), p.y)
		_links[k] = []
	for l in ValleyLayout.STREET_LINKS:
		_links[l[0]].append(l[1])
		_links[l[1]].append(l[0])

func _nearest_node(p: Vector3) -> String:
	var best := ""
	var bd := 1e9
	for k in _nodes:
		var d: float = Vector2(p.x, p.z).distance_to(Vector2(_nodes[k].x, _nodes[k].z))
		if d < bd:
			bd = d
			best = k
	return best

func _node_path(a: String, b: String) -> Array:
	var key := a + ">" + b
	if _paths.has(key):
		return _paths[key]
	var dist := {a: 0.0}
	var prev := {}
	var open: Array = [a]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if dist[open[i]] < dist[open[bi]]:
				bi = i
		var cur: String = open[bi]
		open.remove_at(bi)
		if cur == b:
			break
		for n in _links[cur]:
			var nd: float = dist[cur] + _nodes[cur].distance_to(_nodes[n])
			if nd < float(dist.get(n, 1e9)):
				dist[n] = nd
				prev[n] = cur
				if not open.has(n):
					open.append(n)
	var path: Array = [b]
	var c := b
	while prev.has(c):
		c = prev[c]
		path.push_front(c)
	if path[0] != a:
		path = [a, b]
	_paths[key] = path
	return path

## A walking route between two spots that follows the streets.
func route(a: Vector3, b: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.append(a)
	if Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) > 6.0:
		var na := _nearest_node(a)
		var nb := _nearest_node(b)
		if na != nb:
			for k in _node_path(na, nb):
				pts.append(_nodes[k])
		else:
			pts.append(_nodes[na])
	pts.append(b)
	return pts

# ------------------------------------------------------------------ people

func _person(spec: Dictionary, idx: int) -> Dictionary:
	var look: Dictionary = {"skin": TownCast.S1, "hair": Color("5a3a22"), "hair_style": 0, "shirt": Color("4a7ab0"),
		"pants": Color("4a4a5a"), "hat": -1, "hat_col": Color("4a4a5a"), "height": 1.0, "build": 1.0, "beard": false, "apron": -1}
	for k in spec.get("look", {}):
		look[k] = spec["look"][k]
	look["child"] = spec["age"] == "child"
	if spec["age"] == "child":
		look["beard"] = false
	var p := {
		"id": "npc%d" % idx, "key": spec["key"], "first": spec["first"], "last": spec["last"],
		"name": "%s %s" % [spec["first"], spec["last"]], "age": spec["age"], "role": spec["role"],
		"traits": spec["traits"].duplicate(), "interests": spec["interests"].duplicate(),
		"loves": _valid(spec["loves"]), "likes": _valid(spec["likes"]), "dislikes": spec["dislikes"].duplicate(),
		"family": {}, "friends": [], "rival": "", "look": look, "home": spec.get("home", ""), "work": "",
		"birthday": spec["birthday"].duplicate(), "arrived": 0, "voice_seed": String(spec["key"]).hash() & 0x7fffffff,
		"wish": WISHES.get(spec["interests"][0], "heartstone"),
	}
	if not Items.has(p["wish"]):
		p["wish"] = "heartstone"
	residents.append(p)
	by_id[p["id"]] = p
	_key_to_id[spec["key"]] = p["id"]
	return p

func _valid(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if Items.has(id):
			out.append(id)
	return out

func _people() -> void:
	var specs: Array = TownCast.RESIDENTS
	for i in specs.size():
		_person(specs[i], i)
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var p: Dictionary = residents[i]
		for rel in spec.get("family", {}):
			var v = spec["family"][rel]
			if v is Array:
				var ids: Array = []
				for k in v:
					if _key_to_id.has(k):
						ids.append(_key_to_id[k])
				p["family"][rel] = ids
			elif _key_to_id.has(v):
				p["family"][rel] = _key_to_id[v]
		for k in spec.get("friends", []):
			if _key_to_id.has(k):
				p["friends"].append(_key_to_id[k])
		if spec.get("rival", "") != "" and _key_to_id.has(spec["rival"]):
			p["rival"] = _key_to_id[spec["rival"]]
		var home := building(p["home"])
		if not home.is_empty():
			home["residents"].append(p["id"])
		if ROLE_INFO.get(p["role"], {}).has("building"):
			p["work"] = building_for_role(p["role"]).get("id", "")

## A new neighbor arriving thanks to the town's growth.
func add_newcomer(k: int) -> Dictionary:
	var specs: Array = TownCast.NEWCOMERS
	var spec: Dictionary = specs[k % specs.size()].duplicate(true)
	if k >= specs.size():
		spec["key"] = "%s%d" % [spec["key"], k]
	var p := _person(spec, residents.size())
	var lot := {}
	for b in buildings:
		if b["role"] == "lot":
			lot = b
			break
	if not lot.is_empty():
		lot["role"] = "house"
		lot["reserved"] = false
		lot["residents"].append(p["id"])
		p["home"] = lot["id"]
	else:
		var shared := building_for_role("innkeeper")
		p["home"] = shared.get("id", residents[0]["home"])
	p["arrived"] = 1 + k
	p["friends"] = [residents[(k * 5 + 3) % TownCast.RESIDENTS.size()]["id"]]
	return p

func resident(id: String) -> Dictionary:
	return by_id.get(id, {})

func residents_with_role(role: String) -> Array:
	var out: Array = []
	for p in residents:
		if p["role"] == role:
			out.append(p)
	return out

func keeper_of(shop: String) -> Dictionary:
	for p in residents:
		if ROLE_INFO.get(p["role"], {}).get("shop", "") == shop:
			return p
	return {}

static func job_title(p: Dictionary) -> String:
	return ROLE_INFO.get(p["role"], {}).get("title", p["role"].capitalize())

static func relation_word(rel: String) -> String:
	return {"spouse": "partner", "children": "kid", "parents": "parent", "sibling": "sibling", "grandparent": "grandparent", "grandchildren": "grandkid"}.get(rel, rel)
