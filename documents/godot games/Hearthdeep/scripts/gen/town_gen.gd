class_name TownGen
extends RefCounted
## Generates the town: its name, the buildings ringed around a plaza, and the
## families who live there with their jobs, temperaments, interests and ties.
## Deterministic from the world seed; newcomers are appended as the town grows.

const PLAZA_R := 9.0
const R_INNER := 19.0
const R_OUTER := 31.0

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
const FIRST := ["Agnes", "Bram", "Cora", "Dov", "Elsie", "Finn", "Greta", "Hollis", "Ida", "Jory", "Kit", "Linnea", "Mabel", "Nico", "Opal",
	"Percy", "Quill", "Rosalind", "Silas", "Tamsin", "Ulla", "Vance", "Wren", "Ximena", "Yusuf", "Zelda", "Amara", "Basil", "Calla",
	"Dashiell", "Esme", "Fenn", "Gideon", "Hattie", "Ines", "Jasper", "Kenji", "Lorna", "Magnus", "Nell", "Otto", "Pia", "Rafe",
	"Saoirse", "Teodor", "Una", "Wilhelmina", "Yara", "Arlo", "Bea", "Cassius", "Delphine", "Emeric", "Flora", "Gus", "Hana", "Ivo",
	"Juniper", "Kasimir", "Leander", "Marisol", "Nadia", "Oskar", "Prue", "Rowan", "Sunniva", "Thaddeus", "Viola", "Winifred", "Zeno",
	"Ada", "Booker", "Clementine", "Darius", "Edie", "Felix", "Ginny", "Horace", "Imogen", "Jonah", "Kalinda", "Lucius", "Mirela",
	"Noor", "Orla", "Pascal", "Reuben", "Sela", "Tobiah", "Vesna", "Wendell", "Anouk", "Bertil", "Ciaran", "Dagny", "Ezra", "Freya"]
const LAST := ["Ashdown", "Barrow", "Cobble", "Dunmore", "Elwood", "Fairweather", "Glenn", "Holloway", "Ironside", "Kettleby", "Larkspur",
	"Marsh", "Nettle", "Oakes", "Pennywhistle", "Quarry", "Rook", "Stonebrook", "Thatcher", "Underhill", "Vale", "Whitlock", "Yarrow",
	"Applegate", "Birch", "Copperfield", "Dewhurst", "Fenwick", "Goodwin", "Hearn", "Lowell", "Merriweather", "Norrow", "Pike", "Reed",
	"Sorrel", "Tanner", "Wick", "Brightwater", "Hollins", "Mossgrove", "Tumbledown", "Ember", "Quaile"]
const NAME_A := ["Hollow", "Brindle", "Ash", "Wren", "Thistle", "Copper", "Elder", "Moss", "Fern", "Lark", "Oak", "Pebble", "Bramble",
	"Juniper", "Marrow", "Kettle", "Lantern", "Willow", "Heron", "Clover", "Amber", "Tallow", "Rook", "Sorrel"]
const NAME_B := ["mere", "wick", "ford", "brook", "stead", "holm", "haven", "dale", "well", "cross", "bury", "field", "combe", "hollow", "by", "ton"]

var name := ""
var center := Vector3.ZERO
var buildings: Array = []
var residents: Array = []
var by_id := {}
var decor: Array = []
var rng := RandomNumberGenerator.new()
var road_angles: Array = []

static func town_name() -> String:
	var r := RandomNumberGenerator.new()
	r.seed = Game.hash_ints(int(Game.world.get("seed", 1)), 7171)
	return NAME_A[r.randi() % NAME_A.size()] + NAME_B[r.randi() % NAME_B.size()]

func generate(g: OverworldGen) -> void:
	name = town_name()
	rng.seed = Game.hash_ints(g.seed_value, 4242)
	center = Vector3(g.town_center.x, g.town_h, g.town_center.y)
	var farm_gate := Vector2(g.farm_rect.position.x if g.town_center.x < g.farm_rect.get_center().x else g.farm_rect.end.x, g.farm_rect.get_center().y)
	road_angles = [_angle_to(g.town_center, farm_gate), _angle_to(g.town_center, g.cave_pos)]
	_layout(g)
	_people()
	var extra := int(Game.world.get("town", {}).get("newcomers", 0))
	for i in extra:
		add_newcomer(i)

func _angle_to(a: Vector2, b: Vector2) -> float:
	return atan2(b.y - a.y, b.x - a.x)

func _near_road(ang: float, tol: float) -> bool:
	for ra in road_angles:
		if abs(wrapf(ang - ra, -PI, PI)) < tol:
			return true
	return false

func _layout(g: OverworldGen) -> void:
	var inner_slots: Array = []
	var n_in := 11
	var off := rng.randf() * TAU
	for i in n_in:
		var a := off + TAU * i / n_in
		if not _near_road(a, deg_to_rad(17)):
			inner_slots.append(a)
	var outer_slots: Array = []
	for i in n_in:
		var a2 := off + TAU * (i + 0.5) / n_in
		if not _near_road(a2, deg_to_rad(13)):
			outer_slots.append(a2)
	var roles := SHOP_ROLES.duplicate()
	roles.append("curio_hall")
	for i in inner_slots.size():
		var role: String = roles[i] if i < roles.size() else "house"
		buildings.append(_building("b%d" % i, role, inner_slots[i], R_INNER, g))
	for i in outer_slots.size():
		buildings.append(_building("h%d" % i, "house", outer_slots[i], R_OUTER, g))
	# trees, benches, flower beds, crates
	for i in 14:
		var a3 := rng.randf() * TAU
		var r := rng.randf_range(R_OUTER + 6.0, R_OUTER + 10.0)
		if _near_road(a3, deg_to_rad(10)):
			continue
		decor.append({"k": "tree", "p": _ring_point(a3, r), "r": rng.randf() * TAU, "v": rng.randi() % 4})
	for i in 4:
		var a4 := TAU * (i + 0.5) / 4.0 + off * 0.3
		decor.append({"k": "bench", "p": _ring_point(a4, PLAZA_R + 1.2), "r": -a4 - PI / 2.0})
	for b in buildings:
		if b["role"] in SHOP_ROLES and b["role"] != "mayor":
			var side := Vector3(cos(b["yaw"]), 0, -sin(b["yaw"]))
			decor.append({"k": "crate", "p": b["front"] + side * (b["w"] / 2.0 + 0.3) - b["fwd"] * 1.2, "r": rng.randf() * TAU})

func _ring_point(a: float, r: float) -> Vector3:
	return center + Vector3(cos(a) * r, 0, sin(a) * r)

func _building(id: String, role: String, ang: float, r: float, g: OverworldGen) -> Dictionary:
	var pos := _ring_point(ang, r)
	var to_center := (center - pos).normalized()
	var yaw := atan2(to_center.x, to_center.z)
	var w := rng.randf_range(6.5, 8.5) if role != "house" else rng.randf_range(5.5, 7.0)
	var d := rng.randf_range(5.0, 6.0)
	var floors := 2 if role in ["mayor", "innkeeper", "merchant"] or rng.randf() < 0.25 else 1
	if role == "curio_hall":
		w = 9.0
		floors = 1
	var b := {
		"id": id, "role": role, "pos": pos, "yaw": yaw, "w": w, "d": d, "floors": floors, "ang": ang,
		"wall": Props.WALL_COLORS[rng.randi() % Props.WALL_COLORS.size()],
		"roof": Props.ROOF_COLORS[rng.randi() % Props.ROOF_COLORS.size()],
		"style": rng.randi() % 3 if role != "mayor" else 1,
		"timber": rng.randf() < 0.5,
		"door_x": rng.randf_range(-0.8, 0.8) if role != "house" else rng.randf_range(-1.5, 1.5),
		"seed": rng.randi(),
		"fwd": to_center,
		"reserved": role in ["curio_hall"] or false,
		"residents": [],
	}
	if b["style"] == 2 and floors == 1:
		b["style"] = 0
	b["door"] = pos + Basis(Vector3.UP, yaw) * Vector3(b["door_x"], 0, d / 2.0)
	b["front"] = pos + Basis(Vector3.UP, yaw) * Vector3(b["door_x"], 0, d / 2.0 + 1.6)
	b["counter"] = pos + Basis(Vector3.UP, yaw) * Vector3(b["door_x"] - 1.6, 0, d / 2.0 + 2.3)
	for k in ["door", "front", "counter"]:
		var v: Vector3 = b[k]
		v.y = g.h_at(v.x, v.z)
		b[k] = v
	pos.y = g.h_at(pos.x, pos.z)
	b["pos"] = pos
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

# ------------------------------------------------------------------ people

## Deterministic shuffle (the global shuffle() would differ between players).
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t

func _pick(arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]

func _new_person(first: String, last: String, age: String) -> Dictionary:
	var look := Doll.random_look(rng)
	look["child"] = age == "child"
	if age == "elder":
		look["hair"] = [Color("d8d8d8"), Color("f0f0f0"), Color("a8a8a8")][rng.randi() % 3]
		look["hair_style"] = [0, 3, 6][rng.randi() % 3]
	if age == "child":
		look["beard"] = false
		look["height"] = rng.randf_range(0.95, 1.05)
	var traits := []
	while traits.size() < 2:
		var t: String = _pick(TRAITS)
		if not traits.has(t):
			traits.append(t)
	var p := {
		"id": "npc%d" % residents.size(), "first": first, "last": last, "name": "%s %s" % [first, last],
		"age": age, "role": "child" if age == "child" else ("elder" if age == "elder" else ""), "traits": traits,
		"interests": [], "loves": [], "likes": [], "dislikes": [], "family": {}, "friends": [], "rival": "",
		"look": look, "home": "", "work": "", "birthday": [rng.randi() % 4, rng.randi_range(1, 14)], "arrived": 0,
		"voice_seed": rng.randi(),
	}
	residents.append(p)
	by_id[p["id"]] = p
	return p

func _first_name(used: Dictionary) -> String:
	for i in 50:
		var f: String = _pick(FIRST)
		if not used.has(f):
			used[f] = true
			return f
	return _pick(FIRST)

func _people() -> void:
	var used := {}
	var houses: Array = []
	for b in buildings:
		if b["role"] == "house":
			houses.append(b)
	var adults: Array = []
	var hh_types := ["couple_kids", "single_parent", "elder_family", "siblings", "couple", "single", "single", "elder", "couple_kids", "single"]
	var hi := 0
	var total := 0
	var households: Array = []
	while hi < houses.size() - 2 and (adults.size() < 9 or total < 13) and total < 18:
		var t: String = hh_types[rng.randi() % hh_types.size()] if hi > 1 else ["couple_kids", "elder_family"][hi]
		var last: String = _pick(LAST)
		var members: Array = []
		match t:
			"couple_kids":
				var a := _new_person(_first_name(used), last, "adult")
				var b := _new_person(_first_name(used), last, "adult")
				_link(a, b, "spouse")
				members.append_array([a, b])
				for k in rng.randi_range(1, 2):
					var c := _new_person(_first_name(used), last, "child")
					_child_of(c, [a, b])
					_link(a, c, "child")
					_link(b, c, "child")
					members.append(c)
			"single_parent":
				var a2 := _new_person(_first_name(used), last, "adult")
				var c2 := _new_person(_first_name(used), last, "child")
				_child_of(c2, [a2])
				_link(a2, c2, "child")
				members.append_array([a2, c2])
			"elder_family":
				var e := _new_person(_first_name(used), last, "elder")
				var a3 := _new_person(_first_name(used), last, "adult")
				var c3 := _new_person(_first_name(used), last, "child")
				_link(e, a3, "child")
				_link(a3, c3, "child")
				_link(e, c3, "grandchild")
				_child_of(c3, [a3])
				members.append_array([e, a3, c3])
			"siblings":
				var a4 := _new_person(_first_name(used), last, "adult")
				var b4 := _new_person(_first_name(used), last, "adult")
				_link(a4, b4, "sibling")
				b4["look"]["hair"] = a4["look"]["hair"]
				members.append_array([a4, b4])
			"couple":
				var a5 := _new_person(_first_name(used), last, "adult")
				var b5 := _new_person(_first_name(used), _pick(LAST), "adult")
				_link(a5, b5, "spouse")
				members.append_array([a5, b5])
			"single":
				members.append(_new_person(_first_name(used), last, "adult"))
			"elder":
				members.append(_new_person(_first_name(used), last, "elder"))
		var house: Dictionary = houses[hi]
		for m in members:
			m["home"] = house["id"]
			house["residents"].append(m["id"])
			if m["age"] == "adult":
				adults.append(m)
		households.append(members)
		total += members.size()
		hi += 1
	for j in range(hi, houses.size()):
		houses[j]["reserved"] = true
		houses[j]["role"] = "lot"
	# key jobs
	_shuffle(adults)
	var idx := 0
	for role in SHOP_ROLES:
		if idx >= adults.size():
			break
		var p: Dictionary = adults[idx]
		p["role"] = role
		p["work"] = building_for_role(role).get("id", "")
		idx += 1
	var other_jobs := ["farmer", "teacher", "musician", "scholar", "tailor", "beekeeper", "baker", "courier", "painter", "guard"]
	for p in residents:
		if p["role"] == "":
			p["role"] = _pick(other_jobs)
		elif p["role"] == "elder" and rng.randf() < 0.5:
			p["role"] = "miner"
	for p in residents:
		_give_tastes(p)
	# friendships across households, the occasional rivalry
	for p in residents:
		var tries := 0
		while p["friends"].size() < 2 and tries < 10:
			tries += 1
			var q: Dictionary = _pick(residents)
			if q["id"] == p["id"] or q["home"] == p["home"] or p["friends"].has(q["id"]):
				continue
			if (p["age"] == "child") != (q["age"] == "child") and rng.randf() < 0.8:
				continue
			p["friends"].append(q["id"])
			if not q["friends"].has(p["id"]):
				q["friends"].append(p["id"])
		if p["rival"] == "" and rng.randf() < 0.18 and p["age"] != "child":
			var r: Dictionary = _pick(residents)
			if r["id"] != p["id"] and r["home"] != p["home"] and not p["friends"].has(r["id"]) and r["age"] != "child":
				p["rival"] = r["id"]
				r["rival"] = p["id"]

func _link(a: Dictionary, b: Dictionary, rel: String) -> void:
	match rel:
		"spouse":
			a["family"]["spouse"] = b["id"]
			b["family"]["spouse"] = a["id"]
		"child":
			if not a["family"].has("children"):
				a["family"]["children"] = []
			a["family"]["children"].append(b["id"])
			if not b["family"].has("parents"):
				b["family"]["parents"] = []
			b["family"]["parents"].append(a["id"])
		"grandchild":
			if not a["family"].has("grandchildren"):
				a["family"]["grandchildren"] = []
			a["family"]["grandchildren"].append(b["id"])
			b["family"]["grandparent"] = a["id"]
		"sibling":
			a["family"]["sibling"] = b["id"]
			b["family"]["sibling"] = a["id"]

func _child_of(c: Dictionary, parents: Array) -> void:
	var p: Dictionary = parents[rng.randi() % parents.size()]
	c["look"]["hair"] = p["look"]["hair"]
	c["look"]["skin"] = parents[rng.randi() % parents.size()]["look"]["skin"]

func _give_tastes(p: Dictionary) -> void:
	var job_interest: String = ROLE_INFO.get(p["role"], {}).get("interest", "")
	var ints: Array = []
	if job_interest != "" and rng.randf() < 0.5:
		ints.append(job_interest)
	while ints.size() < 2:
		var i: String = _pick(INTERESTS)
		if not ints.has(i):
			ints.append(i)
	p["interests"] = ints
	var pool: Array = []
	for i in ints:
		pool.append_array(INTEREST_ITEMS.get(i, []))
	_shuffle(pool)
	var rare := pool.duplicate()
	rare.sort_custom(func(a, b): return Items.def(a)["price"] > Items.def(b)["price"])
	p["loves"] = [rare[rng.randi() % min(3, rare.size())]]
	var likes: Array = []
	for it in pool:
		if likes.size() >= 4:
			break
		if not likes.has(it) and not p["loves"].has(it):
			likes.append(it)
	p["likes"] = likes
	var dis := ["junk", "monster", "fish", "mushroom", "ore", "bait"]
	_shuffle(dis)
	for c in dis:
		var clash := false
		for it in pool:
			if Items.cat_of(it) == c:
				clash = true
		if not clash:
			p["dislikes"].append(c)
		if p["dislikes"].size() >= 2:
			break
	p["wish"] = WISHES.get(ints[0], "heartstone")

## A new resident arriving thanks to the town's growth.
func add_newcomer(k: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = Game.hash_ints(int(Game.world.get("seed", 1)), 9393, k)
	var saved := rng.seed
	rng.seed = r.seed
	var used := {}
	for p in residents:
		used[p["first"]] = true
	var p := _new_person(_first_name(used), _pick(LAST), "adult")
	p["role"] = ["explorer", "glassblower", "historian", "chef", "stargazer", "herder", "painter", "musician"][k % 8]
	_give_tastes(p)
	var lot := {}
	for b in buildings:
		if b["role"] == "lot":
			lot = b
			break
	if not lot.is_empty():
		lot["role"] = "house"
		lot["residents"].append(p["id"])
		p["home"] = lot["id"]
	else:
		p["home"] = residents[0]["home"]
	p["arrived"] = 1 + k
	p["friends"] = [residents[rng.randi() % residents.size()]["id"]]
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
