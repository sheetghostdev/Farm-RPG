class_name QuestLogic
extends RefCounted
## The town request board. Residents post small jobs that send the group out into
## the world: deliveries, fish, lost keepsakes on cave floors, pests, places to see.

var srv: ServerLogic

const ENEMY_NAMES := {"bat": "Cave Bats", "burrower": "Burrowers", "beetle": "Shellbacks", "slime": "Mosslings", "spitter": "Spore Spitters",
	"golem": "Crystal Golems", "salamander": "Ember Salamanders", "sentinel": "Ancient Sentinels"}
const KEEPSAKES := ["lost_pick", "lost_satchel", "survey_marker", "lost_charm", "expedition_journal"]

func _init(s: ServerLogic) -> void:
	srv = s

static func quests() -> Dictionary:
	return Game.world.get("quests", {"active": [], "done": [], "next_id": 1})

func _publish() -> void:
	srv._ch({"t": "quests", "v": Game.world["quests"]})

static func enemies_for_floor(f: int) -> Array:
	if f <= 5:
		return ["bat", "burrower", "beetle"]
	if f <= 10:
		return ["slime", "bat", "beetle"]
	if f <= 15:
		return ["golem", "bat", "slime"]
	if f <= 20:
		return ["spitter", "slime", "burrower"]
	if f <= 25:
		return ["salamander", "beetle", "bat"]
	return ["sentinel", "golem", "salamander"]

func new_day(day: int) -> void:
	var q := quests()
	var keep: Array = []
	for r in q["active"]:
		if int(r.get("expires", 9999)) >= day:
			keep.append(r)
	q["active"] = keep
	var cap = 4 + min(2, int(Game.world.get("town", {}).get("level", 0)) / 2)
	var rng := Game.rng_for("requests", day)
	var tries := 0
	var added := 0
	while q["active"].size() < cap and tries < 12 and added < 2:
		tries += 1
		var r := _make(rng, day, int(q.get("next_id", 1)))
		if r.is_empty():
			continue
		var dup := false
		for o in q["active"]:
			if o["npc"] == r["npc"] or (o["type"] == r["type"] and o.get("item", "") == r.get("item", "")):
				dup = true
		if dup:
			continue
		q["next_id"] = int(q.get("next_id", 1)) + 1
		q["active"].append(r)
		added += 1
	Game.world["quests"] = q

func _make(rng: RandomNumberGenerator, day: int, qid: int) -> Dictionary:
	var town := Zones.town
	if town == null or town.residents.is_empty():
		return {}
	var npc: Dictionary = town.residents[rng.randi() % town.residents.size()]
	var deepest := int(Game.world["know"].get("deepest", 0))
	var types := ["deliver", "deliver", "deliver", "fish", "fish", "explore", "brew"]
	if deepest >= 1:
		types.append_array(["slay", "slay"])
	if deepest >= 2:
		types.append_array(["fetch", "fetch"])
	var t: String = types[rng.randi() % types.size()]
	var r := {"qid": qid, "type": t, "npc": npc["id"], "day": day, "expires": day + 7, "progress": 0, "count": 1}
	match t:
		"deliver":
			var pool: Array = []
			for i in npc["interests"]:
				for it in TownGen.INTEREST_ITEMS.get(i, []):
					if Items.has(it) and Items.cat_of(it) not in ["curio", "gem", "brew"] and int(Items.def(it)["price"]) < 250:
						pool.append(it)
			for c in Items.crops:
				if Game.season() in Items.crops[c]["seasons"] and not Items.crops[c]["perennial"]:
					pool.append(c)
			if pool.is_empty():
				return {}
			var it: String = pool[rng.randi() % pool.size()]
			var price := int(Items.def(it)["price"])
			var n := 1
			if price < 15:
				n = rng.randi_range(8, 15)
			elif price < 40:
				n = rng.randi_range(3, 8)
			elif price < 100:
				n = rng.randi_range(2, 4)
			r["item"] = it
			r["count"] = n
			r["reward"] = price * n * 2 + 60
		"fish":
			var pool2: Array = []
			for kind in ["river", "lake", "pond"]:
				for f in Items.fish_for(kind, Game.season(), false, false):
					if not pool2.has(f) and int(Items.def(f)["price"]) < 120:
						pool2.append(f)
			if pool2.is_empty():
				return {}
			var fid: String = pool2[rng.randi() % pool2.size()]
			r["item"] = fid
			r["reward"] = int(Items.def(fid)["price"]) * 3 + 90
		"brew":
			var e: String = Items.ESSENCES[rng.randi() % Items.ESSENCES.size()]
			r["item"] = "brew_%s_0" % e
			r["reward"] = int(Items.def(r["item"])["price"]) * 3 + 120
		"fetch":
			var f2 := rng.randi_range(2, min(29, max(2, deepest + 2)))
			r["floor"] = f2
			r["item"] = KEEPSAKES[rng.randi() % KEEPSAKES.size()]
			r["reward"] = 200 + 45 * f2
			r["expires"] = day + 10
		"slay":
			var f3 := rng.randi_range(max(1, deepest - 3), max(1, deepest))
			var es := enemies_for_floor(f3)
			r["enemy"] = es[rng.randi() % es.size()]
			r["floor"] = f3
			r["count"] = rng.randi_range(5, 9)
			r["reward"] = 150 + 25 * int(r["count"]) + 10 * f3
		"explore":
			var g := Zones.overworld_gen()
			var cands: Array = []
			for p in g.pois:
				if not Game.world["know"]["places"].has(p["id"]) and p.get("name", "") != "" and p["type"] not in ["river", "lake"]:
					cands.append(p)
			if cands.is_empty():
				return {}
			var p2: Dictionary = cands[rng.randi() % cands.size()]
			r["place"] = p2["id"]
			r["place_name"] = p2["name"]
			r["reward"] = 140
	if r.has("item"):
		r["item_name"] = Items.def(r["item"])["name"]
	if r.has("enemy"):
		r["enemy_name"] = ENEMY_NAMES.get(r["enemy"], r["enemy"])
	r["text"] = Dialogue.request_text(npc, {"type": t, "item": r.get("item", ""), "item_name": r.get("item_name", ""), "count": r["count"],
		"floor": r.get("floor", 0), "enemy": r.get("enemy_name", ""), "place": r.get("place_name", "")})
	return r

static func title(r: Dictionary) -> String:
	match r["type"]:
		"deliver":
			return "Bring %d %s" % [int(r["count"]), r.get("item_name", "")] if int(r["count"]) > 1 else "Bring a %s" % r.get("item_name", "")
		"fish":
			return "Catch a %s" % r.get("item_name", "")
		"brew":
			return "Brew a %s" % r.get("item_name", "")
		"fetch":
			return "Recover the %s from floor %d" % [r.get("item_name", ""), int(r.get("floor", 1))]
		"slay":
			return "Thin out %s near floor %d (%d/%d)" % [r.get("enemy_name", ""), int(r.get("floor", 1)), int(r.get("progress", 0)), int(r["count"])]
		"explore":
			return "Visit %s%s" % [r.get("place_name", ""), " (done!)" if int(r.get("progress", 0)) >= 1 else ""]
	return "Request"

static func ready_to_report(r: Dictionary) -> bool:
	if r["type"] == "slay":
		return int(r.get("progress", 0)) >= int(r["count"])
	if r["type"] == "explore":
		return int(r.get("progress", 0)) >= 1 or Game.world["know"]["places"].has(r.get("place", ""))
	return false

static func for_npc(npc_id: String) -> Array:
	var out: Array = []
	for r in quests().get("active", []):
		if r["npc"] == npc_id:
			out.append(r)
	return out

## Active "fetch" requests whose keepsake lies on this floor.
static func fetch_items_for_floor(f: int) -> Array:
	var out: Array = []
	for r in quests().get("active", []):
		if r["type"] == "fetch" and int(r.get("floor", 0)) == f:
			out.append(r)
	return out

func on_kill(peer: int, etype: String, zid: String) -> void:
	var f := Zones.floor_of(zid)
	var changed := false
	for r in quests()["active"]:
		if r["type"] == "slay" and r["enemy"] == etype and abs(f - int(r["floor"])) <= 3 and int(r["progress"]) < int(r["count"]):
			r["progress"] = int(r["progress"]) + 1
			changed = true
			if int(r["progress"]) >= int(r["count"]):
				Net.tell(peer, "toast", {"text": "Request done: report back to %s." % Zones.town.resident(r["npc"]).get("first", "them"), "color": Color("ffe08a")})
	if changed:
		_publish()

func on_discover(place_id: String) -> void:
	var changed := false
	for r in quests()["active"]:
		if r["type"] == "explore" and r.get("place", "") == place_id and int(r["progress"]) < 1:
			r["progress"] = 1
			changed = true
	if changed:
		_publish()

## A player hands over the goods (client already removed them) or reports back.
func a_quest_turn_in(peer: int, a: Dictionary) -> void:
	var qid := int(a["qid"])
	var q := quests()
	var r: Dictionary = {}
	for x in q["active"]:
		if int(x["qid"]) == qid:
			r = x
	if r.is_empty():
		if a.has("returned"):
			Net.grant(peer, a["returned"], true)
		return
	if r["type"] in ["slay", "explore"] and not ready_to_report(r):
		return
	q["active"].erase(r)
	q["done"].append({"qid": qid, "npc": r["npc"], "title": title(r), "by": srv.pname(peer), "day": Game.day()})
	if q["done"].size() > 60:
		q["done"].remove_at(0)
	_publish()
	srv.add_money(int(r.get("reward", 100)), "request")
	srv.town_logic._add_friend(r["npc"], srv.pname(peer), 70, peer)
	Game.world["town"]["prosperity"] = int(Game.world["town"].get("prosperity", 0)) + 10
	var npc: Dictionary = Zones.town.resident(r["npc"])
	Net.tell(peer, "npc_say", {"npc": r["npc"], "text": Dialogue.request_thanks(npc, r, TownUI.context_for(npc, srv.pname(peer)))})
	Net.tell(peer, "sfx", {"s": "quest"})
	srv._toast("%s finished %s's request: +%d coins" % [srv.pname(peer), npc.get("first", "a neighbor"), int(r.get("reward", 100))], Color("ffd36b"))
	srv.chronicle("%s helped %s: %s." % [srv.pname(peer), npc.get("first", "a neighbor"), title(r).to_lower()], "people")
	if r["type"] == "fetch" and rng_bonus(qid):
		Net.grant(peer, [Loot.equipment(Loot.tier_for_depth(int(r.get("floor", 3))), srv.rng)])

func rng_bonus(qid: int) -> bool:
	return Game.rng_for("qbonus", qid).randf() < 0.4
