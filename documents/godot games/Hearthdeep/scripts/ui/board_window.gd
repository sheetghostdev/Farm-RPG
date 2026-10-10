class_name BoardWindow
extends UIWin
## The request board, the community projects ledger and the Curio Hall.

var mode := "requests"
var body: VBoxContainer

func _init(m: String) -> void:
	mode = m
	super._init({"requests": "Request Board", "projects": "Community Projects", "curio": "Curio Hall"}.get(m, "Board"), Vector2(700, 520))
	kind = "board"
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(680, 460)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	sc.add_child(body)
	refresh()

func refresh() -> void:
	clear_box(body)
	match mode:
		"requests":
			_requests()
		"projects":
			_projects()
		"curio":
			_curio()

func _card() -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(0.93, 0.88, 0.76, 0.97), Color("8a6a4a"), 6, 2, 12))
	body.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	return v

func _requests() -> void:
	var act: Array = QuestLogic.quests().get("active", [])
	if act.is_empty():
		body.add_child(UITheme.label("Nothing pinned up right now. Check back tomorrow.", 16, UITheme.TEXT_DIM))
	for r in act:
		var npc: Dictionary = Zones.town.resident(r["npc"]) if Zones.town else {}
		var v := _card()
		v.add_child(UITheme.label(QuestLogic.title(r), 18, Color("4a2a1a")))
		var t := UITheme.label(r.get("text", ""), 15, Color("3a2a20"))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(620, 0)
		v.add_child(t)
		var days := int(r.get("expires", Game.day())) - Game.day()
		v.add_child(UITheme.label("Reward: %d coins · from %s · %s" % [int(r.get("reward", 0)), npc.get("name", "?"), "last day!" if days <= 0 else "%d days left" % days], 14, Color("6a4a2a")))
	var done: Array = QuestLogic.quests().get("done", [])
	if not done.is_empty():
		body.add_child(UITheme.label("Recently helped", 16, UITheme.TEXT_DIM))
		for i in range(done.size() - 1, max(-1, done.size() - 6), -1):
			var d: Dictionary = done[i]
			var who: Dictionary = Zones.town.resident(d["npc"]) if Zones.town else {}
			body.add_child(UITheme.label("Day %d — %s helped %s: %s" % [int(d["day"]), d["by"], who.get("first", "?"), d["title"]], 14, UITheme.TEXT_DIM))

func _projects() -> void:
	var lvl := int(Game.world["town"].get("level", 0))
	body.add_child(UITheme.label("Town level %d · Prosperity %d" % [lvl, int(Game.world["town"].get("prosperity", 0))], 16, UITheme.ACCENT))
	var counts := Game.inv.counts()
	for pd in TownLogic.PROJECTS:
		var st: Dictionary = Game.world["town"].get("projects", {}).get(pd["id"], {})
		var state: String = st.get("state", "open")
		var v := _card()
		var locked := lvl < int(pd["level"])
		v.add_child(UITheme.label(pd["name"] + ("  ✓ built" if state == "built" else ("  (work begins tonight)" if state == "funded" else "")), 18, Color("4a2a1a")))
		var dl := UITheme.label(pd["desc"] if not locked else "The town isn't ready for this yet. (Needs town level %d)" % int(pd["level"]), 14, Color("3a2a20"))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(620, 0)
		v.add_child(dl)
		if locked or state != "open":
			continue
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		for id in pd["needs"]:
			var have := int(st.get("have", {}).get(id, 0))
			var need := int(pd["needs"][id])
			var s := ItemSlot.new(32)
			s.set_item(Items.make(id))
			s.mouse_filter = Control.MOUSE_FILTER_PASS
			h.add_child(s)
			h.add_child(UITheme.label("%d/%d" % [have, need], 14, Color("2a6a2a") if have >= need else Color("6a2a2a")))
			var mine := int(counts.get(id, 0))
			if have < need and mine > 0:
				var give: int = min(mine, need - have)
				var pid: String = pd["id"]
				var iid: String = id
				h.add_child(UITheme.button("Give %d" % give, func():
					Game.inv.remove(iid, give)
					Game.inventory_changed.emit()
					Net.request("project_give", {"pid": pid, "item": iid, "n": give})
					Game.add_stat("project_gifts", give), 13))
		var coins_have := int(st.get("coins", 0))
		var coins_need := int(pd["coins"])
		var ch := HBoxContainer.new()
		v.add_child(ch)
		ch.add_child(UITheme.label("Coins: %d/%d" % [coins_have, coins_need], 14, Color("2a6a2a") if coins_have >= coins_need else Color("6a2a2a")))
		if coins_have < coins_need and Game.money() > 0:
			var pid2: String = pd["id"]
			var amt: int = min(Game.money(), coins_need - coins_have)
			ch.add_child(UITheme.button("Pay %d" % amt, func(): Net.request("project_give", {"pid": pid2, "coins": amt}), 13))

func _curio() -> void:
	var don: Dictionary = Game.world["town"].get("donated", {})
	body.add_child(UITheme.label("%d curiosities on display. Donations earn a reward and a place in the hall's records." % don.size(), 15, UITheme.ACCENT))
	var g := slot_grid(10)
	for id in Items.defs:
		if Items.def(id).get("curio", false) or Items.cat_of(id) == "gem":
			var s := ItemSlot.new(50)
			s.set_item(Items.make(id) if don.has(id) else {})
			if don.has(id):
				s.note = don[id]["by"]
			s.hovered.connect(func(sl, on): Game.main.hud.show_tooltip((ItemSlot.describe(sl.item) + "\n[color=#c8b89a]Donated by %s on day %d[/color]" % [don[id]["by"], int(don[id]["day"])]) if on and not sl.item.is_empty() else ""))
			g.add_child(s)
	body.add_child(g)
	body.add_child(UITheme.label("Donate from your pack:", 15, UITheme.TEXT_DIM))
	var g2 := slot_grid(10)
	for i in Game.inv.capacity:
		var it: Dictionary = Game.inv.get_slot(i)
		if it.is_empty() or don.has(it["id"]) or not (Items.def(it["id"]).get("curio", false) or Items.cat_of(it["id"]) == "gem"):
			continue
		var s2 := make_slot(it, "donate", i, 50)
		var idx := i
		s2.pressed.connect(func(_sl, _b):
			var one := Game.inv.take_at(idx, 1)
			Game.inventory_changed.emit()
			Net.request("donate_curio", {"item": one["id"]}))
		g2.add_child(s2)
	body.add_child(g2)
