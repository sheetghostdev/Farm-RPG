class_name SmithWindow
extends UIWin
## Blacksmith services: tool upgrades, cracking geodes, reforging traits.

var body: VBoxContainer

func _init() -> void:
	super._init("Forge Services", Vector2(620, 420))
	kind = "smith"
	body = VBoxContainer.new()
	content.add_child(body)
	refresh()

func refresh() -> void:
	clear_box(body)
	body.add_child(UITheme.label("Upgrade a tool (needs 5 bars of the next metal + coins):", 16, UITheme.ACCENT))
	var costs := [400, 1200, 3000, 8000]
	var bars := ["copper_bar", "iron_bar", "gold_bar", "starmetal_bar"]
	for i in Game.inv.capacity:
		var it: Dictionary = Game.inv.get_slot(i)
		if it.is_empty() or not Items.def(it["id"]).has("tool"):
			continue
		var t: Dictionary = Items.def(it["id"])["tool"]
		var tier := int(t["tier"])
		if tier >= 4 or (t["kind"] == "rod"):
			continue
		var bar: String = bars[tier]
		var row := HBoxContainer.new()
		row.add_child(make_slot(it, "info", 0, 44))
		row.add_child(UITheme.label("→ %s %s:  5 %s + %d coins" % [Items.TOOL_TIERS[tier + 1], {"hoe": "Hoe", "can": "Watering Can", "axe": "Axe", "pick": "Pickaxe"}.get(t["kind"], ""), Items.def(bar)["name"], costs[tier]], 15))
		var ok = Game.inv.count(bar) >= 5 and Game.money() >= costs[tier]
		var idx := i
		var b := UITheme.button("Upgrade", func():
			var tool := Game.inv.take_at(idx, 1)
			Game.inv.remove(bar, 5)
			Game.inventory_changed.emit()
			Net.request("upgrade_tool", {"item": tool})
			Sfx.play("craft"), 14)
		b.disabled = not ok
		row.add_child(b)
		body.add_child(row)
	body.add_child(HSeparator.new())
	var geodes := Game.inv.count("geode")
	var gb := UITheme.button("Crack %d geode%s (25 coins each)" % [geodes, "" if geodes == 1 else "s"], func():
		var n: int = min(geodes, Game.money() / 25)
		if n > 0:
			Game.inv.remove("geode", n)
			Game.inventory_changed.emit()
			Net.request("crack_geode", {"n": n})
			Sfx.play("mine"), 15)
	gb.disabled = geodes == 0 or Game.money() < 25
	body.add_child(gb)
	if Game.world["flags"].get("project_smithy", false):
		body.add_child(HSeparator.new())
		body.add_child(UITheme.label("Reforge: hold a weapon or piece of gear in your hand, then press:", 15, UITheme.ACCENT))
		var lp = Game.local_player
		var held: Dictionary = lp.held_item() if lp else {}
		var rb := UITheme.button("Reforge %s" % Items.display_name(held) if not held.is_empty() else "Reforge (nothing held)", func():
			var it2 := Game.inv.take_at(lp.hot_index, 1)
			Game.inventory_changed.emit()
			Net.request("reforge", {"item": it2}), 15)
		rb.disabled = held.is_empty() or not (Items.def(held["id"]).has("weapon") or Items.def(held["id"]).has("gear"))
		body.add_child(rb)
