class_name TownLogic
extends RefCounted
## Server-side town rules: friendship, gifts, shops, identifying things, and the
## community projects that physically change the town.

var srv: ServerLogic

const PROJECTS := [
	{"id": "bridge", "name": "Mend the Old Bridge", "desc": "Rebuild the broken bridge over the river. A shortcut to the far bank.", "needs": {"wood": 60, "stone": 40}, "coins": 500, "level": 0},
	{"id": "market", "name": "Market Stalls", "desc": "Stalls in the plaza, and a traveling merchant with rare wares that change daily.", "needs": {"wood": 80, "fiber": 40}, "coins": 1000, "level": 0},
	{"id": "lamps", "name": "Lamplighter's Posts", "desc": "Lamps along the roads so nobody walks home in the dark.", "needs": {"iron_bar": 10, "coal": 20}, "coins": 600, "level": 0},
	{"id": "cottages", "name": "Welcome Cottages", "desc": "Cottages on the empty lots. New neighbors will move in.", "needs": {"wood": 100, "stone": 80, "clay": 30}, "coins": 2000, "level": 1},
	{"id": "fountain", "name": "Plaza Fountain & Gardens", "desc": "A proper fountain and flower beds for the plaza.", "needs": {"stone": 100, "sunpetal": 5, "mossbloom": 5}, "coins": 1500, "level": 1},
	{"id": "pier", "name": "Lakeside Pier", "desc": "Extend the old dock. The angler will stock better tackle.", "needs": {"wood": 120, "iron_bar": 5}, "coins": 2000, "level": 1},
	{"id": "lodge", "name": "Expedition Lodge", "desc": "A lodge by the cave mouth selling expedition supplies. An old explorer will move in.", "needs": {"iron_bar": 15, "wood": 60, "hardwood": 10}, "coins": 3000, "level": 2},
	{"id": "curio_hall", "name": "Curio Hall", "desc": "A little museum for the strange things you bring up from below.", "needs": {"hardwood": 30, "stone": 80, "quartz": 5}, "coins": 3000, "level": 2},
	{"id": "greenhouse", "name": "Apothecary Greenhouse", "desc": "The apothecary will grow and sell seeds of rare underground plants.", "needs": {"crystal_shard": 10, "wood": 50, "clay": 20}, "coins": 2500, "level": 2},
	{"id": "smithy", "name": "Smithy Expansion", "desc": "A bigger forge: better weapons in stock and trait reforging.", "needs": {"iron_bar": 20, "gold_bar": 5}, "coins": 4000, "level": 3},
	{"id": "cottages2", "name": "Hillside Homes", "desc": "Room for even more families to settle in town.", "needs": {"hardwood": 40, "stone": 120, "iron_bar": 5}, "coins": 4000, "level": 4},
]
const SPECIALTY := {
	"general": ["crop", "fruit", "forage", "animal", "seed", "sapling"], "blacksmith": ["ore", "bar", "mineral", "gem", "weapon", "tool"],
	"tavern": ["food", "drink", "fish"], "herbalist": ["herb", "mushroom", "brew", "monster"], "carpenter": ["material", "placeable"],
	"angler": ["fish", "bait", "junk"], "market": ["curio", "gem"], "lodge": ["monster", "mineral", "ore"],
}
const IDENTIFY := {
	"herbalist": ["herb", "mushroom", "forage", "brew", "monster", "fruit"], "smith": ["ore", "mineral", "gem", "bar", "monster"],
	"angler": ["fish", "bait", "junk"], "mayor": ["curio"], "scholar": ["curio"], "historian": ["curio"], "innkeeper": ["food", "drink", "crop", "fruit", "fish"],
	"carpenter": ["material"], "merchant": ["crop", "seed", "forage", "fruit", "animal"], "miner": ["ore", "mineral", "gem"], "explorer": ["monster", "mineral", "curio", "mushroom"],
	"glassblower": ["gem", "mineral"], "chef": ["food", "fish", "mushroom", "crop"], "beekeeper": ["animal", "forage"],
}

func _init(s: ServerLogic) -> void:
	srv = s

func town() -> Dictionary:
	return Game.world["town"]

func set_town(k: String, v) -> void:
	srv._ch({"t": "town", "k": k, "v": v})

func init_town() -> void:
	var t := town()
	t["name"] = TownGen.town_name()
	t["level"] = 0
	t["prosperity"] = 0
	t["projects"] = {}
	t["newcomers"] = 0
	t["friend"] = {}
	t["daily"] = {}
	t["milestones"] = {}
	t["donated"] = {}
	t["wishes"] = {}

static func hearts(npc_id: String, player: String) -> int:
	return int(Game.world.get("town", {}).get("friend", {}).get(npc_id, {}).get(player, 0)) / 100

static func points(npc_id: String, player: String) -> int:
	return int(Game.world.get("town", {}).get("friend", {}).get(npc_id, {}).get(player, 0))

func _add_friend(npc_id: String, player: String, n: int, peer: int) -> void:
	var fr: Dictionary = town().get("friend", {}).duplicate(true)
	if not fr.has(npc_id):
		fr[npc_id] = {}
	var before := int(fr[npc_id].get(player, 0))
	var after: int = clamp(before + n, 0, 1000)
	fr[npc_id][player] = after
	set_town("friend", fr)
	if after / 100 > before / 100:
		_check_milestone(npc_id, player, after / 100, peer)

func _daily(npc_id: String, player: String) -> Dictionary:
	return town().get("daily", {}).get(npc_id, {}).get(player, {})

func _set_daily(npc_id: String, player: String, key: String) -> void:
	var dl: Dictionary = town().get("daily", {}).duplicate(true)
	if not dl.has(npc_id):
		dl[npc_id] = {}
	if not dl[npc_id].has(player):
		dl[npc_id][player] = {}
	dl[npc_id][player][key] = Game.day()
	set_town("daily", dl)

func new_day(day: int) -> void:
	var t := town()
	var built_any := false
	for pid in t.get("projects", {}):
		var p: Dictionary = t["projects"][pid]
		if p.get("state", "") == "funded":
			p["state"] = "built"
			p["day"] = day
			Game.world["flags"]["project_" + pid] = true
			t["level"] = int(t.get("level", 0)) + 1
			t["prosperity"] = int(t.get("prosperity", 0)) + 50
			built_any = true
			var pd := project(pid)
			Game.world["chronicle"].append({"d": day, "s": "The town finished the %s." % pd.get("name", pid), "k": "project"})
			match pid:
				"bridge":
					Game.world["flags"]["bridge_fixed"] = true
				"cottages", "cottages2":
					t["newcomers"] = int(t.get("newcomers", 0)) + 2
					Game.world["chronicle"].append({"d": day, "s": "New neighbors moved into %s." % t.get("name", "town"), "k": "people"})
				"lodge":
					t["newcomers"] = int(t.get("newcomers", 0)) + 1
	if built_any:
		srv._toast("Something in town has changed overnight...", Color("ffe08a"))

static func project(pid: String) -> Dictionary:
	for p in PROJECTS:
		if p["id"] == pid:
			return p
	return {}

## Items a shop sells today.
static func stock(shop: String) -> Array:
	var lvl := int(Game.world.get("town", {}).get("level", 0))
	var f: Dictionary = Game.world.get("flags", {})
	var out: Array = []
	var table: Array = Items.shop_tables.get(shop, [])
	if shop == "market":
		var r := Game.rng_for("market", Game.day())
		var pool := table.duplicate()
		for i in 5:
			if pool.is_empty():
				break
			var k := r.randi() % pool.size()
			out.append(pool[k][0])
			pool.remove_at(k)
		return out
	for e in table:
		if lvl >= int(e[1]):
			out.append(e[0])
	if shop == "herbalist" and f.get("project_greenhouse", false):
		out.append_array(["glowcap_seeds", "deepmoss_seeds", "crystalbloom_seeds", "brew_earth_1", "brew_tide_1"])
	if shop == "blacksmith" and f.get("project_smithy", false):
		out.append_array(["sword_4", "spear_4", "hammer_4", "dagger_3", "bow_4", "prospector_pendant"])
	if shop == "angler" and f.get("project_pier", false):
		out.append_array(["glowgrub", "rod_4", "fish_charm"])
	return out

static func buy_price_for(id: String, shop: String, player: String) -> int:
	var base := Items.buy_price(id)
	var keeper := Zones.town.keeper_of(shop) if Zones.town else {}
	var h := hearts(keeper.get("id", ""), player) if not keeper.is_empty() else 0
	return max(1, int(round(base * (1.0 - 0.01 * min(h, 10)))))

static func sell_price_for(it: Dictionary, shop: String) -> int:
	var p := Items.sell_price(it)
	if SPECIALTY.get(shop, []).has(Items.cat_of(it["id"])):
		p = int(ceil(p * 1.1))
	return p

# ------------------------------------------------------------------ actions

func _npc(id: String) -> Dictionary:
	return Zones.town.resident(id) if Zones.town else {}

func a_talk(peer: int, a: Dictionary) -> void:
	var npc_id: String = a["npc"]
	var pl := srv.pname(peer)
	var met: Dictionary = Game.world["know"]["people"].get(npc_id, {})
	if met.is_empty():
		srv._ch({"t": "people", "id": npc_id, "v": {"day": Game.day(), "by": pl}})
	if int(_daily(npc_id, pl).get("talk", -1)) != Game.day():
		_set_daily(npc_id, pl, "talk")
		_add_friend(npc_id, pl, 12, peer)

func a_gift(peer: int, a: Dictionary) -> void:
	var npc_id: String = a["npc"]
	var item: String = a["item"]
	var pl := srv.pname(peer)
	var npc := _npc(npc_id)
	if npc.is_empty():
		Net.grant(peer, [Items.make(item)], true)
		return
	# wishes are special: always accepted, once
	if item == npc.get("wish", "") and not town().get("wishes", {}).has(npc_id):
		var w: Dictionary = town().get("wishes", {}).duplicate(true)
		w[npc_id] = pl
		set_town("wishes", w)
		_add_friend(npc_id, pl, 250, peer)
		var reward := _wish_reward(npc)
		Net.grant(peer, reward)
		Net.tell(peer, "npc_say", {"npc": npc_id, "text": Dialogue.wish_fulfilled(npc, Items.def(item)["name"])})
		srv.chronicle("%s gave %s the %s they'd always wanted." % [pl, npc["first"], Items.def(item)["name"]], "people")
		town()["prosperity"] = int(town().get("prosperity", 0)) + 15
		return
	if int(_daily(npc_id, pl).get("gift", -1)) == Game.day():
		Net.grant(peer, [Items.make(item)], true)
		Net.tell(peer, "npc_say", {"npc": npc_id, "text": "You've already given me something today. Save it for tomorrow!"})
		return
	_set_daily(npc_id, pl, "gift")
	var ctx := TownUI.context_for(npc, pl)
	var r: Dictionary = Dialogue.gift_reaction(npc, item, ctx)
	var pts := {"love": 80, "like": 45, "neutral": 20, "dislike": -20}.get(r.get("level", "neutral"), 20)
	if ctx.get("birthday_today", false):
		pts *= 2
	_add_friend(npc_id, pl, pts, peer)
	Net.tell(peer, "npc_say", {"npc": npc_id, "text": r.get("text", "Thank you."), "level": r.get("level", "neutral")})
	if not Game.is_known(item):
		srv._ch({"t": "learn_item", "id": item, "by": pl})

func _wish_reward(npc: Dictionary) -> Array:
	var r := Game.rng_for("wish", npc["id"].hash())
	var out: Array = [Loot.equipment(4, r)]
	match npc["interests"][0]:
		"fishing":
			out.append(Items.make("rod_3"))
		"gardening", "flowers":
			out.append(Items.make("starfern_seeds"))
		"cooking", "baking":
			out.append(Items.make("abyssal_broth", 2))
		_:
			out.append(Items.make("heartstone"))
	return out

func a_identify(peer: int, a: Dictionary) -> void:
	var npc := _npc(a["npc"])
	var item: String = a["item"]
	if npc.is_empty() or not Items.has(item):
		return
	var dom: Array = IDENTIFY.get(npc["role"], [])
	var knows := dom.has(Items.cat_of(item))
	if knows and not Game.is_known(item):
		srv._ch({"t": "learn_item", "id": item, "by": srv.pname(peer)})
	Net.tell(peer, "npc_say", {"npc": npc["id"], "text": Dialogue.identify_reply(npc, item, knows)})

func a_shop_buy(peer: int, a: Dictionary) -> void:
	var shop: String = a["shop"]
	var id: String = a["id"]
	var n: int = clamp(int(a.get("n", 1)), 1, 99)
	if not stock(shop).has(id):
		return
	var price := buy_price_for(id, shop, srv.pname(peer)) * n
	if Game.money() < price:
		Net.tell(peer, "toast", {"text": "Not enough coins.", "color": Color("ff9a7a")})
		return
	srv.add_money(-price, "buy")
	var items: Array = []
	if Items.stack_max(id) <= 1:
		for i in n:
			items.append(Items.make(id))
	else:
		items.append(Items.make(id, n))
	Net.grant(peer, items)
	Net.tell(peer, "sfx", {"s": "buy"})
	town()["prosperity"] = int(town().get("prosperity", 0)) + max(1, price / 200)

func a_shop_sell(peer: int, a: Dictionary) -> void:
	var it: Dictionary = a["item"]
	var shop: String = a.get("shop", "general")
	var total := sell_price_for(it, shop) * int(it["n"])
	srv.add_money(total, "sell")
	Net.tell(peer, "sfx", {"s": "sell"})
	if not Game.is_known(it["id"]):
		srv._ch({"t": "learn_item", "id": it["id"], "by": srv.pname(peer)})
	town()["prosperity"] = int(town().get("prosperity", 0)) + max(0, total / 250)

func a_project_give(peer: int, a: Dictionary) -> void:
	var pid: String = a["pid"]
	var pd := project(pid)
	if pd.is_empty():
		return
	var projs: Dictionary = town().get("projects", {}).duplicate(true)
	if not projs.has(pid):
		projs[pid] = {"have": {}, "coins": 0, "state": "open"}
	var p: Dictionary = projs[pid]
	if p["state"] != "open":
		if a.has("item"):
			Net.grant(peer, [Items.make(a["item"], int(a["n"]))], true)
		return
	if a.has("coins"):
		var c: int = min(int(a["coins"]), int(pd["coins"]) - int(p["coins"]), Game.money())
		if c > 0:
			srv.add_money(-c, "project")
			p["coins"] = int(p["coins"]) + c
	elif a.has("item"):
		var id: String = a["item"]
		var need := int(pd["needs"].get(id, 0)) - int(p["have"].get(id, 0))
		var n: int = min(int(a["n"]), need)
		if n < int(a["n"]):
			Net.grant(peer, [Items.make(id, int(a["n"]) - max(0, n))], true)
		if n > 0:
			p["have"][id] = int(p["have"].get(id, 0)) + n
	var done: bool = int(p["coins"]) >= int(pd["coins"])
	for id in pd["needs"]:
		if int(p["have"].get(id, 0)) < int(pd["needs"][id]):
			done = false
	if done:
		p["state"] = "funded"
		srv._toast("The %s is fully supplied! Work begins tonight." % pd["name"], Color("ffe08a"))
		srv.chronicle("%s gave the last of what the %s needed." % [srv.pname(peer), pd["name"]], "project")
	set_town("projects", projs)

func a_donate_curio(peer: int, a: Dictionary) -> void:
	var id: String = a["item"]
	var don: Dictionary = town().get("donated", {}).duplicate(true)
	if don.has(id) or not (Items.def(id).get("curio", false) or Items.cat_of(id) == "gem"):
		Net.grant(peer, [Items.make(id)], true)
		return
	don[id] = {"by": srv.pname(peer), "day": Game.day()}
	set_town("donated", don)
	srv.add_money(Items.def(id)["price"] * 2, "donation")
	town()["prosperity"] = int(town().get("prosperity", 0)) + 5
	srv._toast("%s donated a %s to the Curio Hall." % [srv.pname(peer), Items.def(id)["name"]], Color("ffe08a"))
	srv.chronicle("%s donated a %s to the Curio Hall." % [srv.pname(peer), Items.def(id)["name"]], "find")

func a_reforge(peer: int, a: Dictionary) -> void:
	var it: Dictionary = a["item"]
	var cost = 300 + Items.def(it["id"]).get("price", 100)
	if Game.money() < cost or not Game.world["flags"].get("project_smithy", false):
		Net.grant(peer, [it], true)
		return
	srv.add_money(-cost, "reforge")
	var r := RandomNumberGenerator.new()
	r.randomize()
	var tr := Items.random_traits(it["id"], r, 1 if r.randf() < 0.6 else 2)
	var out: Dictionary = Items.make(it["id"], 1, {"tr": tr, "nm": Items.traited_name(it["id"], tr)})
	Net.grant(peer, [out])

func a_crack_geode(peer: int, a: Dictionary) -> void:
	var n: int = int(a.get("n", 1))
	if Game.money() < 25 * n:
		Net.grant(peer, [Items.make("geode", n)], true)
		return
	srv.add_money(-25 * n, "geode")
	var r := RandomNumberGenerator.new()
	r.randomize()
	var out: Array = []
	for i in n:
		var x := r.randf()
		if x < 0.5:
			out.append(Items.make(Loot.gem_for_depth(12, r)))
		elif x < 0.8:
			out.append(Items.make(["iron_ore", "silver_ore", "gold_ore", "coal"][r.randi() % 4], r.randi_range(2, 5)))
		elif x < 0.95:
			out.append(Items.make("crystal_shard", r.randi_range(1, 3)))
		else:
			out.append(Items.make(["fossil_shell", "dragon_tooth", "ancient_coin"][r.randi() % 3]))
	Net.grant(peer, out)

func a_upgrade_tool(peer: int, a: Dictionary) -> void:
	var it: Dictionary = a["item"]
	var d := Items.def(it["id"])
	if not d.has("tool"):
		Net.grant(peer, [it], true)
		return
	var tier := int(d["tool"]["tier"])
	var kind: String = d["tool"]["kind"]
	var next := "%s_%d" % [kind, tier + 1]
	if not Items.has(next):
		Net.grant(peer, [it], true)
		return
	var cost = [400, 1200, 3000, 8000][min(tier, 3)]
	if Game.money() < cost:
		Net.grant(peer, [it], true)
		Net.tell(peer, "toast", {"text": "Not enough coins.", "color": Color("ff9a7a")})
		return
	srv.add_money(-cost, "upgrade")
	var out := Items.make(next, 1, it.get("d", {}))
	if out.has("d") and out["d"].has("tr"):
		out["d"]["nm"] = Items.traited_name(next, out["d"]["tr"])
	Net.grant(peer, [out])
	srv.chronicle("%s had their %s upgraded at the smithy." % [srv.pname(peer), Items.def(it["id"])["name"].to_lower()], "trade")

# ------------------------------------------------------------------ friendship milestones

func _check_milestone(npc_id: String, player: String, h: int, peer: int) -> void:
	if h not in [2, 4, 6, 8]:
		return
	var ms: Dictionary = town().get("milestones", {}).duplicate(true)
	var key := "%s|%s" % [npc_id, player]
	if int(ms.get(key, 0)) >= h:
		return
	ms[key] = h
	set_town("milestones", ms)
	var npc := _npc(npc_id)
	if npc.is_empty():
		return
	var gift := _milestone_gift(npc, h)
	if gift.is_empty():
		return
	var gift_name := ""
	if gift.has("recipe"):
		var rid: String = gift["recipe"]
		if not Game.knows_recipe(rid):
			srv._ch({"t": "recipe", "id": rid, "by": npc["first"]})
		gift_name = "the recipe for " + Items.def(rid)["name"]
	else:
		Net.grant(peer, [gift])
		gift_name = Items.display_name(gift)
	Net.tell(peer, "npc_gift", {"npc": npc_id, "text": Dialogue.heart_gift_text(npc, h, gift_name)})
	if h >= 6:
		srv.chronicle("%s and %s have become close friends." % [player, npc["first"]], "people")

func _milestone_gift(npc: Dictionary, h: int) -> Dictionary:
	var r := Game.rng_for("milestone", npc["id"].hash(), h)
	var ints: Array = npc["interests"]
	if "cooking" in ints or "baking" in ints or npc["role"] in ["innkeeper", "chef", "baker"]:
		var unknown: Array = []
		for rc in Items.cook_recipes:
			if not Game.knows_recipe(rc["id"]):
				unknown.append(rc["id"])
		if not unknown.is_empty():
			return {"recipe": unknown[r.randi() % unknown.size()]}
	if "fishing" in ints or npc["role"] == "angler":
		return [Items.make("deluxe_bait", 10), Items.make("fish_charm"), Items.make("angler_cap"), Items.make("magnet_lure", 3)][min(3, h / 2 - 1)]
	if "metals" in ints or npc["role"] == "smith":
		return [Items.make("iron_bar", 5), Items.make("work_boots"), Loot.equipment(3, r, "weapon"), Items.make("gold_bar", 4)][min(3, h / 2 - 1)]
	if "brewing" in ints or npc["role"] == "herbalist":
		return [Items.make("brew_vigor_1", 3), Items.make("brew_prospector", 2), Items.make("glowcap_seeds", 4), Items.make("brew_bulwark", 2)][min(3, h / 2 - 1)]
	if "gardening" in ints or "flowers" in ints:
		return [Items.make("strawberry_seeds", 10), Items.make("apple_sapling"), Items.make("straw_hat"), Items.make("crystalbloom_seeds", 2)][min(3, h / 2 - 1)]
	if "caves" in ints or "exploring" in ints:
		return [Items.make("escape_rope", 3), Items.make("miners_helmet"), Loot.equipment(3, r, "gear"), Items.make("featherstep_boots")][min(3, h / 2 - 1)]
	var liked: Array = npc.get("likes", [])
	if not liked.is_empty():
		return Items.make(liked[r.randi() % liked.size()], 3)
	return Items.make("honey_cake", 2)
