class_name FurnaceWindow
extends UIWin
## Smelting: three ore and one coal become a bar.

var list: VBoxContainer

func _init(o) -> void:
	super._init("Furnace", Vector2(520, 320))
	kind = "furnace"
	obj = o
	list = VBoxContainer.new()
	content.add_child(list)
	refresh()

func refresh() -> void:
	clear_box(list)
	var coal := Game.inv.count("coal")
	list.add_child(UITheme.label("Coal in pack: %d" % coal, 16, UITheme.TEXT_DIM))
	var any := false
	for ore in Items.smelt:
		var n := Game.inv.count(ore)
		if n < 3:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(make_slot(Items.make(ore, n), "info", 0, 46))
		row.add_child(UITheme.label("→", 22, UITheme.ACCENT))
		row.add_child(make_slot(Items.make(Items.smelt[ore]), "info", 0, 46))
		var mx: int = min(min(n / 3, coal), 10)
		var l := UITheme.label("%s ×%d possible" % [Items.def(Items.smelt[ore])["name"], mx], 15, UITheme.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b1 := UITheme.button("Smelt 1", func(): _load(ore, 1), 15)
		b1.disabled = mx < 1
		row.add_child(b1)
		var b2 := UITheme.button("Smelt %d" % mx, func(): _load(ore, mx), 15)
		b2.disabled = mx < 2
		row.add_child(b2)
		list.add_child(row)
	if not any:
		list.add_child(UITheme.label("You need at least 3 of the same ore (and some coal).", 15, UITheme.TEXT_DIM))
	list.add_child(UITheme.label("Each bar takes about 50 minutes.", 14, UITheme.TEXT_DIM))

func _load(ore: String, n: int) -> void:
	if Game.inv.count(ore) < n * 3 or Game.inv.count("coal") < n:
		return
	Game.inv.remove(ore, n * 3)
	Game.inv.remove("coal", n)
	Game.inventory_changed.emit()
	Game.learn_item(ore)
	Net.request("furnace_load", {"id": obj.oid, "ore": ore, "n": n})
	Sfx.play("place")
	close_win()
