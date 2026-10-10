class_name ServerLogic
extends RefCounted
## Authoritative game rules. Only the host runs this. Each request "x" from a
## peer is handled by _a_x(peer, args), which validates it, then broadcasts
## changes and grants items.

var rng := RandomNumberGenerator.new()
var town_logic: TownLogic
var quest_logic: QuestLogic

func _init() -> void:
	rng.randomize()
	town_logic = TownLogic.new(self)
	quest_logic = QuestLogic.new(self)

func handle(peer: int, action: String, args: Dictionary) -> void:
	var m := "_a_" + action
	if has_method(m):
		call(m, peer, args)
	elif town_logic.has_method("a_" + action):
		town_logic.call("a_" + action, peer, args)
	elif quest_logic.has_method("a_" + action):
		quest_logic.call("a_" + action, peer, args)
	else:
		push_warning("Unknown action " + action)

func _ch(ch: Dictionary) -> void:
	Net.broadcast(ch)

func _toast(text: String, col: Color = Color.WHITE, peer: int = 0) -> void:
	if peer == 0:
		_ch({"t": "toast", "text": text, "color": col})
	else:
		Net.tell(peer, "toast", {"text": text, "color": col})

func add_money(n: int, _why: String) -> void:
	_ch({"t": "money", "v": max(0, Game.money() + n)})

func chronicle(text: String, kind: String = "event") -> void:
	_ch({"t": "chronicle", "v": {"d": Game.day(), "s": text, "k": kind}})

func pname(peer: int) -> String:
	return Net.name_of(peer)

func zone_obj(zid: String, oid: String):
	var z := Zones.get_zone(zid)
	if z == null:
		return null
	return z.objs.get(oid)

# ------------------------------------------------------------------ world setup

## Called once when a brand new world is created (after the overworld is generated).
func init_new_world() -> void:
	var g := Zones.overworld_gen()
	var fc := g.farm_rect.get_center()
	var hp := Vector3(fc.x, g.farm_h, g.farm_rect.position.y + 6.5)
	_new_obj("chest", "over", hp + Vector3(6.5, 0, 1.5), 0, {"items": [Items.make("wood", 30), Items.make("stone", 15), Items.make("turnip_seeds", 8), Items.make("bandage", 3)]}, false)
	_new_obj("workbench", "over", hp + Vector3(8.5, 0, 1.5), 0, {}, false)
	_new_obj("bed", "home", Vector3(-2000 + 3.5, 0, -2.0), 0, {}, false)
	_new_obj("chest", "home", Vector3(-2000 - 3.5, 0, -2.6), 0, {"items": []}, false)
	_new_obj("table", "home", Vector3(-2000, 0, 0.5), 0, {}, false)
	_new_obj("chair", "home", Vector3(-2000 + 0.9, 0, 0.5), 3, {}, false)
	_new_obj("rug", "home", Vector3(-2000, 0, 0.6), 0, {"v": 0}, false)
	# a few tilled tiles and a little starter patch so the first morning has something to do
	var tiles := {}
	for dx in 4:
		for dz in 3:
			var k := Vector2i(int(fc.x) - 2 + dx, int(fc.y) + 6 + dz)
			tiles[k] = {"till": true, "wet": false}
	Game.world["farm"]["tiles"] = tiles
	Game.world["know"]["recipes"]["chest"] = {"day": 1, "by": ""}
	for id in ["wood", "stone", "turnip_seeds", "bandage"]:
		Game.world["know"]["items"][id] = {"day": 1, "by": "", "known": Items.def(id).get("known", false)}
	Game.world["chronicle"].append({"d": 1, "s": "A small group arrived at an overgrown homestead near %s." % TownGen.town_name(), "k": "founding"})

func _new_obj(item: String, zid: String, pos: Vector3, rot: int, d: Dictionary, broadcast: bool = true) -> String:
	var oid := "o%d" % int(Game.world["next_oid"])
	Game.world["next_oid"] = int(Game.world["next_oid"]) + 1
	var o := {"t": item, "z": zid, "p": pos, "r": rot, "d": d}
	if broadcast:
		_ch({"t": "obj_add", "id": oid, "v": o})
	else:
		Game.world["objects"][oid] = o
	return oid

func on_player_joined(peer: int, nm: String) -> void:
	if not Game.world["flags"].has("met_" + nm):
		Game.world["flags"]["met_" + nm] = true
		if Game.day() > 1:
			chronicle("%s joined the household." % nm, "people")

func on_player_left(_peer: int, _nm: String) -> void:
	pass

# ------------------------------------------------------------------ knowledge & exploration

func _a_know_item(peer: int, a: Dictionary) -> void:
	var id: String = a["id"]
	if Game.is_seen(id) or not Items.has(id):
		return
	_ch({"t": "know_item", "id": id, "by": a.get("by", pname(peer))})
	var c := Items.cat_of(id)
	if c in ["gem", "curio"] or (Items.def(id).has("weapon") == false and Items.def(id).get("price", 0) >= 150 and c != "food"):
		chronicle("%s found the group's first %s." % [pname(peer), Items.def(id)["name"]], "find")

func _a_learn_item(peer: int, a: Dictionary) -> void:
	var id: String = a["id"]
	if Game.is_known(id) or not Items.has(id):
		return
	_ch({"t": "learn_item", "id": id, "by": a.get("by", pname(peer))})

func _a_chronicle(peer: int, a: Dictionary) -> void:
	chronicle(String(a.get("s", "")).substr(0, 200), a.get("k", "event"))

func _a_discover_place(peer: int, a: Dictionary) -> void:
	var id: String = a["id"]
	if Game.world["know"]["places"].has(id):
		return
	_ch({"t": "place", "id": id, "v": {"day": Game.day(), "by": pname(peer), "name": a.get("name", "")}})
	_toast("%s discovered %s" % [pname(peer), a.get("name", "somewhere new")], Color("ffe08a"))
	Net.tell(peer, "sfx", {"s": "discovery"})
	chronicle("%s discovered %s." % [pname(peer), a.get("name", "")], "place")
	quest_logic.on_discover(id)
	Net.tell(peer, "stat", {"k": "places_found", "n": 1})

func _a_explore(_peer: int, a: Dictionary) -> void:
	var cells: PackedInt32Array = a["cells"]
	if cells.size() > 400:
		return
	_ch({"t": "explored", "v": cells})

func _a_cave_explore(_peer: int, a: Dictionary) -> void:
	var cells: PackedInt32Array = a["cells"]
	if cells.size() > 2000:
		return
	_ch({"t": "cave_seen", "f": int(a["f"]), "v": cells})

func _a_enter_zone(peer: int, a: Dictionary) -> void:
	Zones.server_enter_zone(peer, a["z"])

# ------------------------------------------------------------------ gathering

func _a_harvest_node(peer: int, a: Dictionary) -> void:
	var zid: String = a["z"]
	var o = zone_obj(zid, a["id"])
	if o == null or not (o is ResourceNode):
		return
	var r := ResourceNode.info(o.sub)
	if a.get("berry", false):
		if not o.berries_ready:
			return
		_ch({"t": "removed", "z": zid, "id": "b:" + o.oid, "day": Game.day()})
		Net.grant(peer, o.roll_drops(rng, 1))
		return
	var resp: int = r.get("respawn", -1)
	_ch({"t": "removed", "z": zid, "id": o.oid, "day": Game.day()})
	var drops: Array = o.roll_drops(rng, int(a.get("mult", 1)))
	if o.shares_loot():
		Zones.spawn_pickups(zid, o.global_position + Vector3(0, 0.8, 0), drops)
		if o.sub.begins_with("chest") or o.sub in ["crate_loot", "tower_chest"]:
			Net.tell(peer, "sfx", {"s": "chest_open"})
	else:
		var money := 0
		var items: Array = []
		for it in drops:
			if it["id"] == "$money":
				money += int(it["n"])
			else:
				items.append(it)
		if money > 0:
			add_money(money, "found")
		Net.grant(peer, items)
	if o.sub == "cracked_wall":
		chronicle("%s broke through a cracked wall on floor %d." % [pname(peer), Zones.floor_of(zid)], "find")
	if r.get("note", false):
		var z := Zones.get_zone(zid)
		if z and z.has_method("note_for"):
			Net.tell(peer, "note", {"i": z.note_for(o.oid)})

func _a_take_pickup(peer: int, a: Dictionary) -> void:
	Zones.take_pickup_server(peer, int(a["pid"]))

func _a_drop_item(_peer: int, a: Dictionary) -> void:
	var it: Dictionary = a["item"]
	if it.is_empty():
		return
	Zones.spawn_pickups(a["zone"], a["pos"], [it], 0.6)

# ------------------------------------------------------------------ farming

func _tiles() -> Dictionary:
	return Game.world["farm"]["tiles"]

func _over() -> Overworld:
	return Zones.get_zone("over") as Overworld

func _a_till(peer: int, a: Dictionary) -> void:
	var farm := _over().farm
	var changed := {}
	for k in a["tiles"]:
		if _tiles().size() > 3000:
			break
		if not _tiles().has(k) and farm.can_till(k):
			changed[k] = {"till": true, "wet": Game.is_raining()}
	if not changed.is_empty():
		_ch({"t": "tiles", "v": changed})

func _a_untill(_peer: int, a: Dictionary) -> void:
	var k: Vector2i = a["k"]
	if _tiles().has(k) and not _tiles()[k].has("crop"):
		_ch({"t": "tile", "k": k, "v": {}})

func _a_water(_peer: int, a: Dictionary) -> void:
	var changed := {}
	for k in a["tiles"]:
		if _tiles().has(k) and not _tiles()[k].get("wet", false):
			var tv: Dictionary = _tiles()[k].duplicate(true)
			tv["wet"] = true
			if a.get("gt", false):
				tv["gt"] = true
			changed[k] = tv
	if not changed.is_empty():
		_ch({"t": "tiles", "v": changed})

func _a_water_all(_peer: int, _a: Dictionary) -> void:
	var changed := {}
	for k in _tiles():
		var tv: Dictionary = _tiles()[k].duplicate(true)
		tv["wet"] = true
		changed[k] = tv
	_ch({"t": "tiles", "v": changed})
	_toast("A soft rain falls over the fields.", Color("bfe3ff"))

func _a_plant(peer: int, a: Dictionary) -> void:
	var k: Vector2i = a["k"]
	var crop: String = a["crop"]
	if not _tiles().has(k) or _tiles()[k].has("crop") or not Items.crops.has(crop):
		Net.grant(peer, [Items.make(crop + "_seeds")], true)
		return
	var tv: Dictionary = _tiles()[k].duplicate(true)
	tv["crop"] = {"id": crop, "g": 0, "by": a.get("by", pname(peer)), "planted": Game.day()}
	_ch({"t": "tile", "k": k, "v": tv})
	if Items.crops[crop]["perennial"] and not Game.world["flags"].has("planted_" + crop):
		Game.world["flags"]["planted_" + crop] = true
		chronicle("%s planted %s from the deep at the farm." % [pname(peer), Items.def(crop)["name"]], "farm")

func _a_harvest(peer: int, a: Dictionary) -> void:
	var k: Vector2i = a["k"]
	if not _tiles().has(k):
		return
	var tv: Dictionary = _tiles()[k].duplicate(true)
	var farm := _over().farm
	if farm.crop_stage(tv) != 4:
		return
	var crop: String = tv["crop"]["id"]
	var cd: Dictionary = Items.crops[crop]
	var y: Array = cd["yield"]
	var n := rng.randi_range(int(y[0]), int(y[1]))
	if rng.randf() < 0.1:
		n += 1
	var regrow := int(cd["regrow"])
	if regrow > 0:
		tv["crop"]["g"] = int(cd["total"]) - regrow
	else:
		tv.erase("crop")
	_ch({"t": "tile", "k": k, "v": tv})
	Net.grant(peer, [Items.make(crop, n)])
	Net.tell(peer, "stat", {"k": "crops_harvested", "n": n})
	var key := "harvest_" + crop
	if not Game.world["flags"].has(key):
		Game.world["flags"][key] = true
		chronicle("%s harvested the farm's first %s." % [pname(peer), Items.def(crop)["name"]], "farm")

func _a_clear_crop(_peer: int, a: Dictionary) -> void:
	var k: Vector2i = a["k"]
	if _tiles().has(k):
		var tv: Dictionary = _tiles()[k].duplicate(true)
		tv.erase("crop")
		_ch({"t": "tile", "k": k, "v": tv})

func _a_grow_area(_peer: int, a: Dictionary) -> void:
	var p: Vector3 = a["pos"]
	var r: float = a["r"]
	var changed := {}
	for k in _tiles():
		var tv: Dictionary = _tiles()[k]
		if not tv.has("crop") or tv["crop"].get("dead", false):
			continue
		if Vector2(k.x + 0.5 - p.x, k.y + 0.5 - p.z).length() > r:
			continue
		var t2: Dictionary = tv.duplicate(true)
		var cd: Dictionary = Items.crops[t2["crop"]["id"]]
		t2["crop"]["g"] = min(int(cd["total"]), int(t2["crop"]["g"]) + 1)
		changed[k] = t2
	if not changed.is_empty():
		_ch({"t": "tiles", "v": changed})
	# fruit trees nearby grow too
	for oid in Game.world["objects"]:
		var o: Dictionary = Game.world["objects"][oid]
		if o["z"] == "over" and o["t"].ends_with("_sapling") and Vector3(o["p"]).distance_to(p) < r:
			var d: Dictionary = o["d"].duplicate(true)
			d["planted"] = int(d.get("planted", Game.day())) - 4
			_ch({"t": "obj_data", "id": oid, "v": d})

# ------------------------------------------------------------------ placed objects

func _a_place_obj(peer: int, a: Dictionary) -> void:
	var id: String = a["item"]
	if not Items.has(id) or not Items.def(id).has("place"):
		return
	var zid: String = a["z"]
	var pos: Vector3 = a["p"]
	for oid in Game.world["objects"]:
		var o: Dictionary = Game.world["objects"][oid]
		if o["z"] == zid and Vector3(o["p"]).distance_to(pos) < 0.45 and Items.def(o["t"])["place"]["obj"] not in ["stone_path", "wood_path", "rug"]:
			Net.grant(peer, [Items.make(id)], true)
			return
	var d: Dictionary = a.get("d", {})
	var obj: String = Items.def(id)["place"]["obj"]
	if obj in ["chest", "big_chest", "shed"]:
		d["items"] = []
	if obj == "coop":
		d["feed"] = 0
		d["eggs"] = 0
	if obj == "beehive":
		d["last"] = Game.day()
	if obj in ["rug", "banner", "flower_pot"]:
		d["v"] = rng.randi() % 4
	_new_obj(id, zid, pos, int(a.get("r", 0)), d)
	if obj in ["coop", "shed"] or id.ends_with("_sapling"):
		var key := "built_" + obj + ("_" + id if id.ends_with("_sapling") else "")
		if not Game.world["flags"].has(key):
			Game.world["flags"][key] = true
			chronicle("%s put up a %s on the farm." % [pname(peer), Items.def(id)["name"].to_lower()], "farm")

func _a_pickup_obj(peer: int, a: Dictionary) -> void:
	var oid: String = a["id"]
	if not Game.world["objects"].has(oid):
		return
	var o: Dictionary = Game.world["objects"][oid]
	var d: Dictionary = o.get("d", {})
	if not d.get("items", []).is_empty() or d.has("res") or d.has("bar"):
		return
	_ch({"t": "obj_del", "id": oid})
	var back: Array = []
	if o["t"].ends_with("_sapling"):
		var stage := int((Game.day() - int(d.get("planted", Game.day()))) / 3.5)
		if stage >= 4:
			back.append(Items.make("wood", 8))
			back.append(Items.make("hardwood", 2))
		else:
			back.append(Items.make(o["t"]))
	else:
		back.append(Items.make(o["t"]))
	if d.has("item"):
		back.append(d["item"])
	Net.grant(peer, back)

func _obj(oid: String) -> Dictionary:
	return Game.world["objects"].get(oid, {})

func _set_data(oid: String, d: Dictionary) -> void:
	_ch({"t": "obj_data", "id": oid, "v": d})

## Chest contents are a flat list of stacks (merged on insert).
func _a_chest_put(peer: int, a: Dictionary) -> void:
	var o := _obj(a["id"])
	var it: Dictionary = a["item"]
	if o.is_empty() or it.is_empty():
		Net.grant(peer, [it], true)
		return
	var d: Dictionary = o["d"].duplicate(true)
	var items: Array = d.get("items", [])
	var cap: int = PlacedObj.CAPACITY.get(Items.def(o["t"])["place"]["obj"], 36)
	var left := int(it["n"])
	var mx := Items.stack_max(it["id"])
	for s in items:
		if left <= 0:
			break
		if Items.can_stack(s, it) and int(s["n"]) < mx:
			var put: int = min(mx - int(s["n"]), left)
			s["n"] = int(s["n"]) + put
			left -= put
	while left > 0 and items.size() < cap:
		var ns: Dictionary = it.duplicate(true)
		ns["n"] = min(mx, left)
		left -= int(ns["n"])
		items.append(ns)
	d["items"] = items
	_set_data(a["id"], d)
	if left > 0:
		var back: Dictionary = it.duplicate(true)
		back["n"] = left
		Net.grant(peer, [back], true)
		Net.tell(peer, "toast", {"text": "That chest is full.", "color": Color("ffb08a")})

func _a_chest_take(peer: int, a: Dictionary) -> void:
	var o := _obj(a["id"])
	if o.is_empty():
		return
	var d: Dictionary = o["d"].duplicate(true)
	var items: Array = d.get("items", [])
	var idx := int(a["idx"])
	if idx < 0 or idx >= items.size():
		return
	var s: Dictionary = items[idx]
	if a.has("expect") and s["id"] != a["expect"]:
		return
	var n: int = min(int(a.get("n", s["n"])), int(s["n"]))
	var out: Dictionary = s.duplicate(true)
	out["n"] = n
	s["n"] = int(s["n"]) - n
	if int(s["n"]) <= 0:
		items.remove_at(idx)
	d["items"] = items
	_set_data(a["id"], d)
	Net.grant(peer, [out], true)

func _a_chest_sort(_peer: int, a: Dictionary) -> void:
	var o := _obj(a["id"])
	if o.is_empty():
		return
	var d: Dictionary = o["d"].duplicate(true)
	var items: Array = d.get("items", [])
	var merged: Array = []
	for it in items:
		var placed := false
		for m in merged:
			if Items.can_stack(m, it) and int(m["n"]) < Items.stack_max(m["id"]):
				var room: int = Items.stack_max(m["id"]) - int(m["n"])
				var put: int = min(room, int(it["n"]))
				m["n"] = int(m["n"]) + put
				it["n"] = int(it["n"]) - put
				if int(it["n"]) <= 0:
					placed = true
					break
		if not placed:
			merged.append(it)
	merged.sort_custom(func(x, y):
		var cx := Items.cat_of(x["id"])
		var cy := Items.cat_of(y["id"])
		if cx != cy:
			return cx < cy
		return Items.display_name(x) < Items.display_name(y))
	d["items"] = merged
	_set_data(a["id"], d)

func _a_furnace_load(peer: int, a: Dictionary) -> void:
	var o := _obj(a["id"])
	var ore: String = a["ore"]
	var n := int(a["n"])
	if o.is_empty() or o["d"].has("bar") or not Items.smelt.has(ore) or n <= 0:
		Net.grant(peer, [Items.make(ore, n * 3), Items.make("coal", n)], true)
		return
	var d: Dictionary = o["d"].duplicate(true)
	d["bar"] = Items.smelt[ore]
	d["n"] = n
	d["done"] = Game.total_minutes() + 50.0 * n
	_set_data(a["id"], d)

func _a_kettle_brew(peer: int, a: Dictionary) -> void:
	var o := _obj(a["id"])
	var ings: Array = a["ings"]
	if o.is_empty() or o["d"].has("res") or ings.is_empty():
		var back: Array = []
		for i in ings:
			back.append(Items.make(i))
		Net.grant(peer, back, true)
		return
	var res := Items.brew_result(ings)
	var d: Dictionary = o["d"].duplicate(true)
	d["res"] = res
	d["n"] = 1 if not Items.cat_of(res) == "drink" else 2
	d["done"] = Game.total_minutes() + 90.0
	d["by"] = pname(peer)
	d["ings"] = ings
	_set_data(a["id"], d)
	var key := "recipe_" + res
	if not Game.knows_recipe(res):
		_ch({"t": "recipe", "id": res, "by": pname(peer), "ings": ings})
		Net.tell(peer, "toast", {"text": "New brew discovered: %s!" % Items.def(res)["name"], "color": Color("c8ffb0")})
		if res != "brew_murky":
			chronicle("%s brewed the first %s." % [pname(peer), Items.def(res)["name"]], "brew")
	for i in ings:
		if not Game.is_known(i):
			_ch({"t": "learn_item", "id": i, "by": pname(peer)})

func _a_station_collect(peer: int, a: Dictionary) -> void:
	var oid: String = a["id"]
	var o := _obj(oid)
	if o.is_empty():
		return
	var d: Dictionary = o["d"].duplicate(true)
	var obj: String = Items.def(o["t"])["place"]["obj"]
	match obj:
		"furnace":
			if not d.has("bar") or Game.total_minutes() < float(d.get("done", 0)):
				return
			Net.grant(peer, [Items.make(d["bar"], int(d.get("n", 1)))])
			d.erase("bar")
			d.erase("n")
			d.erase("done")
		"kettle":
			if not d.has("res") or Game.total_minutes() < float(d.get("done", 0)):
				return
			Net.grant(peer, [Items.make(d["res"], int(d.get("n", 1)))])
			d.erase("res")
			d.erase("n")
			d.erase("done")
			d.erase("ings")
		"beehive":
			if Game.day() - int(d.get("last", Game.day())) < 3:
				return
			d["last"] = Game.day()
			Net.grant(peer, [Items.make("honeycomb", rng.randi_range(1, 2))])
		"fruit_tree":
			var n := int(d.get("fruit_n", 0))
			if n <= 0:
				return
			Net.grant(peer, [Items.make(d.get("fruit", "apple"), n)])
			d["fruit_n"] = 0
		"coop":
			var e := int(d.get("eggs", 0))
			if e <= 0:
				return
			Net.grant(peer, [Items.make("egg", e)])
			d["eggs"] = 0
		_:
			return
	_set_data(oid, d)

func _a_display_set(peer: int, a: Dictionary) -> void:
	var o := _obj(a["id"])
	if o.is_empty() or o["d"].has("item"):
		Net.grant(peer, [a["item"]], true)
		return
	var d: Dictionary = o["d"].duplicate(true)
	d["item"] = a["item"]
	_set_data(a["id"], d)

func _a_display_take(peer: int, a: Dictionary) -> void:
	var o := _obj(a["id"])
	if o.is_empty() or not o["d"].has("item"):
		return
	var d: Dictionary = o["d"].duplicate(true)
	var it: Dictionary = d["item"]
	d.erase("item")
	_set_data(a["id"], d)
	Net.grant(peer, [it])

func _a_coop_feed(_peer: int, a: Dictionary) -> void:
	var o := _obj(a["id"])
	if o.is_empty():
		return
	var d: Dictionary = o["d"].duplicate(true)
	d["feed"] = int(d.get("feed", 0)) + int(a["n"])
	_set_data(a["id"], d)

# ------------------------------------------------------------------ fishing

func _a_catch_fish(peer: int, a: Dictionary) -> void:
	var id: String = a["id"]
	if not Items.has(id):
		return
	var items: Array = [Items.make(id)]
	var who: String = a.get("by", pname(peer))
	if Items.cat_of(id) == "fish":
		var size := int(a.get("size", 0))
		var rec: Dictionary = Game.world["know"]["fish"].get(id, {}).duplicate(true)
		var first := rec.is_empty()
		if first:
			rec = {"n": 0, "best": 0, "by": who, "day": Game.day(), "where": a.get("z", "")}
		rec["n"] = int(rec["n"]) + 1
		var record := size > int(rec.get("best", 0)) and not first
		if size > int(rec.get("best", 0)):
			rec["best"] = size
			rec["best_by"] = who
		_ch({"t": "fish", "id": id, "v": rec})
		if first:
			var where: String = a.get("z", "")
			var place := "in the caves on floor %d" % Zones.floor_of(where) if where.begins_with("cave_") else ""
			chronicle("%s caught the group's first %s%s (%d cm)." % [who, Items.def(id)["name"], (" " + place) if place != "" else "", size], "fish")
			_toast("New fish: %s!" % Items.def(id)["name"], Color("bfe3ff"))
			_ch({"t": "learn_item", "id": id, "by": who})
		elif record and size >= 40:
			Net.tell(peer, "toast", {"text": "A new record %s: %d cm!" % [Items.def(id)["name"], size], "color": Color("ffd36b")})
		if Items.fish[id].get("legend", false):
			chronicle("%s landed a legendary %s. Nobody believes it until they see it." % [who, Items.def(id)["name"]], "fish")
	if a.get("treasure", false):
		var depth := Zones.floor_of(a.get("z", ""))
		var t := Loot.roll("chest_wood" if depth < 10 else "chest_iron", depth, rng)
		if rng.randf() < 0.12:
			t.append(Loot.equipment(Loot.tier_for_depth(max(depth, 4)), rng))
		if rng.randf() < 0.25:
			t.append(Items.make(["old_locket", "ancient_coin", "rusty_key", "star_map"][rng.randi() % 4]))
		var money := 0
		for it in t:
			if it["id"] == "$money":
				money += int(it["n"])
			else:
				items.append(it)
		if money > 0:
			add_money(money, "treasure")
		Net.tell(peer, "toast", {"text": "You pulled up a treasure chest!", "color": Color("ffd36b")})
		if rng.randf() < 0.3:
			chronicle("%s fished a treasure chest out of %s." % [who, "the deep" if str(a.get("z", "")).begins_with("cave") else "the water"], "find")
	if id == "soggy_letter":
		Net.tell(peer, "note", {"i": Lore.surface_note(rng.randi())})
	Net.grant(peer, items)

# ------------------------------------------------------------------ shipping & knowledge

func _a_ship_put(peer: int, a: Dictionary) -> void:
	var it: Dictionary = a["item"]
	if it.is_empty():
		return
	var arr: Array = Game.world["shipping"].duplicate(true)
	var merged := false
	for s in arr:
		if Items.can_stack(s, it):
			s["n"] = int(s["n"]) + int(it["n"])
			merged = true
			break
	if not merged:
		if arr.size() >= 60:
			Net.grant(peer, [it], true)
			return
		arr.append(it)
	_ch({"t": "shipping", "v": arr})
	if not Game.is_known(it["id"]):
		_ch({"t": "learn_item", "id": it["id"], "by": pname(peer)})

func _a_ship_take(peer: int, a: Dictionary) -> void:
	var arr: Array = Game.world["shipping"].duplicate(true)
	var i := int(a["idx"])
	if i < 0 or i >= arr.size():
		return
	var it: Dictionary = arr[i]
	arr.remove_at(i)
	_ch({"t": "shipping", "v": arr})
	Net.grant(peer, [it], true)

func _a_learn_recipe(peer: int, a: Dictionary) -> void:
	var id: String = a["id"]
	if Game.knows_recipe(id) or not Items.has(id):
		return
	_ch({"t": "recipe", "id": id, "by": a.get("by", pname(peer))})
	chronicle("%s worked out how to make %s." % [pname(peer), Items.def(id)["name"]], "recipe")

func _a_map_pin(peer: int, a: Dictionary) -> void:
	var pins: Array = Game.world["know"].get("pins", []).duplicate(true)
	if a.get("op", "") == "del":
		var i := int(a.get("i", -1))
		if i >= 0 and i < pins.size():
			pins.remove_at(i)
	else:
		if pins.size() >= 60:
			pins.remove_at(0)
		pins.append({"z": String(a.get("z", "over")), "p": Vector2(a.get("p", Vector2.ZERO)), "c": a.get("c", Color("ffd27a")), "by": pname(peer), "d": Game.day()})
	_ch({"t": "pins", "v": pins})

func _a_found_note(peer: int, a: Dictionary) -> void:
	var i := int(a["i"])
	if Game.world["know"]["notes"].has(i):
		return
	_ch({"t": "note", "v": i})

func _a_waystone(peer: int, a: Dictionary) -> void:
	var f := int(a["f"])
	if Game.world["know"]["waystones"].has(f):
		return
	_ch({"t": "waystone", "v": f})
	_toast("%s woke the waystone on floor %d. You can travel here from the cave mouth." % [pname(peer), f], Color("7fe3ff"))
	chronicle("%s activated the waystone on floor %d." % [pname(peer), f], "cave")

# ------------------------------------------------------------------ players

func _a_downed(peer: int, a: Dictionary) -> void:
	var zid: String = a.get("z", "")
	if zid.begins_with("cave_"):
		Net.tell(peer, "stat", {"k": "times_downed", "n": 1})

func _a_revive(peer: int, a: Dictionary) -> void:
	var target := int(a["peer"])
	Net.tell(target, "revived", {"by": a.get("by", pname(peer))})
	chronicle("%s pulled %s back to their feet on %s." % [pname(peer), pname(target), _zone_label(Net.peers.get(target, {}).get("zone", ""))], "rescue")

func _zone_label(zid: String) -> String:
	if zid.begins_with("cave_"):
		return "floor %d" % Zones.floor_of(zid)
	return "the surface"

func _a_passed_out(peer: int, a: Dictionary) -> void:
	var zid: String = a.get("z", "")
	chronicle("%s was carried home from %s, a little lighter in the pack." % [pname(peer), _zone_label(zid)], "rescue")

func _a_party_buff(peer: int, a: Dictionary) -> void:
	for id in Net.peers:
		if id != peer and Net.peers[id].get("zone", "") == a.get("z", ""):
			Net.tell(id, "buff", {"type": a["type"], "mag": a["mag"], "dur": a["dur"], "heal": a.get("heal", 0.0), "from": pname(peer)})

func on_enemy_killed(peer: int, etype: String, zid: String) -> void:
	quest_logic.on_kill(peer, etype, zid)

# ------------------------------------------------------------------ the night

func start_new_day() -> void:
	var w := Game.world
	var old_day := Game.day()
	var raining_today := Game.is_raining() or Game.weather() == "snow" and false
	var new_day := old_day + 1
	var old_season := Game.season()
	# 1. shipping bin
	var total := 0
	var shipped := 0
	for it in w["shipping"]:
		total += Items.sell_price(it) * int(it["n"])
		shipped += int(it["n"])
	if total > 0:
		w["money"] = Game.money() + total
	w["shipping"] = []
	w["day"] = new_day
	var new_season := Game.season()
	var new_weather := Game.weather_for_day(new_day)
	var new_rain := new_weather in ["rain", "storm"]
	# 2. crops
	var tiles: Dictionary = w["farm"]["tiles"]
	for k in tiles:
		var tv: Dictionary = tiles[k]
		var watered: bool = tv.get("wet", false) or raining_today
		if tv.has("crop") and not tv["crop"].get("dead", false):
			var c: Dictionary = tv["crop"]
			var cd: Dictionary = Items.crops.get(c["id"], {})
			if cd.is_empty():
				tv.erase("crop")
			else:
				if watered and int(c.get("g", 0)) < int(cd["total"]):
					c["g"] = int(c.get("g", 0)) + 1
					if tv.get("gt", false) and rng.randf() < 0.3 and int(c["g"]) < int(cd["total"]):
						c["g"] = int(c["g"]) + 1
				if new_season != old_season and not cd["perennial"] and not cd["seasons"].has(new_season):
					c["dead"] = true
		tv["wet"] = new_rain
		tv.erase("gt")
		if not tv.has("crop") and not new_rain and rng.randf() < 0.04:
			tv["till_fade"] = int(tv.get("till_fade", 0)) + 1
	# untended bare soil slowly goes back to grass
	for k in tiles.keys():
		if int(tiles[k].get("till_fade", 0)) >= 3:
			tiles.erase(k)
	# 3. objects
	for oid in w["objects"]:
		var o: Dictionary = w["objects"][oid]
		var obj: String = Items.def(o["t"]).get("place", {}).get("obj", "")
		var d: Dictionary = o["d"]
		match obj:
			"sprinkler", "sprinkler_2":
				var p: Vector3 = o["p"]
				var k0 := Vector2i(floori(p.x), floori(p.z))
				var offs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				if obj == "sprinkler_2":
					offs.append_array([Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)])
				for off in offs:
					if tiles.has(k0 + off):
						tiles[k0 + off]["wet"] = true
			"fruit_tree":
				var stage := int((new_day - int(d.get("planted", new_day))) / 3.5)
				var fs: int = Items.def(o["t"])["place"].get("season", 0)
				if stage >= 4 and (fs < 0 or fs == new_season):
					d["fruit_n"] = min(3, int(d.get("fruit_n", 0)) + 1)
				elif fs >= 0 and fs != new_season:
					d["fruit_n"] = 0
			"coop":
				var hens := 0
				for oid2 in w["objects"]:
					var o2: Dictionary = w["objects"][oid2]
					if o2["t"] == "chicken" and o2["z"] == o["z"] and Vector3(o2["p"]).distance_to(o["p"]) < 18.0:
						hens += 1
				var fed: int = min(hens, int(d.get("feed", 0)))
				d["feed"] = int(d.get("feed", 0)) - fed
				d["eggs"] = min(12, int(d.get("eggs", 0)) + fed)
	# 4. town, quests, shops
	town_logic.new_day(new_day)
	quest_logic.new_day(new_day)
	# 5. chronicle of the season
	if new_season != old_season:
		w["chronicle"].append({"d": new_day, "s": "%s arrived." % Items.season_name(new_season), "k": "season"})
	if total >= 1000:
		w["chronicle"].append({"d": old_day, "s": "The shipping bin earned %d coins in a single night." % total, "k": "trade"})
	var payload := {"day": new_day, "money": w["money"], "farm": w["farm"], "objects": w["objects"], "shipping": w["shipping"],
		"town": w["town"], "quests": w["quests"], "chronicle": w["chronicle"], "flags": w["flags"]}
	Game.tod = 0.0
	_ch({"t": "new_day", "v": payload, "tod": 0.0})
	if total > 0:
		_toast("Overnight, the shipping bin sold %d items for %d coins." % [shipped, total], Color("ffd36b"))
	if Game.main:
		Game.main.autosave()
