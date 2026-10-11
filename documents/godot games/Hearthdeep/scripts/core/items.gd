extends Node
## Item database: every item, crop, fish, recipe and trait in the game.
## Item instances are plain dictionaries: {"id": String, "n": int, "d": Dictionary (optional)}.

const ESSENCES := ["vigor", "earth", "tide", "lumen", "zephyr", "ward", "verdant"]
const ESSENCE_COLORS := {
	"vigor": Color("e0524a"), "earth": Color("a8743f"), "tide": Color("3f8fd8"),
	"lumen": Color("f2d04b"), "zephyr": Color("d8eef0"), "ward": Color("8c8fa3"),
	"verdant": Color("5cbf4a"),
}
const ESSENCE_NAMES := {
	"vigor": "Vigor", "earth": "Earth", "tide": "Tide", "lumen": "Lumen",
	"zephyr": "Zephyr", "ward": "Ward", "verdant": "Verdant",
}
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const TOOL_TIERS := ["Rusty", "Copper", "Iron", "Gold", "Starmetal"]
const WEAPON_TIERS := ["Wooden", "Copper", "Iron", "Silver", "Gold", "Starmetal"]
const TIER_COLORS := [Color("8a6a4a"), Color("c8743a"), Color("a9a9b0"), Color("dfe6ee"), Color("f2c94c"), Color("8a7dff")]
const BAR_FOR_TIER := ["", "copper_bar", "iron_bar", "silver_bar", "gold_bar", "starmetal_bar"]

var defs := {}          # id -> definition dictionary
var crops := {}         # product id -> crop growth data
var fish := {}          # fish id -> fishing data
var traits := {}        # trait id -> {name, desc, slots}
var craft_recipes := [] # workbench recipes
var cook_recipes := []  # stove / campfire dishes
var beverage_recipes := []
var smelt := {}         # ore id -> bar id
var brew_specials := {} # "primary+secondary" -> brew id
var shop_tables := {}   # shop id -> Array of stock entries

func _init() -> void:
	_build_traits()
	_build_materials()
	_build_minerals()
	_build_crops()
	_build_forage()
	_build_fish()
	_build_monster_drops()
	_build_brews()
	_build_food()
	_build_tools()
	_build_weapons()
	_build_gear()
	_build_placeables()
	_build_curios()
	_build_misc()
	_build_recipes()
	_build_shops()

# ---------------------------------------------------------------- helpers

func _add(id: String, nm: String, cat: String, price: int, icon: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "name": nm, "cat": cat, "price": price, "icon": icon, "stack": 99, "desc": "", "known": false}
	for k in extra:
		d[k] = extra[k]
	defs[id] = d
	return d

func has(id: String) -> bool:
	return defs.has(id)

func def(id: String) -> Dictionary:
	return defs.get(id, {"id": id, "name": id.capitalize(), "cat": "misc", "price": 0, "icon": ["box", Color.MAGENTA], "stack": 99, "desc": ""})

func make(id: String, n: int = 1, d: Dictionary = {}) -> Dictionary:
	var it := {"id": id, "n": n}
	if not d.is_empty():
		it["d"] = d
	return it

func stack_max(id: String) -> int:
	return int(def(id).get("stack", 99))

func can_stack(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if a["id"] != b["id"]:
		return false
	if stack_max(a["id"]) <= 1:
		return false
	return not a.has("d") and not b.has("d")

func display_name(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	if it.has("d") and it["d"].has("nm"):
		return it["d"]["nm"]
	return def(it["id"]).get("name", it["id"])

func item_traits(it: Dictionary) -> Array:
	var out: Array = []
	for t in def(it["id"]).get("traits", []):
		out.append(t)
	if it.has("d"):
		for t in it["d"].get("tr", []):
			if not out.has(t):
				out.append(t)
	return out

func sell_price(it: Dictionary) -> int:
	var base := int(def(it["id"]).get("price", 0))
	var tr = item_traits(it).size() - def(it["id"]).get("traits", []).size()
	return int(base * (1.0 + 0.35 * tr))

func buy_price(id: String) -> int:
	var d := def(id)
	if d.has("buy"):
		return int(d["buy"])
	return max(1, int(d.get("price", 1)) * 2 + 2)

func cat_of(id: String) -> String:
	return def(id).get("cat", "misc")

func essences_of(id: String) -> Dictionary:
	return def(id).get("ess", {})

func is_edible(id: String) -> bool:
	return def(id).has("food")

func season_name(i: int) -> String:
	return SEASONS[posmod(i, 4)]

# ---------------------------------------------------------------- traits

func _trait(id: String, nm: String, desc: String, slots: Array) -> void:
	traits[id] = {"id": id, "name": nm, "desc": desc, "slots": slots}

func _build_traits() -> void:
	_trait("delver", "Delver's", "+25% damage underground", ["weapon"])
	_trait("homebody", "Homebody's", "+20% damage on the surface", ["weapon"])
	_trait("keen", "Keen", "+12% critical hit chance", ["weapon", "trinket"])
	_trait("brutal", "Brutal", "+10% damage and much stronger knockback", ["weapon"])
	_trait("quickdraw", "Quick", "Attacks 15% faster", ["weapon", "trinket"])
	_trait("reach", "Long", "+20% attack reach", ["weapon"])
	_trait("leeching", "Leeching", "Heal 2 health on every hit", ["weapon", "trinket"])
	_trait("ember", "Ember", "Hits set creatures ablaze", ["weapon"])
	_trait("frost", "Frostbitten", "Hits slow creatures", ["weapon"])
	_trait("scavenger", "Scavenger's", "Creatures drop extra materials", ["weapon", "trinket"])
	_trait("swift", "Swift", "+12% movement speed", ["boots", "trinket", "hat"])
	_trait("featherstep", "Featherstep", "Dodge rolls travel further and recover faster", ["boots"])
	_trait("stalwart", "Stalwart", "Take 15% less damage", ["hat", "boots", "trinket"])
	_trait("hearty", "Hearty", "+25 maximum health", ["hat", "trinket", "boots"])
	_trait("prospector", "Prospector's", "20% chance to mine double ore", ["pick", "trinket", "hat"])
	_trait("woodsman", "Woodsman's", "Trees fall faster and drop extra wood", ["axe", "trinket"])
	_trait("angler", "Angler's", "Fish bite sooner and the catch zone is larger", ["rod", "hat", "trinket"])
	_trait("lucky", "Lucky", "Treasure turns up more often", ["rod", "trinket", "hat", "weapon"])
	_trait("glowing", "Glowing", "Shines brighter underground (+40% light)", ["hat", "trinket", "weapon", "pick"])
	_trait("greenthumb", "Greenthumb", "Watered crops sometimes grow an extra day", ["can", "hat", "trinket"])
	_trait("gourmand", "Gourmand's", "Food and brews restore 30% more", ["trinket", "hat"])
	_trait("steady", "Steady", "The catch meter drains more slowly", ["rod", "trinket"])

func trait_slots_for(id: String) -> String:
	var d := def(id)
	if d.has("weapon"):
		return "weapon"
	if d.has("gear"):
		return d["gear"]["slot"]
	if d.has("tool"):
		return d["tool"]["kind"]
	return ""

func random_traits(id: String, rng: RandomNumberGenerator, count: int) -> Array:
	var slot := trait_slots_for(id)
	var pool: Array = []
	for t in traits:
		if traits[t]["slots"].has(slot):
			pool.append(t)
	var out: Array = []
	for i in count:
		if pool.is_empty():
			break
		var pick: String = pool[rng.randi() % pool.size()]
		pool.erase(pick)
		out.append(pick)
	return out

func traited_name(id: String, tr: Array) -> String:
	var base: String = def(id)["name"]
	if tr.is_empty():
		return base
	return "%s %s" % [traits[tr[0]]["name"], base]

# ---------------------------------------------------------------- materials

func _build_materials() -> void:
	_add("wood", "Wood", "material", 2, ["log", Color("9a6b3f"), Color("d9b27a")], {"known": true, "desc": "Sturdy timber for building almost anything."})
	_add("hardwood", "Hardwood", "material", 10, ["log", Color("5e3a22"), Color("a8774a")], {"desc": "Dense, dark wood from old trees and stumps."})
	_add("stone", "Stone", "material", 1, ["stone", Color("9a9a96")], {"known": true, "desc": "Common stone. Paths, furnaces, foundations."})
	_add("fiber", "Fiber", "material", 1, ["fiber", Color("8fae4a")], {"known": true, "desc": "Tough plant fiber from weeds and grass."})
	_add("clay", "Clay", "material", 3, ["clay", Color("c07a52")], {"desc": "Soft riverbank clay. Kilns and pots love it."})
	_add("coal", "Coal", "material", 6, ["ore", Color("2b2b2e"), Color("55555c")], {"ess": {"earth": 1}, "desc": "Burns hot. Smelting fuel."})
	_add("sap", "Sap", "material", 2, ["drop", Color("c98a2a")], {"desc": "Sticky tree sap."})
	_add("flint", "Flint", "material", 3, ["stone", Color("4a4b55")], {"desc": "Sharp stone, good for arrowheads."})
	_add("hay", "Hay", "material", 1, ["fiber", Color("d8c06a")], {"desc": "Dried grass. Animals adore it."})
	_add("bone", "Old Bone", "material", 6, ["bone", Color("e9e2cf")], {"desc": "Bleached and old. Something lived down there once."})
	_add("feed", "Animal Feed", "material", 4, ["bag", Color("d8b45c"), Color("8a6a3c")], {"buy": 20, "desc": "Mixed grain. Keeps the coop happy and laying."})
	_add("worm", "Worm", "bait", 2, ["worm", Color("d9857a")], {"known": true, "bait": {"bite": 0.8, "rare": 0.0}, "desc": "Wriggly bait. Fish find it irresistible."})

func _build_minerals() -> void:
	var ores := [
		["copper", "Copper", 5, Color("c8743a")], ["iron", "Iron", 10, Color("b9b4ae")],
		["silver", "Silver", 18, Color("dfe6ee")], ["gold", "Gold", 30, Color("f2c94c")],
		["starmetal", "Starmetal", 60, Color("8a7dff")],
	]
	for o in ores:
		_add(o[0] + "_ore", o[1] + " Ore", "ore", o[2], ["ore", Color("6a625a"), o[3]], {"desc": "Raw %s ore. Smelt it in a furnace with coal." % o[1].to_lower(), "known": o[0] == "copper"})
		_add(o[0] + "_bar", o[1] + " Bar", "bar", o[2] * 6, ["bar", o[3]], {"desc": "A refined %s bar for tools and equipment." % o[1].to_lower(), "known": true})
		smelt[o[0] + "_ore"] = o[0] + "_bar"
	_add("crystal_shard", "Crystal Shard", "mineral", 12, ["crystal", Color("9fe3ff")], {"ess": {"lumen": 1, "ward": 1}, "desc": "A shard that hums faintly when held."})
	_add("obsidian", "Obsidian", "mineral", 28, ["gem", Color("2a1a3a"), Color("6a4a8a")], {"ess": {"ward": 2}, "desc": "Volcanic glass from the Ember Rift."})
	_add("geode", "Geode", "mineral", 20, ["stone", Color("8f8678"), Color("b48cff")], {"desc": "Something rattles inside. The blacksmith can crack it open."})
	_add("quartz", "Quartz", "gem", 15, ["gem", Color("f4f2ea")], {"ess": {"lumen": 1}, "desc": "Clear and bright."})
	_add("amethyst", "Amethyst", "gem", 45, ["gem", Color("a46be0")], {"ess": {"zephyr": 1, "lumen": 1}})
	_add("topaz", "Topaz", "gem", 60, ["gem", Color("f2a93b")], {"ess": {"vigor": 1, "lumen": 1}})
	_add("aquamarine", "Aquamarine", "gem", 80, ["gem", Color("5fd6d0")], {"ess": {"tide": 2}})
	_add("ruby", "Ruby", "gem", 120, ["gem", Color("d63a4a")], {"ess": {"vigor": 2}})
	_add("emerald", "Emerald", "gem", 120, ["gem", Color("2fbf6a")], {"ess": {"verdant": 2}})
	_add("heartstone", "Heartstone", "gem", 450, ["gem", Color("ff6fae"), Color("ffd0e6")], {"ess": {"vigor": 2, "lumen": 2, "ward": 2}, "desc": "Warm to the touch, and it seems to beat. Found only in the deepest halls."})

# ---------------------------------------------------------------- crops

## stages: days per stage (4 growth stages before mature). regrow: days after harvest (0 = single harvest).
func _crop(id: String, nm: String, seasons: Array, stages: Array, regrow: int, price: int, seed_price: int, icon: Array, model: String, extra: Dictionary = {}) -> void:
	var cat: String = extra.get("cat", "crop")
	var item_extra := {"desc": extra.get("desc", ""), "known": extra.get("known", false)}
	if extra.has("ess"):
		item_extra["ess"] = extra["ess"]
	if extra.has("food"):
		item_extra["food"] = extra["food"]
	_add(id, nm, cat, price, icon, item_extra)
	var seed_name: String = extra.get("seed_name", nm + " Seeds")
	var seed_icon := ["seed", icon[1], Color("e9dcb4")]
	var total := 0
	for s in stages:
		total += int(s)
	var names: Array = []
	for s in seasons:
		names.append(SEASONS[s])
	var season_txt := ", ".join(PackedStringArray(names))
	if extra.get("perennial", false):
		season_txt = "any season (hardy)"
	_add(id + "_seeds", seed_name, "seed", max(1, seed_price / 2), seed_icon, {
		"seed": id, "buy": seed_price, "known": true,
		"desc": "Grows in %s. Matures in %d days.%s" % [season_txt, total, (" Keeps producing every %d days." % regrow) if regrow > 0 else ""],
	})
	crops[id] = {"id": id, "seasons": seasons, "stages": stages, "total": total, "regrow": regrow,
		"model": model, "color": icon[1], "perennial": extra.get("perennial", false), "seed": id + "_seeds",
		"yield": extra.get("yield", [1, 1])}

func _build_crops() -> void:
	var F := func(h: int) -> Dictionary: return {"heal": h}
	_crop("turnip", "Turnip", [0], [1, 1, 1, 1], 0, 35, 20, ["round", Color("e9dfe6"), Color("b0508a")], "bulb", {"food": F.call(10), "known": true, "desc": "Crisp and peppery."})
	_crop("potato", "Potato", [0], [1, 2, 1, 2], 0, 60, 30, ["round", Color("c9a46a")], "bush", {"food": F.call(12), "yield": [1, 3], "known": true})
	_crop("carrot", "Carrot", [0], [1, 1, 2, 1], 0, 45, 25, ["long", Color("ef8a2c"), Color("5aa83a")], "bulb", {"food": F.call(10), "known": true})
	_crop("strawberry", "Strawberry", [0], [2, 2, 2, 2], 4, 60, 70, ["berry", Color("e2384a")], "bush", {"food": F.call(12)})
	_crop("tomato", "Tomato", [1], [2, 2, 3, 2], 4, 50, 40, ["round", Color("e0442f")], "vine", {"food": F.call(12)})
	_crop("corn", "Corn", [1, 2], [2, 3, 3, 4], 4, 40, 50, ["long", Color("f2d24a"), Color("6aa83a")], "stalk", {"food": F.call(10)})
	_crop("melon", "Melon", [1], [3, 3, 3, 3], 0, 200, 80, ["gourd", Color("7fc25a"), Color("3f8a3a")], "gourd", {"food": F.call(30)})
	_crop("hops", "Hops", [1], [2, 3, 3, 2], 1, 25, 60, ["berry", Color("a8d65a")], "vine", {"desc": "Bitter cones. Brewers want them for ale."})
	_crop("blueberry", "Blueberry", [1], [3, 3, 3, 3], 4, 40, 80, ["berry", Color("4a5fd0")], "bush", {"food": F.call(10), "yield": [2, 4]})
	_crop("pumpkin", "Pumpkin", [2], [3, 3, 3, 4], 0, 250, 100, ["gourd", Color("ef8a2c"), Color("5a8a3a")], "gourd", {"food": F.call(25)})
	_crop("wheat", "Wheat", [1, 2], [1, 1, 1, 1], 0, 25, 10, ["grain", Color("e3c26a")], "stalk", {"known": true, "desc": "For bread, pies and ale."})
	_crop("cranberry", "Cranberries", [2], [2, 2, 2, 1], 5, 60, 120, ["berry", Color("b3243a")], "bush", {"food": F.call(10), "yield": [2, 3]})
	_crop("beet", "Beet", [2], [1, 2, 2, 1], 0, 70, 30, ["round", Color("8a2448"), Color("4a8a3a")], "bulb", {"food": F.call(12)})
	_crop("frostleek", "Frostleek", [3], [2, 2, 2, 2], 0, 90, 60, ["long", Color("dff2f0"), Color("6ac0a8")], "bulb", {"food": F.call(14), "desc": "The only crop stubborn enough to grow in winter."})
	# Herbs (brewing ingredients)
	_crop("mint", "Mint", [0, 1], [1, 2, 1, 1], 3, 22, 30, ["herb", Color("6fd08a")], "herb", {"cat": "herb", "ess": {"zephyr": 2}, "seed_name": "Mint Cuttings"})
	_crop("sageleaf", "Sageleaf", [0, 2], [1, 2, 2, 1], 3, 26, 35, ["herb", Color("9fb08a")], "herb", {"cat": "herb", "ess": {"ward": 2}, "seed_name": "Sageleaf Seeds"})
	_crop("emberroot", "Emberroot", [1, 2], [2, 2, 2, 1], 0, 40, 40, ["long", Color("d8452f"), Color("8a5a3a")], "bulb", {"cat": "herb", "ess": {"vigor": 2}})
	_crop("stonewort", "Stonewort", [0, 1, 2], [2, 1, 2, 1], 0, 32, 35, ["herb", Color("8a7a5a")], "herb", {"cat": "herb", "ess": {"earth": 2}})
	_crop("silverreed", "Silverreed", [0, 1], [1, 2, 2, 1], 3, 30, 40, ["herb", Color("bcd8e8")], "reed", {"cat": "herb", "ess": {"tide": 2}})
	_crop("sunpetal", "Sunpetal", [1], [2, 2, 2, 1], 3, 36, 45, ["flower", Color("f6cf3a"), Color("8a5a2a")], "flower", {"cat": "herb", "ess": {"lumen": 2}})
	_crop("mossbloom", "Mossbloom", [0, 2], [1, 2, 2, 1], 3, 30, 40, ["flower", Color("7ad06a"), Color("e8f2a0")], "flower", {"cat": "herb", "ess": {"verdant": 2}})
	# Rare plants brought up from the deep - hardy perennials that grow in any season.
	_crop("glowcap", "Glowcap", [0, 1, 2, 3], [2, 2, 1, 1], 3, 55, 0, ["mushroom", Color("7fe3ff"), Color("e8fbff")], "glowshroom", {"cat": "herb", "ess": {"lumen": 3}, "perennial": true, "seed_name": "Glowcap Spores", "desc": "A mushroom that gives off a steady blue light."})
	_crop("crystalbloom", "Crystalbloom", [0, 1, 2, 3], [3, 3, 2, 2], 5, 110, 0, ["flower", Color("b4e8ff"), Color("ffffff")], "crystalflower", {"cat": "herb", "ess": {"ward": 2, "lumen": 1}, "perennial": true, "seed_name": "Crystalbloom Bulb"})
	_crop("deepmoss", "Deepmoss", [0, 1, 2, 3], [1, 2, 1, 1], 2, 45, 0, ["herb", Color("3f9a6a"), Color("7fe3b0")], "herb", {"cat": "herb", "ess": {"verdant": 2, "tide": 1}, "perennial": true, "seed_name": "Deepmoss Clump"})
	_crop("emberlily", "Emberlily", [0, 1, 2, 3], [3, 2, 2, 2], 4, 130, 0, ["flower", Color("ff6a2a"), Color("ffd34a")], "flower", {"cat": "herb", "ess": {"vigor": 3}, "perennial": true, "seed_name": "Emberlily Bulb"})
	_crop("ghostbloom", "Ghostbloom", [0, 1, 2, 3], [3, 2, 2, 1], 4, 120, 0, ["flower", Color("e8e4ff"), Color("9a8aff")], "flower", {"cat": "herb", "ess": {"zephyr": 2, "lumen": 1}, "perennial": true, "seed_name": "Ghostbloom Seed"})
	_crop("starfern", "Starfern", [0, 1, 2, 3], [4, 4, 3, 3], 7, 320, 0, ["herb", Color("6a5fd8"), Color("fff2a0")], "herb", {"cat": "herb", "ess": {"vigor": 1, "earth": 1, "tide": 1, "lumen": 1, "zephyr": 1, "ward": 1, "verdant": 1}, "perennial": true, "seed_name": "Starfern Spore", "desc": "Every essence at once. Nobody in town has seen one."})
	# Fruit trees (planted as saplings)
	for fr in [["apple", "Apple", 2, Color("d8402f")], ["cherry", "Cherry", 0, Color("b0203a")], ["peach", "Peach", 1, Color("f6a26a")]]:
		_add(fr[0], fr[1], "fruit", 40 if fr[0] != "peach" else 60, ["round", fr[3], Color("4a8a3a")], {"food": {"heal": 14}})
		_add(fr[0] + "_sapling", fr[1] + " Sapling", "sapling", 150, ["sapling", Color("6aa83a"), fr[3]], {"buy": 600, "known": true, "place": {"obj": "fruit_tree", "fruit": fr[0], "season": fr[2], "outdoor": true},
			"desc": "Plant on the farm. Grows into a tree in 14 days, then bears fruit every %s." % SEASONS[fr[2]]})
	_add("lumenfruit", "Lumenfruit", "fruit", 140, ["round", Color("fff2a0"), Color("7fe3ff")], {"food": {"heal": 30, "buff": {"type": "light", "mag": 0.5, "dur": 240.0}}, "ess": {"lumen": 2, "vigor": 1}, "desc": "Glows softly. Eating it makes your eyes adjust to the dark."})
	_add("lumenfruit_sapling", "Lumenfruit Sapling", "sapling", 400, ["sapling", Color("7fe3ff"), Color("fff2a0")], {"place": {"obj": "fruit_tree", "fruit": "lumenfruit", "season": -1, "outdoor": true}, "desc": "A pale tree from the deep. It fruits in every season."})

func _build_forage() -> void:
	_add("wild_leek", "Wild Leek", "forage", 20, ["long", Color("e8f0d0"), Color("6ab04a")], {"food": {"heal": 8}})
	_add("dandelion", "Dandelion", "forage", 12, ["flower", Color("f6d23a")], {"ess": {"vigor": 1}, "food": {"heal": 5}})
	_add("fiddlehead", "Fiddlehead", "forage", 25, ["herb", Color("6aa83a")], {"ess": {"verdant": 1}, "food": {"heal": 8}})
	_add("morel", "Morel", "mushroom", 50, ["mushroom", Color("a8865a"), Color("e8dcc0")], {"ess": {"earth": 1, "vigor": 1}, "food": {"heal": 14}})
	_add("bramble_berry", "Bramble Berries", "forage", 15, ["berry", Color("3a2a5a")], {"food": {"heal": 8}})
	_add("sweet_pea", "Sweet Pea", "forage", 20, ["flower", Color("e89ad0")], {"ess": {"zephyr": 1}})
	_add("honeycomb", "Honeycomb", "forage", 60, ["honey", Color("f2b33a")], {"food": {"heal": 25}, "ess": {"vigor": 1, "lumen": 1}, "desc": "Wild honey from a hollow tree."})
	_add("hazelnut", "Hazelnut", "forage", 25, ["nut", Color("a8743f")], {"food": {"heal": 6}})
	_add("chanterelle", "Chanterelle", "mushroom", 45, ["mushroom", Color("f2a93b"), Color("f6d68a")], {"ess": {"earth": 1, "vigor": 1}, "food": {"heal": 12}})
	_add("wild_plum", "Wild Plum", "forage", 25, ["round", Color("6a3a8a")], {"food": {"heal": 10}})
	_add("winter_root", "Winter Root", "forage", 30, ["long", Color("c8a07a"), Color("8a6a4a")], {"ess": {"earth": 1}, "food": {"heal": 10}})
	_add("holly", "Holly", "forage", 15, ["berry", Color("c0202a"), Color("2a6a3a")], {"ess": {"ward": 1}})
	_add("frost_crocus", "Frost Crocus", "forage", 35, ["flower", Color("b8a8f0")], {"ess": {"zephyr": 1, "lumen": 1}})
	_add("common_mushroom", "Field Mushroom", "mushroom", 15, ["mushroom", Color("d8c8b0"), Color("f0e8dc")], {"ess": {"earth": 1}, "food": {"heal": 8}, "known": true})
	_add("moonshroom", "Moonshroom", "mushroom", 90, ["mushroom", Color("c8d0ff"), Color("ffffff")], {"ess": {"lumen": 2, "zephyr": 1}, "desc": "Only seen under a night sky."})
	_add("feather", "Feather", "forage", 8, ["feather", Color("e8e0d0")], {"ess": {"zephyr": 1}})
	_add("wild_herbs", "Wild Herbs", "forage", 10, ["herb", Color("7ab05a")], {"ess": {"verdant": 1}})
	# Underground plants
	_add("cave_mushroom", "Cave Mushroom", "mushroom", 20, ["mushroom", Color("8a7a6a"), Color("c8b8a0")], {"ess": {"earth": 1}, "food": {"heal": 9}})
	_add("inkcap", "Inkcap", "mushroom", 40, ["mushroom", Color("3a3a4a"), Color("8a8aa0")], {"ess": {"tide": 1, "earth": 1}})
	_add("glowgrub", "Glowgrub", "bait", 8, ["worm", Color("bff26a")], {"bait": {"bite": 0.65, "rare": 0.15}, "desc": "A softly glowing larva. Deep fish go mad for it."})

# ---------------------------------------------------------------- fish

## where: water kinds; seasons: indexes (empty = any); tod: "day", "night", "any"; weather: "any", "rain", "clear"
func _fish(id: String, nm: String, price: int, where: Array, seasons: Array, tod: String, weather: String, diff: int, behavior: String, size: Array, col: Color, extra: Dictionary = {}) -> void:
	var item := {"desc": extra.get("desc", "")}
	if extra.has("ess"):
		item["ess"] = extra["ess"]
	item["food"] = {"heal": 6, "raw": true}
	_add(id, nm, "fish", price, ["fish", col, extra.get("c2", col.lightened(0.35))], item)
	fish[id] = {"id": id, "where": where, "seasons": seasons, "tod": tod, "weather": weather, "diff": diff,
		"behavior": behavior, "size": size, "weight": extra.get("weight", 10), "legend": extra.get("legend", false)}

func _build_fish() -> void:
	_fish("chub", "Chub", 15, ["river"], [], "any", "any", 15, "smooth", [15, 35], Color("8a8f6a"), {"weight": 16})
	_fish("river_trout", "River Trout", 30, ["river"], [0, 1, 2], "day", "any", 30, "dart", [20, 50], Color("8ab07a"), {"c2": Color("e88a8a")})
	_fish("river_perch", "Striped Perch", 25, ["river", "lake"], [2, 3], "any", "any", 25, "smooth", [15, 30], Color("b0a04a"))
	_fish("salmon", "Salmon", 70, ["river"], [2], "any", "any", 50, "mixed", [50, 90], Color("d87a6a"), {"weight": 8})
	_fish("rain_eel", "Rain Eel", 90, ["river", "pond"], [], "night", "rain", 60, "sinker", [40, 80], Color("4a5a6a"), {"weight": 6, "desc": "Comes up to feed only on rainy nights."})
	_fish("icefish", "Icefish", 60, ["river", "lake"], [3], "any", "any", 45, "dart", [15, 30], Color("c8e8f0"))
	_fish("bass", "Lake Bass", 35, ["lake"], [0, 1, 2], "any", "any", 30, "smooth", [25, 60], Color("5a7a4a"))
	_fish("carp", "Carp", 20, ["lake", "pond"], [], "any", "any", 15, "smooth", [30, 70], Color("a88a5a"), {"weight": 14})
	_fish("sunfish", "Sunfish", 18, ["lake", "pond"], [0, 1], "day", "clear", 10, "floater", [10, 20], Color("f2b84a"), {"weight": 14})
	_fish("pike", "Pike", 60, ["lake", "river"], [2, 3], "any", "any", 55, "dart", [50, 110], Color("6a8a5a"))
	_fish("sturgeon", "Lake Sturgeon", 150, ["lake"], [1, 3], "any", "any", 70, "sinker", [90, 180], Color("6a6a7a"), {"weight": 3})
	_fish("moonfin", "Moonfin", 85, ["lake", "pond", "hidden"], [], "night", "any", 50, "floater", [20, 40], Color("c8d8ff"), {"weight": 5, "ess": {"lumen": 1}})
	_fish("pond_loach", "Pond Loach", 15, ["pond"], [], "any", "any", 12, "smooth", [10, 20], Color("8a7a5a"), {"weight": 14})
	_fish("goldfish", "Goldfish", 40, ["pond"], [0, 1], "day", "any", 25, "floater", [5, 15], Color("f28a2a"))
	_fish("bullfrog", "Bullfrog", 30, ["pond", "lake"], [1], "night", "any", 20, "mixed", [10, 20], Color("5a8a3a"), {"desc": "Not a fish, but it took the bait all the same."})
	_fish("ridge_koi", "Ridge Koi", 260, ["hidden"], [], "any", "any", 65, "mixed", [30, 60], Color("f2f0e8"), {"c2": Color("e8502a"), "weight": 4, "desc": "Lives in exactly one pond in the whole world."})
	_fish("hotspring_carp", "Hotspring Carp", 95, ["hot"], [], "any", "any", 40, "floater", [20, 50], Color("e8a07a"), {"ess": {"vigor": 1}})
	_fish("blind_cavefish", "Blind Cavefish", 35, ["cave_earth", "cave_moss"], [], "any", "any", 25, "smooth", [10, 25], Color("e8d8d0"), {"weight": 14})
	_fish("cave_shrimp", "Cave Shrimp", 25, ["cave_earth"], [], "any", "any", 18, "dart", [5, 10], Color("f0a090"), {"weight": 12})
	_fish("glowfin", "Glowfin", 70, ["cave_moss", "cave_crystal"], [], "any", "any", 40, "dart", [15, 30], Color("7fe3d0"), {"ess": {"lumen": 1}})
	_fish("moss_eel", "Moss Eel", 65, ["cave_moss"], [], "any", "any", 45, "sinker", [40, 70], Color("3a6a4a"), {"ess": {"verdant": 1}})
	_fish("crystal_minnow", "Crystal Minnow", 90, ["cave_crystal"], [], "any", "any", 50, "dart", [5, 12], Color("c8f0ff"), {"ess": {"ward": 1}})
	_fish("prismfish", "Prismfish", 160, ["cave_crystal"], [], "any", "any", 65, "mixed", [20, 40], Color("e0b0ff"), {"c2": Color("80f0ff"), "weight": 4, "ess": {"lumen": 2}})
	_fish("spore_loach", "Spore Loach", 80, ["cave_fungal"], [], "any", "any", 45, "smooth", [15, 30], Color("a8b06a"), {"ess": {"verdant": 1}})
	_fish("capfish", "Capfish", 115, ["cave_fungal"], [], "any", "any", 55, "floater", [25, 45], Color("d86a8a"), {"c2": Color("f0e0c0")})
	_fish("magma_eel", "Magma Eel", 210, ["cave_ember"], [], "any", "any", 70, "mixed", [50, 90], Color("ff6a2a"), {"c2": Color("3a1a1a"), "ess": {"vigor": 2}, "desc": "Swims in molten rock. Handle with gloves."})
	_fish("ember_snapper", "Ember Snapper", 165, ["cave_ember"], [], "any", "any", 60, "dart", [30, 50], Color("d84a2a"), {"ess": {"vigor": 1}})
	_fish("abyss_angler", "Abyss Angler", 320, ["cave_ancient"], [], "any", "any", 80, "sinker", [40, 80], Color("2a2a4a"), {"c2": Color("7fe3ff"), "ess": {"lumen": 2}, "weight": 4})
	_fish("coelacanth", "Old Coelacanth", 650, ["cave_ancient"], [], "any", "any", 92, "mixed", [120, 200], Color("4a5a7a"), {"c2": Color("d8c08a"), "weight": 1, "legend": true, "desc": "A living fossil older than the town, older than the river."})

func fish_for(kind: String, season: int, is_night: bool, raining: bool) -> Array:
	var out: Array = []
	for id in fish:
		var f: Dictionary = fish[id]
		if not f["where"].has(kind):
			continue
		if not f["seasons"].is_empty() and not f["seasons"].has(season):
			continue
		if f["tod"] == "day" and is_night:
			continue
		if f["tod"] == "night" and not is_night:
			continue
		if f["weather"] == "rain" and not raining:
			continue
		if f["weather"] == "clear" and raining:
			continue
		out.append(id)
	return out

# ---------------------------------------------------------------- monster drops

func _build_monster_drops() -> void:
	_add("bat_wing", "Bat Wing", "monster", 6, ["wing", Color("5a4a5a")], {"ess": {"zephyr": 1}})
	_add("slime_gel", "Slime Gel", "monster", 5, ["gel", Color("7ad06a")], {"ess": {"verdant": 1, "tide": 1}})
	_add("mole_claw", "Burrower Claw", "monster", 9, ["claw", Color("e8d8c0")], {"ess": {"earth": 1}})
	_add("beetle_shell", "Shellback Plate", "monster", 14, ["shell", Color("3a5a8a")], {"ess": {"ward": 2}})
	_add("spore_sac", "Spore Sac", "monster", 12, ["gel", Color("b8a05a")], {"ess": {"verdant": 1, "earth": 1}})
	_add("golem_core", "Golem Core", "monster", 45, ["core", Color("9fe3ff"), Color("4a5a7a")], {"ess": {"earth": 2, "ward": 1}})
	_add("ember_scale", "Ember Scale", "monster", 38, ["shell", Color("e8502a")], {"ess": {"vigor": 2}})
	_add("ancient_cog", "Ancient Cog", "monster", 65, ["cog", Color("c8a85a")], {"ess": {"ward": 1, "earth": 1}, "desc": "Machined by someone, long ago, for something."})

# ---------------------------------------------------------------- brews

const BREW_INFO := {
	"vigor": {"name": "Mending Draught", "desc": "Restores health over a few seconds.", "buff": "heal"},
	"earth": {"name": "Miner's Draught", "desc": "Mine faster and find more ore.", "buff": "mining"},
	"tide": {"name": "Angler's Tonic", "desc": "Fish bite sooner; the catch zone grows.", "buff": "fishing"},
	"lumen": {"name": "Glowbrew", "desc": "Your light reaches much further underground.", "buff": "light"},
	"zephyr": {"name": "Swiftfoot Tonic", "desc": "Move faster.", "buff": "speed"},
	"ward": {"name": "Stoneskin Tonic", "desc": "Take less damage.", "buff": "defense"},
	"verdant": {"name": "Sprout Elixir", "desc": "Pour on crops (use near the field) to grow everything nearby by a day.", "buff": "grow"},
}
const BREW_TIERS := ["Weak", "", "Strong"]

func _build_brews() -> void:
	for e in ESSENCES:
		var info: Dictionary = BREW_INFO[e]
		for t in 3:
			var id := "brew_%s_%d" % [e, t]
			var nm := ("%s %s" % [BREW_TIERS[t], info["name"]]).strip_edges()
			var mag = [0.6, 1.0, 1.6][t]
			var food := {"heal": 0, "buff": {"type": info["buff"], "mag": mag, "dur": [120.0, 210.0, 330.0][t]}}
			if e == "vigor":
				food = {"heal": int(40 * mag), "buff": {"type": "regen", "mag": mag, "dur": 12.0}}
			if e == "verdant":
				food = {"use": "grow", "radius": [3.0, 5.0, 8.0][t]}
			_add(id, nm, "brew", [30, 60, 110][t] + (20 if e in ["lumen", "verdant"] else 0), ["bottle", ESSENCE_COLORS[e], ESSENCE_COLORS[e].lightened(0.4)],
				{"food": food, "known": true, "desc": info["desc"], "drink": true})
	# Special two-essence brews
	var sp := [
		["earth", "lumen", "brew_prospector", "Prospector's Lamp Oil", "Ore glows through the dark; mining yield up.", {"buff": {"type": "prospect", "mag": 1.0, "dur": 300.0}}, Color("e8b84a")],
		["tide", "lumen", "brew_deepwater", "Deepwater Glow", "Underground fish bite much sooner and rarer fish surface.", {"buff": {"type": "deepfish", "mag": 1.0, "dur": 300.0}}, Color("4ad8e8")],
		["vigor", "ward", "brew_bulwark", "Bulwark Tonic", "Big heal and heavy damage reduction for a short while.", {"heal": 60, "buff": {"type": "defense", "mag": 2.0, "dur": 60.0}}, Color("c87a7a")],
		["zephyr", "ward", "brew_dodger", "Dodger's Draught", "Dodges recover almost instantly.", {"buff": {"type": "dodge", "mag": 1.0, "dur": 180.0}}, Color("c8d8f0")],
		["verdant", "tide", "brew_rainmaker", "Rainmaker's Brew", "Pour it out on the farm: every tilled tile is watered.", {"use": "rain"}, Color("6ab0d8")],
		["verdant", "vigor", "brew_bloom", "Bloom Tonic", "Pour near crops: a wide area grows by a day.", {"use": "grow", "radius": 12.0}, Color("9ad84a")],
		["earth", "ward", "brew_ironhide", "Ironhide Brew", "Damage reduction and you can't be knocked back.", {"buff": {"type": "ironhide", "mag": 1.0, "dur": 240.0}}, Color("8a7a6a")],
		["vigor", "zephyr", "brew_rally", "Rallying Cordial", "Shared with everyone nearby: heals and speeds the whole party.", {"heal": 35, "buff": {"type": "speed", "mag": 0.8, "dur": 120.0}, "party": true}, Color("f28a6a")],
		["lumen", "zephyr", "brew_wisp", "Wisp Water", "A wisp of light follows you and you move lightly.", {"buff": {"type": "light", "mag": 1.4, "dur": 300.0}}, Color("f0f0a0")],
		["tide", "vigor", "brew_angler_feast", "Fisher's Cordial", "Heals, and the next few fish bite almost at once.", {"heal": 30, "buff": {"type": "fishing", "mag": 2.0, "dur": 180.0}}, Color("5a9ad8")],
	]
	for s in sp:
		_add(s[2], s[3], "brew", 140, ["bottle", s[6], Color("ffffff")], {"food": s[5], "desc": s[4], "drink": true, "known": true})
		brew_specials[s[0] + "+" + s[1]] = s[2]
		brew_specials[s[1] + "+" + s[0]] = s[2]
	_add("brew_murky", "Murky Brew", "brew", 4, ["bottle", Color("5a5040"), Color("8a7a5a")], {"food": {"heal": 3}, "desc": "Not every experiment works out.", "drink": true, "known": true})

## Determine the brew produced by a list of ingredient ids. Returns {"id", "known_combo"}.
func brew_result(ings: Array) -> String:
	var bev := beverage_for(ings)
	if bev != "":
		return bev
	var tot := {}
	for e in ESSENCES:
		tot[e] = 0
	for id in ings:
		var es := essences_of(id)
		for e in es:
			tot[e] += int(es[e])
	var sorted := ESSENCES.duplicate()
	sorted.sort_custom(func(a, b): return tot[a] > tot[b] or (tot[a] == tot[b] and ESSENCES.find(a) < ESSENCES.find(b)))
	var p: String = sorted[0]
	var s: String = sorted[1]
	var potency: int = 0
	for e in tot:
		potency += tot[e]
	if tot[p] <= 0:
		return "brew_murky"
	if tot[s] >= 2 and tot[s] * 2 >= tot[p] and brew_specials.has(p + "+" + s):
		return brew_specials[p + "+" + s]
	var tier := 0
	if potency >= 5:
		tier = 1
	if potency >= 8:
		tier = 2
	return "brew_%s_%d" % [p, tier]

func beverage_for(ings: Array) -> String:
	for r in beverage_recipes:
		if _matches_exact(r["needs"], ings):
			return r["id"]
	return ""

# ---------------------------------------------------------------- food

func _dish(id: String, nm: String, price: int, heal: int, icon: Array, needs: Array, extra: Dictionary = {}) -> void:
	var food := {"heal": heal}
	if extra.has("buff"):
		food["buff"] = extra["buff"]
	_add(id, nm, "food", price, icon, {"food": food, "desc": extra.get("desc", ""), "known": true})
	cook_recipes.append({"id": id, "needs": needs, "campfire": extra.get("campfire", false)})

func _build_food() -> void:
	_dish("grilled_fish", "Grilled Fish", 40, 30, ["plate", Color("e8d0a0"), Color("c87a4a")], ["#fish"], {"campfire": true, "desc": "Simple and smoky."})
	_dish("campfire_bread", "Campfire Bread", 30, 25, ["bread", Color("d8a85a")], ["wheat", "wheat"], {"campfire": true})
	_dish("mushroom_skewer", "Mushroom Skewer", 45, 35, ["skewer", Color("a8865a")], ["#mushroom", "#mushroom"], {"campfire": true})
	_dish("roasted_roots", "Roasted Roots", 50, 35, ["plate", Color("d8a06a"), Color("ef8a2c")], ["#root", "#root"], {"campfire": true})
	_dish("trail_mix", "Trail Mix", 35, 28, ["bowl", Color("a8743f"), Color("3a2a5a")], ["hazelnut", "#berry"], {"campfire": true, "desc": "Light, filling, and it never spoils in a pack."})
	_dish("fish_stew", "Fish Stew", 90, 60, ["bowl", Color("e8c08a"), Color("c87a4a")], ["#fish", "potato", "#veg"])
	_dish("veggie_soup", "Garden Soup", 70, 45, ["bowl", Color("8ac05a"), Color("e0442f")], ["#veg", "#veg"])
	_dish("berry_pie", "Berry Pie", 110, 60, ["pie", Color("8a2a5a"), Color("e8b86a")], ["#berry", "#berry", "wheat"], {"buff": {"type": "speed", "mag": 0.6, "dur": 180.0}})
	_dish("miners_pasty", "Miner's Pasty", 120, 70, ["bread", Color("d8a050")], ["potato", "carrot", "wheat"], {"buff": {"type": "mining", "mag": 0.8, "dur": 300.0}, "desc": "Every miner's grandmother has her own recipe."})
	_dish("omelette", "Omelette", 70, 45, ["plate", Color("f6e08a"), Color("6aa83a")], ["egg", "#veg"])
	_dish("pumpkin_soup", "Pumpkin Soup", 260, 90, ["bowl", Color("ef8a2c"), Color("f6d0a0")], ["pumpkin", "#veg"], {"buff": {"type": "defense", "mag": 0.6, "dur": 240.0}})
	_dish("eel_fry", "Crispy Eel", 160, 75, ["plate", Color("c8a060"), Color("4a5a6a")], ["#eel", "wheat"], {"buff": {"type": "defense", "mag": 1.0, "dur": 240.0}})
	_dish("honey_cake", "Honey Cake", 180, 90, ["pie", Color("f2c050"), Color("fff0c0")], ["honeycomb", "wheat", "egg"], {"buff": {"type": "regen", "mag": 0.4, "dur": 60.0}})
	_dish("glow_salad", "Glow Salad", 120, 40, ["bowl", Color("7fe3ff"), Color("6ab04a")], ["glowcap", "#green"], {"buff": {"type": "light", "mag": 0.8, "dur": 300.0}})
	_dish("spicy_stew", "Ember Stew", 170, 80, ["bowl", Color("d8452f"), Color("f2a93b")], ["emberroot", "#fish", "#veg"], {"buff": {"type": "attack", "mag": 1.0, "dur": 240.0}})
	_dish("hearty_breakfast", "Hearty Breakfast", 140, 80, ["plate", Color("f6e08a"), Color("c9a46a")], ["egg", "potato", "tomato"], {"buff": {"type": "speed", "mag": 0.4, "dur": 240.0}})
	_dish("stuffed_mushroom", "Stuffed Mushrooms", 120, 55, ["plate", Color("a8865a"), Color("e8f0d0")], ["#mushroom", "wild_leek"])
	_dish("fruit_tart", "Fruit Tart", 110, 55, ["pie", Color("d8402f"), Color("f6d0a0")], ["#fruit", "wheat"])
	_dish("frost_chowder", "Frost Chowder", 200, 85, ["bowl", Color("dff2f0"), Color("c8a060")], ["frostleek", "#fish", "potato"], {"buff": {"type": "defense", "mag": 0.8, "dur": 300.0}})
	_dish("abyssal_broth", "Abyssal Broth", 480, 150, ["bowl", Color("2a2a4a"), Color("7fe3ff")], ["#deepfish", "starfern"], {"buff": {"type": "attack", "mag": 1.6, "dur": 300.0}, "desc": "Nobody is quite sure it should be eaten."})
	_dish("cave_curry", "Cave Curry", 150, 70, ["bowl", Color("d8a03a"), Color("8a7a6a")], ["cave_mushroom", "#fish", "emberroot"], {"campfire": true, "buff": {"type": "attack", "mag": 0.6, "dur": 240.0}})
	_add("egg", "Egg", "animal", 25, ["egg", Color("f4ead8")], {"food": {"heal": 8}, "known": true})
	_add("bandage", "Bandage", "consumable", 15, ["bandage", Color("f0ece0")], {"food": {"heal": 25}, "known": true, "desc": "Patches you up. Not food, but it works the same."})
	# Beverages: brewed from crops in the kettle with no strong essences
	_add("cider", "Cider", "drink", 120, ["mug", Color("e8b04a")], {"food": {"heal": 20, "buff": {"type": "speed", "mag": 0.3, "dur": 120.0}}, "drink": true, "known": true})
	_add("berry_wine", "Berry Wine", "drink", 180, ["bottle", Color("8a2a5a"), Color("d86a9a")], {"food": {"heal": 20}, "drink": true, "known": true})
	_add("ale", "Hearth Ale", "drink", 150, ["mug", Color("d8a03a")], {"food": {"heal": 25, "buff": {"type": "attack", "mag": 0.3, "dur": 120.0}}, "drink": true, "known": true, "desc": "The tavern's favorite. Brewed on your farm."})
	_add("herbal_tea", "Herbal Tea", "drink", 60, ["mug", Color("9ac06a")], {"food": {"heal": 30, "buff": {"type": "regen", "mag": 0.3, "dur": 30.0}}, "drink": true, "known": true})
	_add("mead", "Mead", "drink", 220, ["mug", Color("f2c050")], {"food": {"heal": 35, "buff": {"type": "regen", "mag": 0.5, "dur": 30.0}}, "drink": true, "known": true})
	beverage_recipes.append({"id": "cider", "needs": ["apple", "apple", "apple"]})
	beverage_recipes.append({"id": "berry_wine", "needs": ["#berry", "#berry", "#berry"]})
	beverage_recipes.append({"id": "ale", "needs": ["hops", "hops", "wheat"]})
	beverage_recipes.append({"id": "herbal_tea", "needs": ["mint", "wild_herbs"]})
	beverage_recipes.append({"id": "mead", "needs": ["honeycomb", "honeycomb"]})

## Category tags used in recipes ("#fish", "#veg", ...).
func has_tag(id: String, tag: String) -> bool:
	var d := def(id)
	match tag:
		"fish":
			return d["cat"] == "fish" and id != "bullfrog"
		"eel":
			return id in ["rain_eel", "moss_eel", "magma_eel"]
		"deepfish":
			return id in ["abyss_angler", "coelacanth", "magma_eel", "prismfish", "capfish"]
		"mushroom":
			return d["cat"] == "mushroom" or id == "glowcap"
		"berry":
			return id in ["strawberry", "blueberry", "cranberry", "bramble_berry", "wild_plum", "cherry"]
		"fruit":
			return d["cat"] == "fruit"
		"root":
			return id in ["potato", "carrot", "beet", "turnip", "winter_root", "emberroot", "frostleek"]
		"veg":
			return id in ["potato", "carrot", "beet", "turnip", "tomato", "corn", "pumpkin", "frostleek", "wild_leek", "fiddlehead", "melon"]
		"green":
			return id in ["wild_leek", "fiddlehead", "mint", "sageleaf", "deepmoss", "wild_herbs", "dandelion", "silverreed"]
	return false

func _matches_one(need: String, id: String) -> bool:
	if need.begins_with("#"):
		return has_tag(id, need.substr(1))
	return need == id

## Exact multiset match where every ingredient must be used.
func _matches_exact(needs: Array, ings: Array) -> bool:
	if needs.size() != ings.size():
		return false
	return _assign(needs, ings.duplicate())

func _assign(needs: Array, pool: Array) -> bool:
	if needs.is_empty():
		return pool.is_empty()
	var n: String = needs[0]
	var rest := needs.slice(1)
	for i in pool.size():
		if _matches_one(n, pool[i]):
			var p2 := pool.duplicate()
			p2.remove_at(i)
			if _assign(rest, p2):
				return true
	return false

## Find a cooking recipe matching exactly the given ingredients.
func cook_result(ings: Array, campfire: bool) -> String:
	for r in cook_recipes:
		if campfire and not r["campfire"]:
			continue
		if _matches_exact(r["needs"], ings):
			return r["id"]
	return ""

## Can the inventory (id->count map) satisfy this need list? Returns concrete ingredient ids or [].
func pick_ingredients(needs: Array, counts: Dictionary) -> Array:
	var avail := counts.duplicate()
	var out: Array = []
	# exact ids first, then tags
	var ordered := needs.duplicate()
	ordered.sort_custom(func(a, b): return not a.begins_with("#") and b.begins_with("#"))
	for n in ordered:
		var found := ""
		if not n.begins_with("#"):
			if int(avail.get(n, 0)) > 0:
				found = n
		else:
			var best := ""
			var best_price := 1 << 30
			for id in avail:
				if int(avail[id]) > 0 and has_tag(id, n.substr(1)):
					var p := int(def(id)["price"])
					if p < best_price:
						best_price = p
						best = id
			found = best
		if found == "":
			return []
		avail[found] = int(avail[found]) - 1
		out.append(found)
	return out

func need_label(n: String) -> String:
	if n.begins_with("#"):
		return {"#fish": "Any Fish", "#veg": "Any Vegetable", "#mushroom": "Any Mushroom", "#berry": "Any Berry",
			"#fruit": "Any Fruit", "#root": "Any Root", "#green": "Any Greens", "#eel": "Any Eel", "#deepfish": "Any Deep Fish"}.get(n, n)
	return def(n)["name"]

# ---------------------------------------------------------------- tools & weapons

func _build_tools() -> void:
	var kinds := [["hoe", "Hoe", "Tills soil for planting. Also digs up clay and buried things."],
		["can", "Watering Can", "Waters crops. Refill at any water."],
		["axe", "Axe", "Chops trees and stumps."],
		["pick", "Pickaxe", "Breaks rocks, ore and cracked walls."]]
	for k in kinds:
		for t in 5:
			var nm := "%s %s" % [TOOL_TIERS[t], k[1]]
			_add("%s_%d" % [k[0], t], nm, "tool", [5, 60, 200, 500, 1200][t], [k[0], TIER_COLORS[[0, 1, 2, 4, 5][t]]],
				{"stack": 1, "known": true, "tool": {"kind": k[0], "tier": t}, "desc": k[2] + ("" if k[0] != "can" else " Holds %d water." % [20, 35, 55, 80, 120][t])})
	var rods := ["Bamboo Rod", "Willow Rod", "Iron Rod", "Silver Rod", "Starmetal Rod"]
	for t in 5:
		_add("rod_%d" % t, rods[t], "tool", [5, 80, 250, 600, 1500][t], ["rod", [Color("c8b46a"), Color("8a6a3a"), Color("a9a9b0"), Color("dfe6ee"), Color("8a7dff")][t]],
			{"stack": 1, "known": true, "tool": {"kind": "rod", "tier": t}, "desc": "Cast into any water. Better rods widen the catch zone and pull treasure up more often."})

const WEAPON_BASE := {
	"sword": {"name": "Sword", "dmg": 9.0, "time": 0.36, "range": 2.4, "arc": 115.0, "kb": 5.0, "crit": 0.06},
	"spear": {"name": "Spear", "dmg": 10.0, "time": 0.46, "range": 3.5, "arc": 34.0, "kb": 7.0, "crit": 0.08},
	"hammer": {"name": "Hammer", "dmg": 22.0, "time": 0.78, "range": 2.6, "arc": 160.0, "kb": 12.0, "crit": 0.03, "windup": 0.32},
	"dagger": {"name": "Dagger", "dmg": 5.5, "time": 0.2, "range": 1.8, "arc": 95.0, "kb": 2.0, "crit": 0.18},
	"bow": {"name": "Bow", "dmg": 8.0, "time": 0.55, "range": 22.0, "arc": 0.0, "kb": 3.0, "crit": 0.08},
}

func _build_weapons() -> void:
	var tier_names_bow := ["Shortbow", "Copper Bow", "Ironwood Bow", "Silver Longbow", "Gilded Bow", "Starmetal Bow"]
	for kind in WEAPON_BASE:
		var b: Dictionary = WEAPON_BASE[kind]
		for t in 6:
			var nm := "%s %s" % [WEAPON_TIERS[t], b["name"]]
			if kind == "hammer" and t == 0:
				nm = "Wooden Mallet"
			if kind == "bow":
				nm = tier_names_bow[t]
			var mult := 1.0 + 0.62 * t
			_add("%s_%d" % [kind, t], nm, "weapon", int([10, 80, 220, 500, 900, 2000][t] * (1.2 if kind == "hammer" else 1.0)), [kind, TIER_COLORS[t], Color("8a6a4a")],
				{"stack": 1, "known": true, "weapon": {"kind": kind, "tier": t, "dmg": b["dmg"] * mult, "time": b["time"], "range": b["range"], "arc": b["arc"], "kb": b["kb"], "crit": b["crit"], "windup": b.get("windup", 0.0)},
				"desc": {"sword": "Balanced, sweeping slashes.", "spear": "Long reach. Keeps trouble at arm's length.", "hammer": "Slow, but it sends things flying.", "dagger": "Lightning fast. Strikes from behind crit more often.", "bow": "Hold to draw, release to loose. Needs arrows."}[kind]})
	_add("arrow", "Arrow", "ammo", 1, ["arrow", Color("c8b07a")], {"known": true, "ammo": {"dmg": 1.0}})
	_add("iron_arrow", "Iron Arrow", "ammo", 3, ["arrow", Color("a9a9b0")], {"known": true, "ammo": {"dmg": 1.5}})
	_add("crystal_arrow", "Crystal Arrow", "ammo", 6, ["arrow", Color("9fe3ff")], {"known": true, "ammo": {"dmg": 2.0, "pierce": true}})

func _build_gear() -> void:
	var g := [
		["straw_hat", "Straw Hat", "hat", ["greenthumb"], 60, Color("e3c26a"), "A wide brim for long days in the field."],
		["miners_helmet", "Miner's Helmet", "hat", ["glowing"], 150, Color("d8a03a"), "A little lamp on top. Very practical."],
		["angler_cap", "Angler's Cap", "hat", ["angler"], 150, Color("4a7ab0"), "Smells faintly of the river."],
		["leather_cap", "Leather Cap", "hat", ["stalwart"], 120, Color("8a5a3a"), ""],
		["explorer_hat", "Explorer's Hat", "hat", ["lucky"], 300, Color("a8865a"), "Whoever wore this before found something good."],
		["chef_hat", "Chef's Hat", "hat", ["gourmand"], 200, Color("f4f2ea"), ""],
		["leather_boots", "Leather Boots", "boots", ["swift"], 100, Color("8a5a3a"), ""],
		["work_boots", "Work Boots", "boots", ["stalwart"], 120, Color("5a4a3a"), ""],
		["featherstep_boots", "Featherstep Boots", "boots", ["featherstep", "swift"], 600, Color("e8e0d0"), "Light as anything. You hardly touch the ground."],
		["copper_ring", "Copper Ring", "trinket", ["keen"], 120, Color("c8743a"), ""],
		["silver_ring", "Silver Ring", "trinket", ["hearty"], 300, Color("dfe6ee"), ""],
		["gold_ring", "Gold Ring", "trinket", ["lucky"], 600, Color("f2c94c"), ""],
		["fish_charm", "Fish-Scale Charm", "trinket", ["angler"], 200, Color("7fc0e0"), ""],
		["bone_charm", "Bone Charm", "trinket", ["scavenger"], 200, Color("e9e2cf"), ""],
		["prospector_pendant", "Prospector's Pendant", "trinket", ["prospector"], 400, Color("f2a93b"), ""],
		["lantern_pendant", "Lantern Pendant", "trinket", ["glowing"], 250, Color("ffd36b"), ""],
		["seed_pouch", "Lucky Seed Pouch", "trinket", ["greenthumb"], 250, Color("8fae4a"), ""],
	]
	for x in g:
		var shape: String = {"hat": "hat", "boots": "boots", "trinket": "ring"}[x[2]]
		if x[0].ends_with("pendant") or x[0].ends_with("charm") or x[0] == "seed_pouch":
			shape = "amulet"
		_add(x[0], x[1], "gear", x[4], [shape, x[5]], {"stack": 1, "known": true, "gear": {"slot": x[2]}, "traits": x[3], "desc": x[6]})

# ---------------------------------------------------------------- placeables

func _place(id: String, nm: String, price: int, icon: Array, obj: String, extra: Dictionary = {}) -> void:
	var p := {"obj": obj, "outdoor": extra.get("outdoor", true), "indoor": extra.get("indoor", false), "cave": extra.get("cave", false), "size": extra.get("size", Vector2i(1, 1))}
	var d := {"place": p, "known": true, "desc": extra.get("desc", ""), "stack": extra.get("stack", 99)}
	if extra.has("buy"):
		d["buy"] = extra["buy"]
	_add(id, nm, "placeable", price, icon, d)

func _build_placeables() -> void:
	_place("chest", "Chest", 40, ["chest", Color("9a6b3f")], "chest", {"indoor": true, "cave": false, "desc": "Holds 36 stacks. Shared by everyone."})
	_place("big_chest", "Big Chest", 120, ["chest", Color("6b4a8a")], "big_chest", {"indoor": true, "desc": "Holds 72 stacks."})
	_place("workbench", "Workbench", 60, ["table", Color("a8774a")], "workbench", {"indoor": true, "desc": "Craft tools, furniture and supplies."})
	_place("furnace", "Furnace", 60, ["furnace", Color("8a8a8a")], "furnace", {"desc": "Smelts 3 ore + 1 coal into a bar."})
	_place("kettle", "Brewing Kettle", 150, ["kettle", Color("c8743a")], "kettle", {"indoor": true, "desc": "Brew up to 3 ingredients into tonics and drinks. Essences decide the result."})
	_place("stove", "Cookstove", 120, ["stove", Color("6a6a6a")], "stove", {"indoor": true, "desc": "Cook any known dish, or experiment."})
	_place("campfire", "Campfire Kit", 20, ["campfire", Color("e8702a")], "campfire", {"cave": true, "desc": "Place anywhere, even underground. Cook simple meals and rest a moment."})
	_place("torch", "Torch", 3, ["torch", Color("f2a93b")], "torch", {"cave": true, "desc": "Light the way. Torches placed underground stay put."})
	_place("sprinkler", "Sprinkler", 100, ["sprinkler", Color("c8743a")], "sprinkler", {"desc": "Waters the 4 adjacent tiles every morning."})
	_place("sprinkler_2", "Quality Sprinkler", 300, ["sprinkler", Color("f2c94c")], "sprinkler_2", {"desc": "Waters the 8 surrounding tiles every morning."})
	_place("scarecrow", "Scarecrow", 30, ["box", Color("d8c06a")], "scarecrow", {"desc": "He keeps watch. Mostly decorative, entirely beloved."})
	_place("fence", "Fence", 2, ["fence", Color("9a6b3f")], "fence", {"desc": "Keeps the chickens honest."})
	_place("stone_path", "Stone Path", 1, ["stone", Color("b8b0a0")], "stone_path", {"desc": "A flagstone to walk on."})
	_place("wood_path", "Wood Path", 1, ["log", Color("b88a5a")], "wood_path", {"desc": "A plank walkway."})
	_place("lamp_post", "Lamp Post", 80, ["lamp", Color("3a3a3a")], "lamp_post", {"desc": "Lights up at dusk."})
	_place("flower_pot", "Flower Pot", 20, ["pot", Color("c07a52")], "flower_pot", {"indoor": true})
	_place("beehive", "Bee House", 150, ["box", Color("e8c06a")], "beehive", {"desc": "Produces honeycomb every few days, faster near flowers."})
	_place("display_stand", "Display Stand", 50, ["box", Color("c8b08a")], "display_stand", {"indoor": true, "desc": "Show off a treasure: hold an item and interact to set it on display."})
	_place("fish_tank", "Fish Tank", 150, ["tank", Color("7fc0e0")], "fish_tank", {"indoor": true, "desc": "Interact while holding a fish to let it live here."})
	_place("table", "Table", 30, ["table", Color("b88a5a")], "table", {"indoor": true})
	_place("chair", "Chair", 15, ["chair", Color("b88a5a")], "chair", {"indoor": true})
	_place("rug", "Woven Rug", 30, ["rug", Color("c0504a")], "rug", {"indoor": true})
	_place("bed", "Bed", 80, ["bed", Color("6a8ac0")], "bed", {"indoor": true, "desc": "Sleep here. When everyone is asleep, the night passes."})
	_place("bookshelf", "Bookshelf", 60, ["box", Color("7a4a2a")], "bookshelf", {"indoor": true})
	_place("bench", "Bench", 30, ["chair", Color("9a6b3f")], "bench", {"indoor": true})
	_place("barrel", "Barrel", 20, ["box", Color("8a5a3a")], "barrel", {"indoor": true})
	_place("crate", "Crate", 15, ["box", Color("b88a5a")], "crate", {"indoor": true})
	_place("banner", "Banner", 30, ["box", Color("4a6ab0")], "banner", {"indoor": true})
	_place("painting", "Landscape Painting", 60, ["box", Color("6ab0d8")], "painting", {"indoor": true, "outdoor": false})
	_place("plant_pot", "Potted Fern", 40, ["pot", Color("5aa83a")], "plant_pot", {"indoor": true})
	_place("garden_gnome", "Garden Gnome", 40, ["gnome", Color("d8402f")], "garden_gnome", {"indoor": true, "desc": "He has seen things."})
	_place("coop_kit", "Coop Kit", 400, ["box", Color("c8a07a")], "coop", {"size": Vector2i(4, 3), "stack": 1, "buy": 2500, "desc": "A chicken coop with a feeding trough. Place it on the farm."})
	_place("shed_kit", "Storage Shed Kit", 300, ["box", Color("8a6a4a")], "shed", {"size": Vector2i(4, 4), "stack": 1, "buy": 1800, "desc": "A shed with room for four big chests."})
	_place("chicken", "Chicken", 200, ["egg", Color("f4f2ea"), Color("e04a3a")], "chicken", {"stack": 1, "buy": 800, "desc": "Place near your coop. Lays an egg each day it's fed."})

# ---------------------------------------------------------------- curios & misc

func _build_curios() -> void:
	var c := [
		["ancient_coin", "Ancient Coin", 60, "coin", Color("d8b04a"), "Stamped with a face nobody recognizes."],
		["fossil_shell", "Fossil Shell", 80, "fossil", Color("d8c8a8"), "A spiral of stone that was once alive."],
		["old_locket", "Old Locket", 50, "amulet", Color("c8a85a"), "There's a tiny portrait inside, faded past recognizing."],
		["carved_figure", "Carved Figure", 70, "idol", Color("a8865a"), "A little wooden figure of someone with a lantern."],
		["rusty_key", "Rusty Key", 20, "key", Color("8a5a3a"), "It must open something."],
		["star_map", "Star Map", 150, "scroll", Color("2a3a6a"), "The constellations are wrong. Or old."],
		["clockwork_bird", "Clockwork Bird", 220, "idol", Color("c8a85a"), "It still twitches when wound."],
		["strange_idol", "Strange Idol", 320, "idol", Color("4a8a7a"), "It's heavier than it looks, and always cold."],
		["miners_tag", "Miner's Tag", 40, "coin", Color("a9a9b0"), "A stamped tin tag: a name and a floor number."],
		["dragon_tooth", "Enormous Tooth", 260, "claw", Color("f0e8d0"), "From what, exactly?"],
	]
	for x in c:
		_add(x[0], x[1], "curio", x[2], [x[3], x[4]], {"desc": x[5], "curio": true})
	_add("old_boot", "Old Boot", "junk", 1, ["boots", Color("5a4a3a")], {"known": true, "desc": "Someone lost this. Someone else found it."})
	_add("driftwood", "Driftwood", "junk", 2, ["log", Color("b8a88a")], {"known": true})
	_add("river_weed", "River Weed", "junk", 4, ["herb", Color("4a7a5a")], {"ess": {"tide": 1}})
	_add("soggy_letter", "Soggy Letter", "junk", 1, ["scroll", Color("d8d0b8")], {"desc": "The ink has mostly run. You can just make out a few words."})

func _build_misc() -> void:
	_add("escape_rope", "Homeward Rope", "consumable", 30, ["rope", Color("c8a86a")], {"known": true, "food": {"use": "escape"}, "desc": "Use underground to climb straight back up to Delver's Yard with your haul. A way back down will be waiting there, right where you left off."})
	_add("deluxe_bait", "Deluxe Bait", "bait", 6, ["worm", Color("e8a03a")], {"known": true, "bait": {"bite": 0.55, "rare": 0.1}})
	_add("magnet_lure", "Magnet Lure", "bait", 25, ["coin", Color("c03a3a")], {"known": true, "bait": {"bite": 1.0, "rare": 0.0, "treasure": 0.25}, "stack": 20, "desc": "Fish don't care for it. Treasure does."})
	_add("lost_pick", "Grandfather's Pick", "quest", 0, ["pick", Color("8a6a4a")], {"stack": 1, "desc": "Worn smooth by decades of use."})
	_add("lost_satchel", "Lost Satchel", "quest", 0, ["bag", Color("8a5a3a")], {"stack": 1, "desc": "It still has someone's lunch in it."})
	_add("survey_marker", "Survey Marker", "quest", 0, ["coin", Color("a9a9b0")], {"stack": 1, "desc": "An old surveyor's brass marker."})
	_add("lost_charm", "Lost Charm", "quest", 0, ["amulet", Color("e8a0c0")], {"stack": 1, "desc": "A homemade charm on a frayed string."})
	_add("expedition_journal", "Expedition Journal", "quest", 0, ["scroll", Color("8a5a3a")], {"stack": 1, "desc": "The handwriting gets shakier toward the end."})

# ---------------------------------------------------------------- recipes

func _craft(id: String, n: int, needs: Dictionary, unlock: String = "") -> void:
	craft_recipes.append({"id": id, "n": n, "needs": needs, "unlock": unlock})

func _build_recipes() -> void:
	_craft("chest", 1, {"wood": 25})
	_craft("torch", 5, {"wood": 2, "coal": 1})
	_craft("campfire", 1, {"wood": 8, "stone": 6})
	_craft("furnace", 1, {"stone": 25, "clay": 8})
	_craft("bandage", 2, {"fiber": 6, "sap": 1})
	_craft("arrow", 10, {"wood": 2, "flint": 1})
	_craft("fence", 4, {"wood": 4})
	_craft("stone_path", 5, {"stone": 5})
	_craft("wood_path", 5, {"wood": 3})
	_craft("escape_rope", 1, {"fiber": 15, "sap": 2})
	_craft("chair", 1, {"wood": 6})
	_craft("table", 1, {"wood": 12})
	_craft("crate", 1, {"wood": 8})
	_craft("barrel", 1, {"wood": 10, "copper_bar": 1})
	_craft("bench", 1, {"wood": 10})
	_craft("flower_pot", 1, {"clay": 4})
	_craft("plant_pot", 1, {"clay": 4, "fiddlehead": 1})
	_craft("rug", 1, {"fiber": 20})
	_craft("banner", 1, {"fiber": 15, "wood": 2})
	_craft("bed", 1, {"wood": 20, "fiber": 15})
	_craft("scarecrow", 1, {"wood": 10, "fiber": 10, "hay": 5})
	_craft("feed", 5, {"wheat": 2, "hay": 3})
	_craft("kettle", 1, {"copper_bar": 3, "stone": 15, "clay": 5})
	_craft("stove", 1, {"stone": 30, "clay": 10, "copper_bar": 1})
	_craft("sprinkler", 1, {"copper_bar": 2, "iron_bar": 1})
	_craft("big_chest", 1, {"wood": 40, "iron_bar": 2})
	_craft("lamp_post", 1, {"iron_bar": 1, "wood": 5, "coal": 2})
	_craft("display_stand", 1, {"wood": 15, "stone": 10})
	_craft("bookshelf", 1, {"wood": 20, "hardwood": 4})
	_craft("fish_tank", 1, {"copper_bar": 2, "crystal_shard": 4, "wood": 10})
	_craft("beehive", 1, {"wood": 30, "hardwood": 4, "honeycomb": 1}, "honeycomb")
	_craft("iron_arrow", 10, {"wood": 2, "iron_bar": 1})
	_craft("crystal_arrow", 10, {"wood": 2, "crystal_shard": 2}, "crystal_shard")
	_craft("deluxe_bait", 5, {"worm": 3, "slime_gel": 1}, "slime_gel")
	_craft("magnet_lure", 1, {"iron_bar": 1})
	_craft("garden_gnome", 1, {"clay": 10, "fiber": 2})
	_craft("painting", 1, {"wood": 4, "fiber": 4, "quartz": 1}, "quartz")
	_craft("sprinkler_2", 1, {"iron_bar": 2, "gold_bar": 1}, "gold_bar")

# ---------------------------------------------------------------- shops

func _build_shops() -> void:
	# entry: [item id, min town level]
	shop_tables["general"] = [
		["turnip_seeds", 0], ["potato_seeds", 0], ["carrot_seeds", 0], ["strawberry_seeds", 1],
		["tomato_seeds", 0], ["corn_seeds", 0], ["melon_seeds", 1], ["hops_seeds", 0], ["blueberry_seeds", 1],
		["pumpkin_seeds", 0], ["wheat_seeds", 0], ["cranberry_seeds", 1], ["beet_seeds", 0], ["frostleek_seeds", 0],
		["feed", 0], ["chicken", 1], ["fence", 0], ["torch", 0], ["bandage", 0], ["worm", 0], ["arrow", 0],
		["apple_sapling", 1], ["cherry_sapling", 1], ["peach_sapling", 2],
	]
	shop_tables["herbalist"] = [
		["mint_seeds", 0], ["sageleaf_seeds", 0], ["emberroot_seeds", 0], ["stonewort_seeds", 0],
		["silverreed_seeds", 0], ["sunpetal_seeds", 0], ["mossbloom_seeds", 0], ["brew_vigor_0", 0], ["bandage", 0],
		["brew_vigor_1", 2], ["brew_lumen_0", 1], ["kettle", 0],
	]
	shop_tables["blacksmith"] = [
		["sword_1", 0], ["spear_1", 0], ["hammer_1", 0], ["dagger_1", 0], ["bow_0", 0],
		["sword_2", 2], ["spear_2", 2], ["hammer_2", 2], ["dagger_2", 2], ["bow_2", 2],
		["sword_3", 4], ["spear_3", 4], ["hammer_3", 4], ["bow_3", 4],
		["coal", 0], ["copper_ore", 0], ["iron_ore", 2], ["iron_arrow", 1],
		["leather_cap", 0], ["work_boots", 0], ["miners_helmet", 1],
	]
	shop_tables["tavern"] = [
		["campfire_bread", 0], ["grilled_fish", 0], ["veggie_soup", 0], ["fish_stew", 1], ["miners_pasty", 2],
		["ale", 1], ["cider", 2], ["chef_hat", 3], ["stove", 1],
	]
	shop_tables["carpenter"] = [
		["wood", 0], ["stone", 0], ["clay", 1], ["coop_kit", 0], ["shed_kit", 1], ["chest", 0],
		["table", 0], ["chair", 0], ["bed", 0], ["rug", 0], ["bookshelf", 1], ["lamp_post", 2], ["painting", 2], ["banner", 0],
	]
	shop_tables["angler"] = [
		["rod_1", 0], ["rod_2", 2], ["rod_3", 4], ["worm", 0], ["deluxe_bait", 1], ["magnet_lure", 2],
		["angler_cap", 1], ["fish_charm", 3], ["fish_tank", 1],
	]
	shop_tables["lodge"] = [
		["escape_rope", 0], ["torch", 0], ["campfire", 0], ["bandage", 0], ["brew_vigor_1", 0], ["trail_mix", 0],
		["glowgrub", 0], ["explorer_hat", 0], ["featherstep_boots", 0], ["crystal_arrow", 0],
	]
	shop_tables["market"] = [
		["lumenfruit_sapling", 0], ["glowcap_seeds", 0], ["deepmoss_seeds", 0], ["gold_ring", 0], ["silver_ring", 0],
		["prospector_pendant", 0], ["lantern_pendant", 0], ["bone_charm", 0], ["seed_pouch", 0], ["garden_gnome", 0],
	]
