class_name TownUI
extends RefCounted
## Conversations and town-facing interactions: talking, gifts, shops, requests.

static var talks := {}       # npc id -> {"day": d, "n": count}

## Everything Dialogue needs to know about the world when someone speaks.
static func context_for(npc: Dictionary, player: String) -> Dictionary:
	var town := Zones.town
	var ev: Array = []
	var chron: Array = Game.world.get("chronicle", [])
	for i in range(chron.size() - 1, max(-1, chron.size() - 25), -1):
		var e: Dictionary = chron[i]
		if Game.day() - int(e.get("d", 0)) <= 7:
			ev.append(e)
	var req := {}
	for r in QuestLogic.for_npc(npc.get("id", "")):
		req = {"type": r["type"], "item": r.get("item", ""), "item_name": r.get("item_name", ""), "count": r.get("count", 1),
			"floor": r.get("floor", 0), "enemy": r.get("enemy_name", ""), "place": r.get("place_name", "")}
		break
	var done_names: Array = []
	for pid in Game.world.get("town", {}).get("projects", {}):
		if Game.world["town"]["projects"][pid].get("state", "") == "built":
			done_names.append(TownLogic.project(pid).get("name", pid))
	var bd: Array = npc.get("birthday", [-1, -1])
	var t: Dictionary = talks.get(npc.get("id", ""), {})
	var tc := int(t.get("n", 0)) if int(t.get("day", -1)) == Game.day() else 0
	var keeper_open := false
	var tb = Zones.get_zone("over").town if Zones.get_zone("over") else null
	if tb and tb.npc(npc.get("id", "")):
		keeper_open = tb.npc(npc["id"]).at_work()
	return {
		"player": player, "hearts": TownLogic.hearts(npc.get("id", ""), player), "talk_count": tc,
		"day": Game.day(), "season": Game.season(), "season_name": Items.season_name(Game.season()), "weather": Game.weather(),
		"hour": int(Game.clock_minutes() / 60), "is_night": Game.is_night(), "town": town.name if town else "town",
		"people": town.by_id if town else {}, "events": ev, "deepest": int(Game.world["know"].get("deepest", 0)),
		"identities": identities(), "request": req, "shop_open": keeper_open, "projects_done": done_names,
		"player_count": max(1, Game.world.get("players", {}).size()),
		"birthday_today": bd.size() == 2 and int(bd[0]) == Game.season() and int(bd[1]) == Game.day_of_season(),
	}

## Who in the household has quietly become "the farmer", "the angler"... (never announced; townsfolk notice).
static func identities() -> Dictionary:
	var stats_for := {"farmer": ["crops_harvested", "seeds_planted"], "angler": ["fish_caught"], "miner": ["ore_mined"],
		"brewer": ["brews_started"], "cook": ["meals_cooked"], "fighter": ["creatures_defeated"], "decorator": ["things_placed"], "explorer": ["places_found", "floors_descended"]}
	var players: Dictionary = Game.world.get("players", {})
	var out := {}
	for role in stats_for:
		var best := ""
		var best_v := 0
		var second := 0
		for nm in players:
			var v := 0
			for st in stats_for[role]:
				v += int(players[nm].get("stats", {}).get(st, 0))
			if v > best_v:
				second = best_v
				best_v = v
				best = nm
			elif v > second:
				second = v
		var need := 25 if players.size() > 1 else 60
		if best != "" and best_v >= need and best_v >= second * 1.6:
			out[role] = best
	return out

# ------------------------------------------------------------------ features

static func on_feature(ui: UIRoot, f) -> void:
	match f.action:
		"shop":
			var shop: String = f.args.get("shop", "")
			var role: String = f.args.get("role", "")
			if role == "" or keeper_at_work(role):
				ui.show_win(ShopWindow.new(shop, f.args.get("bname", "Shop")))
			else:
				var keeper := Zones.town.residents_with_role(role)
				var line := "Closed. Opening hours are posted on the door."
				if not keeper.is_empty():
					line = Dialogue.shop_closed(keeper[0], context_for(keeper[0], Game.profile["name"]))
				ui.show_message(line, f.args.get("bname", "Shop"))
		"board":
			ui.show_win(BoardWindow.new("requests"))
		"projects":
			ui.show_win(BoardWindow.new("projects"))
		"curio":
			ui.show_win(BoardWindow.new("curio"))

static func keeper_at_work(role: String) -> bool:
	var over = Zones.get_zone("over")
	if over == null or over.town == null:
		return false
	for p in Zones.town.residents_with_role(role):
		var n = over.town.npc(p["id"])
		if n and n.at_work():
			return true
	return false

static func on_tell(ui: UIRoot, kind: String, data: Dictionary) -> void:
	match kind:
		"npc_say":
			if ui.current and ui.current.kind == "dialogue" and ui.current.npc_id == data["npc"]:
				ui.current.say(data["text"])
				if data.get("level", "") == "love":
					Sfx.play("gift")
			else:
				var p := Zones.town.resident(data["npc"]) if Zones.town else {}
				Game.say("%s: %s" % [p.get("first", "?"), data["text"]], UITheme.TEXT)
		"npc_gift":
			var p2 := Zones.town.resident(data["npc"]) if Zones.town else {}
			ui.show_message(data["text"], "A gift from %s" % p2.get("first", "a friend"))
			Sfx.play("gift")

# ------------------------------------------------------------------ shop & gift clicks

static func shop_click(ui: UIRoot, slot: ItemSlot, button: int, shift: bool) -> void:
	if not (ui.current is ShopWindow) or slot.item.is_empty():
		return
	var w: ShopWindow = ui.current
	var id: String = slot.item["id"]
	var n := 5 if shift and Items.stack_max(id) > 1 else 1
	var cost := TownLogic.buy_price_for(id, w.shop, Game.profile["name"]) * n
	if Game.money() < cost:
		Game.say("You can't afford that.", UITheme.BAD)
		Sfx.play("error", -6.0)
		return
	if not Game.inv.can_add(Items.make(id, n)):
		Game.say("No room in your pack.", UITheme.BAD)
		return
	Net.request("shop_buy", {"shop": w.shop, "id": id, "n": n})

static func sell_from_slot(ui: UIRoot, i: int, button: int, shift: bool) -> void:
	var w: ShopWindow = ui.current
	var s: Dictionary = Game.inv.get_slot(i)
	if s.is_empty():
		return
	var c := Items.cat_of(s["id"])
	if c == "quest":
		Game.say("You can't sell that — someone's waiting for it.", UITheme.BAD)
		return
	if (c in ["tool"] and int(Items.def(s["id"])["tool"]["tier"]) == 0):
		Game.say("You'll want to keep that.", UITheme.BAD)
		return
	var n := int(s["n"]) if shift else 1
	var out := Game.inv.take_at(i, n)
	Game.inventory_changed.emit()
	Net.request("shop_sell", {"item": out, "shop": w.shop})
	Game.learn_item(out["id"])

static func gift_click(_ui: UIRoot, _slot: ItemSlot) -> void:
	pass

# ------------------------------------------------------------------ dialogue window

static func open_dialogue(ui: UIRoot, n: NPC) -> void:
	var w := DialogueWin.new(n)
	ui.show_win(w)

class DialogueWin extends UIWin:
	var npc_id := ""
	var npc: NPC
	var p: Dictionary
	var text_rt: RichTextLabel
	var lines: Array = []
	var line_i := 0
	var opts: VBoxContainer
	var hearts_l: Label

	func _init(n: NPC) -> void:
		npc = n
		p = n.data
		npc_id = p["id"]
		super._init(p["name"], Vector2(620, 300))
		kind = "dialogue"
		obj = null
		var sub := UITheme.label("%s%s" % [TownGen.job_title(p), "" if p["age"] != "child" else ""], 15, UITheme.TEXT_DIM)
		content.add_child(sub)
		hearts_l = UITheme.label("", 18, Color("ff8aa0"))
		content.add_child(hearts_l)
		text_rt = UITheme.rich("", 19)
		text_rt.custom_minimum_size = Vector2(590, 80)
		content.add_child(text_rt)
		opts = VBoxContainer.new()
		content.add_child(opts)
		var me: String = Game.profile["name"]
		var t: Dictionary = TownUI.talks.get(npc_id, {})
		var ctx := TownUI.context_for(p, me)
		var first_meet = not Game.world["know"]["people"].has(npc_id)
		if first_meet and int(p.get("arrived", 0)) > 0:
			lines = [Dialogue.newcomer_intro(p, ctx)]
		else:
			lines = Dialogue.talk(p, ctx)
		if lines.is_empty():
			lines = ["..."]
		if int(t.get("day", -1)) == Game.day():
			t["n"] = int(t.get("n", 0)) + 1
		else:
			t = {"day": Game.day(), "n": 1}
		TownUI.talks[npc_id] = t
		Net.request("talk", {"npc": npc_id})
		Game.add_stat("conversations")
		_show_line()

	func say(text: String) -> void:
		lines = [text]
		line_i = 0
		_show_line()

	func _show_line() -> void:
		text_rt.text = lines[line_i]
		hearts_l.text = _hearts_text()
		clear_box(opts)
		if line_i < lines.size() - 1:
			opts.add_child(UITheme.button("...", func():
				line_i += 1
				_show_line(), 17))
			return
		_build_options()

	func _hearts_text() -> String:
		var h := TownLogic.hearts(npc_id, Game.profile["name"])
		var s := ""
		for i in 10:
			s += "♥" if i < h else "♡"
		return s

	func refresh() -> void:
		hearts_l.text = _hearts_text()

	func _opt(text: String, cb: Callable) -> void:
		var b := UITheme.button(text, cb, 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		opts.add_child(b)

	func _build_options() -> void:
		var role: String = p["role"]
		var shop: String = TownGen.ROLE_INFO.get(role, {}).get("shop", "")
		var ui: UIRoot = Game.main.ui
		if shop != "" and npc.at_work():
			_opt("Let me see what you have.", func(): ui.show_win(ShopWindow.new(shop, TownGen.ROLE_INFO[role]["building"])))
		if role == "smith" and npc.at_work():
			_opt("About your forge services...", func(): ui.show_win(SmithWindow.new()))
		if role == "carpenter" and npc.at_work():
			_opt("About fixing up our farmhouse...", func(): ui.show_win(RenovateWindow.new()))
		if role == "mayor":
			_opt("How are the town projects coming along?", func(): ui.show_win(BoardWindow.new("projects")))
		for r in QuestLogic.for_npc(npc_id):
			var req: Dictionary = r
			if req["type"] in ["deliver", "fish", "brew", "fetch"]:
				var have := Game.inv.count(req["item"])
				if have >= int(req["count"]):
					_opt("Here's your %s%s." % [req["item_name"], " ×%d" % int(req["count"]) if int(req["count"]) > 1 else ""], func(): _turn_in(req))
			elif QuestLogic.ready_to_report(req):
				_opt("About your request — it's done.", func(): _turn_in(req))
		_opt("I brought you something.", func(): ui.show_win(GiftWindow.new(npc, "gift")))
		_opt("Do you know what this is?", func(): ui.show_win(GiftWindow.new(npc, "identify")))
		var h := TownLogic.hearts(npc_id, Game.profile["name"])
		if h >= 4 and not Game.world["town"].get("wishes", {}).has(npc_id):
			_opt("Is there anything you've always wanted?", func(): say(Dialogue.wish_text(p, Items.def(p.get("wish", "heartstone"))["name"])))
		_opt("See you around.", func():
			text_rt.text = Dialogue.goodbye(p, TownUI.context_for(p, Game.profile["name"]))
			var tw := create_tween()
			tw.tween_interval(0.9)
			tw.tween_callback(close_win))

	func _turn_in(req: Dictionary) -> void:
		var returned: Array = []
		if req["type"] in ["deliver", "fish", "brew", "fetch"]:
			if not Game.inv.remove(req["item"], int(req["count"])):
				return
			returned.append(Items.make(req["item"], int(req["count"])))
			Game.inventory_changed.emit()
		Net.request("quest_turn_in", {"qid": req["qid"], "returned": returned})
		Game.add_stat("requests_done")
