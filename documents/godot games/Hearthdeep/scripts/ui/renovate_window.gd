class_name RenovateWindow
extends UIWin
## The carpenter's offer to enlarge the farmhouse. Work happens overnight.

var body: VBoxContainer

func _init() -> void:
	super._init("Farmhouse Renovation", Vector2(560, 300))
	kind = "renovate"
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)
	refresh()

func refresh() -> void:
	clear_box(body)
	var lvl := int(Game.world["farm"].get("level", 0))
	var pending := int(Game.world["flags"].get("house_pending", 0))
	if pending > lvl:
		body.add_child(UITheme.label("The work is underway. It'll be done by tomorrow morning.", 17))
		return
	if lvl >= TownLogic.HOUSE_UPGRADES.size():
		body.add_child(UITheme.label("The farmhouse is as grand as I know how to make it.", 17))
		return
	var up: Dictionary = TownLogic.HOUSE_UPGRADES[lvl]
	body.add_child(UITheme.label(up["name"], 20, UITheme.ACCENT))
	var d := UITheme.label(up["desc"], 15, UITheme.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(520, 0)
	body.add_child(d)
	var counts := {}
	var ok := true
	for id in up["needs"]:
		counts[id] = Game.inv.count(id)
		if counts[id] < int(up["needs"][id]):
			ok = false
	body.add_child(need_row(up["needs"], counts))
	var coins := int(up["coins"])
	body.add_child(UITheme.label("%d coins (household has %d)" % [coins, Game.money()], 16, UITheme.GOOD if Game.money() >= coins else UITheme.BAD))
	if Game.money() < coins:
		ok = false
	var b := UITheme.button("Start the renovation", func():
		var items: Array = []
		for id in up["needs"]:
			var n := int(up["needs"][id])
			if not Game.inv.remove(id, n):
				Game.local_grant(items, true)
				return
			items.append(Items.make(id, n))
		Game.inventory_changed.emit()
		Net.request("house_upgrade", {"items": items})
		Sfx.play("craft")
		close_win(), 17)
	b.disabled = not ok
	body.add_child(b)
	body.add_child(UITheme.label("Bring the materials in your pack. Coins come from the shared purse.", 13, UITheme.TEXT_DIM))
